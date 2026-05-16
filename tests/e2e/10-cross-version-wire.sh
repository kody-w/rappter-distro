#!/usr/bin/env bash
# Cross-version wire test (Constitution Article XXV — time-travel safety).
#
# Spins up the legacy v0.6.0 brainstem from kody-w/rapp-installer alongside
# the current brainstem and proves they interoperate through unmodified
# /chat — both directions, including with a user_guid the legacy code
# has never heard of.
#
# This is the acid test for "a brainstem from a year ago still talks to
# the latest brainstem with no code changes on either side." If this
# breaks, the wire broke.
set -euo pipefail
cd "$(dirname "$0")/../.."

CURR_PORT="${CURR_PORT:-7082}"
LEGACY_PORT="${LEGACY_PORT:-7083}"
PID_CURR=/tmp/rapp-e2e-curr.pid
PID_LEGACY=/tmp/rapp-e2e-legacy.pid
LOG_CURR=/tmp/rapp-e2e-curr.log
LOG_LEGACY=/tmp/rapp-e2e-legacy.log
LEGACY_DIR=/tmp/rapp-e2e-legacy-src
CURR_AUTH_BORROWED=0
LEGACY_AUTH_BORROWED=0

cleanup() {
    [ -f "$PID_CURR" ] && kill "$(cat "$PID_CURR")" 2>/dev/null || true
    [ -f "$PID_LEGACY" ] && kill "$(cat "$PID_LEGACY")" 2>/dev/null || true
    rm -f "$PID_CURR" "$PID_LEGACY"
    if [ "$CURR_AUTH_BORROWED" = "1" ]; then
        rm -f rapp_brainstem/.copilot_token rapp_brainstem/.copilot_session
    fi
    rm -rf "$LEGACY_DIR"
}
trap cleanup EXIT

for p in "$CURR_PORT" "$LEGACY_PORT"; do
    if lsof -i ":$p" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "FAIL: port $p already in use"
        exit 1
    fi
done

# Auth borrow for current brainstem
for AUTH_SRC in "$HOME/.brainstem/src/rapp_brainstem" "$HOME/.brainstem"; do
    if [ -f "$AUTH_SRC/.copilot_session" ] && [ ! -f rapp_brainstem/.copilot_session ]; then
        cp "$AUTH_SRC/.copilot_session" rapp_brainstem/.copilot_session
        cp "$AUTH_SRC/.copilot_token"   rapp_brainstem/.copilot_token 2>/dev/null || true
        CURR_AUTH_BORROWED=1
        break
    fi
done
[ "$CURR_AUTH_BORROWED" = "1" ] || { echo "FAIL: no Copilot session available to borrow"; exit 1; }

# Pull legacy v0.6.0 from kody-w/rapp-installer
echo "▶ Fetching legacy v0.6.0 brainstem..."
mkdir -p "$LEGACY_DIR/agents"
LEGACY_BASE=https://raw.githubusercontent.com/kody-w/rapp-installer/main/rapp_brainstem
for f in brainstem.py local_storage.py soul.md requirements.txt VERSION; do
    curl -fsSL "$LEGACY_BASE/$f" -o "$LEGACY_DIR/$f" || { echo "FAIL: could not fetch $f"; exit 1; }
done
for f in basic_agent.py context_memory_agent.py hacker_news_agent.py manage_memory_agent.py; do
    curl -fsSL "$LEGACY_BASE/agents/$f" -o "$LEGACY_DIR/agents/$f"
done
LEGACY_VERSION=$(cat "$LEGACY_DIR/VERSION")
CURR_VERSION=$(cat rapp_brainstem/VERSION)
echo "  legacy: v$LEGACY_VERSION"
echo "  current: v$CURR_VERSION"

# Share auth with the legacy brainstem too
cp rapp_brainstem/.copilot_session "$LEGACY_DIR/.copilot_session"
cp rapp_brainstem/.copilot_token   "$LEGACY_DIR/.copilot_token" 2>/dev/null || true
cp /dev/null "$LEGACY_DIR/.env" 2>/dev/null || true

