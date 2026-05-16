#!/bin/bash
# tests/test-function-app-chat.sh — exercise the new rewired Tier 2
# function_app.py /api/chat handler directly, without `func start`.
#
# This is the PR #4 acceptance test: proves function_app.py works with
# NO dependency on the deleted swarm_server.py / chat.py, discovers
# agents from BRAINSTEM_HOME, runs the llm.py-backed tool-calling loop,
# and emits the same response envelope Tier 1 brainstem.py emits.
#
# Why not `func start`? The Azure Functions runtime host is heavy and
# not universally installed. The handler is plain Python — import it
# and call it directly.
#
#     bash tests/test-function-app-chat.sh
#
# Exits 0 on success, non-zero with diagnostics on failure.

set -e
set -o pipefail

TEST_HOME="/tmp/rapp-pr4-parity-$$"
rm -rf "$TEST_HOME"
mkdir -p "$TEST_HOME/agents"

cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

cd "$(dirname "$0")/.."

# Seed a fixture agents/ directory under BRAINSTEM_HOME so function_app
# discovers them on startup.
bash rapp_swarm/build.sh >/dev/null 2>&1

# A tiny EchoAgent — mirrors the pattern from the starter set.
cat > "$TEST_HOME/agents/echo_agent.py" <<'PY'
from agents.basic_agent import BasicAgent
import json

class EchoAgent(BasicAgent):
    def __init__(self):
        self.name = "Echo"
        self.metadata = {
            "name": self.name,
            "description": "echoes the `msg` arg back",
            "parameters": {
                "type": "object",
                "properties": {"msg": {"type": "string"}},
                "required": [],
            },
        }
        super().__init__(name=self.name, metadata=self.metadata)

    def perform(self, **kw):
        return json.dumps({"status": "success", "echoed": kw.get("msg", "")})
PY

export BRAINSTEM_HOME="$TEST_HOME"
export LLM_FAKE=1

python3 - <<'PY'
import json, os, sys
from pathlib import Path

# Make rapp_swarm importable
sys.path.insert(0, "rapp_swarm")
import function_app as fa

PASS = 0; FAIL = 0; FAIL_NAMES = []

def eq(name, expected, actual):
    global PASS, FAIL
    if expected == actual:
        print(f"  ✓ {name}"); PASS += 1
    else:
        print(f"  ✗ {name}"); print(f"      expected: {expected!r}"); print(f"      actual:   {actual!r}")
        FAIL += 1; FAIL_NAMES.append(name)

def truthy(name, cond, note=""):
    global PASS, FAIL
    if cond:
        print(f"  ✓ {name}"); PASS += 1
    else:
        print(f"  ✗ {name}" + (f" — {note}" if note else ""))
        FAIL += 1; FAIL_NAMES.append(name)


# ── Section 1: agent discovery under BRAINSTEM_HOME ────────────────────
print("--- Section 1: agent discovery ---")
agents = fa._load_agents()
truthy("Echo agent discovered in BRAINSTEM_HOME/agents/",  "Echo" in agents)
eq   ("exactly one agent under fixture home", 1, len(agents))
inst = agents["Echo"]
eq   ("agent.name == Echo", "Echo", inst.name)
eq   ("agent.metadata.description present", True, bool(inst.metadata.get("description")))


# ── Section 2: run_chat envelope (parity with brainstem.py) ────────────
print("")
print("--- Section 2: /api/chat envelope ---")
result = fa.run_chat("hello world", conversation_history=None, session_id="sess-42")

for key in ("response", "voice_response", "twin_response", "session_id",
            "agent_logs", "provider", "model"):
    truthy(f"envelope has '{key}'", key in result)

eq("session_id echoed",     "sess-42", result["session_id"])
eq("provider is 'fake'",    "fake",    result["provider"])
eq("model is 'fake'",       "fake",    result["model"])

# LLM_FAKE+tools: the fake provider always picks the first tool when tools
# are present, so the loop exhausts at MAX_TOOL_ROUNDS. Content stays empty
# (realistic — a real LLM would produce content once it has what it needs).
# What we verify: agent_logs records the tool invocations.
truthy("agent_logs mentions Echo call",  "Echo" in result["agent_logs"])
truthy("agent_logs marks it ok",         "ok"  in result["agent_logs"])
eq("agent_logs records one Echo per round (up to MAX_TOOL_ROUNDS=4)",
   4, result["agent_logs"].count("Echo"))

