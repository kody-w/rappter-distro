#!/usr/bin/env bash
# tests/osi/L7b-cross-device.sh
#
# Cross-device real-time collaboration: TWO browser-context vbrainstems
# (Carlos + Diana, each its own localStorage = its own device) join the
# published kody-w/sim-art-collective neighborhood and contribute, in
# parallel with the local Bill + Alice claude CLI ticks already pushing
# via the orchestrator. Demonstrates four distinct identities all
# touching the same neighborhood in real time.
#
# Reuses tests/osi/browser/ playwright infrastructure.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BROWSER_DIR="$HERE/browser"

if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  GREEN=""; RED=""; YELLOW=""; BOLD=""; RESET=""
fi

if ! command -v node >/dev/null 2>&1; then
  printf "${RED}node not on PATH${RESET}\n"; exit 1
fi

cd "$BROWSER_DIR"

if [ ! -d "node_modules/playwright" ]; then
  printf "${YELLOW}First-run setup — installing Playwright${RESET}\n"
  npm install --no-audit --no-fund --silent || { printf "${RED}npm install failed${RESET}\n"; exit 1; }
fi

CHROMIUM_PATH=$(node -e "
import('playwright').then(({ chromium }) => {
  process.stdout.write(chromium.executablePath() || '');
  process.exit(0);
}).catch(() => process.exit(0));
" 2>/dev/null)
if [ -z "$CHROMIUM_PATH" ] || [ ! -e "$CHROMIUM_PATH" ]; then
  printf "${YELLOW}First-run setup — downloading headless Chromium${RESET}\n"
  npx --yes playwright install chromium || { printf "${RED}playwright install failed${RESET}\n"; exit 1; }
fi

if [ -z "${GH_TOKEN:-}" ]; then
  if command -v gh >/dev/null 2>&1; then
    GH_TOKEN=$(gh auth token 2>/dev/null)
  fi
fi
if [ -z "${GH_TOKEN:-}" ]; then
  printf "${RED}GH_TOKEN not set and gh auth token failed${RESET}\n"; exit 1
fi
export GH_TOKEN
SIM_REPO=${SIM_REPO:-kody-w/sim-art-collective}
export SIM_REPO

node "$BROWSER_DIR/cross-device.spec.mjs"
