"""
rappid.py — the unified rappid identifier.

A rappid is the public ID for every digital organism in the RAPP species
tree. One format, one species tree.

Canonical RAPP grammar (spec §6.1):

    rappid:@<owner>/<slug>:<64-hex>

Example (the species root, RAPP itself):

    rappid:@kody-w/rapp:9a8f0a4b5a710e20f4d819a0f37d2a4c9f113b5e78fb3c29e70b54fff48a38f9

The rappid STRING is deliberately minimal: owner, slug, and the 64-hex
identity hash. Everything else about an organism — its kind, host, repo,
home vault, lineage — lives as separate fields in its ``rappid.json``,
NOT inside the rappid string. (An earlier "v2" form crammed a version tag,
a kind, and an ``@home_vault_url`` suffix into the string; that drifted from
the RAPP standard and every live estate record now carries the canonical
minimal form, with the old string preserved under ``_migrated_from``.)

The species root — the godfather, RAPP itself — lives at the top of the
tree; every other organism declares parent_rappid pointing to its parent;
walking parent_rappid from any organism terminates at the species root.

Mitosis principle: same rappid = same organism. Different rappid = a
different organism (a child, by mitosis). The rappid IS the identity.

Identity is minted once (spec §6.2): keyless as ``Hb("rapp/1:rappid",
uuid4_bytes)``, keyed as ``Hb("rapp/1:rappid", SPKI_DER)`` — where
``Hb(space, b) = sha256(space + b"\\x0a" + b)``, full 64 hex, domain
separated. It is NEVER ``sha256("owner/slug")`` — hashing a name into an
address is the cardinal sin this protocol exists to end.
"""
from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from typing import Optional


SCHEMA_VERSION = "1"
"""The RAPP spec has revisions (rev-1, rev-2, …) and exactly one wire tag,
``rapp/1``. The rappid string itself carries no version segment; this
constant records which rev of the grammar this module implements."""


# Domain-separation tag for identity hashing (spec §3, §6.2). The keyed and
# keyless mints both hash into this space; verifiers recompute in it.
_RAPPID_SPACE = "rapp/1:rappid"


def Hb(space: str, b: bytes) -> str:
    """Domain-separated content address over raw bytes: the one hash rule.

    ``sha256(space + b"\\x0a" + b)`` as 64 lowercase hex. Identical to the
    reference implementation's ``Hb`` in kody-w/rapp-1 · rapp.py.
    """
    return hashlib.sha256(space.encode("utf-8") + b"\x0a" + b).hexdigest()


# Kinds: open enumeration. New values may be added as the species evolves.
# NOTE: kind is a field of an organism's rappid.json, not part of the rappid
# string. It is retained here only so callers that group organisms by kind
# have a shared vocabulary.
KNOWN_KINDS = {
    "prototype",       # the species root (RAPP itself)
    "kernel-variant",  # a forked code variant of RAPP
    "organism",        # an AI organism (Wildhaven AI Homes, customer entities)
    "twin",            # a sub-entity of an organism (Molly, personal twins)
    "swarm",           # a group of agents in training
    "rapplication",    # a graduated swarm, certified
    "agent",           # a single capability
    "neighborhood",    # a shared coordinate space of organisms
}
"""Reserved/known organism kinds. Verifiers SHOULD accept unknown kinds for
forward compatibility (the species is allowed to evolve new kinds)."""


# The species root — the godfather. Every rappid chains parent_rappid back
# here. Canonical form (spec §6.1): kody-w/RAPP's self rappid, whose
# parent_rappid is null. Load-bearing; do not edit without an amendment.
SPECIES_ROOT = (
    "rappid:@kody-w/rapp:"
    "9a8f0a4b5a710e20f4d819a0f37d2a4c9f113b5e78fb3c29e70b54fff48a38f9"
)


# Canonical grammar (spec §6.1). owner and slug are lowercase [a-z0-9] with
# internal single hyphens (no leading/trailing/double hyphens, no
# underscores); the hash is exactly 64 lowercase hex.
_LABEL = r"[a-z0-9]+(?:-[a-z0-9]+)*"
_RAPPID_RE = re.compile(
    r"^rappid:@(?P<publisher>" + _LABEL + r")/(?P<slug>" + _LABEL + r"):"
    r"(?P<hash>[0-9a-f]{64})$"
)


