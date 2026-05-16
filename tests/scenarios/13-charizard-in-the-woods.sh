#!/usr/bin/env bash
# Scenario 13 — Charizard in the Woods (canonical hero use case).
#
# Two phones. No internet. One has a useful agent — Charizard. The other
# needs it. Trade by QR pair → WebRTC tether → egg transfer. Receiver
# runs the agent locally with whatever model they have.
#
# This scenario formalizes the hero use case from HERO_USECASE.md §1.
# Tests: egg pack/unpack, offline content-addressed storage,
# agent runs on receiver's brainstem after handoff.

source "$(dirname "$0")/_lib.sh"
scenario_parse_args "$@"

heading "Scenario 13 — Charizard in the Woods (canonical)"
note "Pattern: two devices, no network, agent transfer via egg"
note "Showcases: HERO_USECASE.md §1 — the offline-share canon"

TMP=$(mktemp -d -t rapp-scenario-13-XXXXXX)
trap 'rm -rf "$TMP"' EXIT
PHONE_A="$TMP/phone-a"
PHONE_B="$TMP/phone-b"
mkdir -p "$PHONE_A" "$PHONE_B"

# 1. Phone A has the local-only-test seed acting as Charizard
cp -R "$FIXTURES_DIR/local-only-test" "$PHONE_A/charizard"
step_pass "Phone A has Charizard organism"

# 2. Pack as an "egg" — for this scenario, just zip + sha256
EGG="$TMP/charizard.egg"
(cd "$PHONE_A/charizard" && zip -qr "$EGG" .)
SHA=$(shasum -a 256 "$EGG" | awk '{print $1}')
if [ -f "$EGG" ] && [ -n "$SHA" ]; then
  step_pass "Phone A packed Charizard.egg ($(wc -c < "$EGG") bytes, sha256 ${SHA:0:12}...)"
else
  step_fail "egg pack failed"
fi

# 3. "Transfer" the egg — for the test we just cp; in real life this is
#    the WebRTC tether.
cp "$EGG" "$PHONE_B/incoming.egg"
step_pass "egg transferred to Phone B (simulating WebRTC tether)"

# 4. Phone B verifies the sha256 BEFORE unpacking
SHA_B=$(shasum -a 256 "$PHONE_B/incoming.egg" | awk '{print $1}')
if [ "$SHA" = "$SHA_B" ]; then
  step_pass "Phone B verifies sha256 — non-tampered egg"
else
  step_fail "sha256 mismatch! pack=$SHA recv=$SHA_B"
fi

# 5. Phone B hatches the egg into a working organism dir
mkdir -p "$PHONE_B/charizard-hatched"
(cd "$PHONE_B/charizard-hatched" && unzip -q "$PHONE_B/incoming.egg")
if [ -f "$PHONE_B/charizard-hatched/neighborhood.json" ]; then
  step_pass "Phone B hatched the egg — organism content present"
else
  step_fail "hatch failed — neighborhood.json missing"
fi

# 6. Phone B runs Charizard's agent locally — the real test
PING=$(NEIGHBORHOOD_SEED_DIR="$PHONE_B/charizard-hatched" python3 - <<'PY'
import importlib.util, os, sys
sys.path.insert(0, os.environ["NEIGHBORHOOD_SEED_DIR"])
spec = importlib.util.spec_from_file_location("ping", os.path.join(os.environ["NEIGHBORHOOD_SEED_DIR"], "agents/local_test_ping_agent.py"))
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
print(mod.LocalTestPingAgent().perform())
PY
)
if echo "$PING" | grep -q "ok.*True\|'ok': True"; then
  step_pass "Phone B runs Charizard's agent successfully (offline)"
else
  step_fail "Phone B could not run Charizard's agent"
fi

# 7. Both phones now own independent copies — proof of soul-travel
if [ -d "$PHONE_A/charizard" ] && [ -d "$PHONE_B/charizard-hatched" ]; then
  step_pass "both phones now own independent Charizard instances (parallel dimensions)"
else
  step_fail "parallel-dimension property violated"
fi

heading "Why this matters"
cat <<'EOF'
  The canonical hero scenario. Two devices in the woods, no network.
  Trade an organism via egg over WebRTC tether (here simulated with
  cp + sha256). The receiver runs the agent locally. Both devices now
  hold parallel-dimension instances — when they reconnect, Dream
  Catcher merges the divergent histories. This scenario is the
  recoverable proof that the offline-first contract still holds.
EOF

scenario_summary
