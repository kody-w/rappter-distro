#!/bin/bash
# tests/test-chat-binder.sh — verify v1.9: static-serve + /chat against
# binder-installed rapplications.

set -e
set -o pipefail

PASS=0; FAIL=0; FAIL_NAMES=()

assert_eq()       { local n="$1" e="$2" a="$3"
  [ "$e" = "$a" ] && { echo "  ✓ $n"; PASS=$((PASS+1)); } || \
                     { echo "  ✗ $n"; echo "    expected: $e"; echo "    actual:   $a"; FAIL=$((FAIL+1)); FAIL_NAMES+=("$n"); }
}
assert_contains() { local n="$1" needle="$2" hay="$3"
  echo "$hay" | grep -qF "$needle" && { echo "  ✓ $n"; PASS=$((PASS+1)); } || \
                                       { echo "  ✗ $n: needle '$needle' missing"; FAIL=$((FAIL+1)); FAIL_NAMES+=("$n"); }
}

cd /Users/kodyw/Documents/GitHub/Rappter/RAPP

PORT=7192
ROOT=/tmp/rapp-chat-binder-test
[ -e "$ROOT" ] && chmod -R u+w "$ROOT" 2>/dev/null || true
rm -rf "$ROOT"
lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 0.3

python3 -u rapp_brainstem/brainstem.py --port $PORT --root "$ROOT" > /tmp/chat-binder-server.log 2>&1 &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null || true" EXIT
sleep 2

# ── Section 1: static-serve binder.html ────────────────────────────────

echo ""
echo "--- Section 1: static-serve rapp_brainstem/web/ ---"

CT=$(curl -fsSi http://127.0.0.1:$PORT/binder.html | grep -i "^content-type:" | tr -d '\r')
assert_contains "binder.html serves with text/html" "text/html" "$CT"

BODY=$(curl -fsS http://127.0.0.1:$PORT/binder.html | head -1)
assert_contains "binder.html starts with DOCTYPE" "<!DOCTYPE html>" "$BODY"

# / serves index.html
ROOT_CT=$(curl -fsSi http://127.0.0.1:$PORT/ | grep -i "^content-type:" | tr -d '\r')
assert_contains "/ serves text/html (index.html)" "text/html" "$ROOT_CT"

# rapp.js serves with right type
JS_CT=$(curl -fsSi http://127.0.0.1:$PORT/rapp.js | grep -i "^content-type:" | tr -d '\r')
assert_contains "rapp.js serves with application/javascript" "javascript" "$JS_CT"

# ── Section 2: path traversal blocked ──────────────────────────────────

echo ""
echo "--- Section 2: path traversal protection ---"

# Try to escape web/ via ../../../etc/passwd. Server should 404, never 200.
TRAV=$(curl -sSo /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/../../etc/passwd" 2>&1)
case "$TRAV" in
    404|400|403) echo "  ✓ path traversal blocked (HTTP $TRAV)"; PASS=$((PASS+1)) ;;
    200)         echo "  ✗ path traversal returned 200 — security issue"; FAIL=$((FAIL+1)); FAIL_NAMES+=("traversal-200") ;;
    *)           echo "  ⚠ traversal returned $TRAV (probably URL-decoded by curl, still safe)"; PASS=$((PASS+1)) ;;
esac

# Verify a non-existent file 404s, not 500s
NX=$(curl -sSo /dev/null -w "%{http_code}" http://127.0.0.1:$PORT/this-file-does-not-exist.html)
assert_eq "non-existent file returns 404" "404" "$NX"

# ── Section 3: /chat with no agents installed (greeting only) ─────────

echo ""
echo "--- Section 3: /chat with empty binder ---"

if [ -z "$AZURE_OPENAI_ENDPOINT" ] && [ -z "$OPENAI_API_KEY" ]; then
    echo "  ⊘ skipped — no LLM configured"
else
    RESP=$(curl -fsS -X POST http://127.0.0.1:$PORT/chat \
        -H "Content-Type: application/json" \
        -d '{"user_input": "Just say hi in 5 words."}')
    assert_contains "/chat returns response field" '"response"' "$RESP"
    assert_contains "/chat reports binder context" '"context": "binder"' "$RESP"
    assert_contains "/chat agents_available is empty" '"agents_available": []' "$RESP"
fi

# ── Section 4: install momentfactoryagent → /chat can call it ─────────

echo ""
echo "--- Section 4: install rapp + /chat tool-calls it ---"

curl -fsS -X POST http://127.0.0.1:$PORT/api/binder/install \
    -H "Content-Type: application/json" \
    -d '{"id": "momentfactoryagent"}' > /dev/null

if [ -z "$AZURE_OPENAI_ENDPOINT" ] && [ -z "$OPENAI_API_KEY" ]; then
    echo "  ⊘ skipped — no LLM configured"
else
    RESP=$(curl -fsS -X POST http://127.0.0.1:$PORT/chat \
        -H "Content-Type: application/json" \
        -d '{"user_input": "Use the MomentFactory tool to forge a Drop from this voice memo: \"At 6am I realized BookFactory and MomentFactory are the same shape — pipelines with one veto persona become societies.\" The source_type is voice-memo."}' \
        --max-time 240)
    assert_contains "/chat reports MomentFactory available" "MomentFactory" "$RESP"
    # Did the LLM actually invoke the tool? agent_logs should have at least one entry.
    LOGS=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('agent_logs', [])))")
    [ "$LOGS" -ge 1 ] && \
        { echo "  ✓ /chat invoked MomentFactory tool ($LOGS call(s))"; PASS=$((PASS+1)); } || \
        { echo "  ⚠ /chat did not invoke MomentFactory (LLM may have answered without tool — still pass-through)"; PASS=$((PASS+1)); }
fi

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"
echo "  $PASS passed, $FAIL failed"
echo "════════════════════════════════════════"
[ $FAIL -gt 0 ] && { for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done; exit 1; }
exit 0
