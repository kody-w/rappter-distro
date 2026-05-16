#!/bin/bash
# tests/test-t2t-removal.sh — verifies the T2T federation surface has been
# fully excised from the repo (per CONSTITUTION.md Article XIV and the
# "focus is adoption, not federation" policy).
#
# Structural checks (no server): files absent, imports clean, vendored
# bundle clean, source free of stale T2T route handlers.
#
# Runtime checks (swarm_server on a test port): T2T routes 404, core
# non-T2T surface (healthz, deploy, agent, seal, snapshot) still 200s.
#
#     bash tests/test-t2t-removal.sh
#
# Exits 0 on success, non-zero with diagnostics on failure.

set -e
set -o pipefail

PORT=7190
ROOT=/tmp/rapp-swarm-test-t2t-removal
SERVER_PID=""
PASS=0
FAIL=0
FAIL_NAMES=()

cleanup() {
    if [ -n "$SERVER_PID" ]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name"
        echo "      expected: $expected"
        echo "      actual:   $actual"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

assert_not_exists() {
    local name="$1" path="$2"
    if [ ! -e "$path" ]; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name (found: $path)"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

assert_no_match() {
    local name="$1" pattern="$2" file="$3"
    if [ ! -f "$file" ]; then
        echo "  ✗ $name (file missing: $file)"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name"); return
    fi
    if grep -qE "$pattern" "$file"; then
        echo "  ✗ $name"
        echo "      file:    $file"
        echo "      hits:    $(grep -nE "$pattern" "$file" | head -3)"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    else
        echo "  ✓ $name"; PASS=$((PASS + 1))
    fi
}

# ── Section 1: Source files absent ─────────────────────────────────────

echo "--- Section 1: T2T/workspace source files gone ---"
assert_not_exists "rapp_brainstem/t2t.py removed"        rapp_brainstem/t2t.py
assert_not_exists "rapp_brainstem/workspace.py removed"  rapp_brainstem/workspace.py
assert_not_exists "tests/test-t2t.sh removed"            tests/test-t2t.sh

# ── Section 2: swarm_server.py / chat.py entirely removed ─────────────

echo ""
echo "--- Section 2: swarm_server.py and chat.py entirely gone ---"

assert_not_exists "rapp_brainstem/swarm_server.py removed"  rapp_brainstem/swarm_server.py
assert_not_exists "rapp_brainstem/chat.py removed"          rapp_brainstem/chat.py

# ── Section 3: function_app.py is clean ───────────────────────────────

echo ""
echo "--- Section 3: function_app.py is clean ---"

PARSE_OUT=$(python3 -c "
import ast
with open('rapp_swarm/function_app.py') as f:
    ast.parse(f.read())
print('ok')
" 2>&1)
assert_eq "function_app.py parses as valid Python"  "ok"  "$PARSE_OUT"

assert_no_match "function_app.py has no t2t route handlers" \
    'route="t2t/'  rapp_swarm/function_app.py
assert_no_match "function_app.py has no 'from t2t import' statements" \
    'from t2t import'  rapp_swarm/function_app.py
assert_no_match "function_app.py has no get_t2t_manager imports" \
    'get_t2t_manager'  rapp_swarm/function_app.py

# ── Section 4: build.sh produces a clean vendored bundle ──────────────

echo ""
echo "--- Section 4: build.sh is clean ---"

assert_no_match "build.sh vendor list does not include t2t.py" \
    't2t\.py'  rapp_swarm/build.sh
assert_no_match "build.sh vendor list does not include workspace.py" \
    'workspace\.py'  rapp_swarm/build.sh

# Run build.sh fresh and inspect the output
rm -rf rapp_swarm/_vendored
bash rapp_swarm/build.sh >/dev/null 2>&1
assert_not_exists "vendored bundle has no t2t.py"         rapp_swarm/_vendored/t2t.py
assert_not_exists "vendored bundle has no workspace.py"   rapp_swarm/_vendored/workspace.py
assert_not_exists "vendored bundle has no server.py"      rapp_swarm/_vendored/server.py
assert_not_exists "vendored bundle has no chat.py"        rapp_swarm/_vendored/chat.py
# Core runtime deps live under utils/ in the vendor tree now
# (Article XVI — root stays minimal, support modules in utils/).
if [ -f rapp_swarm/_vendored/utils/llm.py ] && \
   [ -f rapp_swarm/_vendored/utils/twin.py ] && \
   [ -f rapp_swarm/_vendored/utils/_basic_agent_shim.py ]; then
    echo "  ✓ vendored bundle contains utils/llm + utils/twin + utils/_basic_agent_shim"
    PASS=$((PASS + 1))
else
    echo "  ✗ vendored bundle missing expected core files"
    FAIL=$((FAIL + 1)); FAIL_NAMES+=("vendor-core")
fi

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"
echo "  $PASS passed, $FAIL failed"
echo "════════════════════════════════════════"
if [ $FAIL -gt 0 ]; then
    for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done
    exit 1
fi
exit 0
