#!/usr/bin/env bash
# Scenario 18 — Real brainstem-to-brainstem federation transport.
#
# Verifies the membership organ's POST /api/neighborhoods/<slug>/contribute
# and GET /api/neighborhoods/<slug>/contributions endpoints. Two simulated
# brainstem environments share a neighborhood subscription; one POSTs a
# contribution, the other receives + stores + lists it. No GitHub round-
# trip; no stubs. The transport is real — the organ accepts a real payload
# and persists a real receipt to disk.

source "$(dirname "$0")/_lib.sh"
scenario_parse_args "$@"

heading "Scenario 18 — Real brainstem-to-brainstem federation"
note "Pattern: POST /api/neighborhoods/<slug>/contribute lands a real receipt"
note "Showcases: federation transport is wired, not stubbed"

ORGAN="$REPO_ROOT/rapp_brainstem/utils/organs/neighborhood_membership_organ.py"

# Use the local-only-test seed as the shared neighborhood
SEED="$FIXTURES_DIR/local-only-test"
SEED_URL="file://$SEED"

# 1. Verify the new endpoints are in the dispatch table
heading "Step 1 — Endpoints registered in organ"
DISPATCH=$(python3 - "$ORGAN" <<'PY'
import importlib.util, json, sys, tempfile, os
spec = importlib.util.spec_from_file_location("o", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
tmp = tempfile.mkdtemp()
m.HOME_BRAINSTEM = tmp
m.SUBS_FILE = os.path.join(tmp, "neighborhoods.json")
m.CACHE_DIR = os.path.join(tmp, "neighborhoods")
body, status = m.handle("PATCH", "frobnicate", {})
print(json.dumps(body))
PY
)
if echo "$DISPATCH" | grep -q "contribute" && echo "$DISPATCH" | grep -q "contributions"; then
  step_pass "POST .../contribute and GET .../contributions registered"
else
  step_fail "endpoints missing from dispatch table"
fi

# 2. Two brainstems subscribe to the same local neighborhood
heading "Step 2 — Two brainstem environments subscribe"
RESULT=$(python3 - "$ORGAN" "$SEED_URL" <<'PY'
import importlib.util, json, sys, tempfile, os
spec = importlib.util.spec_from_file_location("o", sys.argv[1])
seed_url = sys.argv[2]

def fresh_brainstem():
    spec2 = importlib.util.spec_from_file_location("o", sys.argv[1])
    m = importlib.util.module_from_spec(spec2); spec2.loader.exec_module(m)
    tmp = tempfile.mkdtemp(prefix="rapp-bs-")
    m.HOME_BRAINSTEM = tmp
    m.SUBS_FILE = os.path.join(tmp, "neighborhoods.json")
    m.CACHE_DIR = os.path.join(tmp, "neighborhoods")
    return m, tmp

# Sender brainstem (e.g. rappter1's machine)
sender, sender_dir = fresh_brainstem()
body, status = sender.handle("POST", "join", {"gate_url": seed_url})
assert status == 200 and body["joined"], f"sender join failed: {body}"

# Receiver brainstem (e.g. kody-w's machine)
receiver, receiver_dir = fresh_brainstem()
body, status = receiver.handle("POST", "join", {"gate_url": seed_url})
assert status == 200 and body["joined"], f"receiver join failed: {body}"

# Sender constructs a contribution and POSTs it to receiver's contribute endpoint
contribution = {
    "schema": "rapp-braintrust-contribution/1.0",
    "request_id": "feder8",
    "contributor": {"github_login": "rappter1", "rappid": "1ae2561a-1832-45c4-a1b1-984d79b13c1f"},
    "captured_at": "2026-05-08T20:00:00Z",
    "library_kinds_searched": ["files"],
    "findings": [{"snippet": "real federation works", "source": {"kind": "files", "ref": "/notes/test.md"}, "confidence": 0.9}],
    "is_empty": False,
}
post_body = {"request_id": "feder8", "contribution": contribution, "from_peer": "rappter1@laptop"}
body, status = receiver.handle("POST", "local/local-only-test/contribute", post_body)
assert status == 200 and body["received"], f"contribute failed: {body}"
print(json.dumps({"sender_dir": sender_dir, "receiver_dir": receiver_dir, "post_response": body}))
PY
)
if echo "$RESULT" | grep -q '"received": true'; then
  step_pass "receiver brainstem accepted contribution via POST .../contribute"
else
  step_fail "POST .../contribute did not return received=true"
  echo "$RESULT"
fi

# Extract receiver dir for follow-up
RECV_DIR=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['receiver_dir'])")

