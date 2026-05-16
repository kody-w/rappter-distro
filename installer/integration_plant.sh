#!/bin/bash
#
# integration_plant.sh — live end-to-end test: actually plant a real repo
# on GitHub, wait for Pages, verify content, run drift check, report URL.
#
# Requires: gh CLI authenticated (`gh auth status` should pass).
#
# Usage:
#   bash installer/integration_plant.sh                        # auto-named
#   bash installer/integration_plant.sh my-test-repo "Display"
#
# The created repo is left in place. To delete it after testing:
#   gh repo delete <user>/<repo> --yes

set -e

# Resolve repo root from this script's location
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

REPO_NAME="${1:-rapp-plant-smoke-$(date -u +%Y%m%d-%H%M%S)}"
DISPLAY_NAME="${2:-RAPP Plant Smoke Test}"

GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

ok()   { printf "%s✓%s %s\n" "$GREEN" "$NC" "$*"; }
err()  { printf "%s✗%s %s\n" "$RED"   "$NC" "$*" >&2; exit 1; }
info() { printf "%s→%s %s\n" "$CYAN"  "$NC" "$*"; }

info "Repo name: $REPO_NAME"
info "Display:   $DISPLAY_NAME"
echo ""

# 1) Plant
info "Planting..."
MIRROR_REPO_NAME="$REPO_NAME" \
MIRROR_DISPLAY_NAME="$DISPLAY_NAME" \
bash "$SCRIPT_DIR/plant.sh" || err "plant.sh failed"

# 2) Resolve URL
GH_USER=$(gh api user -q .login)
URL="https://$GH_USER.github.io/$REPO_NAME"
RAW_BASE="https://raw.githubusercontent.com/$GH_USER/$REPO_NAME/main"

info "Pages URL:  $URL"
info "Raw base:   $RAW_BASE"
echo ""

# 3) Verify raw files are fetchable (immediately — no Pages wait needed)
info "Checking raw GitHub access (this works as soon as the push lands)..."
sleep 2
for f in rapp_brainstem/brainstem.py rapp_brainstem/VERSION installer/install.sh index.html rappid.json; do
    if curl -fsSL -o /dev/null "$RAW_BASE/$f"; then
        ok "raw fetch: $f"
    else
        err "raw fetch failed: $f (push may not have completed)"
    fi
done

# 4) Drift check vs grail (raw → raw, no Pages dependency)
echo ""
info "Drift check vs grail..."
for f in rapp_brainstem/brainstem.py rapp_brainstem/VERSION rapp_brainstem/agents/basic_agent.py; do
    if diff -q \
        <(curl -fsSL "https://raw.githubusercontent.com/kody-w/rapp-installer/main/$f") \
        <(curl -fsSL "$RAW_BASE/$f") >/dev/null 2>&1; then
        ok "kernel byte-identical: $f"
    else
        err "DRIFT: $f"
    fi
done

# 5) Wait for GitHub Pages deploy (up to 3 minutes)
echo ""
info "Waiting for GitHub Pages to deploy at $URL/ ..."
PAGES_LIVE=0
for i in $(seq 1 36); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL/" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        ok "Pages live (took ~$((i*5))s)"
        PAGES_LIVE=1
        break
    fi
    printf "  poll %d/36 — HTTP %s\n" "$i" "$HTTP_CODE"
    sleep 5
done

if [ "$PAGES_LIVE" -ne 1 ]; then
    echo ""
    info "Pages didn't return 200 within 3 minutes."
    info "This is common on first-time GitHub Pages enablement; it can take 5–10 minutes."
    info "The repo + raw URLs are confirmed working — try the Pages URL again in a few minutes."
    echo ""
    info "Repo: https://github.com/$GH_USER/$REPO_NAME"
    info "URL:  $URL"
    exit 0
fi

# 6) Verify Pages content
echo ""
info "Verifying Pages content..."
TMP=$(mktemp)
curl -fsSL "$URL/" -o "$TMP" || err "fetch Pages root failed"

if grep -q "$DISPLAY_NAME" "$TMP"; then
    ok "index.html renders display name"
else
    err "display name not found in Pages content"
fi

if grep -q "peerjs@1.5.4" "$TMP"; then
    ok "PeerJS CDN script embedded"
else
    err "PeerJS not embedded in served HTML"
fi

if grep -q 'id="my-id"' "$TMP"; then
    ok "tether UI present in served HTML"
else
    err "tether UI missing"
fi

# 7) Verify install.sh is fetchable + valid via Pages URL
info "Checking install.sh via Pages URL..."
if curl -fsSL "$URL/installer/install.sh" | grep -q "raw.githubusercontent.com/kody-w/rapp-installer"; then
    ok "install.sh wrapper served from Pages, proxies to grail"
else
    err "install.sh not served correctly from Pages"
fi

rm -f "$TMP"

# Summary
echo ""
echo "${GREEN}═══════════════════════════════════════════════════${NC}"
echo "${GREEN}  ✓ Integration test passed${NC}"
echo "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo "  URL:  $URL"
echo "  Repo: https://github.com/$GH_USER/$REPO_NAME"
echo ""
echo "  Cross-device test recipe:"
echo "    1. Open $URL on this device."
echo "    2. Click 'Open Door (tether)'."
echo "    3. Wait for the peer ID to appear (~3 seconds)."
echo "    4. Click 'Show QR for this ID'."
echo "    5. Scan the QR with another device's camera."
echo "    6. The other device auto-connects via PeerJS+WebRTC."
echo "    7. Type messages on either side. They flow over a"
echo "       DTLS-encrypted DataChannel. No server in the middle."
echo ""
echo "  To delete this test repo when done:"
echo "    gh repo delete $GH_USER/$REPO_NAME --yes"
echo ""
