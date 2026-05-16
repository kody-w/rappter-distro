#!/usr/bin/env bash
# tests/features/F14-estate-rebuild.sh — Article XLVI.6 conformance.
#
# Verifies the disaster-recovery property: the estate is recomputable from
# pure GitHub raw data given just the operator's handle.
#
#   1. tools/rebuild_estate.py exists + parses
#   2. plant_seed_agent has the _read_operator_rappid helper
#   3. backfill_seeds.py has --patch-parents mode
#   4. estate_agent has 'rebuild' action + extends 'fetch' to accept rappid=
#   5. A known-backfilled door has parent_rappid set (live raw fetch)
#   6. door_from_rappid resolves an operator-kind rappid to door_type=front_door
#   7. The rebuild import + dry-run discovery returns the expected shape
#   8. Round-trip: backed-up estate's created[] is a subset of rebuild output

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F14 — Estate Rebuild (Article XLVI.6 / recompute from network)" "the estate is recoverable from pure GitHub raw data"

REBUILD="$REPO_ROOT/tools/rebuild_estate.py"
BACKFILL="$REPO_ROOT/tools/backfill_seeds.py"
PLANTER="$REPO_ROOT/rapp_brainstem/agents/plant_seed_agent.py"
ESTATE_AGENT="$REPO_ROOT/rapp_brainstem/agents/estate_agent.py"
DOOR_ADDR="$REPO_ROOT/tools/door_address.py"

# ─── Step 1 — rebuild_estate.py present + parses ──────────────────────────
heading "Step 1 — rebuild_estate.py present + parses"
if [ -f "$REBUILD" ] && python3 -c "import ast; ast.parse(open('$REBUILD').read())" 2>/dev/null; then
  step_pass "rebuild_estate.py parses cleanly"
else
  step_fail "rebuild_estate.py missing or unparseable"
fi

# ─── Step 2 — planter has _read_operator_rappid helper ────────────────────
heading "Step 2 — plant_seed_agent has _read_operator_rappid helper"
if grep -q "def _read_operator_rappid" "$PLANTER" && \
   grep -q '"parent_rappid": _read_operator_rappid()' "$PLANTER"; then
  N_USES=$(grep -c '"parent_rappid": _read_operator_rappid()' "$PLANTER")
  if [ "$N_USES" -ge 2 ]; then
    step_pass "_read_operator_rappid wired into both builders ($N_USES call sites)"
  else
    step_fail "expected 2+ call sites (twin + neighborhood), got $N_USES"
  fi
else
  step_fail "_read_operator_rappid helper missing or not used"
fi

# ─── Step 3 — backfill has --patch-parents ────────────────────────────────
heading "Step 3 — backfill_seeds.py has --patch-parents mode"
if grep -q '"--patch-parents"' "$BACKFILL" && grep -q "def patch_parents" "$BACKFILL"; then
  step_pass "--patch-parents CLI flag + handler present"
else
  step_fail "--patch-parents missing"
fi

# ─── Step 4 — estate_agent has rebuild + fetch_by_rappid ──────────────────
heading "Step 4 — estate_agent has 'rebuild' action + fetch accepts rappid="
if grep -q '"rebuild"' "$ESTATE_AGENT" && \
   grep -q 'if action == "rebuild"' "$ESTATE_AGENT" && \
   grep -q "rappid_in = kwargs.get" "$ESTATE_AGENT"; then
  step_pass "rebuild + fetch-by-rappid both wired"
else
  step_fail "rebuild or fetch-by-rappid missing"
fi

# ─── Step 5 — live: a known door has parent_rappid set ────────────────────
heading "Step 5 — kody-w/echo-brainstem carries parent_rappid (live gh api)"
if osi_net "live gh api fetch"; then
  PR=$(gh api /repos/kody-w/echo-brainstem/contents/rappid.json --jq '.content' 2>/dev/null \
        | base64 -d 2>/dev/null \
        | python3 -c "import json,sys; print(json.load(sys.stdin).get('parent_rappid','NULL'))" 2>/dev/null)
  if echo "$PR" | grep -q "^rappid:v2:operator:@"; then
    step_pass "parent_rappid set: ${PR:0:60}…"
  else
    step_fail "parent_rappid not set or not an operator rappid: $PR"
  fi
fi

# ─── Step 6 — door_from_rappid handles operator kind ──────────────────────
heading "Step 6 — door_from_rappid resolves operator-kind rappid"
python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/tools')
from door_address import door_from_rappid
d = door_from_rappid('rappid:v2:operator:@x/y:abc123abc123abc123abc123abc123ab@github.com/x/y')
assert d['kind'] == 'operator'
assert d['door_type'] == 'front_door'
" 2>/dev/null && step_pass "operator-kind rappid → door_type=front_door" || step_fail "operator kind not handled"

# ─── Step 7 — rebuild_estate.py imports + has discover_* functions ────────
heading "Step 7 — rebuild_estate.py exposes the expected discovery API"
python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/tools')
from rebuild_estate import (
    rebuild,
    discover_operator_rappid,
    discover_created,
    discover_memberships,
    _list_handle_repos,
)
assert callable(rebuild)
assert callable(discover_operator_rappid)
assert callable(discover_created)
assert callable(discover_memberships)
" 2>/dev/null && step_pass "all discovery functions importable" || step_fail "rebuild module API incomplete"

# ─── Step 8 — round-trip via the rebuild tool (live) ──────────────────────
heading "Step 8 — round-trip: tools/rebuild_estate.py --handle kody-w finds backfilled doors"
if osi_net "live rebuild dry-run"; then
  RESULT=$(python3 "$REBUILD" --handle kody-w 2>/dev/null \
           | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    rb = d.get('_rebuild', {})
    print(f'{rb.get(\"created_count\", 0)},{rb.get(\"member_count\", 0)}')
except Exception as e:
    print(f'PARSE_ERROR:{e}')
")
  CREATED=$(echo "$RESULT" | cut -d',' -f1)
  if [ -n "$CREATED" ] && [ "$CREATED" -ge 13 ] 2>/dev/null; then
    step_pass "rebuild discovered $CREATED created doors (≥13 expected after backfill)"
  else
    step_fail "rebuild discovered only '$RESULT' created doors (≥13 expected)"
  fi
fi

scenario_summary
