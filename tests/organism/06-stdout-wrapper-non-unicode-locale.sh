#!/usr/bin/env bash
# The kernel's stdout/stderr UTF-8 wrapper must engage on any non-Unicode
# terminal encoding — not just cp* (Windows codepages) but also gbk,
# shift_jis, euc-kr, ascii, etc. Without it, the startup banner's emoji
# (🧠) crashes on the print() with UnicodeEncodeError.
#
# Asserts:
#   - kernel boots under LC_ALL=C PYTHONUTF8=0 (forces ASCII encoding)
#   - /health responds within the boot window
#   - the startup banner's emoji is not what kills the process
#
# Reference: extends 95be0bc (cp-only wrapper) to all non-Unicode encodings.

set -euo pipefail
cd "$(dirname "$0")/../.."

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

LOG="/tmp/rapp-organism-06.log"
PID_FILE="/tmp/rapp-organism-06.pid"

PORT=""
for p in 7095 7096 7097 7098 7099; do
    if ! lsof -i ":$p" -sTCP:LISTEN >/dev/null 2>&1; then
        PORT="$p"; break
    fi
done
[ -n "$PORT" ] || { echo "FAIL: no free port in 7095-7099"; exit 1; }

cleanup() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
}
trap cleanup EXIT

echo "▶ booting canonical kernel under LC_ALL=C PYTHONUTF8=0 on :$PORT (forces ASCII stdout)"
( cd rapp_brainstem && \
    exec env LC_ALL=C LANG=C PYTHONUTF8=0 PORT="$PORT" "$PYTHON" brainstem.py ) > "$LOG" 2>&1 &
echo $! > "$PID_FILE"

for i in $(seq 1 30); do
    if curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1; then break; fi
    sleep 0.5
    if [ "$i" = "30" ]; then
        echo "FAIL: kernel did not boot under ASCII locale in 15s"
        echo "--- log tail ---"
        tail -30 "$LOG"
        exit 1
    fi
done

# Verify the kernel actually printed its startup banner — the emoji line
# is the proof point (without the broadened wrapper, this would crash).
grep -q "RAPP Brainstem v" "$LOG" || {
    echo "FAIL: startup banner missing from log"
    tail -30 "$LOG"
    exit 1
}

# /health must answer
HEALTH="$(curl -s "http://localhost:$PORT/health")"
echo "$HEALTH" | grep -qE '"status":"(ok|unauthenticated)"' || {
    echo "FAIL: /health did not return status:ok|unauthenticated"
    echo "  body: $HEALTH"
    exit 1
}

echo "✓ stdout wrapper engages on non-Unicode encodings; banner survives ASCII locale"
