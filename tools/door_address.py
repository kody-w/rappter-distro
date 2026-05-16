"""door_address — pure derivation of a door's canonical URL set from its rappid.

Authority: pages/docs/ESTATE_SPEC.md (CONSTITUTION Article XLVI).

This is the SINGLE implementation of the Estate Spec's `door_from_rappid()`
contract (ESTATE_SPEC §5). Every consumer that maps rappid → door URLs uses
this module — never reinvents the parsing, never patches around it.

Per Article XLVI.5 (No Fallbacks; Spec Says What's True): an invalid rappid
raises InvalidRappidError. There is no "best-effort" mode, no `local.github.io`
workaround, no "guess the kind from the name." The string either matches the
spec or it doesn't.

Pure stdlib. Zero deps. Importable from agents/, tools/, tests/, or anywhere.
"""

from __future__ import annotations

import re


# Canonical v2 rappid regex — anchored, no wiggle room.
# rappid:v2:<kind>:@<owner>/<repo>:<32-hex-no-dashes>@github.com/<owner2>/<repo2>
# Where (owner, repo) MUST equal (owner2, repo2) — that equality is checked
# explicitly below because regex backreferences make the pattern unreadable.
_RAPPID_RE = re.compile(
    r"^rappid:v2:"
    r"(?P<kind>[a-z][a-z0-9-]*):"
    r"@(?P<owner>[A-Za-z0-9][A-Za-z0-9._-]*)/(?P<repo>[A-Za-z0-9][A-Za-z0-9._-]*):"
    r"(?P<hex>[a-f0-9]{32})"
    r"@github\.com/(?P<owner2>[A-Za-z0-9][A-Za-z0-9._-]*)/(?P<repo2>[A-Za-z0-9][A-Za-z0-9._-]*)$"
)


# Per ESTATE_SPEC §1: valid kinds are frozen as of 2026-05-09. Adding a kind
# requires a CONSTITUTION amendment because every consumer derives behavior
# from this token.
VALID_KINDS = frozenset({
    "twin", "neighborhood", "ant-farm", "braintrust", "workspace",
    "hatched", "rapplication", "prototype", "operator",
})


# Per ESTATE_SPEC §2: door type is deterministic from kind.
# `twin` is a single AI presence (front door); everything else is a community
# AI you enter to find others (gate). The `operator` kind names a person's
# personal brainstem identity, which functions as their own front door.
def _door_type_for_kind(kind: str) -> str:
    if kind in ("twin", "operator"):
        return "front_door"
    return "gate"


class InvalidRappidError(ValueError):
    """Raised by door_from_rappid for any rappid that doesn't match the spec.

    Subclasses ValueError so callers can `except ValueError` if they want a
    catch-all, but typed for explicit handling per ESTATE_SPEC §6 (stale
    rappid rejection).
    """


def door_from_rappid(rappid: str) -> dict:
    """Return the canonical door object for a rappid. Pure function.

    Implements the contract in ESTATE_SPEC §5.

    Args:
      rappid: the v2 rappid string.

    Returns:
      A dict with the keys: rappid, owner, repo, kind, door_type, urls.
      `urls` is a dict with keys: repo, front, identity, holocard, holo_md,
      avatar, summon_qr, members, facets. The `members` URL is included for
      ALL doors but is only populated content for gates — twins return an
      empty members.json (or 404). Consumers that distinguish should check
      door_type first.

    Raises:
      InvalidRappidError: if the string is not a valid v2 rappid, OR the
        (owner, repo) on the left of the rappid don't match the (owner, repo)
        on the right (the @github.com/... origin pin), OR kind is not in
        VALID_KINDS.
    """
    if not isinstance(rappid, str):
        raise InvalidRappidError(f"rappid must be a string, got {type(rappid).__name__}")

    m = _RAPPID_RE.match(rappid)
    if not m:
        raise InvalidRappidError(
            f"rappid does not match v2 format: {rappid!r}. "
            f"Expected: rappid:v2:<kind>:@<owner>/<repo>:<32hex>@github.com/<owner>/<repo>"
        )

    owner = m.group("owner")
    repo = m.group("repo")
    owner2 = m.group("owner2")
    repo2 = m.group("repo2")
    kind = m.group("kind")

    if owner != owner2 or repo != repo2:
        raise InvalidRappidError(
            f"rappid origin mismatch: identity says @{owner}/{repo}, "
            f"origin pin says @github.com/{owner2}/{repo2}. The two MUST be equal."
        )

    if kind not in VALID_KINDS:
        raise InvalidRappidError(
            f"rappid kind {kind!r} is not in VALID_KINDS={sorted(VALID_KINDS)}. "
            f"Adding a kind requires a CONSTITUTION amendment (Article XLVI)."
        )

    raw_base = f"https://raw.githubusercontent.com/{owner}/{repo}/main"
    return {
        "rappid": rappid,
        "owner": owner,
        "repo": repo,
        "kind": kind,
        "door_type": _door_type_for_kind(kind),
        "urls": {
            "repo":      f"https://github.com/{owner}/{repo}",
            "front":     f"https://{owner}.github.io/{repo}/",
            "identity":  f"{raw_base}/rappid.json",
            "holocard":  f"{raw_base}/card.json",
            "holo_md":   f"{raw_base}/holo.md",
            "avatar":    f"{raw_base}/holo.svg",
            "summon_qr": f"{raw_base}/holo-qr.svg",
            "members":   f"{raw_base}/members.json",
            "facets":    f"{raw_base}/facets.json",
        },
    }


def estate_url(github_handle: str) -> str:
    """The canonical pure-raw URL for a user's full estate.

    Per ESTATE_SPEC §4.2 — single roundtrip, no auth, no API.
    """
    if not github_handle or "/" in github_handle or " " in github_handle:
        raise InvalidRappidError(f"invalid github handle: {github_handle!r}")
    return f"https://raw.githubusercontent.com/{github_handle}/rapp-estate/main/estate.json"


# Convenience: parse just the (owner, repo) without building the full URL set.
# Used by the planter where it needs the pair but not the URLs.
def owner_repo_from_rappid(rappid: str) -> tuple[str, str]:
    """Return (owner, repo) for a valid rappid. Raises InvalidRappidError."""
    door = door_from_rappid(rappid)
    return door["owner"], door["repo"]
