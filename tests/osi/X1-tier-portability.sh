#!/usr/bin/env bash
# tests/osi/X1-tier-portability.sh — verify the same agent file runs
# unmodified across all three tiers.
#
# CC1: CONSTITUTION Article XV — tier parity is a /chat contract, not a
# transport. Same *_agent.py files; same {response, agent_logs} envelope;
# storage backend may differ.

source "$(dirname "$0")/_lib.sh"

osi_layer_intro "CC1 — Tier portability" "Same *_agent.py runs on Tier 1 (local Flask), Tier 2 (Azure Functions), Tier 3 (Copilot Studio bundle)"

# 1. Tier 1: brainstem.py present + parses
heading "Step 1 — Tier 1 (local Flask) kernel intact"
if python3 -c "import ast; ast.parse(open('$REPO_ROOT/rapp_brainstem/brainstem.py').read())" 2>/dev/null; then
  step_pass "rapp_brainstem/brainstem.py parses"
else
  step_fail "brainstem.py syntax error — Tier 1 broken"
fi

# 2. Tier 2: function_app.py present + parses
heading "Step 2 — Tier 2 (Azure Functions) function_app.py intact"
T2="$REPO_ROOT/rapp_swarm/function_app.py"
if [ -f "$T2" ] && python3 -c "import ast; ast.parse(open('$T2').read())" 2>/dev/null; then
  step_pass "rapp_swarm/function_app.py parses"
else
  step_fail "function_app.py missing or has syntax errors — Tier 2 broken"
fi

# 3. Tier 2: vendoring discipline — _vendored/ exists OR build.sh present
heading "Step 3 — Tier 2 vendoring (_vendored/ or build.sh)"
T2_VEND="$REPO_ROOT/rapp_swarm/_vendored"
T2_BUILD="$REPO_ROOT/rapp_swarm/build.sh"
if [ -d "$T2_VEND" ] || [ -f "$T2_BUILD" ]; then
  step_pass "vendoring path present (_vendored/ exists or build.sh ready to run)"
else
  step_fail "Tier 2 vendoring discipline broken — no _vendored/ and no build.sh"
fi

# 4. Tier 3: Copilot Studio bundle present
heading "Step 4 — Tier 3 (Copilot Studio) bundle present"
T3=$(ls "$REPO_ROOT/installer/"MSFTAIBASMultiAgentCopilot_*.zip 2>/dev/null | head -1)
if [ -n "$T3" ] && [ -f "$T3" ]; then
  SIZE=$(du -k "$T3" | awk '{print $1}')
  step_pass "Tier 3 bundle present ($T3, ${SIZE}KB)"
else
  step_fail "Tier 3 bundle (installer/MSFTAIBASMultiAgentCopilot_*.zip) missing"
fi

# 5. Cross-tier import: every agent imports cleanly without depending on Flask/Azure-specific symbols
heading "Step 5 — Agents are tier-portable (no Flask/Azure imports)"
COUPLED=()
for f in "$REPO_ROOT/rapp_brainstem/agents/"*_agent.py; do
  [ -e "$f" ] || continue
  if grep -qE "^import (flask|azure|fastapi)\b|^from (flask|azure|fastapi)\b" "$f" 2>/dev/null; then
    COUPLED+=("$(basename "$f")")
  fi
done
if [ "${#COUPLED[@]}" -eq 0 ]; then
  step_pass "no agent imports Flask/Azure/FastAPI directly — tier portable"
else
  step_fail "agents coupled to a tier-specific framework: ${COUPLED[*]}"
fi

# 6. /chat envelope is the same shape on Tier 1 and the test brainstem (Tier 2 surrogate)
heading "Step 6 — /chat envelope shape: {response, agent_logs} on both tiers"
SANDBOX=$(osi_sandbox "rapp-osi-X1")
PORT=$(python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()")
python3 "$REPO_ROOT/tools/test_brainstem_server.py" --port "$PORT" --home "$SANDBOX/home" >"$SANDBOX/log" 2>&1 &
SERVER_PID=$!
cleanup_x1() {
  kill "$SERVER_PID" 2>/dev/null
  wait "$SERVER_PID" 2>/dev/null
  osi_cleanup_dir "$SANDBOX"
}
trap cleanup_x1 EXIT
for _ in $(seq 1 50); do
  curl -fsS --max-time 0.3 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  sleep 0.1
done
RESP=$(curl -fsS --max-time 2 -X POST -H "Content-Type: application/json" \
  -d '{"user_input":"tier portability probe"}' "http://127.0.0.1:$PORT/chat" 2>/dev/null)
if printf "%s" "$RESP" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert {'response','agent_logs','schema'}.issubset(d.keys()) and d['schema'].startswith('rapp-chat-response/')" 2>/dev/null; then
  step_pass "/chat envelope matches canonical {response, agent_logs, schema:rapp-chat-response/*}"
else
  step_fail "/chat envelope drift: $RESP"
fi

# 7. Agent contract: rapp-agent/1.0 metadata works regardless of tier
heading "Step 7 — rapp-agent/1.0 metadata uniform across agents"
GOOD=0
TOTAL=0
for f in "$REPO_ROOT/rapp_brainstem/agents/"*_agent.py; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  [ "$base" = "basic_agent.py" ] && continue
  TOTAL=$((TOTAL+1))
  if grep -q "metadata\s*=" "$f" && grep -q "def perform" "$f"; then
    GOOD=$((GOOD+1))
  fi
done
if [ "$GOOD" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
  step_pass "$GOOD/$TOTAL agents satisfy rapp-agent/1.0 contract"
else
  step_fail "$GOOD/$TOTAL agents satisfy rapp-agent/1.0 (gap exposed)"
fi

scenario_summary
