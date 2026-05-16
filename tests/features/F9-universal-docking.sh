#!/usr/bin/env bash
# tests/features/F9-universal-docking.sh — dock_agent conformance.
#
# Verifies the universal additive-merge primitive: same docking-without-
# destruction property applied at the registry/list-of-dicts scope.
# Works for ANY rar-shaped JSON: rar/index.json, _metropolis.json,
# members.json, neighborhood entries, etc.

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F9 — Universal docking" "dock_agent — additive merge into any rar-shaped registry; same primitive as ant_agent / rar_loader / graft / bond / Dream Catcher"

AGENT="$REPO_ROOT/rapp_brainstem/agents/dock_agent.py"
SANDBOX=$(osi_sandbox "rapp-feature-F9")
trap "osi_cleanup_dir '$SANDBOX'" EXIT

heading "Step 1 — Agent file present + parses + rapp-agent/1.0 contract"
if [ -f "$AGENT" ] && python3 -c "import ast; ast.parse(open('$AGENT').read())" 2>/dev/null; then
  if grep -q "class DockAgent" "$AGENT" \
     && grep -q "metadata\s*=" "$AGENT" \
     && grep -q "def perform" "$AGENT" \
     && grep -q "rapp-dock-result/1.0" "$AGENT"; then
    step_pass "DockAgent has class + metadata + perform + emits rapp-dock-result/1.0"
  else
    step_fail "agent contract incomplete"
  fi
else
  step_fail "agent missing or syntax error"
fi

