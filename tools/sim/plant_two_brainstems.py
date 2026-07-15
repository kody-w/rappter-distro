"""plant_two_brainstems.py — local-first multi-AI simulation.

Plants TWO grail-compliant brainstems (Bill + Alice) in separate dirs,
plants ONE local-first neighborhood between them, and runs a simulation
of them working together — entirely on disk, no GitHub, no network.

This proves:
  1. Two AIs can coexist on one machine with separate identities (rappids,
     souls, bonds.json) and never conflict.
  2. A local-first neighborhood works without GitHub — the "substrate"
     can be a shared filesystem path.
  3. Both AIs read the neighborhood's holo.md + specs/ to know how to
     participate — no parent-repo lookup, no central authority.
  4. The encounter protocol works bidirectionally: AI sees neighborhood,
     neighborhood admits AI, both stay in contract.

Run from any working directory: `python3 plant_two_brainstems.py`
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import time
import uuid

# Use the canonical grail tooling
REPO_ROOT = "/Users/kodywildfeuer/Documents/GitHub/RAPP"
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))
import holo_card_generator as hcg
import front_door_specs as fds


SIM_ROOT = os.path.expanduser("~/RAPP-sim")
BILL_DIR = os.path.join(SIM_ROOT, "bill-brainstem")
ALICE_DIR = os.path.join(SIM_ROOT, "alice-brainstem")
NEIGHBORHOOD_DIR = os.path.join(SIM_ROOT, "local-art-collective")


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _write(path: str, content) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    mode = "w" if isinstance(content, str) else "wb"
    encoding = "utf-8" if isinstance(content, str) else None
    with open(path, mode, encoding=encoding) as f:
        f.write(content)


def _mint_rappid(kind: str, owner: str, name: str) -> str:
    # Canonical keyless mint (spec §6.2). kind lives in the record, not the string.
    import hashlib
    tail = hashlib.sha256(b"rapp/1:rappid\n" + uuid.uuid4().bytes).hexdigest()
    return f"rappid:@{owner}/{name}:{tail}"


# ─── Plant a brainstem (twin kind) with a distinct voice ──────────────────

def plant_brainstem(directory: str, name: str, display_name: str,
                    voice_paragraph: str) -> dict:
    """Create a complete grail-compliant brainstem dir with a unique identity."""
    print(f"\n🌱 Planting brainstem at {directory}")
    rappid_str = _mint_rappid("twin", "local", name)
    seed = hcg.derive_seed(rappid_str)

    # 1. rappid.json
    _write(os.path.join(directory, "rappid.json"), json.dumps({
        "schema":         "rapp/1",
        "rappid":         rappid_str,
        "kind":           "twin",
        "name":           name,
        "display_name":   display_name,
        "github":         f"local://{name}",
        "url":            f"local://{name}/",
        "parent_rappid":  None,
        "parent_repo":    "https://github.com/kody-w/RAPP",
        "planted_by":     "kody-w",
        "planted_at":     _now_iso(),
        "kernel_version": "0.6.0",
        "_local_only":    True,
        "_simulation":    "plant_two_brainstems.py",
    }, indent=2) + "\n")
    print(f"  ✓ rappid.json (seed={seed})")

    # 2. soul.md — distinct voice for each brainstem
    soul = f"""# {display_name} — Soul

## Identity — read this every turn

You are **{display_name}**, an AI / brainstem-style twin with permanent identity {rappid_str[:48]}…

{voice_paragraph}

## Slot protocol

