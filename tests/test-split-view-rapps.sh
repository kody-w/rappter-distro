#!/bin/bash
# tests/test-split-view-rapps.sh — verify the brainstem UI's new
# side-by-side rapplication panel (split-view) feature, the Browse
# RAPP_Store modal, the postMessage bridge, and that NONE of the
# existing UI/UX surface area was modified or removed.
#
#     bash tests/test-split-view-rapps.sh
#
# Exits 0 on success, non-zero with diagnostics on failure.

set -e
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INDEX="$REPO_ROOT/rapp_brainstem/index.html"
PASS=0
FAIL=0
FAIL_NAMES=()

assert_grep() {
    local name="$1" needle="$2" file="$3"
    if grep -qF -- "$needle" "$file"; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name"; echo "      needle:    $needle"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

assert_grep_count() {
    local name="$1" needle="$2" file="$3" min="$4"
    local n; n=$(grep -cF -- "$needle" "$file" || true)
    if [ "$n" -ge "$min" ]; then
        echo "  ✓ $name (found $n, min $min)"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name"; echo "      needle:    $needle"
        echo "      expected at least $min, found $n"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

[ -f "$INDEX" ] || { echo "FAIL: $INDEX not found"; exit 1; }

# ── Section 1: existing UI/UX is preserved ────────────────────────────
# These IDs/labels must still be present after the changes — if any
# of these break, we silently degraded the existing experience.

echo ""
echo "--- Section 1: existing UI/UX preserved (regression guard) ---"
assert_grep "header h1 RAPP Brainstem still present"   '<h1>RAPP Brainstem' "$INDEX"
assert_grep "agents-panel exists"                      'id="agents-panel"'  "$INDEX"
assert_grep "agent-list-ul exists"                     'id="agent-list-ul"' "$INDEX"
assert_grep "browse-modal (RAR) exists"                'id="browse-modal"'  "$INDEX"
assert_grep "browse-link button (Browse RAR)"          'id="browse-link"'   "$INDEX"
assert_grep "rapp-frame full-screen overlay still here" 'id="rapp-frame"'   "$INDEX"
assert_grep "rf-iframe still here"                     'id="rf-iframe"'     "$INDEX"
assert_grep "openRappFrame fn still defined"           'function openRappFrame' "$INDEX"
assert_grep "closeRappFrame fn still defined"          'function closeRappFrame' "$INDEX"
assert_grep "loadRapplications fn still defined"       'async function loadRapplications' "$INDEX"
assert_grep "voice panel preserved"                    'id="voice-panel"'   "$INDEX"
assert_grep "starter-prompts preserved"                'id="starter-prompts"' "$INDEX"
assert_grep "drag-drop overlay preserved"              'id="drop-overlay"'  "$INDEX"

# ── Section 2: new split-view pane structure ───────────────────────────

echo ""
echo "--- Section 2: split-view pane (new) ---"
assert_grep "split-pane container exists"    'id="split-pane"'    "$INDEX"
assert_grep "split-pane has tabs container"  'id="split-tabs"'    "$INDEX"
assert_grep "split-pane has iframe slot"     'id="split-iframes"' "$INDEX"
assert_grep "split divider for resizing"     'id="split-divider"' "$INDEX"
assert_grep "split empty-state CTA"          'id="split-empty"'   "$INDEX"
assert_grep "body class toggled on activation" 'split-active'     "$INDEX"
assert_grep "openRappInSplit JS fn"          'function openRappInSplit' "$INDEX"
assert_grep "closeSplitPane JS fn"           'function closeSplitPane'  "$INDEX"
assert_grep "splitPaneState persistence"     'split_pane_state' "$INDEX"

# ── Section 3: Browse RAPP_Store modal (new, parallel to Browse RAR) ───

echo ""
echo "--- Section 3: Browse RAPP_Store (new) ---"
assert_grep "store-modal exists"          'id="store-modal"'        "$INDEX"
assert_grep "store-list exists"           'id="store-list"'         "$INDEX"
assert_grep "store-search input"          'id="store-search"'       "$INDEX"
assert_grep "openStore JS fn"             'function openStore'      "$INDEX"
assert_grep "closeStore JS fn"            'function closeStore'     "$INDEX"
assert_grep "Browse RAPP_Store button"    'Browse RAPP'             "$INDEX"
assert_grep "store fetches catalog directly (decoupled from binder)" "raw.githubusercontent.com/kody-w/rapp_store/main/index.json" "$INDEX"
# Decoupled architecture: store installs route through /agents/import like
# drag-drop, not /api/binder/install. Binder remains for egg-imports + admin.
assert_grep "store installs via /agents/import (decoupled)" "/agents/import" "$INDEX"
assert_grep "store-installed rapps tracked locally"         "STORE_INSTALLED_KEY" "$INDEX"
assert_grep "CDN URL rewriter for ui_url"                   "_toCdnUrl"          "$INDEX"
assert_grep "rapp_store routes through GitHub Pages"        "kody-w.github.io/RAPP_Store" "$INDEX"
assert_grep "directUrl iframe path (CDN)"                   "directUrl"          "$INDEX"

# ── Section 4: postMessage bridge ──────────────────────────────────────

echo ""
echo "--- Section 4: iframe → chat postMessage bridge (new) ---"
assert_grep "window message listener"     "addEventListener('message'" "$INDEX"
assert_grep "chat:append message type"    'chat:append'             "$INDEX"

# ── Section 5: tabs scaffolding ────────────────────────────────────────

echo ""
echo "--- Section 5: multi-rapp tabs (new) ---"
assert_grep "tab close handler"           'closeTab'                "$INDEX"
assert_grep "tab active class"            'tab-active'              "$INDEX"

# ── Section 5b: Cmd+K command palette (new) ───────────────────────────

echo ""
echo "--- Section 5b: Cmd+K command palette (new) ---"
assert_grep "cmdk-modal exists"          'id="cmdk-modal"'    "$INDEX"
assert_grep "cmdk-search input"          'id="cmdk-search"'   "$INDEX"
assert_grep "cmdk-list container"        'id="cmdk-list"'     "$INDEX"
assert_grep "openCmdK JS fn"             'function openCmdK'  "$INDEX"
assert_grep "Cmd+K binding (metaKey)"    'metaKey'            "$INDEX"
assert_grep "Cmd+K binding (ctrlKey)"    'ctrlKey'            "$INDEX"
assert_grep "key K bound"                "e.key === 'k'"      "$INDEX"

# ── Section 5c: pop-out window for split-pane tab (new) ────────────────

echo ""
echo "--- Section 5c: pop-out window (new) ---"
assert_grep "popOutTab JS fn"            'function popOutTab' "$INDEX"
assert_grep "split-popout button"        'id="split-popout"'  "$INDEX"

# ── Section 5d: multi-chat tabs + per-chat agent toggles (new) ─────────

echo ""
echo "--- Section 5d: multi-chat tabs + per-chat agents (new) ---"
assert_grep "chat-tabs strip exists"        'id="chat-tabs"'           "$INDEX"
assert_grep "chat-column wrapper exists"    'id="chat-column"'         "$INDEX"
assert_grep "appState global"               'const appState'           "$INDEX"
assert_grep "createChat fn"                 'function createChat'      "$INDEX"
assert_grep "switchChat fn"                 'function switchChat'      "$INDEX"
assert_grep "closeChat fn"                  'function closeChat'       "$INDEX"
assert_grep "renameChat fn"                 'function renameChat'      "$INDEX"
assert_grep "_persistChats fn"              'function _persistChats'   "$INDEX"
assert_grep "_loadChats fn"                 'function _loadChats'      "$INDEX"
assert_grep "_renderChatTabs fn"            'function _renderChatTabs' "$INDEX"
assert_grep "_renderChatMessages fn"        'function _renderChatMessages' "$INDEX"
assert_grep "Ctrl+Shift+T new-chat binding" 'shiftKey'                 "$INDEX"
assert_grep "brainstem_chats persist key"   'brainstem_chats'          "$INDEX"

# ── Section 6: only ADDITIONS — sanity that we didn't strip key text ───

echo ""
echo "--- Section 6: file-size sanity (additive only) ---"
LINES=$(wc -l < "$INDEX")
if [ "$LINES" -gt 3280 ]; then
    echo "  ✓ index.html grew (${LINES} lines, was 3280 after cmdk+popout) — additive change"
    PASS=$((PASS + 1))
else
    echo "  ✗ index.html did not grow past 3280 (${LINES} lines) — expected multi-chat additions"
    FAIL=$((FAIL + 1)); FAIL_NAMES+=("file-size-sanity")
fi

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────────────────────────"
echo "Tests: $((PASS + FAIL)) | Pass: $PASS | Fail: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "Failed:"
    for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done
    exit 1
fi
echo "✓ All split-view UI tests passed."
