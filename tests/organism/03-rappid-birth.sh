#!/usr/bin/env bash
# Fixture: hatchling stamp creates a fresh organism rappid linked to the repo's
# variant rappid; running again is idempotent (rappid never regenerates).
#
# Asserts:
#   - first stamp writes ~/.brainstem/rappid.json with parent_rappid = repo rappid
#   - second stamp does NOT change the rappid (XXXIV §5: rappid never regenerates)
#   - status reflects parent ancestry correctly
#
# Reference: Constitution Article XXXIV §1, §5

set -euo pipefail
cd "$(dirname "$0")/../.."

REPO_ROOT="$(pwd)"
HATCHLING="$REPO_ROOT/installer/hatchling"

# Isolate: redirect HOME so we never touch the developer's real ~/.brainstem
TMP_HOME="$(mktemp -d /tmp/rapp-organism-03.XXXXXX)"
trap 'rm -rf "$TMP_HOME"' EXIT
export HOME="$TMP_HOME"

# Make a tiny fixture organism: a git working tree with a rappid.json
ORG="$TMP_HOME/org"
mkdir -p "$ORG"
git -C "$ORG" init -q
cat > "$ORG/rappid.json" <<JSON
{
  "rappid": "test-variant-aaaa-bbbb-cccc-000000000001",
  "parent_rappid": "0b635450-c042-49fb-b4b1-bdb571044dec",
  "name": "test-variant",
  "role": "variant"
}
JSON
git -C "$ORG" add rappid.json
git -C "$ORG" -c user.email=t@t -c user.name=t commit -q -m "init test variant"

cd "$ORG"

# 1. First stamp writes the org rappid
"$HATCHLING" stamp >/dev/null
[ -f "$HOME/.brainstem/rappid.json" ] || { echo "FAIL: rappid.json not written"; exit 1; }

FIRST_RAPPID="$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.brainstem/rappid.json')))['rappid'])")"
PARENT="$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.brainstem/rappid.json')))['parent_rappid'])")"

[ -n "$FIRST_RAPPID" ] || { echo "FAIL: rappid is empty"; exit 1; }
[ "$PARENT" = "test-variant-aaaa-bbbb-cccc-000000000001" ] || {
    echo "FAIL: parent_rappid='$PARENT' (expected the variant's rappid)"
    exit 1
}

# 2. Second stamp is idempotent
"$HATCHLING" stamp >/dev/null
SECOND_RAPPID="$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.brainstem/rappid.json')))['rappid'])")"
[ "$FIRST_RAPPID" = "$SECOND_RAPPID" ] || {
    echo "FAIL: rappid regenerated on second stamp (was $FIRST_RAPPID, now $SECOND_RAPPID)"
    exit 1
}

# 3. Status output references both rappids correctly
STATUS="$("$HATCHLING" status)"
echo "$STATUS" | grep -q "$FIRST_RAPPID" || { echo "FAIL: status missing org rappid"; exit 1; }
echo "$STATUS" | grep -q "test-variant-aaaa-bbbb-cccc-000000000001" || { echo "FAIL: status missing variant rappid"; exit 1; }

echo "✓ rappid birth: stamp is idempotent, parent ancestry correct"
