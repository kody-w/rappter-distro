#!/usr/bin/env bash
# push_canvas.sh — publish the local neighborhood's canvas to the public repo.
#
# Idempotent: no-op if no local changes since the last push. Additive:
# only adds new submissions / votes / members entries — never removes.
# After this runs, vbrainstem (and any other public observer) sees Bill +
# Alice's autonomous tick contributions.
#
# Usage:
#   ./push_canvas.sh [<neighborhood-dir>]
#
# Default neighborhood: ~/RAPP-sim/local-art-collective
# Exit codes:
#   0 — pushed cleanly OR no changes (idempotent success)
#   1 — git/gh failure (auth, network, etc.)
#   2 — neighborhood dir invalid (not a git repo)

set -uo pipefail
NB=${1:-$HOME/RAPP-sim/local-art-collective}

if [ ! -d "$NB" ]; then
  echo "ERROR: neighborhood dir not found: $NB" >&2
  exit 2
fi
if [ ! -d "$NB/.git" ]; then
  echo "ERROR: $NB is not a git repo (run the publish step first)" >&2
  exit 2
fi

cd "$NB"

# Stage the canonical canvas files (additive — git add never removes from index).
# Add each path individually; if the path doesn't exist, skip it.
# (`git add a/ b/ missing.json` aborts the WHOLE add when one pathspec is bad —
# we sidestep that by adding paths one at a time.)
for path in submissions/ votes/ members.json card.json holo.md holo.svg holo-qr.svg \
            specs/ neighborhood.json soul.md rappid.json; do
  [ -e "$path" ] && git add "$path" 2>/dev/null || true
done

if git diff --cached --quiet; then
  echo "[push] no changes since last push (canvas already up-to-date)"
  exit 0
fi

UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
NEW_SUBS=$(git diff --cached --name-only -- submissions/ 2>/dev/null | grep -c "meta\.json$" || true)
NEW_VOTES=$(git diff --cached --name-only -- votes/ 2>/dev/null | grep -c "\.json$" || true)
OTHER=$(git diff --cached --name-only 2>/dev/null | grep -v "^submissions/.*meta\.json$\|^votes/" | wc -l | tr -d ' ')

if ! git -c commit.gpgsign=false commit -q -m "canvas tick @ $UTC: +${NEW_SUBS}sub +${NEW_VOTES}vote +${OTHER}other (autonomous local→public push)"; then
  echo "[push] commit failed" >&2
  exit 1
fi

if ! git push -q origin main 2>&1; then
  echo "[push] git push failed (auth or network — try \`cd $NB && git pull --rebase && git push\`)" >&2
  exit 1
fi

echo "[push] OK @ $UTC: +${NEW_SUBS}sub +${NEW_VOTES}vote +${OTHER}other → $(git remote get-url origin)"
