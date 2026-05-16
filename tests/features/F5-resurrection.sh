#!/usr/bin/env bash
# tests/features/F5-resurrection.sh — resurrection_ceremony_agent conformance.

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F5 — Resurrection ceremony" "Wake an organism from stasis (ECOSYSTEM §15 + Art. XXXIV.5)"

AGENT="$REPO_ROOT/rapp_brainstem/agents/resurrection_ceremony_agent.py"

heading "Step 1 — Agent file present + parses"
if [ -f "$AGENT" ] && python3 -c "import ast; ast.parse(open('$AGENT').read())" 2>/dev/null; then
  step_pass "resurrection_ceremony_agent.py parses cleanly"
else
  step_fail "agent missing or syntax error"
fi

heading "Step 2 — rapp-agent/1.0 contract"
if grep -q "class ResurrectionCeremonyAgent" "$AGENT" \
   && grep -q "metadata\s*=" "$AGENT" \
   && grep -q "def perform" "$AGENT"; then
  step_pass "class + metadata + perform present"
else
  step_fail "agent contract incomplete"
fi

heading "Step 3 — Stasis threshold = 3 years per ECOSYSTEM §6"
python3 - "$AGENT" <<'PY' && step_pass "stasis threshold = 3 years (1095 days)" || step_fail "stasis threshold drift"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("rc", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
assert m._STASIS_THRESHOLD_DAYS == 365 * 3, f"got {m._STASIS_THRESHOLD_DAYS}"
print("OK")
PY

heading "Step 4 — Activity classification (active/slowing/dormant/stasis)"
python3 - "$AGENT" <<'PY' && step_pass "_classify_activity matches ECOSYSTEM §6 thresholds" || step_fail "classification drift"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("rc", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
assert m._classify_activity(10)         == "active"
assert m._classify_activity(60)         == "slowing"
assert m._classify_activity(365)        == "dormant"
assert m._classify_activity(365 * 4)    == "stasis"
assert m._classify_activity(None)       == "unknown"
print("OK")
PY

heading "Step 5 — _resolve_repo handles v2 rappid + github URL"
python3 - "$AGENT" <<'PY' && step_pass "v2 string + github URL both resolve to (owner, repo)" || step_fail "resolution broken"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("rc", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
v2 = "rappid:v2:twin:@kody-w/heimdall:abc123@github.com/kody-w/heimdall"
assert m._resolve_repo(v2) == ("kody-w", "heimdall")
url = "https://github.com/kody-w/heimdall"
assert m._resolve_repo(url) == ("kody-w", "heimdall")
url2 = "https://github.com/kody-w/heimdall/"
assert m._resolve_repo(url2) == ("kody-w", "heimdall")
assert m._resolve_repo("garbage") is None
print("OK")
PY

heading "Step 6 — _frame_hash produces deterministic sha256 chain"
python3 - "$AGENT" <<'PY' && step_pass "frame hash is deterministic + content-addressed" || step_fail "frame hash broken"
import importlib.util, sys, hashlib, json
spec = importlib.util.spec_from_file_location("rc", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
h1 = m._frame_hash("", "2026-05-08T20:00:00Z", 0, "resurrection", {"a": 1})
h2 = m._frame_hash("", "2026-05-08T20:00:00Z", 0, "resurrection", {"a": 1})
assert h1 == h2, "hash not deterministic"
assert len(h1) == 64, f"hash wrong length: {len(h1)}"
# Different payload → different hash
h3 = m._frame_hash("", "2026-05-08T20:00:00Z", 0, "resurrection", {"a": 2})
assert h1 != h3
# Chain: prev_hash changes → hash changes
h4 = m._frame_hash(h1, "2026-05-08T20:00:00Z", 1, "resurrection", {"a": 1})
assert h4 != h1
print("OK")
PY

heading "Step 7 — Compose-action refuses non-stasis organisms"
python3 - "$AGENT" <<'PY' && step_pass "compose blocks active/slowing/dormant; only fires on stasis" || step_fail "compose guard broken"
import importlib.util, sys, json, time
spec = importlib.util.spec_from_file_location("rc", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
agent = m.ResurrectionCeremonyAgent()
# Monkey-patch _last_commit_age_days to return a "fresh" commit (10 days ago)
m._last_commit_age_days = lambda owner, repo: (10.0, "2026-04-28T00:00:00Z")
out = agent.perform(action="compose", rappid_or_url="https://github.com/kody-w/heimdall",
                    reviver_rappid="test-rappid")
result = json.loads(out)
assert result.get("ok") is False, "compose should refuse non-stasis"
assert "not in stasis" in result.get("error", ""), f"unexpected error: {result}"
print("OK")
PY

heading "Step 8 — Compose-action emits valid frame for stasis organism"
python3 - "$AGENT" <<'PY' && step_pass "stasis organism gets a valid resurrection ceremony frame" || step_fail "compose-on-stasis broken"
import importlib.util, sys, json
spec = importlib.util.spec_from_file_location("rc", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
spec.loader.exec_module(m)
agent = m.ResurrectionCeremonyAgent()
# Stasis = 4 years no commits
m._last_commit_age_days = lambda owner, repo: (365.0 * 4, "2022-05-08T00:00:00Z")
out = agent.perform(action="compose", rappid_or_url="https://github.com/test/dormant",
                    reviver_rappid="rappid:v2:twin:@me/successor:abc@github.com/me/successor",
                    note="The clinic is open again.")
result = json.loads(out)
assert result.get("ok") is True, f"compose failed: {result}"
assert result["frame"]["kind"] == "resurrection"
assert len(result["frame"]["hash"]) == 64
assert result["frame"]["payload"]["ceremony"] == "resurrection"
assert "next_step" in result and "commit_message" in result["next_step"]
print("OK")
PY

scenario_summary
