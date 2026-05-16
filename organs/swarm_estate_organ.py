"""
swarm_estate_organ.py — kernel-side endpoints for rappid + lineage + verification.

The Swarm Estate Protocol (Constitution Article XXXVI) is implemented in
Wildhaven's private vault and described in `pages/vault/Architecture/`.
This organ is the kernel-side runtime that exposes the protocol's
verification primitives at HTTP endpoints. Any operator running a brainstem
gets these endpoints for free; they're transport-only — no Foundation IP
exposed, just verification of public records.

Endpoints (dispatched at /api/swarm-estate/*):

    GET  /api/swarm-estate/                   — organ index + version info
    GET  /api/swarm-estate/parse?rappid=<s>   — parse a rappid string into structured fields
    POST /api/swarm-estate/walk               — walk a parent_rappid chain in a vault
    POST /api/swarm-estate/verify-record      — verify a signed record against its declared signer
    GET  /api/swarm-estate/species-root       — return the canonical species-root rappid

Companion to estate_organ.py (which is the local-device twin view);
together they cover both layers of the Article XXXVI / Article XXXIV
identity stack.

Spec: pages/vault/Architecture/Rappid.md, pages/vault/Architecture/The Swarm Estate.md
"""
from __future__ import annotations

import base64
import hashlib
import importlib.util
import json
import os
import sys
from pathlib import Path
from typing import Any

name = "swarm-estate"


_UTILS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _UTILS_DIR not in sys.path:
    sys.path.insert(0, _UTILS_DIR)


def _try_import(modname: str):
    try:
        return importlib.import_module(modname)
    except Exception:
        return None


def _rappid_module():
    # IMPORTANT: prefer utils.rappid because the lineage module imports it
    # via that path. Module identity is path-dependent in Python — using
    # different paths for the same source produces two distinct class
    # objects, breaking isinstance() checks across module boundaries.
    return _try_import("utils.rappid") or _try_import("rappid")


def _lineage_module():
    return _try_import("utils.lineage") or _try_import("lineage")


# ── GET / ────────────────────────────────────────────────────────────────


def _index() -> dict:
    rmod = _rappid_module()
    return {
        "schema": "swarm-estate-organ/1.0",
        "name": "swarm-estate",
        "purpose": "Verification primitives for the rappid identity system (Constitution Articles XXXIV, XXXVI).",
        "spec_urls": [
            "pages/vault/Architecture/Rappid.md",
            "pages/vault/Architecture/The Swarm Estate.md",
            "pages/vault/Architecture/Local-First-by-Design.md",
            "pages/vault/Architecture/Decentralized-by-Design.md",
        ],
        "species_root": rmod.SPECIES_ROOT if rmod else None,
        "endpoints": [
            "GET  /api/swarm-estate/              — this index",
            "GET  /api/swarm-estate/parse?rappid=<s>  — parse a rappid string",
            "POST /api/swarm-estate/walk          — walk parent_rappid in a vault",
            "POST /api/swarm-estate/verify-record — verify a signed record",
            "GET  /api/swarm-estate/species-root  — the godfather rappid",
        ],
    }


# ── GET /parse ───────────────────────────────────────────────────────────


def _parse(query_rappid: str) -> tuple[dict, int]:
    rmod = _rappid_module()
    if rmod is None:
        return {"error": "rappid module unavailable"}, 500
    try:
        r = rmod.Rappid.parse(query_rappid)
    except (ValueError, TypeError) as e:
        return {"error": f"malformed rappid: {e}"}, 400
    return {
        "rappid": r.to_string(),
        "version": r.version,
        "kind": r.kind,
        "publisher": r.publisher,
        "slug": r.slug,
        "hash": r.hash,
        "home_vault_url": r.home_vault_url,
        "fingerprint": r.fingerprint,
        "is_species_root": r.is_species_root(),
        "is_known_kind": r.is_known_kind(),
    }, 200


# ── POST /walk ───────────────────────────────────────────────────────────


