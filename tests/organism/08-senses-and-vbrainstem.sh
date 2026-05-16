#!/usr/bin/env bash
# Boot via boot.py and verify two additive integrations:
#   - Senses (utils/senses/*_sense.py) are composed into the soul cache
#     and the response splitter handles each sense's delimiter.
#   - The vBrainstem (utils/web/index.html) is reachable through the
#     existing /web/ mount — it lives in its native file, no extra route.
#
# Both must work without modifying the kernel.
#
# Reference: pages/vault/Architecture/Boot Sidecar — Integrating Utils
# Without Modifying the Kernel.md

set -euo pipefail
cd "$(dirname "$0")/../.."

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

LOG="/tmp/rapp-organism-08.log"
PID_FILE="/tmp/rapp-organism-08.pid"

PORT=""
for p in 7115 7116 7117 7118 7119; do
    if ! lsof -i ":$p" -sTCP:LISTEN >/dev/null 2>&1; then
        PORT="$p"; break
    fi
done
[ -n "$PORT" ] || { echo "FAIL: no free port in 7115-7119"; exit 1; }

cleanup() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
}
trap cleanup EXIT

# 1. Static: kernel must NOT have grown sense composition logic — that
#    lives in senses_loader.py.
grep -E "_sense\.py|senses_loader" rapp_brainstem/brainstem.py && {
    echo "FAIL: kernel has sense composition baked in — Article XXXIII §4"
    exit 1
}

# 2. Boot via boot.py
echo "▶ booting via boot.py on :$PORT"
( cd rapp_brainstem && exec env PORT="$PORT" "$PYTHON" boot.py ) > "$LOG" 2>&1 &
echo $! > "$PID_FILE"

for i in $(seq 1 30); do
    if curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1; then break; fi
    sleep 0.5
    if [ "$i" = "30" ]; then
        echo "FAIL: kernel did not boot in 15s"
        echo "--- log ---"
        tail -40 "$LOG"
        exit 1
    fi
done

# 3. Boot log must report senses composed
grep -q "sense(s) composed into soul" "$LOG" || {
    echo "FAIL: senses_loader did not run (no 'sense(s) composed' line in log)"
    tail -40 "$LOG"
    exit 1
}
grep -qE "'twin'|'voice'" "$LOG" || {
    echo "FAIL: expected senses (twin, voice) not listed in boot log"
    grep "sense" "$LOG"
    exit 1
}

# 4. The vBrainstem lives at utils/web/index.html and is reachable via
#    the /web mount. No /vbrainstem route — the file is its own home.
VB_STATUS="$(curl -s -o /tmp/rapp-organism-08.vb.html -w "%{http_code}" "http://localhost:$PORT/web/index.html")"
[ "$VB_STATUS" = "200" ] || {
    echo "FAIL: /web/index.html returned $VB_STATUS (expected 200)"
    exit 1
}
SIZE="$(wc -c < /tmp/rapp-organism-08.vb.html | tr -d ' ')"
[ "$SIZE" -gt 100000 ] || {
    echo "FAIL: /web/index.html returned $SIZE bytes (expected >100k for the full vBrainstem)"
    exit 1
}
grep -q "<!DOCTYPE html>" /tmp/rapp-organism-08.vb.html || {
    echo "FAIL: /web/index.html response does not look like HTML"
    exit 1
}

# 5. Unit-test the response splitter directly. We exercise senses_loader's
#    after_request hook via a Flask test client with a synthetic /chat
#    response that contains both sense delimiters. This proves the
#    splitter handles >1 sense in a single response.
HARNESS_OUT="$("$PYTHON" - <<'PY'
import json, os, sys
sys.path.insert(0, "rapp_brainstem")
from flask import Flask, jsonify, request
import senses_loader

senses = senses_loader.discover()
assert senses, "no senses discovered"
names = sorted(s.name for s in senses)
assert names == ["twin", "voice"], f"unexpected senses: {names}"

app = Flask(__name__)

@app.route("/chat", methods=["POST"])
def chat():
    return jsonify({
        "response": "main reply text|||VOICE|||spoken version|||TWIN|||<frame>x</frame>",
        "session_id": "test",
    })

import types
fake_kernel = types.ModuleType("__main__")
fake_kernel._soul_cache = "base soul"
fake_kernel.load_soul = lambda: fake_kernel._soul_cache
fake_kernel.__file__ = "rapp_brainstem/brainstem.py"
sys.modules["__main__"] = fake_kernel

count = senses_loader.install(app, senses=senses)
assert count == 2, f"expected 2 senses installed, got {count}"

client = app.test_client()
resp = client.post("/chat", json={})
data = resp.get_json()
assert data["response"] == "main reply text", f"response not trimmed: {data['response']!r}"
assert "voice_response" in data, "voice_response missing"
assert "twin_response" in data, "twin_response missing"
print("OK senses splitter divides reply into all configured response_keys")
PY
2>&1)"

echo "  $HARNESS_OUT"
echo "$HARNESS_OUT" | grep -q "^OK senses splitter" || {
    echo "FAIL: senses splitter unit test did not pass"
    exit 1
}

echo "✓ senses composed into soul; vBrainstem reachable at /web/index.html (its native home); splitter handles all senses"
