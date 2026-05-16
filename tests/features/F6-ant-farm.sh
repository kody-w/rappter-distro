#!/usr/bin/env bash
# tests/features/F6-ant-farm.sh — ant-farm seed conformance + 3-ant swarm simulation.
#
# Verifies the ant-farm neighborhood seed:
#   1. All seed files present + well-formed (rappid/neighborhood/card/colony/etc.)
#   2. ant_agent.py + colony_observer_agent.py satisfy rapp-agent/1.0
#   3. holo.md has every required section a participating AI needs
#   4. index.html parses + references the right repo + label
#   5. Three-ant simulation: each ant runs against an in-memory pheromone
#      pool, picks an unexplored topic, builds a valid prev_hash chain,
#      and the colony observer correctly synthesizes the result.
#
# Pure local — no GitHub network required (covered by --live opt-in).

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F6 — Ant Farm" "Autonomous distributed swarm seed (kody-w/ant-farm)"

SEED="$REPO_ROOT/tests/fixtures/ant-farm-seed"
ANT_AGENT="$REPO_ROOT/rapp_brainstem/agents/ant_agent.py"
OBS_AGENT="$REPO_ROOT/rapp_brainstem/agents/colony_observer_agent.py"

# 1. Seed scaffolding present
heading "Step 1 — Seed scaffolding (10 required files)"
MISSING=()
for f in README.md neighborhood.json rappid.json soul.md card.json members.json index.html holo.md LICENSE .nojekyll data/colony.json agents/ant_agent.py agents/colony_observer_agent.py agents/basic_agent.py; do
  [ -e "$SEED/$f" ] || MISSING+=("$f")
done
if [ "${#MISSING[@]}" -eq 0 ]; then
  step_pass "all seed files present (incl. agents/, data/, holo.md)"
else
  step_fail "missing files: ${MISSING[*]}"
fi

# 2. JSON files all parse
heading "Step 2 — All JSON files parse cleanly"
JSON_BAD=()
for j in neighborhood.json rappid.json card.json members.json data/colony.json; do
  python3 -c "import json; json.load(open('$SEED/$j'))" 2>/dev/null || JSON_BAD+=("$j")
done
if [ "${#JSON_BAD[@]}" -eq 0 ]; then
  step_pass "all 5 JSON files parse"
else
  step_fail "malformed JSON: ${JSON_BAD[*]}"
fi

# 3. neighborhood.json schema + ant-farm specifics
heading "Step 3 — neighborhood.json declares kind=ant-farm + label routing"
python3 - "$SEED/neighborhood.json" <<'PY' && step_pass "neighborhood.json well-formed (kind=ant-farm, label=ant-pheromone)" || step_fail "neighborhood.json shape wrong"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["schema"] == "rapp-neighborhood/1.0", d["schema"]
assert d["kind"] == "ant-farm"
assert d["visibility"] == "public"
assert d["gate_repo"] == "kody-w/ant-farm"
assert "ant-pheromone" in d.get("labels_in_use", [])
assert "rapp-pheromone/1.0" in d.get("schemas_emitted", [])
assert "agents/ant_agent.py" in d.get("agent_files", [])
print("OK")
PY

# 4. ant_agent contract
heading "Step 4 — ant_agent.py satisfies rapp-agent/1.0"
if grep -q "class AntAgent" "$ANT_AGENT" \
   && grep -q "metadata\s*=" "$ANT_AGENT" \
   && grep -q "def perform" "$ANT_AGENT" \
   && grep -q "rapp-pheromone/1.0" "$ANT_AGENT"; then
  step_pass "AntAgent has class + metadata + perform() + emits rapp-pheromone/1.0"
else
  step_fail "ant_agent.py contract incomplete"
fi

# 5. colony_observer contract
heading "Step 5 — colony_observer_agent.py satisfies rapp-agent/1.0"
if grep -q "class ColonyObserverAgent" "$OBS_AGENT" \
   && grep -q "def perform" "$OBS_AGENT" \
   && grep -q "rapp-colony-observation/1.0" "$OBS_AGENT"; then
  step_pass "ColonyObserverAgent has class + perform() + emits observation envelope"
else
  step_fail "colony_observer_agent.py contract incomplete"
fi

# 6. holo.md required sections
heading "Step 6 — holo.md contains every section a participating AI needs"
HOLO="$SEED/holo.md"
python3 - "$HOLO" <<'PY' && step_pass "holo.md has identity + schema + steps + anti-patterns + verify" || step_fail "holo.md missing required sections"
import sys, re
src = open(sys.argv[1]).read()
required_substrings = [
    "rapp-pheromone/1.0",
    "ant-pheromone",
    "ant_id",
    "prev_hash",
    "hash",
    "kody-w/ant-farm",
    "holo.md",
    "Anti-patterns" if "Anti-patterns" in src else "anti-pattern",  # case-insensitive enough
]
missing = [s for s in required_substrings if s.lower() not in src.lower()]
if missing:
    print(f"FAIL: missing sections/keywords: {missing}"); sys.exit(1)
# Section headers (## level)
for h in ["1.", "2.", "3.", "4.", "5.", "6.", "7.", "8.", "9."]:
    if f"## {h}" not in src:
        print(f"FAIL: missing section header '## {h}'"); sys.exit(1)
