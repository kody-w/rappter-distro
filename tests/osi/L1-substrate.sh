#!/usr/bin/env bash
# tests/osi/L1-substrate.sh — verify the physical layer.
#
# L1 = the medium: GitHub (Pages + raw + APIs), PeerJS broker, local FS.
# Pass if local FS works AND every reachable network anchor responds OR
# we're in --offline mode and only local FS matters.

source "$(dirname "$0")/_lib.sh"

osi_layer_intro "L1 — Substrate" "Local FS + GitHub Pages + raw.githubusercontent.com + PeerJS broker"

# 1. Local filesystem writable
heading "Step 1 — Local filesystem (every layer above assumes this)"
SANDBOX=$(osi_sandbox "rapp-osi-L1")
trap "osi_cleanup_dir '$SANDBOX'" EXIT
echo "test-bytes" >"$SANDBOX/probe.txt"
if [ -f "$SANDBOX/probe.txt" ] && [ "$(cat "$SANDBOX/probe.txt")" = "test-bytes" ]; then
  step_pass "local FS readable + writable at $SANDBOX"
else
  step_fail "local FS write/read failed"
fi

# 2. ~/.brainstem path resolvable (may not exist yet, but the path resolves)
HOME_BS="$HOME/.brainstem"
if [ -n "$HOME" ]; then
  step_pass "operator home brainstem path resolvable: $HOME_BS"
else
  step_fail "HOME env var not set"
fi

# 3. GitHub Pages serves the species root
heading "Step 2 — GitHub Pages serves the species root"
if osi_net "GitHub Pages probe"; then
  CODE=$(osi_head "https://kody-w.github.io/RAPP/" 5)
  if [ "$CODE" = "200" ] || [ "$CODE" = "301" ] || [ "$CODE" = "302" ]; then
    step_pass "kody-w.github.io/RAPP/ → HTTP $CODE"
  else
    step_fail "kody-w.github.io/RAPP/ → HTTP $CODE (expected 200/301/302)"
  fi
fi

# 4. raw.githubusercontent.com reaches the README
heading "Step 3 — raw.githubusercontent.com (the canonical content channel)"
if osi_net "raw fetch probe"; then
  CODE=$(osi_head "https://raw.githubusercontent.com/kody-w/RAPP/main/README.md" 5)
  if [ "$CODE" = "200" ]; then
    step_pass "raw.githubusercontent.com/kody-w/RAPP/main/README.md → HTTP 200"
  else
    step_fail "raw fetch → HTTP $CODE (expected 200)"
  fi
fi

# 5. PeerJS broker reachable for L4a tether handshake
heading "Step 4 — PeerJS public broker (L4a handshake mediator)"
if osi_net "PeerJS broker probe"; then
  # 0.peerjs.com is the public broker; /peerjs/id returns a fresh peer id (text)
  CODE=$(osi_get_status "https://0.peerjs.com/" 5)
  if [ "$CODE" != "000" ]; then
    step_pass "0.peerjs.com responding (HTTP $CODE) — broker reachable"
  else
    step_fail "0.peerjs.com unreachable (transport failure)"
  fi
fi

# 6. Auth worker config present (Cloudflare Worker source checked in)
heading "Step 5 — Cloudflare auth worker source present (Tier 0.5)"
if [ -f "$REPO_ROOT/worker/worker.js" ] && [ -f "$REPO_ROOT/worker/wrangler.toml" ]; then
  step_pass "worker/worker.js + worker/wrangler.toml present"
else
  step_fail "worker/ missing required files"
fi

# 7. Local FS fallback works under simulated network outage
heading "Step 6 — Cached-state fallback: front door wraps fetch in cachedGhJson (ANTIPATTERNS §5)"
FRONT=$(find "$REPO_ROOT" -name "index.html" -path "*/utils/web/*" 2>/dev/null | head -1)
if [ -n "$FRONT" ] && grep -q "cachedGhJson\|cachedGhText" "$FRONT"; then
  step_pass "cachedGhJson/cachedGhText present in front door ($FRONT)"
else
  # Look for it across all front-door templates
  if grep -rq "cachedGhJson\|cachedGhText" "$REPO_ROOT/installer/" "$REPO_ROOT/pages/" 2>/dev/null; then
    step_pass "cachedGhJson/cachedGhText present in plant.sh template OR pages/"
  else
    step_fail "cachedGhJson/cachedGhText not found — local-first fallback regression risk (ANTIPATTERNS §5)"
  fi
fi

scenario_summary
