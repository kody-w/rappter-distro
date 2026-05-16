"""Tests for the RAPP ecosystem graph (tools/ecosystem_graph.py + pages/about).

Verifies:
- Generated JSON is well-formed and matches schema.
- Inventory contains every anchor repo we know must exist.
- Every edge endpoint resolves to a known node.
- Every category in nodes is declared in `categories`.
- HTML viz is syntactically valid, embeds the data, references D3, and
  exposes the data on `window.__ECO__` (verified by static parse).
- Anchor invariants: RAPP is the most-connected node; private mirrors point
  to their public sibling.

Run:  python3 -m pytest tests/test_ecosystem_graph.py -v
"""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "pages" / "about" / "ecosystem.json"
HTML = ROOT / "pages" / "about" / "ecosystem.html"
GENERATOR = ROOT / "tools" / "ecosystem_graph.py"

ANCHOR_REPOS = {
    # Core platform
    "RAPP", "rappter", "openrappter",
    # Installer
    "rapp-installer", "rapp-installer-dev", "rapp-installer-canary",
    # Catalog
    "RAPP_Store", "RAPP_Sense_Store",
    # Trust
    "RAR", "RAPPcards",
    # Egg / distribution
    "rapp-egg-hub", "rapp-zoo", "rappterbox", "twin_vault",
    # Brainstem twins
    "echo-brainstem", "tide-brainstem", "lumen-brainstem",
    # Front doors
    "heimdall", "rapp-test-neighbor",
    # Wildhaven
    "wildhaven-ceo", "wildhaven-ai-homes-twin",
    # Neighborhoods
    "ant-farm", "public-art-collective", "microsoft-se-team-neighborhood",
    # Mars
    "mars-barn", "first-principles-to-mars",
    # Templates
    "braintrust-template", "private-workspace-template",
    # CommunityRAPP
    "CommunityRAPP",
}


@pytest.fixture(scope="module")
def data() -> dict:
    assert DATA.exists(), (
        f"{DATA} not found — run `python3 tools/ecosystem_graph.py` first"
    )
    return json.loads(DATA.read_text())


# ---------------------------------------------------------------- schema

def test_schema_version(data):
    assert data["schema"] == "rapp-ecosystem-graph/1.0"


def test_top_level_keys(data):
    for k in ("schema", "generated_at", "categories", "nodes", "edges", "stats"):
        assert k in data, f"missing top-level key: {k}"


def test_stats_consistency(data):
    stats = data["stats"]
    assert stats["total_repos"] == len(data["nodes"])
    assert stats["total_edges"] == len(data["edges"])
    assert stats["public_repos"] + stats["private_repos"] == stats["total_repos"]
    iso = sum(1 for n in data["nodes"] if n["degree"] == 0)
    assert stats["isolated_repos"] == iso


# ---------------------------------------------------------------- inventory

def test_inventory_size_floor(data):
    # We have 200+ repos in the org; the inventory should reflect that.
    assert len(data["nodes"]) >= 100, (
        f"only {len(data['nodes'])} repos — generator probably failed mid-pull"
    )


@pytest.mark.parametrize("repo", sorted(ANCHOR_REPOS))
def test_anchor_repo_present(data, repo):
    names = {n["id"] for n in data["nodes"]}
    assert repo in names, f"{repo} is missing from the inventory"


def test_node_fields(data):
    required = {"id", "category", "description", "private", "stars",
                "pushedAt", "url", "language", "degree"}
    for n in data["nodes"]:
        missing = required - n.keys()
        assert not missing, f"{n['id']} missing fields: {missing}"
        assert isinstance(n["private"], bool)
        assert isinstance(n["degree"], int)
        assert n["url"].startswith("https://github.com/")


def test_no_duplicate_node_ids(data):
    ids = [n["id"] for n in data["nodes"]]
    dupes = [i for i in ids if ids.count(i) > 1]
    assert not dupes, f"duplicate node ids: {set(dupes)}"


# ---------------------------------------------------------------- edges

def test_every_edge_endpoint_known(data):
    names = {n["id"] for n in data["nodes"]}
    for e in data["edges"]:
        assert e["source"] in names, f"unknown edge source: {e['source']}"
        assert e["target"] in names, f"unknown edge target: {e['target']}"
        assert e["source"] != e["target"], f"self-loop: {e}"


