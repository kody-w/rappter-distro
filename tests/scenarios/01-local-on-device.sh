#!/usr/bin/env bash
# Scenario 1 — Local on-device neighborhood.
#
# Verifies the membership organ's file:// local-mode flow: a brainstem
# subscribes to a seed directly from disk, no GitHub round-trip, no auth.
# Used for the on-device hero scenario where two brainstems on the same
# machine share a neighborhood without anyone going to the network.
#
# Run:
#     bash tests/scenarios/01-local-on-device.sh
#     bash tests/scenarios/01-local-on-device.sh --dry-run

source "$(dirname "$0")/_lib.sh"
scenario_parse_args "$@"

heading "Scenario 1 — Local on-device neighborhood"
note "Seed: $FIXTURES_DIR/local-only-test"
note "Mode: file:// (no GitHub, no auth)"

SEED="$FIXTURES_DIR/local-only-test"
SEED_URL="file://$SEED"

# 1. Seed exists + is well-formed
if [ ! -f "$SEED/neighborhood.json" ]; then
  step_fail "seed neighborhood.json is missing at $SEED"
  scenario_summary
fi
step_pass "seed exists at $SEED"

# 2. Organ accepts the file:// URL via direct call
heading "Step 2 — Organ accepts file:// URL (direct dispatch)"
RESP=$(run_organ_direct "POST" "join" "{\"gate_url\": \"$SEED_URL\"}")
ORGAN_RC=$?
echo "$RESP" | head -30
if [ $ORGAN_RC -eq 0 ] && echo "$RESP" | grep -q '"joined": true' && echo "$RESP" | grep -q '"mode": "local"'; then
  step_pass "organ returns joined=true, mode=local"
else
  step_fail "organ join did not return success"
fi

if echo "$RESP" | grep -q '"role_inferred": "founder"'; then
  step_pass "role_inferred=founder for local-mode subscriber"
else
  step_fail "role_inferred should be founder for local mode"
fi

# 3. Diagnostic ping agent runs against the seed
heading "Step 3 — Local-test ping agent runs"
PING=$(run_agent_direct "$SEED" "agents/local_test_ping_agent.py" "LocalTestPingAgent" "{}")
echo "$PING" | head -10
if echo "$PING" | grep -q '"ok": true'; then
  step_pass "local_test_ping returns ok=true"
else
  step_fail "local_test_ping did not return ok=true"
fi

# 4. Brainstem-mediated check (when running)
heading "Step 4 — Live brainstem subscription (optional)"
if [ "$DRY_RUN" -eq 1 ]; then
  step_skip "skipping live brainstem check (--dry-run)"
else
  if brainstem_alive; then
    LIVE=$(curl -fsS -X POST "${BRAINSTEM_URL}/api/neighborhoods/join" \
      -H 'content-type: application/json' \
      -d "{\"gate_url\": \"$SEED_URL\"}" 2>/dev/null || true)
    if echo "$LIVE" | grep -q '"joined": true'; then
      step_pass "live brainstem at ${BRAINSTEM_URL} accepts the file:// subscription"
    else
      muted "brainstem at ${BRAINSTEM_URL} did not accept the file:// subscription (may be older version)"
      step_skip "live brainstem subscription (organ may need restart)"
    fi
  else
    muted "no brainstem at ${BRAINSTEM_URL}"
    step_skip "live brainstem subscription (start brainstem to verify end-to-end)"
  fi
fi

heading "What to test by hand"
cat <<EOF
  1. Start brainstem A:   PORT=7071 ./rapp_brainstem/start.sh
  2. Start brainstem B:   PORT=7072 ./rapp_brainstem/start.sh
  3. From each, run:
       curl -X POST http://localhost:7071/api/neighborhoods/join \\
            -H 'content-type: application/json' \\
            -d '{"gate_url": "$SEED_URL"}'
       curl -X POST http://localhost:7072/api/neighborhoods/join \\
            -H 'content-type: application/json' \\
            -d '{"gate_url": "$SEED_URL"}'
  4. Verify each brainstem's estate view sees the same subscription:
       curl http://localhost:7071/api/neighborhoods/estate
       curl http://localhost:7072/api/neighborhoods/estate
EOF

scenario_summary
