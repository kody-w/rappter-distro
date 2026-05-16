#!/usr/bin/env bash
# tests/features/F3-proximity.sh — proximity_discovery_agent conformance.

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F3 — Proximity (Pizza Place / Pokémon-Go)" "Location-aware discovery via geohash (HERO_USECASE §4)"

AGENT="$REPO_ROOT/rapp_brainstem/agents/proximity_discovery_agent.py"

heading "Step 1 — Agent + plant.sh wiring present"
if [ -f "$AGENT" ] && python3 -c "import ast; ast.parse(open('$AGENT').read())" 2>/dev/null; then
  step_pass "proximity_discovery_agent.py parses"
else
  step_fail "agent missing or syntax error"
fi
if grep -q "MIRROR_LOCATION_LAT\|location_geohash" "$REPO_ROOT/installer/plant.sh"; then
  step_pass "plant.sh writes location_geohash when MIRROR_LOCATION_LAT/LNG set"
else
  step_fail "plant.sh not wired for location_geohash"
fi

heading "Step 2 — Geohash encode/decode round-trip"
python3 - "$AGENT" <<'PY' && step_pass "encode → decode round-trip stays inside the geohash cell" || step_fail "geohash roundtrip broken"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("pr", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
# Known anchor: Seattle Space Needle ≈ (47.6205, -122.3493)
gh = m.geohash_encode(47.6205, -122.3493, precision=7)
lat, lng = m.geohash_decode(gh)
# precision 7 ≈ 153m × 153m cell — round-trip lat/lng should be within ~0.002°
if abs(lat - 47.6205) > 0.002 or abs(lng - (-122.3493)) > 0.002:
    print(f"FAIL: roundtrip drift: ({lat}, {lng}) vs ({47.6205}, {-122.3493})"); sys.exit(1)
# Standard test vector: (57.64911, 10.40744) → "u4pruydqqvj" (precision 11)
canonical = m.geohash_encode(57.64911, 10.40744, precision=11)
if not canonical.startswith("u4pruydqqv"):
    print(f"FAIL: canonical vector mismatch: {canonical}"); sys.exit(1)
print(f"OK: Seattle → {gh}; canonical → {canonical}")
PY

heading "Step 3 — Geohash precision affects cell size (lower precision = wider)"
python3 - "$AGENT" <<'PY' && step_pass "precision 4 prefix == precision 5 prefix (geohashes nest)" || step_fail "geohash nesting broken"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("pr", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
gh4 = m.geohash_encode(47.6205, -122.3493, precision=4)
gh7 = m.geohash_encode(47.6205, -122.3493, precision=7)
assert gh7.startswith(gh4), f"nesting broken: {gh7} should startswith {gh4}"
print("OK")
PY

heading "Step 4 — Match logic: prefix matches narrower geohash"
python3 - "$AGENT" <<'PY' && step_pass "match returns entries with overlapping geohash prefix" || step_fail "match broken"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("pr", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
entries = [
    {"name": "needle", "location_geohash": "c23nb5x"},   # Seattle area
    {"name": "elsewhere", "location_geohash": "9q8yyk"},  # SF area
    {"name": "near_needle", "location_geohash": "c23ng"},
]
matches = m._match_by_prefix(entries, "c23")  # Seattle prefix
assert len(matches) == 2, f"expected 2 Seattle-area matches; got {len(matches)}"
matches = m._match_by_prefix(entries, "9q8")  # SF prefix
assert len(matches) == 1
matches = m._match_by_prefix(entries, "xxxx")  # nothing
assert len(matches) == 0
print("OK")
PY

heading "Step 5 — Plant.sh dry-run with lat/lng writes location_geohash"
SANDBOX=$(osi_sandbox "rapp-feature-F3")
trap "osi_cleanup_dir '$SANDBOX'" EXIT
mkdir -p "$SANDBOX/dry"
PLANT_DRY_RUN=1 PLANT_DRY_RUN_DIR="$SANDBOX/dry" \
  PLANT_GH_USER=testuser MIRROR_REPO_NAME=test-pizza MIRROR_DISPLAY_NAME='Test Pizza' \
  MIRROR_KIND=place MIRROR_LOCATION_LAT=47.6205 MIRROR_LOCATION_LNG=-122.3493 \
  bash "$REPO_ROOT/installer/plant.sh" >/dev/null 2>&1
if [ -f "$SANDBOX/dry/rappid.json" ]; then
  GH=$(python3 -c "import json; print(json.load(open('$SANDBOX/dry/rappid.json')).get('location_geohash',''))")
  if [ -n "$GH" ] && printf "%s" "$GH" | grep -Eq '^[0-9a-z]{4,}$'; then
    step_pass "plant.sh dry-run wrote location_geohash=$GH"
  else
    step_fail "plant.sh did not write location_geohash"
  fi
else
  step_fail "plant.sh dry-run did not produce rappid.json"
fi

scenario_summary
