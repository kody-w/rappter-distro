#!/bin/bash
# tests/test-agents-api.sh — exercise the agent-manager backend API
# (Article XVIII / XIII — UI is a view onto agents/).
#
# Spins up a fresh brainstem on a test port, drives /api/agents/*
# routes, verifies every write op = a filesystem mutation.
#
#     bash tests/test-agents-api.sh
#
# Exits 0 on success, non-zero with diagnostics on failure.

set -e
set -o pipefail

PORT=7192
TEST_HOME="/tmp/rapp-agents-api-test-$$"
AGENTS_DIR="$TEST_HOME/agents"
SERVER_PID=""
PASS=0
FAIL=0
FAIL_NAMES=()

cleanup() {
    [ -n "$SERVER_PID" ] && kill $SERVER_PID 2>/dev/null || true
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

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
        echo "      haystack:  $(echo "$haystack" | head -c 200)"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

assert_path_exists() {
    local name="$1" path="$2"
    if [ -e "$path" ]; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name (missing: $path)"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

assert_path_missing() {
    local name="$1" path="$2"
    if [ ! -e "$path" ]; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name (unexpectedly exists: $path)"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

# ── Setup ──────────────────────────────────────────────────────────────
cd "$(dirname "$0")/.."

rm -rf "$TEST_HOME"
mkdir -p "$AGENTS_DIR"

# Seed the agents/ tree with a minimal starter set (the real ones plus an
# engine-reserved system_agents subdir, so the UI will see the shape).
cp rapp_brainstem/agents/basic_agent.py         "$AGENTS_DIR/"
cp rapp_brainstem/agents/hacker_news_agent.py   "$AGENTS_DIR/"
mkdir -p "$AGENTS_DIR/workspace_agents/system_agents"
cp rapp_brainstem/agents/workspace_agents/system_agents/swarm_factory_agent.py "$AGENTS_DIR/workspace_agents/system_agents/"

# Point brainstem at the sandbox home for memory, token, swarms state.
export BRAINSTEM_MEMORY_PATH="$TEST_HOME/memory.json"
export BRAINSTEM_SWARMS_FILE="$TEST_HOME/swarms.json"
export BRAINSTEM_COPILOT_TOKEN_FILE="$TEST_HOME/copilot_token"
export BRAINSTEM_COPILOT_SESSION_FILE="$TEST_HOME/copilot_session"
export SOUL_PATH="$TEST_HOME/soul.md"

AGENTS_PATH="$AGENTS_DIR" PORT=$PORT LLM_FAKE=1 \
    python3 -u rapp_brainstem/brainstem.py > "$TEST_HOME/server.log" 2>&1 &
SERVER_PID=$!
sleep 2.5

# ── Section 1: tree ────────────────────────────────────────────────────
echo "--- Section 1: GET /api/agents/tree ---"
TREE=$(curl -s http://127.0.0.1:$PORT/api/agents/tree)
assert_contains "tree has root name 'agents'"    '"name":"agents"'  "$TREE"
assert_contains "tree has basic_agent.py"        "basic_agent.py"        "$TREE"
assert_contains "tree has hacker_news_agent.py"  "hacker_news_agent.py"  "$TREE"
assert_contains "tree has system_agents folder"  "system_agents"         "$TREE"
assert_contains "system_agents marked reserved"  '"reserved":"system_agents"'  "$TREE"

# ── Section 2: templates ───────────────────────────────────────────────
echo ""
echo "--- Section 2: GET /api/agents/templates ---"
TPLS=$(curl -s http://127.0.0.1:$PORT/api/agents/templates)
assert_contains "templates list has echo"           '"id":"echo"'           "$TPLS"
assert_contains "templates list has http_get"       '"id":"http_get"'       "$TPLS"
assert_contains "templates list has note_taker"     '"id":"note_taker"'     "$TPLS"
assert_contains "templates list has persona"        '"id":"persona"'        "$TPLS"
assert_contains "templates list has slack_notifier" '"id":"slack_notifier"' "$TPLS"

# ── Section 3: mkdir ───────────────────────────────────────────────────
echo ""
echo "--- Section 3: POST /api/agents/mkdir ---"
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/agents/mkdir \
    -H "Content-Type: application/json" -d '{"path":"sales_stack"}')
assert_contains "mkdir sales_stack: ok"  '"status":"ok"'  "$RESP"
assert_path_exists "mkdir created dir"  "$AGENTS_DIR/sales_stack"

RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/agents/mkdir \
    -H "Content-Type: application/json" -d '{"path":"sales_stack/q4/prospects"}')
assert_contains "mkdir nested 3-deep: ok" '"status":"ok"'  "$RESP"
assert_path_exists "mkdir created nested dir" "$AGENTS_DIR/sales_stack/q4/prospects"

# Path traversal rejection
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:$PORT/api/agents/mkdir \
    -H "Content-Type: application/json" -d '{"path":"../escape"}')
assert_eq "mkdir rejects path traversal (400)" "400" "$CODE"
assert_path_missing "no escape dir created" "$(dirname "$AGENTS_DIR")/escape"

# ── Section 4: new agent from template ─────────────────────────────────
echo ""
echo "--- Section 4: POST /api/agents/new ---"
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/agents/new \
    -H "Content-Type: application/json" \
    -d '{"folder":"sales_stack","agent_name":"ProspectGreeter","template_id":"echo"}')
assert_contains "new agent: ok"       '"status":"ok"'                      "$RESP"
assert_contains "new agent name"      '"agent_name":"ProspectGreeter"'     "$RESP"
assert_path_exists "new agent file written" "$AGENTS_DIR/sales_stack/prospectgreeter_agent.py"
grep -q "class ProspectGreeterAgent(BasicAgent)" "$AGENTS_DIR/sales_stack/prospectgreeter_agent.py" \
    && { echo "  ✓ new agent class body correctly templated"; PASS=$((PASS+1)); } \
    || { echo "  ✗ new agent class body wrong"; FAIL=$((FAIL+1)); FAIL_NAMES+=("tpl-body"); }

# Duplicate new agent → conflict
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:$PORT/api/agents/new \
    -H "Content-Type: application/json" \
    -d '{"folder":"sales_stack","agent_name":"ProspectGreeter","template_id":"echo"}')
