#!/usr/bin/env bash
# Tier 1 smoke: brainstem starts, /health green, /chat round-trips.
set -euo pipefail
cd "$(dirname "$0")/../.."

PORT="${PORT:-7072}"   # default 7072 to avoid collision with installed brainstem on 7071
PID_FILE=/tmp/rapp-e2e-brainstem.pid
LOG=/tmp/rapp-e2e-brainstem.log

cleanup() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
}
trap cleanup EXIT

# Make sure the port is free
if lsof -i ":$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "FAIL: port $PORT already in use. Stop the existing listener first."
    lsof -i ":$PORT" -sTCP:LISTEN
    exit 1
fi

# Start brainstem in background
echo "▶ Starting brainstem on :$PORT..."
( cd rapp_brainstem && PORT=$PORT python3 brainstem.py ) > "$LOG" 2>&1 &
echo $! > "$PID_FILE"

# Wait up to 30s for /health
for i in $(seq 1 30); do
    if curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1; then
        break
    fi
    sleep 1
    if [ "$i" = "30" ]; then
        echo "FAIL: brainstem did not come up in 30s"
        echo "--- log tail ---"
        tail -30 "$LOG"
        exit 1
    fi
done

# ── Assertions ────────────────────────────────────────────────────────

HEALTH=$(curl -s "http://localhost:$PORT/health")

STATUS=$(echo "$HEALTH" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status",""))')
if [ "$STATUS" = "ok" ]; then
    echo "PASS: /health status=ok"
elif [ "$STATUS" = "unauthenticated" ]; then
    echo "FAIL: brainstem is unauthenticated. Run 'gh auth login' or set GITHUB_TOKEN with Copilot access."
    exit 1
else
    echo "FAIL: /health status='$STATUS' (expected 'ok')"
    echo "$HEALTH"
    exit 1
fi

EXPECTED_AGENTS=(BasicAgent HackerNews LearnNew SaveMemory RecallMemory WorkIQ SwarmFactory)
AGENTS_CSV=$(echo "$HEALTH" | python3 -c 'import sys,json; print(",".join(sorted(json.load(sys.stdin).get("agents",[]))))')
echo "  loaded agents: $AGENTS_CSV"
MISSING=0
for name in "${EXPECTED_AGENTS[@]}"; do
    # Some agent display-names differ slightly; we do contains-match.
    if ! echo "$AGENTS_CSV" | grep -iq "$name"; then
        echo "  (info) '$name' not in agent list — may be named differently"
    fi
done
# Hard floor: at least 5 agents must be present
COUNT=$(echo "$AGENTS_CSV" | awk -F, '{print NF}')
if [ "$COUNT" -lt 5 ]; then
    echo "FAIL: expected at least 5 agents, got $COUNT: $AGENTS_CSV"
    exit 1
fi
echo "PASS: $COUNT agents loaded"

# /chat round-trip
echo "▶ Testing /chat round-trip..."
CHAT_RESP=$(curl -s -X POST "http://localhost:$PORT/chat" \
    -H "Content-Type: application/json" \
    -d '{"user_input":"reply with exactly one word: hi","conversation_history":[]}' )
RESP_TEXT=$(echo "$CHAT_RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("response",""))')
if [ -z "$RESP_TEXT" ]; then
    echo "FAIL: /chat returned empty response"
    echo "$CHAT_RESP"
    exit 1
fi
echo "PASS: /chat returned response (length: ${#RESP_TEXT})"
echo "  sample: $(echo "$RESP_TEXT" | head -c 120)"

echo "✅ Tier 1 smoke test passed"
