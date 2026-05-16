"""path_opacity — Article XLVIII.6 URL opacity helpers (pure stdlib).

Authority: pages/docs/PUBLIC_PRIVATE_BOUNDARY.md §4 + CONSTITUTION Article XLVIII.6.

The threat: static URLs leak metadata even when their content is access-gated.
A URL like
    <handle>/rapp-estate-private/main/mailbox/inbox/dr-jones/test-results.json
reveals — just by existing — that the operator receives correspondence from
dr-jones about test results. URLs surface in beacons, commit history, browser
history, agent logs, error pages, and 404 responses to unauthorized viewers.

This module is the canonical helper for ensuring no URL in the private repo
carries semantic information.

PUBLIC API:
    opaque_path(secret, kind, id) -> str
        Return an opaque path of the form 'kinds/<HMAC>/<HMAC>.json'. Used
        when committing private-estate content. The path reveals nothing.

    decode_local(secret, opaque, known_kinds, known_ids) -> (kind, id) | None
        OPERATOR-ONLY. Walks the operator's known kinds + ids and returns
        which (kind, id) maps to this opaque path. Requires the operator's
        secret. Used by the brainstem to navigate the operator's own private
        repo. NEVER call this from anything that emits to a public-facing
        surface.

    object_path(content_bytes) -> str
        Return 'objects/<sha256>.json' for content-addressed storage. Pure
        derivation; no secret required. The hash is deterministic but
        reveals nothing.

    audit_paths(file_paths) -> list[str]
        Walk a list of relative file paths. Return the subset that VIOLATE
        the opacity contract. Used by `estate_agent.publish` to refuse
        commits with semantic paths.

    OPACITY_REGEX
        The compiled regex defining the only valid path shapes. Exported
        for downstream consumers (F15 conformance gate, audit tooling).
"""

from __future__ import annotations

import hashlib
import hmac
import re

# Per Article XLVIII.6 / PUBLIC_PRIVATE_BOUNDARY §4.2:
# Two well-known paths (meta.json, README.md) + content-addressed objects/
# + HMAC'd kinds/. Anything else is a violation.
OPACITY_REGEX = re.compile(
    r"^("
    r"meta\.json"
    r"|README\.md"
    r"|objects/(\.gitkeep|[a-f0-9]+\.json)"
    r"|kinds/(\.gitkeep|[a-f0-9]+(/[a-f0-9]+\.json)?)"
    r")$"
)


def _hmac_hex(secret: bytes, label: str) -> str:
    """Return the lowercase hex HMAC-SHA256 of `label` keyed by `secret`,
    truncated to 32 hex chars (128 bits). 128 bits is enough collision-
    resistance for the kind/id namespace; shorter paths = less ugly URLs.
    """
    if not isinstance(secret, (bytes, bytearray)) or len(secret) < 16:
        raise ValueError("path_opacity: secret must be ≥16 bytes; this is XLVIII.6 enforcement")
    if not isinstance(label, str) or not label:
        raise ValueError("path_opacity: label must be a non-empty string")
    digest = hmac.new(secret, label.encode("utf-8"), hashlib.sha256).hexdigest()
    return digest[:32]


def opaque_path(secret: bytes, kind: str, id: str) -> str:
    """Return the canonical opaque path for a (kind, id) pair.

    Example:
        opaque_path(secret, "mailbox-inbox", "msg-from-bill-2026-05-09")
        → "kinds/3f9c2e8a4b...e7/9d8f2c4a1e...b3.json"

    The path is deterministic given (secret, kind, id). The HMAC ensures
    nobody without the secret can correlate paths back to semantic kind/id.
    """
    kind_hash = _hmac_hex(secret, f"kind:{kind}")
    id_hash   = _hmac_hex(secret, f"id:{kind}:{id}")
    return f"kinds/{kind_hash}/{id_hash}.json"


def object_path(content_bytes: bytes) -> str:
    """Return 'objects/<sha256>.json' for content-addressed storage.

    Pure derivation; deterministic; no secret required. The hash is the
    only information leaked, and a sha256 of arbitrary bytes reveals
    nothing about content semantics.
    """
    if not isinstance(content_bytes, (bytes, bytearray)):
        raise ValueError("path_opacity: object_path requires bytes")
    return f"objects/{hashlib.sha256(content_bytes).hexdigest()}.json"