assert_eq "new agent duplicate rejected (409)" "409" "$CODE"

# Unknown template → 400
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:$PORT/api/agents/new \
    -H "Content-Type: application/json" \
    -d '{"folder":"sales_stack","agent_name":"X","template_id":"nope"}')
assert_eq "new agent unknown template rejected (400)" "400" "$CODE"

# ── Section 5: move (rename + between folders + disable) ───────────────
echo ""
echo "--- Section 5: POST /api/agents/move ---"
# Rename
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/agents/move \
    -H "Content-Type: application/json" \
    -d '{"from_path":"sales_stack/prospectgreeter_agent.py","to_path":"sales_stack/greeter_agent.py"}')
assert_contains "rename: ok"  '"status":"ok"'  "$RESP"
assert_path_missing "old name gone"    "$AGENTS_DIR/sales_stack/prospectgreeter_agent.py"
assert_path_exists  "new name present" "$AGENTS_DIR/sales_stack/greeter_agent.py"

# Move between folders (disable by moving into disabled_agents)
mkdir -p "$AGENTS_DIR/disabled_agents"
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/agents/move \
    -H "Content-Type: application/json" \
    -d '{"from_path":"sales_stack/greeter_agent.py","to_path":"disabled_agents/greeter_agent.py"}')
assert_contains "move to disabled: ok" '"status":"ok"'  "$RESP"
assert_path_exists "now in disabled" "$AGENTS_DIR/disabled_agents/greeter_agent.py"

# Re-enable (move back)
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/agents/move \
    -H "Content-Type: application/json" \
    -d '{"from_path":"disabled_agents/greeter_agent.py","to_path":"sales_stack/greeter_agent.py"}')
assert_contains "move back (re-enable): ok" '"status":"ok"'  "$RESP"
assert_path_exists "re-enabled" "$AGENTS_DIR/sales_stack/greeter_agent.py"

# Move to existing path → 409
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/agents/move \
    -H "Content-Type: application/json" \
    -d '{"from_path":"basic_agent.py","to_path":"hacker_news_agent.py"}')
assert_contains "move onto existing rejected" "destination exists"  "$RESP"

# Path traversal on from
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:$PORT/api/agents/move \
    -H "Content-Type: application/json" \
    -d '{"from_path":"../etc/passwd","to_path":"sales_stack/pwn.py"}')
assert_eq "move rejects path traversal (400)" "400" "$CODE"

# ── Section 6: delete ──────────────────────────────────────────────────
echo ""
echo "--- Section 6: POST /api/agents/delete ---"
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/agents/delete \
    -H "Content-Type: application/json" \
    -d '{"path":"sales_stack/greeter_agent.py"}')
assert_contains "delete file: ok"  '"status":"ok"'  "$RESP"
assert_path_missing "file gone" "$AGENTS_DIR/sales_stack/greeter_agent.py"

# Can't delete a reserved subdir
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:$PORT/api/agents/delete \
    -H "Content-Type: application/json" -d '{"path":"system_agents"}')