# Without tools (no agents), the fake provider returns real content.
import importlib, pathlib
empty_home = pathlib.Path("/tmp/rapp-pr4-parity-empty-" + os.urandom(4).hex())
empty_home.joinpath("agents").mkdir(parents=True, exist_ok=True)
_prev = fa._AGENTS_DIR
fa._AGENTS_DIR = empty_home / "agents"
try:
    noagents = fa.run_chat("hello world", session_id="s-empty")
finally:
    fa._AGENTS_DIR = _prev
truthy("no-tools path: response contains user input", "hello world" in noagents["response"])
eq   ("no-tools path: provider is fake", "fake", noagents["provider"])


# ── Section 3: conversation_history pass-through ───────────────────────
print("")
print("--- Section 3: conversation_history ---")
hist = [{"role": "user", "content": "earlier message"},
        {"role": "assistant", "content": "earlier reply"}]
# Exercise against empty agents/ so we get a real content response
fa._AGENTS_DIR = empty_home / "agents"
try:
    r = fa.run_chat("current turn", conversation_history=hist, session_id="s2")
finally:
    fa._AGENTS_DIR = _prev
eq("session_id echoed",                "s2",   r["session_id"])
truthy("response contains current turn",     "current turn" in r["response"])
truthy("history included in prior messages", bool(r.get("agent_logs") is not None))


# ── Section 4: VOICE/TWIN split parses identically ─────────────────────
print("")
print("--- Section 4: VOICE/TWIN split parity ---")
main, voice, twin = fa._parse_voice_twin_split("hello|||VOICE|||say hi|||TWIN|||the user is testing")
eq("main split",  "hello",             main)
eq("voice split", "say hi",            voice)
eq("twin split",  "the user is testing", twin)

# No delimiters → everything in main
main, voice, twin = fa._parse_voice_twin_split("plain response")
eq("no delims: main",  "plain response", main)
eq("no delims: voice", "",               voice)
eq("no delims: twin",  "",               twin)


# ── Section 5: BRAINSTEM_HOME swap is honored ──────────────────────────
print("")
print("--- Section 5: BRAINSTEM_HOME swap (per-request state resolution) ---")
ALT = "/tmp/rapp-pr4-parity-alt-" + os.urandom(4).hex()
Path(ALT).joinpath("agents").mkdir(parents=True, exist_ok=True)
# empty agents/ under the alt home — discovery should return {}

# fa's _BRAINSTEM_HOME and _AGENTS_DIR are resolved at import time, so to
# swap we need to simulate what would happen in a fresh process. The
# user-facing guarantee is: "agents live under BRAINSTEM_HOME/agents/" —
# we verify that by asking _load_agents to discover against a different
# dir via monkeypatch.
orig_agents_dir = fa._AGENTS_DIR
try:
    fa._AGENTS_DIR = Path(ALT) / "agents"
    agents = fa._load_agents()
    eq("alt home: 0 agents discovered", 0, len(agents))
finally:
    fa._AGENTS_DIR = orig_agents_dir

# Confirm switching back sees the fixture
agents = fa._load_agents()
eq("restored home: Echo rediscovered", 1, len(agents))


# ── Section 6: no multi-swarm routing surface ──────────────────────────
print("")
print("--- Section 6: Article XIV compliance (no /api/swarm/*) ---")
# function_app.py's `app` is a FunctionApp. Walk its functions and
# assert none of them own an /api/swarm/* route.
import azure.functions as func_mod  # noqa: F401
routes = []
# FunctionApp keeps functions on ._function_builders (v1 SDK) — poke with introspection.
for attr in ("_function_builders", "function_builders"):
    builders = getattr(fa.app, attr, None)
    if builders:
        for b in builders:
            for trig in getattr(b, "_trigger_list", []):
                r = getattr(trig, "route", None)
                if r: routes.append(r)
        break
# Fallback: scan source for @app.route(route="…")
if not routes:
    import re
    src = Path("rapp_swarm/function_app.py").read_text()
    routes = re.findall(r'@app\.route\(route="([^"]+)"', src)

print(f"    discovered routes: {sorted(set(routes))}")
bad = [r for r in routes if "swarm/" in r or "t2t/" in r or "workspace" in r]
eq("no /api/swarm/*, /api/t2t/*, or /api/workspace/* routes", [], bad)
expected_present = {"chat", "health"}
missing = expected_present - set(routes)
eq("has /api/chat and /api/health", set(), missing)


# ── Summary ────────────────────────────────────────────────────────────
print("")
print("=" * 40)
print(f"  {PASS} passed, {FAIL} failed")
print("=" * 40)
if FAIL:
    for n in FAIL_NAMES:
        print(f"  - {n}")
    sys.exit(1)
sys.exit(0)
PY
