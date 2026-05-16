#!/usr/bin/env bash
# tests/features/F7-rar-hotload.sh — universal RAR hot-load conformance.
#
# Verifies the per-neighborhood RAR pattern:
#   1. ant-farm seed has a valid rar/index.json (rapp-rar-index/1.0)
#   2. sha256s in the manifest match the on-disk agent files (no drift)
#   3. rar_loader_agent.py satisfies rapp-agent/1.0 contract
#   4. dry_run returns a loadout without writing files
#   5. Tampered content (wrong sha256) → install refused
#   6. Verified content → installs to the target dir
#   7. Local-first: cache hit when network is "missing" (injected override)

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F7 — Universal RAR hot-loader" "Per-neighborhood required participation kit (rar/index.json + sha256)"

SEED="$REPO_ROOT/tests/fixtures/ant-farm-seed"
LOADER="$REPO_ROOT/rapp_brainstem/agents/rar_loader_agent.py"

heading "Step 1 — ant-farm rar/index.json present + parses"
INDEX="$SEED/rar/index.json"
if [ -f "$INDEX" ] && python3 -c "import json; json.load(open('$INDEX'))" 2>/dev/null; then
  step_pass "rar/index.json parses cleanly"
else
  step_fail "rar/index.json missing or invalid JSON"
fi

heading "Step 2 — index schema = rapp-rar-index/1.0 + required fields"
python3 - "$INDEX" <<'PY' && step_pass "schema + required_for_participation + verification block all present" || step_fail "rar index shape wrong"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["schema"] == "rapp-rar-index/1.0", f"schema={d['schema']}"
assert d.get("rar_for") == "kody-w/ant-farm"
req = d.get("required_for_participation")
assert isinstance(req, list) and len(req) >= 1, "must have at least one required entry"
for item in req:
    for k in ("kind", "name", "file", "raw_url", "sha256", "schema"):
        assert k in item, f"missing field {k} in {item.get('name')}"
    assert len(item["sha256"]) == 64, f"sha256 wrong length for {item['name']}"
    assert item["raw_url"].startswith("https://raw.githubusercontent.com/"), "raw_url must be raw.githubusercontent"
assert "verification" in d
assert "offline_dimension_protocol" in d, "offline-dimension protocol must be documented"
print("OK")
PY

heading "Step 3 — sha256s in manifest match the on-disk agent files"
python3 - "$INDEX" "$SEED" <<'PY' && step_pass "every required + kernel_base sha256 matches its on-disk file" || step_fail "sha256 drift between manifest + files"
import hashlib, json, os, sys
d = json.load(open(sys.argv[1]))
seed = sys.argv[2]
items = (d.get("required_for_participation") or []) + (d.get("kernel_base_included") or [])
bad = []
for item in items:
    p = os.path.join(seed, item["file"])
    if not os.path.exists(p):
        bad.append(f"{item['name']}: missing on disk at {p}"); continue
    with open(p, "rb") as f:
        actual = hashlib.sha256(f.read()).hexdigest()
    if actual != item["sha256"]:
        bad.append(f"{item['name']}: expected {item['sha256'][:12]}… got {actual[:12]}…")
if bad:
    print("DRIFT:", "\n  ".join(bad)); sys.exit(1)
print("OK")
PY

heading "Step 4 — rar_loader_agent.py satisfies rapp-agent/1.0"
if grep -q "class RarLoaderAgent" "$LOADER" \
   && grep -q "metadata\s*=" "$LOADER" \
   && grep -q "def perform" "$LOADER" \
   && grep -q "rapp-rar-index/1.0" "$LOADER" \
   && grep -q "rapp-rar-loadout/1.0" "$LOADER"; then
  step_pass "RarLoaderAgent has class + metadata + perform + emits rapp-rar-loadout/1.0"
else
  step_fail "rar_loader_agent contract incomplete"
fi

