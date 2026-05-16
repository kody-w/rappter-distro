#!/usr/bin/env bash
# One-liner install verification: run curl|bash in a /tmp sandbox,
# verify brainstem starts, /health green, /chat round-trips.
# Only valid AFTER publishing the current main to the public repo.
set -euo pipefail

SANDBOX=/tmp/rapp-install-sandbox-$(date +%Y%m%d-%H%M%S)
PORT=7072  # different from 7071 to avoid colliding with an active dev brainstem
PID_FILE=/tmp/rapp-e2e-install.pid
LOG=/tmp/rapp-e2e-install.log

cleanup() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    rm -rf "$SANDBOX"
}
trap cleanup EXIT

mkdir -p "$SANDBOX"
cd "$SANDBOX"

echo "▶ Running curl|bash in $SANDBOX (project-local mode)..."
# Project-local install with --here so it doesn't touch ~/.brainstem
if ! curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash -s -- --here > install.log 2>&1; then
    echo "FAIL: installer exited non-zero"
    tail -40 install.log
    exit 1
fi
echo "PASS: installer completed"

# Locate the installed brainstem.py (could be at .brainstem/, at
# .brainstem/src/rapp_brainstem/, or under RAPP/rapp_brainstem/
# depending on installer version).
BRAINSTEM_PY=$(find . -maxdepth 5 -name brainstem.py -type f 2>/dev/null | head -1)
if [ -z "$BRAINSTEM_PY" ] || [ ! -f "$BRAINSTEM_PY" ]; then
    echo "FAIL: could not locate installed brainstem.py"
    echo "  sandbox contents:"
    find . -maxdepth 4 -type d 2>/dev/null | head -20
    exit 1
fi
INSTALL_DIR=$(dirname "$BRAINSTEM_PY")
echo "  install dir: $INSTALL_DIR"

# Start brainstem on a non-default port
echo "▶ Starting installed brainstem on :$PORT..."
( cd "$INSTALL_DIR" && PORT=$PORT python3 brainstem.py ) > "$LOG" 2>&1 &
echo $! > "$PID_FILE"

for i in $(seq 1 30); do
    if curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1; then
        break
    fi
    sleep 1
    if [ "$i" = "30" ]; then
        echo "FAIL: installed brainstem did not come up"
        tail -30 "$LOG"
        exit 1
    fi
done

HEALTH=$(curl -s "http://localhost:$PORT/health")
STATUS=$(echo "$HEALTH" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status",""))')
if [ "$STATUS" != "ok" ] && [ "$STATUS" != "unauthenticated" ]; then
    echo "FAIL: /health status='$STATUS'"
    echo "$HEALTH"
    exit 1
fi
echo "PASS: installed brainstem /health returns status=$STATUS"

if [ "$STATUS" = "ok" ]; then
    CHAT=$(curl -s -X POST "http://localhost:$PORT/chat" \
        -H "Content-Type: application/json" \
        -d '{"user_input":"reply with exactly one word: hi","conversation_history":[]}' )
    TXT=$(echo "$CHAT" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("response",""))')
    if [ -z "$TXT" ]; then
        echo "FAIL: /chat empty"
        exit 1
    fi
    echo "PASS: installed /chat round-trip ok"
else
    echo "SKIP: /chat round-trip (installed brainstem unauthenticated; expected on a clean sandbox without gh auth)"
fi

echo "✅ One-liner install verification passed"
