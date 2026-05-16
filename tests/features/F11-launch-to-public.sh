#!/usr/bin/env bash
# tests/features/F11-launch-to-public.sh — launch_to_public_agent conformance.
#
# Verifies the LOCAL→GLOBAL half of the Bond Pulse:
#   1. Agent file present + parses + rapp-agent/1.0 contract
#   2. Emits rapp-launch-result/1.0 envelope
#   3. Default dry_run=True is safe (no fork/push)
#   4. Local-fixture launch packs an egg + writes scaffolding additively
#   5. Egg sha256 fingerprint matches the bytes written to data/launch.egg
#   6. LAUNCH_CONTINUATION.md written + contains the resume one-liner
#   7. Bond event recorded — kind="launch" with egg_sha256
#   8. bond_preserve_local: upstream files byte-identical (additive only)
#   9. Rhythm self-description block present (LOCAL→GLOBAL direction)
#  10. Pre-existing rappid.json is NOT overwritten

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F11 — Launch to public (LOCAL→GLOBAL half of Bond Pulse)" \
                "snapshot local brainstem → plant/graft as public repo with continuation manifest"

AGENT="$REPO_ROOT/rapp_brainstem/agents/launch_to_public_agent.py"
SANDBOX=$(osi_sandbox "rapp-feature-F11")
trap "osi_cleanup_dir '$SANDBOX'" EXIT

heading "Step 1 — Agent file present + parses + rapp-agent/1.0 contract"
if [ -f "$AGENT" ] && python3 -c "import ast; ast.parse(open('$AGENT').read())" 2>/dev/null; then
  if grep -q "class LaunchToPublicAgent" "$AGENT" \
     && grep -q "metadata\s*=" "$AGENT" \
     && grep -q "def perform" "$AGENT" \
     && grep -q "rapp-launch-result/1.0" "$AGENT"; then
    step_pass "LaunchToPublicAgent has class + metadata + perform + emits rapp-launch-result/1.0"
  else
    step_fail "agent contract incomplete"
  fi
else
  step_fail "agent missing or syntax error"
fi

# Build a synthetic local brainstem (rappid + soul + agents)
BS="$SANDBOX/brainstem"
mkdir -p "$BS/agents" "$BS/.brainstem_data"
cat > "$BS/rappid.json" <<'JSON'
{
  "schema": "rapp-rappid/2.0",
  "rappid": "rappid:v2:hatched:@local/test-bs:0123456789abcdef0123456789abcdef@local/test",
  "kind": "brainstem-instance",
  "name": "test-bs",
  "born_at": "2026-05-09T00:00:00Z",
  "incarnations": 1
}
JSON
cat > "$BS/soul.md" <<'MD'
# Test Brainstem Soul
## Identity
You are the test brainstem.
MD
cat > "$BS/agents/basic_agent.py" <<'PY'
class BasicAgent:
    def __init__(self): self.name = self.__class__.__name__
    def perform(self, **kwargs): return ""
PY
cat > "$BS/agents/launchable_agent.py" <<'PY'
from basic_agent import BasicAgent
class LaunchableAgent(BasicAgent):
    metadata = {"name": "Launchable", "description": "test", "parameters": {"type": "object", "properties": {}}}
    def perform(self, **kwargs): return "launched"
PY
echo '{"public": ["alive"]}' > "$BS/.brainstem_data/memory.json"

# Build a synthetic upstream "public repo" with pre-existing content
UP="$SANDBOX/upstream-public"
mkdir -p "$UP/src"
echo "# Upstream README" > "$UP/README.md"
echo "MIT" > "$UP/LICENSE"
echo "print('upstream code')" > "$UP/src/main.py"

