#!/usr/bin/env bash
# Binder install test — kernel-baked, no rapp_store copy needed.
#
# Since the catalog moved to kody-w/rapp_store on 2026-04-26, the binder
# is no longer copied from rapp_store/binder/binder_service.py at install
# time — it ships kernel-baked at rapp_brainstem/services/binder_service.py
# and is part of the brainstem itself. The installer's install_binder_locally
# function is now a no-op happy path; restore-from-git-HEAD is the only
# fallback.
#
# This test verifies:
#   - the kernel-baked binder is present after clone
#   - launching the brainstem makes /api/binder respond 200
#   - /health does NOT include a bootstrap block (we ripped that out)
set -euo pipefail
cd "$(dirname "$0")/../.."

PORT="${PORT:-7084}"
SANDBOX=/tmp/rapp-e2e-binder-install
PID_FILE=/tmp/rapp-e2e-binder-install.pid
LOG=/tmp/rapp-e2e-binder-install.log

cleanup() {
    [ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
    rm -rf "$SANDBOX"
}
trap cleanup EXIT

if lsof -i ":$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "FAIL: port $PORT already in use"
    exit 1
fi

# Build a sandbox that mirrors the post-sparse-clone layout: just
# rapp_brainstem/. No sibling rapp_store/ — that lives in its own repo now.
echo "▶ Building sandbox at $SANDBOX (mirrors sparse-clone layout)..."
rm -rf "$SANDBOX"
mkdir -p "$SANDBOX/src/rapp_brainstem"
cp -r rapp_brainstem/* "$SANDBOX/src/rapp_brainstem/"
# Borrow auth so /chat works (not strictly needed for this test, but consistent)
for AUTH_SRC in "$HOME/.brainstem/src/rapp_brainstem" "$HOME/.brainstem"; do
    if [ -f "$AUTH_SRC/.copilot_session" ]; then
        cp "$AUTH_SRC/.copilot_session" "$SANDBOX/src/rapp_brainstem/.copilot_session"
        cp "$AUTH_SRC/.copilot_token"   "$SANDBOX/src/rapp_brainstem/.copilot_token" 2>/dev/null || true
        break
    fi
done
# Fresh state — no .brainstem_data/. Keep services/ since the binder ships there.
rm -rf "$SANDBOX/src/rapp_brainstem/.brainstem_data"

# ── 1. kernel-baked binder is present (no copy step needed) ──────────
if [ ! -f "$SANDBOX/src/rapp_brainstem/utils/services/binder_service.py" ]; then
    echo "FAIL: utils/services/binder_service.py is missing — kernel binder didn't ship"
    exit 1
fi
echo "PASS: kernel-baked binder_service.py is present"

# Launch the brainstem
echo "▶ Launching brainstem on :$PORT..."
( cd "$SANDBOX/src/rapp_brainstem" && PORT=$PORT python3 brainstem.py ) > "$LOG" 2>&1 &
echo $! > "$PID_FILE"
for i in $(seq 1 30); do
    curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1 && break
    sleep 1
    [ "$i" = "30" ] && { echo "FAIL: did not come up"; tail -20 "$LOG"; exit 1; }
done

# ── 2. /api/binder responds 200 with installed list ──────────────────
RESP=$(curl -s -w "\n%{http_code}" "http://localhost:$PORT/api/binder")
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
if [ "$HTTP_CODE" != "200" ]; then
    echo "FAIL: /api/binder returned $HTTP_CODE"
    echo "$BODY"
    exit 1
fi
HAS_KEY=$(echo "$BODY" | python3 -c 'import sys,json; print("installed" in json.load(sys.stdin))')
if [ "$HAS_KEY" != "True" ]; then
    echo "FAIL: /api/binder response missing 'installed' key"
    exit 1
fi
echo "PASS: /api/binder returns 200 with installed key"

# ── 3. /health does NOT include bootstrap block (ripped out) ─────────
HAS_BOOTSTRAP=$(curl -s "http://localhost:$PORT/health" | python3 -c 'import sys,json; print("bootstrap" in json.load(sys.stdin))')
if [ "$HAS_BOOTSTRAP" = "True" ]; then
    echo "FAIL: /health still includes 'bootstrap' block — should have been removed"
    exit 1
fi
echo "PASS: /health does not include bootstrap block (removed)"

# ── 4. .brainstem_data/bootstrap.json was NOT created ────────────────
if [ -f "$SANDBOX/src/rapp_brainstem/.brainstem_data/bootstrap.json" ]; then
    echo "FAIL: bootstrap.json was created — bootstrap mechanism still active"
    exit 1
fi
echo "PASS: no bootstrap.json (bootstrap mechanism removed)"

echo "✅ Binder install test passed (one-liner copies binder, no bootstrap)"
