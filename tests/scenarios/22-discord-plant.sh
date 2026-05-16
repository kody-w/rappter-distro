#!/usr/bin/env bash
# Scenario 22 — Discord-driven plant_discord_neighborhood_agent.
#
# Verifies the standalone planting agent:
#   1. Validates inputs (rejects bad webhook URL)
#   2. Dry-run gathers template files + customizes neighborhood.json
#   3. Default mode flips defaults correctly (kind=braintrust → template + visibility)
#   4. neighborhood.json gets a `discord` block with the webhook URL preserved
#   5. (--live) Plants a real repo, verifies content, deletes the repo

source "$(dirname "$0")/_lib.sh"
LIVE=0
for arg in "$@"; do
  case "$arg" in --live) LIVE=1 ;; esac
done
scenario_parse_args "$@"

heading "Scenario 22 — Discord-driven neighborhood planting"
note "Pattern: one agent.py + a Discord webhook → fully-planted neighborhood + welcome message"
note "Showcases: the simplest possible discord-bridged neighborhood setup"

AGENT="$REPO_ROOT/rapp_brainstem/agents/plant_discord_neighborhood_agent.py"
TEMPLATE_SEED="$FIXTURES_DIR/local-only-test"

# 1. Agent file exists + is well-formed Python
heading "Step 1 — Agent file present + parseable"
if [ ! -f "$AGENT" ]; then step_fail "agent file missing"; scenario_summary; fi
if python3 -c "import ast; ast.parse(open('$AGENT').read())" 2>/dev/null; then
  step_pass "agent parses as valid Python"
else
  step_fail "agent has syntax errors"
fi

