#!/usr/bin/env bash
# tests/osi/X3-egg-lifecycle.sh — verify the egg lifecycle end-to-end.
#
# CC3: HERO_USECASE.md §1 (Charizard handoff). Pack → SHA verify → hatch
# round-trips through L4 (transport-agnostic) + L6 (envelope) + L7 (agent
# inventory).

source "$(dirname "$0")/_lib.sh"

osi_layer_intro "CC3 — Egg lifecycle" "Pack → SHA verify → hatch (HERO_USECASE.md §1 Charizard handoff)"

SANDBOX=$(osi_sandbox "rapp-osi-X3")
trap "osi_cleanup_dir '$SANDBOX'" EXIT

# 1. Build a synthetic seed (rappid + soul + 2 agents)
heading "Step 1 — Build synthetic seed organism"
SEED="$SANDBOX/seed"
mkdir -p "$SEED/agents" "$SEED/.brainstem_data"
cat >"$SEED/rappid.json" <<JSON
{
  "schema": "rapp-rappid/2.0",
  "rappid": "00000000-1111-4000-8000-aaaaaaaaaaaa",
  "kind": "experiment",
  "name": "osi-x3-seed",
  "display_name": "OSI X3 Test Seed",
  "kernel_version": "0.6.0",
  "planted_by": "osi-test",
  "planted_at": "2026-05-08T00:00:00Z"
}
JSON
cat >"$SEED/soul.md" <<'MD'
# Identity — read this every turn

You are OSI X3 Test Seed. You speak only as OSI X3 Test Seed.
Never introduce yourself as "RAPP", "an AI assistant", or any default branding.

|||VOICE|||
(empty by default)

|||TWIN|||
(empty by default)
MD
cat >"$SEED/agents/basic_agent.py" <<'PY'
class BasicAgent:
    def __init__(self):
        self.name = self.__class__.__name__
    def perform(self, **kwargs):
        return ""
PY
cat >"$SEED/agents/echo_agent.py" <<'PY'
from basic_agent import BasicAgent

class EchoAgent(BasicAgent):
    metadata = {
        "name": "echo",
        "description": "Echoes its input back unchanged.",
        "parameters": {"type": "object", "properties": {"text": {"type": "string"}}}
    }
    def perform(self, text=""):
        return f"echo: {text}"
PY
cat >"$SEED/.brainstem_data/memory.json" <<'JSON'
{"public": ["the seed knows its purpose"]}
JSON
if [ -f "$SEED/rappid.json" ] && [ -f "$SEED/soul.md" ] && [ -f "$SEED/agents/echo_agent.py" ] && [ -f "$SEED/.brainstem_data/memory.json" ]; then
  step_pass "seed built with rappid + soul + 2 agents + memory"
else
  step_fail "seed scaffolding incomplete"
fi

# 2. Pack the egg with brainstem-egg/2.2-organism manifest
heading "Step 2 — Pack: zip + sha256 hashes + manifest"
EGG="$SANDBOX/seed.egg"
python3 - "$SEED" "$EGG" <<'PY' && step_pass "egg packed with brainstem-egg/2.2-organism manifest" || step_fail "egg pack failed"
import hashlib, json, os, sys, zipfile
seed_dir, egg_path = sys.argv[1:3]
file_hashes = {}
with zipfile.ZipFile(egg_path, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(seed_dir):
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, seed_dir)
            with open(full, "rb") as fh:
                content = fh.read()
            file_hashes[rel] = hashlib.sha256(content).hexdigest()
            z.writestr(rel, content)
    manifest = {
        "schema": "brainstem-egg/2.2-organism",
        "type": "organism",
        "tier": "doorman",
        "exported_at": "2026-05-08T00:00:00Z",
        "rappid": "00000000-1111-4000-8000-aaaaaaaaaaaa",
        "kind": "experiment",
        "display_name": "OSI X3 Test Seed",
        "counts": {
            "agents": sum(1 for p in file_hashes if p.startswith("agents/") and p.endswith(".py")),
            "soul": 1, "rappid": 1, "data": sum(1 for p in file_hashes if p.startswith(".brainstem_data/")),
        },
        "provenance": {
            "schema": "rapp-egg-provenance/1.0",
            "scheme": "sha256",
            "file_hashes": file_hashes,
            "manifest_hash": hashlib.sha256(
                json.dumps(file_hashes, sort_keys=True).encode()
            ).hexdigest(),
        },
    }
    z.writestr("manifest.json", json.dumps(manifest, sort_keys=True, indent=2))
PY

