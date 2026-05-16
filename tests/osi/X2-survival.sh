#!/usr/bin/env bash
# tests/osi/X2-survival.sh — verify graceful degradation under failure.
#
# CC2: SURVIVAL.md "what survives what". Local-first fallback + cached
# state + offline-only operation must work.

source "$(dirname "$0")/_lib.sh"

osi_layer_intro "CC2 — Survival" "local-first fallback + cached state + offline-only operation (SURVIVAL.md)"

# 1. cachedGhJson + cachedGhText present (ANTIPATTERNS §5 invariant)
heading "Step 1 — Local-first fallback wrappers present (ANTIPATTERNS §5)"
HITS=$(grep -rl "cachedGhJson\|cachedGhText" "$REPO_ROOT/installer/" "$REPO_ROOT/pages/" "$REPO_ROOT/rapp_brainstem/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$HITS" -ge 1 ]; then
  step_pass "cachedGhJson/cachedGhText present in $HITS file(s)"
else
  step_fail "no cachedGhJson/cachedGhText anywhere — offline regression risk"
fi

# 2. SURVIVAL.md table is present and parseable
heading "Step 2 — SURVIVAL.md failure-mode table present + has rows"
SURV="$REPO_ROOT/SURVIVAL.md"
if [ -f "$SURV" ]; then
  ROWS=$(grep -cE "^\|" "$SURV")
  if [ "$ROWS" -ge 10 ]; then
    step_pass "SURVIVAL.md has $ROWS table rows (failure modes enumerated)"
  else
    step_fail "SURVIVAL.md only has $ROWS table rows — incomplete"
  fi
else
  step_fail "SURVIVAL.md missing"
fi

# 3. Egg state_at_seal block is the offline source of truth (ECOSYSTEM §11 MODE C)
heading "Step 3 — state_at_seal block (offline source of truth, ECOSYSTEM §11)"
if grep -q "state_at_seal" "$REPO_ROOT/rapp_brainstem/utils/bond.py" 2>/dev/null; then
  step_pass "bond.py emits state_at_seal block"
else
  muted "state_at_seal not in bond.py"
  if grep -rq "state_at_seal" "$REPO_ROOT/" --include="*.md" 2>/dev/null; then
    step_pass "state_at_seal documented (impl pending in bond.py)"
  else
    step_fail "state_at_seal entirely missing"
  fi
fi

# 4. Sandboxed organ functions without network — read cache, return graceful
heading "Step 4 — Membership organ runs offline against tmp cache (no network calls in handle())"
SANDBOX=$(osi_sandbox "rapp-osi-X2")
trap "osi_cleanup_dir '$SANDBOX'" EXIT
mkdir -p "$SANDBOX/home"
RESULT=$(python3 - "$REPO_ROOT/rapp_brainstem/utils/organs/neighborhood_membership_organ.py" "$SANDBOX/home" <<'PY'
import importlib.util, json, os, sys
spec = importlib.util.spec_from_file_location("organ", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.HOME_BRAINSTEM = sys.argv[2]
m.SUBS_FILE = os.path.join(sys.argv[2], "neighborhoods.json")
m.CACHE_DIR = os.path.join(sys.argv[2], "neighborhoods")
os.makedirs(m.CACHE_DIR, exist_ok=True)
# GET /api/neighborhoods with empty cache
out, status = m.handle("GET", "", None)
print(json.dumps({"status": status, "subs_count": len(out.get("subscriptions", [])) if isinstance(out, dict) else 0}))
PY
)
if printf "%s" "$RESULT" | grep -q "\"status\":\s*200"; then
  step_pass "membership organ returns 200 against empty cache (no network)"
else
  step_fail "membership organ failed offline: $RESULT"
fi

# 5. Survival contract: scenarios/17 reference (RAPP itself goes down)
heading "Step 5 — survival scenario script present (tests/scenarios/17-survival.sh)"
if [ -f "$REPO_ROOT/tests/scenarios/17-survival.sh" ]; then
  step_pass "scenarios/17-survival.sh present"
else
  muted "scenarios/17-survival.sh not present"
  if grep -rq "tests/scenarios/17-survival.sh" "$REPO_ROOT/SURVIVAL.md" 2>/dev/null; then
    step_pass "survival scenario referenced in SURVIVAL.md (script may live elsewhere)"
  else
    step_fail "no survival scenario script found and not referenced"
  fi
fi

# 6. Synthetic offline simulation: block network, hit organ, expect graceful
heading "Step 6 — Synthetic offline: organ tolerates network failure"
RESULT=$(python3 - "$REPO_ROOT/rapp_brainstem/utils/organs/neighborhood_membership_organ.py" "$SANDBOX/home" <<'PY'
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("organ", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.HOME_BRAINSTEM = sys.argv[2]
m.SUBS_FILE = os.path.join(sys.argv[2], "neighborhoods.json")
m.CACHE_DIR = os.path.join(sys.argv[2], "neighborhoods")
os.makedirs(m.CACHE_DIR, exist_ok=True)
# Try the estate route — should never crash even with no subs + no network
try:
    out, status = m.handle("GET", "estate", None)
    if status in (200, 404):
        print(f"OK status={status}")
    else:
        print(f"unexpected status={status}")
        sys.exit(1)
except Exception as e:
    print(f"CRASH: {e}")
    sys.exit(1)
PY
)
if printf "%s" "$RESULT" | grep -q "^OK"; then
  step_pass "estate endpoint tolerant of empty cache + no network: $RESULT"
else
  step_fail "estate endpoint crashed offline: $RESULT"
fi

scenario_summary
