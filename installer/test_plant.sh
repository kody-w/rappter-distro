#!/bin/bash
#
# test_plant.sh — dry-run + structural tests for plant.sh and the splash pages.
#
# Run from repo root:
#   bash installer/test_plant.sh
#
# Exit code: 0 if all tests pass, 1 if any fail.
# Output: one line per test, "PASS" or "FAIL" with details.

set -u   # not -e — we want to count failures, not bail on the first one

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER_DIR="$REPO_ROOT/installer"
GRAIL_RAW="https://raw.githubusercontent.com/kody-w/rapp-installer/main"

PASS=0
FAIL=0

# ── colors ────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

ok()   { printf "%sPASS%s  %s\n" "$GREEN" "$NC" "$*"; PASS=$((PASS+1)); }
fail() { printf "%sFAIL%s  %s\n" "$RED"   "$NC" "$*"; FAIL=$((FAIL+1)); }
section() { printf "\n%s%s%s\n" "$CYAN" "$*" "$NC"; }

# Helper: assert_file
assert_file() {
    local path="$1" desc="$2"
    if [ -f "$path" ]; then ok "$desc"; else fail "$desc (missing: $path)"; fi
}

# Helper: assert_contains
assert_contains() {
    local file="$1" pattern="$2" desc="$3"
    if grep -q -- "$pattern" "$file" 2>/dev/null; then
        ok "$desc"
    else
        fail "$desc (pattern '$pattern' not found in $file)"
    fi
}

assert_not_contains() {
    local file="$1" pattern="$2" desc="$3"
    if grep -q -- "$pattern" "$file" 2>/dev/null; then
        fail "$desc (unexpected pattern '$pattern' found in $file)"
    else
        ok "$desc"
    fi
}

# ── 1) plant.sh: syntax + presence ────────────────────────────────────
section "1) plant.sh — script existence & syntax"

assert_file "$INSTALLER_DIR/plant.sh" "plant.sh exists"

if bash -n "$INSTALLER_DIR/plant.sh" 2>/dev/null; then
    ok "plant.sh has valid bash syntax"
else
    fail "plant.sh has bash syntax errors"
fi

if [ -x "$INSTALLER_DIR/plant.sh" ]; then
    ok "plant.sh is executable"
else
    fail "plant.sh is not executable (chmod +x needed)"
fi

# ── 2) plant.sh: dry-run produces expected files ──────────────────────
section "2) plant.sh — dry run produces expected mirror tree"

DRY_DIR="$(mktemp -d)"
trap 'rm -rf "$DRY_DIR"' EXIT

DRY_OUT="$(
    PLANT_DRY_RUN=1 \
    PLANT_DRY_RUN_DIR="$DRY_DIR" \
    PLANT_GH_USER="testuser" \
    MIRROR_REPO_NAME="testmirror" \
    MIRROR_DISPLAY_NAME="Test Mirror" \
    bash "$INSTALLER_DIR/plant.sh" 2>&1
)" || { fail "dry run exited non-zero"; echo "$DRY_OUT" | sed 's/^/  /'; }

if echo "$DRY_OUT" | grep -q "Dry run complete"; then
    ok "dry run reports completion"
else
    fail "dry run did not complete cleanly"
fi

# Files we expect after dry-run
for f in \
    "rapp_brainstem/brainstem.py" \
    "rapp_brainstem/VERSION" \
    "rapp_brainstem/agents/basic_agent.py" \
    "installer/install.sh" \
    "rappid.json" \
    "README.md" \
    "index.html" \
    ".gitignore"
do
    assert_file "$DRY_DIR/$f" "dry-run output: $f"
done

# ── 3) Kernel byte-equality with grail ────────────────────────────────
section "3) Kernel byte-equality (drift check)"

for f in rapp_brainstem/brainstem.py rapp_brainstem/VERSION rapp_brainstem/agents/basic_agent.py; do
    if diff -q <(curl -fsSL "$GRAIL_RAW/$f") "$DRY_DIR/$f" >/dev/null 2>&1; then
        ok "byte-identical to grail: $f"
    else
        fail "drift vs grail: $f"
    fi
done

# ── 4) install.sh wrapper points at grail raw URL ─────────────────────
section "4) install.sh wrapper — drift-proofing"