# 3. Verify the egg before hatching (sha + manifest hash)
heading "Step 3 — Verify: sha256 file_hashes + manifest_hash"
python3 - "$EGG" <<'PY' && step_pass "all file hashes match + manifest hash matches" || step_fail "verify failed"
import hashlib, json, sys, zipfile
egg = sys.argv[1]
with zipfile.ZipFile(egg) as z:
    manifest = json.loads(z.read("manifest.json"))
    expected = manifest["provenance"]["file_hashes"]
    for path, want in expected.items():
        got = hashlib.sha256(z.read(path)).hexdigest()
        if got != want:
            print(f"hash mismatch for {path}")
            sys.exit(1)
    expected_manifest = manifest["provenance"]["manifest_hash"]
    actual_manifest = hashlib.sha256(json.dumps(expected, sort_keys=True).encode()).hexdigest()
    if expected_manifest != actual_manifest:
        print("manifest hash mismatch")
        sys.exit(1)
print("OK")
PY

# 4. Hatch the egg into a fresh directory
heading "Step 4 — Hatch into fresh dir"
HATCHED="$SANDBOX/hatched"
mkdir -p "$HATCHED"
python3 - "$EGG" "$HATCHED" <<'PY' && step_pass "egg unpacked into $HATCHED" || step_fail "hatch failed"
import sys, zipfile
egg, dst = sys.argv[1:3]
with zipfile.ZipFile(egg) as z:
    z.extractall(dst)
PY

# 5. Confirm rappid preserved bit-for-bit
heading "Step 5 — rappid preserved bit-for-bit (same UUID, same kernel_version)"
ORIG_RAPPID=$(python3 -c "import json; print(json.load(open('$SEED/rappid.json'))['rappid'])")
HATCHED_RAPPID=$(python3 -c "import json; print(json.load(open('$HATCHED/rappid.json'))['rappid'])")
if [ "$ORIG_RAPPID" = "$HATCHED_RAPPID" ]; then
  step_pass "rappid preserved: $HATCHED_RAPPID"
else
  step_fail "rappid drift: $ORIG_RAPPID → $HATCHED_RAPPID"
fi

# 6. Confirm hatched seed is identical to source (excluding manifest.json which is added at pack time)
heading "Step 6 — Hatched seed == source seed (full diff, excluding manifest.json)"
DIFF=$(diff -r --exclude=manifest.json "$SEED" "$HATCHED" 2>&1 | wc -l | tr -d ' ')
if [ "$DIFF" -eq 0 ]; then
  step_pass "hatched seed is bit-for-bit identical to source (excluding the synthesized manifest.json)"
else
  step_fail "hatched seed differs from source: $DIFF diff lines"
fi

# 7. Hatched echo agent is loadable + perform()s correctly
heading "Step 7 — Hatched echo agent is loadable + perform()s correctly"
RESULT=$(python3 - "$HATCHED/agents/echo_agent.py" "$HATCHED/agents" <<'PY'
import importlib.util, sys
sys.path.insert(0, sys.argv[2])
spec = importlib.util.spec_from_file_location("echo_agent", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
agent = m.EchoAgent()
result = agent.perform(text="hello from hatched egg")
print(result)
PY
)
if [ "$RESULT" = "echo: hello from hatched egg" ]; then
  step_pass "hatched agent.perform() works: '$RESULT'"
else
  step_fail "hatched agent broken: '$RESULT'"
fi

# 8. Tampering detection: edit a file in the hatched seed → re-verify FAILS
# Logic: python exits 0 when tampering IS detected; non-zero when it's missed.
# Bash: && step_pass on python exit 0 (= tampering detected = success).
heading "Step 8 — Tampering detection: modified file fails verification"
echo "tampered" >>"$HATCHED/soul.md"
python3 - "$EGG" "$HATCHED" <<'PY' && step_pass "tampered hatched seed correctly fails re-verification" || step_fail "tampering not detected — integrity broken"
import hashlib, json, os, sys, zipfile
egg, hatched = sys.argv[1:3]
with zipfile.ZipFile(egg) as z:
    manifest = json.loads(z.read("manifest.json"))
expected = manifest["provenance"]["file_hashes"]
for path, want in expected.items():
    full = os.path.join(hatched, path)
    if not os.path.exists(full):
        sys.exit(0)  # missing file = mismatch detected
    with open(full, "rb") as fh:
        got = hashlib.sha256(fh.read()).hexdigest()
    if got != want:
        sys.exit(0)  # mismatch detected (good — tampering caught)
print("no mismatch found — tampering missed!")
sys.exit(1)
PY

scenario_summary
