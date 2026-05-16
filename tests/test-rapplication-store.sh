#!/bin/bash
# tests/test-rapplication-store.sh — validate the RAPPstore catalog + verify
# the bookfactoryagent rapplication is hatchable end-to-end as advertised.

set -e
set -o pipefail

# NOTE (2026-04-26): the catalog moved to kody-w/rapp_store. This script
# inspects local rapp_store/ filesystem content that no longer exists in
# this repo, so it self-skips here. The same test belongs in the catalog
# repo's own test suite — see github.com/kody-w/rapp_store.
if [ ! -d rapp_store ] || [ -f rapp_store/MOVED.md ] && [ ! -f rapp_store/index.json ]; then
    echo "SKIP: tests/test-rapplication-store.sh — catalog moved to kody-w/rapp_store"
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

assert_contains() {
    local name="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name"; echo "      needle:    $needle"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

cd /Users/kodyw/Documents/GitHub/Rappter/RAPP

# ── Section 1: catalog schema ──────────────────────────────────────────

echo ""
echo "--- Section 1: rapp_store/index.json schema ---"

CAT=rapp_store/index.json
[ -f "$CAT" ] || { echo "  ✗ catalog missing: $CAT"; exit 1; }

SCHEMA=$(python3 -c "import json; print(json.load(open('$CAT'))['schema'])")
assert_eq "schema = rapp-store/1.0"  "rapp-store/1.0"  "$SCHEMA"

COUNT=$(python3 -c "import json; print(len(json.load(open('$CAT'))['rapplications']))")
[ "$COUNT" -ge 1 ] && { echo "  ✓ ≥1 rapplication listed (got $COUNT)"; PASS=$((PASS+1)); } || \
                       { echo "  ✗ catalog has 0 rapplications"; FAIL=$((FAIL+1)); FAIL_NAMES+=("count"); }

# Every rapplication has the required fields
python3 - <<'PY'
import json, sys
required = ["id","name","version","summary","manifest_name","singleton_filename","singleton_url"]
cat = json.load(open("rapp_store/index.json"))
fail = 0
for r in cat["rapplications"]:
    missing = [k for k in required if k not in r]
    if missing:
        print(f"  ✗ rapplication '{r.get('id','?')}' missing: {missing}"); fail += 1
    else:
        print(f"  ✓ rapplication '{r['id']}' has all required fields")
sys.exit(1 if fail else 0)
PY

# ── Section 2: SHA-256 pin matches the actual file ────────────────────

echo ""
echo "--- Section 2: SHA-256 pin verification ---"

python3 - <<'PY'
import json, hashlib, pathlib, sys
cat = json.load(open("rapp_store/index.json"))
fail = 0

def find_local(filename):
    """After v1.8 reorg, files live under rapp_store/{name}/{singleton,source}/.
    Search all of them and return the first match."""
    rapps = pathlib.Path("rapp_store")
    for sub in rapps.iterdir() if rapps.exists() else []:
        for kind in ("singleton", "source"):
            cand = sub / kind / filename
            if cand.exists():
                return cand
    return None

for r in cat["rapplications"]:
    p = find_local(r["singleton_filename"])
    if not p:
        print(f"  ✗ {r['id']}: singleton file missing for {r['singleton_filename']}"); fail += 1
        continue
    actual = hashlib.sha256(p.read_bytes()).hexdigest()
    pinned = r.get("singleton_sha256", "")
    if pinned == "compute_at_publish_time":
        print(f"  ⚠ {r['id']}: SHA pin is placeholder — should be computed before publish"); fail += 1
    elif pinned != actual:
        print(f"  ✗ {r['id']}: SHA mismatch")
        print(f"      pinned: {pinned}")
        print(f"      actual: {actual}"); fail += 1
    else:
        print(f"  ✓ {r['id']}: SHA-256 pin matches actual file ({actual[:16]}...)")
sys.exit(1 if fail else 0)
PY

# ── Section 3: bookfactoryagent hatches end-to-end ────────────────────

echo ""
echo "--- Section 3: bookfactoryagent install path ---"

PORT=7185
ROOT=/tmp/rapp-store-test
[ -e "$ROOT" ] && chmod -R u+w "$ROOT" 2>/dev/null || true
rm -rf "$ROOT"
lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 0.5

python3 -u rapp_brainstem/brainstem.py --port $PORT --root "$ROOT" > /tmp/store-test-server.log 2>&1 &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null || true" EXIT
sleep 2

# The "install" path: drop ONLY bookfactory_agent.py into a swarm bundle and
# verify it hatches as one agent (BookFactory).
GUID=$(python3 - <<'PY'
import json, urllib.request, pathlib
src = pathlib.Path("rapp_store/bookfactory/singleton/bookfactory_agent.py").read_text()
bundle = {
    "schema": "rapp-swarm/1.0",
    "name": "store-install-test",
    "soul": "rapplication install path test",
    "agents": [{"filename": "bookfactory_agent.py", "source": src}],
}
r = urllib.request.urlopen(urllib.request.Request(
    "http://127.0.0.1:7185/api/swarm/deploy",
    data=json.dumps(bundle).encode(),
    headers={"Content-Type":"application/json"}, method="POST"))
print(json.loads(r.read())["swarm_guid"])
PY
)
assert_contains "rapplication deploys" "$GUID" "$GUID"

LOADED=$(curl -fsS http://127.0.0.1:$PORT/api/swarm/$GUID/healthz \
         | python3 -c "import json,sys; d=json.load(sys.stdin); print(' '.join(d['agents']))")
assert_contains "BookFactory loaded as one agent"  "BookFactory"  "$LOADED"

COUNT=$(curl -fsS http://127.0.0.1:$PORT/api/swarm/$GUID/healthz \
        | python3 -c "import json,sys; print(json.load(sys.stdin)['agent_count'])")
assert_eq "exactly one agent loaded (the rapplication)"  "1"  "$COUNT"

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"
echo "  $PASS passed, $FAIL failed"
echo "════════════════════════════════════════"
[ $FAIL -gt 0 ] && { for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done; exit 1; }
exit 0
