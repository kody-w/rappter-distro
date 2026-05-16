#!/usr/bin/env bash
# tests/scenarios/_lib.sh — shared helpers for the four scenario scripts.
#
# Source this from each scenario:
#     source "$(dirname "$0")/_lib.sh"

set -uo pipefail

# Colors (disable when not a TTY)
if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  GREEN=""; RED=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Test fixtures (local-only minimal seed for scenarios that need a real seed dir).
# Planted neighborhoods live as their own GitHub repos (e.g. kody-w/microsoft-se-team-neighborhood)
# — this repo holds the spec + kernel only, never the seeds themselves.
FIXTURES_DIR="$REPO_ROOT/tests/fixtures"
ORGAN_PATH="$REPO_ROOT/rapp_brainstem/utils/organs/neighborhood_membership_organ.py"

DRY_RUN=0
BRAINSTEM_URL="${BRAINSTEM_URL:-http://localhost:7071}"

PASSED=0
FAILED=0
FAIL_DETAILS=()

# --- argv handling -----------------------------------------------------------

scenario_parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRY_RUN=1 ;;
      --help|-h)
        echo "Usage: $0 [--dry-run]"
        echo "  --dry-run   Skip steps that need a running brainstem; exercise script logic only."
        exit 0
        ;;
    esac
  done
}

# --- output helpers ---------------------------------------------------------

heading() { printf "\n${BOLD}${BLUE}%s${RESET}\n" "$1"; }
note()    { printf "  %s\n" "$1"; }
muted()   { printf "  ${YELLOW}%s${RESET}\n" "$1"; }

step_pass() {
  PASSED=$((PASSED + 1))
  printf "  ${GREEN}✓${RESET} %s\n" "$1"
}

step_fail() {
  FAILED=$((FAILED + 1))
  FAIL_DETAILS+=("$1")
  printf "  ${RED}✗${RESET} %s\n" "$1"
}

step_skip() {
  printf "  ${YELLOW}⊘${RESET} %s ${YELLOW}(skipped)${RESET}\n" "$1"
}

scenario_summary() {
  local total=$((PASSED + FAILED))
  printf "\n${BOLD}%d passing, %d failing${RESET} (of %d)\n\n" "$PASSED" "$FAILED" "$total"
  if [ "$FAILED" -gt 0 ]; then
    for d in "${FAIL_DETAILS[@]}"; do echo "  - $d"; done
    exit 1
  fi
}

# --- python-direct invocation ------------------------------------------------
# Run an agent's perform() directly (no brainstem required). Args:
#   $1 — seed dir (sets NEIGHBORHOOD_SEED_DIR)
#   $2 — agent module path (e.g. agents/foo_agent.py)
#   $3 — class name (e.g. FooAgent)
#   $4 — JSON kwargs as a single arg
# Echoes the agent's return value.

run_agent_direct() {
  local seed_dir="$1" mod_path="$2" cls_name="$3" kwargs_json="$4"
  python3 - "$seed_dir" "$mod_path" "$cls_name" "$kwargs_json" <<'PY'
import importlib.util, json, os, sys
seed_dir, mod_path, cls_name, kwargs_json = sys.argv[1:5]
os.environ["NEIGHBORHOOD_SEED_DIR"] = seed_dir
sys.path.insert(0, seed_dir)
spec = importlib.util.spec_from_file_location("scenario_agent", os.path.join(seed_dir, mod_path))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
agent = getattr(mod, cls_name)()
out = agent.perform(**json.loads(kwargs_json or "{}"))
if isinstance(out, (dict, list)):
    print(json.dumps(out, indent=2))
else:
    print(out)
PY
}

# --- organ-direct invocation ------------------------------------------------
# Call the membership organ's handle() directly. Args:
#   $1 — method (GET / POST / etc.)
#   $2 — path (e.g. "join", "kody-w/foo/sync")
#   $3 — body JSON or empty
# Echoes the JSON response; sets EXIT to the status code in $? on caller side.

run_organ_direct() {
  local method="$1" path="$2" body="${3:-}"
  python3 - "$method" "$path" "$body" "$ORGAN_PATH" <<'PY'
import importlib.util, json, os, sys, tempfile
method, path, body, organ_path = sys.argv[1:5]
spec = importlib.util.spec_from_file_location("organ", organ_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
# Sandbox the subscription cache to a tmpdir so scenario tests don't mutate real state.
tmp = tempfile.mkdtemp(prefix="rapp-scenario-")
mod.HOME_BRAINSTEM = tmp
mod.SUBS_FILE = os.path.join(tmp, "neighborhoods.json")
mod.CACHE_DIR = os.path.join(tmp, "neighborhoods")
b = json.loads(body) if body else None
out, status = mod.handle(method, path, b)
print(json.dumps({"status": status, "body": out}, indent=2))
sys.exit(0 if 200 <= status < 300 else 1)
PY
}

# --- brainstem reachability --------------------------------------------------

brainstem_alive() {
  curl -fsS --max-time 1 "${BRAINSTEM_URL}/health" >/dev/null 2>&1
}
