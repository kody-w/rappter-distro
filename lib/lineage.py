"""
lineage.py — walk the rappid species tree.

Given a starting rappid + a vault directory containing root.json files,
walks parent_rappid back to the species root, returning the chain of
ancestors. Raises if the chain is broken or cyclic.

The vault directory may be a `blessings/` directory (organisms with
cryptographic backing — root.json files signed by master) or a
`rappid.json`-rooted repo (code variants without keypairs). The walker
handles both: it looks for the parent's record by trying multiple
locations.

External walking (across hosts, into other repos) is not done here —
this module is local-first: it walks records that are already on disk.
For network-fetched lineage walks, layer this module under a
swarm_estate organ or similar.
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from utils.rappid import Rappid, SPECIES_ROOT, species_root


@dataclass
class LineageNode:
    """One node in a walked lineage chain."""

    rappid: Rappid
    parent_rappid: Optional[Rappid]   # None at species root
    record_path: Optional[Path]        # Where root.json was found, if anywhere
    record_kind: str                   # 'root.json' | 'rappid.json' | 'species-root-constant'

    @property
    def is_species_root(self) -> bool:
        return self.parent_rappid is None


@dataclass
class LineageChain:
    """A walked chain from a starting rappid up to the species root."""

    start: Rappid
    nodes: list[LineageNode]   # ordered start-first; final element is the species root
    terminated_at_species_root: bool

    def __len__(self) -> int:
        return len(self.nodes)

    def depth(self) -> int:
        """Number of edges between start and species root.

        depth=0 means the start IS the species root.
        depth=1 means start is a direct child of the species root.
        """
        return len(self.nodes) - 1


def _read_json_silent(path: Path) -> Optional[dict]:
    """Read a JSON file, returning None on any error."""
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def _find_record_for(rappid: Rappid, vault_root: Path) -> tuple[Optional[Path], Optional[dict], str]:
    """Locate the on-disk record (root.json or rappid.json) for a given rappid.

    Search order, from most specific to least:
        1. <vault_root>/blessings/<hash>/root.json (cryptographically signed organism)
        2. <vault_root>/rappid.json (code-only organism at repo root)
        3. <vault_root>/<publisher>-<slug>-rappid.json (legacy convention)

    Returns (path, parsed_dict, record_kind).
    """
    # 1. Cryptographic blessings/<hash>/root.json
    blessings_path = vault_root / "blessings" / rappid.hash / "root.json"
    data = _read_json_silent(blessings_path)
    if data is not None:
        return blessings_path, data, "root.json"

    # 2. Repo-root rappid.json (code-only organism)
    rappid_json = vault_root / "rappid.json"
    data = _read_json_silent(rappid_json)
    if data is not None:
        # Verify the file declares the rappid we're looking for
        declared = data.get("rappid")
        if declared == rappid.to_string():
            return rappid_json, data, "rappid.json"

    # 3. Convention: <publisher>-<slug>-rappid.json (e.g., for legacy snapshots)
    convention_path = vault_root / f"{rappid.publisher}-{rappid.slug}-rappid.json"
    data = _read_json_silent(convention_path)
    if data is not None:
        return convention_path, data, "rappid.json"

    return None, None, ""


def _extract_parent(record: dict, record_kind: str) -> Optional[str]:
    """Extract the parent_rappid string from a record."""
    if record_kind == "root.json":
        return record.get("payload", {}).get("parent_rappid")
    elif record_kind == "rappid.json":
        return record.get("parent_rappid")
    return None


def walk_lineage(start: Rappid, vault_root: Path, max_depth: int = 100) -> LineageChain:
    """Walk parent_rappid from `start` upward.

    The chain MUST terminate at the species root. If it doesn't (broken
    chain, cycle, or unknown parent), raises ValueError. The species root
    is recognized by its canonical SPECIES_ROOT constant.

    Args:
        start: the rappid to walk from
        vault_root: filesystem root holding root.json / rappid.json files
        max_depth: max walk depth; cycle defense (default 100, more than
            enough for any conceivable species tree depth)

    Returns:
        LineageChain with nodes from `start` up to the species root.

    Raises:
        ValueError: chain broken, cyclic, or exceeds max_depth.
    """
    if not isinstance(start, Rappid):
        raise TypeError(f"start must be a Rappid, got {type(start).__name__}")
    vault_root = Path(vault_root)

    nodes: list[LineageNode] = []
    seen: set[str] = set()
    current = start

    while True:
        if str(current) in seen:
            raise ValueError(
                f"cyclic parent_rappid chain detected at {current.fingerprint}; "
                f"chain so far: {[n.rappid.fingerprint for n in nodes]}"
            )
        seen.add(str(current))

        if len(nodes) > max_depth:
            raise ValueError(f"lineage chain exceeds max_depth={max_depth}")

        # Special-case the species root: we know its rappid by constant,
        # so we don't need to read a record for it.
        if current.is_species_root():
            nodes.append(LineageNode(
                rappid=current,
                parent_rappid=None,
                record_path=None,
                record_kind="species-root-constant",
            ))
            return LineageChain(start=start, nodes=nodes, terminated_at_species_root=True)

        # Find the record for `current`
        record_path, record, record_kind = _find_record_for(current, vault_root)
        if record is None:
            # The species root may exist as rappid.json at the vault root
            # even if the search went sideways; try one more time
            if current.to_string() == SPECIES_ROOT:
                nodes.append(LineageNode(
                    rappid=current,
                    parent_rappid=None,
                    record_path=None,
                    record_kind="species-root-constant",
                ))
                return LineageChain(start=start, nodes=nodes, terminated_at_species_root=True)
            raise ValueError(
                f"no record found for {current.fingerprint} ({current.short_hash}...) "
                f"in vault {vault_root}; chain broken at depth {len(nodes)}"
            )

        parent_str = _extract_parent(record, record_kind)
        if parent_str is None:
            # parent_rappid: null — must be the species root
            nodes.append(LineageNode(
                rappid=current,
                parent_rappid=None,
                record_path=record_path,
                record_kind=record_kind,
            ))
            if not current.is_species_root():
                raise ValueError(
                    f"organism {current.fingerprint} declares parent_rappid: null "
                    f"but is not the species root; only the species root is allowed null parent_rappid"
                )
            return LineageChain(start=start, nodes=nodes, terminated_at_species_root=True)

        # Parse the parent and continue walking
        try:
            parent = Rappid.parse(parent_str)
        except ValueError as e:
            raise ValueError(
                f"organism {current.fingerprint} declares malformed parent_rappid: {parent_str!r}"
            ) from e

        nodes.append(LineageNode(
            rappid=current,
            parent_rappid=parent,
            record_path=record_path,
            record_kind=record_kind,
        ))
        current = parent


def render_chain(chain: LineageChain) -> str:
    """Pretty-print a lineage chain as ASCII tree-form."""
    lines = []
    indent = ""
    for i, node in enumerate(chain.nodes):
        marker = "  └──" if i > 0 else "      "
        lines.append(f"{indent}{marker} {node.rappid.fingerprint}")
        lines.append(f"{indent}        hash={node.rappid.short_hash}...")
        if node.is_species_root:
            lines.append(f"{indent}        ★ SPECIES ROOT (parent_rappid: null)")
        else:
            assert node.parent_rappid is not None
            lines.append(f"{indent}        parent: {node.parent_rappid.fingerprint}")
        indent += "  "
    if chain.terminated_at_species_root:
        lines.append("")
        lines.append(f"  ✓ chain terminated at species root (depth {chain.depth()})")
    return "\n".join(lines)


__all__ = ["LineageNode", "LineageChain", "walk_lineage", "render_chain"]
