#!/usr/bin/env bash
# Scenario 25 — Local-neighborhood simulation with multiple brainstems on
# the same machine. End-to-end across REAL HTTP between processes.
#
# Pattern: a "local neighborhood" is multiple brainstems on the same device
# subscribing to a shared seed (file://) and federating contributions over
# real localhost HTTP — exactly the topology twin_agent + perpetual_loop_factory
# create when they boot multiple twins as their own brainstems on different
# ports. This scenario uses tools/test_brainstem_server.py as a lightweight
# stand-in for two full Flask brainstems (it serves the same /api/neighborhoods/*
# surface), so the federation is exercised against actual cross-process HTTP.
#
# Phase 1 of the user's three-phase brief: same machine. Phase 2: cross
# Mac-mini on the LAN. Phase 3: vbrainstem mobile off-network.

source "$(dirname "$0")/_lib.sh"
scenario_parse_args "$@"

heading "Scenario 25 — Local-neighborhood simulation"
note "Pattern: 2 brainstems on this machine = a local neighborhood"
note "Showcases: real cross-process HTTP federation — no mocks, no stubs"

PORT_A=$((40000 + RANDOM % 1000))
PORT_B=$((40000 + RANDOM % 1000))
[ "$PORT_A" = "$PORT_B" ] && PORT_B=$((PORT_B + 1))
TMP=$(mktemp -d -t rapp-sim-XXXXXX)
HOME_A="$TMP/brainstem-A"
HOME_B="$TMP/brainstem-B"
SEED="$FIXTURES_DIR/local-only-test"
SEED_URL="file://$SEED"

cleanup() {
  if [ -n "${PID_A:-}" ] && kill -0 "$PID_A" 2>/dev/null; then kill "$PID_A" 2>/dev/null; fi
  if [ -n "${PID_B:-}" ] && kill -0 "$PID_B" 2>/dev/null; then kill "$PID_B" 2>/dev/null; fi
  rm -rf "$TMP"
}
trap cleanup EXIT

# 1. The two twin agents are present in rapp_brainstem/agents/
heading "Step 1 — twin_agent + perpetual_loop_factory live in rapp_brainstem/agents/"
for agent in twin_agent.py perpetual_loop_factory_agent.py; do
  if [ -f "$REPO_ROOT/rapp_brainstem/agents/$agent" ]; then
    step_pass "rapp_brainstem/agents/$agent present (auto-loads with every brainstem)"
  else
    step_fail "$agent missing from rapp_brainstem/agents/"
  fi
done

# 2. Both agents parse + advertise the right tool surface
heading "Step 2 — Twin agent surface (summon, hatch, boot, stop, list, ...)"
TWIN_OUT=$(python3 - <<'PY'
import importlib.util, json, os, sys, ast
sys.path.insert(0, os.path.join(os.environ["REPO_ROOT"], "rapp_brainstem"))
src = open(os.path.join(os.environ["REPO_ROOT"], "rapp_brainstem", "agents", "twin_agent.py")).read()
tree = ast.parse(src)
# Find ACTIONS tuple
actions = None
for node in ast.walk(tree):
    if isinstance(node, ast.Assign):
        for t in node.targets:
            if isinstance(t, ast.Name) and t.id == "ACTIONS":
                if isinstance(node.value, ast.Tuple):
                    actions = [el.value for el in node.value.elts if isinstance(el, ast.Constant)]
print(json.dumps(actions or []))
PY
)
REPO_ROOT="$REPO_ROOT" \
TWIN_OUT_REAL=$(REPO_ROOT="$REPO_ROOT" python3 - <<'PY'
import ast, json, os
src = open(os.path.join(os.environ["REPO_ROOT"], "rapp_brainstem", "agents", "twin_agent.py")).read()
tree = ast.parse(src)
actions = []
for node in ast.walk(tree):
    if isinstance(node, ast.Assign):
        for t in node.targets:
            if isinstance(t, ast.Name) and t.id == "ACTIONS":
                if isinstance(node.value, ast.Tuple):
                    actions = [el.value for el in node.value.elts if isinstance(el, ast.Constant)]
print(json.dumps(actions))
PY
)
for needed in summon hatch boot stop list lay_egg; do
  if echo "$TWIN_OUT_REAL" | grep -q "\"$needed\""; then
    step_pass "twin_agent exposes action: $needed"
  else
    step_fail "twin_agent missing action: $needed"
  fi
done

