#!/bin/bash
# tests/test-llm-chat.sh — exercises /api/swarm/{guid}/chat via rapp_brainstem/brainstem.py
# in LLM_FAKE mode (deterministic stub LLM). Verifies the wire shape, the
# tool-call execution path, and the LLM provider diagnostic endpoint.
#
# Real LLM smoke (live keys from .env) is OPT-IN: set LIVE_LLM=1 to attempt
# a real Azure OpenAI call. Default is fake-only so CI never burns budget.
#
#     bash tests/test-llm-chat.sh
#     LIVE_LLM=1 bash tests/test-llm-chat.sh

set -e
set -o pipefail

PORT=7184
ROOT=/tmp/rapp-swarm-test-llm
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
        echo "      haystack:  $(echo "$haystack" | head -c 240)"
        FAIL=$((FAIL + 1))
        FAIL_NAMES+=("$name")
    fi
}

# ── Setup ──────────────────────────────────────────────────────────────

echo "Setup: clean state at $ROOT"
[ -e "$ROOT" ] && chmod -R u+w "$ROOT" 2>/dev/null
rm -rf "$ROOT"

# Force fake LLM mode for reproducibility
echo "Setup: starting swarm server with LLM_FAKE=1 on :$PORT"
LLM_FAKE=1 python3 rapp_brainstem/brainstem.py --port $PORT --root "$ROOT" >/dev/null 2>&1 &
SERVER_PID=$!
sleep 1.5

# Build a tiny bundle with the standard SaveMemory + RecallMemory agents
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
    'name': 'llm-test-swarm',
    'purpose': 'LLM-driven chat smoke test',
    'soul': 'You are a test assistant.',
    'created_at': '2026-04-19T00:00:00Z',
    'created_by': 'test',
    'agents': agents,
}))
PY
)
echo "$BUNDLE" > /tmp/test-llm-bundle.json

DEPLOY=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/deploy \
    -H 'Content-Type: application/json' --data-binary @/tmp/test-llm-bundle.json)
SWARM_GUID=$(echo "$DEPLOY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarm_guid"])')
[ -n "$SWARM_GUID" ]

# ── Section 1: provider diagnostics ───────────────────────────────────

echo ""
echo "--- Section 1: /api/llm/status ---"

RESP=$(curl -s http://127.0.0.1:$PORT/api/llm/status)
PROVIDER=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["provider"])')
assert_eq "provider == fake (LLM_FAKE=1)"  "fake"  "$PROVIDER"
assert_contains "diagnostics carries azure_openai_configured field"  "azure_openai_configured"  "$RESP"

# ── Section 2: chat with no tools ─────────────────────────────────────

echo ""
echo "--- Section 2: chat path with fake LLM ---"

# Deploy a swarm with a non-tool agent (the basic agents will be present
# but the fake-LLM still calls one; let's verify the wire shape works).

RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/chat \
    -H 'Content-Type: application/json' \
    -d '{"user_input":"hello, test"}')
RESP_PROVIDER=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("provider",""))')
assert_eq "chat response carries provider=fake"  "fake"  "$RESP_PROVIDER"

# Fake LLM, when given tools, calls the FIRST tool with empty args. So the
# response should include agent_logs reflecting that one round of tool use.
LOGS_LEN=$(echo "$RESP" | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("agent_logs",[])))')
[ "$LOGS_LEN" -ge 1 ]
assert_eq "fake LLM exercised at least one tool call"  "ok"  "ok"

ROUNDS=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("rounds",0))')
[ "$ROUNDS" -ge 1 ]
assert_eq "chat loop ran ≥1 round"  "ok"  "ok"

# Returned swarm_guid must match the one we hit
RESP_GUID=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("swarm_guid"))')
assert_eq "response carries the swarm_guid we addressed"  "$SWARM_GUID"  "$RESP_GUID"

# Missing user_input → 400
RESP=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/chat \
    -H 'Content-Type: application/json' \
    -d '{}' | tail -n 1)
assert_eq "missing user_input → HTTP 400"  "400"  "$RESP"

# Unknown swarm → 404 (or 500 with 'not found')
RESP=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$PORT/api/swarm/00000000-0000-0000-0000-000000000000/chat \
    -H 'Content-Type: application/json' \
    -d '{"user_input":"x"}')
HTTP_CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
assert_contains "unknown swarm chat → response mentions 'not found'"  "not found"  "$BODY"

# ── Section 3 (optional): live LLM smoke ──────────────────────────────

if [ "${LIVE_LLM:-}" = "1" ]; then
    echo ""
    echo "--- Section 3: LIVE LLM smoke (LIVE_LLM=1) ---"
    # Restart server WITHOUT LLM_FAKE so .env keys take over
    kill $SERVER_PID; wait $SERVER_PID 2>/dev/null || true
    [ -e "$ROOT" ] && chmod -R u+w "$ROOT" 2>/dev/null
    rm -rf "$ROOT"
    python3 rapp_brainstem/brainstem.py --port $PORT --root "$ROOT" >/dev/null 2>&1 &
    SERVER_PID=$!
    sleep 1.5

    DEPLOY=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/deploy \
        -H 'Content-Type: application/json' --data-binary @/tmp/test-llm-bundle.json)
    SWARM_GUID=$(echo "$DEPLOY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarm_guid"])')

    RESP=$(curl -s http://127.0.0.1:$PORT/api/llm/status)
    PROVIDER=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["provider"])')
    assert_contains "live provider is one of azure-openai/openai/anthropic"  "$PROVIDER"  "azure-openai openai anthropic"

    # Real LLM call — short prompt to keep cost minimal
    RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$SWARM_GUID/chat \
        -H 'Content-Type: application/json' \
        -d '{"user_input":"In ten words or less, say hello."}')
    RESPONSE_TEXT=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("response",""))' 2>/dev/null || echo "")
    [ -n "$RESPONSE_TEXT" ]
    assert_eq "live LLM produced a non-empty response"  "ok"  "ok"
    echo "  Response: $RESPONSE_TEXT"
fi

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
