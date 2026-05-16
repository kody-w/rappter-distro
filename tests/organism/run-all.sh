#!/usr/bin/env bash
# Run every wild-encounter fixture in order. Exit non-zero if any fail.
set -uo pipefail
cd "$(dirname "$0")"

PASS=0
FAIL=0
# Match any leading-digit fixture (01-, 02-, ..., 10-, 11-, ...). Sort so
# numerical order is preserved across two-digit numbers.
for t in $(ls [0-9]*.sh 2>/dev/null | sort); do
    [ -f "$t" ] || continue
    echo "═══ $t"
    if bash "$t"; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        echo "✗ $t failed"
    fi
    echo
done

echo "─────────────────────"
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" = "0" ]
