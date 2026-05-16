"""Tests for the RAPP prompt ledger (pages/about/prompts.{json,html})."""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "pages" / "about" / "prompts.json"
HTML = ROOT / "pages" / "about" / "prompts.html"
EMBED = ROOT / "tools" / "embed_prompts.py"


@pytest.fixture(scope="module")
def data() -> dict:
    return json.loads(DATA.read_text())


@pytest.fixture(scope="module")
def html() -> str:
    return HTML.read_text()


# ---------------------------------------------------------------- schema

def test_schema(data):
    assert data["schema"] == "rapp-prompt-ledger/1.0"
    assert isinstance(data["prompts"], list)
    assert data["next_id"] > max(p["id"] for p in data["prompts"])


def test_seeded_with_ten(data):
    assert len(data["prompts"]) >= 10, "need the original 10 seed prompts"


def test_prompt_fields(data):
    required = {"id", "title", "added", "prompt", "shows", "tags"}
    for p in data["prompts"]:
        missing = required - p.keys()
        assert not missing, f"prompt #{p.get('id')} missing fields: {missing}"
        assert isinstance(p["id"], int)
        assert p["title"].strip()
        assert p["prompt"].strip()
        assert re.fullmatch(r"\d{4}-\d{2}-\d{2}", p["added"])
        assert isinstance(p["tags"], list)


def test_unique_ids(data):
    ids = [p["id"] for p in data["prompts"]]
    assert len(ids) == len(set(ids)), f"duplicate ids: {ids}"


def test_ids_dense_starting_at_one(data):
    ids = sorted(p["id"] for p in data["prompts"])
    assert ids[0] == 1
    # IDs may have gaps later if entries get retracted, but seed is dense.
    seed = [p for p in data["prompts"] if p["added"] == "2026-05-10"]
    seed_ids = sorted(p["id"] for p in seed)
    assert seed_ids == list(range(1, len(seed_ids) + 1))


def test_tags_lowercase_kebab(data):
    pattern = re.compile(r"^[a-z][a-z0-9-]*$")
    bad = []
    for p in data["prompts"]:
        for t in p["tags"]:
            if not pattern.fullmatch(t):
                bad.append((p["id"], t))
    assert not bad, f"non-kebab tags: {bad}"


# ---------------------------------------------------------------- HTML

def test_html_well_formed(html):
    assert html.lstrip().startswith("<!DOCTYPE html>")
    assert "</html>" in html


def test_html_has_controls(html):
    for ctrl in ["pl-search", "pl-sort", "pl-tags", "pl-cards"]:
        assert f'id="{ctrl}"' in html, f"missing #{ctrl}"


def test_html_has_copy_logic(html):
    assert "navigator.clipboard" in html
    assert "execCommand('copy')" in html, "missing fallback copy path"


def test_html_exposes_data_on_window(html):
    assert "window.__PROMPTS__" in html


def test_html_escapes_user_content(html):
    assert "escapeHtml" in html


# ---------------------------------------------------------------- embedder

def test_embedder_runs():
    result = subprocess.run(
        ["python3", str(EMBED)],
        capture_output=True, text=True, timeout=15, cwd=str(ROOT),
    )
    assert result.returncode == 0, (
        f"embedder failed:\nstdout={result.stdout}\nstderr={result.stderr}"
    )
    # Confirm the embedded block now matches sidecar.
    html = HTML.read_text()
    m = re.search(
        r'<script id="prompts-data" type="application/json">(.*?)</script>',
        html, re.DOTALL,
    )
    assert m, "embed block not found after running embedder"
    payload = json.loads(m.group(1).strip())
    sidecar = json.loads(DATA.read_text())
    assert payload == sidecar


# ---------------------------------------------------------------- manifest

def test_listed_in_site_manifest():
    manifest = json.loads((ROOT / "pages" / "_site" / "index.json").read_text())
    paths = [
        p["path"] for section in manifest["sections"] for p in section["pages"]
    ]
    assert "about/prompts.html" in paths, (
        "prompts.html not registered in pages/_site/index.json"
    )
