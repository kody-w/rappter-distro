#!/usr/bin/env bash
# State (memories, copilot session, voice config, flight log) must travel
# with each generation tag. `hatchling hatch` and `hatchling tag-current`
# capture state into ~/.brainstem/generations/<rappid>/<n>/state.tar.gz;
# `hatchling reset N --yes` restores it.
#
# Asserts:
#   - Tagging a generation snapshots gitignored state paths
#   - reset N --yes restores BOTH code (git reset) and state (tar restore)
#   - revert N (read-only) leaves state untouched
#   - HATCHLING_STATE_PATHS env override works for non-default layouts
#
# Reference: Constitution Article XXXIII §2 (hatching cycle), the "state
# in the lineage" review item — without snapshot+restore, reverting to a
# generation silently lies because memories from later generations stick
# around.

set -euo pipefail
cd "$(dirname "$0")/../.."

REPO_ROOT="$(pwd)"
HATCHLING="$REPO_ROOT/installer/hatchling"

TMP_HOME="$(mktemp -d /tmp/rapp-organism-10.XXXXXX)"
trap 'rm -rf "$TMP_HOME"' EXIT
export HOME="$TMP_HOME"

# Build a fixture organism that mimics the rapp_brainstem layout
ORG="$TMP_HOME/org"
mkdir -p "$ORG/rapp_brainstem/.brainstem_data"
git -C "$ORG" init -q
git -C "$ORG" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "initial"

cat > "$ORG/rappid.json" <<JSON
{"rappid": "test-state-aaaa-bbbb-cccc-000000000010", "parent_rappid": null, "role": "master"}
JSON
echo "soul-v1" > "$ORG/rapp_brainstem/soul.md"
git -C "$ORG" add rappid.json rapp_brainstem/soul.md
git -C "$ORG" -c user.email=t@t -c user.name=t commit -q -m "add rappid + soul"

cd "$ORG"

# Stamp + first generation with state-A
"$HATCHLING" stamp >/dev/null
RAPPID="$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.brainstem/rappid.json')))['rappid'])")"

# Populate state-A
echo '{"memory":"alpha"}' > rapp_brainstem/.brainstem_data/notes.json
echo '{"access_token":"tok-A"}' > rapp_brainstem/.copilot_token

OUT="$("$HATCHLING" tag-current -m "gen 1 with state-A" 2>&1)"
echo "  tag-1: $OUT"
echo "$OUT" | grep -q "state captured at" || {
    echo "FAIL: tag-current did not capture state"
    exit 1
}

SNAP1="$HOME/.brainstem/generations/$RAPPID/1/state.tar.gz"
[ -f "$SNAP1" ] || { echo "FAIL: snapshot missing at $SNAP1"; exit 1; }

# Mutate to state-B
echo '{"memory":"beta-NEW"}' > rapp_brainstem/.brainstem_data/notes.json
echo '{"access_token":"tok-B"}' > rapp_brainstem/.copilot_token
echo "soul-v2" > rapp_brainstem/soul.md
git -c user.email=t@t -c user.name=t commit -q -am "mutate code to v2"

# Tag generation 2 with state-B
"$HATCHLING" tag-current -m "gen 2 with state-B" >/dev/null
SNAP2="$HOME/.brainstem/generations/$RAPPID/2/state.tar.gz"
[ -f "$SNAP2" ] || { echo "FAIL: gen 2 snapshot missing"; exit 1; }

# revert (read-only) to gen 1 — state should NOT change
"$HATCHLING" revert 1 >/dev/null 2>&1 || true
NOTES_AFTER_REVERT="$(cat rapp_brainstem/.brainstem_data/notes.json)"
[ "$NOTES_AFTER_REVERT" = '{"memory":"beta-NEW"}' ] || {
    echo "FAIL: revert (read-only) modified state — expected current state preserved, got: $NOTES_AFTER_REVERT"
    exit 1
}

# Return to main and confirm code state-B
git checkout -q main
[ "$(cat rapp_brainstem/soul.md)" = "soul-v2" ] || {
    echo "FAIL: returning to main did not restore soul-v2"
    exit 1
}

# Now do a full reset to gen 1 — state-A must come back
"$HATCHLING" reset 1 --yes >/dev/null 2>&1
NOTES_AFTER_RESET="$(cat rapp_brainstem/.brainstem_data/notes.json)"
TOKEN_AFTER_RESET="$(cat rapp_brainstem/.copilot_token)"
SOUL_AFTER_RESET="$(cat rapp_brainstem/soul.md)"

[ "$NOTES_AFTER_RESET" = '{"memory":"alpha"}' ] || {
    echo "FAIL: reset did not restore state-A memory (got: $NOTES_AFTER_RESET)"
    exit 1
}
[ "$TOKEN_AFTER_RESET" = '{"access_token":"tok-A"}' ] || {
    echo "FAIL: reset did not restore state-A copilot token"
    exit 1
}
[ "$SOUL_AFTER_RESET" = "soul-v1" ] || {
    echo "FAIL: reset did not restore code to soul-v1"
    exit 1
}

# Verify command runs cleanly
VERIFY_OUT="$("$HATCHLING" verify 2>&1)"
echo "$VERIFY_OUT" | grep -q "verify: ok" || {
    echo "FAIL: hatchling verify did not return ok"
    echo "$VERIFY_OUT"
    exit 1
}
echo "$VERIFY_OUT" | grep -q "stateful" || {
    echo "FAIL: verify output did not flag stateful generations"
    echo "$VERIFY_OUT"
    exit 1
}

# HATCHLING_STATE_PATHS override
export HATCHLING_STATE_PATHS="rapp_brainstem/.brainstem_data"
mkdir -p rapp_brainstem/.brainstem_data
echo '{"x":"y"}' > rapp_brainstem/.brainstem_data/just_this.json
"$HATCHLING" tag-current -m "gen 3 with custom state paths" >/dev/null
SNAP3="$HOME/.brainstem/generations/$RAPPID/3/state.tar.gz"
[ -f "$SNAP3" ] || { echo "FAIL: gen 3 snapshot missing under env override"; exit 1; }
# the snapshot should ONLY contain .brainstem_data, not .copilot_token
tar -tzf "$SNAP3" | grep -q ".copilot_token" && {
    echo "FAIL: env override leaked .copilot_token into snapshot"
    exit 1
}
tar -tzf "$SNAP3" | grep -q ".brainstem_data" || {
    echo "FAIL: env override snapshot missing .brainstem_data"
    exit 1
}
unset HATCHLING_STATE_PATHS

echo "✓ generation state: hatch tags snapshot state; reset restores it; revert preserves current state"