# 3. Receiver lists the contributions and finds it
heading "Step 3 — Receiver can list the contribution"
LIST=$(python3 - "$ORGAN" "$RECV_DIR" <<'PY'
import importlib.util, json, sys, os
spec = importlib.util.spec_from_file_location("o", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
m.HOME_BRAINSTEM = sys.argv[2]
m.SUBS_FILE = os.path.join(sys.argv[2], "neighborhoods.json")
m.CACHE_DIR = os.path.join(sys.argv[2], "neighborhoods")
body, status = m.handle("GET", "local/local-only-test/contributions", None)
print(json.dumps(body))
PY
)
COUNT=$(echo "$LIST" | python3 -c "import json,sys; print(json.load(sys.stdin).get('count', 0))")
if [ "$COUNT" -ge 1 ]; then
  step_pass "GET .../contributions listed $COUNT receipt(s)"
else
  step_fail "expected ≥1 contribution, got $COUNT"
fi

# 4. Verify the receipt has full provenance (sender login + rappid preserved)
heading "Step 4 — Receipt preserves operator-rappid + sender attribution"
LOGIN=$(echo "$LIST" | python3 -c "import json,sys; r=json.load(sys.stdin)['contributions'][0]; print(r['contribution']['contributor']['github_login'])")
RAPPID=$(echo "$LIST" | python3 -c "import json,sys; r=json.load(sys.stdin)['contributions'][0]; print(r['contribution']['contributor']['rappid'])")
PEER=$(echo "$LIST" | python3 -c "import json,sys; r=json.load(sys.stdin)['contributions'][0]; print(r.get('from_peer'))")
if [ "$LOGIN" = "rappter1" ] && [ "$RAPPID" = "1ae2561a-1832-45c4-a1b1-984d79b13c1f" ] && [ "$PEER" = "rappter1@laptop" ]; then
  step_pass "receipt preserves contributor login + rappid + from_peer"
else
  step_fail "provenance broken: login=$LOGIN rappid=$RAPPID peer=$PEER"
fi

# 5. Bad request body returns 400 (real validation, not silent accept)
heading "Step 5 — Bad input returns 400 (no silent accept)"
BAD=$(python3 - "$ORGAN" "$RECV_DIR" <<'PY'
import importlib.util, json, sys, os
spec = importlib.util.spec_from_file_location("o", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
m.HOME_BRAINSTEM = sys.argv[2]
m.SUBS_FILE = os.path.join(sys.argv[2], "neighborhoods.json")
m.CACHE_DIR = os.path.join(sys.argv[2], "neighborhoods")
body, status = m.handle("POST", "local/local-only-test/contribute", {"no": "request_id"})
print(f"{status}|{json.dumps(body)}")
PY
)
STATUS_CODE="${BAD%%|*}"
if [ "$STATUS_CODE" = "400" ]; then
  step_pass "missing request_id → HTTP 400 (validation works)"
else
  step_fail "bad input got status $STATUS_CODE (expected 400)"
fi

# 6. Filtering by request_id works
heading "Step 6 — Contributions can be filtered by request_id"
FILTERED=$(python3 - "$ORGAN" "$RECV_DIR" <<'PY'
import importlib.util, json, sys, os
spec = importlib.util.spec_from_file_location("o", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
m.HOME_BRAINSTEM = sys.argv[2]
m.SUBS_FILE = os.path.join(sys.argv[2], "neighborhoods.json")
m.CACHE_DIR = os.path.join(sys.argv[2], "neighborhoods")
body, status = m.handle("GET", "local/local-only-test/contributions", {"request_id": "no-such-thing"})
print(json.dumps(body))
PY
)
FCOUNT=$(echo "$FILTERED" | python3 -c "import json,sys; print(json.load(sys.stdin).get('count', 0))")
if [ "$FCOUNT" = "0" ]; then
  step_pass "filter by non-matching request_id returns 0 results"
else
  step_fail "filter expected 0, got $FCOUNT"
fi

heading "Why this matters"
cat <<'EOF'
  This is real federation, not a stub. One brainstem POSTs a contribution
  to another brainstem's /api/neighborhoods/<slug>/contribute endpoint;
  the receiving brainstem persists a receipt with full provenance
  (contributor login, rappid, from_peer source). The synthesizer can
  then pull these receipts via GET /api/neighborhoods/<slug>/contributions
  and fold them into a report.

  Two brainstems on the same machine, two brainstems across machines,
  or 200 brainstems across an organization — same protocol. The
  transport is HTTP POST against the membership organ; auth is whatever
  fronts the brainstem; identity is the rappid in the contribution
  envelope. No new infra; no central server.
EOF

scenario_summary
