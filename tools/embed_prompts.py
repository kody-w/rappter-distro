#!/usr/bin/env python3
"""Embed pages/about/prompts.json into pages/about/prompts.html.

The HTML works with either an embedded data block or a fetch(prompts.json)
fallback — embedding makes the file self-contained for offline / file://
viewing. Re-run after editing prompts.json:

    python3 tools/embed_prompts.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "pages" / "about" / "prompts.json"
HTML = ROOT / "pages" / "about" / "prompts.html"

MARKER_START = '<script id="prompts-data" type="application/json">'
MARKER_END = "</script>"


def main() -> None:
    if not DATA.exists():
        sys.exit(f"missing {DATA}")
    if not HTML.exists():
        sys.exit(f"missing {HTML}")

    payload = json.loads(DATA.read_text())
    html = HTML.read_text()
    i = html.find(MARKER_START)
    if i == -1:
        sys.exit(f"no embed marker {MARKER_START!r} in {HTML}")
    j = html.find(MARKER_END, i)
    if j == -1:
        sys.exit("no closing </script> after embed marker")

    new_block = MARKER_START + "\n" + json.dumps(payload, indent=2) + "\n"
    HTML.write_text(html[:i] + new_block + html[j:])
    print(
        f"embedded {len(payload['prompts'])} prompts "
        f"into {HTML.relative_to(ROOT)}"
    )


if __name__ == "__main__":
    main()
