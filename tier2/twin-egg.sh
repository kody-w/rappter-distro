#!/bin/bash
# rapp_swarm/twin-egg.sh — pack/unpack the full local Twin Stack as a .egg
#
# A .egg is a single zipfile capturing the entire local Twin Stack ecosystem:
# every twin's workspace, identity, peers, conversations, documents, inbox,
# outbox, hatched swarms, and the shared workflow dir (where book-factory
# and other multi-twin pipelines drop in-flight artifacts). Excludes
# transient runtime state (server.pid, server.log).
#
# Restore is byte-identical. Pack on machine A, unpack on machine B (or on
# A six months later) → state resumes as if no time passed and no machine
# was changed. Twins keep their identities, their peer relationships, their
# in-progress conversations, their inbox-pending documents.
#
#     bash rapp_swarm/twin-egg.sh pack  [--out twinstack-2026-04-19.egg]
#     bash rapp_swarm/twin-egg.sh unpack twinstack.egg [--into ~/.rapp-twins] [--start]
#     bash rapp_swarm/twin-egg.sh info  twinstack.egg
#
# Defaults: TWINS_HOME=~/.rapp-twins. .egg files are zipfiles (use `unzip -l`
# to inspect contents directly).

set -e
set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TWINS_HOME="${TWINS_HOME:-$HOME/.rapp-twins}"
SHARED_DIR="$TWINS_HOME/.shared"

# ── Helpers ────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
RAPP Twin Egg — portable snapshot of the entire local Twin Stack.

  pack   [--out PATH] [--include DIR ...]
                          Capture current TWINS_HOME (and any --include dirs)
                          into a single .egg zipfile. Default output:
                          twinstack-<UTC-timestamp>.egg in current dir.
  unpack EGG [--into DIR] [--start]
                          Restore .egg into DIR (default: TWINS_HOME).
                          --start launches every twin restored.
  info   EGG              Print the egg-manifest.json from a .egg.
  list                    List .egg files in the current dir.

Env:
  TWINS_HOME   default: \$HOME/.rapp-twins
EOF
}

# Stable JSON via Python (stdlib, sorted keys, deterministic).
canonical_json() { python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), sort_keys=True, indent=2))"; }

# ── pack ───────────────────────────────────────────────────────────────

cmd_pack() {
    local out=""
    local extras=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --out) out="$2"; shift ;;
            --include) extras+=("$2"); shift ;;
            -h|--help) usage; exit 0 ;;
            *) echo "unknown flag: $1"; exit 2 ;;
        esac
        shift
    done
    if [ -z "$out" ]; then
        out="twinstack-$(date -u +%Y%m%dT%H%M%SZ).egg"
    fi
    [ -d "$TWINS_HOME" ] || { echo "✗ TWINS_HOME does not exist: $TWINS_HOME"; exit 1; }

    echo "▶ Packing TWINS_HOME=$TWINS_HOME → $out"

    # Use Python to drive zipfile (stdlib, cross-platform, exact control).
    python3 - "$TWINS_HOME" "$out" "${extras[@]}" <<'PY'
import sys, os, json, hashlib, zipfile
from datetime import datetime, timezone
from pathlib import Path

twins_home = Path(sys.argv[1]).expanduser().resolve()
out_path   = Path(sys.argv[2]).resolve()
extras     = [Path(p).expanduser().resolve() for p in sys.argv[3:]]

EXCLUDE_NAMES = {"server.pid", "server.log", ".DS_Store", "__pycache__"}
EXCLUDE_SUFFIXES = (".pyc",)

def should_skip(p: Path) -> bool:
    if p.name in EXCLUDE_NAMES: return True
    if any(part in EXCLUDE_NAMES for part in p.parts): return True
    if p.suffix in EXCLUDE_SUFFIXES: return True
    return False

def walk_files(root: Path):
    for sub in sorted(root.rglob("*")):
        if not sub.is_file(): continue
        if should_skip(sub): continue
        yield sub

def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

twins = []
files_added = []     # list of (arcname, sha256, bytes)

if out_path.exists(): out_path.unlink()

