#!/bin/bash
# start-local.sh — RAPP local-first launcher.
#
# Boots the full local-first stack on this machine:
#   • Static file server on :8000  (serves the mobile PWA + onboard page)
#   • Optional: swarm server on :7080 (run with --swarm)
#
# For OS-access (tether) endpoints, run the brainstem separately — it serves
# the rapp-tether/1.0 wire shape on :7071. See rapp_brainstem/start.sh.
#
# Then opens the mobile PWA in your default browser.
#
# Stops everything cleanly on Ctrl-C.
#
# Usage:
#     ./start-local.sh                    # static + open PWA
#     ./start-local.sh --swarm            # also start the local swarm server
#     ./start-local.sh --no-open          # don't open browser
#     ./start-local.sh --port 9000        # static server port (default 8000)
#
# Requirements: python3 (already on every Mac/Linux). NOTHING ELSE.

set -e
cd "$(dirname "$0")"

PORT=8000
SWARM_PORT=7080
START_SWARM=0
OPEN_BROWSER=1

while [ $# -gt 0 ]; do
    case "$1" in
        --swarm)      START_SWARM=1 ;;
        --no-open)    OPEN_BROWSER=0 ;;
        --port)       PORT="$2"; shift ;;
        --help|-h)
            grep '^#' "$0" | sed 's/^# \?//'
            exit 0 ;;
        *) echo "unknown flag: $1"; exit 2 ;;
    esac
    shift
done

PIDS=()
cleanup() {
    echo ""
    echo "▶ Stopping local services…"
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    echo "  Stopped. State preserved in IndexedDB (browser) and ~/.rapp-twins/ (filesystem)."
}
trap cleanup EXIT INT TERM

# ── Static file server (serves the mobile PWA + everything in repo) ────

echo "▶ Static file server on :$PORT"
lsof -ti:"$PORT" 2>/dev/null | xargs -r kill -9 2>/dev/null
python3 -m http.server "$PORT" >/tmp/rapp-static.log 2>&1 &
PIDS+=($!)

# ── Optional swarm server (multi-tenant local hosting) ────────────────

if [ "$START_SWARM" = "1" ] && [ -f rapp_brainstem/brainstem.py ]; then
    echo "▶ Swarm server on :$SWARM_PORT"
    lsof -ti:"$SWARM_PORT" 2>/dev/null | xargs -r kill -9 2>/dev/null
    python3 rapp_brainstem/brainstem.py --port "$SWARM_PORT" --root ~/.rapp-swarm >/tmp/rapp-swarm.log 2>&1 &
    PIDS+=($!)
fi

# ── Wait for static server to be ready (it boots fast) ─────────────────
sleep 1

URL="http://127.0.0.1:$PORT/rapp_brainstem/web/mobile/"

cat <<EOF

════════════════════════════════════════════════════════════════
  ✓ RAPP LOCAL-FIRST STACK RUNNING
════════════════════════════════════════════════════════════════

  📱 Mobile PWA:        $URL
  🌐 Onboard hatch:     http://127.0.0.1:$PORT/rapp_brainstem/web/onboard/
  🧠 Brainstem (OG):    http://127.0.0.1:$PORT/brainstem/
EOF

if [ "$START_SWARM" = "1" ]; then
    echo "  🐝 Swarm endpoint:    http://127.0.0.1:$SWARM_PORT/api/swarm/healthz"
fi

cat <<EOF

  Logs (tail to debug):
    tail -f /tmp/rapp-static.log
EOF
[ "$START_SWARM"  = "1" ] && echo "    tail -f /tmp/rapp-swarm.log"

cat <<EOF

  Ctrl-C to stop everything cleanly.

════════════════════════════════════════════════════════════════

EOF

if [ "$OPEN_BROWSER" = "1" ]; then
    if command -v open >/dev/null;     then open "$URL"
    elif command -v xdg-open >/dev/null; then xdg-open "$URL"
    fi
fi

# Wait forever (until Ctrl-C → cleanup trap)
wait
