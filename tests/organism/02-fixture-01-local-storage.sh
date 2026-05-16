#!/usr/bin/env bash
# Fixture #1: the kernel's storage shim must resolve cleanly. The
# canonical layout has the implementation at utils/local_storage.py
# and the kernel imports it directly (with a fallback to a legacy
# root sibling for older organism layouts).
#
# Asserts:
#   - rapp_brainstem/utils/local_storage.py is the implementation
#   - the kernel resolves the import without any sys.path manipulation
#     of its own (the brainstem dir is on sys.path because it IS cwd
#     when the kernel runs)
#   - the resolved class lives under utils.local_storage
#
# Reference: pages/vault/Fixtures/Fixture 01 — Canonical Kernel local_storage Drop-In.md

set -euo pipefail
cd "$(dirname "$0")/../.."

IMPL="rapp_brainstem/utils/local_storage.py"
LEGACY_SHIM="rapp_brainstem/local_storage.py"

# 1. The implementation must live in utils/.
[ -f "$IMPL" ] || { echo "FAIL: $IMPL missing"; exit 1; }

# 2. The kernel must not introduce its own sys.path.insert for utils
#    around the local_storage import — the brainstem dir is already on
#    sys.path because it's the kernel's own directory.
grep -E "sys\.path\.insert.*utils_dir" rapp_brainstem/brainstem.py && {
    echo "FAIL: kernel was edited to add sys.path.insert — that defeats the additive discipline"
    exit 1
}

# 3. With brainstem_dir on sys.path, the kernel's import shape must resolve.
PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

OUT="$("$PYTHON" -c "
import sys
sys.path.insert(0, 'rapp_brainstem')
try:
    from utils.local_storage import AzureFileStorageManager
    print('OK', AzureFileStorageManager.__module__)
except ImportError:
    # Legacy organism layout: root sibling shim.
    from local_storage import AzureFileStorageManager  # type: ignore
    print('OK', AzureFileStorageManager.__module__)
" 2>&1)"

echo "  $OUT"
echo "$OUT" | grep -qE "^OK (utils\.local_storage|local_storage)$" || {
    echo "FAIL: kernel storage import did not resolve to utils.local_storage or local_storage"
    exit 1
}

# 4. If the legacy root shim exists in this organism (older layout),
#    it must not reach into the mutation surface beyond utils.local_storage.
if [ -f "$LEGACY_SHIM" ]; then
    grep -qE "from (agents|utils\.body_functions|utils\.services|utils\.organs)" "$LEGACY_SHIM" && {
        echo "FAIL: legacy shim imports from mutation surface"
        exit 1
    }
fi

echo "✓ fixture 01: kernel storage shim resolves cleanly via utils/local_storage.py"
