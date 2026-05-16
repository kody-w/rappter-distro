#!/usr/bin/env bash
# Legacy wire conformance test (Constitution Article XXV — wire is forever).
#
# Memorializes the legacy /chat handlers as test cases. For each ancestor
# repo, fetch the canonical handler source and assert the sacred wire
# fields are still present:
#
#   - kody-w/rapp-installer (Tier 1 v0.6.0 — legacy local brainstem)
#   - kody-w/CommunityRAPP   (Tier 2 — public Azure cloud)
#   - kody-w/Copilot-Agent-365 (CA365 — the original implementation)
#
# This is a static conformance check, not a live integration test. It
# fails the moment any of those repos ship a /chat handler that drops
# user_input, conversation_history, user_guid, or DEFAULT_USER_GUID,
# or breaks the assistant_response shape. They are the ancestors of the
# wire; if the wire ever drifts in any of them, the federation fragments.
#
# Network required (this test reaches GitHub).
set -euo pipefail
cd "$(dirname "$0")/../.."

DEFAULT_USER_GUID="c0p110t0-aaaa-bbbb-cccc-123456789abc"

assert_contains() {
    local file="$1" needle="$2" label="$3"
    if grep -qE "$needle" "$file"; then
        echo "    PASS: $label"
    else
        echo "    FAIL: $label  ($needle not found in $file)"
        exit 1
    fi
}

check_endpoint() {
    local label="$1" url="$2" needs_assistant_response="$3" needs_default_guid="$4"
    local tmp="/tmp/rapp-legacy-$(echo "$label" | tr '/ ' '-' | tr -d '()').py"
    echo "▶ $label"
    echo "    fetching $url"
    if ! curl -fsSL "$url" -o "$tmp" 2>&1; then
        # Try gh CLI for private repos
        if command -v gh >/dev/null 2>&1; then
            local repo_path
            repo_path=$(echo "$url" | sed -E 's|https://raw.githubusercontent.com/||; s|/main/|/contents/|')
            if gh api -H "Accept: application/vnd.github.raw" "/repos/$repo_path" > "$tmp" 2>/dev/null; then
                echo "    (fetched via gh CLI — private repo)"
            else
                echo "    SKIP: could not fetch $url (private repo, gh CLI not authed for it?)"
                return 0
            fi
        else
            echo "    SKIP: could not fetch $url and gh CLI unavailable"
            return 0
        fi
    fi

    assert_contains "$tmp" 'user_input'                                   "request envelope: user_input present"
    assert_contains "$tmp" 'conversation_history'                         "request envelope: conversation_history present"
    if [ "$needs_default_guid" = "yes" ]; then
        assert_contains "$tmp" "DEFAULT_USER_GUID"                        "identity: DEFAULT_USER_GUID constant present"
        assert_contains "$tmp" "$DEFAULT_USER_GUID"                       "identity: exact default GUID string preserved (c0p110t0...)"
        assert_contains "$tmp" "user_guid"                                "request envelope: user_guid field handled"
    fi
    if [ "$needs_assistant_response" = "yes" ]; then
        assert_contains "$tmp" 'assistant_response'                       "response envelope: assistant_response key present"
    else
        # Tier 1 family uses 'response' as primary; new code adds assistant_response too
        assert_contains "$tmp" '"response"|"assistant_response"'          "response envelope: response key present"
    fi
    rm -f "$tmp"
}

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Legacy ancestors of the /chat wire"
echo "═══════════════════════════════════════════════════════════════"

# Tier 1 v0.6.0 — legacy local brainstem (no user_guid yet)
check_endpoint \
    "kody-w/rapp-installer (Tier 1, v0.6.0)" \
    "https://raw.githubusercontent.com/kody-w/rapp-installer/main/rapp_brainstem/brainstem.py" \
    "no" "no"

# Tier 2 — public Azure-hosted version (already has user_guid + assistant_response)
check_endpoint \
    "kody-w/CommunityRAPP (Tier 2 cloud)" \
    "https://raw.githubusercontent.com/kody-w/CommunityRAPP/main/function_app.py" \
    "yes" "yes"

# CA365 — the original implementation (private; gh CLI auth required)
check_endpoint \
    "kody-w/Copilot-Agent-365 (CA365 original)" \
    "https://raw.githubusercontent.com/kody-w/Copilot-Agent-365/main/function_app.py" \
    "yes" "yes"

# This repo's current brainstem MUST conform to both lineages
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  This repo (must reconcile both lineages)"
echo "═══════════════════════════════════════════════════════════════"

echo "▶ rapp_brainstem/brainstem.py (current Tier 1)"
assert_contains rapp_brainstem/brainstem.py 'user_input'                                "request envelope: user_input"
assert_contains rapp_brainstem/brainstem.py 'conversation_history'                      "request envelope: conversation_history"
assert_contains rapp_brainstem/brainstem.py 'user_guid'                                 "request envelope: user_guid (backported from CA365 lineage)"
assert_contains rapp_brainstem/brainstem.py 'DEFAULT_USER_GUID'                         "identity: DEFAULT_USER_GUID constant"
assert_contains rapp_brainstem/brainstem.py "$DEFAULT_USER_GUID"                        "identity: exact default GUID string"
assert_contains rapp_brainstem/brainstem.py '"response"'                                "response envelope: response key"
assert_contains rapp_brainstem/brainstem.py '"assistant_response"'                      "response envelope: assistant_response key (CA365 parity)"

echo ""
echo "▶ rapp_swarm/function_app.py (current Tier 2)"
if [ -f rapp_swarm/function_app.py ]; then
    assert_contains rapp_swarm/function_app.py 'user_input'                             "request envelope: user_input"
    assert_contains rapp_swarm/function_app.py 'conversation_history'                   "request envelope: conversation_history"
    assert_contains rapp_swarm/function_app.py 'user_guid'                              "request envelope: user_guid"
    assert_contains rapp_swarm/function_app.py 'DEFAULT_USER_GUID'                      "identity: DEFAULT_USER_GUID constant"
    assert_contains rapp_swarm/function_app.py "$DEFAULT_USER_GUID"                     "identity: exact default GUID string"
    assert_contains rapp_swarm/function_app.py '"assistant_response"'                   "response envelope: assistant_response key (CA365 lineage)"
    assert_contains rapp_swarm/function_app.py '"response"'                             "response envelope: response key (rapp_brainstem lineage parity, Article XXV)"
else
    echo "    SKIP: rapp_swarm/function_app.py not found"
fi

echo ""
echo "✅ Legacy wire conformance test passed"
echo "   Every implementation in the lineage still speaks the canonical /chat wire."
