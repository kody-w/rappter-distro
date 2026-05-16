#!/usr/bin/env bash
# tests/osi/L6a-frame-chain-browser.sh
#
# Drives the existing tests/doorman/dreamcatcher.mjs end-to-end conformance
# test for the rapp-frame/1.0 envelope (L6 sub-layer). Verifies:
#   - doorman appendFrame() writes content-addressed frames to localStorage
#   - sha256 prev_hash chain is unbroken
#   - ascended egg packs data/frames.json
#   - Dream Catcher pane reads frames.json and classifies shared / new /
#     contradiction per HERO_USECASE.md §2 doctrine
#
# Auto-installs Playwright + Chromium on first run (idempotent — reuses
# the cache from L4a-tether-browser.sh if already present).

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
DOORMAN_DIR="$REPO_ROOT/tests/doorman"

if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  GREEN=""; RED=""; YELLOW=""; BOLD=""; RESET=""
fi

if ! command -v node >/dev/null 2>&1; then
  printf "${RED}node not on PATH; install Node.js (>= 18)${RESET}\n"; exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  printf "${RED}npm not on PATH${RESET}\n"; exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf "${RED}python3 not on PATH (needed for the static fixture server)${RESET}\n"; exit 1
fi

cd "$DOORMAN_DIR"

if [ ! -d "node_modules/playwright" ]; then
  printf "${YELLOW}First-run setup — installing Playwright in $DOORMAN_DIR${RESET}\n"
  if ! npm install --no-audit --no-fund --silent; then
    printf "${RED}npm install failed${RESET}\n"; exit 1
  fi
fi

# Ensure chromium binary is present (cached at ~/Library/Caches/ms-playwright on macOS;
# shared with tests/osi/browser/ install)
CHROMIUM_PATH=$(node -e "
import('playwright').then(({ chromium }) => {
  process.stdout.write(chromium.executablePath() || '');
  process.exit(0);
}).catch(() => process.exit(0));
" 2>/dev/null)
if [ -z "$CHROMIUM_PATH" ] || [ ! -e "$CHROMIUM_PATH" ]; then
  printf "${YELLOW}First-run setup — downloading headless Chromium${RESET}\n"
  if ! npx --yes playwright install chromium; then
    printf "${RED}playwright install chromium failed${RESET}\n"; exit 1
  fi
fi

node "$DOORMAN_DIR/dreamcatcher.mjs"
