#!/usr/bin/env bash
# Tier 2 cloud: same MCS-shape request against a deployed Azure Function.
# Requires FUNCTION_URL and FUNCTION_KEY env vars.
set -euo pipefail

: "${FUNCTION_URL:?FUNCTION_URL env var required (e.g. https://twin-foo.azurewebsites.net)}"
: "${FUNCTION_KEY:?FUNCTION_KEY env var required (from Azure Portal → Function App → App keys)}"

BASE="${FUNCTION_URL%/}/api/businessinsightbot_function"
HEALTH_URL="${FUNCTION_URL%/}/api/health"

echo "▶ GET $HEALTH_URL"
HEALTH=$(curl -sf "$HEALTH_URL")
H_STATUS=$(echo "$HEALTH" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status",""))')
if [ "$H_STATUS" = "healthy" ] || [ "$H_STATUS" = "degraded" ]; then
    echo "PASS: /api/health status=$H_STATUS"
else
    echo "FAIL: /api/health status='$H_STATUS'"
    echo "$HEALTH"
    exit 1
fi

GUID_A="22222222-3333-4444-5555-aaaaaaaaaaaa"
GUID_B="22222222-3333-4444-5555-bbbbbbbbbbbb"
FACT_A="my lucky number is 9182736-$(date +%s)"

echo "▶ POST $BASE?code=... (guid A save)"
SAVE_BODY=$(python3 -c "import json; print(json.dumps({'user_input': f'Please remember: $FACT_A', 'conversation_history': [], 'user_guid': '$GUID_A'}))")
SAVE_RESP=$(curl -sf -X POST "$BASE?code=$FUNCTION_KEY" \
    -H "Content-Type: application/json" -H "x-functions-key: $FUNCTION_KEY" \
    -d "$SAVE_BODY")
for key in assistant_response agent_logs user_guid; do
    if ! echo "$SAVE_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if '$key' in d else 1)" 2>/dev/null; then
        echo "FAIL: cloud response missing '$key'. Body:"
        echo "$SAVE_RESP" | head -c 500
        exit 1
    fi
done
echo "PASS: envelope has {assistant_response, agent_logs, user_guid}"

ECHOED=$(echo "$SAVE_RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("user_guid",""))')
if [ "$ECHOED" != "$GUID_A" ]; then
    echo "FAIL: user_guid not echoed back. Got '$ECHOED', expected '$GUID_A'"
    exit 1
fi
echo "PASS: user_guid echoed ($ECHOED)"

echo "▶ POST $BASE?code=... (guid B recall — should not see A's fact)"
RECALL_BODY=$(python3 -c "import json; print(json.dumps({'user_input': 'What is my lucky number? Answer in one word or I do not know.', 'conversation_history': [], 'user_guid': '$GUID_B'}))")
RECALL_RESP=$(curl -sf -X POST "$BASE?code=$FUNCTION_KEY" \
    -H "Content-Type: application/json" -H "x-functions-key: $FUNCTION_KEY" \
    -d "$RECALL_BODY")
RECALL_TEXT=$(echo "$RECALL_RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("assistant_response",""))')
if echo "$RECALL_TEXT" | grep -q "9182736"; then
    echo "FAIL: cloud memory leaked between guids"
    exit 1
fi
echo "PASS: cloud guid-scoped memory isolation"

echo "✅ Tier 2 cloud test passed"