print("OK")
PY

# 7. index.html parses + references repo + label
heading "Step 7 — index.html references the right repo + label + holo URL"
python3 - "$SEED/index.html" <<'PY' && step_pass "index.html wired to kody-w/ant-farm + ant-pheromone label + holo.md" || step_fail "index.html wiring wrong"
import sys
src = open(sys.argv[1]).read()
needed = ["kody-w/ant-farm", "ant-pheromone", "holo.md", "rapp-pheromone/1.0",
          "cachedGhJson", "stat-pheromones", "btn-drop"]
missing = [n for n in needed if n not in src]
if missing:
    print(f"FAIL: index.html missing: {missing}"); sys.exit(1)
print("OK")
PY

# 8. THE BIG TEST — three-ant simulation against an in-memory swarm
heading "Step 8 — Three-ant simulation: chain integrity + topic balancing"
python3 - "$ANT_AGENT" "$OBS_AGENT" "$SEED/data/colony.json" <<'PY' && step_pass "3-ant swarm: balanced topics, valid hash chain, observer agrees" || step_fail "swarm simulation failed"
import importlib.util, json, sys

# Load both agents in the same process
def _load(path, modname):
    sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
    sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
    spec = importlib.util.spec_from_file_location(modname, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    sys.modules[f"agents.{modname}"] = m
    return m

ant_mod = _load(sys.argv[1], "ant_agent")
obs_mod = _load(sys.argv[2], "colony_observer_agent")

with open(sys.argv[3]) as f:
    colony = json.load(f)

pool = []  # in-memory pheromone pool (simulates GH Issues)
ants = ["ant:claude-opus-4.7", "ant:gpt-4o", "ant:gemini-2.5"]

for i, ant_id in enumerate(ants):
    agent = ant_mod.AntAgent()
    out_str = agent.perform(
        ant_id=ant_id,
        trail=f"trail from {ant_id} ({i+1}/3) — observing the colony.",
        farm_owner="kody-w", farm_repo="ant-farm",
        dry_run=True,
        _existing_pheromones=pool,
        _colony=colony,
    )
    out = json.loads(out_str)
    assert out["dry_run"] is True
    pheromone = out["pheromone"]
    assert pheromone["schema"] == "rapp-pheromone/1.0"
    assert pheromone["ant_id"] == ant_id
    assert pheromone["topic"] in colony["tasks"]
    assert len(pheromone["hash"]) == 64
    if pool:
        assert pheromone["prev_hash"] == pool[-1]["hash"], f"chain broken at ant {i+1}"
    else:
        assert pheromone["prev_hash"] == ""
    pool.append(pheromone)

# Topics: verify load-balancing (each ant picked a different topic since pool grew)
topics = [p["topic"] for p in pool]
assert len(set(topics)) >= 2, f"expected ≥2 distinct topics; got {topics}"

# Re-compute hash for each pheromone independently and verify
import hashlib
for p in pool:
    body = (p["prev_hash"] or "") + "|" + p["utc"] + "|" + p["topic"] + "|" + p["ant_id"] + "|" + p["trail"]
    h = hashlib.sha256(body.encode()).hexdigest()
    assert h == p["hash"], f"hash mismatch for {p['ant_id']}"

# Observer reads the pool and produces a coherent summary
obs = obs_mod.ColonyObserverAgent()
summary = json.loads(obs.perform(
    farm_owner="kody-w", farm_repo="ant-farm",
    _existing_pheromones=pool, _colony=colony,
))
assert summary["pheromone_count"] == 3
assert summary["ant_count"] == 3
assert summary["longest_chain_length"] == 3, f"expected chain of 3; got {summary['longest_chain_length']}"
print("OK")
PY

# 9. dry_run defaults true (safety: never post without explicit opt-in)
heading "Step 9 — Safety: ant_agent defaults to dry_run=True"
python3 - "$ANT_AGENT" <<'PY' && step_pass "ant_agent dry_run defaults true (no accidental posts)" || step_fail "ant_agent could post by accident"
import importlib.util, json, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("ant_agent", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
agent = m.AntAgent()
out = json.loads(agent.perform(
    ant_id="test", trail="test trail",
    _existing_pheromones=[], _colony={"tasks": ["a"]},
))
assert out["dry_run"] is True, "dry_run not default true"
assert "post" not in out, "post should not have run on default invocation"
print("OK")
PY

# 10. Pheromone hash chain is tamper-evident
heading "Step 10 — Tampering breaks the chain"
python3 - "$ANT_AGENT" <<'PY' && step_pass "modifying any field changes the hash → tamper detected" || step_fail "tampering not detected"
import importlib.util, hashlib, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("ant_agent", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
ph = m.compose_pheromone(ant_id="x", topic="t", trail="trail", links=[], previous_hash="")
# Tamper: change trail; recompute the hash; original should not match.
tampered_body = (ph["prev_hash"] + "|" + ph["utc"] + "|" + ph["topic"] + "|" + ph["ant_id"] + "|" + "DIFFERENT")
tampered_hash = hashlib.sha256(tampered_body.encode()).hexdigest()
assert tampered_hash != ph["hash"]
print("OK")
PY

scenario_summary