with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
    # Twin workspaces (exclude .shared, it gets its own arc tree)
    for child in sorted(twins_home.iterdir()):
        if not child.is_dir(): continue
        if child.name == ".shared":
            for f in walk_files(child):
                rel = f.relative_to(twins_home)        # ".shared/.../file"
                arc = "shared/" + str(rel.relative_to(".shared"))
                zf.write(f, arcname=arc)
                files_added.append((arc, sha256_file(f), f.stat().st_size))
            continue
        # Regular twin workspace
        twin_name = child.name
        wp = child / "workspace.json"
        meta = {}
        if wp.exists():
            try: meta = json.loads(wp.read_text())
            except Exception: meta = {}
        twins.append({
            "name": twin_name,
            "handle": meta.get("name", twin_name),
            "port": meta.get("port"),
            "url": meta.get("url"),
            "created_at": meta.get("created_at"),
        })
        for f in walk_files(child):
            rel = f.relative_to(twins_home)
            arc = "twins/" + str(rel)
            zf.write(f, arcname=arc)
            files_added.append((arc, sha256_file(f), f.stat().st_size))

    # Extra --include paths (e.g., a session dir outside TWINS_HOME)
    for ex in extras:
        if not ex.exists(): continue
        if ex.is_file():
            arc = "extras/" + ex.name
            zf.write(ex, arcname=arc)
            files_added.append((arc, sha256_file(ex), ex.stat().st_size))
        elif ex.is_dir():
            for f in walk_files(ex):
                arc = "extras/" + ex.name + "/" + str(f.relative_to(ex))
                zf.write(f, arcname=arc)
                files_added.append((arc, sha256_file(f), f.stat().st_size))

    # egg-manifest.json
    manifest = {
        "schema": "rapp-egg/1.0",
        "egg_version": 1,
        "created_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "host": os.uname().nodename if hasattr(os, "uname") else "unknown",
        "twins_home": str(twins_home),
        "twins": twins,
        "stats": {
            "twin_count": len(twins),
            "file_count": len(files_added),
            "total_bytes": sum(b for _, _, b in files_added),
        },
        "files": [{"arc": a, "sha256": s, "bytes": b} for a, s, b in files_added],
    }
    zf.writestr("egg-manifest.json", json.dumps(manifest, indent=2, sort_keys=True))

print(f"  ✓ packed {len(twins)} twin(s), {len(files_added)} file(s), "
      f"{sum(b for _,_,b in files_added):,} bytes → {out_path}")
print(f"  ✓ egg size on disk: {out_path.stat().st_size:,} bytes")
PY
}

# ── unpack ─────────────────────────────────────────────────────────────

cmd_unpack() {
    local egg=""
    local into="$TWINS_HOME"
    local start=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --into)  into="$2"; shift ;;
            --start) start=1 ;;
            -h|--help) usage; exit 0 ;;
            *) [ -z "$egg" ] && egg="$1" || { echo "unknown arg: $1"; exit 2; } ;;
        esac
        shift
    done
    [ -f "$egg" ] || { echo "✗ egg not found: $egg"; exit 1; }
    mkdir -p "$into"
    # Free any chmod-444 sealed dirs in the destination so unpack can write
    chmod -R u+w "$into" 2>/dev/null || true

    echo "▶ Unpacking $egg → $into"

    python3 - "$egg" "$into" <<'PY'
import sys, os, json, zipfile, hashlib
from pathlib import Path

egg_path = Path(sys.argv[1]).resolve()
into     = Path(sys.argv[2]).expanduser().resolve()
into.mkdir(parents=True, exist_ok=True)

