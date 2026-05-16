#!/bin/bash
# tests/test-sealing-snapshot.sh — end-to-end test of sealing + snapshot extensions
# to the public RAPP swarm server.
#
# Tests the on-the-wire contract that downstream products (rapptwin, etc.)
# build on. Run from repo root:
#
#     bash tests/test-sealing-snapshot.sh
#
# Exits 0 on success, non-zero with diagnostics on failure.

set -e
set -o pipefail

PORT=7180
ROOT=/tmp/rapp-swarm-test-sealing
SERVER_PID=""
PASS=0
FAIL=0
FAIL_NAMES=()

cleanup() {
    if [ -n "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ── Helpers ────────────────────────────────────────────────────────────

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $name"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $name"
        echo "      expected: $expected"
        echo "      actual:   $actual"
        FAIL=$((FAIL + 1))
        FAIL_NAMES+=("$name")
    fi
}

assert_contains() {
    local name="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "  ✓ $name"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $name"
        echo "      needle:    $needle"
        echo "      haystack:  $(echo "$haystack" | head -c 200)"
        FAIL=$((FAIL + 1))
        FAIL_NAMES+=("$name")
    fi
}

curl_json() {
    curl -s -w "\n%{http_code}" "$@"
}

last_line() { tail -n 1; }
all_but_last() { sed '$d'; }

# ── Setup ──────────────────────────────────────────────────────────────

echo "Setup: clean state at $ROOT"
# Sealed snapshots get chmod 444/555 — force writable before removal so a
# previous run's read-only tree doesn't block this run's cleanup.
[ -e "$ROOT" ] && chmod -R u+w "$ROOT" 2>/dev/null
rm -rf "$ROOT"

echo "Setup: starting swarm server on :$PORT"
python3 rapp_brainstem/brainstem.py --port $PORT --root "$ROOT" >/dev/null 2>&1 &
SERVER_PID=$!
sleep 1.5

# Build a test bundle from the agents/ directory
BUNDLE=$(python3 - <<'PY'
import json, pathlib
agents = []
for p in pathlib.Path('rapp_brainstem/agents').glob('*_agent.py'):
    if p.name == 'basic_agent.py': continue
    agents.append({
        'filename': p.name,
        'name': p.stem.replace('_agent', '').title().replace('_', ''),
        'source': p.read_text(),
    })
print(json.dumps({
    'schema': 'rapp-swarm/1.0',
    'name': 'test-seal-swarm',
    'purpose': 'sealing+snapshot smoke test',
    'created_at': '2026-04-19T00:00:00Z',
    'created_by': 'test',
    'agents': agents,
}))
PY
)
echo "$BUNDLE" > /tmp/test-bundle.json
echo "Setup: built bundle with $(echo "$BUNDLE" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["agents"]),"agents")')"

# ── Section 1: Deploy & basic ops (sanity baseline) ────────────────────

echo ""
echo "--- Section 1: deploy + basic ops ---"

DEPLOY=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/deploy \
    -H 'Content-Type: application/json' --data-binary @/tmp/test-bundle.json)
SWARM_GUID=$(echo "$DEPLOY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarm_guid"])')
assert_contains "deploy returns swarm_guid"  "$SWARM_GUID"  "$DEPLOY"

# Initial seal status: must be unsealed
RESP=$(curl -s http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/seal)
SEALED=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["sealed"])')
assert_eq "initial sealed = false"  "False"  "$SEALED"

# Save a memory (writes work pre-seal)
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/agent \
    -H 'Content-Type: application/json' \
    -d '{"name":"SaveMemory","args":{"memory_type":"fact","content":"pre-seal memory"}}')
STATUS=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])')
assert_eq "save memory pre-seal succeeds (status=ok)"  "ok"  "$STATUS"

# Recall it
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/agent \
    -H 'Content-Type: application/json' \
    -d '{"name":"RecallMemory","args":{}}')
assert_contains "recall sees pre-seal memory"  "pre-seal memory"  "$RESP"

# ── Section 2: Sealing ────────────────────────────────────────────────

echo ""
echo "--- Section 2: sealing ---"

# Seal the swarm
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/seal \
    -H 'Content-Type: application/json' \
    -d '{"actor":"test-principal","trigger":"voluntary"}')
STATUS=$(echo "$RESP" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("status",""))')
assert_eq "POST /seal returns status=ok"  "ok"  "$STATUS"

# Re-check sealed status
RESP=$(curl -s http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/seal)
SEALED=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["sealed"])')
assert_eq "GET /seal now reports sealed=true"  "True"  "$SEALED"

# Sealing is idempotent
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/seal \
    -H 'Content-Type: application/json' -d '{"actor":"test-principal"}')
STATUS=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))')
assert_eq "second seal call is idempotent (status=ok)"  "ok"  "$STATUS"

# Reads still work after seal
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/agent \
    -H 'Content-Type: application/json' \
    -d '{"name":"RecallMemory","args":{}}')
assert_contains "recall after seal still works"  "pre-seal memory"  "$RESP"

# Writes are rejected after seal — agent execution returns error envelope
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/agent \
    -H 'Content-Type: application/json' \
    -d '{"name":"SaveMemory","args":{"memory_type":"fact","content":"post-seal write attempt"}}')
# The output is a JSON-encoded envelope from the agent; it should indicate failure.
# Expected shape: {"status":"ok","output":"{\"status\":\"error\",\"message\":\"sealed\",...}"}
# OR the server can return 423 Locked. Either is acceptable; check for "sealed" in the response.
assert_contains "post-seal write attempt rejected (response mentions sealed)"  "sealed"  "$RESP"