def _walk(body: dict) -> tuple[dict, int]:
    rmod = _rappid_module()
    lmod = _lineage_module()
    if rmod is None or lmod is None:
        return {"error": "rappid/lineage modules unavailable"}, 500

    start_str = body.get("rappid")
    vault_root_str = body.get("vault_root")
    if not start_str:
        return {"error": "body must include 'rappid'"}, 400
    if not vault_root_str:
        return {"error": "body must include 'vault_root' (filesystem path)"}, 400

    try:
        start = rmod.Rappid.parse(start_str)
    except ValueError as e:
        return {"error": f"malformed rappid: {e}"}, 400

    vault_root = Path(vault_root_str)
    if not vault_root.exists():
        return {"error": f"vault_root does not exist: {vault_root_str}"}, 400

    try:
        chain = lmod.walk_lineage(start, vault_root, max_depth=int(body.get("max_depth", 100)))
    except (ValueError, TypeError) as e:
        return {"error": f"lineage walk failed: {e}"}, 422

    return {
        "start": chain.start.to_string(),
        "depth": chain.depth(),
        "terminated_at_species_root": chain.terminated_at_species_root,
        "chain": [
            {
                "rappid": node.rappid.to_string(),
                "fingerprint": node.rappid.fingerprint,
                "parent_rappid": node.parent_rappid.to_string() if node.parent_rappid else None,
                "record_path": str(node.record_path) if node.record_path else None,
                "record_kind": node.record_kind,
                "is_species_root": node.is_species_root,
            }
            for node in chain.nodes
        ],
    }, 200


# ── POST /verify-record ──────────────────────────────────────────────────


def _verify_record(body: dict) -> tuple[dict, int]:
    """Verify a signed swarm-estate-record against an explicit signer pubkey.

    Body:
      {
        "record": <full signed record JSON>,
        "signer_pubkey": "<base64 SPKI of the key the signature claims to be from>"
      }

    Returns whether the signature verifies.
    """
    record = body.get("record")
    signer_pubkey_b64 = body.get("signer_pubkey")
    if not isinstance(record, dict):
        return {"error": "body.record must be a dict"}, 400
    if not isinstance(signer_pubkey_b64, str):
        return {"error": "body.signer_pubkey must be a base64 string"}, 400

    if "signature" not in record:
        return {"verified": False, "reason": "record has no 'signature' field"}, 200

    try:
        from cryptography.hazmat.primitives.asymmetric import ec
        from cryptography.hazmat.primitives import serialization, hashes
    except ImportError:
        return {"error": "cryptography module not installed"}, 500

    try:
        pub = serialization.load_der_public_key(base64.b64decode(signer_pubkey_b64))
    except Exception as e:
        return {"verified": False, "reason": f"could not load pubkey: {e}"}, 200

    record_no_sig = {k: v for k, v in record.items() if k != "signature"}
    canonical = json.dumps(record_no_sig, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    sig = base64.b64decode(record["signature"])

    try:
        pub.verify(sig, canonical, ec.ECDSA(hashes.SHA256()))
        return {
            "verified": True,
            "alg": record.get("alg"),
            "kind": record.get("kind"),
            "issued_by": record.get("issued_by"),
            "issued_at": record.get("issued_at"),
        }, 200
    except Exception as e:
        return {"verified": False, "reason": f"signature did not verify: {e}"}, 200


# ── GET /species-root ────────────────────────────────────────────────────


def _species_root() -> tuple[dict, int]:
    rmod = _rappid_module()
    if rmod is None:
        return {"error": "rappid module unavailable"}, 500
    r = rmod.species_root()
    return {
        "rappid": r.to_string(),
        "version": r.version,
        "kind": r.kind,
        "publisher": r.publisher,
        "slug": r.slug,
        "hash": r.hash,
        "home_vault_url": r.home_vault_url,
        "_note": (
            "The species root — the godfather of the RAPP digital-organism species tree. "
            "Constitution Article XXXIV.2. Every rappid's parent_rappid chain terminates here."
        ),
    }, 200


# ── handle ───────────────────────────────────────────────────────────────


def handle(method: str, path: str, body: dict):
    """Organ entry point — dispatched by utils/organs.

    Path is everything after /api/swarm-estate/ (or empty for the index).
    """
    # Index
    if method == "GET" and path in ("", "/"):
        return _index(), 200

    # Parse
    if method == "GET" and path == "parse":
        # query string is in body via Flask request.args; brainstem flattens it
        # into 'body' on GETs. Look for 'rappid' there or query string.
        # Accept either {'rappid': '...'} in body or via GET query.
        rappid_str = body.get("rappid") if isinstance(body, dict) else None
        if not rappid_str:
            from flask import request
            rappid_str = request.args.get("rappid")
        if not rappid_str:
            return {"error": "missing 'rappid' query parameter"}, 400
        return _parse(rappid_str)

    # Walk
    if method == "POST" and path == "walk":
        return _walk(body)

    # Verify record
    if method == "POST" and path == "verify-record":
        return _verify_record(body)

    # Species root
    if method == "GET" and path == "species-root":
        return _species_root()

    return {"error": f"unknown route: {method} /api/swarm-estate/{path}"}, 404
