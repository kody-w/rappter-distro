#!/usr/bin/env bash
# tests/features/F12-bond-rhythm.sh — Bond Pulse heartbeat conformance.
#
# Verifies rapp_brainstem/agents/bond_rhythm_agent.py:
#   1. Module + metadata shape
#   2. pulse_once safe by default (dry_run always True regardless of input — operator-mediated)
#   3. Schema rapp-rhythm-pulse/1.0 envelope present + all required keys
#   4. Drift classification (LOCAL→GLOBAL / GLOBAL→LOCAL / INFORMATIONAL) via _audit_override
#   5. Suggested action one-liners are concrete + name the right actuator
#   6. Bond event recorded with kind='rhythm' + drift_count + degraded fields
#   7. time_since_last_pulse_seconds tracked across consecutive pulses
#   8. Graceful degradation: when audit subprocess fails, sets degraded=True + valid envelope
#   9. by_direction counts add up + match offspring_count

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F12 — Bond Rhythm (Bond Pulse heartbeat)" \
                "rapp_brainstem/agents/bond_rhythm_agent.py"

AGENT="$REPO_ROOT/rapp_brainstem/agents/bond_rhythm_agent.py"
SANDBOX=$(osi_sandbox "rapp-feature-F12")
trap "osi_cleanup_dir '$SANDBOX'" EXIT

heading "Step 1 — Agent module present + parses + has metadata"
if [ -f "$AGENT" ] && python3 -c "import ast; ast.parse(open('$AGENT').read())" 2>/dev/null; then
  step_pass "bond_rhythm_agent.py present and parses"
else
  step_fail "bond_rhythm_agent.py missing or has syntax errors"
fi