# Start both
echo "▶ Starting current brainstem on :$CURR_PORT..."
( cd rapp_brainstem && PORT=$CURR_PORT python3 brainstem.py ) > "$LOG_CURR" 2>&1 &
echo $! > "$PID_CURR"
echo "▶ Starting legacy brainstem on :$LEGACY_PORT..."
( cd "$LEGACY_DIR" && PORT=$LEGACY_PORT python3 brainstem.py ) > "$LOG_LEGACY" 2>&1 &
echo $! > "$PID_LEGACY"

for port in $CURR_PORT $LEGACY_PORT; do
    for i in $(seq 1 30); do
        curl -sf "http://localhost:$port/health" >/dev/null 2>&1 && break
        sleep 1
        if [ "$i" = "30" ]; then
            echo "FAIL: brainstem on :$port did not come up"
            tail -20 "/tmp/rapp-e2e-$([ "$port" = "$CURR_PORT" ] && echo curr || echo legacy).log"
            exit 1
        fi
    done
done

# ── Test A: current → legacy with a user_guid the legacy code has never heard of
echo "▶ A. current → legacy WITH user_guid (legacy must accept and ignore)"
RESP=$(curl -s -X POST "http://localhost:$LEGACY_PORT/chat" \
    -H "Content-Type: application/json" \
    -d '{"user_input":"reply with exactly the word: ok","conversation_history":[],"user_guid":"99999999-aaaa-bbbb-cccc-dddddddddddd"}')
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:$LEGACY_PORT/chat" \
    -H "Content-Type: application/json" \
    -d '{"user_input":"reply with exactly the word: ok","conversation_history":[],"user_guid":"99999999-aaaa-bbbb-cccc-dddddddddddd"}')
if [ "$HTTP_CODE" != "200" ]; then
    echo "FAIL: legacy rejected request with unknown user_guid (HTTP $HTTP_CODE)"
    echo "$RESP"
    exit 1
fi
TEXT=$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin,strict=False).get("response",""))')
[ -z "$TEXT" ] && { echo "FAIL: legacy returned empty response"; echo "$RESP"; exit 1; }
echo "PASS: legacy v$LEGACY_VERSION accepted unknown user_guid and replied"

# ── Test B: legacy → current WITHOUT user_guid (current must default silently)
echo "▶ B. legacy → current WITHOUT user_guid (current must default)"
RESP=$(curl -s -X POST "http://localhost:$CURR_PORT/chat" \
    -H "Content-Type: application/json" \
    -d '{"user_input":"reply with exactly the word: ok","conversation_history":[]}')
ECHOED=$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin,strict=False).get("user_guid",""))')
DEFAULT="c0p110t0-aaaa-bbbb-cccc-123456789abc"
if [ "$ECHOED" != "$DEFAULT" ]; then
    echo "FAIL: current did not default user_guid; got '$ECHOED'"
    exit 1
fi
echo "PASS: current v$CURR_VERSION defaulted user_guid silently"

# ── Test C: cross-version conversation_history honored
echo "▶ C. multi-turn history across both brainstems"
PAYLOAD='{
  "user_input": "What number did I just ask you to remember?",
  "conversation_history": [
    {"role": "user", "content": "Remember the number 42 for me."},
    {"role": "assistant", "content": "Got it — 42."}
  ]
}'
for tag in "legacy:$LEGACY_PORT" "current:$CURR_PORT"; do
    name="${tag%:*}"
    port="${tag#*:}"
    RESP=$(curl -s -X POST "http://localhost:$port/chat" \
        -H "Content-Type: application/json" -d "$PAYLOAD")
    TEXT=$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin,strict=False).get("response",""))')
    if echo "$TEXT" | grep -q "42"; then
        echo "PASS: $name honored conversation_history"
    else
        echo "FAIL: $name did not return 42"
        echo "  reply: $TEXT"
        exit 1
    fi
done

echo "✅ Cross-version wire test passed (v$LEGACY_VERSION ↔ v$CURR_VERSION)"