# 2. Bad webhook URL returns ok=False
heading "Step 2 — Validation: bad webhook URL rejected"
RES=$(NEIGHBORHOOD_SEED_DIR="$TEMPLATE_SEED" python3 - "$AGENT" <<'PY'
import importlib.util, json, os, sys
sys.path.insert(0, os.environ["NEIGHBORHOOD_SEED_DIR"])
spec = importlib.util.spec_from_file_location("a", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = m.PlantDiscordNeighborhoodAgent().perform(
    neighborhood_name="x", discord_webhook_url="not-a-url", dry_run=True,
)
print(out)
PY
)
OK=$(echo "$RES" | python3 -c "import json,sys; print(json.load(sys.stdin)['ok'])")
if [ "$OK" = "False" ]; then
  step_pass "rejects non-URL webhook"
else
  step_fail "validation missed the bad URL"
fi

# 3. Dry-run with valid input gathers + customizes
heading "Step 3 — Dry-run: gather template + customize neighborhood.json"
RES=$(NEIGHBORHOOD_SEED_DIR="$TEMPLATE_SEED" python3 - "$AGENT" <<'PY'
import importlib.util, json, os, sys
sys.path.insert(0, os.environ["NEIGHBORHOOD_SEED_DIR"])
spec = importlib.util.spec_from_file_location("a", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = m.PlantDiscordNeighborhoodAgent().perform(
    neighborhood_name="Design Team 2026",
    display_name="Design Team 2026",
    discord_webhook_url="https://discord.com/api/webhooks/abc/xyz",
    discord_server_id="1234567890",
    kind="braintrust",
    dry_run=True,
)
print(out)
PY
)
KIND=$(echo "$RES" | python3 -c "import json,sys; print(json.load(sys.stdin)['kind'])")
TPL=$(echo "$RES" | python3 -c "import json,sys; print(json.load(sys.stdin)['template_used'])")
FILES_COUNT=$(echo "$RES" | python3 -c "import json,sys; print(json.load(sys.stdin)['files_count'])")
if [ "$KIND" = "braintrust" ] && [ "$TPL" = "kody-w/braintrust-template" ] && [ "$FILES_COUNT" -ge 10 ]; then
  step_pass "dry-run resolves kind=braintrust → braintrust-template; gathered $FILES_COUNT files"
else
  step_fail "dry-run defaults broken: kind=$KIND template=$TPL files=$FILES_COUNT"
fi

# 4. kind=neighborhood resolves to public visibility + public-art template
heading "Step 4 — kind=neighborhood defaults to public + art-collective template"
RES=$(NEIGHBORHOOD_SEED_DIR="$TEMPLATE_SEED" python3 - "$AGENT" <<'PY'
import importlib.util, json, os, sys
sys.path.insert(0, os.environ["NEIGHBORHOOD_SEED_DIR"])
spec = importlib.util.spec_from_file_location("a", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = m.PlantDiscordNeighborhoodAgent().perform(
    neighborhood_name="open-jam",
    discord_webhook_url="https://discord.com/api/webhooks/a/b",
    kind="neighborhood",
    dry_run=True,
)
print(out)
PY
)
VIS=$(echo "$RES" | python3 -c "import json,sys; print(json.load(sys.stdin)['visibility'])")
TPL=$(echo "$RES" | python3 -c "import json,sys; print(json.load(sys.stdin)['template_used'])")
if [ "$VIS" = "public" ] && [[ "$TPL" == *"public-art-collective"* ]]; then
  step_pass "kind=neighborhood → visibility=public + public-art-collective"
else
  step_fail "wrong defaults: vis=$VIS tpl=$TPL"
fi

# 5. Customized neighborhood.json carries the discord block + new rappid
heading "Step 5 — Customized neighborhood.json embeds discord block"
RES=$(NEIGHBORHOOD_SEED_DIR="$TEMPLATE_SEED" python3 - "$AGENT" <<'PY'
import importlib.util, json, os, sys
sys.path.insert(0, os.environ["NEIGHBORHOOD_SEED_DIR"])
spec = importlib.util.spec_from_file_location("a", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
agent = m.PlantDiscordNeighborhoodAgent()
# Use the internal _customize_neighborhood_json directly to verify the block
import json as J
fake = J.dumps({"schema":"rapp-neighborhood/1.0","github":"old","kind":"old"}).encode("utf-8")
new = agent._customize_neighborhood_json(
    fake, "kody-w", "test-name", "Test Display",
    "braintrust", "private-workspace",
    "00000000-1111-2222-3333-444444444444", "demo purpose",
    "https://discord.com/api/webhooks/x/y", "srv123", "chan456",
)
print(new.decode("utf-8"))
PY
)
DISC_OK=$(echo "$RES" | python3 -c "import json,sys; n=json.load(sys.stdin); d=n.get('discord',{}); print(d.get('webhook_url')=='https://discord.com/api/webhooks/x/y' and d.get('server_id')=='srv123' and d.get('channel_id')=='chan456' and d.get('schema')=='rapp-discord-bridge/1.0')")
if [ "$DISC_OK" = "True" ]; then
  step_pass "neighborhood.json carries discord block (schema/webhook/server/channel preserved)"
else
  step_fail "discord block missing or malformed"
fi
RAPPID_NEW=$(echo "$RES" | python3 -c "import json,sys; print(json.load(sys.stdin).get('neighborhood_rappid'))")
if [ "$RAPPID_NEW" = "00000000-1111-2222-3333-444444444444" ]; then
  step_pass "neighborhood_rappid set to the minted UUID"
else
  step_fail "rappid not set: $RAPPID_NEW"
fi

# 6. Live round-trip (only with --live)
heading "Step 6 — Live: plant + verify + delete (--live only)"
if [ "$LIVE" -eq 0 ]; then
  step_skip "live round-trip (run with --live to enable)"
else
  TOKEN=$(gh auth token 2>/dev/null)
  if [ -z "$TOKEN" ]; then
    step_skip "no gh auth token"
  else
    LIVE_NAME="rapp-plant-test-$(date +%s)"
    # We need a webhook URL — use a Discord-format URL that will return 401/404
    # without actually side-effecting Discord.
    FAKE_HOOK="https://discord.com/api/webhooks/0/test-token-will-not-resolve"
    LIVE_RES=$(GITHUB_TOKEN="$TOKEN" NEIGHBORHOOD_SEED_DIR="$TEMPLATE_SEED" python3 - "$AGENT" "$LIVE_NAME" "$FAKE_HOOK" <<'PY'
import importlib.util, json, os, sys
sys.path.insert(0, os.environ["NEIGHBORHOOD_SEED_DIR"])
spec = importlib.util.spec_from_file_location("a", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = m.PlantDiscordNeighborhoodAgent().perform(
    neighborhood_name=sys.argv[2],
    display_name="RAPP plant test",
    discord_webhook_url=sys.argv[3],
    kind="workspace",
    purpose="Live test of plant_discord_neighborhood — please ignore",
)
print(out)
PY
)
    LIVE_OK=$(echo "$LIVE_RES" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ok'))")
    LIVE_OWNER=$(echo "$LIVE_RES" | python3 -c "import json,sys; print(json.load(sys.stdin).get('owner'))")
    LIVE_NAME_R=$(echo "$LIVE_RES" | python3 -c "import json,sys; print(json.load(sys.stdin).get('name'))")
    if [ "$LIVE_OK" = "True" ] && [ -n "$LIVE_OWNER" ] && [ -n "$LIVE_NAME_R" ]; then
      step_pass "live: planted $LIVE_OWNER/$LIVE_NAME_R"
      # Verify content really landed
      CHECK=$(gh api "repos/$LIVE_OWNER/$LIVE_NAME_R/contents/neighborhood.json" --jq .name 2>/dev/null)
      if [ "$CHECK" = "neighborhood.json" ]; then
        step_pass "live: neighborhood.json present in planted repo"
      else
        step_fail "live: neighborhood.json missing"
      fi
      # Archive the test repo (reversible cleanup, only needs `repo` scope —
      # delete_repo would force a separate auth-refresh).
      ARCHIVED=$(gh api -X PATCH "repos/$LIVE_OWNER/$LIVE_NAME_R" -F archived=true --jq .archived 2>&1)
      if [ "$ARCHIVED" = "true" ]; then
        step_pass "live: archived $LIVE_OWNER/$LIVE_NAME_R (test artifact, reversible)"
      else
        step_fail "live: could not archive ($ARCHIVED)"
      fi
    else
      step_fail "live plant failed: $LIVE_RES"
    fi
  fi
fi

heading "Why this matters"
cat <<'EOF'
  One file, one webhook URL, one agent invocation = a fully-planted RAPP
  neighborhood with the Discord bridge wired in. Operators don't write
  code; they don't run shell scripts; they don't fork repos manually.
  They drop this agent into their brainstem, give it a Discord webhook,
  and the platform takes care of the rest. The planted neighborhood
  carries the discord block in neighborhood.json so future bridge agents
  know where to talk.
EOF

scenario_summary
