#!/bin/bash
# tests/test-egg-2.0.sh — verify the brainstem-egg/2.0 cartridge system
# end-to-end: identity, pack, summon, assimilate.
#
# The egg is the local-first guarantee — the unit by which a digital
# organism becomes portable. RAPPID is the soul anchor that travels
# with every egg. This test exercises the full loop: a brainstem mints
# a twin RAPPID, packs itself as an egg, the egg gets imported via
# /agents/import auto-detect, and assimilated as a divergent version.
#
#     bash tests/test-egg-2.0.sh

set -e
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT=7290
TEST_HOME="/tmp/rapp-egg-test-$$"
SERVER_PID=""
PASS=0
FAIL=0
FAIL_NAMES=()

cleanup() {
    [ -n "$SERVER_PID" ] && kill $SERVER_PID 2>/dev/null || true
    rm -rf "$TEST_HOME"
    rm -f /tmp/egg-test.egg /tmp/egg-test-body.json /tmp/card_incant_agent.py.card
    rm -rf "$REPO_ROOT/rapp_brainstem/.brainstem_data/_versions"
    rm -f  "$REPO_ROOT/rapp_brainstem/.brainstem_data/identity.json"
    rm -f  "$REPO_ROOT/rapp_brainstem/.brainstem_data/stream.json"
    rm -f  "$REPO_ROOT/rapp_brainstem/.brainstem_data/frames.jsonl"
    rm -f  "$REPO_ROOT/rapp_brainstem/agents/card_incant_agent.py"
}
trap cleanup EXIT

assert_contains() {
    local name="$1" needle="$2" hay="$3"
    if echo "$hay" | grep -qF -- "$needle"; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name"; echo "      needle:    $needle"
        echo "      hay:       $(echo "$hay" | head -c 200)"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}
assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name"; echo "      expected: $expected"; echo "      actual:   $actual"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

mkdir -p "$TEST_HOME"
lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 0.3

PORT=$PORT python3 -u "$REPO_ROOT/rapp_brainstem/brainstem.py" > /tmp/egg-test-server.log 2>&1 &
SERVER_PID=$!
sleep 2.5

# ── Section 1: identity (RAPPID minting) ──────────────────────────────

