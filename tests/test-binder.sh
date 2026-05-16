#!/bin/bash
# tests/test-binder.sh — verify the brainstem's baked-in /api/binder API
# end-to-end. Install momentfactoryagent into a temp twin, verify materialization,
# verify execution via /api/binder/agent, verify uninstall, verify sync.

set -e
set -o pipefail

# NOTE (2026-04-26): the catalog moved to kody-w/rapp_store. This script
# inspects local rapp_store/ filesystem content that no longer exists in
# this repo, so it self-skips here. The same test belongs in the catalog
# repo's own test suite — see github.com/kody-w/rapp_store.
if [ ! -d rapp_store ] || [ -f rapp_store/MOVED.md ] && [ ! -f rapp_store/index.json ]; then
    echo "SKIP: tests/test-binder.sh — catalog moved to kody-w/rapp_store"
    exit 0
fi

PASS=0; FAIL=0; FAIL_NAMES=()

assert_eq()   { local n="$1" e="$2" a="$3"
  [ "$e" = "$a" ] && { echo "  ✓ $n"; PASS=$((PASS+1)); } || \
                     { echo "  ✗ $n"; echo "    expected: $e"; echo "    actual:   $a"; FAIL=$((FAIL+1)); FAIL_NAMES+=("$n"); }
}
assert_contains() { local n="$1" needle="$2" hay="$3"
  echo "$hay" | grep -qF "$needle" && { echo "  ✓ $n"; PASS=$((PASS+1)); } || \
                                       { echo "  ✗ $n: needle '$needle' missing"; FAIL=$((FAIL+1)); FAIL_NAMES+=("$n"); }
}

cd /Users/kodyw/Documents/GitHub/Rappter/RAPP

PORT=7191
ROOT=/tmp/rapp-binder-test
[ -e "$ROOT" ] && chmod -R u+w "$ROOT" 2>/dev/null || true
rm -rf "$ROOT"
lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 0.3

python3 -u rapp_brainstem/brainstem.py --port $PORT --root "$ROOT" > /tmp/binder-test-server.log 2>&1 &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null || true" EXIT
sleep 2

# ── Section 1: empty binder ────────────────────────────────────────────

echo ""
echo "--- Section 1: empty binder on a fresh twin ---"

