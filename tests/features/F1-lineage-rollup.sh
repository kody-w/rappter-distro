#!/usr/bin/env bash
# tests/features/F1-lineage-rollup.sh — lineage_rollup_agent conformance.
#
# Verifies the agent contract + computation logic without depending on
# live GitHub state: parses the agent in isolation, checks metadata,
# runs a synthetic MMR computation against a controlled input.

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F1 — Lineage roll-up" "Aggregate stats across an organism's lineage tree (ECOSYSTEM §15)"

AGENT="$REPO_ROOT/rapp_brainstem/agents/lineage_rollup_agent.py"

# 1. Agent file exists + parses
heading "Step 1 — Agent file present + parses"
if [ -f "$AGENT" ] && python3 -c "import ast; ast.parse(open('$AGENT').read())" 2>/dev/null; then
  step_pass "lineage_rollup_agent.py parses cleanly"
else
  step_fail "lineage_rollup_agent.py missing or has syntax errors"
fi

# 2. Class + metadata + perform present
heading "Step 2 — rapp-agent/1.0 contract: class + metadata + perform"
if grep -q "class LineageRollupAgent" "$AGENT" \
   && grep -q "metadata\s*=" "$AGENT" \
   && grep -q "def perform" "$AGENT"; then
  step_pass "LineageRollupAgent has class + metadata + perform()"
else
  step_fail "agent contract incomplete"
fi

# 3. MMR formula constants match ECOSYSTEM §6
heading "Step 3 — MMR formula constants (ECOSYSTEM §6)"
python3 - "$AGENT" <<'PY' && step_pass "MMR formula constants present" || step_fail "MMR formula drift"
import re, sys
src = open(sys.argv[1]).read()
# ECOSYSTEM §6: 30 / 250 / 350 / 80 / 400 (per-mem / sqrt-mut / per-agent / sqrt-age / sqrt-fork)
expected = {"_MMR_PER_MEM": 30, "_MMR_PER_SQRT_MUT": 250, "_MMR_PER_AGENT": 350,
            "_MMR_PER_SQRT_AGE_DAYS": 80, "_MMR_PER_SQRT_FORK": 400, "_MMR_BASELINE": 1000}
bad = []
for k, v in expected.items():
    m = re.search(rf"^{k}\s*=\s*(\d+)", src, re.MULTILINE)
    if not m or int(m.group(1)) != v:
        bad.append(f"{k}={m.group(1) if m else 'absent'} expected={v}")
if bad:
    print("DRIFT:", "; ".join(bad)); sys.exit(1)
print("OK")
PY

# 4. Synthetic computation: known signals → expected MMR
heading "Step 4 — Synthetic MMR computation against known signals"
python3 - "$AGENT" <<'PY' && step_pass "_compute_mmr produces expected value for known signals" || step_fail "MMR computation incorrect"
import importlib.util, sys, math
spec = importlib.util.spec_from_file_location("lr", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules["agents.basic_agent"] = type(sys)("agents.basic_agent")
class _Stub:
    def __init__(self): pass
sys.modules["agents.basic_agent"].BasicAgent = _Stub
spec.loader.exec_module(m)
# Known signals: 10 mems, 16 mutations, 2 custom agents, 100 days old, 4 forks, recent commit
signals = {"mem_count": 10, "mut_count": 16, "custom_agent_count": 2,
           "age_days": 100.0, "fork_count": 4,
           "last_commit_at": __import__("time").strftime("%Y-%m-%dT%H:%M:%S", __import__("time").gmtime())}
mmr = m._compute_mmr(signals)
# Expected = 1000 + 10*30 + sqrt(16)*250 + 2*350 + sqrt(100)*80 + sqrt(4)*400  (× 1.0 activity)
#         = 1000 + 300 + 1000 + 700 + 800 + 800 = 4600
expected = 4600
if mmr != expected:
    print(f"FAIL: got {mmr}, expected {expected}"); sys.exit(1)
print(f"OK: {mmr}")
PY

# 5. Activity factor decay table matches ECOSYSTEM §6
heading "Step 5 — Activity factor: 1.00 / 0.85 / 0.65 / 0.45 by recency"
python3 - "$AGENT" <<'PY' && step_pass "activity factor honors ECOSYSTEM §6 thresholds" || step_fail "activity factor wrong"
import importlib.util, sys, time
spec = importlib.util.spec_from_file_location("lr", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
def _iso(days_ago):
    return time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(time.time() - days_ago * 86400))
checks = [(_iso(10), 1.00), (_iso(60), 0.85), (_iso(365), 0.65), (_iso(365*5), 0.45)]
for ts, expected in checks:
    got = m._activity_factor(ts)
    if got != expected:
        print(f"FAIL: {ts} → {got}, expected {expected}"); sys.exit(1)
print("OK")
PY

# 6. Agent registered with proper schema in metadata
heading "Step 6 — Agent metadata.name == 'LineageRollup' (LLM tool-call schema)"
python3 - "$AGENT" <<'PY' && step_pass "metadata exposes LineageRollup name + parameters" || step_fail "metadata schema wrong"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("lr", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
md = m.LineageRollupAgent.metadata
assert md["name"] == "LineageRollup"
assert "rappid" in md["parameters"]["properties"]
assert "max_depth" in md["parameters"]["properties"]
print("OK")
PY

scenario_summary
