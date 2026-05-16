#!/usr/bin/env bash
# Scenario 24 — vbrainstem (browser-side brainstem).
#
# Verifies the page is structurally complete + the JS class API is
# exposed on the page. Runtime UI behavior + GitHub OAuth flow are not
# scriptable from bash without a browser, so this scenario asserts the
# CONTRACT (file present, correct selectors, correct method names, the
# right LS keys, the right API endpoints referenced) and a Node-based
# JS evaluation of the VBrainstem class methods on a stubbed environment.

source "$(dirname "$0")/_lib.sh"
scenario_parse_args "$@"

heading "Scenario 24 — vbrainstem"
note "Pattern: browser-based brainstem; no Python install for collaboration"
note "Showcases: mobile users authenticate + join + federate from any browser"

PAGE="$REPO_ROOT/pages/vbrainstem/index.html"

# 1. Page exists + valid HTML structure
heading "Step 1 — Page present + structure valid"
if [ ! -f "$PAGE" ]; then step_fail "vbrainstem page missing"; scenario_summary; fi
step_pass "page present"

if grep -q '<meta name="viewport"' "$PAGE" && grep -q 'theme-color' "$PAGE"; then
  step_pass "mobile viewport + theme-color set"
else
  step_fail "mobile meta tags missing"
fi

# 2. Auth wires to existing rapp-auth worker
heading "Step 2 — Reuses existing auth worker (no new infra)"
if grep -q "rapp-auth.kwildfeuer.workers.dev" "$PAGE"; then
  step_pass "AUTH_WORKER_URL points at existing worker"
else
  step_fail "auth worker URL missing or different"
fi
for endpoint in "/api/auth/device" "/api/auth/device/poll"; do
  if grep -q "$endpoint" "$PAGE"; then
    step_pass "device-code endpoint $endpoint referenced"
  else
    step_fail "endpoint $endpoint missing"
  fi
done

# 3. localStorage keys are namespaced
heading "Step 3 — localStorage keys are namespaced (vbs_*)"
for key in "vbs_rappid" "vbs_token" "vbs_login" "vbs_subscriptions"; do
  if grep -q "$key" "$PAGE"; then
    step_pass "uses LS key: $key"
  else
    step_fail "missing LS key: $key"
  fi
done

# 4. VBrainstem class exposes the documented API
heading "Step 4 — VBrainstem class API"
for fn in "_mintRappid" "saveToken" "signOut" "startDeviceFlow" "pollDeviceFlow" "whoAmI" "_slugFromUrl" "fetchNeighborhood" "verifyMembership" "join" "list" "leave" "estate" "byRappid" "contribute"; do
  if grep -qE "(^|\s|\.)${fn}\s*\(" "$PAGE"; then
    step_pass "exposes $fn()"
  else
    step_fail "missing method: $fn"
  fi
done

# 5. Federation: contribute() POSTs to the GitHub Issues comments endpoint
heading "Step 5 — Federation primitive (real GitHub API)"
if grep -q "/issues/.*comments\b\|/issues/' + issueNumber + '/comments" "$PAGE" || grep -q '/issues/" + issueNumber + "/comments' "$PAGE"; then
  step_pass "contribute() posts to /repos/<o>/<r>/issues/<n>/comments"
else
  step_fail "contribute path not wired to issues/comments"
fi

# 6. UI tabs present
heading "Step 6 — All four tabs in UI"
for tab in "auth" "subs" "estate" "lookup"; do
  if grep -q "data-tab=\"$tab\"" "$PAGE"; then
    step_pass "tab $tab present"
  else
    step_fail "missing tab: $tab"
  fi
done

# 7. Both sign-in methods (device-code + paste-token)
heading "Step 7 — Two sign-in methods"
if grep -q "btn-device-flow" "$PAGE"; then step_pass "device-code button present"; else step_fail "device-code missing"; fi
if grep -q "btn-paste-token" "$PAGE"; then step_pass "paste-token button present"; else step_fail "paste-token missing"; fi

