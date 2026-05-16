#!/usr/bin/env python3
"""sign_release.py — ed25519 signing for rapp_kernel/manifest.json.

Implements CONSTITUTION Article XXXIV.7 "Signed releases and variant
attestation". ed25519 chosen as the canonical method (acceptable per the
article's open list); deterministic, fast verify, 32-byte pubkey, 64-byte
signature.

Produces a sigstore-bundle-shaped sidecar at the path supplied by the
caller; verifier walks `manifest.signing.verification_uri` to resolve the
public key and re-checks the signature locally.

Auto-installs `cryptography` on first run via pip — same pattern the
brainstem uses for agent dependencies (CLAUDE.md "Missing pip
dependencies are auto-installed at import time").

Usage:
    # Generate a fresh signing keypair (one-time per maintainer)
    python3 tools/sign_release.py keygen --out ~/.rapp/release-keys

    # Sign a kernel manifest
    python3 tools/sign_release.py sign \\
        --in   rapp_kernel/manifest.json \\
        --out  rapp_kernel/manifest.sig \\
        --key  ~/.rapp/release-keys/private.pem

    # Verify a signed manifest
    python3 tools/sign_release.py verify \\
        --in       rapp_kernel/manifest.json \\
        --sig      rapp_kernel/manifest.sig \\
        --pubkey   ~/.rapp/release-keys/public.pem
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys


def _ensure_cryptography():
    """Auto-install cryptography on first run (mirrors brainstem agent dep install)."""
    try:
        from cryptography.hazmat.primitives.asymmetric import ed25519  # noqa: F401
        return
    except ImportError:
        pass
    print("first-run setup: installing 'cryptography' via pip...", file=sys.stderr)
    try:
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "--quiet", "--user", "cryptography"],
            stderr=subprocess.STDOUT,
        )
    except subprocess.CalledProcessError as e:
        print(f"pip install failed: {e}", file=sys.stderr)
        print("install manually:  pip install --user cryptography", file=sys.stderr)
        sys.exit(2)
    # Ensure user-site is on path
    user_site = subprocess.check_output(
        [sys.executable, "-m", "site", "--user-site"], text=True
    ).strip()
    if user_site and user_site not in sys.path:
        sys.path.insert(0, user_site)


def _load_pem(path: str) -> bytes:
    with open(path, "rb") as f:
        return f.read()


def cmd_keygen(args):
    _ensure_cryptography()
    from cryptography.hazmat.primitives.asymmetric import ed25519
    from cryptography.hazmat.primitives import serialization

    out_dir = os.path.expanduser(args.out)
    os.makedirs(out_dir, exist_ok=True)

    priv = ed25519.Ed25519PrivateKey.generate()
    pub = priv.public_key()

    priv_pem = priv.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    pub_pem = pub.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )

    pub_raw = pub.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    fp = hashlib.sha256(pub_raw).hexdigest()[:16]

    priv_path = os.path.join(out_dir, "private.pem")
    pub_path = os.path.join(out_dir, "public.pem")
    fp_path = os.path.join(out_dir, "fingerprint.txt")

    with open(priv_path, "wb") as f: f.write(priv_pem)
    os.chmod(priv_path, 0o600)
    with open(pub_path, "wb") as f: f.write(pub_pem)
    with open(fp_path, "w") as f: f.write(fp + "\n")

    print(json.dumps({
        "ok": True,
        "schema": "rapp-release-key/1.0",
        "private_key": priv_path,
        "public_key": pub_path,
        "fingerprint": fp,
        "note": "Publish public.pem at the URL referenced by manifest.signing.verification_uri",
    }, indent=2))


def cmd_sign(args):
    _ensure_cryptography()
    from cryptography.hazmat.primitives.asymmetric import ed25519
    from cryptography.hazmat.primitives import serialization

    in_path = os.path.expanduser(args.input)
    out_path = os.path.expanduser(args.out)
    key_path = os.path.expanduser(args.key)

    with open(in_path, "rb") as f:
        body = f.read()
    file_hash = hashlib.sha256(body).hexdigest()

    priv = serialization.load_pem_private_key(_load_pem(key_path), password=None)
    if not isinstance(priv, ed25519.Ed25519PrivateKey):
        print("error: key is not ed25519", file=sys.stderr)
        sys.exit(2)

    sig = priv.sign(body)
    pub_raw = priv.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    fp = hashlib.sha256(pub_raw).hexdigest()[:16]

    sidecar = {
        "schema": "rapp-release-signature/1.0",
        "method": "ed25519",
        "signed_file": os.path.basename(in_path),
        "signed_file_sha256": file_hash,
        "signature_b64": base64.b64encode(sig).decode("ascii"),
        "publisher_fingerprint": fp,
        "signed_at": __import__("time").strftime("%Y-%m-%dT%H:%M:%SZ", __import__("time").gmtime()),
    }
    with open(out_path, "w") as f:
        json.dump(sidecar, f, indent=2)
    print(json.dumps({"ok": True, "sidecar": out_path, "fingerprint": fp,
                      "signed_file_sha256": file_hash}, indent=2))


def cmd_verify(args):
    _ensure_cryptography()
    from cryptography.hazmat.primitives.asymmetric import ed25519
    from cryptography.hazmat.primitives import serialization
    from cryptography.exceptions import InvalidSignature

    in_path = os.path.expanduser(args.input)
    sig_path = os.path.expanduser(args.sig)
    pub_path = os.path.expanduser(args.pubkey)

    with open(in_path, "rb") as f:
        body = f.read()
    file_hash = hashlib.sha256(body).hexdigest()
    with open(sig_path) as f:
        sidecar = json.load(f)
    pub = serialization.load_pem_public_key(_load_pem(pub_path))
    if not isinstance(pub, ed25519.Ed25519PublicKey):
        print(json.dumps({"ok": False, "error": "pubkey is not ed25519"}))
        sys.exit(2)
    if sidecar.get("signed_file_sha256") != file_hash:
        print(json.dumps({"ok": False, "error": "signed_file_sha256 mismatch",
                          "expected": sidecar.get("signed_file_sha256"),
                          "actual": file_hash}))
        sys.exit(1)
    sig = base64.b64decode(sidecar["signature_b64"])
    try:
        pub.verify(sig, body)
    except InvalidSignature:
        print(json.dumps({"ok": False, "error": "ed25519 signature invalid"}))
        sys.exit(1)

    pub_raw = pub.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    fp = hashlib.sha256(pub_raw).hexdigest()[:16]
    print(json.dumps({
        "ok": True,
        "signed_file": in_path,
        "signed_file_sha256": file_hash,
        "publisher_fingerprint": fp,
        "method": "ed25519",
    }, indent=2))


def main(argv=None):
    p = argparse.ArgumentParser(description="ed25519 signing for RAPP release manifests (Art. XXXIV.7)")
    sub = p.add_subparsers(dest="cmd", required=True)

    pk = sub.add_parser("keygen", help="Generate a fresh ed25519 keypair")
    pk.add_argument("--out", required=True, help="Output directory for private.pem + public.pem")
    pk.set_defaults(func=cmd_keygen)

    ps = sub.add_parser("sign", help="Sign a manifest file → sidecar")
    ps.add_argument("--in", dest="input", required=True)
    ps.add_argument("--out", required=True)
    ps.add_argument("--key", required=True)
    ps.set_defaults(func=cmd_sign)

    pv = sub.add_parser("verify", help="Verify a signed manifest")
    pv.add_argument("--in", dest="input", required=True)
    pv.add_argument("--sig", required=True)
    pv.add_argument("--pubkey", required=True)
    pv.set_defaults(func=cmd_verify)

    args = p.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