@dataclass(frozen=True)
class Rappid:
    """A parsed rappid. Immutable. Equality is by full string form
    (every field must match)."""

    publisher: str
    slug: str
    hash: str
    # Compatibility fields. Not part of the canonical rappid string — an
    # organism's kind/home vault live in its rappid.json. Kept so existing
    # callers (introspection organs, lineage display) don't break; they are
    # canonical constants for any string-parsed rappid.
    version: str = "1"
    kind: str = ""
    home_vault_url: str = ""

    @classmethod
    def parse(cls, s: str) -> "Rappid":
        """Parse a canonical rappid string. Raises ValueError on malformed
        input (which includes the legacy ``rappid:v2:…@vault`` form — that
        data must be migrated to the canonical grammar)."""
        if not isinstance(s, str):
            raise ValueError(f"rappid must be a string, got {type(s).__name__}")
        m = _RAPPID_RE.match(s.strip())
        if not m:
            raise ValueError(
                f"malformed rappid: {s!r}\n"
                f"expected canonical RAPP grammar: rappid:@<owner>/<slug>:<64-hex>"
            )
        return cls(
            publisher=m.group("publisher"),
            slug=m.group("slug"),
            hash=m.group("hash"),
        )

    @classmethod
    def try_parse(cls, s: str) -> Optional["Rappid"]:
        """Parse, returning None on failure instead of raising."""
        try:
            return cls.parse(s)
        except (ValueError, TypeError):
            return None

    def to_string(self) -> str:
        """Serialize back to the canonical rappid string."""
        return f"rappid:@{self.publisher}/{self.slug}:{self.hash}"

    def __str__(self) -> str:
        return self.to_string()

    @property
    def fingerprint(self) -> str:
        """Short, human-friendly identifier: '@pub/slug'.

        Useful for log lines, UI tags, error messages. Not unique across
        the species tree (multiple organisms can share pub/slug if they
        differ in hash); use the full rappid for uniqueness."""
        return f"@{self.publisher}/{self.slug}"

    @property
    def short_hash(self) -> str:
        """First 12 chars of the hash, for log display."""
        return self.hash[:12]

    def is_species_root(self) -> bool:
        """True iff this rappid is the species root (the godfather)."""
        return self.to_string() == SPECIES_ROOT

    def is_known_kind(self) -> bool:
        """True iff kind is in the reserved set. Unknown kinds are still
        valid rappids (forward compat); this is just a hint. Note kind is
        carried by rappid.json, not the rappid string, so a string-parsed
        Rappid reports kind='' (unknown) unless a caller sets it."""
        return self.kind in KNOWN_KINDS

    def is_cryptographically_backed(self, master_pubkey_spki_b64: Optional[str] = None) -> bool:
        """Check whether the hash field is the keyed mint of a master pubkey.

        Returns True iff a master_pubkey_spki_b64 is provided and the keyed
        mint ``Hb("rapp/1:rappid", SPKI_DER)`` equals this rappid's 64-hex
        hash (spec §6.2). Returns False if not provided (we can't verify
        cryptographic backing without the key) — callers should treat that
        as 'conventional / keyless' rather than 'invalid'.
        """
        if not master_pubkey_spki_b64:
            return False
        import base64
        try:
            spki = base64.b64decode(master_pubkey_spki_b64)
        except Exception:
            return False
        return Hb(_RAPPID_SPACE, spki) == self.hash

    def same_estate_as(self, other: "Rappid") -> bool:
        """True iff `other` shares this rappid's identity-hash. Used for
        'is this the same organism in a different location after
        migration?' Note: same hash + different publisher is
        cryptographically suspicious and probably means a forge attempt."""
        if not isinstance(other, Rappid):
            return False
        return self.hash == other.hash


def mint_keyless(uuid_bytes: bytes) -> str:
    """Keyless mint (spec §6.2): the 64-hex tail = Hb('rapp/1:rappid', uuid4).

    Pass the 16 raw bytes of a uuid4. Returns just the hash tail; compose
    the full rappid as ``rappid:@<owner>/<slug>:<tail>``."""
    return Hb(_RAPPID_SPACE, uuid_bytes)


def mint_keyed(spki_der: bytes) -> str:
    """Keyed mint (spec §6.2): the 64-hex tail = Hb('rapp/1:rappid', SPKI_DER)."""
    return Hb(_RAPPID_SPACE, spki_der)


def species_root() -> Rappid:
    """Return the parsed species root (the godfather, RAPP itself).

    This is the parent_rappid that every other organism's lineage chain
    eventually terminates at.
    """
    return Rappid.parse(SPECIES_ROOT)


__all__ = [
    "Rappid",
    "Hb",
    "mint_keyless",
    "mint_keyed",
    "SCHEMA_VERSION",
    "SPECIES_ROOT",
    "KNOWN_KINDS",
    "species_root",
]
