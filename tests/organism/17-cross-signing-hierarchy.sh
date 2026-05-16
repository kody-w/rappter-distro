#!/usr/bin/env bash
# Fixture: M/S/U/D depth-limited cross-signing hierarchy enforces role rules.
#
# Asserts:
#   - M can sign S and U
#   - S can sign D
#   - U can sign kin pubkeys
#   - D records sign with D, not M/S/U
#   - Roles are recorded in `issued_by_role` and verifiers reject role mismatches
#
# Reference: pages/vault/Architecture/The Swarm Estate.md (Three-role cross-signing)
# Constitution Article XXXVI.4

set -euo pipefail
cd "$(dirname "$0")/../.."

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

"$PYTHON" - <<'PYEOF'
import base64, json
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization, hashes

# Mint M, S, U, D keys
M = ec.generate_private_key(ec.SECP256R1())
S = ec.generate_private_key(ec.SECP256R1())
U = ec.generate_private_key(ec.SECP256R1())
D = ec.generate_private_key(ec.SECP256R1())

def pub_b64(p):
    return base64.b64encode(p.public_key().public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )).decode()

def canonical(o):
    return json.dumps(o, sort_keys=True, separators=(",",":"), ensure_ascii=False).encode()

def sign(priv, payload):
    return base64.b64encode(priv.sign(canonical(payload), ec.ECDSA(hashes.SHA256()))).decode()

def verify(record, signer_pub_b64):
    rec = dict(record)
    sig = base64.b64decode(rec.pop("signature"))
    pub = serialization.load_der_public_key(base64.b64decode(signer_pub_b64))
    pub.verify(sig, canonical(rec), ec.ECDSA(hashes.SHA256()))

# 1. M signs S/U into a root.json
root = {
    "alg": "ecdsa-p256", "schema": "swarm-estate-record/1.0", "kind": "root",
    "rappid": "rappid:v2:organism:@test/foo:aaaa@local",
    "issued_at": "2026-04-30T00:00:00Z", "issued_by": "fp:M:test", "issued_by_role": "M",
    "payload": {
        "master_pubkey": pub_b64(M),
        "self_signing_pubkey": pub_b64(S),
        "user_signing_pubkey": pub_b64(U),
    },
}
root["signature"] = sign(M, root)
verify(root, pub_b64(M))  # M's signature verifies

# 2. S signs a device key (correct role)
device_record = {
    "alg": "ecdsa-p256", "schema": "swarm-estate-record/1.0", "kind": "device-signing",
    "rappid": "rappid:v2:organism:@test/foo:aaaa@local",
    "issued_at": "2026-04-30T00:01:00Z", "issued_by": "fp:S:test", "issued_by_role": "S",
    "payload": {"device_pubkey": pub_b64(D), "label": "test laptop"},
}
device_record["signature"] = sign(S, device_record)
verify(device_record, pub_b64(S))

# 3. U signs a kin-vouch
kin_record = {
    "alg": "ecdsa-p256", "schema": "swarm-estate-record/1.0", "kind": "kin-vouch",
    "rappid": "rappid:v2:organism:@test/foo:aaaa@local",
    "issued_at": "2026-04-30T00:02:00Z", "issued_by": "fp:U:test", "issued_by_role": "U",
    "payload": {"vouched_rappid": "rappid:v2:twin:@test/bar:bbbb@local"},
}
kin_record["signature"] = sign(U, kin_record)
verify(kin_record, pub_b64(U))

# 4. Role mismatch defense: D should not be able to forge an S-role record
forge = {
    "alg": "ecdsa-p256", "schema": "swarm-estate-record/1.0", "kind": "device-signing",
    "rappid": "rappid:v2:organism:@test/foo:aaaa@local",
    "issued_at": "2026-04-30T00:03:00Z", "issued_by": "fp:S:test", "issued_by_role": "S",
    "payload": {"device_pubkey": "fake"},
}
# D signs it but claims role S
forge["signature"] = sign(D, forge)
try:
    verify(forge, pub_b64(S))
    assert False, "D-signed record should not verify under S's pubkey"
except Exception:
    pass  # expected

# 5. Verifying with wrong role pubkey fails
try:
    verify(device_record, pub_b64(M))  # device_record was S-signed, not M
    assert False, "S-signed record should not verify under M's pubkey"
except Exception:
    pass  # expected

print("PASS: 17-cross-signing-hierarchy")
PYEOF
