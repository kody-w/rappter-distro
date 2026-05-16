#!/bin/bash
# tests/test-bookfactory-v2.sh — verify v2 BookFactory:
#   1. New specialist agents (strip_scaffolding, restructure) load and run
#   2. Code blocks survive the editor pass (cutweak now preserves them)
#   3. Outline scaffolding is stripped from synthetic input that contains it
#   4. Editor composite runs all 5 specialists in order
#
# This is a wire-and-behavior test, not a quality test (we can't programmatically
# score "did the writing get better"). For quality, see tests/test-bookfactory-v2-vs-v1-quality.md.

set -e
set -o pipefail

# NOTE (2026-04-26): the catalog moved to kody-w/rapp_store. This script
# inspects local rapp_store/ filesystem content that no longer exists in
# this repo, so it self-skips here. The same test belongs in the catalog
# repo's own test suite — see github.com/kody-w/rapp_store.
if [ ! -d rapp_store ] || [ -f rapp_store/MOVED.md ] && [ ! -f rapp_store/index.json ]; then
    echo "SKIP: tests/test-bookfactory-v2.sh — catalog moved to kody-w/rapp_store"
    exit 0
fi

PORT=7180
ROOT=/tmp/rapp-bf-v2-test
PASS=0; FAIL=0; FAIL_NAMES=()

cleanup() {
    [ -n "$SERVER_PID" ] && { kill $SERVER_PID 2>/dev/null || true; wait $SERVER_PID 2>/dev/null || true; }
}
trap cleanup EXIT

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name"; echo "      expected: $expected"; echo "      actual:   $actual"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

assert_contains() {
    local name="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name"; echo "      needle:    $needle"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

assert_not_contains() {
    local name="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "  ✗ $name (found $needle)"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    else
        echo "  ✓ $name"; PASS=$((PASS + 1))
    fi
}

# ── Setup ──────────────────────────────────────────────────────────────

cd /Users/kodyw/Documents/GitHub/Rappter/RAPP
[ -e "$ROOT" ] && chmod -R u+w "$ROOT" 2>/dev/null || true
rm -rf "$ROOT"
lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 0.5
python3 -u rapp_brainstem/brainstem.py --port $PORT --root $ROOT > /tmp/bf-v2-server.log 2>&1 &
SERVER_PID=$!
sleep 2

# Hatch the swarm with all current agent.py files (v2 included)
GUID=$(python3 - <<'PY'
import json, urllib.request, pathlib
agents = [{'filename':p.name,'source':p.read_text()}
          for p in sorted(pathlib.Path('rapp_store/bookfactory/source').glob('*_agent.py'))
          if p.name != 'basic_agent.py']
bundle = {'schema':'rapp-swarm/1.0','name':'bf-v2-test',
          'soul':'BookFactory v2 wire test','agents':agents}
import urllib.request
r = urllib.request.urlopen(urllib.request.Request(
    'http://127.0.0.1:7180/api/swarm/deploy',
    data=json.dumps(bundle).encode(),
    headers={'Content-Type':'application/json'}, method='POST'))
print(json.loads(r.read())['swarm_guid'])
PY
)

# ── Section 1: agent loading ────────────────────────────────────────

echo ""
echo "--- Section 1: v2 agents load ---"

LOADED=$(curl -fsS http://127.0.0.1:$PORT/api/swarm/$GUID/healthz \
    | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)["agents"]))')

assert_contains "EditorStripScaffolding loaded" "EditorStripScaffolding" "$LOADED"
assert_contains "EditorRestructure loaded"      "EditorRestructure"      "$LOADED"
assert_contains "EditorCutweak loaded"          "EditorCutweak"          "$LOADED"
assert_contains "EditorFactcheck loaded"        "EditorFactcheck"        "$LOADED"
assert_contains "EditorVoicecheck loaded"       "EditorVoicecheck"       "$LOADED"
assert_contains "Editor composite loaded"       "Editor"                  "$LOADED"

# ── Section 2: scaffolding stripper directly ────────────────────────

echo ""
echo "--- Section 2: strip_scaffolding agent works ---"

# Build a draft that has the exact failure mode from v1: a literal '## Outline'
# section at the top followed by a list, then the real content.
SCAFF_DRAFT='## Outline

- Setup the scene
- Introduce the bug
- Show the fix
- Discuss tradeoffs

# Real chapter title

The actual chapter prose starts here. There is a real point being made. The
prose is unrelated to the outline above.'

RESP=$(curl -fsS -X POST http://127.0.0.1:$PORT/api/swarm/$GUID/agent \
    -H 'Content-Type: application/json' \
    -d "$(python3 -c "import json,sys; print(json.dumps({'name':'EditorStripScaffolding','args':{'input':'''$SCAFF_DRAFT'''}}))")")
OUT=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("output",""))')

assert_not_contains "outline header stripped"      "## Outline"               "$OUT"
assert_not_contains "outline bullet stripped"      "- Setup the scene"        "$OUT"
assert_contains     "real H1 preserved"            "# Real chapter title"      "$OUT"
assert_contains     "real prose preserved"         "real point being made"     "$OUT"

# ── Section 3: cutweak preserves code blocks ─────────────────────────

echo ""
echo "--- Section 3: cutweak preserves fenced code ---"

CODE_DRAFT='# A real post

This paragraph is filler. It restates an obvious thing twice and adds no value
to the reader. A weak paragraph that the editor should cut.

```python
def critical_function():
    """This is the load-bearing code in the post."""
    return "do not cut me"
```

This paragraph has substance. It explains why the function above matters.
Without it the post would lose its main point.'

RESP=$(curl -fsS -X POST http://127.0.0.1:$PORT/api/swarm/$GUID/agent \
    -H 'Content-Type: application/json' \
    -d "$(python3 -c "import json,sys; print(json.dumps({'name':'EditorCutweak','args':{'input':'''$CODE_DRAFT'''}}))")")
OUT=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("output",""))')

assert_contains "code block fence preserved"        '```python'                "$OUT"
assert_contains "code function name preserved"      "critical_function"        "$OUT"
assert_contains "do-not-cut comment preserved"      "do not cut me"             "$OUT"
assert_contains "substantive paragraph preserved"   "explains why"              "$OUT"

# ── Section 4: full composite Editor runs all 5 specialists ──────────

echo ""
echo "--- Section 4: composite Editor runs all 5 specialists ---"

COMPOSITE_DRAFT='## Outline

- A
- B

# Test chapter

```python
SOUL = "preserve me"
```

This is the single substantive paragraph. It says something concrete about
the system. It says something concrete about the system, restated. It says
something concrete about the system, restated again.

A second paragraph that adds new information beyond the first.'

RESP=$(curl -fsS -X POST http://127.0.0.1:$PORT/api/swarm/$GUID/agent \
    -H 'Content-Type: application/json' \
    -d "$(python3 -c "import json,sys; print(json.dumps({'name':'Editor','args':{'input':'''$COMPOSITE_DRAFT'''}}))")")
OUT=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("output",""))')

assert_not_contains "composite stripped Outline"     "## Outline"               "$OUT"
assert_contains     "composite preserved code"       "SOUL"                      "$OUT"
assert_contains     "composite produced editor note" "Editor's note"             "$OUT"
assert_contains     "composite produced sourcing"    "Sourcing flags:"           "$OUT"
assert_contains     "composite produced voice check" "Voice drift:"              "$OUT"

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"
echo "  $PASS passed, $FAIL failed"
echo "════════════════════════════════════════"
[ $FAIL -gt 0 ] && { for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done; exit 1; }
exit 0