# 3. PerpetualLoopFactory is well-formed
heading "Step 3 — PerpetualLoopFactory advertises the loop lifecycle"
PLF=$(REPO_ROOT="$REPO_ROOT" python3 - <<'PY'
import ast, json, os
src = open(os.path.join(os.environ["REPO_ROOT"], "rapp_brainstem", "agents", "perpetual_loop_factory_agent.py")).read()
tree = ast.parse(src)
actions = []
for node in ast.walk(tree):
    if isinstance(node, ast.Assign):
        for t in node.targets:
            if isinstance(t, ast.Name) and t.id == "ACTIONS":
                if isinstance(node.value, ast.Tuple):
                    actions = [el.value for el in node.value.elts if isinstance(el, ast.Constant)]
print(json.dumps(actions))
PY
)
for needed in spawn list stop status help; do
  if echo "$PLF" | grep -q "\"$needed\""; then
    step_pass "PerpetualLoopFactory exposes action: $needed"
  else
    step_fail "PerpetualLoopFactory missing action: $needed"
  fi
done

# 4. Spin up two test-brainstem-servers as the local neighborhood
heading "Step 4 — Spin up 2 brainstems on this machine"
mkdir -p "$HOME_A" "$HOME_B"
python3 "$REPO_ROOT/tools/test_brainstem_server.py" --port "$PORT_A" --home "$HOME_A" >/tmp/bs-a.log 2>&1 &
PID_A=$!
python3 "$REPO_ROOT/tools/test_brainstem_server.py" --port "$PORT_B" --home "$HOME_B" >/tmp/bs-b.log 2>&1 &
PID_B=$!

wait_for_port() {
  local port=$1; local tries=0
  while [ $tries -lt 50 ]; do
    if curl -sf -o /dev/null --max-time 1 "http://127.0.0.1:$port/health"; then return 0; fi
    sleep 0.1; tries=$((tries + 1))
  done
  return 1
}

if wait_for_port "$PORT_A"; then step_pass "brainstem A live at :$PORT_A (pid $PID_A)"
else step_fail "brainstem A did not bind to :$PORT_A"; cat /tmp/bs-a.log | head -10; fi

if wait_for_port "$PORT_B"; then step_pass "brainstem B live at :$PORT_B (pid $PID_B)"
else step_fail "brainstem B did not bind to :$PORT_B"; cat /tmp/bs-b.log | head -10; fi

# 5. Health endpoints return brainstem-shaped JSON
heading "Step 5 — Both /health return real responses"
HA=$(curl -sf "http://127.0.0.1:$PORT_A/health" 2>/dev/null)
HB=$(curl -sf "http://127.0.0.1:$PORT_B/health" 2>/dev/null)
if echo "$HA" | grep -q '"ok": true' && echo "$HA" | grep -q '"port"'; then step_pass "A /health: ok"
else step_fail "A /health: $HA"; fi
if echo "$HB" | grep -q '"ok": true' && echo "$HB" | grep -q '"port"'; then step_pass "B /health: ok"
else step_fail "B /health: $HB"; fi

# 6. Both subscribe to the local neighborhood (file://)
heading "Step 6 — Both brainstems join the same local neighborhood"
JOIN_A=$(curl -sf -X POST "http://127.0.0.1:$PORT_A/api/neighborhoods/join" \
  -H 'content-type: application/json' \
  -d "{\"gate_url\":\"$SEED_URL\"}")
JOIN_B=$(curl -sf -X POST "http://127.0.0.1:$PORT_B/api/neighborhoods/join" \
  -H 'content-type: application/json' \
  -d "{\"gate_url\":\"$SEED_URL\"}")
if echo "$JOIN_A" | grep -q '"joined": true'; then step_pass "A subscribed to neighborhood"
else step_fail "A subscription failed: $JOIN_A"; fi
if echo "$JOIN_B" | grep -q '"joined": true'; then step_pass "B subscribed to neighborhood"
else step_fail "B subscription failed: $JOIN_B"; fi

# 7. Federate: A POSTs a contribution to B's /contribute over real HTTP
heading "Step 7 — Real cross-process HTTP federation: A → B"
CONTRIB_PAYLOAD='{
  "request_id": "twin-chat-1",
  "from_peer": "twin-A@localhost:'"$PORT_A"'",
  "contribution": {
    "schema": "rapp-braintrust-contribution/1.0",
    "request_id": "twin-chat-1",
    "contributor": {"github_login": "twin-a", "rappid": "00000000-aaaa-aaaa-aaaa-000000000001"},
    "captured_at": "2026-05-08T22:00:00Z",
    "library_kinds_searched": ["files"],
    "findings": [{"snippet": "twin A says hello over real HTTP", "source": {"kind": "files", "ref": "/twin-a-notes.md"}, "confidence": 0.92}]
  }
}'
RESP=$(curl -sS -X POST "http://127.0.0.1:$PORT_B/api/neighborhoods/local/local-only-test/contribute" \
  -H 'content-type: application/json' \
  -d "$CONTRIB_PAYLOAD")
