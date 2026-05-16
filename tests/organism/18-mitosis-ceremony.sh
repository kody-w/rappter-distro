#!/usr/bin/env bash
# Fixture: minting a new rappid IS digital mitosis — child organism is born,
# parent organism is unchanged.
#
# Asserts:
#   - Mitosis produces a new master keypair (different from parent)
#   - The child's parent_rappid points back to the parent
#   - Walking the child's lineage terminates at the species root
#   - The parent's identity is unchanged (no mutation)
#
# Reference: Constitution Article XXXIV (mitosis principle),
#            pages/vault/Architecture/Rappid.md (mitosis ceremony)

set -euo pipefail
cd "$(dirname "$0")/../.."

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

"$PYTHON" -c "from mnemonic import Mnemonic" 2>/dev/null || pip3 install -q mnemonic 2>&1 | tail -1

# Synthetic vault — represents a parent organism's home
SYNTH=$(mktemp -d)
trap "rm -rf $SYNTH" EXIT

cd rapp_brainstem
"$PYTHON" - "$SYNTH" <<'PYEOF'
import sys, os, json, base64, hashlib, time
from pathlib import Path
from mnemonic import Mnemonic
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

sys.path.insert(0, '.')
from utils.rappid import Rappid, species_root
from utils.lineage import walk_lineage

vault = Path(sys.argv[1])
SECP_ORDER = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551

def derive(phrase, label):
    seed = Mnemonic.to_seed(phrase, passphrase="")
    d = HKDF(algorithm=hashes.SHA256(), length=32,
             salt=b"wildhaven-swarm-estate-v2", info=label).derive(seed)
    return ec.derive_private_key((int.from_bytes(d, "big") % (SECP_ORDER - 1)) + 1, ec.SECP256R1())

def spki(p):
    return p.public_key().public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )

def canonical(o):
    return json.dumps(o, sort_keys=True, separators=(",",":"), ensure_ascii=False).encode()

# 1. Mint a parent organism (the "Wildhaven-equivalent")
parent_phrase = Mnemonic("english").generate(strength=256)
parent_M = derive(parent_phrase, b"role:master/v2")
parent_M_spki = spki(parent_M)
parent_hash = hashlib.sha256(parent_M_spki).hexdigest()[:32]
parent_rappid_str = f"rappid:v2:organism:@test/parent:{parent_hash}@local"
parent_root = {
    "alg": "ecdsa-p256", "schema": "swarm-estate-record/1.0", "kind": "root",
    "rappid": parent_rappid_str,
    "issued_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "issued_by": f"fp:M:{parent_hash[:24]}", "issued_by_role": "M",
    "payload": {
        "parent_rappid": species_root().to_string(),
        "master_pubkey": base64.b64encode(parent_M_spki).decode(),
    },
}
parent_root["signature"] = base64.b64encode(parent_M.sign(canonical(parent_root), ec.ECDSA(hashes.SHA256()))).decode()
(vault / f"blessings/{parent_hash}").mkdir(parents=True, exist_ok=True)
(vault / f"blessings/{parent_hash}/root.json").write_text(json.dumps(parent_root, indent=2))

# 2. Capture parent identity BEFORE mitosis
parent_M_pub_before = base64.b64encode(parent_M_spki).decode()

# 3. Mitosis ceremony — mint a child organism
child_phrase = Mnemonic("english").generate(strength=256)
assert child_phrase != parent_phrase, "BIP-39 generation collisions are astronomically unlikely"

child_M = derive(child_phrase, b"role:master/v2")
child_M_spki = spki(child_M)
child_hash = hashlib.sha256(child_M_spki).hexdigest()[:32]
child_rappid_str = f"rappid:v2:twin:@test/child:{child_hash}@local"
child_root = {
    "alg": "ecdsa-p256", "schema": "swarm-estate-record/1.0", "kind": "root",
    "rappid": child_rappid_str,
    "issued_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "issued_by": f"fp:M:{child_hash[:24]}", "issued_by_role": "M",
    "payload": {
        "parent_rappid": parent_rappid_str,
        "master_pubkey": base64.b64encode(child_M_spki).decode(),
    },
}
child_root["signature"] = base64.b64encode(child_M.sign(canonical(child_root), ec.ECDSA(hashes.SHA256()))).decode()
(vault / f"blessings/{child_hash}").mkdir(parents=True, exist_ok=True)
(vault / f"blessings/{child_hash}/root.json").write_text(json.dumps(child_root, indent=2))

# 4. Assertions

# (a) Child's master pubkey is DIFFERENT from parent's (mitosis = new identity)
assert base64.b64encode(child_M_spki).decode() != parent_M_pub_before
assert child_hash != parent_hash

# (b) Child's parent_rappid points at parent
child_rappid = Rappid.parse(child_rappid_str)
parent_rappid = Rappid.parse(parent_rappid_str)
assert child_rappid != parent_rappid

# (c) Walk child's lineage: child → parent → species root
chain = walk_lineage(child_rappid, vault)
assert chain.terminated_at_species_root
assert chain.depth() == 2, f"expected depth 2, got {chain.depth()}"
assert chain.nodes[0].rappid == child_rappid
assert chain.nodes[1].rappid == parent_rappid
assert chain.nodes[-1].rappid.is_species_root()

# (d) Parent's identity is unchanged: re-read parent's root.json, verify same pubkey
with open(vault / f"blessings/{parent_hash}/root.json") as f:
    parent_root_after = json.load(f)
assert parent_root_after["payload"]["master_pubkey"] == parent_M_pub_before
assert parent_root_after["rappid"] == parent_rappid_str  # parent's rappid unchanged

# (e) Mitosis is a one-way operation: child cannot become parent
# (this is structural — there's no API to "rename" a rappid)

print("PASS: 18-mitosis-ceremony")
PYEOF
