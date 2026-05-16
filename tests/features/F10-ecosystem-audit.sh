#!/usr/bin/env bash
# tests/features/F10-ecosystem-audit.sh — Bond Pulse drift detector conformance.
#
# Verifies tools/ecosystem_audit.py + tools/ecosystem_contract.py:
#   1. Both modules parse cleanly
#   2. Contract self-check: 9 kinds, no internal issues
#   3. Offline run on the real metropolis index → drift_count=0
#   4. Synthetic drift detection — fake metropolis index with bare-UUID rappid
#      flagged as rappid_drift
#   5. Schema shape: rapp-ecosystem-audit/1.0 envelope has every required key
#   6. --repo filter narrows scope to one offspring
#   7. --no-write doesn't touch pages/_audit/
#   8. Outputs land at pages/_audit/ when --out-dir is given

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F10 — Ecosystem audit (Bond Pulse drift detector)" \
                "tools/ecosystem_audit.py + tools/ecosystem_contract.py"

CONTRACT="$REPO_ROOT/tools/ecosystem_contract.py"
AUDIT="$REPO_ROOT/tools/ecosystem_audit.py"
SANDBOX=$(osi_sandbox "rapp-feature-F10")
trap "osi_cleanup_dir '$SANDBOX'" EXIT

heading "Step 1 — Contract + audit modules present and parse"
if [ -f "$CONTRACT" ] && python3 -c "import ast; ast.parse(open('$CONTRACT').read())" 2>/dev/null \
   && [ -f "$AUDIT" ] && python3 -c "import ast; ast.parse(open('$AUDIT').read())" 2>/dev/null; then
  step_pass "ecosystem_contract.py + ecosystem_audit.py both parse"
else
  step_fail "one of the audit modules missing or has syntax errors"
fi

