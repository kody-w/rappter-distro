#!/bin/bash
# tests/test-twin-egg.sh — pack/unpack/info round-trip for .egg snapshots.
#
# Verifies:
#   1. Pack captures a TWINS_HOME into a single .egg zipfile
#   2. Manifest carries schema=rapp-egg/1.0, twins[], file SHA-256 hashes
#   3. Unpack restores byte-identical state into a fresh dir
#   4. Round-trip preserves: workspace.json, swarms, documents, inbox,
#      outbox, AND .shared/ (in-flight pipeline state)
#   5. Transient files (server.pid, server.log) are excluded
#   6. info command reads manifest without extracting

set -e
set -o pipefail

PASS=0
FAIL=0
FAIL_NAMES=()

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name"; echo "      expected: $expected"; echo "      actual:   $actual"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

assert_contains() {
    local name="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "  ✓ $name"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name"; echo "      needle:    $needle"; echo "      haystack:  $(echo "$haystack" | head -c 200)"
        FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

assert_file() {
    local name="$1" path="$2"
    if [ -f "$path" ]; then
        echo "  ✓ $name (exists)"; PASS=$((PASS + 1))
    else
        echo "  ✗ $name (missing: $path)"; FAIL=$((FAIL + 1)); FAIL_NAMES+=("$name")
    fi
}

# ── Setup: a synthetic TWINS_HOME ────────────────────────────────────

SRC=/tmp/rapp-egg-test-src
DST=/tmp/rapp-egg-test-dst
EGG=/tmp/rapp-egg-test.egg
chmod -R u+w $SRC $DST 2>/dev/null || true
rm -rf $SRC $DST $EGG

mkdir -p $SRC/kody/{swarms/abc,documents,inbox,outbox}
mkdir -p $SRC/molly/{swarms,documents}
mkdir -p $SRC/.shared/book-factory

# Kody twin state
echo '{"name":"kody","port":7142,"created_at":"2026-04-19T00:00:00Z"}' > $SRC/kody/workspace.json
echo 'kody source notes'                                                    > $SRC/kody/documents/notes.md
echo 'inbox-doc-from-molly'                                                 > $SRC/kody/inbox/molly_q3.md
echo '{"name":"@bf/sample"}'                                                > $SRC/kody/swarms/abc/manifest.json

# Molly twin state
echo '{"name":"molly","port":7094}'           > $SRC/molly/workspace.json
echo 'molly contact list'                     > $SRC/molly/documents/contacts.md

# Shared book-factory state (the kind of artifact the user wants captured)
echo '# source material'                      > $SRC/.shared/book-factory/00-source.md
echo '# draft'                                > $SRC/.shared/book-factory/01-draft.md

# Transient files that MUST be excluded
echo '12345'                                  > $SRC/kody/server.pid
echo 'lots of log lines'                      > $SRC/kody/server.log
echo '...'                                    > $SRC/molly/server.log

# ── Pack ─────────────────────────────────────────────────────────────

cd /Users/kodyw/Documents/GitHub/Rappter/RAPP

echo ""
echo "--- pack ---"
TWINS_HOME=$SRC bash rapp_swarm/twin-egg.sh pack --out $EGG > /tmp/egg-pack.out
PACKED_LINE=$(grep "packed" /tmp/egg-pack.out)
assert_contains "pack reports 2 twins"  "2 twin"  "$PACKED_LINE"
assert_file "egg file produced"  "$EGG"

# ── Info ─────────────────────────────────────────────────────────────

echo ""
echo "--- info ---"
INFO=$(bash rapp_swarm/twin-egg.sh info $EGG)
assert_contains "info: rapp-egg/1.0 schema"  "rapp-egg/1.0"  "$INFO"
assert_contains "info: kody twin listed"     "kody"          "$INFO"
assert_contains "info: molly twin listed"    "molly"         "$INFO"

# Verify manifest internals via direct python
python3 - <<PY
import zipfile, json
m = json.loads(zipfile.ZipFile("$EGG").read("egg-manifest.json"))
assert m["schema"] == "rapp-egg/1.0", f"schema: {m['schema']}"
assert m["egg_version"] == 1, f"version: {m['egg_version']}"
assert len(m["twins"]) == 2, f"twin count: {len(m['twins'])}"
assert any(t["handle"] == "kody"  for t in m["twins"]), "kody missing"
assert any(t["handle"] == "molly" for t in m["twins"]), "molly missing"
# Every file has a SHA-256
assert all(f.get("sha256") for f in m["files"]), "missing SHA"
# Transient files excluded
arcs = {f["arc"] for f in m["files"]}
assert not any("server.pid" in a for a in arcs), "server.pid leaked into egg!"
assert not any("server.log" in a for a in arcs), "server.log leaked into egg!"
# Shared dir captured
assert any(a.startswith("shared/book-factory/") for a in arcs), "shared/ dir missed"
print("  ✓ manifest schema + version + 2 twins + SHA-256 on all files")
print("  ✓ transient files (server.pid/log) excluded")
print("  ✓ .shared/book-factory captured under shared/ in archive")
PY

# ── Unpack into fresh dir ────────────────────────────────────────────

echo ""
echo "--- unpack ---"
TWINS_HOME=$DST bash rapp_swarm/twin-egg.sh unpack $EGG --into $DST > /tmp/egg-unpack.out
RESTORED=$(grep "restored" /tmp/egg-unpack.out || echo "")
assert_contains "unpack: SHA verified"  "all SHA"          "$(cat /tmp/egg-unpack.out)"
assert_contains "unpack: 2 twins restored" "restored 2 twin" "$RESTORED"

# Per-file byte-identical restore
echo ""
echo "--- byte-identical restore checks ---"
diff -q $SRC/kody/workspace.json   $DST/kody/workspace.json   >/dev/null && \
    { echo "  ✓ kody/workspace.json bit-identical"; PASS=$((PASS+1)); } || \
    { echo "  ✗ kody/workspace.json differs"; FAIL=$((FAIL+1)); FAIL_NAMES+=("workspace.json"); }
diff -q $SRC/kody/documents/notes.md $DST/kody/documents/notes.md >/dev/null && \
    { echo "  ✓ kody/documents/notes.md bit-identical"; PASS=$((PASS+1)); } || \
    { echo "  ✗ documents differ"; FAIL=$((FAIL+1)); FAIL_NAMES+=("docs"); }
diff -q $SRC/kody/inbox/molly_q3.md  $DST/kody/inbox/molly_q3.md >/dev/null && \
    { echo "  ✓ kody/inbox/molly_q3.md bit-identical"; PASS=$((PASS+1)); } || \
    { echo "  ✗ inbox differs"; FAIL=$((FAIL+1)); FAIL_NAMES+=("inbox"); }
diff -q $SRC/.shared/book-factory/01-draft.md $DST/.shared/book-factory/01-draft.md >/dev/null && \
    { echo "  ✓ .shared/book-factory/01-draft.md bit-identical (workflow state preserved)"; PASS=$((PASS+1)); } || \
    { echo "  ✗ shared/ differs"; FAIL=$((FAIL+1)); FAIL_NAMES+=("shared"); }

# Verify exclusions
echo ""
echo "--- exclusions ---"
[ ! -f "$DST/kody/server.pid" ] && \
    { echo "  ✓ server.pid NOT restored (correctly excluded)"; PASS=$((PASS+1)); } || \
    { echo "  ✗ server.pid was restored!"; FAIL=$((FAIL+1)); FAIL_NAMES+=("excl-pid"); }
[ ! -f "$DST/kody/server.log" ] && \
    { echo "  ✓ server.log NOT restored (correctly excluded)"; PASS=$((PASS+1)); } || \
    { echo "  ✗ server.log was restored!"; FAIL=$((FAIL+1)); FAIL_NAMES+=("excl-log"); }

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"
echo "  $PASS passed, $FAIL failed"
echo "════════════════════════════════════════"
[ $FAIL -gt 0 ] && { for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done; exit 1; }
exit 0
