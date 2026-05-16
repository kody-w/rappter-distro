"""
rappid.py — the unified rappid identifier.

A rappid is the public ID for every digital organism in the RAPP species
tree. One format, one species tree, ratified Constitution Articles XXXIV
and XXXVI on 2026-04-30.

Format:
    rappid:v2:<kind>:@<publisher>/<slug>:<hash>@<home_vault_url>

Example:
    rappid:v2:prototype:@rapp/origin:0b635450c04249fbb4b1bdb571044dec@github.com/kody-w/RAPP

The species root (the godfather, RAPP itself) lives at the top of the
tree; every other organism declares parent_rappid pointing to its parent;
walking parent_rappid from any organism terminates at the species root.

Mitosis principle: same rappid = same organism. Different rappid = a
different organism (a child, by mitosis). The rappid IS the identity.

Spec: pages/vault/Architecture/Rappid.md
Constitution: Articles XXXIV (rappid + lineage), XXXVI (swarm estate)
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Optional


SCHEMA_VERSION = "v2"
"""The current rappid format version. Bumped to v3 only if a future spec
introduces an incompatible format change. v2 supersedes the draft v1
UUID-only era ratified during early April 2026."""


# Kinds: open enumeration. New values may be added as the species evolves.
KNOWN_KINDS = {
    "prototype",       # the species root (RAPP itself)
    "kernel-variant",  # a forked code variant of RAPP
    "organism",        # an AI organism (Wildhaven AI Homes, customer entities)
    "twin",            # a sub-entity of an organism (Molly, personal twins)
    "swarm",           # a group of agents in training
    "rapplication",    # a graduated swarm, certified
    "agent",           # a single capability
}
"""Reserved/known organism kinds. Verifiers SHOULD accept unknown kinds for
forward compatibility (the species is allowed to evolve new kinds)."""


# The species root — the godfather. Every rappid chains parent_rappid
# back here. This constant is load-bearing; do not edit without a
# constitutional amendment.
SPECIES_ROOT = (
    "rappid:v2:prototype:@rapp/origin:"
    "0b635450c04249fbb4b1bdb571044dec"
    "@github.com/kody-w/RAPP"
)


# Format regex. Strict on prefix and version; permissive on the rest
# because publisher / slug / hash / home_vault_url have varying content.
_RAPPID_RE = re.compile(
    r"^rappid:"
    r"(?P<version>v\d+):"
    r"(?P<kind>[a-z][a-z0-9-]*):"
    r"@(?P<publisher>[a-z0-9][a-z0-9-]*)/(?P<slug>[a-z0-9][a-z0-9-]*):"
    r"(?P<hash>[A-Za-z0-9-]+)"
    r"@(?P<home_vault_url>.+)$"
)


@dataclass(frozen=True)
class Rappid:
    """A parsed rappid. Immutable. Equality is by full string form
    (every field must match)."""

    version: str
    kind: str
    publisher: str
    slug: str
    hash: str
    home_vault_url: str

    @classmethod
    def parse(cls, s: str) -> "Rappid":
        """Parse a rappid string. Raises ValueError on malformed input."""
        if not isinstance(s, str):
            raise ValueError(f"rappid must be a string, got {type(s).__name__}")
        m = _RAPPID_RE.match(s.strip())
        if not m:
            raise ValueError(
                f"malformed rappid: {s!r}\n"
                f"expected format: rappid:v2:<kind>:@<publisher>/<slug>:<hash>@<home_vault_url>"
            )
        return cls(
            version=m.group("version"),
            kind=m.group("kind"),
            publisher=m.group("publisher"),
            slug=m.group("slug"),
            hash=m.group("hash"),
            home_vault_url=m.group("home_vault_url"),
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
        return (
            f"rappid:{self.version}:{self.kind}:"
            f"@{self.publisher}/{self.slug}:"
            f"{self.hash}"
            f"@{self.home_vault_url}"
        )

    def __str__(self) -> str:
        return self.to_string()

    @property
    def fingerprint(self) -> str:
        """Short, human-friendly identifier: 'kind:@pub/slug'.

        Useful for log lines, UI tags, error messages. Not unique across
        the species tree (multiple organisms can share kind+pub+slug if
        they differ in hash); use the full rappid for uniqueness."""
        return f"{self.kind}:@{self.publisher}/{self.slug}"

    @property
    def short_hash(self) -> str:
        """First 12 chars of the hash, for log display."""
        return self.hash[:12]

    def is_species_root(self) -> bool:
        """True iff this rappid is the species root (the godfather)."""
        return self.to_string() == SPECIES_ROOT

    def is_known_kind(self) -> bool:
        """True iff kind is in the reserved set. Unknown kinds are still
        valid rappids (forward compat); this is just a hint."""
        return self.kind in KNOWN_KINDS

    def is_cryptographically_backed(self, master_pubkey_spki_b64: Optional[str] = None) -> bool:
        """Check whether the hash field is consistent with a master pubkey.

        Returns True iff a master_pubkey_spki_b64 is provided and its sha256
        truncates to this rappid's hash field. Returns False if not provided
        (we can't verify cryptographic backing without the key) — callers
        should treat that as 'conventional / unsigned' rather than 'invalid'.
        """
        if not master_pubkey_spki_b64:
            return False
        import base64, hashlib
        try:
            spki = base64.b64decode(master_pubkey_spki_b64)
        except Exception:
            return False
        return hashlib.sha256(spki).hexdigest()[:32] == self.hash

    def same_estate_as(self, other: "Rappid") -> bool:
        """True iff `other` shares this rappid's identity-hash. Used for
        'is this the same organism in a different home_vault_url after
        migration?' Note: same hash + different kind/publisher is
        cryptographically suspicious and probably means a forge attempt."""
        if not isinstance(other, Rappid):
            return False
        return self.hash == other.hash


def species_root() -> Rappid:
    """Return the parsed species root (the godfather, RAPP itself).

    This is the parent_rappid that every other organism's lineage chain
    eventually terminates at.
    """
    return Rappid.parse(SPECIES_ROOT)


__all__ = [
    "Rappid",
    "SCHEMA_VERSION",
    "SPECIES_ROOT",
    "KNOWN_KINDS",
    "species_root",
]
