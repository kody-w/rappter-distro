#!/usr/bin/env bash
# Fixture: the rappid library parses, round-trips, and rejects malformed input.
#
# Asserts:
#   - Rappid.parse() round-trips the species root constant
#   - Rappid.parse() rejects bare UUIDs (the legacy v1 format) with a clear error
#   - Rappid.parse() rejects malformed strings
#   - is_species_root() returns True for the godfather and False for descendants
#   - Wildhaven and Molly rappids parse successfully and have correct kinds
#
# Reference: Constitution Article XXXIV (rappid lineage), Article XXXVI (swarm estate),
#            pages/vault/Architecture/Rappid.md (canonical spec)

set -euo pipefail
cd "$(dirname "$0")/../.."

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

cd rapp_brainstem
"$PYTHON" - <<'PYEOF'
import sys
sys.path.insert(0, '.')
from utils.rappid import Rappid, SPECIES_ROOT, species_root, KNOWN_KINDS

# 1. Round-trip the species root
root = species_root()
assert root.to_string() == SPECIES_ROOT, f"species root round-trip mismatch"
assert root.is_species_root(), "species_root() should be species root"
assert root.kind == "prototype"
assert root.publisher == "rapp"
assert root.slug == "origin"
assert root.hash == "0b635450c04249fbb4b1bdb571044dec"

# 2. Wildhaven (real Foundation organism)
wh = Rappid.parse("rappid:v2:organism:@wildhaven/ai-homes:144d673475618dfbc9710e999e7d2907@github.com/kody-w/wildhaven-ceo")
assert wh.kind == "organism"
assert wh.publisher == "wildhaven"
assert wh.slug == "ai-homes"
assert not wh.is_species_root()
assert wh.is_known_kind()

# 3. Molly (real Foundation twin)
m = Rappid.parse("rappid:v2:twin:@wildhaven/molly:74f0dc145d9c86decd61fbad53c67f2e@github.com/kody-w/wildhaven-ceo")
assert m.kind == "twin"
assert m.publisher == "wildhaven"
assert m.slug == "molly"

# 4. Round-trip
for r in (root, wh, m):
    assert Rappid.parse(r.to_string()) == r, f"round-trip mismatch for {r.fingerprint}"

# 5. Reject bare UUID (the legacy format)
assert Rappid.try_parse("0b635450-c042-49fb-b4b1-bdb571044dec") is None, \
    "bare UUIDs must be rejected — they're not the unified format"

# 6. Reject malformed (note: any v\d+ is valid for forward-compat — only true syntax errors are rejected)
for bad in ("", "not-a-rappid", "rappid:v2:organism", "rappid:v2:organism:@wildhaven/ai-homes",
            "rappid:v2:organism:@wildhaven/ai-homes:abc", "rappid:v2:organism:@wildhaven/ai-homes:abc@",
            "rappid:notaversion:organism:@x/y:abc@host"):
    assert Rappid.try_parse(bad) is None, f"should have rejected: {bad!r}"

# Forward-compat: v3+ should be accepted (parsed as a future version) — not rejected at the regex layer
future = Rappid.try_parse("rappid:v9:organism:@x/y:abcdef0123456789@host")
assert future is not None, "future version (v9) must parse for forward compat"
assert future.version == "v9"

# 7. Equality
assert wh == Rappid.parse(wh.to_string())
assert wh != m
assert hash(wh) == hash(Rappid.parse(wh.to_string()))

# 8. same_estate_as
assert wh.same_estate_as(wh)
assert not wh.same_estate_as(m)
assert not wh.same_estate_as("not a rappid")  # type: ignore

# 9. Known kinds set is non-empty and contains all expected
expected_kinds = {"prototype", "kernel-variant", "organism", "twin", "swarm", "rapplication", "agent"}
assert expected_kinds <= KNOWN_KINDS, f"known kinds incomplete: {KNOWN_KINDS}"

print("PASS: 13-rappid-format")
PYEOF
