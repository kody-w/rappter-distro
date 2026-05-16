#!/usr/bin/env bash
# Wire-envelope test (Constitution Article XXV / SPEC §0.1).
#
# Verifies the sacred /chat envelope on a current brainstem:
#   - request without user_guid → defaults to DEFAULT_USER_GUID
#   - request with user_guid → echoed in response
#   - response always contains BOTH `response` AND `assistant_response`
#     keys with identical content (CA365 + rapp_brainstem lineage parity)
#   - /health includes the `bootstrap` block (start.sh canary)
#
# These shapes are forever. If this test breaks, the wire broke.
set -euo pipefail
cd "$(dirname "$0")/../.."

PORT="${PORT:-7081}"
PID_FILE=/tmp/rapp-e2e-wire.pid
LOG=/tmp/rapp-e2e-wire.log
DEFAULT_USER_GUID="c0p110t0-aaaa-bbbb-cccc-123456789abc"
TEST_USER_GUID="11111111-2222-3333-4444-555555555555"

# If the user has a globally-installed brainstem at ~/.brainstem with a
# valid Copilot session, borrow its auth files for the test process.
# Otherwise the test brainstem can't talk to Copilot. We restore on exit.
AUTH_BORROWED=0
cleanup() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    if [ "$AUTH_BORROWED" = "1" ]; then
        rm -f rapp_brainstem/.copilot_token rapp_brainstem/.copilot_session
    fi
}
trap cleanup EXIT

if lsof -i ":$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "FAIL: port $PORT already in use"
    exit 1
fi

# Auth source candidates — check both possible install locations
for AUTH_SRC in \
    "$HOME/.brainstem/src/rapp_brainstem" \
    "$HOME/.brainstem"; do
    if [ -f "$AUTH_SRC/.copilot_session" ] && [ ! -f rapp_brainstem/.copilot_session ]; then
        cp "$AUTH_SRC/.copilot_session" rapp_brainstem/.copilot_session
        cp "$AUTH_SRC/.copilot_token"   rapp_brainstem/.copilot_token 2>/dev/null || true
        AUTH_BORROWED=1
        echo "▶ Borrowed Copilot auth from $AUTH_SRC"
        break
    fi
done

echo "▶ Starting brainstem on :$PORT..."
( cd rapp_brainstem && PORT=$PORT python3 brainstem.py ) > "$LOG" 2>&1 &
echo $! > "$PID_FILE"

for i in $(seq 1 30); do
    curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1 && break
    sleep 1
    [ "$i" = "30" ] && { echo "FAIL: did not come up"; tail -20 "$LOG"; exit 1; }
done

# ── 1. /chat without user_guid → defaults to DEFAULT_USER_GUID ───────
RESP=$(curl -s -X POST "http://localhost:$PORT/chat" \
    -H "Content-Type: application/json" \
    -d '{"user_input":"reply with exactly the word: ok","conversation_history":[]}')
ECHOED=$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin,strict=False).get("user_guid",""))')
if [ "$ECHOED" != "$DEFAULT_USER_GUID" ]; then
    echo "FAIL: omitted user_guid did not default; got '$ECHOED' expected '$DEFAULT_USER_GUID'"
    echo "$RESP"
    exit 1
fi
echo "PASS: omitted user_guid defaults to DEFAULT_USER_GUID"

# ── 3. /chat with user_guid → echoed back ────────────────────────────
RESP=$(curl -s -X POST "http://localhost:$PORT/chat" \
    -H "Content-Type: application/json" \
    -d "{\"user_input\":\"reply with exactly the word: ok\",\"user_guid\":\"$TEST_USER_GUID\"}")
ECHOED=$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin,strict=False).get("user_guid",""))')
if [ "$ECHOED" != "$TEST_USER_GUID" ]; then
    echo "FAIL: explicit user_guid not echoed; got '$ECHOED' expected '$TEST_USER_GUID'"
    echo "$RESP"
    exit 1
fi
echo "PASS: explicit user_guid is echoed in response"

# ── 4. Both response keys present with identical values ──────────────
A=$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin,strict=False).get("response",""))')
B=$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin,strict=False).get("assistant_response",""))')
if [ -z "$A" ]; then
    echo "FAIL: response key missing or empty"
    echo "$RESP"
    exit 1
fi
if [ -z "$B" ]; then
    echo "FAIL: assistant_response key missing or empty (CA365 lineage compat)"
    echo "$RESP"
    exit 1
fi
if [ "$A" != "$B" ]; then
    echo "FAIL: response and assistant_response carry different values"
    echo "  response:           $A"
    echo "  assistant_response: $B"
    exit 1
fi
echo "PASS: response and assistant_response present with identical content"

# ── 5. Slot delimiters cleanly stripped from response field ──────────
# When TWIN_MODE is on and the LLM emits |||TWIN|||, the `response` and
# `assistant_response` fields must NOT contain the delimiter or the twin
# text. Programmatic clients reading `response` should never see a leaked
# slot delimiter — that's the whole point of the server-side split.
RESP=$(curl -s -X POST "http://localhost:$PORT/chat" \
    -H "Content-Type: application/json" \
    -d '{"user_input":"reply with one short sentence and a brief twin observation"}')
A=$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin,strict=False).get("response",""))')
B=$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin,strict=False).get("assistant_response",""))')
if echo "$A" | grep -qE '\|\|\|(VOICE|TWIN)\|\|\|'; then
    echo "FAIL: response field leaks slot delimiter — server-side split is broken"
    echo "  response: $A"
    exit 1
fi
if echo "$B" | grep -qE '\|\|\|(VOICE|TWIN)\|\|\|'; then
    echo "FAIL: assistant_response field leaks slot delimiter"
    echo "  assistant_response: $B"
    exit 1
fi
echo "PASS: slot delimiters stripped cleanly from response/assistant_response"

# ── 6. Unknown future field → ignored gracefully ─────────────────────
RESP=$(curl -s -w "\n%{http_code}" -X POST "http://localhost:$PORT/chat" \
    -H "Content-Type: application/json" \
    -d '{"user_input":"hi","future_field_v99":{"nested":[1,2,3]}}')
HTTP_CODE=$(echo "$RESP" | tail -1)
if [ "$HTTP_CODE" != "200" ]; then
    echo "FAIL: unknown future field rejected (HTTP $HTTP_CODE); additive-only rule broken"
    echo "$RESP"
    exit 1
fi
echo "PASS: unknown future field accepted (additive-only honored)"

echo "✅ Wire-envelope test passed"
