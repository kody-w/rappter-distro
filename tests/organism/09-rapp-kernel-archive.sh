#!/usr/bin/env bash
# rapp_kernel/ is the public source of truth for kernel DNA. The four
# files in rapp_kernel/latest/ must match rapp_brainstem/ byte-for-byte
# (drift detection). The pinned snapshot at rapp_kernel/v/<version>/
# must validate against its checksums.txt (tamper detection).
#
# Asserts:
#   - rapp_kernel/latest/* matches rapp_brainstem/* exactly
#   - rapp_kernel/manifest.json is well-formed JSON with the schema fields
#   - rapp_kernel/v/<latest>/checksums.txt validates against the on-disk files
#   - rapp_kernel/v/<latest>/VERSION matches manifest.latest
#
# Reference: Constitution Article XXXIII §1 (DNA), Article XXXIV (Lineage),
# pages/vault/Architecture/The Species DNA Archive.

set -euo pipefail
cd "$(dirname "$0")/../.."

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

ARCHIVE="rapp_kernel"
[ -d "$ARCHIVE" ] || { echo "FAIL: $ARCHIVE/ does not exist"; exit 1; }
[ -d "$ARCHIVE/latest" ] || { echo "FAIL: $ARCHIVE/latest/ missing"; exit 1; }
[ -f "$ARCHIVE/manifest.json" ] || { echo "FAIL: $ARCHIVE/manifest.json missing"; exit 1; }

# 1. Manifest is well-formed and names the four kernel files.
#    Schema 1.1 requires 'signing' block and per-version 'attestation' field
#    (both nullable until signing is adopted, but the keys must exist).
LATEST_VERSION="$("$PYTHON" -c "
import json
m = json.load(open('$ARCHIVE/manifest.json'))
assert m.get('schema', '').startswith('rapp-kernel/'), 'bad schema'
files = m.get('files', [])
expected = {'brainstem.py', 'basic_agent.py', 'context_memory_agent.py', 'manage_memory_agent.py'}
assert set(files) == expected, f'manifest files mismatch: {files}'
# Schema 1.1: signing block must exist (fields may be null)
signing = m.get('signing')
assert isinstance(signing, dict), 'manifest missing signing block'
for key in ('method', 'key_id', 'verification_uri'):
    assert key in signing, f'manifest.signing missing {key}'
# Schema 1.1: every version has an attestation field
for v in m['versions']:
    assert 'attestation' in v, f\"version {v.get('version')} missing attestation field\"
print(m['latest'])
")"
[ -n "$LATEST_VERSION" ] || { echo "FAIL: manifest.latest missing"; exit 1; }

# 1b. rappid.json (master) — schema 1.1 requires the attestation field.
"$PYTHON" -c "
import json
r = json.load(open('rappid.json'))
assert r.get('schema', '').startswith('rapp-rappid/'), 'bad rappid schema'
assert 'attestation' in r, 'master rappid.json missing attestation field'
" || {
    echo "FAIL: rappid.json schema 1.1 fields missing"
    exit 1
}

# 2. latest/ contents match rapp_brainstem/ counterparts byte-for-byte.
KERNEL_FILES=(brainstem.py)
AGENT_FILES=(basic_agent.py context_memory_agent.py manage_memory_agent.py)
for f in "${KERNEL_FILES[@]}"; do
    cmp -s "$ARCHIVE/latest/$f" "rapp_brainstem/$f" || {
        echo "FAIL: drift between $ARCHIVE/latest/$f and rapp_brainstem/$f"
        exit 1
    }
done
for f in "${AGENT_FILES[@]}"; do
    cmp -s "$ARCHIVE/latest/$f" "rapp_brainstem/agents/$f" || {
        echo "FAIL: drift between $ARCHIVE/latest/$f and rapp_brainstem/agents/$f"
        exit 1
    }
done

# 3. latest/VERSION matches manifest.latest
LATEST_VERSION_FILE="$(tr -d '[:space:]' < "$ARCHIVE/latest/VERSION")"
[ "$LATEST_VERSION_FILE" = "$LATEST_VERSION" ] || {
    echo "FAIL: $ARCHIVE/latest/VERSION ($LATEST_VERSION_FILE) != manifest.latest ($LATEST_VERSION)"
    exit 1
}

# 4. Pinned snapshot v/<latest>/ exists and validates against checksums.txt
PINNED_DIR="$ARCHIVE/v/$LATEST_VERSION"
[ -d "$PINNED_DIR" ] || { echo "FAIL: pinned snapshot $PINNED_DIR missing"; exit 1; }
[ -f "$PINNED_DIR/checksums.txt" ] || { echo "FAIL: $PINNED_DIR/checksums.txt missing"; exit 1; }

# Verify checksums (cd in for relative paths)
( cd "$PINNED_DIR" && shasum -a 256 -c checksums.txt >/dev/null 2>&1 ) || {
    echo "FAIL: checksums.txt validation failed for $PINNED_DIR"
    ( cd "$PINNED_DIR" && shasum -a 256 -c checksums.txt 2>&1 | grep FAILED )
    exit 1
}

# 5. Pinned snapshot files match latest/ (since this is the current version)
for f in "${KERNEL_FILES[@]}" "${AGENT_FILES[@]}"; do
    cmp -s "$ARCHIVE/latest/$f" "$PINNED_DIR/$f" || {
        echo "FAIL: $ARCHIVE/latest/$f != $PINNED_DIR/$f (current version's pinned snapshot diverged from latest)"
        exit 1
    }
done

echo "✓ rapp_kernel: latest matches rapp_brainstem; pinned v/$LATEST_VERSION validates against checksums"