def decode_local(secret: bytes, opaque: str,
                  known_kinds: list[str], known_ids: dict[str, list[str]]) -> tuple[str, str] | None:
    """OPERATOR-ONLY. Resolve an opaque kinds/HMAC/HMAC.json path back to
    (kind, id) by trying every known (kind, id) pair from the operator's
    local map.

    Args:
        secret: the operator's per-install HMAC secret.
        opaque: the path to decode (e.g. "kinds/3f9c.../9d8f...json").
        known_kinds: list of kind labels the operator has seen.
        known_ids: dict mapping each kind to the list of ids under it.

    Returns:
        (kind, id) if a match is found, or None. None means either the
        secret is wrong, OR the (kind, id) isn't in the operator's local
        map yet — common when discovering a new entry committed via raw
        gh api outside the brainstem.

    NEVER call this from any consumer that emits to public-facing
    surfaces (beacon, sniff result, error page, agent log). Article
    XLVIII.6 forbids surfaces that could correlate opaque paths back
    to semantic identifiers via decode oracle.
    """
    m = re.match(r"^kinds/([a-f0-9]+)/([a-f0-9]+)\.json$", opaque)
    if not m:
        return None
    target_kind_hash, target_id_hash = m.group(1), m.group(2)
    for kind in known_kinds:
        if _hmac_hex(secret, f"kind:{kind}") != target_kind_hash:
            continue
        for id_ in known_ids.get(kind, []):
            if _hmac_hex(secret, f"id:{kind}:{id_}") == target_id_hash:
                return (kind, id_)
    return None


def audit_paths(file_paths: list[str]) -> list[str]:
    """Return the subset of `file_paths` that VIOLATE the opacity contract.

    Used by `estate_agent.publish` to refuse commits when the operator
    (or some other tool) has accidentally introduced a semantic path.
    Empty return = all paths compliant.

    Example:
        violations = audit_paths(["meta.json",
                                   "objects/abc123.json",
                                   "mailbox/inbox/dr-jones.json"])
        → ["mailbox/inbox/dr-jones.json"]
    """
    return [p for p in file_paths if not OPACITY_REGEX.match(p)]


# ─── Self-check ───────────────────────────────────────────────────────────

def _self_check() -> dict:
    """Verify the helper itself is correct + the regex catches drift."""
    issues: list[str] = []
    secret = b"x" * 32

    # Round-trip test
    path = opaque_path(secret, "mailbox-inbox", "msg-001")
    if not OPACITY_REGEX.match(path):
        issues.append(f"opaque_path output failed regex: {path}")
    decoded = decode_local(secret, path, ["mailbox-inbox"], {"mailbox-inbox": ["msg-001"]})
    if decoded != ("mailbox-inbox", "msg-001"):
        issues.append(f"decode_local round-trip failed: got {decoded}")

    # Negative tests for audit_paths
    bad = [
        "mailbox/inbox/dr-jones/test-results.json",
        "channels/bill/2026-05-09.md",
        "secrets.json",
        "memory/2026-05-09-therapy.md",
    ]
    violations = audit_paths(bad)
    if set(violations) != set(bad):
        issues.append(f"audit_paths missed violations: {set(bad) - set(violations)}")

    # Positive tests for valid paths
    good = [
        "meta.json",
        "README.md",
        "objects/.gitkeep",
        "objects/abc123def456.json",
        "kinds/.gitkeep",
        "kinds/aaaa1111/bbbb2222.json",
    ]
    if audit_paths(good):
        issues.append(f"audit_paths false-flagged valid paths: {audit_paths(good)}")

    # Different secrets produce different paths
    p1 = opaque_path(b"a" * 32, "x", "y")
    p2 = opaque_path(b"b" * 32, "x", "y")
    if p1 == p2:
        issues.append("opaque_path returns same value for different secrets — broken")

    # Object path is deterministic + opaque
    op1 = object_path(b"hello world")
    op2 = object_path(b"hello world")
    if op1 != op2 or not OPACITY_REGEX.match(op1):
        issues.append(f"object_path broken: {op1} vs {op2}")

    return {"ok": len(issues) == 0, "issues": issues}


if __name__ == "__main__":
    import json, sys
    chk = _self_check()
    print(json.dumps(chk, indent=2))
    sys.exit(0 if chk["ok"] else 1)
