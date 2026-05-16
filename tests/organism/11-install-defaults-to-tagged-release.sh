#!/usr/bin/env bash
# install.sh must default to the latest brainstem-v* tagged release, not
# main HEAD. Pinning via BRAINSTEM_VERSION=X.Y.Z still works; opting back
# into main HEAD requires explicit RAPP_INSTALL_TRACK=main.
#
# Asserts:
#   - install.sh references RAPP_INSTALL_TRACK env var
#   - the resolver uses `git ls-remote --tags ... brainstem-v*` to find latest
#   - main HEAD is no longer the silent default (must be opt-in)
#
# Reference: review item #7 — install one-liner pulls main HEAD by default.

set -euo pipefail
cd "$(dirname "$0")/../.."

INSTALL="installer/install.sh"

# 1. New env var is documented + parsed
grep -q "RAPP_INSTALL_TRACK" "$INSTALL" || {
    echo "FAIL: install.sh has no RAPP_INSTALL_TRACK handling"
    exit 1
}

# 2. Latest-tag resolver pattern is present
grep -qE "git ls-remote.*--tags.*brainstem-v\\*" "$INSTALL" || {
    echo "FAIL: install.sh does not resolve latest brainstem-v* tag from remote"
    exit 1
}

# 3. The default branch is "release" (latest tag), not "main"
grep -qE 'INSTALL_TRACK="\$\{RAPP_INSTALL_TRACK:-release\}"' "$INSTALL" || {
    echo "FAIL: install.sh default track is not 'release'"
    exit 1
}

# 4. main is reachable via opt-in
grep -qE 'INSTALL_TRACK.*!=.*"main"' "$INSTALL" || {
    echo "FAIL: install.sh has no main-HEAD opt-in path"
    exit 1
}

# 5. Behavioral check: the shell sort -V logic must pick the correct
#    latest tag from a mixed list. Reproduce the awk + sort -V pipe and
#    verify on a known input.
TAG_INPUT="$(printf '%s\n' \
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/brainstem-v0.4.0' \
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/tags/brainstem-v0.5.1' \
    'cccccccccccccccccccccccccccccccccccccccc\trefs/tags/brainstem-v0.10.0' \
    'dddddddddddddddddddddddddddddddddddddddd\trefs/tags/brainstem-v0.12.2' \
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\trefs/tags/brainstem-v0.9.99' \
)"

LATEST="$(echo "$TAG_INPUT" | awk -F/ '{print $NF}' | sort -V | tail -n1)"
[ "$LATEST" = "brainstem-v0.12.2" ] || {
    echo "FAIL: shell tag-sort picks wrong latest (got '$LATEST', want brainstem-v0.12.2)"
    exit 1
}
echo "  shell sort -V picks $LATEST from mixed input"

echo "✓ install.sh defaults to latest tagged release; main HEAD is opt-in via RAPP_INSTALL_TRACK=main"
