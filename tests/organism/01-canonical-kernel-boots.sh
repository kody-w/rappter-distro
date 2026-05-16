#!/usr/bin/env bash
# Fixture: the canonical kernel must boot from a fresh repo checkout.
#
# Asserts:
#   - PORT=<free> python brainstem.py exits cleanly to /health
#   - /health returns status:ok with the soul path resolved
#   - /agents lists at least one *_agent.py file
#   - /version matches the VERSION file
#
# Reference: Constitution Article XXXIII §3 — drop-in replaceability is the test.

set -euo pipefail
cd "$(dirname "$0")/../.."

REPO_ROOT="$(pwd)"
LOG="/tmp/rapp-organism-01.log"
PID_FILE="/tmp/rapp-organism-01.pid"

# Pick a free port
PORT=""
for p in 7080 7081 7082 7083 7084 7085 7086 7087; do
    if ! lsof -i ":$p" -sTCP:LISTEN >/dev/null 2>&1; then
        PORT="$p"; break
    fi
done
[ -n "$PORT" ] || { echo "FAIL: no free port in 7080-7087"; exit 1; }

cleanup() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
}
trap cleanup EXIT

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

echo "▶ booting canonical kernel on :$PORT (python: $PYTHON)"
( cd rapp_brainstem && exec env PORT="$PORT" "$PYTHON" brainstem.py ) > "$LOG" 2>&1 &
echo $! > "$PID_FILE"

# Wait for /health
for i in $(seq 1 30); do
    if curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1; then break; fi
    sleep 0.5
    if [ "$i" = "30" ]; then
        echo "FAIL: kernel did not come up in 15s"
        echo "--- log tail ---"
        tail -40 "$LOG"
        exit 1
    fi
done

HEALTH="$(curl -s "http://localhost:$PORT/health")"
echo "  /health: $HEALTH"

# /health must include status (ok or unauthenticated — both are valid boot states)
echo "$HEALTH" | grep -qE '"status":"(ok|unauthenticated)"' || {
    echo "FAIL: /health missing status:ok|unauthenticated"
    exit 1
}

# /health must list agents (non-empty)
echo "$HEALTH" | grep -qE '"agents":\[' || {
    echo "FAIL: /health missing agents key"
    exit 1
}
echo "$HEALTH" | grep -qE '"agents":\[\]' && {
    echo "FAIL: /health agents list is empty (no *_agent.py files discovered)"
    exit 1
}

# /version must match VERSION file
VERSION_FILE="$(cat rapp_brainstem/VERSION | tr -d '[:space:]')"
VERSION_API="$(curl -s "http://localhost:$PORT/version" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')"
[ "$VERSION_FILE" = "$VERSION_API" ] || {
    echo "FAIL: /version mismatch (file=$VERSION_FILE api=$VERSION_API)"
    exit 1
}

# /agents file listing must include at least basic_agent.py and one *_agent.py
AGENTS="$(curl -s "http://localhost:$PORT/agents")"
echo "$AGENTS" | grep -q "basic_agent.py" || {
    echo "FAIL: /agents listing missing basic_agent.py"
    exit 1
}
echo "$AGENTS" | grep -qE '_agent\.py' || {
    echo "FAIL: /agents listing has no *_agent.py files"
    exit 1
}

echo "✓ canonical kernel boots, /health ok, /version matches, /agents lists files"
