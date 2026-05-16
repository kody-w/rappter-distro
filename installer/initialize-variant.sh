#!/usr/bin/env bash
# initialize-variant.sh — for variants spawned directly from kody-w/RAPP
# (the species root) via GitHub's "Use this template" flow.
#
# Run from inside the freshly-created repository's working tree.
#
# Single-parent rule (Constitution Article XXXIV): a variant's parent is
# the repo whose code it inherited — no exceptions. This script ALWAYS
# sets parent_rappid to rapp's species root rappid, because if you got
# here, you templated from RAPP. Variants templated from a downstream
# RAPP variant (e.g., wildhaven-ai-homes-twin) should use that
# downstream's installer, not this one.
#
# What it does:
#   1. Verifies this is an uninitialized template clone (via lineage_check)
#   2. Generates a fresh rappid (UUIDv4)
#   3. Updates ONLY the lineage fields of rappid.json (rappid,
#      parent_rappid, parent_repo, parent_commit, born_at, name, role)
#   4. Prints next-step guidance
#
# What it does NOT do (rule: never overwrite local data):
#   - Does not touch any content files (README, CLAUDE.md, agents,
#     pages, rapp_brainstem internals, etc.). The variant inherits
#     RAPP's content as a starting point; edit it manually as the
#     variant takes its own shape.
#   - Does not delete or rewrite kind/description/private_companion or
#     any other rappid.json fields. Only lineage pointers are updated.

set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

if [ ! -f rappid.json ]; then
    echo "FAIL: no rappid.json at repo root. This script must run inside a"
    echo "      repo created from the kody-w/RAPP template."
    exit 1
fi

# ── Identity (hardcoded — single-parent rule) ────────────────────────────

# Species root v2-format rappid per CONSTITUTION Article XXXIV.1.
PARENT_RAPPID="rappid:v2:prototype:@rapp/origin:0b635450c04249fbb4b1bdb571044dec@github.com/kody-w/RAPP"
PARENT_REPO="https://github.com/kody-w/RAPP.git"

# ── Freshness check via lineage_check.py ─────────────────────────────────

LINEAGE_STATUS="$(python3 - <<'PYEOF'
import json, sys
sys.path.insert(0, "rapp_brainstem/utils")
try:
    from lineage_check import check_lineage
    info = check_lineage()
    print(info["status"])
except Exception as e:
    print(f"error:{e}")
PYEOF
)"

case "$LINEAGE_STATUS" in
    variant_uninitialized)
        : # Expected — proceed
        ;;
    self|master)
        echo "FAIL: this IS the rapp species-root repo itself. Refusing to"
        echo "      reinitialize the species root. If you meant to create a"
        echo "      variant, click 'Use this template' on GitHub first, then"
        echo "      run this script inside the new repo."
        exit 1
        ;;
    variant_initialized)
        echo "WARNING: this variant is already initialized. Re-running will"
        echo "         overwrite its rappid with a fresh one — descendants"
        echo "         that point at the current rappid will lose their link."
        read -p "Continue? [y/N] " confirm
        case "$confirm" in
            y|Y|yes|Yes) ;;
            *) echo "aborted."; exit 1 ;;
        esac
        ;;
    lineage_mismatch|no_rappid|error:*)
        echo "FAIL: lineage check returned: $LINEAGE_STATUS"
        echo "      Run: python3 rapp_brainstem/utils/lineage_check.py for details."
        exit 1
        ;;
    *)
        echo "FAIL: unexpected lineage status: $LINEAGE_STATUS"
        exit 1
        ;;
esac

# ── Variant name ─────────────────────────────────────────────────────────

DEFAULT_NAME="$(basename "$(git rev-parse --show-toplevel)")"
read -p "Variant name (default: $DEFAULT_NAME): " VARIANT_NAME
VARIANT_NAME="${VARIANT_NAME:-$DEFAULT_NAME}"

# ── Generate rappid ──────────────────────────────────────────────────────

