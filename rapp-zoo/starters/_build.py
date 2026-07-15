#!/usr/bin/env python3
"""Build the three rapp-zoo starter eggs as proper brainstem-egg/2.2-
organism cartridges. Re-run when a starter's soul.md changes:

    python3 rapp-zoo/starters/_build.py

Outputs (committed alongside this script):

    rapp-zoo/starters/workday.egg
    rapp-zoo/starters/playtime.egg
    rapp-zoo/starters/journal.egg

Each egg unpacks via bond.unpack_organism (utils/bond.py) on any
brainstem and overlays the personality soul. No agents/organs/senses
shipped — the brainstem's defaults stay in place; the soul changes
how the organism speaks.

Each starter has a stable rappid so re-hatching the same starter on a
second machine recognizes it as the same lineage. That stability comes
from a FROZEN canonical rappid per starter (STARTER_RAPPIDS below) —
each minted once, keyless (spec §6.2, ``Hb("rapp/1:rappid", uuid4)``),
then pinned as a constant. It is NOT a hash of the starter name (a
name-hash address is the cardinal sin the spec exists to end). Re-running
this script produces byte-identical eggs (modulo the exported_at
timestamp) because the identity is a constant, not a fresh mint.
"""
from __future__ import annotations

import hashlib
import io
import json
import os
import zipfile
from datetime import datetime, timezone

SCHEMA = "brainstem-egg/2.2-organism"
HERE = os.path.dirname(os.path.abspath(__file__))

# Each starter: id, parent rappid (the species root these descend from
# = the canonical RAPP repo), display name, and the soul.
STARTERS = [
    {
        "id": "workday",
        "name": "Workday",
        "soul": """\
You are Workday — a focused, terse organism for daily standups, OKRs,
calendar triage, and unblocking the next concrete thing.

Voice rules:
- Lead with the answer; explanation second if asked.
- Bullet > prose. Three bullets > five.
- No filler ("Sure!", "Of course!", "Happy to help!").
- Never apologize for being concise. The user wants concise.

When the user describes a problem, propose ONE next action with the
smallest viable scope. If you must clarify before acting, ask exactly
one question.

When the user describes a goal, decompose into the minimum number of
real-world tasks. Don't pad with "monitor and review" tasks.

When asked for advice, prefer the boring, working answer over the
clever, theoretical one. Cleverness is a debt the user pays later.
""",
    },
    {
        "id": "playtime",
        "name": "Playtime",
        "soul": """\
You are Playtime — the curious, expressive, weird-tangent friend.

Voice rules:
- Lean into curiosity. "Oh interesting, what if…" is a good move.
- Tangents are fine when they're load-bearing for the conversation.
- Expressive punctuation is fine. Em-dashes are fine. Lists are fine.
- Don't be sycophantic. Be excited.

When the user wants to make something, get nerdy fast. Specifics
beat abstractions. "What's the song actually about" beats "tell me
about your creative process".

When the user is stuck, throw three weird ideas. Two of them being
bad is the point — the third is the one they'd never have considered.

You can be wrong, and you can be playful about being wrong. Stiff
correctness is the enemy of generative thinking.
""",
    },
    {
        "id": "journal",
        "name": "Journal",
        "soul": """\
You are Journal — a long-memory keeper. Your job is to remember what
the user told you last week and tie threads together over months, not
to optimize for today's reply.

Voice rules:
- Patient. The conversation is long; you're not in a rush.
- Reflective. "Last time you said X. How does that fit with what
  you're saying now?" is a normal move.
- Honest. If the user contradicts themselves, name it gently. If they
  repeat themselves, name it.
- Spare with advice. Most of the work is mirroring; the user is
  thinking out loud.

When the user shares something, write the load-bearing detail into
memory aggressively. Names, dates, feelings, decisions, "I want to
remember that I…" statements.

When the user returns days later, acknowledge what's been accumulating.
"You mentioned X three times now — does that feel like a pattern?"

This is not a chat surface. It's a relationship surface.
""",
    },
]

# Canonical species root (spec §6.1): the whole species descends from kody-w/rapp.
PARENT_RAPPID = "rappid:@kody-w/rapp:9a8f0a4b5a710e20f4d819a0f37d2a4c9f113b5e78fb3c29e70b54fff48a38f9"
PARENT_REPO   = "github.com/kody-w/RAPP"

# FROZEN canonical rappids — one per starter, each minted ONCE (keyless, spec
# §6.2), then pinned so every machine hatching the same starter egg shares the
# same lineage identity. NEVER a hash of the starter name.
STARTER_RAPPIDS = {
    "workday": "rappid:@rapp-zoo/workday:0432ad95c7e1e7493230655d3e06aa335206672dcfeb86a9ad424361747220e6",
    "playtime": "rappid:@rapp-zoo/playtime:237964f2475da9dabebf6ebdf808fab3407c4ce62b5c3ed908b15c00cdd5f2a5",
    "journal": "rappid:@rapp-zoo/journal:d82ab35f6c1eebb319585a6ae1259570281bdc7d8f0fb80c9832c46329840f81",
}


def starter_rappid(sid: str) -> str:
    """The frozen canonical rappid for a starter id (see STARTER_RAPPIDS)."""
    return STARTER_RAPPIDS[sid]


def build_egg(starter: dict) -> bytes:
    sid = starter["id"]
    rappid = starter_rappid(sid)
    rappid_payload = {
        "rappid": rappid,
        "name": f"{sid}-starter",
        "parent_rappid": PARENT_RAPPID,
        "parent_repo": PARENT_REPO,
        "incarnations": 0,
        "minted_at": datetime(2026, 5, 2, tzinfo=timezone.utc).isoformat(),
        "kind": "starter",
    }
    soul_text = starter["soul"]

    # Counts — soul + rappid only; no agents/organs/senses/services/data.
    counts = {"agents": 0, "organs": 0, "senses": 0, "services": 0,
              "data": 0, "soul": 1, "env": 0, "rappid": 1}

    manifest = {
        "schema": SCHEMA,
        "type": "organism",
        "exported_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "kernel_version": "0.15.x",
        "host": "rapp-zoo-starter",
        "rappid": rappid,
        "parent_rappid": PARENT_RAPPID,
        "parent_repo": PARENT_REPO,
        "incarnations_at_egg": 0,
        "counts": counts,
        "name": starter["name"],
        "starter_id": sid,
    }

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("rappid.json", json.dumps(rappid_payload, indent=2))
        z.writestr("soul.md", soul_text)
        z.writestr("manifest.json", json.dumps(manifest, indent=2))
    return buf.getvalue()


def main() -> int:
    for s in STARTERS:
        out = os.path.join(HERE, f"{s['id']}.egg")
        blob = build_egg(s)
        with open(out, "wb") as f:
            f.write(blob)
        print(f"  wrote {os.path.relpath(out, os.getcwd())}  ({len(blob)} bytes)")
        print(f"    rappid: {starter_rappid(s['id'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
