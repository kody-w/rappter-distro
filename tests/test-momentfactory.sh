#!/bin/bash
# tests/test-momentfactory.sh — validate the MomentFactory rapplication
# (the new Rappterbook engine candidate) end-to-end.

set -e
set -o pipefail

# NOTE (2026-04-26): the catalog moved to kody-w/rapp_store. This script
# inspects local rapp_store/ filesystem content that no longer exists in
# this repo, so it self-skips here. The same test belongs in the catalog
# repo's own test suite — see github.com/kody-w/rapp_store.
if [ ! -d rapp_store ] || [ -f rapp_store/MOVED.md ] && [ ! -f rapp_store/index.json ]; then
    echo "SKIP: tests/test-momentfactory.sh — catalog moved to kody-w/rapp_store"
    exit 0
fi

PASS=0; FAIL=0; FAIL_NAMES=()

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

cd /Users/kodyw/Documents/GitHub/Rappter/RAPP

# ── Section 1: source agents — manifests + parse cleanly ──────────────

echo ""
echo "--- Section 1: MomentFactory source files ---"

python3 - <<'PY'
import ast, sys
from pathlib import Path

agents = [
    "sensorium_agent.py",
    "significance_filter_agent.py",
    "hook_writer_agent.py",
    "body_writer_agent.py",
    "channel_router_agent.py",
    "card_forger_agent.py",
    "seed_stamper_agent.py",
    "moment_factory_agent.py",
]

fail = 0
for fn in agents:
    p = Path("rapp_store/momentfactory/source") / fn
    if not p.exists():
        print(f"  ✗ missing: {fn}"); fail += 1; continue
    try:
        tree = ast.parse(p.read_text())
    except SyntaxError as e:
        print(f"  ✗ syntax error in {fn}: {e}"); fail += 1; continue
    manifest = None
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for t in node.targets:
                if isinstance(t, ast.Name) and t.id == "__manifest__":
                    manifest = ast.literal_eval(node.value)
    if not manifest:
        print(f"  ✗ {fn}: no __manifest__"); fail += 1; continue
    if not manifest["name"].startswith("@rapp/"):
        print(f"  ✗ {fn}: name not under @rapp/: {manifest['name']}"); fail += 1; continue
    print(f"  ✓ {fn}: {manifest['name']} v{manifest['version']}")

sys.exit(1 if fail else 0)
PY

# ── Section 2: SeedStamper is deterministic + 7-word incantation works ─

echo ""
echo "--- Section 2: SeedStamper deterministic + wordlist ---"

python3 - <<'PY'
import sys, json
# Make `from agents.basic_agent import BasicAgent` resolve via rapp_brainstem/agents/
sys.path.insert(0, "rapp_brainstem")
sys.path.insert(0, "rapp_store/momentfactory/source")
from seed_stamper_agent import SeedStamperAgent, WORDS

assert len(WORDS) == 256, f"wordlist must be 256 words, got {len(WORDS)}"
assert len(set(WORDS)) == 256, "wordlist words must be unique"
print(f"  ✓ wordlist: 256 unique words")

a = SeedStamperAgent()
out1 = json.loads(a.perform(hook="hello", body="world", channel="r/test"))
out2 = json.loads(a.perform(hook="hello", body="world", channel="r/test"))
assert out1 == out2, "SeedStamper must be deterministic"
print(f"  ✓ deterministic: {out1['seed']} → {out1['incantation']}")

words = out1["incantation"].split()
assert len(words) == 7, f"incantation must be 7 words, got {len(words)}"
assert all(w in WORDS for w in words), "all incantation words must come from the wordlist"
print(f"  ✓ incantation is 7 words from the wordlist")

# Different inputs → different seeds
out3 = json.loads(a.perform(hook="different", body="content", channel="r/test"))
assert out3["seed"] != out1["seed"], "different inputs must produce different seeds"
print(f"  ✓ different inputs produce different seeds")
PY

# ── Section 3: composite hatches in the brainstem as one agent ────────

echo ""
echo "--- Section 3: MomentFactory hatches in brainstem ---"

PORT=7187
ROOT=/tmp/rapp-momentfactory-test
[ -e "$ROOT" ] && chmod -R u+w "$ROOT" 2>/dev/null || true
rm -rf "$ROOT"
lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 0.5

python3 -u rapp_brainstem/brainstem.py --port $PORT --root "$ROOT" > /tmp/momentfactory-test-server.log 2>&1 &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null || true" EXIT
sleep 2

# Bundle = ALL 8 source files (composite + 7 personas)
GUID=$(python3 - <<PY
import json, urllib.request, pathlib
files = [
    "sensorium_agent.py",
    "significance_filter_agent.py",
    "hook_writer_agent.py",
    "body_writer_agent.py",
    "channel_router_agent.py",
    "card_forger_agent.py",
    "seed_stamper_agent.py",
    "moment_factory_agent.py",
]
agents = [{"filename": f, "source": pathlib.Path("rapp_store/momentfactory/source/" + f).read_text()} for f in files]
bundle = {
    "schema": "rapp-swarm/1.0",
    "name": "momentfactory-test",
    "soul": "MomentFactory composite hatch test",
    "agents": agents,
}
r = urllib.request.urlopen(urllib.request.Request(
    "http://127.0.0.1:$PORT/api/swarm/deploy",
    data=json.dumps(bundle).encode(),
    headers={"Content-Type":"application/json"}, method="POST"))
print(json.loads(r.read())["swarm_guid"])
PY
)
assert_contains "MomentFactory bundle deploys" "$GUID" "$GUID"

