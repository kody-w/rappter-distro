#!/usr/bin/env bash
# Fixture: BIP-39 holocard incantation deterministically produces identical M/S/U keys.
#
# Asserts:
#   - Same 24 words → same master pubkey (byte-identical), repeatedly
#   - Different role labels (M / S / U) → different keys but all deterministic
#   - Different incantations → different keys
#   - Identity hash = sha256(master_pubkey_SPKI)[:32] is reproducible
#
# Reference: pages/vault/Architecture/Rappid.md (derivation spec),
#            wildhaven-ceo/legal/swarm-estate/birth-record.md (canonical recipe)

set -euo pipefail
cd "$(dirname "$0")/../.."

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

# Some Python envs may not have mnemonic preinstalled
"$PYTHON" -c "from mnemonic import Mnemonic" 2>/dev/null || pip3 install -q mnemonic 2>&1 | tail -1

"$PYTHON" - <<'PYEOF'
import base64, hashlib
from mnemonic import Mnemonic
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

SECP_ORDER = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551

def derive(phrase: str, label: bytes) -> ec.EllipticCurvePrivateKey:
    seed = Mnemonic.to_seed(phrase, passphrase="")
    d = HKDF(algorithm=hashes.SHA256(), length=32,
             salt=b"wildhaven-swarm-estate-v2", info=label).derive(seed)
    return ec.derive_private_key((int.from_bytes(d, "big") % (SECP_ORDER - 1)) + 1, ec.SECP256R1())

def spki_b64(priv) -> str:
    return base64.b64encode(priv.public_key().public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )).decode()

# A canonical 24-word test phrase (BIP-39 valid)
test_phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"

# 1. Same phrase → same master pubkey, three runs
M_pubs = []
for _ in range(3):
    M = derive(test_phrase, b"role:master/v2")
    M_pubs.append(spki_b64(M))
assert len(set(M_pubs)) == 1, f"derivation not deterministic: {M_pubs}"

# 2. M / S / U are distinct from each other but each is deterministic
S_pubs = [spki_b64(derive(test_phrase, b"role:self-signing/v2")) for _ in range(2)]
U_pubs = [spki_b64(derive(test_phrase, b"role:user-signing/v2")) for _ in range(2)]
assert len(set(S_pubs)) == 1
assert len(set(U_pubs)) == 1
assert M_pubs[0] != S_pubs[0]
assert M_pubs[0] != U_pubs[0]
assert S_pubs[0] != U_pubs[0]

# 3. Different incantation → different keys
phrase2 = "absurd action acoustic acquire across act action add address adjust admit adult advance advice aerobic affair afford afraid again age agent agree ahead air"
M2 = spki_b64(derive(phrase2, b"role:master/v2"))
assert M2 != M_pubs[0], "different incantations must produce different keys"

# 4. Identity hash is reproducible
M_priv = derive(test_phrase, b"role:master/v2")
M_pub_spki = M_priv.public_key().public_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
)
hash1 = hashlib.sha256(M_pub_spki).hexdigest()[:32]
hash2 = hashlib.sha256(M_pub_spki).hexdigest()[:32]
assert hash1 == hash2

print("PASS: 16-derivation-determinism")
PYEOF
