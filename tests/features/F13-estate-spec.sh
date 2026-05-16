#!/usr/bin/env bash
# tests/features/F13-estate-spec.sh — ESTATE_SPEC + Article XLVI conformance.
#
# Verifies the constitutional Estate Spec contract:
#   1. door_address.py exists + parses + door_from_rappid is the canonical parser
#   2. Valid v2 rappid → full door object with all 9 canonical URLs
#   3. Invalid rappid (origin mismatch) raises InvalidRappidError (no fallback)
#   4. Invalid rappid (bogus kind) raises InvalidRappidError
#   5. Bundle 2.0.0 contains specs/SPEC.md + specs/skill.md (god spec + runbook)
#   6. SPEC.md mentions rappid v2, raw.githubusercontent.com, door_from_rappid
#   7. skill.md frames "GitHub account" as the ONLY requirement
#   8. plant_seed_agent emits facets.json + members.json for both kinds
#   9. estate_agent stores entries as exactly {rappid, added_at, via} — no leaks
#  10. Spec doc at pages/docs/ESTATE_SPEC.md exists + cross-references Article XLVI
#  11. CONSTITUTION Article XLVI is appended

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F13 — Estate Spec (Article XLVI / rappid is the global address)" "spec compliance for door_from_rappid + estate_agent + planter + bundle"

DOOR_ADDR="$REPO_ROOT/tools/door_address.py"
ESTATE_SPEC="$REPO_ROOT/pages/docs/ESTATE_SPEC.md"
GOD_SPEC="$REPO_ROOT/specs/SPEC.md"
SKILL="$REPO_ROOT/specs/skill.md"
PLANTER="$REPO_ROOT/rapp_brainstem/agents/plant_seed_agent.py"
ESTATE_AGENT="$REPO_ROOT/rapp_brainstem/agents/estate_agent.py"
FRONT_DOOR_SPECS="$REPO_ROOT/tools/front_door_specs.py"
CONSTITUTION="$REPO_ROOT/CONSTITUTION.md"

# ─── Step 1 — door_address.py is present + parses ─────────────────────────
heading "Step 1 — door_address.py present + parses"
if [ -f "$DOOR_ADDR" ] && python3 -c "import ast; ast.parse(open('$DOOR_ADDR').read())" 2>/dev/null; then
  step_pass "door_address.py exists and parses cleanly"
else
  step_fail "door_address.py missing or unparseable"
fi

# ─── Step 2 — door_from_rappid produces full URL set ──────────────────────
heading "Step 2 — door_from_rappid produces all 9 canonical URLs for valid rappid"
python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/tools')
from door_address import door_from_rappid
d = door_from_rappid('rappid:v2:twin:@kody-w/echo-brainstem:abc123abc123abc123abc123abc123ab@github.com/kody-w/echo-brainstem')
assert d['owner'] == 'kody-w' and d['repo'] == 'echo-brainstem'
assert d['kind'] == 'twin' and d['door_type'] == 'front_door'
required = {'repo', 'front', 'identity', 'holocard', 'holo_md', 'avatar', 'summon_qr', 'members', 'facets'}
got = set(d['urls'].keys())
assert got == required, f'missing: {required - got}, extra: {got - required}'
assert d['urls']['identity'] == 'https://raw.githubusercontent.com/kody-w/echo-brainstem/main/rappid.json'
assert d['urls']['front'] == 'https://kody-w.github.io/echo-brainstem/'
" 2>/dev/null && step_pass "door object has all 9 canonical URLs" || step_fail "door object incomplete"

# ─── Step 3 — invalid rappid (origin mismatch) raises ─────────────────────
heading "Step 3 — origin-mismatched rappid raises InvalidRappidError (no fallback)"
python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/tools')
from door_address import door_from_rappid, InvalidRappidError
try:
    door_from_rappid('rappid:v2:twin:@kody-w/echo:abc123abc123abc123abc123abc123ab@github.com/kody-w/different')
except InvalidRappidError:
    sys.exit(0)
sys.exit(1)
" 2>/dev/null && step_pass "origin mismatch correctly rejected" || step_fail "did not raise on origin mismatch"

# ─── Step 4 — invalid rappid (bogus kind) raises ──────────────────────────
heading "Step 4 — invalid kind raises (kinds are frozen by spec §2.1)"
python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/tools')
from door_address import door_from_rappid, InvalidRappidError
try:
    door_from_rappid('rappid:v2:bogus:@x/y:abc123abc123abc123abc123abc123ab@github.com/x/y')
except InvalidRappidError:
    sys.exit(0)
sys.exit(1)
" 2>/dev/null && step_pass "bogus kind correctly rejected" || step_fail "did not raise on invalid kind"

