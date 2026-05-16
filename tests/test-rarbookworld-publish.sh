#!/bin/bash
# tests/test-rarbookworld-publish.sh — verify @rarbookworld publish to BOTH:
#   1. RAR repo at agents/@rarbookworld/<slug>.py with valid RAR manifests
#   2. RAPP rapp_store/index.json with publisher: @rarbookworld entries

set -e
set -o pipefail

# NOTE (2026-04-26): the catalog moved to kody-w/rapp_store. This script
# inspects local rapp_store/ filesystem content that no longer exists in
# this repo, so it self-skips here. The same test belongs in the catalog
# repo's own test suite — see github.com/kody-w/rapp_store.
if [ ! -d rapp_store ] || [ -f rapp_store/MOVED.md ] && [ ! -f rapp_store/index.json ]; then
    echo "SKIP: tests/test-rarbookworld-publish.sh — catalog moved to kody-w/rapp_store"
    exit 0
fi

PASS=0; FAIL=0; FAIL_NAMES=()

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name"; echo "      expected: $expected"; echo "      actual:   $actual"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

assert_ge() {
    local name="$1" min="$2" actual="$3"
    if [ "$actual" -ge "$min" ]; then
        echo "  ✓ $name (got $actual ≥ $min)"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name (got $actual < $min)"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

cd /Users/kodyw/Documents/GitHub/Rappter/RAPP

RAR=/Users/kodyw/Documents/GitHub/Rappter/RAR
DEST=$RAR/agents/@rarbookworld

# ── Section 1: publisher tool ran and produced output ─────────────────

echo ""
echo "--- Section 1: @rarbookworld publish artifacts ---"

[ -d "$DEST" ] || { echo "  ✗ $DEST does not exist — run tools/publish-bookfactory-to-rar.py"; exit 1; }
echo "  ✓ $DEST exists"; PASS=$((PASS + 1))

COUNT=$(ls "$DEST"/*.py 2>/dev/null | wc -l | tr -d ' ')
assert_ge "≥14 agent.py files published" 14 "$COUNT"

# ── Section 2: every file has a valid RAR-compliant manifest ──────────

echo ""
echo "--- Section 2: RAR manifest validation ---"

python3 - <<'PY'
import ast, json, sys
from pathlib import Path

DEST = Path("/Users/kodyw/Documents/GitHub/Rappter/RAR/agents/@rarbookworld")
REQUIRED = ["schema", "name", "version", "display_name", "description",
            "author", "tags", "category"]

fail = 0
for f in sorted(DEST.glob("*.py")):
    src = f.read_text()
    try:
        tree = ast.parse(src)
    except SyntaxError as e:
        print(f"  ✗ {f.name}: syntax error: {e}"); fail += 1; continue

    manifest = None
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for t in node.targets:
                if isinstance(t, ast.Name) and t.id == "__manifest__":
                    manifest = ast.literal_eval(node.value)
    if not manifest:
        print(f"  ✗ {f.name}: no __manifest__ found"); fail += 1; continue

    missing = [k for k in REQUIRED if k not in manifest]
    if missing:
        print(f"  ✗ {f.name}: missing fields {missing}"); fail += 1; continue

    name = manifest["name"]
    if not name.startswith("@rarbookworld/"):
        print(f"  ✗ {f.name}: name '{name}' is not under @rarbookworld/"); fail += 1; continue

    version = manifest["version"]
    parts = version.split(".")
    if len(parts) != 3 or not all(p.isdigit() for p in parts):
        print(f"  ✗ {f.name}: invalid semver '{version}'"); fail += 1; continue

    print(f"  ✓ {f.name}: {name} v{version}")

sys.exit(1 if fail else 0)
PY

# ── Section 3: every file is import-clean (parses + can be loaded) ────

echo ""
echo "--- Section 3: file is loadable ---"

python3 - <<'PY'
import importlib.util, sys, traceback
from pathlib import Path

DEST = Path("/Users/kodyw/Documents/GitHub/Rappter/RAR/agents/@rarbookworld")

# Make the @rarbookworld dir importable so sibling imports resolve
sys.path.insert(0, str(DEST))
# Also make RAPP agents/ available so the BasicAgent fallback works
sys.path.insert(0, "/Users/kodyw/Documents/GitHub/Rappter/RAPP")

fail = 0
for f in sorted(DEST.glob("*.py")):
    try:
        spec = importlib.util.spec_from_file_location(f.stem, f)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        print(f"  ✓ {f.name} loads cleanly")
    except Exception as e:
        print(f"  ✗ {f.name}: {type(e).__name__}: {e}"); fail += 1

sys.exit(1 if fail else 0)
PY

# ── Section 4: RAPP rapp_store/index.json has the @rarbookworld entries ────

echo ""
echo "--- Section 4: RAPP rapp_store/index.json @rarbookworld coverage ---"

python3 - <<'PY'
import json, sys
cat = json.load(open("rapp_store/index.json"))
rb = [r for r in cat["rapplications"] if r.get("publisher") == "@rarbookworld"]
print(f"  total rapplications: {len(cat['rapplications'])}")
print(f"  @rarbookworld entries: {len(rb)}")
if len(rb) < 2:
    print(f"  ✗ expected ≥2 @rarbookworld entries (singleton + components)"); sys.exit(1)
for r in rb[:5]:
    print(f"    - {r['id']}: {r['manifest_name']}")
print(f"  ✓ @rarbookworld publisher is recorded in catalog")
PY

# ── Section 5: SHA-256 pins in catalog match actual RAPP files ────────

echo ""
echo "--- Section 5: catalog SHA-256 still verifies ---"

python3 - <<'PY'
import json, hashlib, pathlib, sys
cat = json.load(open("rapp_store/index.json"))
fail = 0
checked = 0
for r in cat["rapplications"]:
    fn = "agents/" + r["singleton_filename"]
    p = pathlib.Path(fn)
    if not p.exists():
        continue  # some catalog entries may point to RAR raw, not RAPP
    actual = hashlib.sha256(p.read_bytes()).hexdigest()
    pinned = r.get("singleton_sha256", "")
    if pinned and pinned != actual and pinned != "compute_at_publish_time":
        print(f"  ✗ {r['id']}: SHA mismatch"); fail += 1
    else:
        checked += 1
print(f"  ✓ {checked} entries verified")
sys.exit(1 if fail else 0)
PY

# ── Section 6: end-to-end — bookfactory_agent.py still hatches as 1 agent ─

echo ""
echo "--- Section 6: bookfactory_agent singleton still hatches in RAPP brainstem ---"

PORT=7186
ROOT=/tmp/rapp-rarbookworld-test
[ -e "$ROOT" ] && chmod -R u+w "$ROOT" 2>/dev/null || true
rm -rf "$ROOT"
lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 0.5

python3 -u rapp_brainstem/brainstem.py --port $PORT --root "$ROOT" > /tmp/rarbookworld-test-server.log 2>&1 &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null || true" EXIT
sleep 2

GUID=$(python3 - <<PY
import json, urllib.request, pathlib
src = pathlib.Path("rapp_store/bookfactory/singleton/bookfactory_agent.py").read_text()
bundle = {
    "schema": "rapp-swarm/1.0",
    "name": "rarbookworld-singleton-test",
    "soul": "verify @rarbookworld singleton hatch",
    "agents": [{"filename": "bookfactory_agent.py", "source": src}],
}
r = urllib.request.urlopen(urllib.request.Request(
    "http://127.0.0.1:$PORT/api/swarm/deploy",
    data=json.dumps(bundle).encode(),
    headers={"Content-Type":"application/json"}, method="POST"))
print(json.loads(r.read())["swarm_guid"])
PY
)
[ -n "$GUID" ] && { echo "  ✓ rapplication deploys: $GUID"; PASS=$((PASS+1)); } || \
                  { echo "  ✗ deploy failed"; FAIL=$((FAIL+1)); FAIL_NAMES+=("deploy"); }

LOADED=$(curl -fsS http://127.0.0.1:$PORT/api/swarm/$GUID/healthz \
         | python3 -c "import json,sys; d=json.load(sys.stdin); print(' '.join(d['agents']))")
case "$LOADED" in
    *BookFactory*) echo "  ✓ BookFactory loaded as one agent"; PASS=$((PASS+1)) ;;
    *) echo "  ✗ BookFactory not in loaded agents: $LOADED"; FAIL=$((FAIL+1)); FAIL_NAMES+=("BookFactory load") ;;
esac

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"
echo "  $PASS passed, $FAIL failed"
echo "════════════════════════════════════════"
[ $FAIL -gt 0 ] && { for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done; exit 1; }
exit 0
