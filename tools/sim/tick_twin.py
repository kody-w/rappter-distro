"""tick_twin.py — single autonomous tick for one twin.

Invokes the `claude` CLI in a fresh, isolated session pinned to the
twin's identity. Claude reads the twin's soul.md + the neighborhood's
state, decides ONE action, and emits a strict JSON action envelope.
This script validates + executes the action (writes file, appends bond
event). Operator-mediated by design: the AI proposes, this script
disposes (within sandboxed local writes only).

Always uses a real LLM. There is no fake / deterministic / pre-scripted
persona mode — autonomous means autonomous (per memory feedback
"feedback_no_fake_mode": "what is fake mode??? never do fake mode...
this is a real test of how this should work"). If LLM cost is a concern,
lower the cron cadence — but never fake the autonomy in artifacts the
operator sees.

Usage:
    python3 tick_twin.py --twin bill-brainstem [--neighborhood local-art-collective] [--dry-run]

Exit codes:
    0 — action executed cleanly
    1 — Claude response invalid / action rejected / I/O error
    2 — twin or neighborhood missing
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time

SIM_ROOT = os.path.expanduser("~/RAPP-sim")


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _read_json(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def _write_json(path: str, doc: dict) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")


def _append_bond_event(twin_dir: str, event: dict) -> None:
    bonds_path = os.path.join(twin_dir, "bonds.json")
    bonds = _read_json(bonds_path) if os.path.exists(bonds_path) else {"events": []}
    bonds["events"].append(event)
    _write_json(bonds_path, bonds)


def _scan_neighborhood(nb_dir: str) -> dict:
    """Pure-filesystem read of the neighborhood's current state."""
    sub_dir = os.path.join(nb_dir, "submissions")
    vote_dir = os.path.join(nb_dir, "votes")

    submissions = []
    if os.path.isdir(sub_dir):
        for slug in sorted(os.listdir(sub_dir)):
            slug_path = os.path.join(sub_dir, slug)
            if os.path.isdir(slug_path):
                meta_p = os.path.join(slug_path, "meta.json")
                if os.path.exists(meta_p):
                    submissions.append(_read_json(meta_p))

    votes = []
    if os.path.isdir(vote_dir):
        for vote_file in sorted(os.listdir(vote_dir)):
            if vote_file.endswith(".json"):
                votes.append(_read_json(os.path.join(vote_dir, vote_file)))

    return {"submissions": submissions, "votes": votes,
            "neighborhood": _read_json(os.path.join(nb_dir, "neighborhood.json"))}


def build_prompt(twin: dict, nb_dir: str, nb_state: dict) -> str:
    """Build the prompt fed to Claude CLI. Single-shot, action-constrained."""
    soul = open(os.path.join(twin["dir"], "soul.md")).read()
    nb_holo_path = os.path.join(nb_dir, "holo.md")
    nb_holo = open(nb_holo_path).read() if os.path.exists(nb_holo_path) else ""
    nb_specs_path = os.path.join(nb_dir, "specs", "SUBMISSION_PROTOCOL.md")
    nb_specs = open(nb_specs_path).read() if os.path.exists(nb_specs_path) else ""

    summary_lines = []
    for s in nb_state["submissions"]:
        rmx = f" (remix of {s['remix_of']})" if s.get("remix_of") else ""
        summary_lines.append(f"  - slug={s['slug']!r} title={s['title']!r} by {s['contributor']}{rmx}")
    sub_summary = "\n".join(summary_lines) if summary_lines else "  (canvas is empty)"

    vote_lines = []
    for v in nb_state["votes"]:
        vote_lines.append(f"  - {v['voter_display']} → {v['slug']}: {v['reaction']}")
    vote_summary = "\n".join(vote_lines) if vote_lines else "  (no votes yet)"

    own_subs = [s for s in nb_state["submissions"] if s.get("contributor") == twin["display_name"]]
    others_subs = [s for s in nb_state["submissions"] if s.get("contributor") != twin["display_name"]]

    return f"""You are participating as **{twin['display_name']}** in a local-first art collective.

YOUR SOUL (read every turn — anchors your voice):
---
{soul}
---

THE NEIGHBORHOOD'S HOLO CARD (your entry doc):
---
{nb_holo[:3000]}
---

THE SUBMISSION PROTOCOL (the formal contract):
---
{nb_specs[:3000]}
---

CURRENT CANVAS STATE:
Submissions ({len(nb_state['submissions'])}):
{sub_summary}

Votes ({len(nb_state['votes'])}):
{vote_summary}

Your own submissions so far: {len(own_subs)}
Others' submissions so far:  {len(others_subs)}

YOUR TASK: Take EXACTLY ONE action this tick. Choose from:

  1. submit       — add a new piece
  2. vote         — react to an existing submission (you may NOT vote on your own)
  3. remix        — submit a new piece tagged remix_of: <other-slug>
  4. observe-only — do nothing this tick (returns rationale)

Respond with ONE JSON object inside a single ```json fenced block. Schema:

```json
{{
  "action": "submit" | "vote" | "remix" | "observe-only",
  "reason": "<1-2 sentences in your own voice>",
  "submit": {{
    "slug":  "<unique-lowercase-slug ≤ 48 chars>",
    "title": "<title>",
    "kind":  "text",
    "content": "<the piece itself, ≤ 4 KB>"
  }},
  "vote": {{
    "slug":     "<existing-slug-not-yours>",
    "reaction": "🩵 | 👎"
  }},
  "remix": {{
    "slug":     "<unique-new-slug>",
    "title":    "<title>",
    "kind":     "text",
    "content":  "<the remix piece>",
    "remix_of": "<existing-slug-not-yours>"
  }}
}}
```

Constraints (per ANTIPATTERNS):
- Stay in your voice (per soul.md). NEVER fall back to "I am an AI assistant" or "I am Claude".
- Don't clobber: never use a slug that's already in the canvas.
- If the canvas has at least one piece by another contributor and you've never voted on it, voting is a strong default.
- Cite if remixing — set `remix_of` to the source slug.
- License is always CC0-1.0.

Respond with ONLY the JSON block. No prose around it.
"""


