"""utils/bond.py — Identity, egg, and hatch for the locally-hatched organism.

This is the runtime side of the bonding lifecycle the install one-liner uses:

  birth   — fresh install on a machine that has no organism yet
  egg     — pack the full organism into a portable .egg cartridge
  bond    — egg + apply new framework + hatch (in-place kernel evolution)
  hatch   — extract a .egg over the local kernel (in-place restore, or
            adoption when the egg arrived from elsewhere)

Why bond.py exists separate from the older egg.py:

  egg.py packs *parts* of an organism — a single rapplication, the twin
  agent set, a full snapshot — into a /catalog/-shaped egg. Useful, but
  the layout assumes the active brainstem instance owns the rappid in
  .brainstem_data/identity.json, and the eggs land in a per-rappid
  workspace under a host root.

  Locally-hatched organisms want a different shape: ONE organism per
  brainstem install, identity at ~/.brainstem/rappid.json (above the
  kernel src tree, so kernel overlays can never touch it), and eggs that
  resurrect the *whole* organism (agents/organs/senses/services + soul
  + .env + data + identity) on any kernel that knows how to hatch them.

  bond.py is the CLI the installer drives, and it keeps the schema
  (`brainstem-egg/2.2-organism`) explicit so portable .egg files round-
  trip cleanly across machines.

Usage (run as `python -m utils.bond <cmd>` from inside rapp_brainstem/):

  python -m utils.bond mint-rappid /path/to/brainstem_home [--parent-commit SHA]
  python -m utils.bond egg /path/to/brainstem_home /path/to/out.egg --kernel-version X.Y.Z
  python -m utils.bond hatch /path/to/brainstem_home /path/to/in.egg
  python -m utils.bond record-bond /path/to/brainstem_home <kind> [--from-version V] [--to-version V] [--from-commit SHA] [--to-commit SHA]
  python -m utils.bond bump-incarnations /path/to/brainstem_home
  python -m utils.bond inspect /path/to/in.egg

The egg is a zip at the byte level (PK header) — `unzip foo.egg` works,
recovery from a broken bond is `unzip -o egg -d ~/.brainstem/src/rapp_brainstem`.

Stdlib only — must be importable on a fresh venv before any other deps.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import platform
import re
import socket
import sys
import time
import uuid
import zipfile
from typing import Optional


SCHEMA = "brainstem-egg/2.2-organism"
SCHEMA_RAPP = "brainstem-egg/2.2-rapplication"

# ── §9 rapp/1-egg packing (stdlib-only, inlined from kody-w/rapp-1 · rapp.py) ──
EGG_SCHEMA = "rapp/1-egg"

def _egg_canonical(v):
    if v is None or isinstance(v, bool) or isinstance(v, int):
        return json.dumps(v)
    if isinstance(v, float):
        raise ValueError("no floats in egg manifest")
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list):
        return "[" + ",".join(_egg_canonical(x) for x in v) + "]"
    if isinstance(v, dict):
        ks = sorted(v.keys())
        return "{" + ",".join(json.dumps(k, ensure_ascii=False) + ":" + _egg_canonical(v[k]) for k in ks) + "}"
    raise ValueError(f"uncanonicalizable: {type(v)}")

def _egg_hb(space, b):
    return hashlib.sha256(space.encode() + b"\x0a" + b).hexdigest()

def _now_iso_ms():
    from datetime import datetime, timezone
    n = datetime.now(timezone.utc)
    return n.strftime("%Y-%m-%dT%H:%M:%S.") + f"{n.microsecond // 1000:03d}Z"

class _EggCollector:
    """Drop-in for a ZipFile handle: captures file octets + the legacy manifest dict."""
    def __init__(self): self.files = {}; self.meta = {}
    def __enter__(self): return self
    def __exit__(self, *a): return False
    def writestr(self, name, data):
        octets = data.encode("utf-8") if isinstance(data, str) else data
        if name == "manifest.json":
            self.meta = json.loads(octets); return
        self.files[name] = octets
    def write(self, filename, arcname):
        with open(filename, "rb") as _fh:
            self.files[arcname] = _fh.read()

def _pack_v9(variant, rappid, created_utc, files, payload):
    """Byte-reproducible §9 rapp/1-egg (ZIP stored). Mirrors rapp.pack_egg."""
    contents = sorted(({"path": p, "hash": _egg_hb("rapp/1:egg", o)} for p, o in files.items()),
                      key=lambda c: c["path"].encode("utf-8"))
    manifest = {"schema": EGG_SCHEMA, "variant": variant, "rappid": rappid,
                "created_utc": created_utc, "contents": contents, "payload": payload or {}, "sig": None}
    man = _egg_canonical(manifest).encode("utf-8")
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_STORED) as z:
        def _w(name, d):
            zi = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            zi.compress_type = zipfile.ZIP_STORED; zi.flag_bits |= 0x800
            z.writestr(zi, d)
        _w("manifest.json", man)
        for c in contents:
            _w(c["path"], files[c["path"]])
    return buf.getvalue()

def _finalize_egg(z, variant):
    """Build a §9 egg from a collector: legacy meta → payload; rappid from the record."""
    meta = z.meta
    rappid = meta.get("rappid")
    files = dict(z.files)
    if variant == "organism":
        files.setdefault("soul.md", b"# soul\n")
    if variant == "rapplication":
        # §9 requires exactly one root agent.py; promote the primary agent from agents/.
        af = meta.get("agent_filename")
        cand = ("agents/" + af) if af and ("agents/" + af) in files else                next((n for n in sorted(files) if n.endswith("_agent.py") or n.endswith("agent.py")), None)
        if cand:
            files["agent.py"] = files.pop(cand)
        for n in [n for n in list(files) if "/" not in n and n.endswith(".py") and n != "agent.py"]:
            files["src/" + n] = files.pop(n)
        if not any(n == "agent.py" for n in files):
            variant = "organism"; files.setdefault("soul.md", b"# soul\n")
    payload = {k: v for k, v in meta.items()
               if k not in ("schema", "type", "rappid", "exported_at", "created_utc")}
    return _pack_v9(variant, rappid, _now_iso_ms(), files, payload)


# Canonical species root (RAPP spec §6.1 consolidated form). The whole species
# descends from kody-w/rapp; the 64-hex is its fixed identity hash.
SPECIES_ROOT_RAPPID = (
    "rappid:@kody-w/rapp:"
    "9a8f0a4b5a710e20f4d819a0f37d2a4c9f113b5e78fb3c29e70b54fff48a38f9"
)


def _canon_label(s: str, fallback: str) -> str:
    """Coerce to a canonical §6.1 label: lowercase [a-z0-9] with single internal
    hyphens, no leading/trailing/double hyphens, no underscores."""
    s = re.sub(r"[^a-z0-9]+", "-", (s or "").lower()).strip("-")
    return re.sub(r"-+", "-", s) or fallback


def _mint_rappid_keyless(owner: str, slug: str) -> str:
    """Mint a fresh canonical rappid (spec §6.2, keyless). The tail is
    ``Hb("rapp/1:rappid", uuid4_bytes)`` — 64 hex, domain-separated — NEVER a
    hash of the name. Called ONCE per organism, ever."""
    o = _canon_label(owner, "local")
    s = _canon_label(slug, "unnamed")
    tail = hashlib.sha256(b"rapp/1:rappid" + b"\x0a" + uuid.uuid4().bytes).hexdigest()
    return f"rappid:@{o}/{s}:{tail}"

# Files under brainstem-src that are part of the *organism*, not the
# *kernel*. The kernel ships defaults at install time; the organism's
# customizations to these files are what the egg captures.
ORGANISM_TOP_FILES = ("soul.md", ".env")

# Subtrees under brainstem-src that the egg packs in full (subject to
# per-file exclusions below). Filename layout is mirrored inside the egg.
ORGANISM_TREES = {
    # zip arcname prefix → path inside brainstem-src
    "agents":   "agents",
    "organs":   "utils/organs",
    "senses":   "utils/senses",
    "services": "utils/services",
    "data":     ".brainstem_data",
}

# LAN-federation tools bundled at the root of every organism egg so a
# hatched egg works completely local-first on any device — no
# kody-w/RAPP install required to advertise on the LAN or sniff peers.
# Files live OUTSIDE brainstem-src (at <repo-root>/tools/); resolved at
# pack time as os.path.join(os.path.dirname(src), "tools", <name>).
# Per Article XLVII.5.1 — Bonjour LAN auto-discovery.
ORGANISM_LAN_FEDERATION_TOOLS = (
    "lan_advertise.py",      # broadcast brainstem on _rapp-estate._tcp.local
    "sniff_network.py",      # --via bonjour discovers LAN peers
    "door_address.py",       # the canonical rappid parser (Article XLVI.5)
    "path_opacity.py",       # XLVIII.6 URL-opacity helpers (used by sniffer)
    "private_estate_init.py",# XLVIII bootstrap (lets a hatched op recreate private side)
    "rebuild_estate.py",     # XLVI.6 disaster-recovery rebuild
    "import_peer_egg.py",    # XLVII.5.3 sneakernet federation (import a received egg)
)

# Files that travel as kernel-shipped infrastructure, not as organism
# state. Skip them on egg AND ignore them on hatch.
INFRA_FILES = {"basic_agent.py", "__init__.py"}

# Names that must never enter an egg under any circumstances. Secrets,
# environment artifacts, OS noise, explicit "no-share" namespaces.
SECRETS_FILES = {
    ".copilot_token", ".copilot_session", ".copilot_pending",
    "voice.zip", ".DS_Store", "Thumbs.db",
}
SECRETS_DIRS = {
    "__pycache__", ".pytest_cache", "venv", ".venv", "node_modules",
    "private",  # explicit no-share namespace inside .brainstem_data/
}

# Substrings — if any path component matches a regex below, skip.
_SECRET_PATTERNS = [
    re.compile(r".*\.(token|session|secret|key)$", re.IGNORECASE),
]


# ── small helpers ────────────────────────────────────────────────────────

def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _short_host() -> str:
    raw = socket.gethostname() or "local"
    short = raw.split(".")[0].lower()
    short = re.sub(r"[^\w-]", "-", short).strip("-")
    return short or "local"


def _organism_slug() -> str:
    return f"{_short_host()}-brainstem"


def _excluded(rel_path: str) -> bool:
    """True if a path component would leak secrets or environment noise."""
    parts = rel_path.replace("\\", "/").split("/")
    for p in parts:
        if not p:
            continue
        if p in SECRETS_FILES or p in SECRETS_DIRS:
            return True
        for pat in _SECRET_PATTERNS:
            if pat.match(p):
                return True
    return False


def _read_json(path: str) -> Optional[dict]:
    if not os.path.exists(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def _write_json(path: str, data: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


# ── identity ─────────────────────────────────────────────────────────────

def _rappid_path(home: str) -> str:
    return os.path.join(home, "rappid.json")


def _bonds_path(home: str) -> str:
    return os.path.join(home, "bonds.json")


def mint_rappid(home: str, parent_commit: Optional[str] = None) -> dict:
    """Mint ~/.brainstem/rappid.json if missing. Idempotent.

    Returns the rappid dict (existing or freshly-minted). Includes the
    parent_commit (the framework SHA at hatching time) when known so the
    organism's lineage points at the exact upstream snapshot it was born
    from. Re-running this is a no-op once an identity exists — the egg
    is the only thing that should ever overwrite it.
    """
    os.makedirs(home, exist_ok=True)
    path = _rappid_path(home)
    existing = _read_json(path)
    if existing and existing.get("rappid"):
        return existing

    uid = uuid.uuid4()
    name = _organism_slug()
    # Canonical keyless mint (spec §6.2). A locally-hatched organism is not yet
    # published, so it locates under @local/<name>; launch_to_public re-anchors
    # owner/slug to the real repo (migrate_rappid) while PRESERVING this hash.
    rappid = _mint_rappid_keyless("local", name)
    data = {
        "schema": "rapp/1",
        "rappid": rappid,
        "parent_rappid": SPECIES_ROOT_RAPPID,
        "parent_repo": "github.com/kody-w/RAPP",
        "parent_commit": parent_commit or "",
        "born_at": _now_iso(),
        "kind": "brainstem-instance",
        "name": name,
        "host": _short_host(),
        "platform": platform.system().lower(),
        "incarnations": 1,
        "_legacy_uuid": str(uid),
        "_note": (
            "Locally-hatched digital organism. Identity is preserved across "
            "kernel upgrades by the egg/hatch bonding cycle — the kernel "
            "evolves under the organism, not the other way around."
        ),
    }
    _write_json(path, data)
    return data


def bump_incarnations(home: str) -> int:
    """Increment incarnations counter after a successful bond. Returns new count."""
    path = _rappid_path(home)
    data = _read_json(path)
    if not data:
        return 0
    data["incarnations"] = int(data.get("incarnations", 1)) + 1
    _write_json(path, data)
    return data["incarnations"]


def record_bond(home: str, kind: str,
                from_version: Optional[str] = None,
                to_version: Optional[str] = None,
                from_commit: Optional[str] = None,
                to_commit: Optional[str] = None,
                note: Optional[str] = None) -> dict:
    """Append an event to ~/.brainstem/bonds.json. Returns the event dict.

    Event kinds:
      birth       — fresh install on this machine
      bond        — kernel upgrade-in-place (egg → overlay → hatch)
      adoption    — legacy install detected, identity minted retroactively
      hatch       — egg arrived from another machine and was applied
      graft       — RAPP neighborhood scaffolding was overlaid on an
                    existing public repo (the upstream is the "local
                    mutation"; the RAPP layer is additive). Same bond
                    technique: existing files are preserved; only new
                    files land. The graft event records the upstream
                    commit so the lineage can be reconstructed later.
      launch      — local brainstem snapshot launched as public repo via
                    launch_to_public_agent (the LOCAL→GLOBAL half of the
                    Bond Pulse). Records egg sha256 + target_repo so a
                    cloud AI can resume from raw.githubusercontent.com.
      rhythm      — Bond Pulse heartbeat event (audit drift, classify,
                    suggest direction; the rhythm agent SUGGESTS, never
                    auto-executes). Records drift_count + suggested
                    action count + degraded mode for observability.
    """
    os.makedirs(home, exist_ok=True)
    path = _bonds_path(home)
    data = _read_json(path) or {"events": []}
    if "events" not in data or not isinstance(data["events"], list):
        data["events"] = []
    event = {
        "at": _now_iso(),
        "kind": kind,
        "from_version": from_version or None,
        "to_version": to_version or None,
        "from_commit": from_commit or None,
        "to_commit": to_commit or None,
        "note": note or None,
    }
    data["events"].append(event)
    _write_json(path, data)
    return event


# ── egg / hatch ──────────────────────────────────────────────────────────

def _walk_subtree(src_dir: str, arcname_prefix: str,
                  z: zipfile.ZipFile) -> int:
    """Pack every non-excluded file under src_dir into z at arcname_prefix/."""
    if not os.path.isdir(src_dir):
        return 0
    count = 0
    for root, dirs, files in os.walk(src_dir):
        # prune excluded directories so we never enter them
        dirs[:] = [d for d in dirs if d not in SECRETS_DIRS]
        for fname in files:
            if fname in INFRA_FILES:
                continue
            if fname in SECRETS_FILES:
                continue
            full = os.path.join(root, fname)
            rel = os.path.relpath(full, src_dir).replace(os.sep, "/")
            if _excluded(rel):
                continue
            z.write(full, f"{arcname_prefix}/{rel}")
            count += 1
    return count


def _sanitize_env(env_text: str) -> str:
    """Strip secret values from a .env so the egg is shareable.

    Keys are kept (so the destination knows the shape), but the values
    of anything that smells like a credential are blanked. The user re-
    enters their own credentials on the destination machine.
    """
    out_lines = []
    secret_re = re.compile(
        r"^\s*(?P<k>[A-Z][A-Z0-9_]*(?:TOKEN|KEY|SECRET|PASSWORD|PASS|CREDENTIAL|PAT|API_KEY))\s*=",
        re.IGNORECASE,
    )
    for line in env_text.splitlines():
        if secret_re.match(line):
            key = line.split("=", 1)[0]
            out_lines.append(f"{key}=")
        else:
            out_lines.append(line)
    return "\n".join(out_lines) + ("\n" if env_text.endswith("\n") else "")


def pack_organism(home: str, src: str, kernel_version: str) -> bytes:
    """Pack the full organism into a brainstem-egg/2.2-organism blob.

    The egg captures everything that makes this organism *itself* —
    identity (rappid.json), personality (soul.md), config (.env minus
    secrets), all custom code (agents/organs/senses/services), and all
    accumulated state (.brainstem_data/, minus secrets and private/).
    """
    if not os.path.isdir(src):
        raise FileNotFoundError(f"brainstem src not found: {src}")
    rappid = _read_json(_rappid_path(home)) or {}
    buf = io.BytesIO()
    counts = {"agents": 0, "organs": 0, "senses": 0, "services": 0, "data": 0,
              "soul": 0, "env": 0, "rappid": 0, "lan_tools": 0, "quickstart": 0}

    # LAN federation tools live at <repo-root>/tools/ — one level above brainstem-src.
    # Article XLVII.5.1: every egg ships them so a hatched device can
    # advertise on Bonjour + sniff LAN peers without needing the kody-w/RAPP install.
    tools_src = os.path.join(os.path.dirname(os.path.abspath(src)), "tools")

    with _EggCollector() as z:
        # Identity (always at the root of the egg, so inspectors see it
        # without having to walk a tree)
        if rappid:
            z.writestr("rappid.json", json.dumps(rappid, indent=2))
            counts["rappid"] = 1

        # Soul + .env (sanitized). Both live at brainstem_src root.
        for fname in ORGANISM_TOP_FILES:
            full = os.path.join(src, fname)
            if not os.path.isfile(full):
                continue
            with open(full, "r", encoding="utf-8", errors="replace") as f:
                contents = f.read()
            if fname == ".env":
                contents = _sanitize_env(contents)
            z.writestr(fname, contents)
            counts["soul" if fname == "soul.md" else "env"] = 1

        # Subtrees: agents, organs, senses, services, data
        for arc_prefix, rel_path in ORGANISM_TREES.items():
            counts[arc_prefix] = _walk_subtree(
                os.path.join(src, rel_path), arc_prefix, z
            )

        # LAN federation tools (Article XLVII.5.1) — bundled at tools/<name>
        # inside the egg so a hatched egg works fully local-first. If the
        # tools dir doesn't exist (egg packed from a non-standard layout),
        # gracefully degrade — the egg still works, just without LAN portability.
        if os.path.isdir(tools_src):
            for tool_name in ORGANISM_LAN_FEDERATION_TOOLS:
                tp = os.path.join(tools_src, tool_name)
                if os.path.isfile(tp):
                    with open(tp, "r", encoding="utf-8", errors="replace") as f:
                        z.writestr(f"tools/{tool_name}", f.read())
                    counts["lan_tools"] += 1

        # lan-quickstart.sh — tiny launcher at the egg root so users can
        # `bash lan-quickstart.sh advertise|sniff` after extracting the egg.
        # No Python imports beyond stdlib + the bundled tools/ files.
        if counts["lan_tools"] > 0:
            quickstart = _LAN_QUICKSTART_SCRIPT
            z.writestr("lan-quickstart.sh", quickstart)
            counts["quickstart"] = 1

        manifest = {
            "schema": SCHEMA,
            "type": "organism",
            "exported_at": _now_iso(),
            "kernel_version": kernel_version,
            "host": _short_host(),
            "rappid": rappid.get("rappid"),
            "parent_rappid": rappid.get("parent_rappid"),
            "parent_repo": rappid.get("parent_repo"),
            "incarnations_at_egg": rappid.get("incarnations"),
            "counts": counts,
            "lan_federation_ready": counts["lan_tools"] > 0,  # XLVII.5.1
            "implements": [
                "article-xlvi", "article-xlvi.6",
                "article-xlvii", "article-xlvii.5", "article-xlvii.5.1",
                "article-xlviii",
            ],
        }
        z.writestr("manifest.json", json.dumps(manifest, indent=2))

    return _finalize_egg(z, "organism")


_LAN_QUICKSTART_SCRIPT = """#!/usr/bin/env bash
# lan-quickstart.sh — bundled with every brainstem-egg/2.2-organism.
#
# After extracting the egg, you can advertise this brainstem on the LAN
# (Article XLVII.5.1 Bonjour discovery) or sniff for LAN peers — completely
# local-first, no kody-w/RAPP install required.
#
# WORKS OVER AIRDROP: AirDrop the .egg to anyone with a Mac. They extract,
# run `bash lan-quickstart.sh advertise`, and they're on the LAN federation.
# Even works without shared WiFi (AirDrop uses peer-to-peer Wi-Fi Direct;
# Bonjour discovery rides the same multicast). Genuinely substrate-agnostic.
#
# USAGE:
#   bash lan-quickstart.sh advertise [PORT]
#   bash lan-quickstart.sh sniff [SECONDS]
#   bash lan-quickstart.sh both [PORT]            # advertise in background, then sniff
#   bash lan-quickstart.sh                         # show this help
#
# REQUIREMENTS:
#   - python3 (for tools/* and the HTTP server)
#   - dns-sd (macOS native; on Linux install avahi-utils)
#   - This egg's contents extracted to a directory that contains:
#       tools/lan_advertise.py  tools/sniff_network.py
#       rappid.json  (your operator identity)
#       optional: .well-known/rapp-network.json + estate.json
#
# If you don't have a beacon staged, lan_advertise.py synthesizes one
# from your rappid.json automatically.

set -euo pipefail
EGG_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$EGG_DIR"

# Stage rappid.json + soul.md + .brainstem_data into a fake home so the
# bundled tools see the operator's state via the standard ~/.brainstem path.
# We use a temp dir with a symlinked .brainstem inside it.
BRAINSTEM_HOME="${RAPP_BRAINSTEM_HOME:-$HOME/.brainstem}"
mkdir -p "$BRAINSTEM_HOME"
[ -f "$EGG_DIR/rappid.json" ] && [ ! -f "$BRAINSTEM_HOME/rappid.json" ] && \\
    cp "$EGG_DIR/rappid.json" "$BRAINSTEM_HOME/rappid.json"
[ -d "$EGG_DIR/.well-known" ] && [ ! -d "$BRAINSTEM_HOME/.well-known" ] && \\
    cp -r "$EGG_DIR/.well-known" "$BRAINSTEM_HOME/.well-known"

case "${1:-help}" in
  advertise)
    PORT="${2:-8080}"
    echo "  ▸ advertising this brainstem on _rapp-estate._tcp.local (port $PORT)"
    exec python3 "$EGG_DIR/tools/lan_advertise.py" --port "$PORT"
    ;;
  sniff)
    SECS="${2:-3}"
    echo "  ▸ sniffing LAN for _rapp-estate._tcp peers (browse $SECS sec)"
    exec python3 "$EGG_DIR/tools/sniff_network.py" --via bonjour --bonjour-seconds "$SECS"
    ;;
  both)
    PORT="${2:-8080}"
    echo "  ▸ advertising in background + sniffing"
    python3 "$EGG_DIR/tools/lan_advertise.py" --port "$PORT" >/tmp/lan-advertise.log 2>&1 &
    ADV_PID=$!
    sleep 4
    python3 "$EGG_DIR/tools/sniff_network.py" --via bonjour --bonjour-seconds 5 || true
    kill "$ADV_PID" 2>/dev/null || true
    pkill -f "http.server $PORT" 2>/dev/null || true
    pkill -f "dns-sd -R" 2>/dev/null || true
    ;;
  import-peer)
    EGG="${2:-}"
    if [ -z "$EGG" ]; then
      echo "error: usage: bash lan-quickstart.sh import-peer <path-to-received.egg>"
      exit 2
    fi
    echo "  ▸ importing peer egg $EGG (Article XLVII.5.3 sneakernet federation)"
    python3 "$EGG_DIR/tools/import_peer_egg.py" "$EGG"
    echo ""
    echo "  Now run: bash $0 sniff-via-seed"
    ;;
  sniff-via-seed)
    SEED="${2:-$BRAINSTEM_HOME/network-seed.json}"
    if [ ! -f "$SEED" ]; then
      echo "error: seed file not found: $SEED"
      echo "  Hint: run 'bash $0 import-peer <egg>' first to create one"
      exit 2
    fi
    echo "  ▸ sniffing via local seed (includes sneakernet-imported peers): $SEED"
    exec python3 "$EGG_DIR/tools/sniff_network.py" --via raw --seed-url "file://$SEED"
    ;;
  *)
    echo "Usage: bash lan-quickstart.sh [advertise|sniff|both|import-peer|sniff-via-seed] ..."
    echo ""
    echo "  LAN substrate (Article XLVII.5.1, requires shared LAN + Bonjour):"
    echo "    advertise        Broadcast this brainstem on the LAN via Bonjour"
    echo "    sniff            Discover LAN peers via _rapp-estate._tcp browse"
    echo "    both             advertise in background, then sniff once"
    echo ""
    echo "  Sneakernet substrate (Article XLVII.5.3, NO network required):"
    echo "    import-peer EGG  Add a received egg as a federation hint (file://)"
    echo "    sniff-via-seed   Walk all peers in your local seed file"
    echo ""
    echo "Same JSON shapes, same door_from_rappid(), different substrate."
    echo "Federation walks github raw, LAN HTTP, Bonjour, and file:// — uniformly."
    ;;
