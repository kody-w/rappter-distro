#!/usr/bin/env bash
# tests/features/F2-leaderboard.sh — species_leaderboard_agent conformance.

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F2 — Species Leaderboard" "Global MMR ladder via fork-tree walk (ECOSYSTEM §15)"

AGENT="$REPO_ROOT/rapp_brainstem/agents/species_leaderboard_agent.py"

heading "Step 1 — Agent file present + parses"
if [ -f "$AGENT" ] && python3 -c "import ast; ast.parse(open('$AGENT').read())" 2>/dev/null; then
  step_pass "species_leaderboard_agent.py parses cleanly"
else
  step_fail "agent missing or syntax error"
fi

heading "Step 2 — rapp-agent/1.0 contract"
if grep -q "class SpeciesLeaderboardAgent" "$AGENT" \
   && grep -q "metadata\s*=" "$AGENT" \
   && grep -q "def perform" "$AGENT"; then
  step_pass "class + metadata + perform present"
else
  step_fail "agent contract incomplete"
fi

heading "Step 3 — Tier ladder matches ECOSYSTEM §6 medals"
python3 - "$AGENT" <<'PY' && step_pass "Herald → Immortal ladder thresholds correct" || step_fail "tier ladder drift"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("sl", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
checks = [(7000, "Immortal"), (5000, "Divine"), (3700, "Ancient"),
          (3100, "Legend"), (2600, "Archon"), (2100, "Crusader"),
          (1600, "Guardian"), (1200, "Herald"), (500, "Herald")]
for mmr, expected in checks:
    got = m._tier(mmr)
    if got != expected:
        print(f"FAIL: mmr={mmr} → {got}, expected {expected}"); sys.exit(1)
print("OK")
PY

heading "Step 4 — Cache TTL: 600s (10 min) per agent docstring"
python3 - "$AGENT" <<'PY' && step_pass "cache TTL is 600s (rate-limit-friendly)" || step_fail "cache TTL drift"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("sl", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
assert m._CACHE_TTL_SECONDS == 600
assert m._SPECIES_ROOT_OWNER == "kody-w"
assert m._SPECIES_ROOT_REPO == "RAPP"
print("OK")
PY

heading "Step 5 — Cache write/read roundtrip works"
SANDBOX=$(osi_sandbox "rapp-feature-F2")
trap "osi_cleanup_dir '$SANDBOX'" EXIT
python3 - "$AGENT" "$SANDBOX/cache.json" <<'PY' && step_pass "_write_cache + _read_cache survive roundtrip" || step_fail "cache I/O broken"
import importlib.util, json, os, sys, time
spec = importlib.util.spec_from_file_location("sl", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
m._CACHE_PATH = sys.argv[2]
payload = {"schema": "rapp-species-leaderboard/1.0", "cached_at_unix": int(time.time()),
           "entries": [{"name": "test", "mmr": 1234}], "from_cache": False}
m._write_cache(payload)
back = m._read_cache()
assert back is not None and back["entries"][0]["mmr"] == 1234
print("OK")
PY

heading "Step 6 — Schema string is rapp-species-leaderboard/1.0"
if grep -q '"schema": "rapp-species-leaderboard/1.0"' "$AGENT"; then
  step_pass "leaderboard payload uses rapp-species-leaderboard/1.0"
else
  step_fail "schema string drift"
fi

scenario_summary
