#!/usr/bin/env bash
# tests/osi/L4a-tether-browser.sh
#
# Playwright-driven L4a (WebRTC tether) conformance test. Two real
# Chromium contexts open a DTLS-encrypted DataChannel via the PeerJS
# broker and exchange messages both ways. Closes the gap the shell-only
# L4 test can't cover.
#
# Auto-installs Playwright + Chromium on first run (~150MB one-time).
# Idempotent — subsequent runs reuse the install.
#
# Usage:
#   bash tests/osi/L4a-tether-browser.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BROWSER_DIR="$HERE/browser"

if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  GREEN=""; RED=""; YELLOW=""; BOLD=""; RESET=""
fi

if ! command -v node >/dev/null 2>&1; then
  printf "${RED}node not on PATH; install Node.js (>= 18) and retry${RESET}\n"
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  printf "${RED}npm not on PATH; install npm and retry${RESET}\n"
  exit 1
fi

cd "$BROWSER_DIR"

if [ ! -d "node_modules/playwright" ]; then
  printf "${YELLOW}First-run setup — installing Playwright (~30s)${RESET}\n"
  if ! npm install --no-audit --no-fund --silent; then
    printf "${RED}npm install failed${RESET}\n"
    exit 1
  fi
fi

# Check whether Chromium is installed for Playwright; install if missing.
CHROMIUM_PATH=$(node -e "
import('playwright').then(({ chromium }) => {
  process.stdout.write(chromium.executablePath() || '');
  process.exit(0);
}).catch(() => process.exit(0));
" 2>/dev/null)
if [ -z "$CHROMIUM_PATH" ] || [ ! -e "$CHROMIUM_PATH" ]; then
  printf "${YELLOW}First-run setup — downloading headless Chromium (~150MB)${RESET}\n"
  if ! npx --yes playwright install chromium; then
    printf "${RED}playwright install chromium failed${RESET}\n"
    exit 1
  fi
fi

node "$BROWSER_DIR/L4a-tether.spec.mjs"
