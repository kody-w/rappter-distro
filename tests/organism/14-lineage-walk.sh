#!/usr/bin/env bash
# Fixture: the lineage walker traces parent_rappid chains to the species root.
#
# Asserts:
#   - Walking the species root itself produces a chain of length 1, depth 0
#   - Walking against a synthetic vault with intermediate parent records works
#   - Walking detects cycles
#   - Walking rejects malformed parent_rappid
#   - Walking respects max_depth (cycle defense)
#
# Reference: Constitution Article XXXIV (rappid lineage), Article XXXVI (swarm estate)

set -euo pipefail
cd "$(dirname "$0")/../.."

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

# Build a synthetic vault that has Wildhaven + Molly records
# (we can't depend on the private wildhaven-ceo repo from a public test)
SYNTH_VAULT=$(mktemp -d)
trap "rm -rf $SYNTH_VAULT" EXIT

mkdir -p "$SYNTH_VAULT/blessings/144d673475618dfbc9710e999e7d2907"
mkdir -p "$SYNTH_VAULT/blessings/74f0dc145d9c86decd61fbad53c67f2e"

# Wildhaven root.json — minimal, parent_rappid points at species root
cat > "$SYNTH_VAULT/blessings/144d673475618dfbc9710e999e7d2907/root.json" <<EOF
{
  "alg": "ecdsa-p256",
  "schema": "swarm-estate-record/1.0",
  "kind": "root",
  "rappid": "rappid:v2:organism:@wildhaven/ai-homes:144d673475618dfbc9710e999e7d2907@github.com/kody-w/wildhaven-ceo",
  "issued_at": "2026-04-30T00:00:00Z",
  "issued_by": "fp:M:144d673475618dfbc9710e99",
  "issued_by_role": "M",
  "payload": {
    "parent_rappid": "rappid:v2:prototype:@rapp/origin:0b635450c04249fbb4b1bdb571044dec@github.com/kody-w/RAPP",
    "master_pubkey": "synthetic-test"
  },
  "signature": "synthetic-test"
}
EOF

# Molly root.json — parent_rappid points at Wildhaven
cat > "$SYNTH_VAULT/blessings/74f0dc145d9c86decd61fbad53c67f2e/root.json" <<EOF
{
  "alg": "ecdsa-p256",
  "schema": "swarm-estate-record/1.0",
  "kind": "root",
  "rappid": "rappid:v2:twin:@wildhaven/molly:74f0dc145d9c86decd61fbad53c67f2e@github.com/kody-w/wildhaven-ceo",
  "issued_at": "2026-04-30T00:00:00Z",
  "issued_by": "fp:M:74f0dc145d9c86decd61fbad",
  "issued_by_role": "M",
  "payload": {
    "parent_rappid": "rappid:v2:organism:@wildhaven/ai-homes:144d673475618dfbc9710e999e7d2907@github.com/kody-w/wildhaven-ceo",
    "master_pubkey": "synthetic-test"
  },
  "signature": "synthetic-test"
}
EOF

cd rapp_brainstem
"$PYTHON" - "$SYNTH_VAULT" <<'PYEOF'
import sys
sys.path.insert(0, '.')
from pathlib import Path
from utils.rappid import Rappid, species_root
from utils.lineage import walk_lineage

vault = Path(sys.argv[1])

# 1. Walk the species root itself: chain length 1, depth 0
chain = walk_lineage(species_root(), vault)
assert len(chain) == 1, f"species root chain should be length 1, got {len(chain)}"
assert chain.depth() == 0, f"species root depth should be 0, got {chain.depth()}"
assert chain.terminated_at_species_root

# 2. Walk Wildhaven: chain Wildhaven → species root, depth 1
wh = Rappid.parse("rappid:v2:organism:@wildhaven/ai-homes:144d673475618dfbc9710e999e7d2907@github.com/kody-w/wildhaven-ceo")
chain = walk_lineage(wh, vault)
assert len(chain) == 2
assert chain.depth() == 1
assert chain.terminated_at_species_root
assert chain.nodes[0].rappid == wh
assert chain.nodes[-1].rappid.is_species_root()

# 3. Walk Molly: chain Molly → Wildhaven → species root, depth 2
m = Rappid.parse("rappid:v2:twin:@wildhaven/molly:74f0dc145d9c86decd61fbad53c67f2e@github.com/kody-w/wildhaven-ceo")
chain = walk_lineage(m, vault)
assert len(chain) == 3, f"expected 3 nodes, got {len(chain)}"
assert chain.depth() == 2
assert chain.terminated_at_species_root

# 4. max_depth defense (cycle protection)
try:
    walk_lineage(m, vault, max_depth=1)
    assert False, "should have raised on max_depth=1"
except ValueError as e:
    assert "max_depth" in str(e), f"unexpected error: {e}"

# 5. Missing record: walk a rappid not in the vault
phantom = Rappid.parse("rappid:v2:organism:@phantom/missing:deadbeefdeadbeefdeadbeefdeadbeef@nowhere")
try:
    walk_lineage(phantom, vault)
    assert False, "should have raised on missing record"
except ValueError as e:
    assert "no record found" in str(e), f"unexpected error: {e}"

# 6. Cycle detection: build a synthetic vault with A → B → A
import tempfile
import shutil
from pathlib import Path as P
cycle_vault = P(tempfile.mkdtemp())
try:
    A_hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    B_hash = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    A_rappid = f"rappid:v2:organism:@test/a:{A_hash}@local"
    B_rappid = f"rappid:v2:organism:@test/b:{B_hash}@local"
    for h, parent in [(A_hash, B_rappid), (B_hash, A_rappid)]:
        d = cycle_vault / "blessings" / h
        d.mkdir(parents=True)
        (d / "root.json").write_text(f'{{"rappid":"rappid:v2:organism:@test/{("a" if h == A_hash else "b")}:{h}@local","payload":{{"parent_rappid":"{parent}"}},"signature":"x"}}')
    try:
        walk_lineage(Rappid.parse(A_rappid), cycle_vault)
        assert False, "cycle should have raised"
    except ValueError as e:
        assert "cyclic" in str(e), f"unexpected error: {e}"
finally:
    shutil.rmtree(cycle_vault)

print("PASS: 14-lineage-walk")
PYEOF
