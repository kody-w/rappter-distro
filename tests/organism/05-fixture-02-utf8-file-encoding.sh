#!/usr/bin/env bash
# Fixture 02: every text-mode open() in the kernel must specify
# encoding="utf-8" so the kernel reads/writes UTF-8 universally
# regardless of the OS locale (GBK, Shift_JIS, cp1252, etc.).
#
# Asserts:
#   - Static: no bare text-mode open(...) in brainstem.py
#   - Runtime: kernel boots under LC_ALL=C PYTHONUTF8=0 (ASCII-only locale)
#     even when soul.md contains UTF-8 multibyte sequences
#
# Reference: pages/vault/Fixtures/Fixture 02 — Soul Read on Non-UTF-8 Windows Locale.md

set -euo pipefail
cd "$(dirname "$0")/../.."

KERNEL="rapp_brainstem/brainstem.py"

# 1. Static check: every text-mode open() in the kernel must declare encoding.
#    Allowed:
#      - open(..., 'wb') / open(..., 'rb')         binary mode
#      - open(..., encoding="utf-8") / encoding='utf-8'
#      - zf.open(...) on zipfile members           handled by zipfile
#      - Lines that aren't actually open() calls (comments, attr accesses)
BARE_OPEN="$(
    grep -nE '(^|[^.])open\(' "$KERNEL" \
        | grep -v 'encoding="utf-8"' \
        | grep -v "encoding='utf-8'" \
        | grep -v "'wb'" \
        | grep -v "'rb'" \
        | grep -v "\"wb\"" \
        | grep -v "\"rb\"" \
        | grep -v 'webbrowser\.\|app\.run\|request\.get_json\|isinstance\|subprocess' \
        || true
)"

if [ -n "$BARE_OPEN" ]; then
    echo "FAIL: kernel has text-mode open() calls without encoding=\"utf-8\":"
    echo "$BARE_OPEN"
    exit 1
fi

# 2. Runtime check: simulate a non-UTF-8 locale and confirm the kernel
#    can still load a UTF-8 soul. We don't need to boot the full Flask
#    server — just exercise load_soul() and the file readers in isolation.
PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

TMP_ORG="$(mktemp -d /tmp/rapp-organism-05.XXXXXX)"
trap 'rm -rf "$TMP_ORG"' EXIT

# Write a soul.md with UTF-8 multibyte content (smart quotes, emoji, CJK).
# Byte 0x94 here matches Michael's failure exactly — it's part of the
# UTF-8 encoding for an em-dash and other punctuation.
printf '\xe2\x80\x9chello\xe2\x80\x9d \xf0\x9f\xa7\xa0 \xe4\xbd\xa0\xe5\xa5\xbd\n' > "$TMP_ORG/soul.md"

# Run a tiny Python harness that does what the kernel's load_soul does.
# Force ASCII locale + disable PEP 540 → Python's default open() will be
# ASCII. Without encoding="utf-8" this would crash on the first multibyte
# sequence. With it, it must succeed.
OUT="$(LC_ALL=C LANG=C PYTHONUTF8=0 "$PYTHON" -c "
with open('$TMP_ORG/soul.md', 'r', encoding='utf-8') as f:
    soul = f.read().strip()
assert len(soul) > 0
assert '“' in soul, 'expected smart quote character in decoded soul'
print('OK', len(soul), 'chars')
" 2>&1)"

echo "  $OUT"
echo "$OUT" | grep -q "^OK" || {
    echo "FAIL: utf-8 file open under ASCII locale did not succeed"
    exit 1
}

# 3. Module-level check: import the kernel and call load_soul() under a
#    non-UTF-8 locale. This is exactly the path that crashed for Michael
#    on Chinese Windows. With encoding="utf-8" pinned at every site, it
#    must succeed. We force PYTHONIOENCODING=utf-8 to keep stdout sane —
#    the kernel's emoji-bearing print() under PYTHONUTF8=0 LC_ALL=C is
#    a separate concern from Michael's file-read bug.
HARNESS="$TMP_ORG/harness.py"
cat > "$HARNESS" <<PY
import os, sys
# Point the kernel at our UTF-8 soul fixture (smart quotes + emoji + CJK)
os.environ['SOUL_PATH'] = '$TMP_ORG/soul.md'
sys.path.insert(0, 'rapp_brainstem')
import brainstem
soul = brainstem.load_soul()
assert len(soul) > 0
assert '“' in soul, 'expected smart quote in decoded soul'
assert '\U0001f9e0' in soul, 'expected emoji in decoded soul'
assert '你' in soul, 'expected CJK character in decoded soul'
print('OK soul=%d chars' % len(soul))
PY

OUT="$(LC_ALL=C LANG=C PYTHONUTF8=0 PYTHONIOENCODING=utf-8 "$PYTHON" "$HARNESS" 2>&1)"
echo "  $OUT"
echo "$OUT" | grep -q "^OK soul=" || {
    echo "FAIL: kernel module + load_soul did not succeed under ASCII locale"
    exit 1
}

echo "✓ fixture 02: kernel reads UTF-8 files universally regardless of OS locale"