assert_eq "can't delete reserved system_agents (403)" "403" "$CODE"
assert_path_exists "system_agents still here" "$AGENTS_DIR/system_agents"

# ── Section 7: folder-group enable/disable ────────────────────────────
echo ""
echo "--- Section 7: POST /api/agents/folder-toggle ---"
# Create a folder + agent, confirm it loads
mkdir -p "$AGENTS_DIR/group_test"
cat > "$AGENTS_DIR/group_test/alpha_agent.py" <<'PY'
from agents.basic_agent import BasicAgent
import json
class AlphaAgent(BasicAgent):
    def __init__(self):
        self.name = "Alpha"
        self.metadata = {"name": self.name, "description": "x", "parameters": {"type":"object","properties":{},"required":[]}}
        super().__init__(name=self.name, metadata=self.metadata)
    def perform(self, **kw): return json.dumps({"status":"success"})
PY

BEFORE=$(curl -s http://127.0.0.1:$PORT/api/agents/tree | python3 -c "
import json, sys
t = json.load(sys.stdin)
def find(n, p):
    if n['path']==p: return n
    for c in n.get('children',[]) or []:
        r=find(c,p)
        if r: return r
n = find(t, 'group_test')
print('yes' if n else 'no')
")
assert_eq "folder group_test present in tree" "yes" "$BEFORE"

# Disable the folder
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/agents/folder-toggle \
    -H 'Content-Type: application/json' -d '{"path":"group_test","enabled":false}')
assert_contains "folder-toggle disable: ok" '"status":"ok"' "$RESP"
assert_contains "folder-toggle reports enabled=false" '"enabled":false' "$RESP"
assert_path_exists "marker written" "$AGENTS_DIR/group_test/.folder_disabled"

# Tree reflects disabled state
DISABLED=$(curl -s http://127.0.0.1:$PORT/api/agents/tree | python3 -c "
import json, sys
t = json.load(sys.stdin)
def find(n, p):
    if n['path']==p: return n
    for c in n.get('children',[]) or []:
        r=find(c,p)
        if r: return r
n = find(t, 'group_test')
print('yes' if n and n.get('folder_disabled') else 'no')
")
assert_eq "tree reports folder_disabled=true" "yes" "$DISABLED"

# Re-enable
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/agents/folder-toggle \
    -H 'Content-Type: application/json' -d '{"path":"group_test","enabled":true}')
assert_contains "folder-toggle enable: ok" '"status":"ok"' "$RESP"
assert_path_missing "marker removed" "$AGENTS_DIR/group_test/.folder_disabled"

# Reserved dir is forbidden
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:$PORT/api/agents/folder-toggle \
    -H 'Content-Type: application/json' -d '{"path":"system_agents","enabled":false}')
assert_eq "folder-toggle refuses reserved dir (403)" "403" "$CODE"

# Not-a-folder is rejected
echo "dummy" > "$AGENTS_DIR/group_test/some_file.txt"
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:$PORT/api/agents/folder-toggle \
    -H 'Content-Type: application/json' -d '{"path":"group_test/some_file.txt","enabled":false}')
assert_eq "folder-toggle rejects non-folder (400)" "400" "$CODE"


# ── Section 8: config get/set ──────────────────────────────────────────
echo ""
echo "--- Section 7: /api/config ---"
RESP=$(curl -s http://127.0.0.1:$PORT/api/config)
assert_contains "config has soul field"           "\"soul\":"       "$RESP"
assert_contains "config has env field"            "\"env\":"        "$RESP"
assert_contains "config has secrets presence map" "\"secrets\":"    "$RESP"

# Update soul
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/config/soul \
    -H "Content-Type: application/json" -d '{"soul":"new persona for test"}')
assert_contains "POST /api/config/soul: ok" '"status":"ok"' "$RESP"
RESP=$(curl -s http://127.0.0.1:$PORT/api/config)
assert_contains "soul round-trips" "new persona for test" "$RESP"

# Update env (whitelisted keys only)
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/config/env \
    -H "Content-Type: application/json" \
    -d '{"values":{"GITHUB_MODEL":"gpt-4.1","DISALLOWED":"pwn"}}')
assert_contains "env update accepts GITHUB_MODEL" "GITHUB_MODEL" "$RESP"
assert_eq "env update silently drops disallowed keys" \
    "$(echo "$RESP" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["updated"]))')" "1"

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "  $PASS passed, $FAIL failed"
echo "════════════════════════════════════════"
if [ $FAIL -gt 0 ]; then
    for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done
    exit 1
fi
exit 0
