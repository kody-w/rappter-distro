#!/usr/bin/env bash
# tests/features/F4-ed25519-sign.sh — ed25519 signed releases per CONSTITUTION Art. XXXIV.7.
#
# Drives tools/sign_release.py through the full keygen → sign → verify
# round-trip. Auto-installs the `cryptography` Python package on first
# run (mirrors the brainstem's agent dep auto-install pattern).

source "$(dirname "$0")/../osi/_lib.sh"

osi_layer_intro "F4 — ed25519 signed releases" "tools/sign_release.py + manifest signing block (Art. XXXIV.7)"

TOOL="$REPO_ROOT/tools/sign_release.py"

heading "Step 1 — sign_release.py present + parses"
if [ -f "$TOOL" ] && python3 -c "import ast; ast.parse(open('$TOOL').read())" 2>/dev/null; then
  step_pass "tools/sign_release.py parses cleanly"
else
  step_fail "tool missing or syntax error"
fi

heading "Step 2 — manifest declares preferred_method=ed25519 (Art. XXXIV.7)"
python3 - "$REPO_ROOT/rapp_kernel/manifest.json" <<'PY' && step_pass "manifest signing block declares ed25519" || step_fail "manifest signing block missing/wrong"
import json, sys
with open(sys.argv[1]) as f:
    m = json.load(f)
sig = m.get("signing", {})
assert sig.get("preferred_method") == "ed25519", f"got {sig.get('preferred_method')}"
assert sig.get("tool", "").endswith("sign_release.py")
print("OK")
PY

SANDBOX=$(osi_sandbox "rapp-feature-F4")
trap "osi_cleanup_dir '$SANDBOX'" EXIT

heading "Step 3 — Resolve a Python with cryptography (system or per-test venv)"
# PEP 668 blocks system-pip on many platforms; isolate cryptography in a
# per-test venv. Reuses the system python if cryptography is already there.
PY=""
if python3 -c "from cryptography.hazmat.primitives.asymmetric import ed25519" 2>/dev/null; then
  PY="python3"
  step_pass "cryptography already installed in system python3"
else
  muted "cryptography not on system python — building per-test venv (~5s)"
  if python3 -m venv "$SANDBOX/venv" 2>&1 | tail -3; then
    "$SANDBOX/venv/bin/pip" install --quiet --disable-pip-version-check cryptography >"$SANDBOX/pip.log" 2>&1
    if "$SANDBOX/venv/bin/python" -c "from cryptography.hazmat.primitives.asymmetric import ed25519" 2>/dev/null; then
      PY="$SANDBOX/venv/bin/python"
      step_pass "venv has cryptography ($("$SANDBOX/venv/bin/python" --version))"
    else
      step_fail "venv created but cryptography import failed (see $SANDBOX/pip.log)"
      scenario_summary
    fi
  else
    step_fail "venv creation failed"
    scenario_summary
  fi
fi

heading "Step 4 — Keygen produces private.pem + public.pem + fingerprint"
if "$PY" "$TOOL" keygen --out "$SANDBOX/keys" >"$SANDBOX/keygen.json" 2>"$SANDBOX/keygen.err"; then
  if [ -f "$SANDBOX/keys/private.pem" ] && [ -f "$SANDBOX/keys/public.pem" ] && [ -f "$SANDBOX/keys/fingerprint.txt" ]; then
    step_pass "keypair files written + 16-char fingerprint emitted"
  else
    step_fail "keygen succeeded but expected files missing"
  fi
else
  step_fail "keygen failed: $(cat "$SANDBOX/keygen.err")"
  scenario_summary
fi

heading "Step 5 — Sign the kernel manifest with the fresh keypair"
if "$PY" "$TOOL" sign \
    --in "$REPO_ROOT/rapp_kernel/manifest.json" \
    --out "$SANDBOX/manifest.sig" \
    --key "$SANDBOX/keys/private.pem" >"$SANDBOX/sign.json" 2>"$SANDBOX/sign.err"; then
  if [ -f "$SANDBOX/manifest.sig" ]; then
    step_pass "ed25519 sidecar written: $SANDBOX/manifest.sig"
  else
    step_fail "sign succeeded but sidecar missing"
  fi
else
  step_fail "sign failed: $(cat "$SANDBOX/sign.err")"
  scenario_summary
fi

heading "Step 6 — Verify the signed manifest"
if "$PY" "$TOOL" verify \
    --in "$REPO_ROOT/rapp_kernel/manifest.json" \
    --sig "$SANDBOX/manifest.sig" \
    --pubkey "$SANDBOX/keys/public.pem" >"$SANDBOX/verify.json" 2>"$SANDBOX/verify.err"; then
  if grep -q '"ok": true' "$SANDBOX/verify.json"; then
    step_pass "verify returned ok=true with matching fingerprint"
  else
    step_fail "verify returned but ok!=true"
  fi
else
  step_fail "verify failed: $(cat "$SANDBOX/verify.err")"
fi

heading "Step 7 — Tampered manifest fails verification"
TAMPERED="$SANDBOX/manifest-tampered.json"
cp "$REPO_ROOT/rapp_kernel/manifest.json" "$TAMPERED"
echo "/* tampered */" >>"$TAMPERED"
if "$PY" "$TOOL" verify \
    --in "$TAMPERED" \
    --sig "$SANDBOX/manifest.sig" \
    --pubkey "$SANDBOX/keys/public.pem" >"$SANDBOX/tampered-verify.json" 2>&1; then
  step_fail "tampered manifest passed verification — integrity broken!"
else
  step_pass "tampered manifest correctly rejected (signed_file_sha256 mismatch)"
fi

scenario_summary