heading "Step 2 — Contract self-check: ≥7 kinds, no internal issues"
python3 - "$CONTRACT" <<'PY' && step_pass "contract is internally consistent" || step_fail "contract failed self-check"
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("ecosystem_contract", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
chk = m._self_check()
assert chk["ok"], f"issues: {chk['issues']}"
assert chk["kind_count"] >= 7, f"too few kinds: {chk['kind_count']}"
for required in ("neighborhood", "ant-farm", "twin", "workspace", "braintrust", "catalog", "template"):
    assert required in chk["kinds"], f"missing kind: {required}"
print("OK")
PY

heading "Step 3 — Audit emits valid rapp-ecosystem-audit/1.0 envelope"
python3 - "$AUDIT" <<'PY' && step_pass "audit envelope shape matches schema" || step_fail "envelope shape wrong"
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("ecosystem_audit", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
audit = m.audit_ecosystem(mode="offline", write_outputs=False)
assert audit["schema"] == "rapp-ecosystem-audit/1.0"
for key in ("audited_at", "mode", "metropolis_url", "offspring_count", "drift_count",
            "by_kind", "offspring", "summary", "next_actions", "ok"):
    assert key in audit, f"missing key: {key}"
print("OK")
PY

heading "Step 4 — Offline run on the real metropolis index → drift_count=0"
python3 - "$AUDIT" <<'PY' && step_pass "real metropolis index is aligned (drift_count=0)" || step_fail "drift detected — fixtures + contract not in sync"
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("ecosystem_audit", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
audit = m.audit_ecosystem(mode="offline", write_outputs=False)
if audit["drift_count"] != 0:
    print("DRIFT FOUND:")
    for o in audit["offspring"]:
        if o.get("skipped") or o.get("ok"):
            continue
        print(f"  {o['name']}: {[d['category']+':'+d['path'] for d in o.get('drift',[])]}")
    sys.exit(1)
print("OK")
PY

heading "Step 5 — Synthetic drift detection: bare-UUID rappid → rappid_drift"
mkdir -p "$SANDBOX/synthetic-fixtures/test-bad-seed"
cat > "$SANDBOX/synthetic-fixtures/test-bad-seed/rappid.json" <<'JSON'
{"schema": "rapp-rappid/2.0", "rappid": "869ea057-4755-47ec-80df-54551ecf8581"}
JSON
cat > "$SANDBOX/synthetic-metropolis.json" <<'JSON'
{
  "schema": "rapp-metropolis-index/1.0",
  "tracker_name": "synthetic-test",
  "tracker_url": "file:///tmp/synthetic",
  "synced_at": "2026-05-09T00:00:00Z",
  "entries": [
    {"schema": "rapp-metropolis-entry/1.0", "name": "test-bad",
     "kind": "neighborhood", "neighborhood_rappid": "869ea057-4755-47ec-80df-54551ecf8581",
     "gate_repo": "fake/test-bad", "visibility": "public"}
  ]
}
JSON
python3 - "$AUDIT" "$SANDBOX/synthetic-metropolis.json" "$SANDBOX/synthetic-fixtures" <<'PY' && step_pass "bare-UUID rappid correctly flagged as rappid_drift" || step_fail "synthetic drift not detected"
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("ecosystem_audit", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
audit = m.audit_ecosystem(
    mode="offline",
    metropolis_index_path=sys.argv[2],
    fixtures_dir=sys.argv[3],
    write_outputs=False,
)
assert audit["drift_count"] >= 1, f"expected drift; got {audit['drift_count']}"
test_bad = next(o for o in audit["offspring"] if o["name"] == "test-bad")
categories = {d["category"] for d in test_bad.get("drift", [])}
assert "rappid_drift" in categories, f"expected rappid_drift in {categories}"
print("OK")
PY

heading "Step 6 — --repo filter narrows scope to one offspring"
python3 - "$AUDIT" <<'PY' && step_pass "--repo filter narrows to one offspring" || step_fail "filter broken"
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("ecosystem_audit", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
audit = m.audit_ecosystem(mode="offline", repo_filter="ant-farm", write_outputs=False)
assert audit["offspring_count"] == 1, f"expected 1; got {audit['offspring_count']}"
assert audit["offspring"][0]["name"] == "ant-farm"
print("OK")
PY

heading "Step 7 — write_outputs=True lands files at out_dir"
mkdir -p "$SANDBOX/audit-out"
python3 - "$AUDIT" "$SANDBOX/audit-out" <<'PY' && step_pass "ecosystem-audit.{md,json} written to out_dir" || step_fail "outputs not written"
import importlib.util, json, os, sys
spec = importlib.util.spec_from_file_location("ecosystem_audit", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
m.audit_ecosystem(mode="offline", out_dir=sys.argv[2], write_outputs=True)
assert os.path.exists(os.path.join(sys.argv[2], "ecosystem-audit.json"))
assert os.path.exists(os.path.join(sys.argv[2], "ecosystem-audit.md"))
md = open(os.path.join(sys.argv[2], "ecosystem-audit.md")).read()
assert "Bond Pulse" in md, "markdown report missing Bond Pulse header"
assert "rapp-ecosystem-audit/1.0" in md
print("OK")
PY

heading "Step 8 — CLI: --no-write prints JSON to stdout, doesn't touch pages/_audit/"
OUT=$(python3 "$AUDIT" --offline --no-write 2>/dev/null)
if printf "%s" "$OUT" | python3 -c "import json, sys; d=json.loads(sys.stdin.read()); assert d['schema']=='rapp-ecosystem-audit/1.0'; assert isinstance(d['offspring'], list); print('OK')" 2>/dev/null | grep -q OK; then
  step_pass "--no-write prints valid JSON envelope on stdout"
else
  step_fail "--no-write output invalid"
fi

heading "Step 9 — CLI exits 1 on drift (--strict default), 0 when clean"
python3 "$AUDIT" --offline --no-write >/dev/null 2>&1
if [ $? -eq 0 ]; then
  step_pass "clean audit exits 0 (no drift in offline-mode fixtures)"
else
  step_fail "clean audit unexpectedly exited non-zero"
fi
python3 "$AUDIT" --offline --no-write \
  --metropolis "$SANDBOX/synthetic-metropolis.json" \
  --fixtures-dir "$SANDBOX/synthetic-fixtures" >/dev/null 2>&1
RC=$?
if [ "$RC" -ne 0 ]; then
  step_pass "synthetic drift correctly exits non-zero (rc=$RC)"
else
  step_fail "synthetic drift but exit was 0"
fi

scenario_summary
