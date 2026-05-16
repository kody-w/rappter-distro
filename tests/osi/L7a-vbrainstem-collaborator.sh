#!/usr/bin/env bash
# tests/osi/L7a-vbrainstem-collaborator.sh
#
# Browser-side collaborator test (Layer 7 — application).
#
# Drives vbrainstem (pages/vbrainstem/index.html) in a real Chromium
# context via Playwright, authenticates with GitHub, joins the published
# kody-w/sim-art-collective neighborhood, and proves it can post an Issue
# (collaboration via the same auth chain). Demonstrates the third
# participant in the multi-AI sim alongside Bill + Alice (claude CLI).
#
# Reuses tests/osi/browser/ playwright infrastructure (auto-installs
# on first run).
#
# ENV:
#   GH_TOKEN  — GitHub PAT with repo scope (defaults to `gh auth token`)
#   SIM_REPO  — defaults to "kody-w/sim-art-collective"

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
  printf "${YELLOW}First-run setup — installing Playwright${RESET}\n"
  if ! npm install --no-audit --no-fund --silent; then
    printf "${RED}npm install failed${RESET}\n"
    exit 1
  fi
fi

CHROMIUM_PATH=$(node -e "
import('playwright').then(({ chromium }) => {
  process.stdout.write(chromium.executablePath() || '');
  process.exit(0);
}).catch(() => process.exit(0));
" 2>/dev/null)
if [ -z "$CHROMIUM_PATH" ] || [ ! -e "$CHROMIUM_PATH" ]; then
  printf "${YELLOW}First-run setup — downloading headless Chromium${RESET}\n"
  if ! npx --yes playwright install chromium; then
    printf "${RED}playwright install chromium failed${RESET}\n"
    exit 1
  fi
fi

# Resolve the GitHub token: explicit env > gh auth token
if [ -z "${GH_TOKEN:-}" ]; then
  if command -v gh >/dev/null 2>&1; then
    GH_TOKEN=$(gh auth token 2>/dev/null)
  fi
fi
if [ -z "${GH_TOKEN:-}" ]; then
  printf "${RED}GH_TOKEN not set and gh auth token failed. Authenticate gh CLI or export GH_TOKEN.${RESET}\n"
  exit 1
fi

export GH_TOKEN
SIM_REPO=${SIM_REPO:-kody-w/sim-art-collective}
export SIM_REPO

node "$BROWSER_DIR/vbrainstem-join.spec.mjs"
