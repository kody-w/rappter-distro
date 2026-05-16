#!/usr/bin/env bash
# The boot sidecar must wire organ dispatch and /web mount onto the
# canonical kernel without modifying brainstem.py. End-to-end: fresh
# boot via utils/boot.py → /api/<name>/<path> answers, /web/<file>
# serves static, /health still ok, /chat still answers as the kernel
# would.
#
# Asserts:
#   - boot sidecar runs the canonical kernel (kernel /health responds)
#   - organ dispatcher is wired (/api/neighborhood/peers → 200)
#   - /web mount is wired (/web/neighborhood.html → 200)
#   - the kernel itself was NOT modified by this addition
#
# Reference: Constitution Article XXXIII §4 — additive integrations only.

set -euo pipefail
cd "$(dirname "$0")/../.."

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

LOG="/tmp/rapp-organism-07.log"
PID_FILE="/tmp/rapp-organism-07.pid"

PORT=""
for p in 7110 7111 7112 7113 7114; do
    if ! lsof -i ":$p" -sTCP:LISTEN >/dev/null 2>&1; then
        PORT="$p"; break
    fi
done
[ -n "$PORT" ] || { echo "FAIL: no free port in 7110-7114"; exit 1; }

cleanup() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
}
trap cleanup EXIT

# 1. The kernel itself must NOT have been edited to add organ or /web
#    dispatch — that's the additive-only rule.
grep -E "^def load_services|^def load_body_functions|^def load_organs|service_dispatch|organ_dispatch|api/<svc>" rapp_brainstem/brainstem.py && {
    echo "FAIL: kernel has organ/body_function/service dispatch baked in — that violates Article XXXIII §4"
    exit 1
}

# 2. Boot via the sidecar
BOOT_PATH=""
if [ -f rapp_brainstem/utils/boot.py ]; then
    BOOT_PATH="utils/boot.py"
elif [ -f rapp_brainstem/boot.py ]; then
    BOOT_PATH="boot.py"  # legacy layout
else
    echo "FAIL: no boot sidecar found"; exit 1
fi
echo "▶ booting via $BOOT_PATH on :$PORT"
( cd rapp_brainstem && exec env PORT="$PORT" "$PYTHON" "$BOOT_PATH" ) > "$LOG" 2>&1 &
echo $! > "$PID_FILE"

for i in $(seq 1 30); do
    if curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1; then break; fi
    sleep 0.5
    if [ "$i" = "30" ]; then
        echo "FAIL: kernel did not boot via $BOOT_PATH in 15s"
        echo "--- log tail ---"
        tail -40 "$LOG"
        exit 1
    fi
done

# 3. /health is the canonical kernel surface — must still answer
HEALTH="$(curl -s "http://localhost:$PORT/health")"
echo "$HEALTH" | grep -qE '"status":"(ok|unauthenticated)"' || {
    echo "FAIL: /health did not return status:ok|unauthenticated"
    exit 1
}

# 4. organ dispatch must be wired (neighborhood is shipped)
NEIGHBOR_STATUS="$(curl -s -o /tmp/rapp-organism-07.neighbor.json -w "%{http_code}" "http://localhost:$PORT/api/neighborhood/peers")"
if [ "$NEIGHBOR_STATUS" != "200" ]; then
    echo "FAIL: /api/neighborhood/peers returned $NEIGHBOR_STATUS (expected 200)"
    cat /tmp/rapp-organism-07.neighbor.json | head -c 400
    exit 1
fi
grep -q "peers" /tmp/rapp-organism-07.neighbor.json || {
    echo "FAIL: /api/neighborhood/peers response did not contain 'peers' key"
    cat /tmp/rapp-organism-07.neighbor.json | head -c 400
    exit 1
}

# 5. /web mount must serve static (neighborhood.html ships with the organ)
WEB_STATUS="$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/web/neighborhood.html")"
if [ "$WEB_STATUS" != "200" ]; then
    echo "FAIL: /web/neighborhood.html returned $WEB_STATUS (expected 200)"
    exit 1
fi

# 6. /web path traversal must be blocked
TRAV_STATUS="$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/web/../brainstem.py")"
if [ "$TRAV_STATUS" = "200" ]; then
    echo "FAIL: /web mount allowed path traversal — /web/../brainstem.py returned 200"
    exit 1
fi

echo "✓ boot sidecar wires organs + /web onto unmodified kernel"