if echo "$RESP" | grep -q '"received": true'; then
  step_pass "B accepted contribution from A (real HTTP, pid $PID_A → pid $PID_B)"
else
  step_fail "federate A→B failed: $RESP"
fi

# 8. B reciprocates back to A
heading "Step 8 — B reciprocates: B → A"
CONTRIB_PAYLOAD2='{
  "request_id": "twin-chat-1",
  "from_peer": "twin-B@localhost:'"$PORT_B"'",
  "contribution": {
    "schema": "rapp-braintrust-contribution/1.0",
    "request_id": "twin-chat-1",
    "contributor": {"github_login": "twin-b", "rappid": "00000000-bbbb-bbbb-bbbb-000000000002"},
    "captured_at": "2026-05-08T22:00:01Z",
    "library_kinds_searched": ["memory"],
    "findings": [{"snippet": "twin B replies — chain established", "source": {"kind": "memory", "ref": "/mem/last"}, "confidence": 0.88}]
  }
}'
RESP2=$(curl -sS -X POST "http://127.0.0.1:$PORT_A/api/neighborhoods/local/local-only-test/contribute" \
  -H 'content-type: application/json' \
  -d "$CONTRIB_PAYLOAD2")
if echo "$RESP2" | grep -q '"received": true'; then
  step_pass "A accepted reciprocal contribution from B"
else
  step_fail "federate B→A failed: $RESP2"
fi

# 9. Both list contributions and find the right one
heading "Step 9 — Each brainstem holds the contribution it received"
LIST_B=$(curl -sf "http://127.0.0.1:$PORT_B/api/neighborhoods/local/local-only-test/contributions")
LIST_A=$(curl -sf "http://127.0.0.1:$PORT_A/api/neighborhoods/local/local-only-test/contributions")

if echo "$LIST_B" | grep -q "twin-a" && echo "$LIST_B" | grep -q "twin-A@localhost:$PORT_A"; then
  step_pass "B's contributions list shows twin-a's contribution with from_peer provenance"
else
  step_fail "B does not show A's contribution: $LIST_B"
fi

if echo "$LIST_A" | grep -q "twin-b" && echo "$LIST_A" | grep -q "twin-B@localhost:$PORT_B"; then
  step_pass "A's contributions list shows twin-b's reciprocal with from_peer provenance"
else
  step_fail "A does not show B's contribution: $LIST_A"
fi

# 10. Estate views show the subscription on each brainstem
heading "Step 10 — Each brainstem's estate view sees the shared neighborhood"
EST_A=$(curl -sf "http://127.0.0.1:$PORT_A/api/neighborhoods/estate")
EST_B=$(curl -sf "http://127.0.0.1:$PORT_B/api/neighborhoods/estate")
if echo "$EST_A" | grep -q '"subscription_count": 1'; then step_pass "A estate: 1 subscription"
else step_fail "A estate: $EST_A"; fi
if echo "$EST_B" | grep -q '"subscription_count": 1'; then step_pass "B estate: 1 subscription"
else step_fail "B estate: $EST_B"; fi

# 11. Both subscriptions point at the same neighborhood_rappid
heading "Step 11 — Same neighborhood_rappid on both brainstems (one neighborhood, two members)"
RA=$(curl -sf "http://127.0.0.1:$PORT_A/api/neighborhoods" | python3 -c "import json,sys; subs=json.load(sys.stdin)['subscriptions']; print(subs[0]['neighborhood_rappid'] if subs else '')")
RB=$(curl -sf "http://127.0.0.1:$PORT_B/api/neighborhoods" | python3 -c "import json,sys; subs=json.load(sys.stdin)['subscriptions']; print(subs[0]['neighborhood_rappid'] if subs else '')")
if [ -n "$RA" ] && [ "$RA" = "$RB" ]; then
  step_pass "both brainstems hold the same neighborhood_rappid: $RA"
else
  step_fail "rappid mismatch: A=$RA B=$RB"
fi

