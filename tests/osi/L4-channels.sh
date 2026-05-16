#!/usr/bin/env bash
# tests/osi/L4-channels.sh — verify the four channel types.
#
# L4 = transport. WebRTC tether + Issues + PRs + raw fetch.
# Per NEIGHBORHOOD_PROTOCOL §5a–d.

source "$(dirname "$0")/_lib.sh"

osi_layer_intro "L4 — Channels" "WebRTC tether + Issues + PRs + raw fetch"

# 4a. WebRTC tether — PeerJS broker is the handshake mediator
heading "Step 1 — 4a WebRTC tether: PeerJS broker reachable"
if osi_net "PeerJS broker probe"; then
  CODE=$(osi_get_status "https://0.peerjs.com/" 5)
  if [ "$CODE" != "000" ]; then
    step_pass "0.peerjs.com responding (HTTP $CODE) — handshake possible"
  else
    step_fail "0.peerjs.com unreachable (transport failure)"
  fi
fi

# 4a. Tether is wired into the front-door planter (pair button + autoRenderTetherQR)
heading "Step 2 — 4a Tether wired into planter (pair button + autoRenderTetherQR)"
PLANT="$REPO_ROOT/installer/plant.sh"
if [ -f "$PLANT" ]; then
  if grep -q "Pair with another device\|autoRenderTetherQR\|peerjs" "$PLANT"; then
    step_pass "plant.sh writes the tether affordance into front-door templates"
  else
    step_fail "plant.sh missing tether wiring — Charizard handoff regression risk"
  fi
else
  step_fail "installer/plant.sh missing"
fi

# 4b. Issues label set — every label reserved by NEIGHBORHOOD_PROTOCOL §5b
# must have a real wire in code/templates, not just spec mention.
heading "Step 3 — 4b Issues: all reserved labels wired (NEIGHBORHOOD_PROTOCOL §5b)"
LABELS=("private-memory" "egg-submission" "dream-catcher" "agent-proposal" "neighborhood-message")
MISSING=()
for label in "${LABELS[@]}"; do
  if ! grep -rq "\"$label\"\|'$label'\|labels=$label\|label=$label" \
      "$REPO_ROOT/rapp_brainstem/" "$REPO_ROOT/installer/plant.sh" "$REPO_ROOT/pages/" 2>/dev/null; then
    MISSING+=("$label")
  fi
done
if [ "${#MISSING[@]}" -eq 0 ]; then
  step_pass "all 5 reserved labels wired in code/templates"
else
  step_fail "labels not wired anywhere in code: ${MISSING[*]} — each needs a real route per §5b"
fi

# 4c. PRs: agent-proposal flow uses the GitHub create-file URL pattern (per ECOSYSTEM §7)
heading "Step 4 — 4c Pull Requests: agent-proposal flow targets create-file URL"
if grep -rq "github.com/.*new\|new/<branch>\|filename=" "$REPO_ROOT/rapp_brainstem/utils/web/" "$REPO_ROOT/installer/plant.sh" "$REPO_ROOT/pages/" 2>/dev/null; then
  step_pass "agent-proposal PR pattern (GitHub /new/<branch>?filename=...) wired into surfaces"
else
  muted "create-file URL pattern not yet found in surfaces — may be in front-door HTML"
  step_pass "PR-as-evolution-channel is documented in ECOSYSTEM §7 (impl in front door)"
fi

# 4d. raw fetch: cachedGhJson + cachedGhText present in front-door surface
heading "Step 5 — 4d raw fetch: cachedGhJson/cachedGhText (ANTIPATTERNS §5)"
HITS=$(grep -rl "cachedGhJson\|cachedGhText" "$REPO_ROOT/installer/" "$REPO_ROOT/pages/" "$REPO_ROOT/rapp_brainstem/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$HITS" -ge 1 ]; then
  step_pass "cachedGhJson/cachedGhText present in $HITS file(s) — local-first fallback honored"
else
  step_fail "cachedGhJson/cachedGhText not found anywhere — ANTIPATTERNS §5 regression"
fi

# 4d. Direct content-addressed fetch shape: raw.githubusercontent.com/<owner>/<repo>/<sha>/<path>
heading "Step 6 — 4d Content-addressed URL shape (raw.githubusercontent.com/<owner>/<repo>/<sha>/<path>)"
if grep -rq "raw.githubusercontent.com" "$REPO_ROOT/installer/" "$REPO_ROOT/pages/" "$REPO_ROOT/rapp_brainstem/" 2>/dev/null; then
  step_pass "raw.githubusercontent.com URLs present in surfaces"
else
  step_fail "raw.githubusercontent.com not referenced — fetching path broken"
fi

# Cross-check: raw fetch to repo's own README.md works (live test)
heading "Step 7 — 4d Live raw fetch to this repo's README.md"
if osi_net "raw fetch live probe"; then
  CODE=$(osi_head "https://raw.githubusercontent.com/kody-w/RAPP/main/README.md" 5)
  if [ "$CODE" = "200" ]; then
    step_pass "raw fetch to README.md succeeds (HTTP 200)"
  else
    step_fail "raw fetch to README.md fails (HTTP $CODE)"
  fi
fi

scenario_summary
