#!/usr/bin/env bash
# installer/shortcuts/sign.sh — wrap `shortcuts sign --mode anyone`
#
# Why: Shortcuts.app exports .shortcut files signed for "people who know me"
# by default. That mode only lets people in your iCloud contacts install. For
# a brainstem-compatible Shortcut hosted publicly on GitHub Pages, sign with
# --mode anyone so anyone with the URL can install.
#
# Usage:
#   bash installer/shortcuts/sign.sh <input>.shortcut [<output>.shortcut]
#
# If output is omitted, the file is signed in place (input is overwritten
# after a backup).
#
# Requires: macOS with the `shortcuts` CLI (Monterey or later).

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <input>.shortcut [<output>.shortcut]" >&2
  exit 1
fi

INPUT="$1"
OUTPUT="${2:-$INPUT}"

if ! command -v shortcuts >/dev/null 2>&1; then
  echo "error: \`shortcuts\` CLI not found. macOS Monterey or later required." >&2
  exit 1
fi

if [ ! -f "$INPUT" ]; then
  echo "error: $INPUT does not exist." >&2
  exit 1
fi

# If signing in place, back up first.
if [ "$INPUT" = "$OUTPUT" ]; then
  cp "$INPUT" "$INPUT.unsigned.bak"
  TMP="$(mktemp).shortcut"
  shortcuts sign --mode anyone --input "$INPUT" --output "$TMP"
  mv "$TMP" "$OUTPUT"
  echo "✓ signed in place: $OUTPUT (unsigned backup at $INPUT.unsigned.bak)"
else
  shortcuts sign --mode anyone --input "$INPUT" --output "$OUTPUT"
  echo "✓ signed: $OUTPUT"
fi
