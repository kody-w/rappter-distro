#!/usr/bin/env bash
# Tier 2 local: func start, /api/health, /api/businessinsightbot_function
# with Power-Automate-shape body, guid-scoped memory isolation.
set -euo pipefail
cd "$(dirname "$0")/../.."

PORT="${PORT:-7073}"   # default 7073 to avoid collision with an installed brainstem or a tier-1 test on 7072
FUNC_PID_FILE=/tmp/rapp-e2e-func.pid
LOG=/tmp/rapp-e2e-func.log

cleanup() {
    if [ -f "$FUNC_PID_FILE" ]; then
        kill "$(cat "$FUNC_PID_FILE")" 2>/dev/null || true
        # Give it a moment to release the port
        sleep 1
        rm -f "$FUNC_PID_FILE"
    fi
}
trap cleanup EXIT

# ── Gates ─────────────────────────────────────────────────────────────

if ! command -v func >/dev/null 2>&1; then
    echo "FAIL: 'func' CLI not found. Install with:"
    echo "    brew tap azure/functions && brew install azure-functions-core-tools@4"
    exit 1
fi
echo "PASS: func CLI present ($(func --version 2>&1 | head -1))"

if lsof -i ":$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "FAIL: port $PORT is in use. Stop brainstem (or whatever's there) before running this test."
    lsof -i ":$PORT" -sTCP:LISTEN
    exit 1
fi

# Ensure vendored tree is fresh
echo "▶ Running build.sh to refresh _vendored/..."
bash rapp_swarm/build.sh >/dev/null

# Install python deps into the venv the user presumably has (best-effort).
# We don't force pip install here — leave that to the user/CI. If imports
# fail at func start we'll catch it in the log.

# local.settings.json — create from example if missing
if [ ! -f rapp_swarm/local.settings.json ]; then
    if [ -f rapp_swarm/local.settings.json.example ]; then
        cp rapp_swarm/local.settings.json.example rapp_swarm/local.settings.json
        echo "  created local.settings.json from example"
    else
        cat > rapp_swarm/local.settings.json <<'EOF'
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "AzureWebJobsStorage": "UseDevelopmentStorage=true"
  }
}
EOF
        echo "  created minimal local.settings.json"
    fi
fi

# ── Start func host ───────────────────────────────────────────────────

echo "▶ Starting 'func start' on :$PORT..."
( cd rapp_swarm && func start --port "$PORT" ) > "$LOG" 2>&1 &
echo $! > "$FUNC_PID_FILE"

# Wait up to 60s for /api/health
for i in $(seq 1 60); do
    if curl -sf "http://localhost:$PORT/api/health" >/dev/null 2>&1; then
        break
    fi
    sleep 1
    if [ "$i" = "60" ]; then
        echo "FAIL: func host did not come up in 60s"
        echo "--- log tail ---"
        tail -40 "$LOG"
        exit 1
    fi
done

# ── Assertions ────────────────────────────────────────────────────────

HEALTH=$(curl -s "http://localhost:$PORT/api/health")
H_STATUS=$(echo "$HEALTH" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status",""))')
if [ "$H_STATUS" = "healthy" ] || [ "$H_STATUS" = "degraded" ]; then
    echo "PASS: /api/health status=$H_STATUS"
else
    echo "FAIL: /api/health status='$H_STATUS'"
    echo "$HEALTH"
    exit 1
fi

# MCS-shape POST with user_guid
GUID_A="11111111-2222-3333-4444-aaaaaaaaaaaa"
GUID_B="11111111-2222-3333-4444-bbbbbbbbbbbb"
FACT_A="my lucky number is 4271828-$(date +%s)"

echo "▶ Save fact under guid A via /api/businessinsightbot_function..."
SAVE_BODY=$(python3 -c "import json; print(json.dumps({'user_input': f'Please remember: $FACT_A', 'conversation_history': [], 'user_guid': '$GUID_A'}))")
SAVE_RESP=$(curl -s -X POST "http://localhost:$PORT/api/businessinsightbot_function" \
    -H "Content-Type: application/json" -d "$SAVE_BODY")
for key in assistant_response agent_logs user_guid; do
    if ! echo "$SAVE_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if '$key' in d else 1)" 2>/dev/null; then
        echo "FAIL: response missing '$key' key. Response:"
        echo "$SAVE_RESP" | head -c 500
        exit 1
    fi
done
echo "PASS: response envelope has {assistant_response, agent_logs, user_guid}"

ECHOED_GUID=$(echo "$SAVE_RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("user_guid",""))')
if [ "$ECHOED_GUID" = "$GUID_A" ]; then
    echo "PASS: user_guid echoed back ($ECHOED_GUID)"
else
    echo "FAIL: expected user_guid=$GUID_A, got '$ECHOED_GUID'"
    exit 1
fi

# Guid isolation: guid B should NOT see guid A's fact
echo "▶ Attempt recall under guid B (should NOT see guid A's fact)..."
RECALL_B_BODY=$(python3 -c "import json; print(json.dumps({'user_input': 'What is my lucky number? Answer in one word or I do not know.', 'conversation_history': [], 'user_guid': '$GUID_B'}))")
RECALL_B_RESP=$(curl -s -X POST "http://localhost:$PORT/api/businessinsightbot_function" \
    -H "Content-Type: application/json" -d "$RECALL_B_BODY")
RECALL_B_TEXT=$(echo "$RECALL_B_RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("assistant_response",""))')
if echo "$RECALL_B_TEXT" | grep -q "4271828"; then
    echo "FAIL: memory leaked between guids — guid B sees guid A's fact!"
    echo "  response: $(echo "$RECALL_B_TEXT" | head -c 300)"
    exit 1
fi
echo "PASS: guid-scoped memory isolation (guid B did not see guid A's fact)"

echo "✅ Tier 2 local test passed"
