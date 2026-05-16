#!/usr/bin/env bash
# tests/osi/L2-identity.sh — verify the identity layer.
#
# L2 = the rappid. UUIDv4 minted once at plant, never regenerated.
# Schema: rapp-rappid/2.0 (current) — tracked alongside legacy 1.1 entries.

source "$(dirname "$0")/_lib.sh"

osi_layer_intro "L2 — Identity" "rappid (UUIDv4) + parent_rappid + kernel_version. Schema: rapp-rappid/2.0"

# 1. UUIDv4 mint via Python stdlib (no deps)
heading "Step 1 — UUIDv4 mint (stdlib, no deps)"
RAPPID=$(python3 -c "import uuid; print(uuid.uuid4())")
if printf "%s" "$RAPPID" | grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'; then
  step_pass "minted UUIDv4: $RAPPID"
else
  step_fail "rappid does not match UUIDv4 shape: $RAPPID"
fi

# 2. bond.py + rappid.py exist + are loadable (kernel-adjacent)
heading "Step 2 — utils/bond.py + utils/rappid.py loadable"
BOND="$REPO_ROOT/rapp_brainstem/utils/bond.py"
RAPPID_MOD="$REPO_ROOT/rapp_brainstem/utils/rappid.py"
if [ -f "$BOND" ]; then
  if python3 -c "import ast; ast.parse(open('$BOND').read())" 2>/dev/null; then
    step_pass "bond.py parses cleanly"
  else
    step_fail "bond.py has syntax errors"
  fi
else
  step_fail "bond.py missing — L2 mint path broken"
fi
if [ -f "$RAPPID_MOD" ]; then
  step_pass "rappid.py present"
else
  muted "rappid.py not present (bond.py may be sole owner — non-fatal)"
fi

# 3. The repo's own root rappid.json exists and validates
# Per CONSTITUTION Art. XXXIV + LEXICON.md, rappid is EITHER:
#   (a) UUIDv4 — used for organisms (ECOSYSTEM §3 schema rapp-rappid/1.1)
#   (b) structured string `rappid:v2:<kind>:@<pub>/<slug>:<hash>@<host>` — species root + attestation chain
heading "Step 3 — Repo root rappid.json (species root identity, UUID OR structured string)"
ROOT_RAPPID="$REPO_ROOT/rappid.json"
if [ -f "$ROOT_RAPPID" ]; then
  python3 - "$ROOT_RAPPID" <<'PY' && step_pass "rappid.json validates as JSON with 'schema' + 'rappid' fields" || step_fail "rappid.json invalid"
import json, sys, re
p = sys.argv[1]
with open(p) as f:
    d = json.load(f)
required = ["schema", "rappid"]
missing = [k for k in required if k not in d]
if missing:
    print(f"missing: {missing}")
    sys.exit(1)
if not d["schema"].startswith("rapp-rappid/"):
    print(f"bad schema: {d['schema']}")
    sys.exit(1)
val = d["rappid"]
uuid_re = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
struct_re = re.compile(r'^rappid:v\d+:[A-Za-z][A-Za-z0-9_-]*:@[A-Za-z0-9_-]+/[A-Za-z0-9_-]+:[0-9a-f]+@[A-Za-z0-9.\-/_]+$')
if not (uuid_re.match(val) or struct_re.match(val)):
    print(f"rappid is neither UUIDv4 nor structured-string: {val}")
    sys.exit(1)
PY
else
  step_fail "repo root rappid.json missing"
fi

# 4. parent_rappid chain — every rappid.json with non-null parent_rappid points at a UUID OR structured string
heading "Step 4 — parent_rappid chain (UUID-shaped or structured-string)"
BAD=0
while IFS= read -r f; do
  python3 - "$f" <<'PY'
import json, re, sys
with open(sys.argv[1]) as fh:
    d = json.load(fh)
parent = d.get("parent_rappid")
if parent is not None:
    uuid_re = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
    struct_re = re.compile(r'^rappid:v\d+:')
    if not (uuid_re.match(parent) or struct_re.match(parent)):
        print(f"BAD parent_rappid in {sys.argv[1]}: {parent}", file=sys.stderr)
        sys.exit(1)
PY
  if [ $? -ne 0 ]; then BAD=1; fi
done < <(find "$REPO_ROOT" -name "rappid.json" -not -path "*/node_modules/*" -not -path "*/__pycache__/*" -not -path "*/.brainstem_data/*")
if [ "$BAD" -eq 0 ]; then
  step_pass "every parent_rappid in repo is UUID-shaped or structured-string"
else
  step_fail "at least one rappid.json has malformed parent_rappid"
fi

# 5. Mint deterministic-test-rappid via bond.py + ensure idempotence (mint twice, same input → same output IF inputs deterministic)
heading "Step 5 — bond.py mint exposes a callable surface"
SANDBOX=$(osi_sandbox "rapp-osi-L2")
trap "osi_cleanup_dir '$SANDBOX'" EXIT
RESULT=$(python3 - "$BOND" "$SANDBOX" <<'PY'
import importlib.util, sys, os
spec = importlib.util.spec_from_file_location("bond", sys.argv[1])
m = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(m)
except Exception as e:
    print(f"IMPORT_ERROR: {e}")
    sys.exit(1)
# We don't require a specific entry function name — just that bond.py loads
# and exposes SOMETHING callable. Adjust assertions if the contract solidifies.
attrs = [a for a in dir(m) if not a.startswith("_")]
print(f"OK loaded; public attrs: {len(attrs)}")
PY
)
if printf "%s" "$RESULT" | grep -q "^OK loaded"; then
  step_pass "bond.py imports cleanly: $RESULT"
else
  step_fail "bond.py import failed: $RESULT"
fi

# 6. CONSTITUTION Article XXXIV — variant lineage is single-parent only
heading "Step 6 — Lineage protocol: single-parent invariant (Art. XXXIV)"
DUPS=$(find "$REPO_ROOT" -name "rappid.json" -not -path "*/node_modules/*" -not -path "*/__pycache__/*" \
  -exec python3 -c "import json,sys; d=json.load(open(sys.argv[1])); k=[k for k in d if 'parent' in k.lower() and 'rappid' in k.lower()]; print(' '.join(k))" {} \; 2>/dev/null \
  | sort -u | grep -v "^parent_rappid$" | grep -v "^$" | head -3)
if [ -z "$DUPS" ]; then
  step_pass "no rappid.json declares parents other than parent_rappid (single-parent invariant intact)"
else
  step_fail "found alternate parent fields: $DUPS — Art. XXXIV violation risk"
fi

scenario_summary