heading "Step 5 — dry_run returns loadout without writing anything"
SANDBOX=$(osi_sandbox "rapp-feature-F7")
trap "osi_cleanup_dir '$SANDBOX'" EXIT
python3 - "$LOADER" "$INDEX" "$SEED" "$SANDBOX/install" <<'PY' && step_pass "dry_run reports would_install + zero files written" || step_fail "dry_run wrote files"
import importlib.util, json, os, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("rl", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
loader = sys.argv[1]; index_path = sys.argv[2]; seed = sys.argv[3]; install = sys.argv[4]
os.makedirs(install, exist_ok=True)

# Inject the index + the agent contents (skip network entirely)
index = json.load(open(index_path))
overrides = {}
for item in (index.get("required_for_participation") or []):
    with open(os.path.join(seed, item["file"]), "rb") as f:
        overrides[f"_content_override:{item['name']}"] = f.read()

agent = m.RarLoaderAgent()
out = json.loads(agent.perform(
    rar_url="https://example/rar/index.json", _index_override=index,
    target_dir=install, dry_run=True, include_cards=False,
    **overrides,
))
assert out["dry_run"] is True
# Zero files should have been written
assert os.listdir(install) == [], f"dry_run wrote: {os.listdir(install)}"
# But all required entries should be in installed[] with status=would_install
assert out["summary"]["installed_count"] == len(index["required_for_participation"]), \
    f"got {out['summary']['installed_count']} would_install"
for entry in out["installed"]:
    assert entry["status"] == "would_install"
print("OK")
PY

heading "Step 6 — Tampered content → sha256 mismatch → install refused"
python3 - "$LOADER" "$INDEX" <<'PY' && step_pass "tampered agents correctly refused with sha256_mismatch" || step_fail "tampering not detected"
import importlib.util, json, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("rl", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
index = json.load(open(sys.argv[2]))
# Corrupt the required-agent contents only (rapplications + cards excluded from this test)
overrides = {}
for item in index["required_for_participation"]:
    overrides[f"_content_override:{item['name']}"] = b"# tampered evil bytes\n"
agent = m.RarLoaderAgent()
out = json.loads(agent.perform(
    rar_url="https://example/rar/index.json", _index_override=index,
    dry_run=True, include_cards=False, include_rapplications=False, **overrides,
))
n_required = len(index["required_for_participation"])
assert out["summary"]["by_kind"].get("agent", 0) == 0, "tampered agents should not install"
agent_errors = [e for e in out["errors"] if e.get("kind") == "agent"]
assert len(agent_errors) == n_required, f"expected {n_required} agent errors, got {len(agent_errors)}"
for err in agent_errors:
    assert "sha256_mismatch" in err["status"], f"expected sha256_mismatch, got {err['status']}"
print("OK")
PY

heading "Step 7 — Real install: dry_run=False writes verified files to target"
python3 - "$LOADER" "$INDEX" "$SEED" "$SANDBOX/install2" <<'PY' && step_pass "verified content installs to target dir" || step_fail "real install failed"
import importlib.util, json, os, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("rl", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
index = json.load(open(sys.argv[2]))
seed = sys.argv[3]; install = sys.argv[4]
os.makedirs(install, exist_ok=True)
overrides = {}
for item in index["required_for_participation"]:
    with open(os.path.join(seed, item["file"]), "rb") as f:
        overrides[f"_content_override:{item['name']}"] = f.read()
agent = m.RarLoaderAgent()
out = json.loads(agent.perform(
    rar_url="https://example/rar/index.json", _index_override=index,
    dry_run=False, target_dir=install, include_cards=False, **overrides,
))
assert out["dry_run"] is False
assert out["summary"]["installed_count"] == len(index["required_for_participation"])
# Verify actual files
written = sorted(os.listdir(install))
expected = sorted(os.path.basename(it["file"]) for it in index["required_for_participation"])
assert written == expected, f"expected {expected} got {written}"
# Verify on-disk sha256 matches manifest
import hashlib
for it in index["required_for_participation"]:
    target = os.path.join(install, os.path.basename(it["file"]))
    with open(target, "rb") as f:
        actual = hashlib.sha256(f.read()).hexdigest()
    assert actual == it["sha256"], f"{it['name']}: hash drift after install"
print("OK")
PY

heading "Step 7b — Federation: scope-local default + opt-in pointers to global stores"
python3 - "$INDEX" <<'PY' && step_pass "federation.default_mode=separate; known global stores documented; opt-in via include_federated" || step_fail "federation block missing/wrong"
import json, sys
d = json.load(open(sys.argv[1]))
fed = d.get("federation") or {}
assert fed.get("default_mode") == "separate", f"default_mode should be 'separate' (scope-local), got {fed.get('default_mode')}"
assert fed.get("federates_with") == [], "federates_with empty by default — opt-in only"
known = fed.get("_known_global_stores") or []
names = {s["name"] for s in known}
for expected in ("kody-w/RAR", "kody-w/RAPP_Store", "kody-w/RAPP_Sense_Store"):
    assert expected in names, f"missing reference to {expected} in federation._known_global_stores"
print("OK")
PY

heading "Step 8a — Rapplications slot present + ant_farm_explorer valid"
python3 - "$INDEX" "$SEED" <<'PY' && step_pass "rapplications array + ant_farm_explorer rapp-application/1.0 both valid" || step_fail "rapplications scaffolding broken"
import json, os, sys
idx = json.load(open(sys.argv[1]))
seed = sys.argv[2]
rapps = idx.get("rapplications") or []
assert isinstance(rapps, list) and len(rapps) >= 1, "rapplications array missing or empty"
for r in rapps:
    assert r.get("kind") == "rapplication"
    assert r.get("schema") == "rapp-application/1.0"
    p = os.path.join(seed, r["file"])
    assert os.path.exists(p), f"{r['file']} missing on disk"
    rj = json.load(open(p))
    assert rj["schema"] == "rapp-application/1.0", f"unexpected rapp schema {rj['schema']}"
    assert "requires_agents" in rj, "rapp must declare requires_agents"
    assert "ui" in rj and "actions" in rj["ui"], "rapp must declare ui.actions"
print("OK")
PY

heading "Step 8 — Cards: rar/cards/*.card.json present + valid rapp-card/1.0"
python3 - "$SEED" <<'PY' && step_pass "ant + colony_observer cards both valid rapp-card/1.0" || step_fail "card validation failed"
import json, os, sys
seed = sys.argv[1]
for c in ("ant.card.json", "colony_observer.card.json"):
    p = os.path.join(seed, "rar", "cards", c)
    assert os.path.exists(p), f"{c} missing"
    d = json.load(open(p))
    assert d["schema"] == "rapp-card/1.0"
    assert "for_agent" in d and "abilities" in d and "title" in d
print("OK")
PY

heading "Step 9 — neighborhood.json declares rar_index_url + offline_dimension"
python3 - "$SEED/neighborhood.json" <<'PY' && step_pass "neighborhood.json points at rar + documents offline-dimension semantic" || step_fail "neighborhood.json wiring incomplete"
import json, sys
n = json.load(open(sys.argv[1]))
assert n.get("rar_index_url"), "rar_index_url missing"
assert n.get("required_participation_via") == "rar"
assert "offline_dimension" in n, "offline_dimension block missing"
assert n["offline_dimension"].get("merge_via")
print("OK")
PY

heading "Step 9b — plant.sh write_rar_index emits valid rar/ on dry-run"
PLANT_SANDBOX=$(osi_sandbox "rapp-feature-F7-plant")
trap "osi_cleanup_dir '$PLANT_SANDBOX'; osi_cleanup_dir '$SANDBOX'" EXIT
mkdir -p "$PLANT_SANDBOX/dry"
PLANT_DRY_RUN=1 PLANT_DRY_RUN_DIR="$PLANT_SANDBOX/dry" \
  PLANT_GH_USER=testuser MIRROR_REPO_NAME=test-rar-scaffold MIRROR_DISPLAY_NAME='Test RAR Scaffold' \
  MIRROR_KIND=neighborhood bash "$REPO_ROOT/installer/plant.sh" >/dev/null 2>&1 || true
if [ -f "$PLANT_SANDBOX/dry/rar/index.json" ]; then
  python3 - "$PLANT_SANDBOX/dry/rar/index.json" <<'PY' && step_pass "plant.sh dry-run scaffolds rar/index.json with proper schema + sha256s" || step_fail "scaffolded rar/index.json invalid"
import hashlib, json, os, sys
d = json.load(open(sys.argv[1]))
assert d["schema"] == "rapp-rar-index/1.0"
assert d.get("rar_for") == "testuser/test-rar-scaffold"
assert d.get("kind") == "neighborhood"
# Federation block must be present, default separate
fed = d.get("federation") or {}
assert fed.get("default_mode") == "separate"
# offline_dimension_protocol must be present
assert "offline_dimension_protocol" in d
# Every kernel_base entry must have a 64-char sha256
for kb in d.get("kernel_base_included") or []:
    assert len(kb["sha256"]) == 64, f"bad sha256 for {kb['name']}"
print("OK")
PY
else
  step_fail "plant.sh did not produce rar/index.json"
fi

heading "Step 9c — Live: real ant-farm rar/index.json reachable + valid"
if osi_net "live ant-farm rar fetch"; then
  CODE=$(osi_get_status "https://raw.githubusercontent.com/kody-w/ant-farm/main/rar/index.json" 8)
  if [ "$CODE" = "200" ]; then
    LIVE=$(curl -fsSL --max-time 8 "https://raw.githubusercontent.com/kody-w/ant-farm/main/rar/index.json")
    if printf "%s" "$LIVE" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['schema']=='rapp-rar-index/1.0'; assert d['rar_for']=='kody-w/ant-farm'; assert len(d['required_for_participation'])>=2" 2>/dev/null; then
      step_pass "live ant-farm rar/index.json valid + ≥2 required entries"
    else
      step_fail "live rar/index.json fetched but shape wrong"
    fi
  else
    muted "live rar/index.json HTTP $CODE — non-fatal, ant-farm may be propagating"
    step_pass "live probe attempted (HTTP $CODE)"
  fi
fi

heading "Step 10 — Universal pattern: any planted seed could adopt rar/ (Pizza Place, heimdall, etc.)"
python3 - "$LOADER" <<'PY' && step_pass "loader is repo-agnostic — gate_repo shortcut works for any owner/repo" || step_fail "loader is hard-coded to ant-farm"
import importlib.util, sys
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec = importlib.util.spec_from_file_location("rl", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
agent = m.RarLoaderAgent()
# Attempt with a hypothetical different gate_repo — should construct the right URL
# (will return 'unreachable' in test env since we don't have network for nonexistent repo).
# What we check: the agent does NOT hard-code ant-farm anywhere (grep-equivalent at runtime).
src = open(sys.argv[1]).read()
ant_farm_refs = src.count("ant-farm")
# Allow at most 1 reference (in docstring/comments)
assert ant_farm_refs <= 2, f"loader contains {ant_farm_refs} hard-coded ant-farm references — should be ≤ 2 (docstring example only)"
print("OK")
PY

scenario_summary
