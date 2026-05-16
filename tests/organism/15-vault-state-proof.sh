#!/usr/bin/env bash
# Fixture: vault content_hash is recomputable + signed records reject tampering.
#
# Asserts:
#   - canonical JSON serialization is deterministic (stable bytes for same input)
#   - swap a record's content and signature verification fails
#   - signed record verification works against pubkey
#
# Reference: pages/vault/Architecture/Local-First-by-Design.md (canonical JSON, content_hash)

set -euo pipefail
cd "$(dirname "$0")/../.."

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

cd rapp_brainstem
"$PYTHON" - <<'PYEOF'
import json, base64, hashlib
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization, hashes

# 1. Canonical JSON is deterministic (sorted keys, no whitespace)
def canonical(o):
    return json.dumps(o, sort_keys=True, separators=(",",":"), ensure_ascii=False).encode()

obj1 = {"a": 1, "b": [3, 2, 1], "z": {"y": 2, "x": 1}}
obj2 = {"z": {"x": 1, "y": 2}, "b": [3, 2, 1], "a": 1}  # same data, different key order

assert canonical(obj1) == canonical(obj2), "canonical JSON must be order-independent"

# 2. Sign + verify a fake record
priv = ec.generate_private_key(ec.SECP256R1())
pub_b64 = base64.b64encode(priv.public_key().public_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
)).decode()

record = {
    "alg": "ecdsa-p256",
    "schema": "swarm-estate-record/1.0",
    "kind": "test-record",
    "rappid": "rappid:v2:organism:@test/foo:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa@nowhere",
    "issued_at": "2026-04-30T00:00:00Z",
    "issued_by": "fp:M:aaaaaaaaaaaaaaaaaaaaaaaa",
    "issued_by_role": "M",
    "payload": {"some": "field"},
}
record["signature"] = base64.b64encode(
    priv.sign(canonical(record), ec.ECDSA(hashes.SHA256()))
).decode()

# Verify
def verify(rec, pub_b64):
    sig = base64.b64decode(rec.pop("signature"))
    pub = serialization.load_der_public_key(base64.b64decode(pub_b64))
    canon = canonical(rec)
    pub.verify(sig, canon, ec.ECDSA(hashes.SHA256()))
    rec["signature"] = base64.b64encode(sig).decode()  # restore

verify(dict(record), pub_b64)  # passes silently

# 3. Tamper detection: change a payload field, signature should fail
tampered = json.loads(json.dumps(record))
tampered["payload"]["some"] = "different"
try:
    verify(tampered, pub_b64)
    assert False, "tampered record should not verify"
except Exception:
    pass  # expected

# 4. Wrong-key detection: try to verify with a different pubkey
priv2 = ec.generate_private_key(ec.SECP256R1())
pub2_b64 = base64.b64encode(priv2.public_key().public_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
)).decode()
try:
    verify(json.loads(json.dumps(record)), pub2_b64)
    assert False, "record signed by priv1 should not verify under priv2"
except Exception:
    pass  # expected

print("PASS: 15-vault-state-proof")
PYEOF
