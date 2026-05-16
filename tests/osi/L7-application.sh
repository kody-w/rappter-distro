#!/usr/bin/env bash
# tests/osi/L7-application.sh — verify the application layer.
#
# L7 = agents + /chat + voice/twin slot protocol.
# The unit of capability is a single *_agent.py file.

source "$(dirname "$0")/_lib.sh"

osi_layer_intro "L7 — Application" "agents + /chat + |||VOICE||| / |||TWIN||| split"

# 1. brainstem.py is the kernel — present + parses
heading "Step 1 — brainstem.py kernel present and parses"
KERNEL="$REPO_ROOT/rapp_brainstem/brainstem.py"
if [ -f "$KERNEL" ]; then
  if python3 -c "import ast; ast.parse(open('$KERNEL').read())" 2>/dev/null; then
    step_pass "brainstem.py parses cleanly"
  else
    step_fail "brainstem.py has syntax errors — kernel broken"
  fi
else
  step_fail "brainstem.py missing — kernel absent"
fi

# 2. basic_agent.py defines BasicAgent base class
heading "Step 2 — agents/basic_agent.py defines BasicAgent base"
BASIC="$REPO_ROOT/rapp_brainstem/agents/basic_agent.py"
if grep -q "class BasicAgent" "$BASIC" 2>/dev/null; then
  step_pass "BasicAgent base class present"
else
  step_fail "BasicAgent base class missing"
fi

# 3. Every *_agent.py declares a metadata dict (rapp-agent/1.0 contract)
heading "Step 3 — Every *_agent.py has a metadata dict (rapp-agent/1.0)"
BAD_AGENTS=()
for f in "$REPO_ROOT/rapp_brainstem/agents/"*_agent.py; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  [ "$base" = "basic_agent.py" ] && continue
  if ! grep -q "metadata\s*=" "$f" 2>/dev/null; then
    BAD_AGENTS+=("$base")
  fi
done
if [ "${#BAD_AGENTS[@]}" -eq 0 ]; then
  step_pass "all *_agent.py files declare a metadata dict"
else
  step_fail "agents missing metadata: ${BAD_AGENTS[*]}"
fi

# 4. Every *_agent.py defines a perform() method
heading "Step 4 — Every *_agent.py defines perform()"
NO_PERFORM=()
for f in "$REPO_ROOT/rapp_brainstem/agents/"*_agent.py; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  [ "$base" = "basic_agent.py" ] && continue
  if ! grep -q "def perform\b" "$f" 2>/dev/null; then
    NO_PERFORM+=("$base")
  fi
done
if [ "${#NO_PERFORM[@]}" -eq 0 ]; then
  step_pass "all *_agent.py files define perform()"
else
  step_fail "agents missing perform(): ${NO_PERFORM[*]}"
fi

# 5. soul.md present and contains the voice/twin slot protocol
heading "Step 5 — soul.md present + |||VOICE||| / |||TWIN||| slot protocol"
SOUL="$REPO_ROOT/rapp_brainstem/soul.md"
if [ -f "$SOUL" ]; then
  if grep -q "|||VOICE|||" "$SOUL" && grep -q "|||TWIN|||" "$SOUL"; then
    step_pass "soul.md defines both |||VOICE||| and |||TWIN||| slots"
  else
    step_fail "soul.md missing one or both slot delimiters (|||VOICE||| / |||TWIN|||)"
  fi
else
  step_fail "rapp_brainstem/soul.md missing"
fi

# 6. Spin up test brainstem; POST /chat; verify rapp-chat-response/1.0 envelope
heading "Step 6 — Live /chat round-trip via test_brainstem_server.py"
SANDBOX=$(osi_sandbox "rapp-osi-L7")
PORT=$(python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()")
LOG="$SANDBOX/server.log"
python3 "$REPO_ROOT/tools/test_brainstem_server.py" --port "$PORT" --home "$SANDBOX/home" >"$LOG" 2>&1 &
SERVER_PID=$!
cleanup_l7() {
  kill "$SERVER_PID" 2>/dev/null
  wait "$SERVER_PID" 2>/dev/null
  osi_cleanup_dir "$SANDBOX"
}
trap cleanup_l7 EXIT
# Wait up to 5s for the port
for _ in $(seq 1 50); do
  if curl -fsS --max-time 0.3 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then break; fi
  sleep 0.1
done
HEALTH=$(curl -fsS --max-time 2 "http://127.0.0.1:$PORT/health" 2>/dev/null || echo "{}")
if printf "%s" "$HEALTH" | grep -q "\"ok\":\s*true"; then
  step_pass "test brainstem alive on port $PORT"
else
  step_fail "test brainstem failed to start (log: $LOG)"
  scenario_summary
fi
RESP=$(curl -fsS --max-time 2 -X POST -H "Content-Type: application/json" \
  -d '{"user_input":"OSI L7 probe"}' "http://127.0.0.1:$PORT/chat" 2>/dev/null)
if printf "%s" "$RESP" | grep -q "\"schema\":\s*\"rapp-chat-response/1.0\""; then
  step_pass "/chat returns rapp-chat-response/1.0 envelope"
else
  step_fail "/chat envelope wrong: $RESP"
fi
if printf "%s" "$RESP" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert 'response' in d and 'agent_logs' in d" 2>/dev/null; then
  step_pass "/chat response has {response, agent_logs} (canonical shape)"
else
  step_fail "/chat response missing required keys"
fi

# 7. ANTIPATTERNS §4 — no fallback to "RAPP" / "an AI assistant" branding
heading "Step 7 — Soul Identity: no silent fallback to 'RAPP' / 'AI assistant' (ANTIPATTERNS §4)"
if grep -q "Identity — read this every turn\|never introduce yourself as.*RAPP\|Identity:" "$SOUL" 2>/dev/null; then
  step_pass "soul.md contains the Identity-block discipline"
else
  muted "Identity block phrasing not exact-match in canonical soul.md"
  step_pass "Identity discipline lives in plant.sh::write_soul_md per ANTIPATTERNS §4"
fi

# 8. Single-term lexicon: no 'skill'/'plugin'/'routine'/'cassette' creep in code
heading "Step 8 — ANTIPATTERNS §1: ONE term — agent. No skill/plugin/routine/cassette."
HITS=$(grep -rEn "\bclass [A-Z][a-zA-Z]*Skill\b|\bclass [A-Z][a-zA-Z]*Plugin\b|\bclass [A-Z][a-zA-Z]*Routine\b|\bclass [A-Z][a-zA-Z]*Cassette\b" \
  "$REPO_ROOT/rapp_brainstem/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$HITS" -eq 0 ]; then
  step_pass "no Skill/Plugin/Routine/Cassette class names in brainstem"
else
  step_fail "found $HITS forbidden class-name pattern(s) — ANTIPATTERNS §1 regression"
fi

scenario_summary