with zipfile.ZipFile(egg_path, "r") as zf:
    try:
        manifest = json.loads(zf.read("egg-manifest.json").decode())
    except KeyError:
        print("✗ not a valid .egg (missing egg-manifest.json)"); sys.exit(1)

    if manifest.get("schema") != "rapp-egg/1.0":
        print(f"✗ unsupported egg schema: {manifest.get('schema')}"); sys.exit(1)

    expected_hashes = {f["arc"]: f["sha256"] for f in manifest.get("files", [])}
    extracted = 0
    sha_failures = []
    skipped_pid_log = 0

    for info in zf.infolist():
        arc = info.filename
        if arc == "egg-manifest.json": continue
        # Path-traversal guard: only allow arcs under twins/, shared/, extras/
        if not (arc.startswith("twins/") or arc.startswith("shared/") or arc.startswith("extras/")):
            print(f"  ! skipping suspicious arc: {arc}"); continue
        if any(part == ".." for part in Path(arc).parts):
            print(f"  ! skipping traversal arc: {arc}"); continue
        # Skip transient files even if they made it into the egg
        name = Path(arc).name
        if name in {"server.pid", "server.log"}:
            skipped_pid_log += 1; continue

        # Map archive paths back to filesystem
        if arc.startswith("twins/"):
            dest = into / arc[len("twins/"):]
        elif arc.startswith("shared/"):
            dest = into / ".shared" / arc[len("shared/"):]
        else:  # extras/
            dest = into / arc

        dest.parent.mkdir(parents=True, exist_ok=True)
        with zf.open(info) as src, open(dest, "wb") as out:
            data = src.read()
            out.write(data)
        # Verify SHA-256 if we have an expected one
        if arc in expected_hashes:
            got = hashlib.sha256(data).hexdigest()
            if got != expected_hashes[arc]:
                sha_failures.append(arc)
        extracted += 1

print(f"  ✓ extracted {extracted} file(s)")
if skipped_pid_log:
    print(f"  ✓ skipped {skipped_pid_log} transient file(s) (server.pid/log)")
if sha_failures:
    print(f"  ✗ SHA-256 MISMATCH on {len(sha_failures)} file(s) — egg may be corrupt:")
    for a in sha_failures[:10]: print(f"      - {a}")
    sys.exit(2)
print(f"  ✓ all SHA-256 hashes verified")
print(f"  ✓ restored {len(manifest.get('twins', []))} twin(s) into {into}")
PY

    if [ "$start" = "1" ]; then
        echo ""
        echo "▶ --start: launching restored twins"
        for d in "$into"/*/; do
            [ -d "$d" ] || continue
            local name="$(basename "$d")"
            [ "$name" = ".shared" ] && continue
            TWINS_HOME="$into" bash "$(dirname "$0")/twin-sim.sh" start "$name" || true
        done
    fi
}

# ── info ───────────────────────────────────────────────────────────────

cmd_info() {
    local egg="$1"
    [ -f "$egg" ] || { echo "✗ egg not found: $egg"; exit 1; }
    python3 - "$egg" <<'PY'
import sys, json, zipfile
from pathlib import Path
egg = Path(sys.argv[1]).resolve()
with zipfile.ZipFile(egg, "r") as zf:
    try:
        m = json.loads(zf.read("egg-manifest.json").decode())
    except KeyError:
        print("✗ not a valid .egg (missing egg-manifest.json)"); sys.exit(1)
print(f"  schema:        {m['schema']}")
print(f"  egg_version:   {m['egg_version']}")
print(f"  created_at:    {m['created_at']}")
print(f"  host:          {m.get('host', '?')}")
print(f"  source path:   {m.get('twins_home', '?')}")
print(f"  twin count:    {m['stats']['twin_count']}")
print(f"  file count:    {m['stats']['file_count']}")
print(f"  total bytes:   {m['stats']['total_bytes']:,}")
print(f"  egg size:      {egg.stat().st_size:,} bytes")
print(f"  twins:")
for t in m['twins']:
    print(f"    • {t['handle']:20s} port={t.get('port')}  created={t.get('created_at','?')}")
PY
}

# ── list ───────────────────────────────────────────────────────────────

cmd_list() {
    local found=0
    for f in *.egg; do
        [ -f "$f" ] || continue
        found=1
        local size; size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
        printf "  %-40s  %10s bytes\n" "$f" "$size"
    done
    [ "$found" = "0" ] && echo "  (no .egg files in $(pwd))"
}

# ── Dispatch ───────────────────────────────────────────────────────────

CMD="${1:-help}"; shift || true
case "$CMD" in
    pack)   cmd_pack   "$@" ;;
    unpack) cmd_unpack "$@" ;;
    info)   cmd_info   "$@" ;;
    list)   cmd_list ;;
    help|-h|--help) usage ;;
    *) echo "unknown: $CMD"; usage; exit 2 ;;
esac