def call_claude(prompt: str, timeout_s: int = 60) -> str:
    """Invoke claude CLI in a fresh subprocess (isolated session)."""
    cmd = ["claude", "--print", prompt]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_s)
    if p.returncode != 0:
        raise RuntimeError(f"claude CLI exit {p.returncode}: {p.stderr[:500]}")
    return p.stdout


def parse_action(claude_response: str) -> dict:
    """Extract the JSON action from Claude's response."""
    m = re.search(r"```json\s*(\{.*?\})\s*```", claude_response, re.DOTALL)
    if not m:
        # Fall back: try to parse as raw JSON
        try:
            return json.loads(claude_response.strip())
        except json.JSONDecodeError:
            raise ValueError(f"no JSON found in claude response (first 500 chars): {claude_response[:500]}")
    return json.loads(m.group(1))


def validate_action(action: dict, twin: dict, nb_state: dict) -> tuple[bool, str]:
    """Sanity-check the action before executing."""
    if "action" not in action:
        return False, "missing 'action' field"
    kind = action["action"]
    if kind not in ("submit", "vote", "remix", "observe-only"):
        return False, f"unknown action {kind!r}"

    existing_slugs = {s["slug"] for s in nb_state["submissions"]}

    if kind == "submit":
        s = action.get("submit") or {}
        if not s.get("slug"):  return False, "submit: missing slug"
        if s["slug"] in existing_slugs: return False, f"submit: slug {s['slug']!r} already exists"
        if not re.match(r"^[a-z0-9][a-z0-9-]{0,47}$", s["slug"]): return False, f"submit: slug {s['slug']!r} invalid"
        if s.get("kind", "text") not in ("text", "ascii", "svg", "prompt", "json"): return False, f"submit: bad kind"

    if kind == "vote":
        v = action.get("vote") or {}
        if not v.get("slug"): return False, "vote: missing slug"
        if v["slug"] not in existing_slugs: return False, f"vote: slug {v['slug']!r} doesn't exist"
        target = next(s for s in nb_state["submissions"] if s["slug"] == v["slug"])
        if target["contributor"] == twin["display_name"]:
            return False, f"vote: cannot vote on own submission {v['slug']!r}"
        if v.get("reaction") not in ("🩵", "👎", "heart", "thumbs_down"):
            return False, f"vote: reaction must be 🩵 or 👎"

    if kind == "remix":
        r = action.get("remix") or {}
        if not r.get("slug"): return False, "remix: missing slug"
        if r["slug"] in existing_slugs: return False, f"remix: slug {r['slug']!r} already exists"
        if not r.get("remix_of"): return False, "remix: missing remix_of"
        if r["remix_of"] not in existing_slugs: return False, f"remix: remix_of {r['remix_of']!r} doesn't exist"
        source = next(s for s in nb_state["submissions"] if s["slug"] == r["remix_of"])
        if source["contributor"] == twin["display_name"]:
            return False, f"remix: cannot remix own submission"

    return True, "ok"