INIT=$(curl -fsS http://127.0.0.1:$PORT/api/binder)
assert_contains "binder schema is rapp-binder/1.0"  '"schema": "rapp-binder/1.0"'  "$INIT"
assert_contains "installed list starts empty"        '"installed": []'              "$INIT"

# ── Section 2: catalog proxy ────────────────────────────────────────────

echo ""
echo "--- Section 2: catalog proxy ---"

CAT=$(curl -fsS http://127.0.0.1:$PORT/api/binder/catalog)
assert_contains "catalog has rapp-store schema" '"schema": "rapp-store/1.0"' "$CAT"
assert_contains "catalog lists momentfactoryagent" '"id": "momentfactoryagent"' "$CAT"
assert_contains "catalog lists bookfactoryagent"   '"id": "bookfactoryagent"'   "$CAT"

# ── Section 3: install momentfactoryagent ─────────────────────────────

echo ""
echo "--- Section 3: install momentfactoryagent ---"

INSTALL=$(curl -fsS -X POST http://127.0.0.1:$PORT/api/binder/install \
    -H "Content-Type: application/json" \
    -d '{"id": "momentfactoryagent"}')
assert_contains "install succeeded" '"status": "ok"' "$INSTALL"
assert_contains "install reports id" '"id": "momentfactoryagent"' "$INSTALL"

# Verify materialization: <root>/agents/momentfactory_agent.py exists
[ -f "$ROOT/agents/momentfactory_agent.py" ] && \
    { echo "  ✓ singleton materialized to $ROOT/agents/momentfactory_agent.py"; PASS=$((PASS+1)); } || \
    { echo "  ✗ singleton NOT materialized"; FAIL=$((FAIL+1)); FAIL_NAMES+=("materialize"); }

# Verify .binder.json updated
[ -f "$ROOT/.binder.json" ] && \
    { echo "  ✓ .binder.json written"; PASS=$((PASS+1)); } || \
    { echo "  ✗ .binder.json missing"; FAIL=$((FAIL+1)); FAIL_NAMES+=(".binder.json"); }

LIST=$(curl -fsS http://127.0.0.1:$PORT/api/binder)
assert_contains "binder lists momentfactoryagent" '"id": "momentfactoryagent"' "$LIST"

# ── Section 4: execute via /api/binder/agent (no swarm needed) ─────────

echo ""
echo "--- Section 4: execute installed rapplication via /api/binder/agent ---"

if [ -z "$AZURE_OPENAI_ENDPOINT" ] && [ -z "$OPENAI_API_KEY" ]; then
    echo "  ⊘ skipped — no LLM configured"
else
    OUT=$(python3 - <<PY
import json, urllib.request
moment = json.load(open("tests/fixtures/moments/05-location.json"))
body = {"name": "MomentFactory",
        "args": {"source": moment["source"], "source_type": moment["source_type"],
                 "significance_threshold": 0.6}}
r = urllib.request.urlopen(urllib.request.Request(
    "http://127.0.0.1:$PORT/api/binder/agent",
    data=json.dumps(body).encode(),
    headers={"Content-Type":"application/json"}, method="POST"), timeout=180)
print(r.read().decode("utf-8"))
PY
)
    assert_contains "binder/agent returned status ok" '"status": "ok"' "$OUT"
    # The "Coffee." moment should be skipped — the inner output JSON is escaped within the envelope
    assert_contains "low-sig moment skipped"          '\"skipped\": true' "$OUT"
fi

# ── Section 5: uninstall removes the file + the record ────────────────

echo ""
echo "--- Section 5: uninstall ---"

DEL=$(curl -fsS -X DELETE http://127.0.0.1:$PORT/api/binder/installed/momentfactoryagent)
assert_contains "uninstall succeeded" '"status": "ok"' "$DEL"

[ ! -f "$ROOT/agents/momentfactory_agent.py" ] && \
    { echo "  ✓ singleton file removed"; PASS=$((PASS+1)); } || \
    { echo "  ✗ singleton file still present"; FAIL=$((FAIL+1)); FAIL_NAMES+=("uninstall-file"); }

LIST2=$(curl -fsS http://127.0.0.1:$PORT/api/binder)
assert_contains "binder is empty after uninstall" '"installed": []' "$LIST2"

# ── Section 6: sync re-materializes from binder.json ──────────────────

echo ""
echo "--- Section 6: sync re-materializes ---"

# Re-install and then manually delete the file to simulate state drift
curl -fsS -X POST http://127.0.0.1:$PORT/api/binder/install \
    -H "Content-Type: application/json" \
    -d '{"id": "momentfactoryagent"}' > /dev/null
rm "$ROOT/agents/momentfactory_agent.py"

SYNC=$(curl -fsS -X POST http://127.0.0.1:$PORT/api/binder/sync \
    -H "Content-Type: application/json" -d '{}')
assert_contains "sync reports synced" '"status": "synced"' "$SYNC"
[ -f "$ROOT/agents/momentfactory_agent.py" ] && \
    { echo "  ✓ singleton restored by sync"; PASS=$((PASS+1)); } || \
    { echo "  ✗ singleton NOT restored"; FAIL=$((FAIL+1)); FAIL_NAMES+=("sync-restore"); }

# ── Section 7: SHA-256 mismatch is rejected ───────────────────────────

echo ""
echo "--- Section 7: SHA-256 enforcement ---"

# Create a doctored catalog with a wrong SHA pin and point the brainstem at it
DOCTORED=/tmp/doctored-catalog.json
python3 - <<PY
import json
cat = json.load(open("rapp_store/index.json"))
for r in cat["rapplications"]:
    if r["id"] == "bookfactoryagent":
        r["singleton_sha256"] = "0" * 64
json.dump(cat, open("$DOCTORED", "w"), indent=2)
PY

# Bounce server with the doctored catalog
kill $SERVER_PID 2>/dev/null
sleep 0.3
lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 0.3
RAPP_CATALOG=$DOCTORED python3 -u rapp_brainstem/brainstem.py --port $PORT --root "$ROOT" > /tmp/binder-test-server2.log 2>&1 &
SERVER_PID=$!
sleep 2

REJECT=$(curl -sS -X POST http://127.0.0.1:$PORT/api/binder/install \
    -H "Content-Type: application/json" \
    -d '{"id": "bookfactoryagent"}')
assert_contains "doctored catalog rejected on SHA mismatch" "SHA-256 mismatch" "$REJECT"

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"
echo "  $PASS passed, $FAIL failed"
echo "════════════════════════════════════════"
[ $FAIL -gt 0 ] && { for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done; exit 1; }
exit 0