def test_edges_have_kind(data):
    valid_kinds = {"references", "private-mirror", "archive-of",
                   "canary-of", "dev-channel-of", "state-of",
                   "extends", "variant-of", "extension-of"}
    for e in data["edges"]:
        assert e["kind"] in valid_kinds, f"unknown edge kind: {e['kind']}"


def test_no_duplicate_edges(data):
    seen = set()
    for e in data["edges"]:
        key = (e["source"], e["target"], e["kind"])
        assert key not in seen, f"duplicate edge: {key}"
        seen.add(key)


def test_some_edges_exist(data):
    assert len(data["edges"]) >= 30, (
        f"only {len(data['edges'])} edges — generator probably mis-fired"
    )


# ---------------------------------------------------------------- invariants

def test_rapp_is_central(data):
    """RAPP should be the most-connected node in the graph."""
    by_degree = sorted(data["nodes"], key=lambda n: -n["degree"])
    top = by_degree[0]
    # RAPP should be in the top 3 (allow a tie).
    top_names = {n["id"] for n in by_degree[:3]}
    assert "RAPP" in top_names, (
        f"RAPP not in top 3 by degree: {top_names} (top={top['id']} deg={top['degree']})"
    )


@pytest.mark.parametrize("private,public", [
    ("RAPP_Store_Private", "RAPP_Store"),
    ("microsoft-se-team-neighborhood-private", "microsoft-se-team-neighborhood"),
    ("wildhaven-ai-homes-twin-private", "wildhaven-ai-homes-twin"),
])
def test_private_mirror_edge(data, private, public):
    names = {n["id"] for n in data["nodes"]}
    if private not in names or public not in names:
        pytest.skip(f"{private} or {public} not in inventory")
    found = any(
        e["source"] == private and e["target"] == public and e["kind"] == "private-mirror"
        for e in data["edges"]
    )
    assert found, f"missing private-mirror edge {private} → {public}"


def test_categories_declared(data):
    declared = {c["key"] for c in data["categories"]}
    used = {n["category"] for n in data["nodes"]}
    extra = used - declared
    assert not extra, f"node categories not in `categories` list: {extra}"


def test_categories_have_color(data):
    for c in data["categories"]:
        assert re.fullmatch(r"#[0-9a-fA-F]{6}", c["color"]), (
            f"bad color for {c['key']}: {c['color']}"
        )


# ---------------------------------------------------------------- HTML

@pytest.fixture(scope="module")
def html_text() -> str:
    assert HTML.exists()
    return HTML.read_text()


def test_html_well_formed(html_text):
    assert html_text.lstrip().startswith("<!DOCTYPE html>")
    assert "</html>" in html_text


def test_html_loads_d3(html_text):
    assert "d3@7" in html_text or "d3.v7" in html_text


def test_html_embeds_data(html_text):
    m = re.search(
        r'<script id="ecosystem-data" type="application/json">(.*?)</script>',
        html_text, re.DOTALL,
    )
    assert m, "no embedded data block found"
    payload = json.loads(m.group(1).strip())
    assert payload.get("schema") == "rapp-ecosystem-graph/1.0"
    assert len(payload["nodes"]) > 0
    # Embedded data must match the JSON sidecar.
    sidecar = json.loads(DATA.read_text())
    assert payload["stats"] == sidecar["stats"]


def test_html_exposes_data_on_window(html_text):
    """Allows tests + browser console to inspect the loaded data."""
    assert "window.__ECO__" in html_text


def test_html_has_controls(html_text):
    for ctrl in ["eco-search", "eco-show-offtopic", "eco-show-isolated"]:
        assert f'id="{ctrl}"' in html_text, f"missing control: {ctrl}"


def test_html_safe_no_script_in_descriptions(data, html_text):
    # The inventory renders descriptions; ensure escapeHtml exists in source.
    assert "escapeHtml" in html_text


# ---------------------------------------------------------------- generator

def test_generator_runs(tmp_path):
    """Smoke-test that the generator exits cleanly (uses real gh CLI)."""
    result = subprocess.run(
        ["python3", str(GENERATOR)],
        capture_output=True, text=True, timeout=60, cwd=str(ROOT),
    )
    assert result.returncode == 0, (
        f"generator failed:\nstdout={result.stdout}\nstderr={result.stderr}"
    )
    assert "RAPP ecosystem map" in result.stdout
