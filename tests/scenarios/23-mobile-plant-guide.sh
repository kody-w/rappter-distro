#!/usr/bin/env bash
# Scenario 23 — Mobile plant-from-Discord guide page.
#
# Verifies the mobile-first HTML guide at pages/metropolis/plant-from-discord.html
# carries the right content for someone setting up a neighborhood from
# Discord on their phone.

source "$(dirname "$0")/_lib.sh"
scenario_parse_args "$@"

heading "Scenario 23 — Mobile guide for Discord-driven planting"
note "Pattern: form-driven HTML page on phone → generated chat command for brainstem"

GUIDE="$REPO_ROOT/pages/metropolis/plant-from-discord.html"

# 1. Page exists
if [ ! -f "$GUIDE" ]; then
  step_fail "guide HTML missing at $GUIDE"
  scenario_summary
fi
step_pass "guide HTML present"

# 2. Mobile viewport + theme color set (PWA-ready)
heading "Step 2 — Mobile-first directives"
if grep -q 'name="viewport"' "$GUIDE" && grep -q "viewport-fit=cover" "$GUIDE"; then
  step_pass "viewport meta with cover for notched displays"
else
  step_fail "viewport missing or not cover-mode"
fi
if grep -q 'name="theme-color"' "$GUIDE"; then
  step_pass "theme-color set (matches dark UI in browser chrome)"
else
  step_fail "theme-color missing"
fi

# 3. Discord webhook validation regex present
heading "Step 3 — Webhook URL validation"
if grep -q "discord.com/api/webhooks" "$GUIDE"; then
  step_pass "webhook URL pattern referenced"
else
  step_fail "missing discord webhook URL pattern"
fi

# 4. All three templates listed (braintrust / workspace / neighborhood)
heading "Step 4 — Three templates offered"
COUNT=0
for kind in "braintrust" "workspace" "neighborhood"; do
  if grep -q "key: \"$kind\"" "$GUIDE"; then
    COUNT=$((COUNT + 1))
  fi
done
if [ "$COUNT" -eq 3 ]; then
  step_pass "all 3 templates declared (braintrust / workspace / neighborhood)"
else
  step_fail "only $COUNT/3 templates"
fi

# 5. Generated command references the right agent
heading "Step 5 — Generated command targets plant_discord_neighborhood"
if grep -q "plant_discord_neighborhood" "$GUIDE"; then
  step_pass "guide generates a command invoking plant_discord_neighborhood"
else
  step_fail "guide does not reference the planting agent by name"
fi

# 6. Copy-to-clipboard wired
heading "Step 6 — Copy-to-clipboard interaction wired"
if grep -q "navigator.clipboard.writeText" "$GUIDE"; then
  step_pass "Copy command uses Clipboard API"
else
  step_fail "Clipboard copy not wired"
fi

# 7. Sticky bottom action bar (mobile UX)
heading "Step 7 — Sticky bottom action bar for thumb reach"
if grep -q "copy-bar" "$GUIDE" && grep -q "position: fixed" "$GUIDE"; then
  step_pass "sticky copy bar at bottom"
else
  step_fail "sticky copy bar missing"
fi

# 8. Slug auto-generation as user types
heading "Step 8 — Slug auto-generated from display name"
if grep -q "slugify" "$GUIDE" && grep -q "elSlug.dataset.touched" "$GUIDE"; then
  step_pass "slug auto-generates until user manually edits"
else
  step_fail "slug auto-gen behavior missing"
fi

# 9. Linked from the metropolis directory page
heading "Step 9 — Linked from metropolis directory"
METRO="$REPO_ROOT/pages/metropolis/index.html"
if grep -q "plant-from-discord" "$METRO"; then
  step_pass "metropolis directory carries a link to the mobile guide"
else
  step_fail "metropolis does not link to the mobile guide"
fi

# 10. Brainstem + agent download links
heading "Step 10 — Brainstem + agent fetch links"
if grep -q "sphere.html" "$GUIDE" && grep -q "plant_discord_neighborhood_agent.py" "$GUIDE"; then
  step_pass "guide links to brainstem doorman + the agent file for download"
else
  step_fail "brainstem/agent links missing"
fi

heading "Why this matters"
cat <<'EOF'
  The user's brief: set up + use a RAPP neighborhood end-to-end from
  the Discord app on a phone. This page is the one-tap-from-Discord
  guide. They tap the Discord webhook URL into a field, pick a template,
  name the neighborhood, copy the generated brainstem command, paste
  into their brainstem (the doorman or installed brainstem), done.
  No typing, no shell, no documentation deep-dive — just three taps
  and a paste.
EOF

scenario_summary