heading "Step 2 — Metadata shape: name='BondRhythm', mentions Bond Pulse + dry_run"
python3 - "$AGENT" <<'PY' && step_pass "metadata names BondRhythm + describes Bond Pulse + has dry_run param" || step_fail "metadata wrong"
import importlib.util, sys, os
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("br", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
md = m.BondRhythmAgent.metadata
assert md["name"] == "BondRhythm", f"name={md['name']!r}"
desc = md["description"]
assert "Bond Pulse" in desc or "Bond Rhythm" in desc, f"description must mention Bond Pulse / Bond Rhythm: {desc[:200]}"
assert "operator-mediated" in desc.lower() or "does not auto-execute" in desc.lower(), "must declare it does not auto-execute"
assert "dry_run" in md["parameters"]["properties"], "missing dry_run param"
assert md["parameters"]["properties"]["dry_run"].get("default") is True, "dry_run must default to True"
print("OK")
PY

heading "Step 3 — pulse_once returns rapp-rhythm-pulse/1.0 envelope with all required keys"
python3 - "$AGENT" "$SANDBOX/bonds-step3.json" <<'PY' && step_pass "envelope shape matches schema rapp-rhythm-pulse/1.0" || step_fail "envelope shape wrong"
import importlib.util, json, os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("br", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
fake_audit = {"schema": "rapp-ecosystem-audit/1.0", "mode": "offline",
              "offspring_count": 0, "drift_count": 0, "offspring": [],
              "by_kind": {}, "summary": {}, "next_actions": []}
out = json.loads(m.BondRhythmAgent().perform(_audit_override=fake_audit, _bonds_file=sys.argv[2]))
for key in ("schema", "ok", "dry_run", "pulse_at", "audit_mode", "degraded",
            "drift_count", "offspring_count", "suggested_actions", "by_direction",
            "rhythm", "bond_event", "next_step"):
    assert key in out, f"missing key: {key}"
assert out["schema"] == "rapp-rhythm-pulse/1.0", out["schema"]
assert out["ok"] is True
assert out["dry_run"] is True, "rhythm always returns dry_run=True (operator-mediated)"
assert out["rhythm"]["operator_mediated"] is True
print("OK")
PY

heading "Step 4 — dry_run=True ENFORCED even if caller passes dry_run=False"
python3 - "$AGENT" "$SANDBOX/bonds-step4.json" <<'PY' && step_pass "dry_run=True enforced regardless of input (operator-mediated by design)" || step_fail "rhythm agent leaked dry_run=False"
import importlib.util, json, os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("br", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
fake_audit = {"schema": "rapp-ecosystem-audit/1.0", "mode": "offline",
              "offspring_count": 0, "drift_count": 0, "offspring": [],
              "by_kind": {}, "summary": {}, "next_actions": []}
out = json.loads(m.BondRhythmAgent().perform(dry_run=False, _audit_override=fake_audit, _bonds_file=sys.argv[2]))
assert out["dry_run"] is True, "rhythm MUST never honor dry_run=False — only Launch/Graft/RarLoader actuate"
print("OK")
PY

heading "Step 5 — Drift classification: LOCAL→GLOBAL push for missing_files + schema_drift"
python3 - "$AGENT" "$SANDBOX/bonds-step5.json" <<'PY' && step_pass "missing_files + schema_drift correctly classified as LOCAL_TO_GLOBAL" || step_fail "classifier wrong"
import importlib.util, json, os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("br", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
fake_audit = {
    "schema": "rapp-ecosystem-audit/1.0", "mode": "offline",
    "offspring_count": 1, "drift_count": 1,
    "offspring": [{
        "name": "fake-neighborhood", "kind": "neighborhood",
        "rappid": "rappid:v2:neighborhood:@kody-w/fake:abc@github.com/kody-w/fake",
        "ok": False,
        "drift": [
            {"category": "missing_files", "path": "rar/index.json", "detail": "required file absent"},
            {"category": "schema_drift", "path": "rappid.json", "detail": "schema is rapp-rappid/1.0; expected 2.0"},
        ],
    }],
    "by_kind": {"neighborhood": 1}, "summary": {}, "next_actions": [],
}
out = json.loads(m.BondRhythmAgent().perform(_audit_override=fake_audit, _bonds_file=sys.argv[2]))
assert out["drift_count"] == 1
assert out["by_direction"]["LOCAL_TO_GLOBAL"] == 1, f"by_direction={out['by_direction']}"
assert len(out["suggested_actions"]) == 1
sa = out["suggested_actions"][0]
assert sa["direction"] == "LOCAL_TO_GLOBAL"
assert sa["agent_to_invoke"] == "Graft", f"expected Graft for neighborhood; got {sa['agent_to_invoke']}"
assert sa["offspring"] == "fake-neighborhood"
assert "Graft.perform" in sa["one_liner"]
print("OK")
PY

heading "Step 6 — Drift classification: GLOBAL→LOCAL pull for kernel_drift"
python3 - "$AGENT" "$SANDBOX/bonds-step6.json" <<'PY' && step_pass "kernel_drift correctly classified as GLOBAL_TO_LOCAL → suggest RarLoader" || step_fail "classifier wrong"
import importlib.util, json, os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("br", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
fake_audit = {
    "schema": "rapp-ecosystem-audit/1.0", "mode": "offline",
    "offspring_count": 1, "drift_count": 1,
    "offspring": [{
        "name": "ant-farm", "kind": "ant-farm",
        "rappid": "rappid:v2:ant-farm:@kody-w/ant-farm:def@github.com/kody-w/ant-farm",
        "ok": False,
        "drift": [
            {"category": "kernel_drift", "path": "agents/basic_agent.py",
             "detail": "kernel agent sha256 differs from local cache"},
        ],
    }],
    "by_kind": {"ant-farm": 1}, "summary": {}, "next_actions": [],
}
out = json.loads(m.BondRhythmAgent().perform(_audit_override=fake_audit, _bonds_file=sys.argv[2]))
assert out["by_direction"]["GLOBAL_TO_LOCAL"] == 1, f"by_direction={out['by_direction']}"
sa = out["suggested_actions"][0]
assert sa["direction"] == "GLOBAL_TO_LOCAL"
assert sa["agent_to_invoke"] == "RarLoader"
assert "RarLoader.perform" in sa["one_liner"]
print("OK")
PY

heading "Step 7 — Bond event recorded with kind='rhythm' + drift_count + degraded fields"
python3 - "$AGENT" "$SANDBOX/bonds-step7.json" <<'PY' && step_pass "bonds.json gained kind='rhythm' event with full metadata" || step_fail "bond event missing or malformed"
import importlib.util, json, os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("br", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
bonds_path = sys.argv[2]
fake_audit = {"schema": "rapp-ecosystem-audit/1.0", "mode": "offline",
              "offspring_count": 3, "drift_count": 2, "offspring": [],
              "by_kind": {}, "summary": {}, "next_actions": []}
m.BondRhythmAgent().perform(_audit_override=fake_audit, _bonds_file=bonds_path)
doc = json.load(open(bonds_path))
assert "events" in doc
ev = [e for e in doc["events"] if e.get("kind") == "rhythm"]
assert len(ev) == 1, f"expected 1 rhythm event; got {len(ev)}"
e = ev[0]
for key in ("at", "kind", "drift_count", "offspring_audited", "mode", "degraded", "suggested_action_count", "note"):
    assert key in e, f"missing field: {key}"
assert e["drift_count"] == 2
assert e["offspring_audited"] == 3
print("OK")
PY

heading "Step 8 — time_since_last_pulse_seconds tracked across consecutive pulses"
python3 - "$AGENT" "$SANDBOX/bonds-step8.json" <<'PY' && step_pass "second pulse reports last_pulse_at + time_since_last_pulse_seconds" || step_fail "rhythm not tracking inter-pulse interval"
import importlib.util, json, os, sys, time
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("br", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
bonds = sys.argv[2]
fake = {"schema": "rapp-ecosystem-audit/1.0", "mode": "offline",
        "offspring_count": 0, "drift_count": 0, "offspring": [],
        "by_kind": {}, "summary": {}, "next_actions": []}
out1 = json.loads(m.BondRhythmAgent().perform(_audit_override=fake, _bonds_file=bonds))
assert out1["last_pulse_at"] is None, "first pulse should report no prior"
assert out1["time_since_last_pulse_seconds"] is None
time.sleep(1.1)
out2 = json.loads(m.BondRhythmAgent().perform(_audit_override=fake, _bonds_file=bonds))
assert out2["last_pulse_at"] == out1["pulse_at"], "second pulse should reference first as last"
assert out2["time_since_last_pulse_seconds"] is not None
assert out2["time_since_last_pulse_seconds"] >= 1
print("OK")
PY

heading "Step 9 — Graceful degradation: bad repo_root → degraded=True + valid envelope"
python3 - "$AGENT" "$SANDBOX/bonds-step9.json" <<'PY' && step_pass "degrades cleanly when repo_root unresolvable, returns valid envelope" || step_fail "rhythm crashed or returned malformed envelope on degradation"
import importlib.util, json, os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("br", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = json.loads(m.BondRhythmAgent().perform(repo_root="/nonexistent/path/to/repo", _bonds_file=sys.argv[2]))
assert out["schema"] == "rapp-rhythm-pulse/1.0"
assert out["ok"] is True, "rhythm should still report ok=True even when degraded"
assert out["degraded"] is True
assert out["degradation_reason"] is not None
assert out["drift_count"] == 0
print("OK")
PY

heading "Step 10 — by_direction counts add up to offspring_count"
python3 - "$AGENT" "$SANDBOX/bonds-step10.json" <<'PY' && step_pass "by_direction totals match offspring_count" || step_fail "direction counts inconsistent"
import importlib.util, json, os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("br", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
fake_audit = {
    "schema": "rapp-ecosystem-audit/1.0", "mode": "offline",
    "offspring_count": 3, "drift_count": 2,
    "offspring": [
        {"name": "a", "kind": "neighborhood", "ok": True, "drift": []},
        {"name": "b", "kind": "neighborhood", "ok": False,
         "drift": [{"category": "missing_files", "path": "x", "detail": ""}]},
        {"name": "c", "kind": "ant-farm", "ok": False,
         "drift": [{"category": "kernel_drift", "path": "y", "detail": ""}]},
    ],
    "by_kind": {"neighborhood": 2, "ant-farm": 1}, "summary": {}, "next_actions": [],
}
out = json.loads(m.BondRhythmAgent().perform(_audit_override=fake_audit, _bonds_file=sys.argv[2]))
total = sum(out["by_direction"].values())
assert total == 3, f"by_direction totals {total}; offspring_count=3"
assert out["by_direction"]["ALIGNED"] == 1
assert out["by_direction"]["LOCAL_TO_GLOBAL"] == 1
assert out["by_direction"]["GLOBAL_TO_LOCAL"] == 1
assert len(out["suggested_actions"]) == 2  # ALIGNED has no action
print("OK")
PY

scenario_summary
