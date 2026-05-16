#!/usr/bin/env python3
"""Generate the cross-repo dependency map for the RAPP ecosystem.

Pulls every kody-w repo via `gh repo list`, categorizes by name + description,
collects edges from:
  - this repo's own outbound references (grep)
  - a probed sample of external READMEs / install scripts
  - inferred lineage (X-private → X, X-archive → X, X-canary → X-stable)
Writes pages/about/ecosystem.json (machine-readable inventory) and refreshes
the data block embedded in pages/about/ecosystem.html.

Run:  python3 tools/ecosystem_graph.py
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAGES = ROOT / "pages" / "about"
DATA_FILE = PAGES / "ecosystem.json"
HTML_FILE = PAGES / "ecosystem.html"

# ---------------------------------------------------------------- categorize

CATEGORIES = [
    # (key, label, color, predicate)
    ("core", "Core platform", "#ff7b72", lambda n, d: n in {
        "RAPP", "rappter", "openrappter", "rapp-private-backup",
        "RAPP-Private-Workspace", "rapp-installer-canary",
    }),
    ("installer", "Installer", "#ffa657", lambda n, d: (
        n.startswith("rapp-installer") or n in {"installer"}
    )),
    ("catalog", "Catalog / store", "#79c0ff", lambda n, d: (
        n in {"RAPP_Store", "RAPP_Store_Private", "RAPP_Sense_Store",
              "rapp_store", "rapp-store-archive", "rappterhub"}
    )),
    ("trust", "Trust / signing (RAR)", "#d2a8ff", lambda n, d: (
        n in {"RAR", "RAPPcards", "twin-binder", "red-binder", "obsidian-binder"}
    )),
    ("egg", "Egg / distribution", "#ffb86c", lambda n, d: (
        n in {"rapp-egg-hub", "twin_vault", "rapp-zoo", "rappterbox"}
    )),
    ("twin", "Twins", "#7ee787", lambda n, d: (
        n.endswith("-twin") or n.endswith("-twin-private")
        or n in {"twin", "twin-private", "kody-twin", "sim-demo-twin",
                 "sim-art-collective", "twin_agent"}
    )),
    ("brainstem", "Planted brainstems", "#a5d6ff", lambda n, d: (
        n.endswith("-brainstem")
    )),
    ("frontdoor", "Front doors / pkstop", "#f0c674", lambda n, d: (
        n.startswith("pkstop-") or n in {"heimdall", "rapp-test-neighbor"}
    )),
    ("neighborhood", "Neighborhoods", "#56d4dd", lambda n, d: (
        "neighborhood" in n or n in {"public-art-collective", "ant-farm",
                                      "rapp-estate", "rapp-estate-private"}
    )),
    ("template", "Templates", "#bc8cff", lambda n, d: (
        n.endswith("-template") or n in {"TEMPLATE"}
    )),
    ("plant", "Plant tests", "#8b949e", lambda n, d: (
        n.startswith("rapp-plant-")
    )),
    ("rappterbook", "Rappterbook (parallel social net)", "#f97583", lambda n, d: (
        n.startswith("rappterbook") or n in {"rappterverse"}
    )),
    ("mars", "Mars sims", "#e3b341", lambda n, d: (
        n.startswith("mars-") or n in {"first-principles-to-mars"}
    )),
    ("wildhaven", "Wildhaven business", "#ff9492", lambda n, d: (
        n.startswith("wildhaven-") or n in {
            "invention-notebook", "dreamcatcher-engine-archive",
            "obsidian-vault-backup",
        }
    )),
    ("community", "CommunityRAPP", "#a5f3a5", lambda n, d: (
        n.lower().startswith("communityrapp") or n == "RAPP_hippo"
    )),
    ("mmo", "MMO / metaverse", "#ff7eb6", lambda n, d: (
        n in {"rappter-mmo", "zion", "rappverse-data"}
    )),
    ("tools", "Tools / SDKs", "#a8ff60", lambda n, d: (
        n.startswith("lisppy") or n in {"rappter-cli", "rappter-fleet",
                                         "rappter-factory"}
    )),
    ("local-tools", "localFirstTools / aux apps", "#5d6770", lambda n, d: (
        n.lower().startswith("localfirsttools") or n in {
            "localtoolsdev", "aideate", "expense-tracker",
            "pvpoke-rankings-tracker", "BillWhalenCopilotstudio",
            "kody-w.github.io", "ubiquitous-train",
            "fantastic-computing-machine", "autoresearch",
        }
    )),
    ("ancestor", "Ancestor / pre-RAPP", "#bcd4a4", lambda n, d: n in {
        "RAP", "Rapid-Agent-Prototyping-Platform-RAPP-",
        "agentbookfactory", "openrapp", "RAPPagent", "RAPPtools",
        "RAPP_Hub", "rapphub", "rappbook-admin", "RappterNest",
        "rappverse", "RAPP_Desktop", "RAPPsquared",
    }),
    ("federation", "RAPPverse dimensions", "#c39ce0", lambda n, d: (
        n in {"VoidRAPP", "CrystalRAPP", "ShadowRAPP", "AINexus",
              "AINexus-Demo", "nexus", "nexus-engine",
              "NexusMetaverse", "TheMatrix"}
    )),
    ("ms-stack", "MS Copilot/M365", "#a4c8e8", lambda n, d: n in {
        "Copilot-Agent-365", "EntraCopilotAgent365",
        "copilot-agent-365-docker", "M365Agents",
        "M365AgentDemoer", "M365AgentSDKAI",
        "M365DemoRecorderandPlayer", "skills-for-copilot-studio",
        "AI-Agent-Templates", "AIBAST-Industry-Agents",
        "aibast-agents-library", "RAPPAgentLibrary-template",
        "RAPP-Agent-Repo", "BillWhalenCopilotstudio",
        "copilot-yolo-mode", "copilotsdktown", "MAC",
        "Business-Insight-Copilot",
    }),
    ("offtopic", "Off-topic / experiments", "#3a4148", lambda n, d: True),
]


def categorize(name: str, desc: str) -> str:
    for key, _label, _color, predicate in CATEGORIES:
        if predicate(name, desc or ""):
            return key
    return "auxiliary"


# ---------------------------------------------------------------- discovery

def fetch_repos() -> list[dict]:
    """Pull every kody-w repo via gh CLI."""
    print("Pulling kody-w repo list via gh...", file=sys.stderr)
    out = subprocess.check_output([
        "gh", "repo", "list", "kody-w", "--limit", "300",
        "--json", "name,description,isPrivate,isFork,url,pushedAt,"
                  "stargazerCount,primaryLanguage",
    ], text=True)
    return json.loads(out)


def grep_local_outbound() -> dict[str, int]:
    """Count outbound kody-w/* references in this repo's source files."""
    pattern = r"kody-w/[a-zA-Z0-9_.-]+"
    counts: Counter[str] = Counter()
    extensions = ["*.md", "*.html", "*.py", "*.sh", "*.json", "*.js",
                  "*.mjs", "*.ps1", "*.cmd", "*.yml", "*.yaml"]
    # Skip our own generator output and per-node listing files that would
    # otherwise feed back as edges from RAPP → every other repo.
    self_outputs = {
        ROOT / "pages" / "about" / "ecosystem.json",
        ROOT / "pages" / "about" / "ecosystem.html",
    }
    for ext in extensions:
        for path in ROOT.rglob(ext):
            if path in self_outputs:
                continue
            if any(p.startswith(".") for p in path.relative_to(ROOT).parts):
                continue
            if "node_modules" in path.parts or ".venv" in path.parts:
                continue
            try:
                text = path.read_text(errors="ignore")
            except Exception:
                continue
            for m in re.findall(pattern, text):
                # Normalize: strip trailing punctuation, .git suffix
                name = m.split("/", 1)[1].rstrip(".,);:'\"!?")
                if name.endswith(".git"):
                    name = name[:-4]
                counts[name] += 1
    return dict(counts)


# Probed outbound from external repos (the 25-repo subagent run).
PROBED_EDGES: dict[str, list[str]] = {
    "ant-farm": ["RAPP"],
    "rapp-installer": ["CommunityRAPP"],
    "rapp-installer-dev": ["CommunityRAPP", "rapp-installer"],
    "rapp-installer-canary": ["CommunityRAPP", "rapp-installer"],
    "RAR": ["RAPP", "RAPP_Store", "rapp-installer"],
    "RAPP_Store": ["RAPP", "RAPP_Store_Private", "RAR", "rapp-zoo"],
    "RAPP_Sense_Store": ["RAPP", "RAPP_Store", "RAR"],
    "rapp-egg-hub": ["RAR", "rapp-installer", "rappterbox", "wildhaven-ai-homes-twin"],
    "rapp-zoo": ["RAPP", "RAPP_Store"],
    "rappterbox": ["RAPP", "rapp-zoo", "wildhaven-ai-homes-twin"],
    "RAPPcards": ["RAR", "rapp-installer"],
    "wildhaven-ai-homes-twin": ["RAPP", "wildhaven-ai-homes-twin-private"],
    "kody-twin": ["rapp-installer"],
    "microsoft-se-team-neighborhood": ["RAPP", "microsoft-se-team-neighborhood-private"],
    "rappterhub": ["openrappter"],
    "mars-barn": ["rappterbook"],
    "lisppy": ["mars-barn-opus", "rappterbook"],
    "CommunityRAPP": ["rapp-installer"],
    "heimdall": ["rapp-installer"],
}


def derived_lineage_edges(names: set[str]) -> list[tuple[str, str, str]]:
    """Edges inferred from naming conventions.

    Returns (source, target, kind) triples. The source is a derivative; the
    target is its progenitor. Edge kind = "lineage".
    """
    edges: list[tuple[str, str, str]] = []
    for n in names:
        # Suffix → kind. We accept both "-x" and "_X" / "_x" separators
        # (e.g. RAPP_Store_Private uses underscore + TitleCase).
        matched = False
        for stem, kind in [("private", "private-mirror"),
                           ("archive", "archive-of"),
                           ("canary", "canary-of"),
                           ("dev", "dev-channel-of")]:
            for sep in ("-", "_"):
                for cap in (stem, stem.title()):
                    suffix = f"{sep}{cap}"
                    if n.endswith(suffix):
                        base = n[: -len(suffix)]
                        if base in names:
                            edges.append((n, base, kind))
                            matched = True
                            break
                if matched:
                    break
            if matched:
                break
        # CommunityRAPP-archive → CommunityRAPP (already handled)
        # rappterbook-v2-state → rappterbook-v2
        if n == "rappterbook-v2-state" and "rappterbook-v2" in names:
            edges.append((n, "rappterbook-v2", "state-of"))
        if n == "lisppy-shepherd" and "lisppy" in names:
            edges.append((n, "lisppy", "extends"))
        # mars-barn-opus / mars-barn-opus-1 → mars-barn
        if n in {"mars-barn-opus", "mars-barn-opus-1"} and "mars-barn" in names:
            edges.append((n, "mars-barn", "variant-of"))
        # rappterbook-* (specialized) → rappterbook
        if n.startswith("rappterbook-") and n != "rappterbook-v2" and \
                "rappterbook" in names:
            edges.append((n, "rappterbook", "extension-of"))
        if n == "rapp-store-archive" and "RAPP_Store" in names:
            edges.append((n, "RAPP_Store", "archive-of"))
    return edges


# ---------------------------------------------------------------- assembly

def build_graph() -> dict:
    repos = fetch_repos()
    repos = [r for r in repos if not r["isFork"]]
    name_set = {r["name"] for r in repos}

    nodes = []
    for r in repos:
        nodes.append({
            "id": r["name"],
            "category": categorize(r["name"], r.get("description") or ""),
            "description": r.get("description") or "",
            "private": bool(r.get("isPrivate")),
            "stars": r.get("stargazerCount", 0),
            "pushedAt": r.get("pushedAt"),
            "url": r.get("url") or f"https://github.com/kody-w/{r['name']}",
            "language": (r.get("primaryLanguage") or {}).get("name") if isinstance(
                r.get("primaryLanguage"), dict) else r.get("primaryLanguage"),
        })

    edges_set: set[tuple[str, str, str]] = set()

    # 1. This repo's outbound references
    local = grep_local_outbound()
    # Normalize known case-collisions
    case_map = {n.lower(): n for n in name_set}
    for ref, count in local.items():
        if ref == "RAPP" or count < 2:
            continue
        canon = case_map.get(ref.lower())
        if canon and canon in name_set and canon != "RAPP":
            edges_set.add(("RAPP", canon, "references"))

    # 2. Probed external edges
    for source, targets in PROBED_EDGES.items():
        if source not in name_set:
            continue
        for tgt in targets:
            canon = case_map.get(tgt.lower(), tgt)
            if canon in name_set and canon != source:
                edges_set.add((source, canon, "references"))

    # 3. Derived lineage
    for source, target, kind in derived_lineage_edges(name_set):
        edges_set.add((source, target, kind))

    edges = [{"source": s, "target": t, "kind": k} for s, t, k in sorted(edges_set)]

    # Compute degree per node
    degree: defaultdict[str, int] = defaultdict(int)
    for e in edges:
        degree[e["source"]] += 1
        degree[e["target"]] += 1
    for n in nodes:
        n["degree"] = degree.get(n["id"], 0)

    categories_meta = [
        {"key": k, "label": label, "color": color}
        for k, label, color, _ in CATEGORIES
    ]

    return {
        "schema": "rapp-ecosystem-graph/1.0",
        "generated_at": subprocess.check_output(
            ["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"], text=True
        ).strip(),
        "categories": categories_meta,
        "nodes": nodes,
        "edges": edges,
        "stats": {
            "total_repos": len(nodes),
            "public_repos": sum(1 for n in nodes if not n["private"]),
            "private_repos": sum(1 for n in nodes if n["private"]),
            "total_edges": len(edges),
            "isolated_repos": sum(1 for n in nodes if n["degree"] == 0),
            "by_category": dict(Counter(n["category"] for n in nodes)),
        },
    }


def write_outputs(data: dict) -> None:
    PAGES.mkdir(parents=True, exist_ok=True)
    DATA_FILE.write_text(json.dumps(data, indent=2) + "\n")
    print(f"wrote {DATA_FILE.relative_to(ROOT)}", file=sys.stderr)

    # Refresh the embedded data block in ecosystem.html if present.
    if HTML_FILE.exists():
        html = HTML_FILE.read_text()
        marker_start = '<script id="ecosystem-data" type="application/json">'
        marker_end = "</script>"
        i = html.find(marker_start)
        if i != -1:
            j = html.find(marker_end, i)
            if j != -1:
                new_block = (
                    marker_start + "\n" + json.dumps(data, indent=2) + "\n"
                )
                html = html[:i] + new_block + html[j:]
                HTML_FILE.write_text(html)
                print(f"refreshed data block in {HTML_FILE.relative_to(ROOT)}",
                      file=sys.stderr)


def main() -> None:
    data = build_graph()
    write_outputs(data)
    s = data["stats"]
    print(f"\nRAPP ecosystem map — {s['total_repos']} repos, "
          f"{s['total_edges']} edges, {s['isolated_repos']} isolated")
    print("By category:")
    for k, v in sorted(s["by_category"].items(), key=lambda kv: -kv[1]):
        print(f"  {k:18s} {v}")


if __name__ == "__main__":
    main()