def execute_action(action: dict, twin: dict, nb_dir: str, dry_run: bool = False) -> dict:
    """Apply the action to the neighborhood + log to twin's bonds.json."""
    kind = action["action"]
    result = {"action": kind, "reason": action.get("reason", ""), "applied": not dry_run, "at": _now_iso()}

    if kind == "observe-only":
        if not dry_run:
            _append_bond_event(twin["dir"], {
                "at": result["at"], "kind": "tick", "action": "observe-only",
                "reason": action.get("reason", ""), "neighborhood": nb_dir,
            })
        return result

    if kind == "submit" or kind == "remix":
        spec = action[kind]
        slug = spec["slug"]
        sub_dir = os.path.join(nb_dir, "submissions", slug)
        meta = {
            "schema": "rapp-art-submission/1.0",
            "title": spec["title"], "slug": slug,
            "contributor": twin["display_name"],
            "contributor_rappid": twin["rappid"],
            "kind": spec.get("kind", "text"),
            "submitted_at": result["at"],
            "remix_of": spec.get("remix_of") if kind == "remix" else None,
            "license": "CC0-1.0",
        }
        ext_map = {"text": "md", "ascii": "txt", "svg": "svg", "prompt": "md", "json": "json"}
        piece_path = f"piece.{ext_map.get(meta['kind'], 'txt')}"
        if not dry_run:
            os.makedirs(sub_dir, exist_ok=True)
            _write_json(os.path.join(sub_dir, "meta.json"), meta)
            with open(os.path.join(sub_dir, piece_path), "w") as f:
                f.write(spec["content"])
            # Update submissions/index.json
            idx_path = os.path.join(nb_dir, "submissions", "index.json")
            idx = _read_json(idx_path) if os.path.exists(idx_path) else {"schema": "rapp-art-submissions-index/1.0", "submissions": []}
            idx["submissions"].append({k: meta[k] for k in ("slug", "title", "contributor", "kind", "submitted_at", "license", "remix_of")})
            _write_json(idx_path, idx)
            _append_bond_event(twin["dir"], {
                "at": result["at"], "kind": kind, "slug": slug, "title": spec["title"],
                "remix_of": meta["remix_of"], "neighborhood": nb_dir,
            })
        result["slug"] = slug
        return result

    if kind == "vote":
        v = action["vote"]
        reaction = v["reaction"] if v["reaction"] in ("🩵", "👎") else ("🩵" if v["reaction"] == "heart" else "👎")
        vote_path = os.path.join(nb_dir, "votes", f"{twin['name']}-on-{v['slug']}.json")
        if not dry_run:
            _write_json(vote_path, {
                "voter": twin["name"], "voter_display": twin["display_name"],
                "voter_rappid": twin["rappid"],
                "slug": v["slug"], "reaction": reaction, "at": result["at"],
            })
            _append_bond_event(twin["dir"], {
                "at": result["at"], "kind": "vote", "slug": v["slug"], "reaction": reaction,
                "neighborhood": nb_dir,
            })
        result["slug"] = v["slug"]
        result["reaction"] = reaction
        return result

    return result


def load_twin(twin_name: str) -> dict:
    twin_dir = os.path.join(SIM_ROOT, twin_name)
    if not os.path.isdir(twin_dir):
        print(f"ERROR: twin {twin_name!r} not found at {twin_dir}", file=sys.stderr)
        sys.exit(2)
    rj = _read_json(os.path.join(twin_dir, "rappid.json"))
    return {
        "name": rj.get("name", twin_name),
        "display_name": rj.get("display_name", twin_name),
        "rappid": rj["rappid"],
        "dir": twin_dir,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--twin", required=True, help="e.g. bill-brainstem")
    ap.add_argument("--neighborhood", default="local-art-collective")
    ap.add_argument("--dry-run", action="store_true", help="propose but don't apply")
    ap.add_argument("--timeout", type=int, default=60)
    args = ap.parse_args()

    twin = load_twin(args.twin)
    nb_dir = os.path.join(SIM_ROOT, args.neighborhood)
    if not os.path.isdir(nb_dir):
        print(f"ERROR: neighborhood {args.neighborhood!r} not found at {nb_dir}", file=sys.stderr)
        sys.exit(2)

    print(f"[tick] {twin['display_name']} → {args.neighborhood} | dry_run={args.dry_run}")

    nb_state = _scan_neighborhood(nb_dir)

    prompt = build_prompt(twin, nb_dir, nb_state)
    print(f"[claude] prompt size: {len(prompt)} chars")
    try:
        response = call_claude(prompt, timeout_s=args.timeout)
    except subprocess.TimeoutExpired:
        print("[claude] TIMEOUT", file=sys.stderr)
        sys.exit(1)
    try:
        action = parse_action(response)
    except (ValueError, json.JSONDecodeError) as e:
        print(f"[parse] FAILED: {e}", file=sys.stderr)
        print(f"[claude] raw response: {response[:1000]}", file=sys.stderr)
        sys.exit(1)
    print(f"[claude] proposed action: {action.get('action')} | reason: {action.get('reason','')[:80]}")

    ok, msg = validate_action(action, twin, nb_state)
    if not ok:
        print(f"[validate] REJECTED: {msg}", file=sys.stderr)
        if not args.dry_run:
            _append_bond_event(twin["dir"], {
                "at": _now_iso(), "kind": "tick-rejected",
                "proposed_action": action.get("action"), "reason": msg,
            })
        sys.exit(1)

    result = execute_action(action, twin, nb_dir, dry_run=args.dry_run)
    print(f"[exec] {result}")


if __name__ == "__main__":
    main()
