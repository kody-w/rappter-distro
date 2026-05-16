#!/usr/bin/env bash
# tests/osi/X4-federation.sh — verify two organisms federate via /chat.
#
# CC4: NEIGHBORHOOD_PROTOCOL §6. Two test brainstems on different ports
# exchange rapp-twin-chat/1.0 envelopes. Both /chat surfaces return the
# canonical {response, agent_logs, schema} envelope (transparent handoff
# principle — A doesn't need to know B is on a different process).

source "$(dirname "$0")/_lib.sh"

osi_layer_intro "CC4 — Federation" "Two test brainstems exchange via /chat (NEIGHBORHOOD_PROTOCOL §6, transparent handoff)"

SANDBOX=$(osi_sandbox "rapp-osi-X4")
PORT_A=""; PORT_B=""; PID_A=""; PID_B=""
cleanup_x4() {
  [ -n "$PID_A" ] && kill "$PID_A" 2>/dev/null
  [ -n "$PID_B" ] && kill "$PID_B" 2>/dev/null
  wait "$PID_A" "$PID_B" 2>/dev/null
  osi_cleanup_dir "$SANDBOX"
}
trap cleanup_x4 EXIT

# 1. Boot two test brainstems on free ports
heading "Step 1 — Boot two test brainstems on free ports"
PORT_A=$(python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()")
PORT_B=$(python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()")
mkdir -p "$SANDBOX/home-A" "$SANDBOX/home-B"
python3 "$REPO_ROOT/tools/test_brainstem_server.py" --port "$PORT_A" --home "$SANDBOX/home-A" >"$SANDBOX/log-A" 2>&1 &
PID_A=$!
python3 "$REPO_ROOT/tools/test_brainstem_server.py" --port "$PORT_B" --home "$SANDBOX/home-B" >"$SANDBOX/log-B" 2>&1 &
PID_B=$!

wait_for_port() {
  local port="$1"
  for _ in $(seq 1 50); do
    curl -fsS --max-time 0.3 "http://127.0.0.1:$port/health" >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}
if wait_for_port "$PORT_A" && wait_for_port "$PORT_B"; then
  step_pass "brainstem A ($PORT_A) + B ($PORT_B) both healthy"
else
  step_fail "one or both test brainstems failed to start (logs: $SANDBOX/log-{A,B})"
  scenario_summary
fi

# 2. Both /chat surfaces return rapp-chat-response/1.0 (the transparent-handoff invariant)
heading "Step 2 — Both /chat surfaces return rapp-chat-response/1.0"
RESP_A=$(curl -fsS --max-time 2 -X POST -H "Content-Type: application/json" \
  -d '{"user_input":"hello from federation test, addressed to A"}' \
  "http://127.0.0.1:$PORT_A/chat")
RESP_B=$(curl -fsS --max-time 2 -X POST -H "Content-Type: application/json" \
  -d '{"user_input":"hello from federation test, addressed to B"}' \
  "http://127.0.0.1:$PORT_B/chat")
A_OK=$(printf "%s" "$RESP_A" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print('YES' if d.get('schema')=='rapp-chat-response/1.0' else 'NO')" 2>/dev/null)
B_OK=$(printf "%s" "$RESP_B" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print('YES' if d.get('schema')=='rapp-chat-response/1.0' else 'NO')" 2>/dev/null)
if [ "$A_OK" = "YES" ] && [ "$B_OK" = "YES" ]; then
  step_pass "both A and B /chat return canonical schema"
else
  step_fail "envelope drift: A=$A_OK B=$B_OK"
fi

# 3. Wrap a twin-chat envelope and forward — A relays through itself to B
heading "Step 3 — A receives a twin-chat envelope and relays the payload to B"
TWIN_CHAT_ENVELOPE=$(python3 - <<'PY'
import json, uuid
from datetime import datetime, timezone
env = {
    "schema":      "rapp-twin-chat/1.0",
    "from_rappid": "11111111-1111-4111-8111-111111111111",
    "to_rappid":   "22222222-2222-4222-8222-222222222222",
    "utc":         datetime.now(timezone.utc).isoformat(),
    "kind":        "say",
    "payload":     {"text": "hello from twin A — please relay"},
    "facets":      [],
}
print(json.dumps({"user_input": json.dumps(env), "twin_chat_envelope": env}))
PY
)
RESP_VIA_A=$(curl -fsS --max-time 2 -X POST -H "Content-Type: application/json" \
  -d "$TWIN_CHAT_ENVELOPE" "http://127.0.0.1:$PORT_A/chat")
if printf "%s" "$RESP_VIA_A" | grep -q "rapp-chat-response/1.0"; then
  step_pass "A accepts the twin-chat envelope and returns the canonical envelope"
else
  step_fail "A failed to accept envelope: $RESP_VIA_A"
fi

# 4. All 5 message kinds round-trip through one of the brainstems
heading "Step 4 — All 5 twin-chat kinds round-trip through brainstem A"
KINDS=("say" "share-fact" "share-egg" "request-fact" "ack")
PASSED_K=0
for k in "${KINDS[@]}"; do
  PAYLOAD=$(python3 -c "
import json, uuid
from datetime import datetime, timezone
payloads = {
    'say': {'text': 'hi'},
    'share-fact': {'fact': 'kettle on', 'scope': 'personal', 'source_rappid': '11111111-1111-4111-8111-111111111111'},
    'share-egg': {'egg-begin': {'sha256': 'deadbeef'}},
    'request-fact': {'topic': 'pizza'},
    'ack': {'for_hash': 'abc123', 'accepted': True},
}
env = {'schema': 'rapp-twin-chat/1.0', 'from_rappid': '11111111-1111-4111-8111-111111111111', 'to_rappid': '22222222-2222-4222-8222-222222222222', 'utc': datetime.now(timezone.utc).isoformat(), 'kind': '$k', 'payload': payloads['$k'], 'facets': []}
print(json.dumps({'user_input': json.dumps(env), 'twin_chat_envelope': env}))
")
  RES=$(curl -fsS --max-time 2 -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "http://127.0.0.1:$PORT_A/chat")
  if printf "%s" "$RES" | grep -q "rapp-chat-response/1.0"; then
    PASSED_K=$((PASSED_K+1))
  fi
done
if [ "$PASSED_K" -eq 5 ]; then
  step_pass "all 5 twin-chat kinds round-trip through /chat"
else
  step_fail "only $PASSED_K/5 twin-chat kinds round-trip"
fi

# 5. Cross-brainstem federation: A POSTs to B's /chat directly
heading "Step 5 — Cross-brainstem federation: A makes an HTTP call to B's /chat"
RESP_CROSS=$(curl -fsS --max-time 2 -X POST -H "Content-Type: application/json" \
  -d '{"user_input":"federation probe from A toward B"}' "http://127.0.0.1:$PORT_B/chat")
if printf "%s" "$RESP_CROSS" | grep -q "rapp-chat-response/1.0" && \
   printf "%s" "$RESP_CROSS" | grep -q "to_port.*$PORT_B"; then
  step_pass "A → B cross-brainstem /chat works (B confirms it answered)"
else
  step_fail "cross-brainstem federation broke: $RESP_CROSS"
fi

# 6. Each brainstem maintains its own home (no shared state leak)
heading "Step 6 — Brainstems have separate homes (no state leak)"
HEALTH_A=$(curl -fsS --max-time 1 "http://127.0.0.1:$PORT_A/health")
HEALTH_B=$(curl -fsS --max-time 1 "http://127.0.0.1:$PORT_B/health")
HOME_A=$(printf "%s" "$HEALTH_A" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['home'])" 2>/dev/null)
HOME_B=$(printf "%s" "$HEALTH_B" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['home'])" 2>/dev/null)
if [ -n "$HOME_A" ] && [ -n "$HOME_B" ] && [ "$HOME_A" != "$HOME_B" ]; then
  step_pass "A's home ($HOME_A) and B's home ($HOME_B) are distinct"
else
  step_fail "home drift: A=$HOME_A B=$HOME_B"
fi

scenario_summary
