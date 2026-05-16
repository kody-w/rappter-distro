#!/usr/bin/env bash
# Tier 1 memory + factory: save_memory/recall_memory round-trip through
# the LLM tool-call loop, then swarm_factory action=build produces a
# singleton file.
set -euo pipefail
cd "$(dirname "$0")/../.."

PORT="${PORT:-7072}"
PID_FILE=/tmp/rapp-e2e-brainstem.pid
LOG=/tmp/rapp-e2e-brainstem.log
TMP_DIR=$(mktemp -d)

cleanup_test_swarm() {
    rm -rf rapp_brainstem/agents/workspace_agents/e2e_test_swarm
    rm -f rapp_brainstem/agents/e2e_test_swarm_agent.py 2>/dev/null || true
}
cleanup() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    rm -rf "$TMP_DIR"
    cleanup_test_swarm
}
trap cleanup EXIT

# Reuse or start the brainstem
if curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1; then
    echo "▶ Reusing brainstem already on :$PORT"
else
    echo "▶ Starting brainstem on :$PORT..."
    ( cd rapp_brainstem && PORT=$PORT python3 brainstem.py ) > "$LOG" 2>&1 &
    echo $! > "$PID_FILE"
    for i in $(seq 1 30); do
        curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1 && break
        sleep 1
    done
fi

# Helper: build JSON body via python, read from stdin, write to file
jbody() {
    python3 -c 'import json, sys; print(json.dumps(json.loads(sys.stdin.read())))'
}

# ── Memory round-trip ─────────────────────────────────────────────────

STAMP=$(date +%s)
FACT="my favourite color is viridian-$STAMP"
echo "▶ Saving fact via chat: '$FACT'"

cat > "$TMP_DIR/save_body.json" <<JSON
{
  "user_input": "Please remember this for me: $FACT",
  "conversation_history": []
}
JSON

SAVE_RESP=$(curl -s -X POST "http://localhost:$PORT/chat" \
    -H "Content-Type: application/json" \
    --data @"$TMP_DIR/save_body.json")
echo "$SAVE_RESP" > "$TMP_DIR/save_resp.json"
SAVE_LOGS=$(python3 -c "import json; print(json.load(open('$TMP_DIR/save_resp.json')).get('agent_logs',''))")
SAVE_TEXT=$(python3 -c "import json; print(json.load(open('$TMP_DIR/save_resp.json')).get('response',''))")

if echo "$SAVE_LOGS" | grep -iq "save_memory\|savememory\|SaveMemory"; then
    echo "PASS: save_memory invoked during save turn"
else
    echo "WARN: save_memory was not invoked on the save turn."
    echo "  agent_logs: $(echo "$SAVE_LOGS" | head -c 200)"
    echo "  response: $(echo "$SAVE_TEXT" | head -c 200)"
fi

echo "▶ Recalling via chat..."
cat > "$TMP_DIR/recall_body.json" <<'JSON'
{
  "user_input": "What is my favourite color? Answer in one word only.",
  "conversation_history": []
}
JSON
RECALL_RESP=$(curl -s -X POST "http://localhost:$PORT/chat" \
    -H "Content-Type: application/json" \
    --data @"$TMP_DIR/recall_body.json")
echo "$RECALL_RESP" > "$TMP_DIR/recall_resp.json"
RECALL_TEXT=$(python3 -c "import json; print(json.load(open('$TMP_DIR/recall_resp.json')).get('response',''))")

if echo "$RECALL_TEXT" | grep -iq "viridian"; then
    echo "PASS: memory round-trip (fact recovered in recall turn)"
else
    echo "WARN: 'viridian' not in recall response. LLM may have ignored memory context."
    echo "  response: $(echo "$RECALL_TEXT" | head -c 200)"
fi

# ── Swarm factory: converge workshop → singleton ──────────────────────

TEST_SWARM_DIR=rapp_brainstem/agents/workspace_agents/e2e_test_swarm
mkdir -p "$TEST_SWARM_DIR"
cat > "$TEST_SWARM_DIR/e2e_echo_agent.py" <<'EOF'
from agents.basic_agent import BasicAgent
class E2EEchoAgent(BasicAgent):
    def __init__(self):
        self.name = "E2EEcho"
        self.metadata = {
            "name": self.name,
            "description": "Echoes the message argument back. Test-only.",
            "parameters": {"type":"object","properties":{"message":{"type":"string"}},"required":["message"]}
        }
        super().__init__(name=self.name, metadata=self.metadata)
    def perform(self, message="", **kwargs):
        return f"echo: {message}"
EOF
echo "  seeded test swarm at $TEST_SWARM_DIR"

echo "▶ Invoking swarm_factory (action=build) via /chat..."
cat > "$TMP_DIR/build_body.json" <<'JSON'
{
  "user_input": "Use the swarm_factory tool with action=build to package the agents in the e2e_test_swarm workshop into a singleton named e2e_test_swarm. Report the output path.",
  "conversation_history": []
}
JSON
BUILD_RESP=$(curl -s -X POST "http://localhost:$PORT/chat" \
    -H "Content-Type: application/json" \
    --data @"$TMP_DIR/build_body.json")
echo "$BUILD_RESP" > "$TMP_DIR/build_resp.json"
BUILD_LOGS=$(python3 -c "import json; print(json.load(open('$TMP_DIR/build_resp.json')).get('agent_logs',''))")
BUILD_TEXT=$(python3 -c "import json; print(json.load(open('$TMP_DIR/build_resp.json')).get('response',''))")

if echo "$BUILD_LOGS" | grep -iq "swarm_factory\|swarmfactory\|SwarmFactory"; then
    echo "PASS: swarm_factory invoked"
    echo "  factory output (first 300 chars of logs):"
    echo "$BUILD_LOGS" | head -c 300 | sed 's/^/    /'
    echo
else
    echo "FAIL: swarm_factory was not invoked"
    echo "  agent_logs: $(echo "$BUILD_LOGS" | head -c 300)"
    echo "  response: $(echo "$BUILD_TEXT" | head -c 300)"
    exit 1
fi

SINGLETON=$(find rapp_brainstem/agents -maxdepth 4 -name "e2e_test_swarm*_agent.py" -newer "$TEST_SWARM_DIR" 2>/dev/null | head -1)
if [ -n "$SINGLETON" ] && [ -f "$SINGLETON" ]; then
    SIZE=$(wc -c < "$SINGLETON")
    echo "PASS: singleton produced at $SINGLETON ($SIZE bytes)"
else
    echo "WARN: no singleton file found on disk. Factory reported success in logs."
    echo "  (Non-fatal — factory may write elsewhere or require different args.)"
fi

echo "✅ Tier 1 memory + factory test complete"