# v2-format rappid per CONSTITUTION Article XXXIV.1. UUID hex (dashes
# stripped) as hash; pub/slug derived from this repo's git remote.
_VAR_OWNER="$(git config --get remote.origin.url 2>/dev/null | sed -nE 's#.*[/:]([^/]+)/[^/]+(\.git)?$#\1#p')"
_VAR_OWNER="${_VAR_OWNER:-anon}"
_VAR_REPO="$(git config --get remote.origin.url 2>/dev/null | sed -nE 's#.*/([^/]+)\.git$#\1#p; s#.*/([^/]+)$#\1#p' | head -1)"
_VAR_REPO="${_VAR_REPO:-$VARIANT_NAME}"
_VAR_HASH="$(python3 -c "import uuid; print(uuid.uuid4().hex)")"
NEW_RAPPID="rappid:v2:variant:@${_VAR_OWNER}/${_VAR_REPO}:${_VAR_HASH}@github.com/${_VAR_OWNER}/${_VAR_REPO}"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

PARENT_COMMIT="$(curl -fsSL "https://api.github.com/repos/kody-w/RAPP/commits/main" 2>/dev/null \
    | python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('sha',''))" 2>/dev/null || echo "")"

# ── Update rappid.json (lineage fields only — preserve everything else) ──

python3 - "$NEW_RAPPID" "$PARENT_RAPPID" "$PARENT_REPO" "$PARENT_COMMIT" "$NOW" "$VARIANT_NAME" <<'PYEOF'
import json
import sys

(rappid, parent_rappid, parent_repo, parent_commit, born_at, name) = sys.argv[1:7]

with open("rappid.json") as f:
    data = json.load(f)

# Update ONLY lineage fields. Preserve description, kind, private_companion,
# and any other content the user (or the parent) put there.
data["rappid"] = rappid
data["parent_rappid"] = parent_rappid
data["parent_repo"] = parent_repo
data["parent_commit"] = parent_commit or None
data["born_at"] = born_at
data["name"] = name
data["role"] = "variant"
data["schema"] = "rapp-rappid/2.0"
# attestation resets because the new rappid hasn't been attested yet.
data["attestation"] = None

with open("rappid.json", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

echo ""
echo "✓ rappid.json updated:"
echo "    rappid:         $NEW_RAPPID"
echo "    parent_rappid:  $PARENT_RAPPID  (rapp species root)"
echo "    parent_repo:    $PARENT_REPO"
echo "    parent_commit:  ${PARENT_COMMIT:-(could not resolve from network)}"
echo "    born_at:        $NOW"
echo "    name:           $VARIANT_NAME"

# ── Print next-step guidance ─────────────────────────────────────────────

REMOTE_URL="$(git config --get remote.origin.url 2>/dev/null || echo '')"

echo ""
echo "──────────────────────────────────────────────────────────────────────"
echo " Variant initialized as a direct child of rapp."
echo "──────────────────────────────────────────────────────────────────────"
echo ""
echo " Your variant inherits the entire RAPP repo layout — kernel, brainstem,"
echo " swarm, pages, installer — as content. The installer ONLY changed the"
echo " lineage fields in rappid.json; nothing else was touched. Edit local"
echo " files as the variant takes its own shape."
echo ""
echo " Next steps:"
echo "   1. Edit README.md / CLAUDE.md / rappid.json description to reflect"
echo "      your variant (the installer left them as-is)."
echo "   2. Remove components you don't need (rapp_swarm, pages, etc.) by"
echo "      editing them locally — the installer will not delete files."
echo "   3. If you want your variant to be a template too:"
echo "        gh repo edit \$(echo \"$REMOTE_URL\" | sed 's|.*github.com[:/]||;s|\\.git\$||') --template=true"
echo "      Then add YOUR rappid + canonical owner/repo to the"
echo "      KNOWN_TEMPLATE_REPOS dict in rapp_brainstem/utils/lineage_check.py"
echo "      so descendants of YOUR variant can detect uninitialized clones."
echo "   4. Commit + push:"
echo "        git add -A && git commit -m 'init: $VARIANT_NAME' && git push"
echo ""
echo " Lineage walk: your_rappid → $PARENT_RAPPID (rapp species root)"
echo ""