heading "Step 2 — Dock into a fresh (non-existent) registry creates it"
REG="$SANDBOX/fresh.json"
python3 - "$AGENT" "$REG" <<'PY' && step_pass "fresh registry created with default skeleton + entry added" || step_fail "fresh-registry path broken"
import importlib.util, json, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("dock", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = json.loads(m.DockAgent().perform(
    registry_path=sys.argv[2],
    new_entries=[{"name": "first-entry", "kind": "agent"}],
    dry_run=False,
))
assert out["ok"]
assert out["summary"]["added"] == 1
import os
assert os.path.exists(sys.argv[2])
print("OK")
PY

heading "Step 3 — Dock more: additive append (preserve existing)"
python3 - "$AGENT" "$REG" <<'PY' && step_pass "second dock: existing preserved + new entry appended" || step_fail "additive merge broken"
import importlib.util, json, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("dock", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = json.loads(m.DockAgent().perform(
    registry_path=sys.argv[2],
    new_entries=[{"name": "second-entry", "kind": "card"}],
    dry_run=False,
))
assert out["ok"] and out["summary"]["added"] == 1
# Verify file has BOTH entries
reg = json.load(open(sys.argv[2]))
names = sorted(e["name"] for e in reg["entries"])
assert names == ["first-entry", "second-entry"], f"got {names}"
print("OK")
PY

heading "Step 4 — Re-dock same name: SKIPPED (preserve-local)"
python3 - "$AGENT" "$REG" <<'PY' && step_pass "duplicate key skipped; existing entry untouched" || step_fail "duplicate-key dedup broken"
import importlib.util, json, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("dock", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = json.loads(m.DockAgent().perform(
    registry_path=sys.argv[2],
    new_entries=[{"name": "first-entry", "kind": "agent", "fresh_field": "should_not_clobber"}],
    dry_run=False,
))
assert out["ok"]
assert out["summary"]["added"] == 0, "should not have added duplicate"
assert out["summary"]["skipped"] == 1
# The original "first-entry" must NOT have fresh_field
reg = json.load(open(sys.argv[2]))
first = next(e for e in reg["entries"] if e["name"] == "first-entry")
assert "fresh_field" not in first, "duplicate dock clobbered original entry"
print("OK")
PY

heading "Step 5 — Dock works with custom key_field (dedup by sha256 instead of name)"
REG2="$SANDBOX/by_sha.json"
python3 - "$AGENT" "$REG2" <<'PY' && step_pass "custom key_field works (e.g. sha256 dedup)" || step_fail "custom key_field broken"
import importlib.util, json, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("dock", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
agent = m.DockAgent()
# First dock
out = json.loads(agent.perform(
    registry_path=sys.argv[2], key_field="sha256",
    new_entries=[{"name": "a", "sha256": "deadbeef"}, {"name": "b", "sha256": "cafe1234"}],
    dry_run=False,
))
assert out["summary"]["added"] == 2
# Second dock — same sha256 different name → still SKIP
out = json.loads(agent.perform(
    registry_path=sys.argv[2], key_field="sha256",
    new_entries=[{"name": "a-renamed", "sha256": "deadbeef"}],
    dry_run=False,
))
assert out["summary"]["added"] == 0, "sha256 collision should skip"
print("OK")
PY

heading "Step 6 — Dock into top-level list (entries_path='')"
REG3="$SANDBOX/list.json"
import_init=$(python3 -c "
import json
with open('$REG3', 'w') as f: json.dump([{'name':'one'}], f)
")
python3 - "$AGENT" "$REG3" <<'PY' && step_pass "top-level list registry merged correctly" || step_fail "top-level list path broken"
import importlib.util, json, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("dock", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = json.loads(m.DockAgent().perform(
    registry_path=sys.argv[2],
    entries_path="",   # the top-level IS the list
    new_entries=[{"name": "two"}, {"name": "three"}],
    dry_run=False,
))
assert out["summary"]["added"] == 2
data = json.load(open(sys.argv[2]))
assert isinstance(data, list)
names = sorted(e["name"] for e in data)
assert names == ["one", "three", "two"]
print("OK")
PY

heading "Step 7 — Dry-run: zero file writes (preserve-local default)"
REG4="$SANDBOX/dry.json"
python3 -c "
import json
with open('$REG4', 'w') as f: json.dump({'schema':'test','entries':[{'name':'untouched'}]}, f)
"
ORIG_SHA=$(shasum -a 256 "$REG4" | awk '{print $1}')
python3 - "$AGENT" "$REG4" <<'PY' && step_pass "dry_run reports added but file untouched" || step_fail "dry_run wrote to disk"
import importlib.util, json, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("dock", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = json.loads(m.DockAgent().perform(
    registry_path=sys.argv[2],
    new_entries=[{"name": "would-add"}],
    # default dry_run=True
))
assert out["dry_run"] is True
assert out["summary"]["added"] == 1
print("OK")
PY
NEW_SHA=$(shasum -a 256 "$REG4" | awk '{print $1}')
if [ "$ORIG_SHA" = "$NEW_SHA" ]; then
  step_pass "file sha256 unchanged (proof: dry_run did not touch disk)"
else
  step_fail "dry_run modified disk: $ORIG_SHA → $NEW_SHA"
fi

heading "Step 8 — Bond event log: dock writes append-only event when log_path set"
LOG="$SANDBOX/bonds.json"
python3 - "$AGENT" "$REG" "$LOG" <<'PY' && step_pass "log_path triggers a 'dock' kind event in bonds.json" || step_fail "bond event logging broken"
import importlib.util, json, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("dock", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = json.loads(m.DockAgent().perform(
    registry_path=sys.argv[2],
    new_entries=[{"name": "logged-entry", "kind": "agent"}],
    dry_run=False,
    log_path=sys.argv[3],
))
assert out["bond_event"] is not None
assert out["bond_event"]["kind"] == "dock"
import os
log = json.load(open(sys.argv[3]))
assert any(e["kind"] == "dock" for e in log["events"])
print("OK")
PY

heading "Step 9 — Parallel-to framing: agent advertises every other dock-variant scope"
python3 - "$AGENT" <<'PY' && step_pass "parallel_to enumerates ant_agent + rar_loader + graft + bond + Dream Catcher" || step_fail "parallel framing missing"
import importlib.util, json, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("dock", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = json.loads(m.DockAgent().perform(
    registry_path="/tmp/__dock_probe__.json",
    new_entries=[{"name": "probe"}],
))
parallel = out.get("parallel_to") or {}
for required in ("ant_agent_pheromone", "rar_loader", "graft_neighborhood", "bond_py_egg_hatch", "dream_catcher", "this_dock_agent"):
    assert required in parallel, f"missing parallel scope: {required}"
print("OK")
PY

scenario_summary