# Re-deploy with same swarm_guid: must be rejected (sealed swarms are immutable)
REDEPLOY_BODY=$(echo "$BUNDLE" | python3 -c "import json,sys; b=json.load(sys.stdin); b['swarm_guid']='$SWARM_GUID'; print(json.dumps(b))")
RESP=$(curl_json -X POST http://127.0.0.1:$PORT/api/swarm/deploy \
    -H 'Content-Type: application/json' --data-binary "$REDEPLOY_BODY")
HTTP_CODE=$(echo "$RESP" | last_line)
BODY=$(echo "$RESP" | all_but_last)
assert_eq "redeploy of sealed swarm returns HTTP 423"  "423"  "$HTTP_CODE"
assert_contains "redeploy error mentions sealed"  "sealed"  "$BODY"

# DELETE on a sealed swarm: must be rejected
RESP=$(curl_json -X DELETE http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID)
HTTP_CODE=$(echo "$RESP" | last_line)
assert_eq "DELETE on sealed swarm returns HTTP 423"  "423"  "$HTTP_CODE"

# Verify sealing metadata is in /healthz output
RESP=$(curl -s http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/healthz)
assert_contains "swarm-level healthz reports sealed status"  '"sealed": true'  "$RESP"

# ── Section 3: Snapshots ──────────────────────────────────────────────

echo ""
echo "--- Section 3: snapshots ---"

# Deploy a SECOND swarm (unsealed) to test snapshots
BUNDLE2=$(echo "$BUNDLE" | python3 -c 'import json,sys; b=json.load(sys.stdin); b["name"]="snap-test-swarm"; print(json.dumps(b))')
DEPLOY2=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/deploy \
    -H 'Content-Type: application/json' --data-binary "$BUNDLE2")
SNAP_GUID=$(echo "$DEPLOY2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarm_guid"])')
assert_contains "second swarm deploys"  "$SNAP_GUID"  "$DEPLOY2"

# Save a memory we want to snapshot
curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SNAP_GUID/agent \
    -H 'Content-Type: application/json' \
    -d '{"name":"SaveMemory","args":{"memory_type":"fact","content":"phase-1 memory"}}' >/dev/null

# Create a snapshot
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SNAP_GUID/snapshot \
    -H 'Content-Type: application/json' -d '{"label":"phase-1"}')
SNAP1=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("snapshot_name",""))')
[ -n "$SNAP1" ]
assert_contains "snapshot 1 created"  "phase-1"  "$RESP"

# Save a SECOND memory after snapshot
curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SNAP_GUID/agent \
    -H 'Content-Type: application/json' \
    -d '{"name":"SaveMemory","args":{"memory_type":"fact","content":"phase-2 memory"}}' >/dev/null

# Create a second snapshot
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SNAP_GUID/snapshot \
    -H 'Content-Type: application/json' -d '{"label":"phase-2"}')
SNAP2=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("snapshot_name",""))')
[ -n "$SNAP2" ]

# List snapshots — should see both
RESP=$(curl -s http://127.0.0.1:$PORT/api/swarm/$SNAP_GUID/snapshots)
COUNT=$(echo "$RESP" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["snapshots"]))')
assert_eq "snapshot list contains 2 entries"  "2"  "$COUNT"

# Active swarm sees BOTH memories (phase-1 + phase-2)
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SNAP_GUID/agent \
    -H 'Content-Type: application/json' \
    -d '{"name":"RecallMemory","args":{}}')
assert_contains "active swarm has phase-1 memory"  "phase-1 memory"  "$RESP"
assert_contains "active swarm has phase-2 memory"  "phase-2 memory"  "$RESP"

# Calling agent against snapshot phase-1 sees ONLY phase-1 memory
RESP=$(curl -s -X POST "http://127.0.0.1:$PORT/api/swarm/$SNAP_GUID/snapshots/$SNAP1/agent" \
    -H 'Content-Type: application/json' \
    -d '{"name":"RecallMemory","args":{}}')
assert_contains "snapshot 1 agent call sees phase-1 memory"  "phase-1 memory"  "$RESP"
# Phase 2 should NOT be in snapshot 1
if echo "$RESP" | grep -qF "phase-2 memory"; then
    echo "  ✗ snapshot 1 should NOT contain phase-2 memory"
    FAIL=$((FAIL + 1))
    FAIL_NAMES+=("snapshot 1 isolation")
else
    echo "  ✓ snapshot 1 does not contain phase-2 memory (isolation correct)"
    PASS=$((PASS + 1))
fi

# Snapshot is read-only: writing to it should fail
RESP=$(curl -s -X POST "http://127.0.0.1:$PORT/api/swarm/$SNAP_GUID/snapshots/$SNAP1/agent" \
    -H 'Content-Type: application/json' \
    -d '{"name":"SaveMemory","args":{"memory_type":"fact","content":"trying to write to snapshot"}}')
assert_contains "snapshot write attempt rejected (response mentions snapshot or sealed)"  "snapshot"  "$RESP"

# Snapshot of a sealed swarm should also work (final-snapshot semantics)
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/snapshot \
    -H 'Content-Type: application/json' -d '{"label":"post-seal-archive"}')
assert_contains "snapshot of sealed swarm succeeds (final archive use case)"  "post-seal-archive"  "$RESP"

# ── Section 4: Top-level health ────────────────────────────────────────

echo ""
echo "--- Section 4: top-level health ---"

RESP=$(curl -s http://127.0.0.1:$PORT/api/swarm/healthz)
COUNT=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarm_count"])')
assert_eq "top-level healthz reports 2 swarms"  "2"  "$COUNT"

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"
echo "  $PASS passed, $FAIL failed"
echo "════════════════════════════════════════"

if [ $FAIL -gt 0 ]; then
    echo "Failures:"
    for n in "${FAIL_NAMES[@]}"; do
        echo "  - $n"
    done
    exit 1
fi
exit 0
