#!/usr/bin/env bash
# UI smoke: brainstem serves /, HTML parses, v0.6.0 chrome markers AND
# v0.12.x feature handlers are both present in the served file.
set -euo pipefail
cd "$(dirname "$0")/../.."

PORT="${PORT:-7072}"
PID_FILE=/tmp/rapp-e2e-brainstem.pid
LOG=/tmp/rapp-e2e-brainstem.log
HTML=/tmp/rapp-e2e-index.html

cleanup() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    rm -f "$HTML"
}
trap cleanup EXIT

if curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1; then
    echo "▶ Reusing brainstem already on :$PORT"
else
    echo "▶ Starting brainstem on :$PORT..."
    ( cd rapp_brainstem && PORT=$PORT python3 brainstem.py ) > "$LOG" 2>&1 &
    echo $! > "$PID_FILE"
    for i in $(seq 1 30); do
        curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1 && break
        sleep 1
    done
fi

echo "▶ GET / ..."
HTTP=$(curl -s -o "$HTML" -w "%{http_code}" "http://localhost:$PORT/")
if [ "$HTTP" != "200" ]; then
    echo "FAIL: / returned HTTP $HTTP"
    exit 1
fi
BYTES=$(wc -c < "$HTML")
LINES=$(wc -l < "$HTML")
if [ "$BYTES" -lt 10000 ]; then
    echo "FAIL: / returned too-small body ($BYTES bytes)"
    exit 1
fi
echo "PASS: / → 200 ($BYTES bytes, $LINES lines)"

# HTML parse sanity — use python html.parser which catches gross errors
python3 - <<EOF || { echo "FAIL: HTML parse error"; exit 1; }
from html.parser import HTMLParser
import sys
class P(HTMLParser):
    def __init__(self):
        super().__init__(); self.err = None
    def error(self, msg): self.err = msg
p = P()
with open("$HTML") as f: p.feed(f.read())
if p.err:
    print(p.err); sys.exit(1)
EOF
echo "PASS: HTML parses cleanly"

# ── v0.6.0 chrome markers ─────────────────────────────────────────────

check_marker() {
    local label="$1"; local pattern="$2"
    if grep -qE "$pattern" "$HTML"; then
        echo "PASS: $label"
    else
        echo "FAIL: missing marker — $label"
        echo "  expected pattern: $pattern"
        exit 1
    fi
}

echo "▶ Checking v0.6.0 chrome markers..."
check_marker "header RAPP Brainstem title"           'RAPP Brainstem'
check_marker "status indicator element"              'id="status-text"|status-dot|class="status"'
check_marker "model-select dropdown"                 'model-select'
check_marker "footer tag present"                    '<footer'
check_marker "Export toolbar link"                   'exportChat\(\)'
check_marker "Import toolbar link"                   'chat-import'
check_marker "Clear toolbar link"                    'clearChat\(\)|Clear'
check_marker "Get Help link (diagnostics report)"    'reportToAdmin\(\)|Get Help'
check_marker "Send button"                           'id="send"|onclick="send\(\)"|Send'
check_marker "icon-only labeled-btn override applied" '\.icon-btn\.labeled-btn \.btn-label \{ display: none'

# ── v0.12.x feature wiring (must survive the look-and-feel port) ─────

echo "▶ Checking v0.12.x feature handlers are still wired..."
check_marker "voice toggle endpoint"                 '/voice/toggle'
check_marker "voice config endpoint"                 '/voice/config'
check_marker "models list endpoint"                  '/models'
check_marker "agents API endpoint"                   '/agents'
check_marker "diagnostics export"                    '/diagnostics|exportBook'
check_marker "egg export"                            'exportEgg|egg/export'
check_marker "twin mode JS variable"                 'twinMode'
check_marker "swarm management JS"                   'swarmSelect|activeSwarms|swarm-bar'
check_marker "settings panel"                        'settings-gear-btn|sp-'
check_marker "starter prompts"                       'starter-btn'

echo "✅ UI smoke test passed"
