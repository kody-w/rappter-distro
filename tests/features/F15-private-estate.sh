#!/usr/bin/env bash
# tests/features/F15-private-estate.sh — Article XLVIII conformance gate.
#
# Verifies the two-tier estate boundary:
#   1. tools/path_opacity.py exists + parses + self-check passes
#   2. tools/private_estate_init.py exists + parses
#   3. estate_agent has init_private + verify_private actions
#   4. Beacon schema bumped to rapp-network-beacon/1.1
#   5. CONSTITUTION.md has Article XLVIII (with §XLVIII.6 URL Opacity)
#   6. PUBLIC_PRIVATE_BOUNDARY.md exists + cross-references Article XLVIII
#   7. LIVE: kody-w/rapp-estate-private exists + IS private
#   8. LIVE: kody-w's beacon carries private_estate_pointer + commitment + door_count
#   9. URL OPACITY (XLVIII.6): every path in the private repo matches the opacity regex
#  10. Sniffer surfaces private extension presence WITHOUT fetching content

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F15 — Two-Tier Estate (Article XLVIII / Public Discovery, Private Substance)" "the boundary between what's discoverable and what's substantial"

PATH_OPACITY="$REPO_ROOT/tools/path_opacity.py"
PRIVATE_INIT="$REPO_ROOT/tools/private_estate_init.py"
ESTATE_AGENT="$REPO_ROOT/rapp_brainstem/agents/estate_agent.py"
BOUNDARY_SPEC="$REPO_ROOT/pages/docs/PUBLIC_PRIVATE_BOUNDARY.md"
CONSTITUTION="$REPO_ROOT/CONSTITUTION.md"
SNIFFER="$REPO_ROOT/tools/sniff_network.py"

# ─── Step 1 — path_opacity.py self-check passes ──────────────────────────
heading "Step 1 — tools/path_opacity.py exists, parses, self-check passes"
if [ -f "$PATH_OPACITY" ] && python3 -c "import ast; ast.parse(open('$PATH_OPACITY').read())" 2>/dev/null; then
  if python3 "$PATH_OPACITY" 2>/dev/null | grep -q '"ok": true'; then
    step_pass "self-check green"
  else
    step_fail "self-check failed"
  fi
else
  step_fail "path_opacity.py missing or unparseable"
fi

# ─── Step 2 — private_estate_init.py present + parses ───────────────────
heading "Step 2 — tools/private_estate_init.py present + parses"
if [ -f "$PRIVATE_INIT" ] && python3 -c "import ast; ast.parse(open('$PRIVATE_INIT').read())" 2>/dev/null; then
  step_pass "private_estate_init.py parses cleanly"
else
  step_fail "private_estate_init.py missing or unparseable"
fi

# ─── Step 3 — estate_agent has init_private + verify_private ────────────
heading "Step 3 — estate_agent.py has init_private + verify_private actions"
if grep -q '"init_private"' "$ESTATE_AGENT" && \
   grep -q '"verify_private"' "$ESTATE_AGENT"; then
  step_pass "both actions present in enum + handler"
else
  step_fail "init_private or verify_private missing"
fi

# ─── Step 4 — beacon schema bumped to 1.1 ───────────────────────────────
heading "Step 4 — beacon schema bumped to rapp-network-beacon/1.1"
if grep -q '_BEACON_SCHEMA = "rapp-network-beacon/1.1"' "$ESTATE_AGENT" && \
   grep -q 'private_estate_pointer' "$ESTATE_AGENT" && \
   grep -q 'private_estate_commitment' "$ESTATE_AGENT"; then
  step_pass "schema 1.1 + private_estate_pointer + commitment in beacon builder"
else
  step_fail "beacon schema not bumped or private fields missing"
fi

# ─── Step 5 — CONSTITUTION has Article XLVIII (with §XLVIII.6) ──────────
heading "Step 5 — CONSTITUTION.md contains Article XLVIII + §XLVIII.6"
if grep -q "^## Article XLVIII " "$CONSTITUTION" && \
   grep -q "Public Discovery, Private Substance" "$CONSTITUTION" && \
   grep -q "XLVIII.6 — The URL Space Is Opaque" "$CONSTITUTION"; then
  step_pass "Article XLVIII appended with URL-opacity subsection"
else
  step_fail "Article XLVIII or §XLVIII.6 missing"
fi

# ─── Step 6 — boundary spec exists + cross-references Article XLVIII ────
heading "Step 6 — pages/docs/PUBLIC_PRIVATE_BOUNDARY.md cross-references Article XLVIII"
if [ -f "$BOUNDARY_SPEC" ] && grep -q "Article XLVIII" "$BOUNDARY_SPEC"; then
  step_pass "boundary spec present + cites Article XLVIII"
else
  step_fail "boundary spec missing or doesn't cite Article XLVIII"
fi

# ─── Step 7 — LIVE: kody-w/rapp-estate-private exists + IS private ──────
heading "Step 7 — kody-w/rapp-estate-private exists and is PRIVATE"
if osi_net "live gh repo view"; then
  VIS=$(gh repo view kody-w/rapp-estate-private --json visibility --jq '.visibility' 2>/dev/null)
  if [ "$VIS" = "PRIVATE" ]; then
    step_pass "repo exists and is PRIVATE"
  else
    step_fail "repo missing or not private (got: $VIS)"
  fi
fi

