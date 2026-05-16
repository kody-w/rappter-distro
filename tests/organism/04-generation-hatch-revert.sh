#!/usr/bin/env bash
# Fixture: the hatching cycle creates a generation tag (egg) before each
# upgrade; the tag survives subsequent mutations; reverting reproduces the
# original state.
#
# Asserts:
#   - hatchling tag-current creates generations/<rappid>/<n> tags
#   - clutch lists them in order
#   - reverting to gen N restores the working tree to gen N's state
#
# Reference: Constitution Article XXXIII §2 (the hatching cycle)

set -euo pipefail
cd "$(dirname "$0")/../.."

REPO_ROOT="$(pwd)"
HATCHLING="$REPO_ROOT/installer/hatchling"

TMP_HOME="$(mktemp -d /tmp/rapp-organism-04.XXXXXX)"
trap 'rm -rf "$TMP_HOME"' EXIT
export HOME="$TMP_HOME"

# Build a fixture organism with a small history
ORG="$TMP_HOME/org"
mkdir -p "$ORG"
git -C "$ORG" init -q
git -C "$ORG" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "initial"

cat > "$ORG/rappid.json" <<JSON
{"rappid": "test-variant-0000-0000-0000-000000000004", "parent_rappid": null, "role": "master"}
JSON
echo "soul-v1" > "$ORG/soul.md"
git -C "$ORG" add rappid.json soul.md
git -C "$ORG" -c user.email=t@t -c user.name=t commit -q -m "add rappid + soul"

cd "$ORG"

# Stamp the org rappid
"$HATCHLING" stamp >/dev/null
ORG_RAPPID="$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.brainstem/rappid.json')))['rappid'])")"

# 1. Tag generation 1 (the egg)
"$HATCHLING" tag-current -m "first egg" >/dev/null
git tag --list "generations/$ORG_RAPPID/1" | grep -q "generations/$ORG_RAPPID/1" || {
    echo "FAIL: generation 1 tag not created"
    exit 1
}

# 2. Mutate (simulate a kernel upgrade or local edit)
echo "soul-v2-mutated" > soul.md
git -c user.email=t@t -c user.name=t commit -q -am "mutate soul to v2"

# 3. Tag generation 2
"$HATCHLING" tag-current -m "post-mutation" >/dev/null
git tag --list "generations/$ORG_RAPPID/2" | grep -q "generations/$ORG_RAPPID/2" || {
    echo "FAIL: generation 2 tag not created"
    exit 1
}

# 4. Clutch lists both
CLUTCH="$("$HATCHLING" clutch)"
echo "$CLUTCH" | grep -q "gen   1" || { echo "FAIL: clutch missing gen 1"; echo "$CLUTCH"; exit 1; }
echo "$CLUTCH" | grep -q "gen   2" || { echo "FAIL: clutch missing gen 2"; echo "$CLUTCH"; exit 1; }

# 5. Revert to gen 1 — soul.md should be back to v1
"$HATCHLING" revert 1 >/dev/null 2>&1 || true
SOUL_AT_GEN1="$(cat soul.md)"
[ "$SOUL_AT_GEN1" = "soul-v1" ] || {
    echo "FAIL: revert did not restore soul-v1 (got: '$SOUL_AT_GEN1')"
    exit 1
}

# 6. Return to main and confirm gen 2 mutation is still present
git checkout -q main
SOUL_AT_HEAD="$(cat soul.md)"
[ "$SOUL_AT_HEAD" = "soul-v2-mutated" ] || {
    echo "FAIL: gen 2 mutation lost when returning to main (got: '$SOUL_AT_HEAD')"
    exit 1
}

echo "✓ generation cycle: egg/clutch/revert all work; mutations preserved across cycles"