# 12. The unified federation primitive: Twin.chat = POST /chat to peer URL
#     Same pattern works on-LAN (this test) and over the public internet
#     (just change the URL). Local-first: the URL lookup never requires
#     GitHub, so when the internet drops, on-LAN federation keeps working.
heading "Step 12 — Twin.chat unified primitive (works on-LAN AND over public internet)"
TWIN_OUT=$(REPO_ROOT="$REPO_ROOT" PEER_URL="http://127.0.0.1:$PORT_B" python3 - <<'PY'
import importlib.util, json, os, sys
sys.path.insert(0, os.path.join(os.environ["REPO_ROOT"], "rapp_brainstem"))
spec = importlib.util.spec_from_file_location("ta", os.path.join(os.environ["REPO_ROOT"], "rapp_brainstem", "agents", "twin_agent.py"))
ta = importlib.util.module_from_spec(spec); spec.loader.exec_module(ta)
agent = ta.TwinAgent()
out = agent.perform(
    action="chat",
    brainstem_url=os.environ["PEER_URL"],
    message="hello from twin A — federate using the unified Twin.chat primitive",
    timeout_s=5,
)
print(out)
PY
)
if echo "$TWIN_OUT" | grep -q "rapp-twin-chat-response/1.0" && \
   echo "$TWIN_OUT" | grep -q '"response":' && \
   echo "$TWIN_OUT" | grep -q "test brainstem at :$PORT_B"; then
  step_pass "Twin.chat → peer brainstem /chat → canonical {response, agent_logs} shape"
else
  step_fail "Twin.chat unified primitive failed: $TWIN_OUT"
fi

# 13. Demonstrate location-agnostic property: same call shape would work
#     against a public-internet URL. The peer URL is the only thing that
#     changes between LAN and public.
heading "Step 13 — Same call shape, any URL: location-agnostic federation"
TWIN_OUT2=$(REPO_ROOT="$REPO_ROOT" PEER_URL="http://127.0.0.1:$PORT_A" python3 - <<'PY'
import importlib.util, json, os, sys
sys.path.insert(0, os.path.join(os.environ["REPO_ROOT"], "rapp_brainstem"))
spec = importlib.util.spec_from_file_location("ta", os.path.join(os.environ["REPO_ROOT"], "rapp_brainstem", "agents", "twin_agent.py"))
ta = importlib.util.module_from_spec(spec); spec.loader.exec_module(ta)
out = ta.TwinAgent().perform(
    action="chat",
    brainstem_url=os.environ["PEER_URL"],
    message="reciprocal chat from twin B",
    timeout_s=5,
)
print(out)
PY
)
if echo "$TWIN_OUT2" | grep -q '"response":' && echo "$TWIN_OUT2" | grep -q "test brainstem at :$PORT_A"; then
  step_pass "Twin.chat reciprocal call works (same code path, different URL)"
else
  step_fail "reciprocal Twin.chat failed: $TWIN_OUT2"
fi

# 14. Graceful failure when peer is unreachable — fallback hint surfaced
heading "Step 14 — Twin.chat to dead peer returns clear next-step (no crash)"
TWIN_DEAD=$(REPO_ROOT="$REPO_ROOT" python3 - <<'PY'
import importlib.util, json, os, sys
sys.path.insert(0, os.path.join(os.environ["REPO_ROOT"], "rapp_brainstem"))
spec = importlib.util.spec_from_file_location("ta", os.path.join(os.environ["REPO_ROOT"], "rapp_brainstem", "agents", "twin_agent.py"))
ta = importlib.util.module_from_spec(spec); spec.loader.exec_module(ta)
out = ta.TwinAgent().perform(
    action="chat",
    brainstem_url="http://127.0.0.1:1",  # unreachable
    message="this should fail gracefully",
    timeout_s=2,
)
print(out)
PY
)
if echo "$TWIN_DEAD" | grep -q '"ok": false' && echo "$TWIN_DEAD" | grep -q "GitHub Issue"; then
  step_pass "unreachable peer → clear error + fallback to async GitHub Issue"
else
  step_fail "graceful-fail expected but got: $TWIN_DEAD"
fi

heading "Why this matters"
cat <<EOF
  This is THE local neighborhood: two brainstems on this machine joined
  to a shared neighborhood, federating contributions across real HTTP
  between processes. No mocks. No stubs. Two real listeners on real
  ports talking real protocol.

  In production, twin_agent + perpetual_loop_factory boot N twins as
  their own brainstems on their own ports. Each twin auto-loads the
  membership organ (since twin_agent's _boot copies the parent's
  start.sh / brainstem.py via env vars). They subscribe to the same
  neighborhood. They federate via the same /api/neighborhoods/<slug>/
  contribute endpoint exercised here.

  Phase 2 (next): same scenario with brainstems on different Mac minis
  reachable on the LAN. Replace 127.0.0.1 with the LAN IP — same protocol.

  Phase 3: vbrainstem (browser) on a phone off the local network joins
  via GitHub Issue-comment posting, with results aggregated by the
  same membership organ.

  Local URLs that just worked:
    http://127.0.0.1:$PORT_A/health
    http://127.0.0.1:$PORT_B/health
    http://127.0.0.1:$PORT_A/api/neighborhoods/estate
    http://127.0.0.1:$PORT_B/api/neighborhoods/local/local-only-test/contributions
EOF

scenario_summary
