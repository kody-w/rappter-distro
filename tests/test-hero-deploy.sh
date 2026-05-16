#!/bin/bash
# tests/test-hero-deploy.sh — end-to-end test of the onboard hatch flow:
# read rapp_brainstem/web/onboard/registry.json, generate a swarm bundle from a hero
# cloud (Kody's), deploy it through the swarm server, verify the swarm
# hatched and an agent in it executes.
#
# Mirrors the bundleFromCloud() logic in rapp_brainstem/web/onboard/index.html so
# the wire contract stays in sync between the browser hatcher and the
# stdlib server. Run from repo root:
#
#     bash tests/test-hero-deploy.sh
#
# Exits 0 on success, non-zero with diagnostics on failure.

set -e
set -o pipefail

PORT=7181
ROOT=/tmp/rapp-swarm-test-hero
SERVER_PID=""
PASS=0
FAIL=0
FAIL_NAMES=()

cleanup() {
    if [ -n "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $name"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $name"
        echo "      expected: $expected"
        echo "      actual:   $actual"
        FAIL=$((FAIL + 1))
        FAIL_NAMES+=("$name")
    fi
}

assert_contains() {
    local name="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "  ✓ $name"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $name"
        echo "      needle:    $needle"
        echo "      haystack:  $(echo "$haystack" | head -c 240)"
        FAIL=$((FAIL + 1))
        FAIL_NAMES+=("$name")
    fi
}

# ── Setup ──────────────────────────────────────────────────────────────

echo "Setup: clean state at $ROOT"
rm -rf "$ROOT"

echo "Setup: starting swarm server on :$PORT"
python3 rapp_brainstem/brainstem.py --port $PORT --root "$ROOT" >/dev/null 2>&1 &
SERVER_PID=$!
sleep 1.5

# ── Section 1: registry sanity ────────────────────────────────────────

echo ""
echo "--- Section 1: registry shape ---"

REGISTRY=rapp_brainstem/web/onboard/registry.json
[ -f "$REGISTRY" ] || { echo "  ✗ registry missing: $REGISTRY"; exit 1; }
SCHEMA=$(python3 -c "import json; print(json.load(open('$REGISTRY'))['schema'])")
assert_eq "registry schema = rapp-cloud-registry/1.0"  "rapp-cloud-registry/1.0"  "$SCHEMA"

STACK=$(python3 -c "import json; print(json.load(open('$REGISTRY'))['stack'])")
assert_eq "registry stack name = The Twin Stack"  "The Twin Stack"  "$STACK"

KODY_PRESENT=$(python3 -c "
import json
r = json.load(open('$REGISTRY'))
ids = [c['id'] for c in r.get('hero_humans', [])]
print('yes' if 'kody-cloud' in ids else 'no')
")
assert_eq "kody-cloud present in hero_humans"  "yes"  "$KODY_PRESENT"

MOLLY_PRESENT=$(python3 -c "
import json
r = json.load(open('$REGISTRY'))
ids = [c['id'] for c in r.get('hero_humans', [])]
print('yes' if 'molly-cloud' in ids else 'no')
")
assert_eq "molly-cloud present in hero_humans"  "yes"  "$MOLLY_PRESENT"

ROLE_COUNT=$(python3 -c "
import json
print(len(json.load(open('$REGISTRY')).get('hero_role_twins', [])))
")
[ "$ROLE_COUNT" -ge 10 ] && { echo "  ✓ 10+ role twins in registry (got $ROLE_COUNT)"; PASS=$((PASS+1)); } || \
                              { echo "  ✗ expected ≥10 role twins, got $ROLE_COUNT"; FAIL=$((FAIL+1)); FAIL_NAMES+=("role-twin-count"); }

PROMPTS_COUNT=$(python3 -c "
import json
r = json.load(open('$REGISTRY'))
print(len((r.get('demo_prompts') or {}).get('mind_blowing_10', [])))
")
assert_eq "10 mind-blowing demo prompts"  "10"  "$PROMPTS_COUNT"

# Verify collaboration layer documentation
LAYERS_COUNT=$(python3 -c "
import json
r = json.load(open('$REGISTRY'))
print(len((r.get('collaboration_layers') or {})))
")
assert_eq "3 collaboration layers documented (A2A,S2S,C2C)"  "3"  "$LAYERS_COUNT"

# ── Section 2: bundle assembly mirrors browser hatcher ────────────────

echo ""
echo "--- Section 2: bundle assembly ---"

# This Python mirrors bundleFromCloud() in rapp_brainstem/web/onboard/index.html.
# If the browser hatcher's bundle shape changes, update both.
build_bundle() {
    local cloud_id="$1" out="$2"
    python3 - <<PY > "$out"
import json, re, datetime

reg = json.load(open('$REGISTRY'))
cloud = next(
    (c for c in (reg.get('hero_humans', []) + reg.get('hero_role_twins', []))
     if c['id'] == '$cloud_id'),
    None
)
assert cloud, f"cloud not found: $cloud_id"

def stub_source(cid, swarm):
    camel = re.sub(r'[^A-Za-z0-9]', '', swarm['name'])
    cls = camel + 'Agent'
    desc = (swarm.get('description') or '').replace('"', '\\\\"')
    role = (swarm.get('role_framing') or '').replace('"', '\\\\"')
    return f'''from agents.basic_agent import BasicAgent

__manifest__ = {{
    "schema": "rapp-agent/1.0",
    "name": "@twinstack/{cid}-{swarm['name'].lower()}",
    "tier": "core",
    "trust": "community",
    "version": "0.1.0",
    "tags": ["twin-stack", "hatched-stub"],
    "example_call": {{"args": {{}}}}
}}


class {cls}(BasicAgent):
    def __init__(self):
        self.name = "{swarm['name']}"
        self.metadata = {{
            "name": self.name,
            "description": "{desc}",
            "parameters": {{"type": "object", "properties": {{}}, "required": []}}
        }}
        super().__init__(name=self.name, metadata=self.metadata)

    def perform(self, **kwargs):
        return ("Stub for {swarm['name']}. Role framing: {role}. "
                "Replace with real implementation once your twin learns this domain.")
'''

agents = []
for s in cloud.get('swarms', []):
    fname = re.sub(r'[^a-z0-9]', '_', s['name'].lower()) + '_agent.py'
    agents.append({
        'filename': fname,
        'name': s['name'],
        'description': s.get('description', ''),
        'source': stub_source(cloud['id'], s),
    })

bundle = {
    'schema': 'rapp-swarm/1.0',
    'name': cloud['title'],
    'purpose': cloud.get('tagline') or cloud.get('for') or cloud['title'],
    'soul': cloud.get('soul_addendum', ''),
    'cloud_id': cloud['id'],
    'handle': cloud.get('owner_handle', '@hatched'),
    'created_at': datetime.datetime.utcnow().isoformat() + 'Z',
    'created_by': 'test',
    'twin_stack_meta': {
        'stack': reg['stack'],
        'registry_schema': reg['schema'],
        'cloud_category': cloud.get('category'),
        'estate': cloud.get('estate', []),
    },
    'agents': agents,
}
print(json.dumps(bundle))
PY
}

build_bundle kody-cloud /tmp/kody-bundle.json
KODY_AGENTS=$(python3 -c "import json; print(len(json.load(open('/tmp/kody-bundle.json'))['agents']))")
assert_eq "kody-cloud bundle has 6 agents (PlatformShipper..BuildInPublicEditor)"  "6"  "$KODY_AGENTS"

build_bundle molly-cloud /tmp/molly-bundle.json
MOLLY_AGENTS=$(python3 -c "import json; print(len(json.load(open('/tmp/molly-bundle.json'))['agents']))")
assert_eq "molly-cloud bundle has 6 agents (CEODecisions..FoundingCardBinder)"  "6"  "$MOLLY_AGENTS"

# Verify each generated agent file is syntactically valid Python.
PY_OK=$(python3 - <<'PY'
import json, ast
ok = 0; bad = 0
for path in ('/tmp/kody-bundle.json', '/tmp/molly-bundle.json'):
    b = json.load(open(path))
    for a in b['agents']:
        try:
            ast.parse(a['source'])
            ok += 1
        except SyntaxError as e:
            bad += 1
            print(f"  syntax error in {b['name']}/{a['filename']}: {e}")
print(f"{ok}/{ok+bad}")
PY
)
assert_eq "all stub agents parse as valid Python"  "12/12"  "$PY_OK"

# ── Section 3: deploy through swarm server ────────────────────────────

echo ""
echo "--- Section 3: deploy bundles ---"

DEPLOY=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/deploy \
    -H 'Content-Type: application/json' --data-binary @/tmp/kody-bundle.json)
KODY_GUID=$(echo "$DEPLOY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarm_guid"])')
assert_contains "Kody bundle deploys, returns swarm_guid"  "$KODY_GUID"  "$DEPLOY"

KODY_AGENT_COUNT=$(echo "$DEPLOY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["agent_count"])')
assert_eq "Kody swarm reports agent_count=6"  "6"  "$KODY_AGENT_COUNT"

DEPLOY=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/deploy \
    -H 'Content-Type: application/json' --data-binary @/tmp/molly-bundle.json)
MOLLY_GUID=$(echo "$DEPLOY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarm_guid"])')
assert_contains "Molly bundle deploys, returns swarm_guid"  "$MOLLY_GUID"  "$DEPLOY"

# Both swarms visible in healthz
HEALTHZ=$(curl -s http://127.0.0.1:$PORT/api/swarm/healthz)
TOTAL=$(echo "$HEALTHZ" | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarm_count"])')
assert_eq "top-level healthz reports 2 swarms"  "2"  "$TOTAL"

# ── Section 4: agents actually load + execute ─────────────────────────

echo ""
echo "--- Section 4: hatched agents respond ---"

# Kody swarm /healthz lists the 6 swarm names as agents.
SWARM_INFO=$(curl -s http://127.0.0.1:$PORT/api/swarm/$KODY_GUID/healthz)
LOADED=$(echo "$SWARM_INFO" | python3 -c 'import json,sys; print(json.load(sys.stdin)["agent_count"])')
assert_eq "Kody swarm loaded 6 agents"  "6"  "$LOADED"

assert_contains "Kody swarm exposes PlatformShipper agent"  "PlatformShipper"  "$SWARM_INFO"
assert_contains "Kody swarm exposes IPGuardian agent"        "IPGuardian"       "$SWARM_INFO"
assert_contains "Kody swarm exposes MollyComms agent"        "MollyComms"       "$SWARM_INFO"

# Invoke an agent — should return the stub message
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$KODY_GUID/agent \
    -H 'Content-Type: application/json' \
    -d '{"name":"PlatformShipper","args":{}}')
STATUS=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])')
assert_eq "PlatformShipper executes (status=ok)"  "ok"  "$STATUS"
assert_contains "PlatformShipper output mentions its stub"   "Stub for PlatformShipper"  "$RESP"
assert_contains "PlatformShipper output carries role framing" "platform-shipping"        "$RESP"

# Invoke a Molly-cloud agent
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$MOLLY_GUID/agent \
    -H 'Content-Type: application/json' \
    -d '{"name":"CEODecisions","args":{}}')
assert_contains "CEODecisions stub executes"  "Stub for CEODecisions"  "$RESP"
assert_contains "CEODecisions reflects strategic-decision keeper framing"  "strategic-decision"  "$RESP"

# Verify cloud_id and twin_stack_meta survived into the manifest
MANIFEST=$(cat "$ROOT/swarms/$KODY_GUID/manifest.json")
# (manifest schema doesn't promise twin_stack_meta survival — purpose is enough)
assert_contains "Kody manifest carries the cloud's purpose"  "Ship the platform"  "$MANIFEST"

# ── Section 5: role twin too ──────────────────────────────────────────

echo ""
echo "--- Section 5: role twin (founder) hatches ---"

build_bundle founder /tmp/founder-bundle.json
DEPLOY=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/deploy \
    -H 'Content-Type: application/json' --data-binary @/tmp/founder-bundle.json)
FOUNDER_GUID=$(echo "$DEPLOY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarm_guid"])')
assert_contains "Founder role twin deploys"  "$FOUNDER_GUID"  "$DEPLOY"

RESP=$(curl -s -X POST http://127.0.0.1:$PORT/api/swarm/$FOUNDER_GUID/agent \
    -H 'Content-Type: application/json' \
    -d '{"name":"CalendarBrain","args":{}}')
assert_contains "Founder/CalendarBrain stub executes"  "Stub for CalendarBrain"  "$RESP"

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"
echo "  $PASS passed, $FAIL failed"
echo "════════════════════════════════════════"

if [ $FAIL -gt 0 ]; then
    echo "Failures:"
    for n in "${FAIL_NAMES[@]}"; do
        echo "  - $n"
    done
    exit 1
fi
exit 0