# 8. Linked from metropolis directory? (optional but good)
heading "Step 8 — Discoverability from metropolis"
METRO="$REPO_ROOT/pages/metropolis/index.html"
if grep -q "vbrainstem" "$METRO"; then
  step_pass "metropolis directory links to vbrainstem"
else
  step_skip "vbrainstem link from metropolis (will be added in same commit)"
fi

# 9. JS class instantiable in a stubbed Node environment (logic-only)
heading "Step 9 — VBrainstem class logic exercises in Node"
TEST_JS="$(mktemp -t vbs-test-XXXXXX).js"
cat > "$TEST_JS" <<'JS'
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const m = html.match(/<script>([\s\S]*?)<\/script>/);
if (!m) { console.log("FAIL: no script block"); process.exit(1); }
let script = m[1];

global.window = {};
global.document = {
  getElementById: () => ({
    classList: { add: () => {}, remove: () => {}, toggle: () => {} },
    addEventListener: () => {},
    querySelectorAll: () => [],
    textContent: "", innerHTML: "", style: {}, href: "", value: "",
  }),
  querySelectorAll: () => [],
};
const _store = {};
global.localStorage = {
  getItem: (k) => Object.prototype.hasOwnProperty.call(_store, k) ? _store[k] : null,
  setItem: (k, v) => { _store[k] = String(v); },
  removeItem: (k) => { delete _store[k]; },
};
global.crypto = {
  randomUUID: () => "00000000-1111-2222-3333-444444444444",
  getRandomValues: (a) => { for (let i = 0; i < a.length; i++) a[i] = i; return a; },
};
global.fetch = async () => ({ ok: false, status: 0 });
global.atob = (s) => Buffer.from(s, "base64").toString("utf8");

try {
  new Function(script)();
  // The IIFE assigns its instance to window.vbs — reach the class via that.
  const vbsInstance = global.window && global.window.vbs;
  if (!vbsInstance) { console.log("FAIL: window.vbs not exposed"); process.exit(1); }
  const VBrainstemForTest = vbsInstance.constructor;
  if (!VBrainstemForTest) { console.log("FAIL: class not reachable from instance"); process.exit(1); }
  const v = new VBrainstemForTest();
  if (!v.rappid || v.rappid.length < 8) { console.log("FAIL: rappid not minted"); process.exit(1); }
  if (!Array.isArray(v.subs) || v.subs.length !== 0) { console.log("FAIL: subs not empty array"); process.exit(1); }
  const est = v.estate();
  if (est.subscription_count !== 0) { console.log("FAIL: estate count"); process.exit(1); }
  if (est.bridges.length !== 0) { console.log("FAIL: estate bridges"); process.exit(1); }
  const lookup = v.byRappid("anything");
  if (lookup.appears_in_count !== 0) { console.log("FAIL: byRappid empty"); process.exit(1); }
  v.signOut();
  if (v.token !== null) { console.log("FAIL: signOut"); process.exit(1); }
  const s = v._slugFromUrl("https://github.com/kody-w/microsoft-se-team-neighborhood");
  if (s !== "kody-w/microsoft-se-team-neighborhood") { console.log("FAIL: slug parse: " + s); process.exit(1); }
  console.log("OK");
} catch (e) {
  console.log("FAIL: " + e.message);
  process.exit(1);
}
JS
NODE_CHECK=$(node "$TEST_JS" "$PAGE" 2>&1)
rm -f "$TEST_JS"
if [ "$NODE_CHECK" = "OK" ]; then
  step_pass "VBrainstem class: identity + estate + signOut + slug parse all work"
else
  step_fail "Node-side check: $NODE_CHECK"
fi

heading "Why this matters"
cat <<'EOF'
  vbrainstem is the browser-side brainstem — same membership protocol,
  no Python install. Mobile users open the page, sign in with GitHub
  device-code (or paste a PAT), join neighborhoods, see their estate,
  look up rappids, and post contributions to braintrusts via real
  GitHub Issue comments. The trust anchor is the same gh auth token;
  the federation primitive is the same /repos/.../issues/<n>/comments.
  No central infra. No new identity layer. The platform's substrate
  scales to the browser without compromise.
EOF

scenario_summary