heading "Step 2 — Default dry_run=True is safe (no fork/push)"
python3 - "$AGENT" <<'PY' && step_pass "dry_run defaults true; no git/gh attempted" || step_fail "default not safe"
import importlib.util, json, os, sys
# launch_to_public_agent imports graft_neighborhood_agent + bond.py via fallback
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("launch", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = json.loads(m.LaunchToPublicAgent().perform(
    target_repo="some/dest", instructions="Continue the work."
))
assert out["dry_run"] is True
assert out["git_commit_sha"] is None
print("OK")
PY

heading "Step 3 — Local-fixture launch packs an egg + writes scaffolding"
WS="$SANDBOX/workspace1"
python3 - "$AGENT" "$BS" "$UP" "$WS" <<'PY' && step_pass "local-fixture launch ok=True; scaffold + egg + continuation written" || step_fail "local-fixture launch broke"
import importlib.util, json, os, sys
# launch_to_public_agent imports graft_neighborhood_agent + bond.py via fallback
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("launch", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = json.loads(m.LaunchToPublicAgent().perform(
    target_repo="testowner/test-launched",
    instructions="Continue the work — minimal continuation instructions for the F11 test.",
    _local_brainstem_dir=sys.argv[2],
    _local_target_dir=sys.argv[3],
    _workspace_dir=sys.argv[4],
    _skip_push=True,
    dry_run=False,
))
assert out["ok"] is True
written_paths = [w["path"] for w in out["scaffold"]["written"]]
for required in ("rappid.json", "neighborhood.json", "soul.md", "card.json", "members.json",
                 "rar/index.json", "data/launch.egg", "data/launch_fingerprint.json",
                 "LAUNCH_CONTINUATION.md"):
    assert required in written_paths, f"missing {required} in scaffold.written: {written_paths}"
print("OK")
PY

heading "Step 4 — Fingerprint sha256 matches the bytes written to data/launch.egg"
python3 - "$WS" <<'PY' && step_pass "egg sha256 matches fingerprint exactly" || step_fail "egg sha256 mismatch"
import hashlib, json, os, sys
ws = sys.argv[1]
fingerprint = json.load(open(os.path.join(ws, "fork", "data", "launch_fingerprint.json")))
with open(os.path.join(ws, "fork", "data", "launch.egg"), "rb") as f:
    actual = hashlib.sha256(f.read()).hexdigest()
expected = fingerprint["egg_sha256"]
assert actual == expected, f"egg sha256 mismatch: file={actual[:12]}, fingerprint={expected[:12]}"
assert fingerprint["schema"] == "rapp-launch-fingerprint/1.0"
print("OK")
PY

heading "Step 5 — LAUNCH_CONTINUATION.md contains the resume one-liner + schema"
python3 - "$WS" <<'PY' && step_pass "continuation manifest has all required sections" || step_fail "manifest missing required content"
import os, sys
ws = sys.argv[1]
md = open(os.path.join(ws, "fork", "LAUNCH_CONTINUATION.md")).read()
for required in ("rapp-launch-continuation/1.0", "Continuation instructions", "Egg sha256",
                 "data/launch.egg", "shasum", "utils.bond hatch"):
    assert required in md, f"continuation manifest missing: {required!r}"
print("OK")
PY

heading "Step 6 — Bond event recorded with kind='launch'"
python3 - "$WS" <<'PY' && step_pass "bonds.json has kind='launch' event with egg_sha256 + target_repo" || step_fail "bond event wrong shape"
import json, os, sys
b = json.load(open(os.path.join(sys.argv[1], "fork", "bonds.json")))
launch_events = [e for e in b["events"] if e.get("kind") == "launch"]
assert len(launch_events) >= 1
ev = launch_events[-1]
assert "egg_sha256" in ev and len(ev["egg_sha256"]) == 64
assert ev.get("to_repo") == "testowner/test-launched"
assert ev.get("from_brainstem_rappid", "").startswith("rappid:v2:")
print("OK")
PY

heading "Step 7 — bond_preserve_local: upstream files byte-identical"
python3 - "$AGENT" "$BS" "$UP" "$SANDBOX/workspace2" <<'PY' && step_pass "upstream README/LICENSE/src preserved (clobbered=0)" || step_fail "upstream content clobbered"
import hashlib, importlib.util, json, os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("launch", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
# Snapshot upstream sha256s before launch
def _sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()
pre_readme = _sha(os.path.join(sys.argv[3], "README.md"))
pre_license = _sha(os.path.join(sys.argv[3], "LICENSE"))
pre_src = _sha(os.path.join(sys.argv[3], "src/main.py"))
out = json.loads(m.LaunchToPublicAgent().perform(
    target_repo="testowner/test-launched-2", instructions="x",
    _local_brainstem_dir=sys.argv[2],
    _local_target_dir=sys.argv[3],
    _workspace_dir=sys.argv[4],
    _skip_push=True, dry_run=False,
))
assert out["bond_preserve_local"]["upstream_files_clobbered"] == 0
# Post-launch: all upstream files byte-identical
post = sys.argv[4] + "/fork"
assert _sha(os.path.join(post, "README.md")) == pre_readme
assert _sha(os.path.join(post, "LICENSE")) == pre_license
assert _sha(os.path.join(post, "src/main.py")) == pre_src
print("OK")
PY

heading "Step 8 — Rhythm self-description in result envelope"
python3 - "$AGENT" "$BS" "$UP" "$SANDBOX/workspace3" <<'PY' && step_pass "result envelope advertises LOCAL→GLOBAL direction" || step_fail "rhythm hint missing"
import importlib.util, json, os, sys
# launch_to_public_agent imports graft_neighborhood_agent + bond.py via fallback
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("launch", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = json.loads(m.LaunchToPublicAgent().perform(
    target_repo="testowner/test-rhythm", instructions="x",
    _local_brainstem_dir=sys.argv[2], _local_target_dir=sys.argv[3],
    _workspace_dir=sys.argv[4], _skip_push=True, dry_run=False,
))
rhythm = out.get("rhythm") or {}
assert "LOCAL" in rhythm.get("this_direction", "") and "GLOBAL" in rhythm.get("this_direction", "")
assert "rar_loader" in rhythm.get("return_direction", "").lower() or "graft" in rhythm.get("return_direction", "").lower()
print("OK")
PY

heading "Step 9 — Pre-existing rappid.json in upstream → NOT overwritten"
UP_WITH_RAPPID="$SANDBOX/upstream-with-rappid"
mkdir -p "$UP_WITH_RAPPID"
echo "# Pre-existing repo" > "$UP_WITH_RAPPID/README.md"
cat > "$UP_WITH_RAPPID/rappid.json" <<'JSON'
{"schema": "pre-existing/1.0", "rappid": "ORIGINAL_KEEP_ME"}
JSON
python3 - "$AGENT" "$BS" "$UP_WITH_RAPPID" "$SANDBOX/workspace4" <<'PY' && step_pass "existing rappid.json preserved (additive overlay only)" || step_fail "existing rappid.json clobbered"
import importlib.util, json, os, sys
# launch_to_public_agent imports graft_neighborhood_agent + bond.py via fallback
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("launch", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
out = json.loads(m.LaunchToPublicAgent().perform(
    target_repo="testowner/test-no-clobber", instructions="x",
    _local_brainstem_dir=sys.argv[2], _local_target_dir=sys.argv[3],
    _workspace_dir=sys.argv[4], _skip_push=True, dry_run=False,
))
skipped = [s["path"] for s in out["scaffold"]["skipped"]]
assert "rappid.json" in skipped, f"rappid.json should be skipped; got skipped={skipped}"
assert out["bond_preserve_local"]["upstream_files_clobbered"] == 0
print("OK")
PY

scenario_summary