INSTALL_SH="$DRY_DIR/installer/install.sh"
assert_contains "$INSTALL_SH" "raw.githubusercontent.com/kody-w/rapp-installer/main/install.sh" \
    "install.sh re-fetches grail's install.sh on every run"
assert_contains "$INSTALL_SH" 'bash -s --' \
    "install.sh forwards args to grail's installer"

# ── 5) rappid.json — schema sanity ────────────────────────────────────
section "5) rappid.json — schema sanity"

if python3 -c "import json; json.load(open('$DRY_DIR/rappid.json'))" 2>/dev/null; then
    ok "rappid.json is valid JSON"
else
    fail "rappid.json is not valid JSON"
fi

python3 - <<EOF
import json, sys
with open("$DRY_DIR/rappid.json") as f:
    d = json.load(f)
required = ["schema", "rappid", "kind", "name", "display_name",
            "github", "url", "parent_rappid", "parent_repo",
            "planted_by", "planted_at", "kernel_version"]
missing = [k for k in required if k not in d]
if missing:
    print("FAIL  rappid.json missing keys:", missing)
    sys.exit(1)
SPECIES_ROOT = "rappid:@kody-w/rapp:9a8f0a4b5a710e20f4d819a0f37d2a4c9f113b5e78fb3c29e70b54fff48a38f9"
import re
# RAPP §6.1 grammar: rappid:@<owner>/<slug>:<64hex>, owner/slug lowercase alnum + single hyphens
RAPPID_RE = re.compile(r"^rappid:@[a-z0-9]+(?:-[a-z0-9]+)*/[a-z0-9]+(?:-[a-z0-9]+)*:[0-9a-f]{64}$")
checks = [
    (d["schema"] == "rapp/1",                "schema is rapp/1 (§12)"),
    (d["kind"] == "mirror",                  "kind is mirror"),
    (d["name"] == "testmirror",              "name matches dry-run input"),
    (d["display_name"] == "Test Mirror",     "display_name matches input"),
    (d["planted_by"] == "testuser",          "planted_by matches input"),
    (d["kernel_version"] == "0.6.0",         "kernel_version is 0.6.0"),
    (d["parent_rappid"] == SPECIES_ROOT,     "parent_rappid is canonical §6.1 species root"),
    (bool(RAPPID_RE.match(d["rappid"])),     "rappid matches §6.1 grammar (rappid:@owner/slug:64hex)"),
    (d["rappid"].count("@") == 1,            "rappid has exactly one @ (no v2 host suffix)"),
    (":v2:" not in d["rappid"],              "rappid is NOT a legacy v2 string"),
]
for ok_, desc in checks:
    print(("PASS" if ok_ else "FAIL") + "  " + desc)
sys.exit(0 if all(c[0] for c in checks) else 2)
EOF
RC=$?
if [ $RC -eq 0 ]; then
    PASS=$((PASS + 9))
elif [ $RC -eq 1 ]; then
    FAIL=$((FAIL + 1))
else
    FAIL=$((FAIL + 9))
fi

# ── 6) index.html — placeholders substituted, peerjs embedded ─────────
section "6) index.html — substitutions & embedded deps"

INDEX="$DRY_DIR/index.html"

assert_not_contains "$INDEX" '__DISPLAY_NAME__' "no leftover __DISPLAY_NAME__ placeholder"
assert_not_contains "$INDEX" '__REPO_NAME__'    "no leftover __REPO_NAME__ placeholder"
assert_not_contains "$INDEX" '__GH_USER__'      "no leftover __GH_USER__ placeholder"
assert_not_contains "$INDEX" '__RAPPID__'       "no leftover __RAPPID__ placeholder"
assert_not_contains "$INDEX" '__URL__'          "no leftover __URL__ placeholder"
assert_not_contains "$INDEX" '__LINEAGE_HTML__' "no leftover __LINEAGE_HTML__ placeholder"

assert_contains "$INDEX" "Test Mirror"          "display name rendered"
assert_contains "$INDEX" "testmirror"           "repo slug rendered"
assert_contains "$INDEX" "testuser"             "github user rendered"

assert_contains "$INDEX" "peerjs@1.5.4"         "PeerJS CDN script embedded"
assert_contains "$INDEX" 'id="my-id"'           "tether: my-id element present"
assert_contains "$INDEX" 'id="peer-id-input"'   "tether: peer-id input present"
assert_contains "$INDEX" 'id="chat-input"'      "tether: chat-input present"
assert_contains "$INDEX" 'id="card-back-qr"'    "Trade-card back QR present (front-door QR moved to card back)"
assert_contains "$INDEX" 'id="install-cmd"'     "install command element present"