echo ""
echo "--- Section 1: identity (RAPPID minting) ---"
ID=$(curl -sS http://127.0.0.1:$PORT/identity)
assert_contains "twin RAPPID present"             '"twin_rappid":'         "$ID"
assert_contains "twin RAPPID format = rappid:..." '"rappid:twin:'          "$ID"
assert_contains "twin RAPPID has @publisher"      '/personal:'             "$ID"
assert_contains "rapps namespace exists"          '"rapps":'               "$ID"

# Stable identity: a second call returns the SAME RAPPID
ID2=$(curl -sS http://127.0.0.1:$PORT/identity)
RID1=$(echo "$ID"  | python3 -c "import json,sys; print(json.load(sys.stdin)['twin_rappid'])")
RID2=$(echo "$ID2" | python3 -c "import json,sys; print(json.load(sys.stdin)['twin_rappid'])")
assert_eq "RAPPID is stable across calls" "$RID1" "$RID2"

# ── Section 2: export — twin egg ──────────────────────────────────────

echo ""
echo "--- Section 2: /rapps/export/twin ---"
curl -sS "http://127.0.0.1:$PORT/rapps/export/twin?id=test_twin" -o /tmp/egg-test.egg
SIZE=$(wc -c < /tmp/egg-test.egg)
if [ "$SIZE" -gt 1000 ]; then
    echo "  ✓ twin egg downloaded ($SIZE bytes)"; PASS=$((PASS + 1))
else
    echo "  ✗ twin egg too small ($SIZE bytes)"; FAIL=$((FAIL + 1)); FAIL_NAMES+=("twin egg size")
fi

# Verify it's a valid zip with manifest.json
unzip -p /tmp/egg-test.egg manifest.json > /tmp/egg-test-manifest.json
MANIFEST=$(cat /tmp/egg-test-manifest.json)
assert_contains "manifest schema = brainstem-egg/2.0" '"schema": "brainstem-egg/2.0"' "$MANIFEST"
assert_contains "manifest type = twin"                '"type": "twin"'                "$MANIFEST"
assert_contains "manifest carries RAPPID"             "$RID1"                          "$MANIFEST"
assert_contains "manifest has lineage block"          '"lineage":'                     "$MANIFEST"
assert_contains "lineage tracks incarnations"         '"incarnations":'                "$MANIFEST"

# ── Section 3: import via /agents/import auto-detect ──────────────────

echo ""
echo "--- Section 3: /agents/import egg auto-detect ---"
IMPORT=$(curl -sS -X POST http://127.0.0.1:$PORT/agents/import \
  -F "file=@/tmp/egg-test.egg;filename=test_twin.egg;type=application/zip")
# jsonify emits compact JSON ("kind":"egg") — needle is space-flexible
assert_contains "egg auto-detected"   '"kind":"egg"'    "$IMPORT"
assert_contains "egg type = twin"     '"type":"twin"'   "$IMPORT"
assert_contains "import status ok"    '"status":"ok"'   "$IMPORT"

# ── Section 4: /eggs/assimilate stages a divergent version ────────────

echo ""
echo "--- Section 4: /eggs/assimilate (dreamcatcher seam) ---"
python3 -c "
import json, base64
blob = open('/tmp/egg-test.egg','rb').read()
open('/tmp/egg-test-body.json','w').write(json.dumps({'egg_b64': base64.b64encode(blob).decode()}))
"
ASSIM=$(curl -sS -X POST http://127.0.0.1:$PORT/eggs/assimilate \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/egg-test-body.json)
assert_contains "assimilate ok"               '"ok":true'              "$ASSIM"
assert_contains "merge_kind = same-twin"      '"merge_kind":"same-twin"' "$ASSIM"
assert_contains "source/target RAPPIDs match" "$RID1"                    "$ASSIM"
assert_contains "version staged under _versions/" '_versions/'           "$ASSIM"

# ── Section 5: /eggs/summon (URL-based) — fault tolerance ────────────

echo ""
echo "--- Section 5: /eggs/summon validation ---"
SUMMON_BAD=$(curl -sS -X POST http://127.0.0.1:$PORT/eggs/summon \
  -H "Content-Type: application/json" -d '{}' || echo "{}")
assert_contains "summon requires url"   '"url is required"'   "$SUMMON_BAD"

SUMMON_NONHTTP=$(curl -sS -X POST http://127.0.0.1:$PORT/eggs/summon \
  -H "Content-Type: application/json" -d '{"url":"file:///etc/passwd"}' || echo "{}")
assert_contains "summon rejects non-http" '"url must be http(s)"'  "$SUMMON_NONHTTP"

# ── Section 6: snapshot egg ────────────────────────────────────────────

echo ""
echo "--- Section 6: /rapps/export/snapshot ---"
curl -sS "http://127.0.0.1:$PORT/rapps/export/snapshot?id=test_snap" -o /tmp/egg-snap.egg
SSIZE=$(wc -c < /tmp/egg-snap.egg)
if [ "$SSIZE" -gt 1000 ]; then
    echo "  ✓ snapshot egg downloaded ($SSIZE bytes)"; PASS=$((PASS + 1))
else
    echo "  ✗ snapshot egg too small ($SSIZE bytes)"; FAIL=$((FAIL + 1)); FAIL_NAMES+=("snapshot egg size")
fi

unzip -p /tmp/egg-snap.egg manifest.json > /tmp/snap-manifest.json
SMANIFEST=$(cat /tmp/snap-manifest.json)
assert_contains "snapshot schema = brainstem-egg/2.0" '"schema": "brainstem-egg/2.0"' "$SMANIFEST"
assert_contains "snapshot type = snapshot"            '"type": "snapshot"'            "$SMANIFEST"
assert_contains "snapshot has agent_count"            '"agent_count":'                "$SMANIFEST"
assert_contains "snapshot has service_count"          '"service_count":'              "$SMANIFEST"
rm -f /tmp/egg-snap.egg /tmp/snap-manifest.json /tmp/egg-test-manifest.json

# ── Summary ────────────────────────────────────────────────────────────

# ── Section 7: frames + twin manifest + card incantation ──────────────

echo ""
echo "--- Section 7: frame log + twin manifest ---"
MANIFEST=$(curl -sS "http://127.0.0.1:$PORT/twin/manifest")
assert_contains "twin manifest schema"        '"schema":"twin-manifest/1.0"' "$MANIFEST"
assert_contains "twin manifest has rappid"    '"twin_rappid":"rappid:'        "$MANIFEST"
assert_contains "twin manifest has stream_id" '"stream_id":"stream-'          "$MANIFEST"
assert_contains "twin manifest has frames"    '"frames":'                     "$MANIFEST"
assert_contains "twin manifest has agents"    '"agent_names":'                "$MANIFEST"

FRAMES=$(curl -sS "http://127.0.0.1:$PORT/frames/recent?limit=10")
assert_contains "frames endpoint responds"    '"frames":'                     "$FRAMES"
assert_contains "frames stream summary"       '"stream":'                     "$FRAMES"

# ── Section 8: card incantation — drop a .py.card with __card__.summon ─

echo ""
echo "--- Section 8: card incantation ---"
# Build a tiny .py.card that points at our existing test egg URL
TEST_EGG_URL="file:///tmp/egg-test.egg"  # file:// won't work, use http via local server
# Use the brainstem's own egg-export endpoint as the summon source
cat > /tmp/card_incant_agent.py.card <<EOF
"""card_incant_agent — minimal card for incantation test."""

__manifest__ = {
    "schema": "rapp-agent/1.0",
    "name": "@test/card_incant",
    "version": "1.0.0",
    "display_name": "CardIncant",
    "description": "Card incantation test fixture.",
    "author": "test",
    "tags": ["test"],
    "category": "general",
    "quality_tier": "experimental",
    "requires_env": [],
    "dependencies": [],
}

__card__ = {
    "name": "CardIncant",
    "summon": "http://127.0.0.1:$PORT/rapps/export/twin?id=card_summon_test",
}

class CardIncantAgent:
    def perform(self, **kw):
        return "ok"
EOF

INCANT=$(curl -sS -X POST http://127.0.0.1:$PORT/agents/import \
  -F "file=@/tmp/card_incant_agent.py.card;filename=card_incant_agent.py.card;type=text/x-python")
assert_contains "card incantation triggered" '"kind":"card-incantation"' "$INCANT"
assert_contains "incantation summoned twin"  '"summoned":'               "$INCANT"
rm -f /tmp/card_incant_agent.py.card

echo ""
echo "─────────────────────────────────────────────────────"
echo "Tests: $((PASS + FAIL)) | Pass: $PASS | Fail: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "Failed:"
    for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done
    exit 1
fi
echo "✓ Egg cartridge system is whole."
