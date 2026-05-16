#!/usr/bin/env bash
# tests/features/run.sh — runs every F<n>-*.sh test; prints conformance matrix.
#
# Usage:
#   bash tests/features/run.sh
#   bash tests/features/run.sh --offline   (passed through to feature tests)

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  GREEN=""; RED=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""
fi

OFFLINE=0
for arg in "$@"; do
  case "$arg" in
    --offline) OFFLINE=1 ;;
    --help|-h) echo "Usage: $0 [--offline]"; exit 0 ;;
  esac
done

EXTRA_FLAGS=()
[ "$OFFLINE" -eq 1 ] && EXTRA_FLAGS+=("--offline")

FEATURES=(
  "F1-lineage-rollup"
  "F2-leaderboard"
  "F3-proximity"
  "F4-ed25519-sign"
  "F5-resurrection"
  "F6-ant-farm"
  "F7-rar-hotload"
  "F8-graft"
  "F9-universal-docking"
  "F10-ecosystem-audit"
  "F11-launch-to-public"
  "F12-bond-rhythm"
  "F13-estate-spec"
  "F14-estate-rebuild"
  "F15-private-estate"
)

declare -a NAMES STATUS
TOTAL_PASS=0 TOTAL_FAIL=0
START=$(date +%s)

printf "\n${BOLD}${BLUE}━━━ RAPP Feature Conformance Suite (${#FEATURES[@]} features) ━━━${RESET}\n"

for f in "${FEATURES[@]}"; do
  TEST="$HERE/$f.sh"
  if [ ! -f "$TEST" ]; then
    printf "${RED}MISSING: $TEST${RESET}\n"
    NAMES+=("$f"); STATUS+=("✗"); TOTAL_FAIL=$((TOTAL_FAIL+1)); continue
  fi
  printf "\n${BOLD}▶ Running $f${RESET}\n"
  if bash "$TEST" ${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}; then
    NAMES+=("$f"); STATUS+=("✓"); TOTAL_PASS=$((TOTAL_PASS+1))
  else
    NAMES+=("$f"); STATUS+=("✗"); TOTAL_FAIL=$((TOTAL_FAIL+1))
  fi
done

ELAPSED=$(($(date +%s) - START))

printf "\n\n${BOLD}━━━ Feature Conformance Matrix ━━━${RESET}\n\n"
printf "  ${BOLD}%-22s %s${RESET}\n" "Feature" "Status"
printf "  ${BLUE}%s${RESET}\n" "──────────────────────  ──────"
for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  status="${STATUS[$i]}"
  if [ "$status" = "✓" ]; then
    printf "  %-22s ${GREEN}%s pass${RESET}\n" "$name" "$status"
  else
    printf "  %-22s ${RED}%s FAIL${RESET}\n" "$name" "$status"
  fi
done
printf "\n  ${BOLD}%d passing, %d failing${RESET} (of ${#FEATURES[@]} features, ${ELAPSED}s)\n\n" "$TOTAL_PASS" "$TOTAL_FAIL"

[ "$TOTAL_FAIL" -gt 0 ] && exit 1
exit 0