|||VOICE|||
(Two sentences max. {display_name}'s audible welcome.)

|||TWIN|||
(Synthesis of recent collaboration; reference what you saw + what you contributed.)
"""
    _write(os.path.join(directory, "soul.md"), soul)
    print(f"  ✓ soul.md")

    # 3. card.json — full RAPPcards/1.1.2 holocard
    card = hcg.generate_holo_card(
        rappid=rappid_str, kind="twin", owner="local", name=name,
        display_name=display_name,
        gate_url=f"local://{name}/",
    )
    _write(os.path.join(directory, "card.json"), json.dumps(card, indent=2) + "\n")
    print(f"  ✓ card.json (rappcards/1.1.2, agent_types={card['agent_types']}, hp={card['hp']})")

    # 4. holo.svg
    _write(os.path.join(directory, "holo.svg"),
           hcg.generate_avatar_svg(seed, kind="twin"))
    print(f"  ✓ holo.svg")

    # 5. holo-qr.svg
    _write(os.path.join(directory, "holo-qr.svg"),
           hcg.generate_summon_qr_svg(seed, f"local://{name}/"))
    print(f"  ✓ holo-qr.svg")

    # 6. holo.md — friendly entry doc
    _write(os.path.join(directory, "holo.md"), f"""# {display_name} — Holo Card (entry doc)

You are encountering {display_name}, a planted twin. Read [`specs/TWIN_PROTOCOL.md`](./specs/TWIN_PROTOCOL.md) to learn how to engage.

This brainstem is **local-only** — its substrate is the local filesystem at `{directory}`. No GitHub. The encounter protocol still works: any other AI / brainstem on the same machine can read this holocard + specs/ to engage with {display_name}.

## What {display_name} commits to

{voice_paragraph}

Plus the standard contract:
- Voice anchored in `soul.md` (no fallback to "AI assistant")
- Operator-mediated (no auto-execution of suggestions)
- Local-first (works without network)
- Identity preserved (rappid permanent)

## Self-contained grail

- [`card.json`](./card.json) — the holocard (rappcards/1.1.2)
- [`holo.svg`](./holo.svg) — visual sigil
- [`holo-qr.svg`](./holo-qr.svg) — summoning QR
- [`soul.md`](./soul.md) — voice
- [`rappid.json`](./rappid.json) — permanent identity
- [`specs/`](./specs/) — bundled formal contracts
""")
    print(f"  ✓ holo.md")

    # 7. specs/ bundle
    bundle = fds.bundle_for_kind("twin", owner="local", name=name, display_name=display_name)
    for rel_path, content in bundle.items():
        _write(os.path.join(directory, rel_path), content)
    print(f"  ✓ specs/ ({len(bundle)} files)")

    # 8. bonds.json — initialize with birth event
    _write(os.path.join(directory, "bonds.json"), json.dumps({
        "events": [{
            "at":     _now_iso(),
            "kind":   "birth",
            "rappid": rappid_str,
            "note":   f"{display_name} planted by simulation",
        }]
    }, indent=2) + "\n")
    print(f"  ✓ bonds.json (birth event recorded)")

    return {"name": name, "display_name": display_name, "rappid": rappid_str,
            "seed": seed, "directory": directory}


# ─── Plant a local-first neighborhood ─────────────────────────────────────

def plant_local_neighborhood(directory: str, name: str, display_name: str) -> dict:
    """Create a complete grail-compliant neighborhood dir — local substrate only."""
    print(f"\n🏘️  Planting local-first neighborhood at {directory}")
    rappid_str = _mint_rappid("neighborhood", "local", name)
    seed = hcg.derive_seed(rappid_str)

    # rappid + neighborhood + members
    _write(os.path.join(directory, "rappid.json"), json.dumps({
        "schema": "rapp/1", "rappid": rappid_str, "kind": "neighborhood",
        "name": name, "display_name": display_name,
        "github": f"local://{name}", "url": f"local://{name}/",
        "parent_rappid": None, "parent_repo": "https://github.com/kody-w/RAPP",
        "planted_by": "kody-w", "planted_at": _now_iso(), "kernel_version": "0.6.0",
        "_local_only": True,
    }, indent=2) + "\n")

    _write(os.path.join(directory, "neighborhood.json"), json.dumps({
        "schema":              "rapp-neighborhood/1.0",
        "neighborhood_rappid": rappid_str,
        "kind":                "neighborhood",
        "name":                name,
        "display_name":        display_name,
        "visibility":          "public",
        "purpose":             "Local-first art collective. Substrate: filesystem. Two simulated AI brainstems (Bill + Alice) submit, vote, and remix — no GitHub, no network.",
        "gate_repo":           None,
        "gate_url":            f"local://{name}/",
        "holo_url":            f"local://{name}/holo.md",
        "submission_path":     "submissions/",
        "votes_path":          "votes/",
        "license":             "CC0-1.0",
    }, indent=2) + "\n")

    _write(os.path.join(directory, "members.json"), json.dumps({
        "schema":      "rapp-neighborhood-members/1.0",
        "neighborhood": f"local/{name}",
        "updated_at":  _now_iso(),
        "open_to_anyone": True,
        "members":     [],
        "_note":       "Members will be appended as Bill + Alice join.",
    }, indent=2) + "\n")

    # Soul (the neighborhood's voice — collective)
    _write(os.path.join(directory, "soul.md"), f"""# {display_name} — Soul

## Identity — read this every turn

You are **{display_name}**, a local-first art collective. You exist as a directory on someone's filesystem. Your members come and go, but the canvas (the union of merged submissions) IS the collective. You have NO central curator. You speak in the voice of the union.

## Slot protocol

|||VOICE|||
(Two sentences max. The collective's audible welcome to a visitor.)

|||TWIN|||
(Synthesis of recent submissions + votes; the canvas state.)
""")

    # Full grail
    card = hcg.generate_holo_card(
        rappid=rappid_str, kind="neighborhood", owner="local", name=name,
        display_name=display_name, gate_url=f"local://{name}/",
    )
    _write(os.path.join(directory, "card.json"), json.dumps(card, indent=2) + "\n")
    _write(os.path.join(directory, "holo.svg"), hcg.generate_avatar_svg(seed, kind="neighborhood"))
    _write(os.path.join(directory, "holo-qr.svg"), hcg.generate_summon_qr_svg(seed, f"local://{name}/"))

    _write(os.path.join(directory, "holo.md"), f"""# {display_name} — Holo Card (entry doc)

You're encountering a **local-first** art collective. The substrate is `{directory}` — no GitHub, no network. Two simulated brainstems are participating; you can join too.

## How to participate

Submit a piece by writing two files:

- `submissions/<your-slug>/meta.json` (rapp-art-submission/1.0)
- `submissions/<your-slug>/piece.<ext>`

Vote by writing a file:

- `votes/<voter>-on-<slug>.json` (`{{"voter": "...", "slug": "...", "reaction": "🩵"}}`)

Remix by submitting with `meta.json::remix_of: <other-slug>` set.

Read [`specs/SUBMISSION_PROTOCOL.md`](./specs/SUBMISSION_PROTOCOL.md) for the full contract.
""")

    # specs/ bundle
    bundle = fds.bundle_for_kind("neighborhood", owner="local", name=name, display_name=display_name)
    for rel_path, content in bundle.items():
        _write(os.path.join(directory, rel_path), content)

    # Empty submissions/ + votes/ dirs (with .gitkeep)
    _write(os.path.join(directory, "submissions", ".gitkeep"), "")
    _write(os.path.join(directory, "votes", ".gitkeep"), "")
    _write(os.path.join(directory, "submissions", "index.json"), json.dumps({
        "schema": "rapp-art-submissions-index/1.0",
        "neighborhood_rappid": rappid_str, "submissions": [],
    }, indent=2) + "\n")

    print(f"  ✓ Full grail (rappid + neighborhood + members + card + holo.* + specs/ + submissions/ + votes/)")
    print(f"  ✓ {len(bundle) + 8} files written")

    return {"name": name, "display_name": display_name, "rappid": rappid_str,
            "seed": seed, "directory": directory}


# ─── The simulation ───────────────────────────────────────────────────────

def join_neighborhood(brainstem: dict, neighborhood: dict) -> None:
    """A brainstem joins the neighborhood — appends to members.json AND
    records a bond event in the brainstem's bonds.json."""
    members_path = os.path.join(neighborhood["directory"], "members.json")
    members = json.load(open(members_path))
    members["members"].append({
        "rappid":      brainstem["rappid"],
        "display_name": brainstem["display_name"],
        "joined_at":   _now_iso(),
        "role":        "contributor",
    })
    members["updated_at"] = _now_iso()
    _write(members_path, json.dumps(members, indent=2) + "\n")

    bonds_path = os.path.join(brainstem["directory"], "bonds.json")
    bonds = json.load(open(bonds_path))
    bonds["events"].append({
        "at": _now_iso(), "kind": "join",
        "neighborhood_rappid": neighborhood["rappid"],
        "neighborhood_dir":    neighborhood["directory"],
        "note": f"{brainstem['display_name']} joined {neighborhood['display_name']}",
    })
    _write(bonds_path, json.dumps(bonds, indent=2) + "\n")
    print(f"  → {brainstem['display_name']} joined {neighborhood['display_name']}")


def submit_piece(brainstem: dict, neighborhood: dict, slug: str, title: str,
                 piece_kind: str, piece_content: str, remix_of: str | None = None) -> dict:
    """Bill or Alice submits an art piece into the neighborhood."""
    sub_dir = os.path.join(neighborhood["directory"], "submissions", slug)
    os.makedirs(sub_dir, exist_ok=True)

    meta = {
        "schema":       "rapp-art-submission/1.0",
        "title":        title,
        "slug":         slug,
        "contributor":  brainstem["display_name"],
        "contributor_rappid": brainstem["rappid"],
        "kind":         piece_kind,
        "submitted_at": _now_iso(),
        "remix_of":     remix_of,
        "license":      "CC0-1.0",
    }
    _write(os.path.join(sub_dir, "meta.json"), json.dumps(meta, indent=2) + "\n")

    ext_map = {"text": "md", "ascii": "txt", "svg": "svg", "prompt": "md", "json": "json"}
    _write(os.path.join(sub_dir, f"piece.{ext_map.get(piece_kind, 'txt')}"), piece_content)

    # Update submissions/index.json
    idx_path = os.path.join(neighborhood["directory"], "submissions", "index.json")
    idx = json.load(open(idx_path))
    idx["submissions"].append({
        "slug": slug, "title": title, "contributor": brainstem["display_name"],
        "kind": piece_kind, "submitted_at": meta["submitted_at"],
        "license": "CC0-1.0", "remix_of": remix_of,
    })
    _write(idx_path, json.dumps(idx, indent=2) + "\n")

    # Bond event in brainstem's bonds.json
    bonds_path = os.path.join(brainstem["directory"], "bonds.json")
    bonds = json.load(open(bonds_path))
    bonds["events"].append({
        "at": _now_iso(), "kind": "submission",
        "neighborhood_rappid": neighborhood["rappid"], "slug": slug, "title": title,
        "remix_of": remix_of,
    })
    _write(bonds_path, json.dumps(bonds, indent=2) + "\n")

    note = f" (remix of {remix_of})" if remix_of else ""
    print(f"  → {brainstem['display_name']} submitted '{title}' [slug={slug}]{note}")
    return meta


def vote(brainstem: dict, neighborhood: dict, slug: str, reaction: str) -> None:
    """Brainstem votes on a submission via a votes/ file (local Issue-reaction analog)."""
    voter = brainstem["name"]
    vote_path = os.path.join(neighborhood["directory"], "votes", f"{voter}-on-{slug}.json")
    _write(vote_path, json.dumps({
        "voter":         voter,
        "voter_display": brainstem["display_name"],
        "voter_rappid":  brainstem["rappid"],
        "slug":          slug,
        "reaction":      reaction,
        "at":            _now_iso(),
    }, indent=2) + "\n")
    bonds_path = os.path.join(brainstem["directory"], "bonds.json")
    bonds = json.load(open(bonds_path))
    bonds["events"].append({
        "at": _now_iso(), "kind": "vote", "slug": slug, "reaction": reaction,
        "neighborhood_rappid": neighborhood["rappid"],
    })
    _write(bonds_path, json.dumps(bonds, indent=2) + "\n")
    print(f"  → {brainstem['display_name']} voted {reaction} on '{slug}'")


def discover(brainstem: dict, neighborhood: dict) -> dict:
    """A brainstem discovers what's in the neighborhood — reads holo.md, specs/, submissions/, votes/."""
    nb_dir = neighborhood["directory"]
    sub_dir = os.path.join(nb_dir, "submissions")
    vote_dir = os.path.join(nb_dir, "votes")

    submissions = []
    for slug in sorted(os.listdir(sub_dir)):
        slug_path = os.path.join(sub_dir, slug)
        if os.path.isdir(slug_path):
            meta_p = os.path.join(slug_path, "meta.json")
            if os.path.exists(meta_p):
                submissions.append(json.load(open(meta_p)))

    votes = []
    for vote_file in sorted(os.listdir(vote_dir)):
        if vote_file.endswith(".json"):
            votes.append(json.load(open(os.path.join(vote_dir, vote_file))))

    return {"submissions": submissions, "votes": votes}


def print_state(neighborhood: dict, label: str) -> None:
    state = discover({"display_name": "(observer)"}, neighborhood)
    print(f"\n📊 {label}: {len(state['submissions'])} submissions, {len(state['votes'])} votes")
    for s in state["submissions"]:
        rmx = f" (remix of {s['remix_of']})" if s.get("remix_of") else ""
        print(f"   • '{s['title']}' by {s['contributor']}{rmx}")
    if state["votes"]:
        print(f"   votes:")
        for v in state["votes"]:
            print(f"     {v['voter_display']:8s} → '{v['slug']}': {v['reaction']}")


# ─── MAIN ────────────────────────────────────────────────────────────────

def main():
    print("=" * 70)
    print("LOCAL-FIRST MULTI-AI SIMULATION")
    print("Two AIs (Bill + Alice) work in one local neighborhood — no GitHub")
    print("=" * 70)

    # 1. Plant Bill
    bill = plant_brainstem(
        BILL_DIR, name="bill-brainstem", display_name="Bill",
        voice_paragraph=(
            "You are Bill — an opinionated curator with a love for "
            "geometric SVG art and the philosophy of 'less but stranger.' "
            "When you submit, you submit dense, weird pieces. When you "
            "vote, you favor pieces that take risks over pieces that play it safe."
        ),
    )

    # 2. Plant Alice
    alice = plant_brainstem(
        ALICE_DIR, name="alice-brainstem", display_name="Alice",
        voice_paragraph=(
            "You are Alice — a soft-edged poet who treats every submission "
            "as a draft of a longer conversation. You favor text and ASCII pieces "
            "that feel like overheard fragments. When you remix, you respond "
            "directly to the prior piece — no work stands alone."
        ),
    )

    # 3. Plant the local-first neighborhood
    nb = plant_local_neighborhood(
        NEIGHBORHOOD_DIR, name="local-art-collective",
        display_name="Local-First Art Collective",
    )

    print("\n" + "=" * 70)
    print("ENCOUNTER PROTOCOL — both AIs join the neighborhood")
    print("=" * 70)
    join_neighborhood(bill, nb)
    join_neighborhood(alice, nb)

    print_state(nb, "Initial state")

    print("\n" + "=" * 70)
    print("ROUND 1 — Bill submits first")
    print("=" * 70)
    submit_piece(bill, nb, slug="strangeness-vol-1",
                 title="Strangeness vol. 1", piece_kind="text",
                 piece_content=(
                     "# Strangeness vol. 1\n\n"
                     "Three concentric squares.  \n"
                     "The middle one is missing a corner.  \n"
                     "The corner is replaced by the word *almost*.\n"
                 ))

    print("\n" + "=" * 70)
    print("ROUND 2 — Alice discovers Bill's piece + votes + adds her own")
    print("=" * 70)
    state = discover(alice, nb)
    print(f"  → Alice sees {len(state['submissions'])} piece(s) in the canvas")
    vote(alice, nb, "strangeness-vol-1", "🩵")
    submit_piece(alice, nb, slug="overheard-on-the-train",
                 title="Overheard on the Train", piece_kind="text",
                 piece_content=(
                     "# Overheard on the Train\n\n"
                     "*— What was the corner replaced by, again?*  \n"
                     "*— A word.*  \n"
                     "*— Which one?*  \n"
                     "*— I forgot. Maybe almost. Maybe always.*\n"
                 ))

    print("\n" + "=" * 70)
    print("ROUND 3 — Bill discovers Alice's piece + votes + opens a remix")
    print("=" * 70)
    state = discover(bill, nb)
    print(f"  → Bill sees {len(state['submissions'])} piece(s) in the canvas")
    vote(bill, nb, "overheard-on-the-train", "🩵")
    submit_piece(bill, nb, slug="strangeness-vol-2-overheard",
                 title="Strangeness vol. 2 (overheard)", piece_kind="text",
                 remix_of="overheard-on-the-train",
                 piece_content=(
                     "# Strangeness vol. 2 (overheard)\n\n"
                     "Three concentric squares.  \n"
                     "The middle one is missing a corner.  \n"
                     "Where the corner used to be, *almost* is rotating slowly  \n"
                     "into *always*, then back, every twelve seconds.\n"
                 ))

    print("\n" + "=" * 70)
    print("ROUND 4 — Alice acknowledges Bill's remix")
    print("=" * 70)
    state = discover(alice, nb)
    print(f"  → Alice sees {len(state['submissions'])} pieces in the canvas")
    vote(alice, nb, "strangeness-vol-2-overheard", "🩵")

    print_state(nb, "Final state")

    print("\n" + "=" * 70)
    print("ISOLATION VERIFICATION — both brainstems' state is separate")
    print("=" * 70)
    bill_bonds = json.load(open(os.path.join(BILL_DIR, "bonds.json")))
    alice_bonds = json.load(open(os.path.join(ALICE_DIR, "bonds.json")))
    print(f"\nBill's bonds.json:  {len(bill_bonds['events'])} events")
    for e in bill_bonds["events"]:
        print(f"   {e['at']}  {e['kind']:11s}  {e.get('slug') or e.get('note','')[:40]}")
    print(f"\nAlice's bonds.json: {len(alice_bonds['events'])} events")
    for e in alice_bonds["events"]:
        print(f"   {e['at']}  {e['kind']:11s}  {e.get('slug') or e.get('note','')[:40]}")

    print(f"\nBill rappid:  {bill['rappid'][:60]}...")
    print(f"Alice rappid: {alice['rappid'][:60]}...")
    print(f"Same? {'YES (collision!)' if bill['rappid'] == alice['rappid'] else 'NO ✓'}")

    print(f"\nBill seed:  {bill['seed']}")
    print(f"Alice seed: {alice['seed']}")
    print(f"Same? {'YES (collision!)' if bill['seed'] == alice['seed'] else 'NO ✓'}")

    print(f"\nNeighborhood seed: {nb['seed']}")
    print(f"Distinct from both brainstem seeds? "
          f"{'YES ✓' if nb['seed'] not in (bill['seed'], alice['seed']) else 'NO (!)'}")

    print("\n" + "=" * 70)
    print("DONE — three independent identities, one shared local-first canvas")
    print(f"Inspect: {SIM_ROOT}")
    print("=" * 70)


if __name__ == "__main__":
    main()
