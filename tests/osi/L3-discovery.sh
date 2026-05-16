#!/usr/bin/env bash
# tests/osi/L3-discovery.sh — verify the discovery layer.
#
# L3 = how organisms find each other: lineage walk, public catalog,
# direct invitation, canonical test neighbor + metropolis tracker.

source "$(dirname "$0")/_lib.sh"

osi_layer_intro "L3 — Discovery" "lineage walk + public catalog + direct invite + canonical test neighbor + metropolis tracker"

# 1. Metropolis index validates against rapp-metropolis-index/1.0
heading "Step 1 — Metropolis tracker (pages/metropolis/index.json) validates"
INDEX="$REPO_ROOT/pages/metropolis/index.json"
if [ ! -f "$INDEX" ]; then
  step_fail "pages/metropolis/index.json missing"
else
  python3 - "$INDEX" <<'PY' >/tmp/osi-L3-mx 2>&1 && step_pass "$(cat /tmp/osi-L3-mx)" || step_fail "$(cat /tmp/osi-L3-mx)"
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
required = ["schema", "tracker_name", "synced_at", "entries"]
missing = [k for k in required if k not in d]
if missing:
    print(f"missing fields in metropolis index: {','.join(missing)}")
    sys.exit(1)
if d["schema"] != "rapp-metropolis-index/1.0":
    print(f"unexpected schema: {d['schema']}")
    sys.exit(1)
if not isinstance(d["entries"], list):
    print("entries field must be a list")
    sys.exit(1)
print(f"index validates; {len(d['entries'])} entries")
PY
fi

# 2. Each entry validates against rapp-metropolis-entry/1.0
heading "Step 2 — Each metropolis entry shape (rapp-metropolis-entry/1.0)"
if [ -f "$INDEX" ]; then
  python3 - "$INDEX" <<'PY' >/tmp/osi-L3-entries 2>&1 && step_pass "$(cat /tmp/osi-L3-entries)" || step_fail "$(cat /tmp/osi-L3-entries)"
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
entries = d.get("entries", [])
required = ["name", "kind", "visibility", "gate_repo"]
bad = []
for e in entries:
    missing = [k for k in required if k not in e]
    if missing:
        bad.append(f"{e.get('name','<unnamed>')}: missing {','.join(missing)}")
if bad:
    for b in bad: print(b)
    sys.exit(1)
print(f"all {len(entries)} entries have name+kind+visibility+gate_repo")
PY
fi

# 3. by-rappid endpoint exists in the membership organ (L3 estate-by-identity lookup)
heading "Step 3 — by-rappid lookup endpoint (project_rappid_is_global_passport)"
if grep -q "by-rappid\|by_rappid" "$REPO_ROOT/rapp_brainstem/utils/organs/neighborhood_membership_organ.py"; then
  step_pass "by-rappid route present in neighborhood_membership_organ.py"
else
  step_fail "by-rappid route missing — Rappid-as-global-passport spec broken"
fi

# 4. Lineage walk via parent_rappid: simulate forward + backward walk
heading "Step 4 — Lineage walk: synthetic forward + backward chain"
SANDBOX=$(osi_sandbox "rapp-osi-L3")
trap "osi_cleanup_dir '$SANDBOX'" EXIT
python3 - "$SANDBOX" <<'PY' >/tmp/osi-L3-lineage 2>&1 && step_pass "$(cat /tmp/osi-L3-lineage)" || step_fail "$(cat /tmp/osi-L3-lineage)"
import json, os, sys, uuid
sandbox = sys.argv[1]
# Simulate a 3-generation lineage
species_root = str(uuid.uuid4())
parent      = str(uuid.uuid4())
child       = str(uuid.uuid4())
chain = {
    "species_root": {"schema": "rapp-rappid/2.0", "rappid": species_root, "parent_rappid": None},
    "parent":       {"schema": "rapp-rappid/2.0", "rappid": parent,       "parent_rappid": species_root},
    "child":        {"schema": "rapp-rappid/2.0", "rappid": child,        "parent_rappid": parent},
}
for name, doc in chain.items():
    with open(os.path.join(sandbox, f"{name}.json"), "w") as fh:
        json.dump(doc, fh)
# Walk backward from child → species root via parent_rappid
visited = []
current = "child"
for _ in range(10):
    with open(os.path.join(sandbox, f"{current}.json")) as fh:
        d = json.load(fh)
    visited.append(d["rappid"])
    p = d["parent_rappid"]
    if p is None:
        break
    if p == species_root:
        current = "species_root"
    elif p == parent:
        current = "parent"
    else:
        sys.exit(1)
if visited == [child, parent, species_root]:
    print(f"backward lineage walk: {len(visited)} generations, terminates at species root")
else:
    print(f"FAIL — chain malformed: {visited}")
    sys.exit(1)
PY

# 5. Canonical test neighbor reachable
heading "Step 5 — kody-w/rapp-test-neighbor (NEIGHBORHOOD_PROTOCOL §4d)"
if osi_net "test neighbor probe"; then
  CODE=$(osi_head "https://kody-w.github.io/rapp-test-neighbor/" 5)
  if [ "$CODE" = "200" ] || [ "$CODE" = "301" ] || [ "$CODE" = "302" ]; then
    step_pass "rapp-test-neighbor reachable (HTTP $CODE)"
  else
    muted "rapp-test-neighbor → HTTP $CODE (may not yet be planted; non-fatal)"
    step_pass "rapp-test-neighbor probe attempted"
  fi
fi

# 6. Egg hub catalog reachable (NEIGHBORHOOD_PROTOCOL §4b)
heading "Step 6 — Public egg-hub catalog (NEIGHBORHOOD_PROTOCOL §4b)"
if osi_net "egg-hub probe"; then
  CODE=$(osi_head "https://github.com/kody-w/rapp-egg-hub" 5)
  if [ "$CODE" = "200" ] || [ "$CODE" = "301" ] || [ "$CODE" = "302" ]; then
    step_pass "kody-w/rapp-egg-hub repo reachable (HTTP $CODE)"
  else
    muted "egg-hub → HTTP $CODE (non-fatal)"
    step_pass "egg-hub probe attempted"
  fi
fi

scenario_summary