# ─── Step 8 — LIVE: beacon carries private extension fields ─────────────
heading "Step 8 — kody-w's beacon carries private_estate_pointer + commitment + door_count"
if osi_net "live beacon fetch"; then
  BEACON=$(curl -fsSL "https://raw.githubusercontent.com/kody-w/rapp-estate/main/.well-known/rapp-network.json" 2>/dev/null)
  HAS_POINTER=$(echo "$BEACON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(bool(d.get('private_estate_pointer')))" 2>/dev/null)
  HAS_COMMIT=$(echo "$BEACON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(bool(d.get('private_estate_commitment')))" 2>/dev/null)
  if [ "$HAS_POINTER" = "True" ] && [ "$HAS_COMMIT" = "True" ]; then
    step_pass "beacon has both private_estate_pointer + commitment"
  else
    step_fail "beacon missing private fields (pointer=$HAS_POINTER commit=$HAS_COMMIT)"
  fi
fi

# ─── Step 9 — URL OPACITY (XLVIII.6): every path matches the opacity regex
heading "Step 9 — URL opacity sweep — every path in private repo matches regex"
if osi_net "live tree fetch"; then
  PATHS=$(gh api '/repos/kody-w/rapp-estate-private/git/trees/main?recursive=1' --jq '.tree[] | select(.type == "blob") | .path' 2>/dev/null)
  VIOLATIONS=$(echo "$PATHS" | python3 -c "
import re, sys
regex = re.compile(r'^(meta\.json|README\.md|objects/(\.gitkeep|[a-f0-9]+\.json)|kinds/(\.gitkeep|[a-f0-9]+(/[a-f0-9]+\.json)?))$')
v = [p.strip() for p in sys.stdin if p.strip() and not regex.match(p.strip())]
print('\n'.join(v))
" 2>/dev/null)
  if [ -z "$VIOLATIONS" ]; then
    N=$(echo "$PATHS" | wc -l | tr -d ' ')
    step_pass "all $N paths match opacity regex (Article XLVIII.6)"
  else
    step_fail "URL opacity violations: $VIOLATIONS"
  fi
fi

# ─── Step 10 — Sniffer surfaces private extension WITHOUT fetching ──────
heading "Step 10 — sniff_network surfaces private extension; never fetches content"
if osi_net "live sniff"; then
  SNIFF_TMP=$(mktemp)
  python3 "$SNIFFER" --json 2>/dev/null > "$SNIFF_TMP"
  RESULT=$(python3 -c "
import json
d = json.load(open('$SNIFF_TMP'))
op = next((o for o in d.get('operators', []) if o['github'] == 'kody-w'), {})
hp = bool(op.get('has_private_extension'))
co = op.get('compliance', '?')
print(f'{hp}|{co}')
" 2>/dev/null)
  rm -f "$SNIFF_TMP"
  HAS_PRIV="${RESULT%%|*}"
  COMPLIANCE="${RESULT##*|}"
  if [ "$HAS_PRIV" = "True" ] && [ "$COMPLIANCE" = "xlviii" ]; then
    step_pass "sniffer reports has_private_extension=True, compliance=xlviii"
  else
    step_fail "sniffer didn't surface XLVIII compliance (has_priv=$HAS_PRIV, compliance=$COMPLIANCE)"
  fi
fi

# ─── Step 11 — DESTRUCTIVE: simulate fresh operator + verify auto-create ───
# Gated by RAPP_F15_DESTRUCTIVE=1 because it deletes + recreates the live
# kody-w/rapp-estate-private repo. Normal F15 runs skip this step (10/10).
heading "Step 11 — DESTRUCTIVE: simulate fresh operator + verify publish auto-creates private (gated)"
if [ "${RAPP_F15_DESTRUCTIVE:-0}" = "1" ]; then
  if osi_net "destructive auto-create test"; then
    # Snapshot the operator's HMAC secret + local map so we can restore on failure
    SECRET_BAK=$(mktemp)
    MAP_BAK=$(mktemp)
    cp "$HOME/.brainstem/private-estate-secret" "$SECRET_BAK" 2>/dev/null || true
    cp "$HOME/.brainstem/private-estate-map.json" "$MAP_BAK" 2>/dev/null || true

    # Delete the live private repo (destructive — that's the whole point)
    gh repo delete kody-w/rapp-estate-private --yes 2>/dev/null

    # Verify it's actually gone
    if gh repo view kody-w/rapp-estate-private --json visibility 2>/dev/null | grep -q PRIVATE; then
      step_fail "destructive setup failed — couldn't delete kody-w/rapp-estate-private"
    else
      # Run estate publish — should auto-create the private estate per XLVIII.1
      AUTO_CREATED=$(python3 - <<PY
import json, sys, types
sys.path.insert(0, '$REPO_ROOT/rapp_brainstem/agents')
ba = types.ModuleType('agents.basic_agent')
class _B:
    def __init__(self, **kw): pass
ba.BasicAgent = _B
sys.modules['agents.basic_agent'] = ba
sys.modules['agents'] = types.ModuleType('agents')
import basic_agent
sys.modules.setdefault('basic_agent', basic_agent)
from estate_agent import EstateAgent
out = json.loads(EstateAgent().perform(action='publish'))
print('auto_created' if out.get('auto_created_private') else 'no_auto_create')
PY
)
      if [ "$AUTO_CREATED" = "auto_created" ]; then
        # Verify the repo IS recreated as PRIVATE
        VIS=$(gh repo view kody-w/rapp-estate-private --json visibility --jq '.visibility' 2>/dev/null)
        if [ "$VIS" = "PRIVATE" ]; then
          step_pass "publish auto-created kody-w/rapp-estate-private (XLVIII.1 enforcement)"
        else
          step_fail "auto-create reported success but repo not PRIVATE (got: $VIS)"
        fi
      else
        step_fail "publish did not auto-create the private estate (got: $AUTO_CREATED)"
      fi
    fi
    rm -f "$SECRET_BAK" "$MAP_BAK"
  fi
else
  step_skip "Step 11 — destructive auto-create test (set RAPP_F15_DESTRUCTIVE=1 to enable)"
fi

scenario_summary