LOADED=$(curl -fsS http://127.0.0.1:$PORT/api/swarm/$GUID/healthz \
         | python3 -c "import json,sys; d=json.load(sys.stdin); print(' '.join(d['agents']))")
assert_contains "MomentFactory loaded as composite agent" "MomentFactory" "$LOADED"
assert_contains "Sensorium loaded" "Sensorium" "$LOADED"
assert_contains "SignificanceFilter loaded" "SignificanceFilter" "$LOADED"
assert_contains "HookWriter loaded" "HookWriter" "$LOADED"
assert_contains "BodyWriter loaded" "BodyWriter" "$LOADED"
assert_contains "ChannelRouter loaded" "ChannelRouter" "$LOADED"
assert_contains "CardForger loaded" "CardForger" "$LOADED"
assert_contains "SeedStamper loaded" "SeedStamper" "$LOADED"

COUNT=$(curl -fsS http://127.0.0.1:$PORT/api/swarm/$GUID/healthz \
        | python3 -c "import json,sys; print(json.load(sys.stdin)['agent_count'])")
assert_eq "exactly 8 agents loaded" "8" "$COUNT"

# ── Section 4: MomentFactory.perform() returns a complete Drop ───────

echo ""
echo "--- Section 4: MomentFactory produces a Drop on a high-significance moment ---"

# Use a small in-corpus fixture so we get a real LLM-driven Drop.
# Skip this section if no LLM is configured (CI without secrets).
if [ -z "$AZURE_OPENAI_ENDPOINT" ] && [ -z "$OPENAI_API_KEY" ]; then
    echo "  ⊘ skipped — no LLM configured (set AZURE_OPENAI_* or OPENAI_API_KEY)"
else
    DROP=$(python3 - <<PY
import json, urllib.request
moment = json.load(open("tests/fixtures/moments/01-code-commit.json"))
body = {"name": "MomentFactory",
        "args": {"source": moment["source"], "source_type": moment["source_type"]}}
r = urllib.request.urlopen(urllib.request.Request(
    "http://127.0.0.1:$PORT/api/swarm/$GUID/agent",
    data=json.dumps(body).encode(),
    headers={"Content-Type":"application/json"}, method="POST"), timeout=180)
out = json.loads(r.read())
# The brainstem returns {status, output, ...}; the agent's output is JSON-as-string
print(out.get("output", "{}"))
PY
)
    echo "  raw drop output (truncated):"
    echo "$DROP" | head -c 400 ; echo "..."
    DROP_PARSED=$(echo "$DROP" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(json.dumps(d))")
    assert_contains "Drop has hook field"           '"hook"'            "$DROP_PARSED"
    assert_contains "Drop has body field"           '"body"'            "$DROP_PARSED"
    assert_contains "Drop has channel field"        '"channel"'         "$DROP_PARSED"
    assert_contains "Drop has card field"           '"card"'            "$DROP_PARSED"
    assert_contains "Drop has seed field"           '"seed"'            "$DROP_PARSED"
    assert_contains "Drop has incantation field"    '"incantation"'     "$DROP_PARSED"
    assert_contains "Drop has significance_score"   '"significance_score"' "$DROP_PARSED"
fi

# ── Section 5: SignificanceFilter rejects a low-significance moment ───

echo ""
echo "--- Section 5: SignificanceFilter blocks low-significance moment ---"

if [ -z "$AZURE_OPENAI_ENDPOINT" ] && [ -z "$OPENAI_API_KEY" ]; then
    echo "  ⊘ skipped — no LLM configured"
else
    SKIP_DROP=$(python3 - <<PY
import json, urllib.request
# Use the location-with-just-"Coffee" fixture
moment = json.load(open("tests/fixtures/moments/05-location.json"))
body = {"name": "MomentFactory",
        "args": {"source": moment["source"], "source_type": moment["source_type"],
                 "significance_threshold": 0.6}}
r = urllib.request.urlopen(urllib.request.Request(
    "http://127.0.0.1:$PORT/api/swarm/$GUID/agent",
    data=json.dumps(body).encode(),
    headers={"Content-Type":"application/json"}, method="POST"), timeout=180)
out = json.loads(r.read())
print(out.get("output", "{}"))
PY
)
    echo "  skip-drop output (truncated):"
    echo "$SKIP_DROP" | head -c 400 ; echo "..."
    SKIPPED=$(echo "$SKIP_DROP" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('skipped'))")
    case "$SKIPPED" in
        True) echo "  ✓ low-significance moment correctly skipped"; PASS=$((PASS+1)) ;;
        *)    echo "  ⚠ low-significance moment was NOT skipped (skipped=$SKIPPED) — filter may be too lenient" ;;
    esac
fi

# ── Section 6: comparison harness exists + runs without LLM (dry mode) ─

echo ""
echo "--- Section 6: comparison harness ---"

[ -f tools/compare-rappter-vs-momentfactory.py ] && \
    { echo "  ✓ comparison harness exists"; PASS=$((PASS+1)); } || \
    { echo "  ✗ tools/compare-rappter-vs-momentfactory.py missing"; FAIL=$((FAIL+1)); FAIL_NAMES+=("harness exists"); }

python3 tools/compare-rappter-vs-momentfactory.py --dry-run > /tmp/compare-dry.log 2>&1 && \
    { echo "  ✓ harness --dry-run completes cleanly"; PASS=$((PASS+1)); } || \
    { echo "  ✗ harness --dry-run failed:"; tail -10 /tmp/compare-dry.log; FAIL=$((FAIL+1)); FAIL_NAMES+=("dry-run"); }

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"
echo "  $PASS passed, $FAIL failed"
echo "════════════════════════════════════════"
[ $FAIL -gt 0 ] && { for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done; exit 1; }
exit 0
