#!/usr/bin/env bash
# Fixture: vault notes referenced from CONSTITUTION.md exist in pages/vault/
# and key vault notes (Rappid, The Swarm Estate, Local-First-by-Design,
# Decentralized-by-Design) are present at expected paths.
#
# Asserts:
#   - All four canonical vault notes exist
#   - rappid.json at repo root parses as valid JSON and declares schema 2.0
#   - rappid.json's rappid field parses as a valid v2-format string
#   - The species root constant in utils/rappid.py matches rappid.json
#
# Reference: pages/vault/Architecture/Rappid.md (canonical spec)

set -euo pipefail
cd "$(dirname "$0")/../.."

# 1. Vault notes exist
for note in \
  "pages/vault/Architecture/Rappid.md" \
  "pages/vault/Architecture/The Swarm Estate.md" \
  "pages/vault/Architecture/Local-First-by-Design.md" \
  "pages/vault/Architecture/Decentralized-by-Design.md" \
  "pages/vault/Architecture/The Species DNA Archive — rapp_kernel.md" \
  "pages/vault/Architecture/Signed Releases and Variant Attestation.md"
do
  [ -f "$note" ] || { echo "FAIL: missing vault note: $note"; exit 1; }
done

# 2. rappid.json is valid + schema 2.0
[ -f "rappid.json" ] || { echo "FAIL: missing rappid.json"; exit 1; }
SCHEMA=$(python3 -c "import json; print(json.load(open('rappid.json'))['schema'])")
[ "$SCHEMA" = "rapp-rappid/2.0" ] || { echo "FAIL: rappid.json schema is $SCHEMA, expected rapp-rappid/2.0"; exit 1; }

# 3. rappid.json's rappid string parses as a valid v2 rappid that's the species root
PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

cd rapp_brainstem
"$PYTHON" - <<'PYEOF'
import sys, json
sys.path.insert(0, '.')
from utils.rappid import Rappid, SPECIES_ROOT, species_root

with open("../rappid.json") as f:
    rj = json.load(f)
declared = rj["rappid"]
parsed = Rappid.parse(declared)

# (a) parses as valid v2
assert parsed.version == "v2"
assert parsed.kind == "prototype"
assert parsed.publisher == "rapp"
assert parsed.slug == "origin"

# (b) matches the constant in utils/rappid.py
assert declared == SPECIES_ROOT, f"rappid.json declares {declared} but utils/rappid.py SPECIES_ROOT is {SPECIES_ROOT}"

# (c) species_root() function returns the same
assert species_root().to_string() == declared

# (d) parent_rappid is null (species root has no parent)
assert rj["parent_rappid"] is None

print("PASS: 20-rappid-spec-fixtures")
PYEOF