# Auto-tether via ?peer= URL param
assert_contains "$INDEX" 'params.get("peer")'   "auto-tether on ?peer= URL param"

# ── 7) plant.html (splash) — exists, has device branches ──────────────
section "7) plant.html splash page"

assert_file "$INSTALLER_DIR/plant.html" "plant.html exists"
assert_contains "$INSTALLER_DIR/plant.html" 'id="pane-desktop"' "desktop pane present"
assert_contains "$INSTALLER_DIR/plant.html" 'id="pane-mobile"'  "mobile pane present"
assert_contains "$INSTALLER_DIR/plant.html" 'isMobile'           "device-detection function present"
assert_contains "$INSTALLER_DIR/plant.html" 'plant.sh | bash'    "install command shown"
assert_contains "$INSTALLER_DIR/plant.html" 'MIRROR_PARENT'      "lineage env var supported"
assert_contains "$INSTALLER_DIR/plant.html" 'navigator.share'    "Web Share API used for mobile share"

# ── 8) plant_qr.html — QR generator ──────────────────────────────────
section "8) plant_qr.html QR generator"

assert_file "$INSTALLER_DIR/plant_qr.html" "plant_qr.html exists"
assert_contains "$INSTALLER_DIR/plant_qr.html" 'api.qrserver.com' "QR server endpoint used"
assert_contains "$INSTALLER_DIR/plant_qr.html" 'id="target-url"'  "target URL input present"
assert_contains "$INSTALLER_DIR/plant_qr.html" 'id="from-handle"' "from-handle input present"
assert_contains "$INSTALLER_DIR/plant_qr.html" 'window.print'     "print button wired"
assert_contains "$INSTALLER_DIR/plant_qr.html" 'plant.html'       "default target is plant.html"

# ── 9) installer/install.sh (the RAPP one, top-level) ─────────────────
# RAPP is the "first planted mirror" with its own customized install
# ceremony (bond cycle, --here mode, agent-assist handshake, etc.). The
# strict thin-wrapper check applies to *newly planted* mirrors (covered
# in section 4), not to RAPP itself. Here we only verify install.sh
# exists and is a runnable shell script — the kernel-equality check in
# section 10 is what proves RAPP delivers the canonical kernel bytes.
section "9) RAPP/installer/install.sh — exists and runnable"

RAPP_INSTALL_SH="$INSTALLER_DIR/install.sh"
assert_file "$RAPP_INSTALL_SH" "RAPP installer/install.sh exists"
if head -1 "$RAPP_INSTALL_SH" | grep -qE '^#!/(usr/bin/env )?bash'; then
    ok "RAPP install.sh has a bash shebang"
else
    fail "RAPP install.sh missing bash shebang"
fi

# ── 10) Local kernel files match grail (this repo *is* a mirror) ──────
section "10) RAPP itself — kernel byte-equality with grail"

for f in rapp_brainstem/brainstem.py rapp_brainstem/VERSION rapp_brainstem/agents/basic_agent.py; do
    if diff -q <(curl -fsSL "$GRAIL_RAW/$f") "$REPO_ROOT/$f" >/dev/null 2>&1; then
        ok "RAPP self-mirror compliant: $f"
    else
        fail "RAPP self-mirror DRIFT: $f"
    fi
done

# ── summary ───────────────────────────────────────────────────────────
echo ""
TOTAL=$((PASS + FAIL))
if [ $FAIL -eq 0 ]; then
    printf "%s═══════════════════════════════════════════%s\n" "$GREEN" "$NC"
    printf "%s  ALL %d TESTS PASSED%s\n" "$GREEN" "$TOTAL" "$NC"
    printf "%s═══════════════════════════════════════════%s\n" "$GREEN" "$NC"
    exit 0
else
    printf "%s═══════════════════════════════════════════%s\n" "$RED" "$NC"
    printf "%s  %d/%d FAILED%s\n" "$RED" "$FAIL" "$TOTAL" "$NC"
    printf "%s═══════════════════════════════════════════%s\n" "$RED" "$NC"
    exit 1
fi