# ─── Step 5 — Bundle 2.0.0 contains god spec + skill.md ───────────────────
heading "Step 5 — front_door_specs bundle 2.0.0 ships specs/SPEC.md + specs/skill.md"
python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/tools')
from front_door_specs import bundle_for_kind, bundle_version
assert bundle_version() == '2.0.0', f'wrong version: {bundle_version()}'
b = bundle_for_kind('twin', owner='x', name='y', display_name='Y')
assert 'specs/SPEC.md' in b, f'SPEC.md missing from bundle (got {sorted(b)})'
assert 'specs/skill.md' in b, f'skill.md missing from bundle'
assert 'specs/TWIN_PROTOCOL.md' in b, f'TWIN_PROTOCOL missing'
" 2>/dev/null && step_pass "bundle 2.0.0 has SPEC.md + skill.md + kind-protocol" || step_fail "bundle malformed"

# ─── Step 6 — SPEC.md mentions all the load-bearing terms ─────────────────
heading "Step 6 — specs/SPEC.md mentions rappid v2, raw URL, door_from_rappid"
if grep -q "rappid:v2:" "$GOD_SPEC" && \
   grep -q "raw.githubusercontent.com" "$GOD_SPEC" && \
   grep -q "door_from_rappid" "$GOD_SPEC"; then
  step_pass "all load-bearing references present"
else
  step_fail "SPEC.md missing required terms"
fi

# ─── Step 7 — skill.md frames "GitHub account" as the only requirement ────
heading "Step 7 — specs/skill.md frames 'GitHub account' as the only requirement"
if grep -q "GitHub account" "$SKILL" && grep -q "only requirement" "$SKILL"; then
  step_pass "skill.md correctly frames the onboarding floor"
else
  step_fail "skill.md missing 'GitHub account' / 'only requirement' framing"
fi

# ─── Step 8 — plant_seed_agent emits facets.json + members.json (both kinds)
heading "Step 8 — planter emits facets.json + members.json for both twin and neighborhood"
if grep -q 'files\["facets.json"\]' "$PLANTER" && \
   grep -q 'files\["members.json"\]' "$PLANTER"; then
  # Count occurrences — should be 2 of each (one per builder)
  N_FACETS=$(grep -c 'files\["facets.json"\]' "$PLANTER")
  N_MEMBERS=$(grep -c 'files\["members.json"\]' "$PLANTER")
  if [ "$N_FACETS" -ge 2 ] && [ "$N_MEMBERS" -ge 2 ]; then
    step_pass "facets.json + members.json emitted for both builders ($N_FACETS facets, $N_MEMBERS members)"
  else
    step_fail "expected ≥2 occurrences each, got facets=$N_FACETS members=$N_MEMBERS"
  fi
else
  step_fail "planter not emitting facets.json or members.json"
fi

# ─── Step 9 — estate_agent stores strict {rappid, added_at, via} ──────────
heading "Step 9 — estate_agent stores entries as exactly {rappid, added_at, via}"
TMP_HOME=$(mktemp -d)
HOME="$TMP_HOME" python3 -c "
import sys, json, types
sys.path.insert(0, '$REPO_ROOT/rapp_brainstem/agents')
ba_pkg = types.ModuleType('agents')
ba_mod = types.ModuleType('agents.basic_agent')
class _B:
    def __init__(self, **kw): pass
ba_mod.BasicAgent = _B
sys.modules.setdefault('agents', ba_pkg)
sys.modules['agents.basic_agent'] = ba_mod
import basic_agent
sys.modules.setdefault('basic_agent', basic_agent)

from estate_agent import EstateAgent, append_to_estate

# Add an entry with leaked derived fields
append_to_estate('created', {
    'rappid': 'rappid:v2:twin:@a/b:abc123abc123abc123abc123abc123ab@github.com/a/b',
    'added_at': '2026-05-09T00:00:00Z',
    'via': 'manual',
    'kind': 'LEAKED', 'name': 'LEAKED', 'url': 'LEAKED',
})
out = json.loads(EstateAgent().perform(action='show'))
e = out['estate']['created'][0]
assert set(e.keys()) == {'rappid', 'added_at', 'via'}, f'leaked: {set(e.keys())}'
" 2>/dev/null && step_pass "estate stores strict {rappid, added_at, via}" || step_fail "estate leaked derived fields"
rm -rf "$TMP_HOME"

# ─── Step 10 — pages/docs/ESTATE_SPEC.md exists + cross-references ────────
heading "Step 10 — pages/docs/ESTATE_SPEC.md cross-references Article XLVI"
if [ -f "$ESTATE_SPEC" ] && grep -q "Article XLVI" "$ESTATE_SPEC"; then
  step_pass "ESTATE_SPEC.md present and references Article XLVI"
else
  step_fail "ESTATE_SPEC.md missing or doesn't cite Article XLVI"
fi

# ─── Step 11 — CONSTITUTION has Article XLVI appended ─────────────────────
heading "Step 11 — CONSTITUTION.md contains Article XLVI"
if grep -q "^## Article XLVI " "$CONSTITUTION" && \
   grep -q "Rappid Is The Global Address" "$CONSTITUTION"; then
  step_pass "Article XLVI appended"
else
  step_fail "Article XLVI not in CONSTITUTION.md"
fi

scenario_summary