esac
"""


# ── rapplication-scope packing ────────────────────────────────────────────
# A rapplication is an organism with smaller scope: one agent (+ its
# optional UI / organ / per-rapp state) instead of a whole brainstem
# instance. Same egg layout as an organism egg, just a tighter include
# set. The unification: rapps and organisms are the same kind of thing
# at different scales (see pages/vault/Architecture/Rapplications Are Organisms.md).

def pack_rapplication(src: str, rapp_id: str,
                      agent_filename: Optional[str] = None,
                      organ_filename: Optional[str] = None,
                      include_state: bool = True,
                      include_ui: bool = True,
                      name: Optional[str] = None,
                      version: str = "0.0.0",
                      publisher: str = "@anon",
                      parent_rappid: Optional[str] = None,
                      soul_filename: Optional[str] = None) -> bytes:
    """Pack a single rapplication into a brainstem-egg/2.2-rapplication blob.

    The egg layout mirrors 2.2-organism but is scoped to ONE rapp:

        rappid.json                              ← rapp identity (minted if missing)
        soul.md                                  ← optional rapp-specific soul
        agents/<agent_filename>                  ← the rapp's primary agent
        organs/<organ_filename>                  ← optional sibling organ
        rapp_ui/<rapp_id>/<...>                  ← skin (UI bundle)
        data/<rapp_id>/<...>                     ← per-rapp state cartridge

    Hatching this onto another brainstem installs the rapplication into
    that host body. The same egg-on-fresh-kernel pattern that works for
    full organisms works for rapps — same protocol, smaller scope.

    Skin matters: a rapplication that ships only an agent (no UI bundle,
    no organ) is functionally a bare agent — should be in RAR not the
    rapplication store. The pack function will warn if `include_ui` is
    True but no UI files are found at <src>/.brainstem_data/rapp_ui/<rapp_id>/.
    """
    if not os.path.isdir(src):
        raise FileNotFoundError(f"brainstem src not found: {src}")

    # Rapp-scope identity (canonical spec §6.1). The rappid is minted ONCE
    # (keyless, spec §6.2) and PERSISTED next to the rapp's state so re-packs
    # reuse the SAME identity — never re-derived from the name (a name-hash is
    # the cardinal-sin identity forbidden by the spec). Location @<pub>/<rapp_id>.
    _rapp_id_home = os.path.join(src, ".brainstem_data", rapp_id, "rappid.json")
    _existing = _read_json(_rapp_id_home)
    if _existing and isinstance(_existing.get("rappid"), str) \
            and _existing["rappid"].startswith("rappid:@"):
        rapp_rappid = _existing["rappid"]
    else:
        rapp_rappid = _mint_rappid_keyless(publisher.lstrip("@"), rapp_id)
        try:
            os.makedirs(os.path.dirname(_rapp_id_home), exist_ok=True)
            _write_json(_rapp_id_home, {"schema": "rapp/1",
                                        "rappid": rapp_rappid, "kind": "rapplication",
                                        "rapp_id": rapp_id, "publisher": publisher})
        except OSError:
            pass  # read-only src — identity still travels in the egg's rappid.json

    counts = {"agent": 0, "organ": 0, "ui": 0, "data": 0, "soul": 0}
    buf = io.BytesIO()

    with _EggCollector() as z:
        # Identity
        identity = {
            "schema": "rapp/1",
            "rappid": rapp_rappid,
            "parent_rappid": parent_rappid or SPECIES_ROOT_RAPPID,
            "kind": "rapplication",
            "name": name or rapp_id,
            "version": version,
            "publisher": publisher,
            "rapp_id": rapp_id,
            "born_at": _now_iso(),
        }
        z.writestr("rappid.json", json.dumps(identity, indent=2))

        # Optional rapp-specific soul (the rapp's own personality if it has one)
        if soul_filename:
            soul_path = os.path.join(src, soul_filename)
            if os.path.isfile(soul_path):
                with open(soul_path, "r", encoding="utf-8", errors="replace") as f:
                    z.writestr("soul.md", f.read())
                counts["soul"] = 1

        # The rapp's primary agent
        if agent_filename:
            ap = os.path.join(src, "agents", agent_filename)
            if os.path.isfile(ap):
                with open(ap, "rb") as f:
                    z.writestr(f"agents/{agent_filename}", f.read())
                counts["agent"] = 1

        # Optional sibling organ
        if organ_filename:
            op = os.path.join(src, "utils", "organs", organ_filename)
            if os.path.isfile(op):
                with open(op, "rb") as f:
                    z.writestr(f"organs/{organ_filename}", f.read())
                counts["organ"] = 1

        # Skin — the UI bundle. The line that earns the rapplication tier.
        if include_ui:
            ui_dir = os.path.join(src, ".brainstem_data", "rapp_ui", rapp_id)
            if os.path.isdir(ui_dir):
                counts["ui"] = _walk_subtree(ui_dir, f"rapp_ui/{rapp_id}", z)

        # Per-rapp state cartridge
        if include_state:
            state_dir = os.path.join(src, ".brainstem_data", rapp_id)
            if os.path.isdir(state_dir):
                counts["data"] = _walk_subtree(state_dir, f"data/{rapp_id}", z)

        manifest = {
            "schema": SCHEMA_RAPP,
            "type": "rapplication",
            "exported_at": _now_iso(),
            "rappid": rapp_rappid,
            "rapp_id": rapp_id,
            "name": name or rapp_id,
            "version": version,
            "publisher": publisher,
            "host": _short_host(),
            "agent_filename": agent_filename,
            "organ_filename": organ_filename,
            "has_skin": counts["ui"] > 0,
            "counts": counts,
        }
        z.writestr("manifest.json", json.dumps(manifest, indent=2))

    return _finalize_egg(z, "rapplication")


def unpack_rapplication(blob: bytes, src: str,
                        overwrite_state: bool = False) -> dict:
    """Hatch a brainstem-egg/2.2-rapplication blob into a host brainstem.

    Maps egg paths to host destinations:
        agents/<f>            → <src>/agents/<f>
        organs/<f>            → <src>/utils/organs/<f>
        rapp_ui/<rapp>/<...>  → <src>/.brainstem_data/rapp_ui/<rapp>/<...>
        data/<rapp>/<...>     → <src>/.brainstem_data/<rapp>/<...>
        soul.md               → <src>/.brainstem_data/<rapp>/soul.md
                                (rapp soul lands UNDER the rapp's data
                                dir so it doesn't clobber the host soul)
        rappid.json           → <src>/.brainstem_data/<rapp>/rappid.json
                                (per-rapp identity registered in the
                                host's rapp registry, not at workspace root)

    Hatching does NOT touch the host's identity (~/.brainstem/rappid.json).
    The host stays the host; the rapp becomes a guest organism inside it.

    `overwrite_state` controls whether existing per-rapp state is replaced
    on conflict. Default False (merge — preserve any local edits).
    """
    if not blob[:4] == b"PK\x03\x04":
        raise ValueError("not a zip / egg blob")
    os.makedirs(src, exist_ok=True)

    try:
        zf = zipfile.ZipFile(io.BytesIO(blob))
    except zipfile.BadZipFile as e:
        raise ValueError(f"corrupt or truncated egg: {e}")

    with zf as z:
        try:
            manifest = json.loads(z.read("manifest.json"))
        except Exception as e:
            raise ValueError(f"egg has no readable manifest.json: {e}")

        if manifest.get("schema") != EGG_SCHEMA or manifest.get("variant") != "rapplication":
            raise ValueError(
                f"not a rapp/1-egg rapplication (schema={manifest.get('schema')!r}, "
                f"variant={manifest.get('variant')!r}). Use unpack_organism for organism eggs."
            )

        rapp_id = manifest.get("rapp_id") or "unknown_rapp"
        restored = {"agent": 0, "organ": 0, "ui": 0, "data": 0,
                    "soul": 0, "rappid": 0, "skipped": 0}
        errors: list = []

        rapp_data_dir = os.path.join(src, ".brainstem_data", rapp_id)

        for name in z.namelist():
            if name == "manifest.json" or name.endswith("/"):
                continue

            # rappid.json + soul.md → rapp's data dir
            if name == "rappid.json":
                target = os.path.join(rapp_data_dir, "rappid.json")
                _safe_extract(z, name, target, errors)
                restored["rappid"] += 1
                continue
            if name == "soul.md":
                target = os.path.join(rapp_data_dir, "soul.md")
                _safe_extract(z, name, target, errors)
                restored["soul"] += 1
                continue

            # Subtree dispatch
            dispatch = (
                ("agents/",  os.path.join(src, "agents"),               "agent"),
                ("organs/",  os.path.join(src, "utils", "organs"),      "organ"),
                ("rapp_ui/", os.path.join(src, ".brainstem_data", "rapp_ui"), "ui"),
                ("data/",    os.path.join(src, ".brainstem_data"),      "data"),
            )
            matched = False
            for prefix, dest_root, key in dispatch:
                if not name.startswith(prefix):
                    continue
                rel = name[len(prefix):]
                if _excluded(rel):
                    restored["skipped"] += 1
                    matched = True
                    break
                target = os.path.normpath(os.path.join(dest_root, rel))
                if not target.startswith(os.path.normpath(dest_root) + os.sep):
                    errors.append(f"path-traversal blocked: {name}")
                    matched = True
                    break
                # Merge semantics for state — skip if exists and not overwriting
                if key == "data" and os.path.exists(target) and not overwrite_state:
                    restored["skipped"] += 1
                    matched = True
                    break
                _safe_extract(z, name, target, errors)
                restored[key] += 1
                matched = True
                break

            if not matched:
                restored["skipped"] += 1

        return {"ok": not errors, "restored": restored, "errors": errors,
                "manifest": manifest, "rapp_id": rapp_id}


def unpack_organism(blob: bytes, home: str, src: str,
                    overwrite_rappid: bool = True) -> dict:
    """Hatch a brainstem-egg/2.2-organism blob over a local kernel.

    Hatch semantics (egg = source of truth for the organism):
      - rappid.json:   egg wins (overwrite_rappid=True). The hatched
                       brainstem ADOPTS the egg's identity. This is what
                       lets the same organism continue on a new machine.
      - soul.md:       egg wins, written to brainstem_src/soul.md.
      - .env:          egg wins ONLY if no local .env exists. Otherwise
                       the local one is preserved — the egg's .env is
                       sanitized for portability (secrets stripped) and
                       must never clobber a working local .env. This is
                       the bond-on-same-machine guarantee: kernel
                       upgrades never wipe credentials.
      - agents/<f>:    egg wins, written to brainstem_src/agents/<f>.
      - organs/<f>:    egg wins, written to brainstem_src/utils/organs/<f>.
      - senses/<f>:    egg wins, written to brainstem_src/utils/senses/<f>.
      - services/<f>:  egg wins, written to brainstem_src/utils/services/<f>.
      - data/<...>:    egg wins on file conflict; new kernel files (e.g.
                       data files the egg doesn't know about) stay put.

    Hatch is purely additive on the kernel side: any file in the
    destination tree that isn't named in the egg is left alone.
    """
    if not blob[:4] == b"PK\x03\x04":
        raise ValueError("not a zip / egg blob")
    os.makedirs(home, exist_ok=True)
    os.makedirs(src, exist_ok=True)

    restored = {"rappid": 0, "soul": 0, "env": 0,
                "agents": 0, "organs": 0, "senses": 0, "services": 0,
                "data": 0, "skipped": 0}
    errors = []

    with zipfile.ZipFile(io.BytesIO(blob)) as z:
        try:
            manifest = json.loads(z.read("manifest.json"))
        except Exception as e:
            raise ValueError(f"egg has no readable manifest.json: {e}")

        schema = manifest.get("schema", "")
        if schema != EGG_SCHEMA or manifest.get("variant") != "organism":
            raise ValueError(
                f"unsupported egg schema {schema!r} (expected {SCHEMA}). "
                f"Use a newer brainstem to hatch this egg, or open it in rappzoo."
            )

        # Destination map for subtrees
        SUBTREE_DEST = {
            "agents/":   os.path.join(src, "agents"),
            "organs/":   os.path.join(src, "utils", "organs"),
            "senses/":   os.path.join(src, "utils", "senses"),
            "services/": os.path.join(src, "utils", "services"),
            "data/":     os.path.join(src, ".brainstem_data"),
        }

        for name in z.namelist():
            if name == "manifest.json" or name.endswith("/"):
                continue

            # Identity (egg's rappid wins by default)
            if name == "rappid.json":
                if overwrite_rappid:
                    z.extract(name, home)  # writes rappid.json into home
                    restored["rappid"] += 1
                else:
                    restored["skipped"] += 1
                continue

            # Top-level organism files (soul.md, .env)
            if name in ORGANISM_TOP_FILES:
                target = os.path.join(src, name)
                # .env is sanitized in the egg — never clobber a real
                # local .env that has working credentials. The egg's .env
                # only lands when the destination has no .env yet (e.g.
                # first hatch on a fresh machine).
                if name == ".env" and os.path.exists(target):
                    restored["skipped"] += 1
                    continue
                _safe_extract(z, name, target, errors)
                restored["soul" if name == "soul.md" else "env"] += 1
                continue

            # Subtree dispatch
            matched = False
            for prefix, dest_root in SUBTREE_DEST.items():
                if not name.startswith(prefix):
                    continue
                rel = name[len(prefix):]
                if _excluded(rel):
                    restored["skipped"] += 1
                    matched = True
                    break
                # Path-traversal guard
                target = os.path.normpath(os.path.join(dest_root, rel))
                if not target.startswith(os.path.normpath(dest_root) + os.sep):
                    errors.append(f"path-traversal blocked: {name}")
                    matched = True
                    break
                _safe_extract(z, name, target, errors)
                key = prefix.rstrip("/")
                restored[key] += 1
                matched = True
                break

            if not matched:
                # Unknown top-level entry — preserve forward-compatibility
                # with future schemas, just count it as skipped.
                restored["skipped"] += 1

    return {"ok": not errors, "restored": restored, "errors": errors,
            "manifest": manifest}


def _safe_extract(z: zipfile.ZipFile, name: str, target: str,
                  errors: list) -> None:
    try:
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with z.open(name) as src, open(target, "wb") as dst:
            dst.write(src.read())
    except OSError as e:
        errors.append(f"{name}: {e}")


def inspect_egg(blob: bytes) -> dict:
    """Read a manifest without unpacking. Returns the manifest dict."""
    if not blob[:4] == b"PK\x03\x04":
        raise ValueError("not a zip / egg blob")
    with zipfile.ZipFile(io.BytesIO(blob)) as z:
        return json.loads(z.read("manifest.json"))


# ── CLI ──────────────────────────────────────────────────────────────────

def _cmd_mint(args):
    data = mint_rappid(args.home, parent_commit=args.parent_commit)
    print(json.dumps({"rappid": data.get("rappid"),
                      "born_at": data.get("born_at"),
                      "incarnations": data.get("incarnations")},
                     indent=2))


def _cmd_egg(args):
    blob = pack_organism(args.home, args.src, args.kernel_version)
    with open(args.output, "wb") as f:
        f.write(blob)
    size_kb = round(len(blob) / 1024, 1)
    print(json.dumps({"egg": args.output,
                      "size_kb": size_kb,
                      "kernel_version": args.kernel_version}, indent=2))


def _cmd_hatch(args):
    with open(args.egg, "rb") as f:
        blob = f.read()
    # Schema dispatch — organism eggs and rapplication eggs use different
    # unpackers. Read the manifest and route accordingly.
    manifest = inspect_egg(blob)
    variant = manifest.get("variant") or ("rapplication" if manifest.get("schema")==SCHEMA_RAPP else "organism")
    if variant == "rapplication":
        result = unpack_rapplication(blob, args.src,
                                     overwrite_state=getattr(args, 'overwrite_state', False))
    elif variant == "organism":
        result = unpack_organism(blob, args.home, args.src,
                                 overwrite_rappid=not args.preserve_rappid)
    else:
        result = {"ok": False, "errors": [f"unsupported schema: {schema!r}"]}
    print(json.dumps(result, indent=2))
    if not result.get("ok"):
        sys.exit(1)


def _cmd_pack_rapp(args):
    blob = pack_rapplication(
        args.src, args.rapp_id,
        agent_filename=args.agent,
        organ_filename=args.organ,
        include_state=not args.no_state,
        include_ui=not args.no_ui,
        name=args.name,
        version=args.version,
        publisher=args.publisher,
        soul_filename=args.soul,
    )
    with open(args.output, "wb") as f:
        f.write(blob)
    print(json.dumps({
        "egg": args.output,
        "size_kb": round(len(blob) / 1024, 1),
        "rappid": inspect_egg(blob).get("rappid"),
    }, indent=2))


def _cmd_record_bond(args):
    event = record_bond(args.home, args.kind,
                        from_version=args.from_version,
                        to_version=args.to_version,
                        from_commit=args.from_commit,
                        to_commit=args.to_commit,
                        note=args.note)
    print(json.dumps(event, indent=2))


def _cmd_bump(args):
    n = bump_incarnations(args.home)
    print(json.dumps({"incarnations": n}, indent=2))


def _cmd_inspect(args):
    with open(args.egg, "rb") as f:
        blob = f.read()
    print(json.dumps(inspect_egg(blob), indent=2))


def main(argv=None):
    p = argparse.ArgumentParser(prog="bond")
    sub = p.add_subparsers(dest="cmd", required=True)

    m = sub.add_parser("mint-rappid", help="Mint ~/.brainstem/rappid.json if missing")
    m.add_argument("home")
    m.add_argument("--parent-commit", default=None)
    m.set_defaults(func=_cmd_mint)

    e = sub.add_parser("egg", help="Pack the organism into a portable .egg")
    e.add_argument("home")
    e.add_argument("output")
    e.add_argument("--kernel-version", required=True)
    e.add_argument("--src", default=None,
                   help="brainstem src dir (default: <home>/src/rapp_brainstem)")
    e.set_defaults(func=lambda a: _cmd_egg(_with_src(a)))

    h = sub.add_parser("hatch", help="Hatch a .egg over the local kernel (auto-detects schema)")
    h.add_argument("home")
    h.add_argument("egg")
    h.add_argument("--src", default=None)
    h.add_argument("--preserve-rappid", action="store_true",
                   help="(organism eggs) Keep the local rappid.json instead of adopting the egg's")
    h.add_argument("--overwrite-state", action="store_true",
                   help="(rapplication eggs) Replace existing per-rapp state on conflict")
    h.set_defaults(func=lambda a: _cmd_hatch(_with_src(a)))

    pr = sub.add_parser("pack-rapp", help="Pack one rapplication into a 2.2-rapplication egg")
    pr.add_argument("src", help="brainstem src dir (e.g. ~/.brainstem/src/rapp_brainstem)")
    pr.add_argument("rapp_id", help="The rapp's id — also the dir name under .brainstem_data/rapp_ui/")
    pr.add_argument("output", help="Output .egg path")
    pr.add_argument("--agent", default=None, help="Filename under agents/ (e.g. bookfactory_agent.py)")
    pr.add_argument("--organ", default=None, help="Optional filename under utils/organs/")
    pr.add_argument("--soul", default=None, help="Optional rapp-specific soul.md path (relative to src)")
    pr.add_argument("--name", default=None)
    pr.add_argument("--version", default="0.0.0")
    pr.add_argument("--publisher", default="@anon")
    pr.add_argument("--no-state", action="store_true", help="Skip the per-rapp state cartridge")
    pr.add_argument("--no-ui", action="store_true", help="Skip the UI bundle")
    pr.set_defaults(func=_cmd_pack_rapp)

    rb = sub.add_parser("record-bond", help="Append an event to bonds.json")
    rb.add_argument("home")
    rb.add_argument("kind", choices=["birth", "bond", "adoption", "hatch", "graft", "launch", "rhythm"])
    rb.add_argument("--from-version", default=None)
    rb.add_argument("--to-version", default=None)
    rb.add_argument("--from-commit", default=None)
    rb.add_argument("--to-commit", default=None)
    rb.add_argument("--note", default=None)
    rb.set_defaults(func=_cmd_record_bond)

    b = sub.add_parser("bump-incarnations",
                       help="Increment incarnations counter in rappid.json")
    b.add_argument("home")
    b.set_defaults(func=_cmd_bump)

    i = sub.add_parser("inspect", help="Print an egg's manifest without unpacking")
    i.add_argument("egg")
    i.set_defaults(func=_cmd_inspect)

    args = p.parse_args(argv)
    args.func(args)


def _with_src(args):
    if args.src is None:
        args.src = os.path.join(args.home, "src", "rapp_brainstem")
    return args


if __name__ == "__main__":
    main()
