#!/usr/bin/env bash
# tests/osi/_lib.sh — shared helpers for OSI layer tests.
#
# Wraps tests/scenarios/_lib.sh and adds OSI-specific concerns:
#   - --offline flag (skip every step that would touch the network)
#   - HTTP HEAD reachability with strict timeout
#   - one-line schema-shape validators (no jsonschema dependency)
#   - sandbox tmpdir per test process

OSI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$OSI_LIB_DIR/../.." && pwd)"

# shellcheck source=tests/scenarios/_lib.sh
source "$REPO_ROOT/tests/scenarios/_lib.sh"

OFFLINE=0
LAYER=""
for arg in "$@"; do
  case "$arg" in
    --offline) OFFLINE=1 ;;
    --layer=*) LAYER="${arg#*=}" ;;
  esac
done

# --- network helpers ---------------------------------------------------------

# osi_head <url> [timeout_seconds=5] — emit HTTP status code; "000" on transport fail.
# NB: no -f flag — we want the actual status code (e.g. 404), not a curl-side error.
osi_head() {
  local url="$1" timeout="${2:-5}"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time "$timeout" -I "$url" 2>/dev/null)
  if [ -z "$code" ] || [ "$code" = "000" ]; then echo "000"; else echo "$code"; fi
}

# osi_get_status <url> [timeout_seconds=5] — like osi_head but uses GET (some
# servers refuse HEAD; PeerJS is one of them).
osi_get_status() {
  local url="$1" timeout="${2:-5}"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)
  if [ -z "$code" ] || [ "$code" = "000" ]; then echo "000"; else echo "$code"; fi
}

# osi_get <url> [timeout_seconds=5] — emit body to stdout; non-zero on fail.
osi_get() {
  local url="$1" timeout="${2:-5}"
  curl -fsS --max-time "$timeout" "$url"
}

# Skip a network step in offline mode; otherwise run the supplied step body.
osi_net() {
  local label="$1"; shift
  if [ "$OFFLINE" -eq 1 ]; then
    step_skip "$label (offline mode)"
    return 1
  fi
  return 0
}

# --- sandbox -----------------------------------------------------------------

# Create a per-test tmpdir; remove on EXIT.
osi_sandbox() {
  local prefix="${1:-rapp-osi}"
  local dir
  dir=$(mktemp -d -t "${prefix}.XXXXXX")
  echo "$dir"
}

osi_cleanup_dir() {
  [ -d "$1" ] && rm -rf "$1"
}

# --- shape validators --------------------------------------------------------

# osi_assert_schema <json-text> <expected-schema-string> <test-label>
osi_assert_schema() {
  local json="$1" expected="$2" label="$3"
  local got
  got=$(printf "%s" "$json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('schema',''))" 2>/dev/null)
  if [ "$got" = "$expected" ]; then
    step_pass "$label — schema=$expected"
  else
    step_fail "$label — schema mismatch (expected $expected, got '$got')"
  fi
}

# osi_assert_keys <json-text> <comma-separated-required-keys> <test-label>
osi_assert_keys() {
  local json="$1" keys="$2" label="$3"
  python3 - "$keys" "$label" <<PY
import json, sys
keys = sys.argv[1].split(",")
label = sys.argv[2]
data = json.loads(sys.stdin.read())
missing = [k for k in keys if k not in data]
if missing:
    print(f"::FAIL::{label} — missing keys: {','.join(missing)}", file=sys.stderr)
    sys.exit(1)
print(f"::PASS::{label} — has {','.join(keys)}", file=sys.stderr)
PY
  if [ $? -eq 0 ]; then
    step_pass "$label — has $keys"
  else
    step_fail "$label — missing keys (expected $keys)"
  fi
} <<<"$1"

# osi_python — run a python block with REPO_ROOT on sys.path; emit stdout.
osi_python() {
  python3 -c "
import sys, os
sys.path.insert(0, '$REPO_ROOT')
$1
"
}

# --- pretty headers per layer ------------------------------------------------

osi_layer_intro() {
  local layer="$1" purpose="$2"
  printf "\n${BOLD}${BLUE}=== %s ===${RESET}\n" "$layer"
  printf "  ${YELLOW}%s${RESET}\n" "$purpose"
  if [ "$OFFLINE" -eq 1 ]; then
    printf "  ${YELLOW}(offline mode — network checks skipped)${RESET}\n"
  fi
}
