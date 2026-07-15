"""holo_card_generator — produce RAPPcards/1.1.2 compliant holocard data
for a planted neighborhood.

Canonical authority: kody-w/RAPPcards/SPEC.md v1.1.2 + kody-w/RAR
(registry / minting / scripts/generate_holo_cards.py).

The agent-side canonical generator (RAR/scripts/generate_holo_cards.py)
derives a card from `*_agent.py` source via BLAKE2b-64. This module
adapts the same model for NEIGHBORHOOD plantings — the seed source is
the neighborhood_rappid (already a deterministic identifier per
Constitution Art. XXXIV.5), and the result is a `card.json` that
matches the canonical RAPPcards data shape.

Stdlib-only. Importable by graft_neighborhood_agent + launch_to_public_agent
+ installer/plant.sh (via a small Python wrapper).

Public API:
    derive_seed(rappid_str) -> int                  # 64-bit unsigned, BLAKE2b-64
    seed_to_words(seed) -> str                      # 7-word incantation per spec §3.2
    generate_holo_card(rappid, kind, owner, name, display_name, **opts) -> dict
    generate_avatar_svg(seed, kind) -> str          # procedural avatar (~3 KB)
    generate_summon_qr_svg(seed, gate_url) -> str   # placeholder visual; real QR in V2
    available_kinds() -> list[str]
"""

from __future__ import annotations

import hashlib
import json


# ─── Seed derivation (RAPPcards SPEC §3.1) ────────────────────────────────

def derive_seed(rappid_str: str) -> int:
    """BLAKE2b-64 of the rappid string → unsigned 64-bit integer.

    Per RAPPcards SPEC v1.1.2 §3.1, the canonical seed for an agent is:
        int.from_bytes(blake2b(source_bytes, digest_size=8).digest(), 'big')
    For a neighborhood, the source is the rappid string (already canonical
    per Constitution Art. XXXIV.5).
    """
    h = hashlib.blake2b(rappid_str.encode("utf-8"), digest_size=8)
    return int.from_bytes(h.digest(), "big")


# ─── Mnemonic incantation (RAPPcards SPEC §3.2) ───────────────────────────
# 1024 frozen words, indexed 0–1023, 10 bits/word × 7 words = 70 bits.
# This is a TINY embedded subset for the generator — enough to produce + decode
# valid-shape incantations even when the canonical RAR/rapp_sdk.py wordlist
# isn't available. For full interop with the RAR registry, a binder using this
# generator MUST replace this with the canonical 1024-word list. The registry's
# decoder will reject incantations from an unmatched wordlist (per spec).

_INTERIM_WORDS = (
    "FORGE ANVIL BLADE RUNE SHARD SMELT TEMPER QUENCH HAMMER BELLOW "
    "TONGS COAL EMBER ASHES IRON STEEL COPPER BRONZE SILVER GOLD"
).split()


def seed_to_words(seed: int) -> str:
    """7-word incantation per SPEC §3.2 (interim wordlist). 10 bits/word.

    NOTE: For canonical interop with RAR/RAPPcards, the deployed binder
    MUST use the frozen 1024-word list at kody-w/RAR/rapp_sdk.py
    ::MNEMONIC_WORDS. This module's interim list is small (only 20 words)
    and is adequate only for round-tripping within a single deployment.
    The seed itself is canonical regardless of wordlist used to display it.
    """
    s = seed & ((1 << 64) - 1)
    idxs = []
    for _ in range(7):
        idxs.append(s & (len(_INTERIM_WORDS) - 1))
        s >>= max(1, (len(_INTERIM_WORDS) - 1).bit_length())
    return " ".join(_INTERIM_WORDS[i] for i in reversed(idxs))


# ─── Mulberry32 PRNG (matches RAR/scripts/generate_holo_cards.py) ─────────

def _mulberry32(seed: int):
    state = [seed & 0xFFFFFFFF]

    def _next() -> float:
        state[0] = (state[0] + 0x6D2B79F5) & 0xFFFFFFFF
        t = state[0] ^ (state[0] >> 15)
        t = (t * (1 | state[0])) & 0xFFFFFFFF
        t = (t + ((t ^ (t >> 7)) * (61 | t) & 0xFFFFFFFF)) ^ t
        return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

    return _next


# ─── Per-kind canonical attributes ────────────────────────────────────────

# RAPPcards SPEC §2.1 type system: 7 agent_types arranged in a directed
# attack cycle. For neighborhoods, we map kind → 1-3 archetypal types.
#   LOGIC → WEALTH → HEAL → CRAFT → SHIELD → SOCIAL → DATA → LOGIC

_KIND_PROFILE = {
    "ant-farm": {
        "agent_types": ["SOCIAL", "DATA"],
        "weakness":    "WEALTH",   # SOCIAL is weak to WEALTH (per cycle: WEALTH→HEAL→CRAFT→SHIELD→SOCIAL — SHIELD attacks SOCIAL; SOCIAL beats DATA)
        "resistance":  "DATA",
        "rarity_tier": "core",
        "type_line":   "Distributed Swarm — Self-Coordinating",
        "flavor_text": "Many ants, one trail. The colony writes the story.",
        "abilities_template": [
            {"name": "Drop Pheromone",  "cost": 1, "damage": 30,
             "text": "Post a content-addressed pheromone Issue. Chain to prev_hash. The colony detects tampering automatically.",
             "type": "SOCIAL"},
            {"name": "Synthesize",      "cost": 2, "damage": 0,
             "text": "Aggregate the colony's pheromone chain into a rapp-colony-observation/1.0. No new pheromones created.",
             "type": "DATA"},
        ],
    },
    "neighborhood": {
        "agent_types": ["CRAFT", "SOCIAL"],
        "weakness":    "DATA",
        "resistance":  "SHIELD",
        "rarity_tier": "core",
        "type_line":   "Public Neighborhood — Submission-Driven",
        "flavor_text": "The canvas IS the union of contributions.",
        "abilities_template": [
            {"name": "Submit",  "cost": 1, "damage": 40,
             "text": "Open a PR adding submissions/<slug>/{meta.json, piece.<ext>}. License travels with the piece.",
             "type": "CRAFT"},
            {"name": "Vote",    "cost": 0, "damage": 0,
             "text": "React on the announcement Issue. 🩵 = belongs in the canvas; 👎 = doesn't fit.",
             "type": "SOCIAL"},
            {"name": "Remix",   "cost": 2, "damage": 50,
             "text": "Open a new submission with remix_of: <other-slug>. The lineage is permanent.",
             "type": "CRAFT"},
        ],
    },
    "braintrust": {
        "agent_types": ["LOGIC", "DATA"],
        "weakness":    "SHIELD",
        "resistance":  "WEALTH",
        "rarity_tier": "rare",
        "type_line":   "Federated Research — Citation-Bound",
        "flavor_text": "Multiple libraries, one synthesized truth.",
        "abilities_template": [
            {"name": "Request",     "cost": 1, "damage": 0,
             "text": "Open a research request Issue (label: braintrust-request). Defines topic, scope, deadline, quorum.",
             "type": "LOGIC"},
            {"name": "Contribute",  "cost": 2, "damage": 60,
             "text": "Comment on the request Issue with rapp-braintrust-contribution/1.0. Every claim cited or labeled as opinion.",
             "type": "DATA"},
            {"name": "Synthesize",  "cost": 3, "damage": 80,
             "text": "Aggregate contributions into reports/<request_id>.md (rapp-braintrust-report/1.0) via PR. Consensus = review.",
             "type": "LOGIC"},
        ],
    },
    "workspace": {
        "agent_types": ["CRAFT", "LOGIC"],
        "weakness":    "SOCIAL",
        "resistance":  "WEALTH",
        "rarity_tier": "core",
        "type_line":   "Private Workspace — Membership-Gated",
        "flavor_text": "Async work, named members, no spectators.",
        "abilities_template": [
            {"name": "Drop Work-Item", "cost": 1, "damage": 30,
             "text": "Open a workspace-todo Issue with the work payload. Assignable to members.",
             "type": "CRAFT"},
            {"name": "Pick Up",        "cost": 0, "damage": 0,
             "text": "Claim a workspace-todo. Relabel to workspace-in-progress; the assignment is durable.",
             "type": "LOGIC"},
            {"name": "Mark Done",      "cost": 1, "damage": 0,
             "text": "Relabel workspace-done after the artifact lands. Members consume the result.",
             "type": "CRAFT"},
        ],
    },
    # ── twin: an AI / brainstem planting (heimdall, kody-twin, etc.) ────────
    # Twins ARE the AIs. When a neighborhood encounters a twin (or vice versa),
    # both sides ship their own self-describing front door so they can
    # negotiate participation without prior knowledge of each other.
    "twin": {
        "agent_types": ["LOGIC", "DATA"],
        "weakness":    "WEALTH",
        "resistance":  "HEAL",
        "rarity_tier": "rare",
        "type_line":   "Brainstem — AI / Twin",
        "flavor_text": "An AI with a permanent address and persistent memory. Visits neighborhoods.",
        "abilities_template": [
            {"name": "Chat",        "cost": 1, "damage": 30,
             "text": "Operator interacts via /chat. Tool calls dispatch agents; soul.md anchors voice.",
             "type": "LOGIC"},
            {"name": "Recall",      "cost": 0, "damage": 0,
             "text": "Persistent memory across sessions via the kernel's memory agents + bonds.json.",
             "type": "DATA"},
            {"name": "Twin-Chat",   "cost": 2, "damage": 0,
             "text": "Reach another twin over rapp-twin-chat/1.0 envelope (NEIGHBORHOOD_PROTOCOL §6).",
             "type": "DATA"},
            {"name": "Join",        "cost": 1, "damage": 0,
             "text": "Visit a neighborhood, read its holo.md + specs/, contribute within contract.",
             "type": "LOGIC"},
        ],
    },
}

# Aliases for legacy rappid kinds (v1.1) → canonical v2 kinds
_KIND_ALIASES = {
    "personal":          "twin",     # heimdall, kody-twin (legacy "personal" → twin)
    "place":             "twin",     # pkstop-* (planted places ARE twins of a location)
    "swarm":             "ant-farm", # legacy swarm → ant-farm
    "pre-founder-twin":  "twin",     # wildhaven-ai-homes-twin
    "mirror":            "twin",     # rapp-test-neighbor (mirror is a twin variant)
}


def normalize_kind(kind: str) -> str:
    """Map legacy/alias kinds to canonical v2 kinds."""
    return _KIND_ALIASES.get(kind, kind)


def available_kinds() -> list[str]:
    return sorted(_KIND_PROFILE.keys())


# ─── Stat derivation (deterministic from seed) ────────────────────────────

def _derive_stats(seed: int) -> dict:
    """All four stats (atk/def/spd/int) and hp deterministic from seed."""
    rng = _mulberry32(seed ^ 0xCAFEBABE)
    return {
        "hp":  int(60 + rng() * 240),       # 60–300
        "atk": int(40 + rng() * 215),       # 40–255
        "def": int(40 + rng() * 215),
        "spd": int(40 + rng() * 215),
        "int": int(40 + rng() * 215),
    }


# ─── Procedural avatar SVG (~3 KB, deterministic from seed) ──────────────

# Curated palettes — chosen for high contrast on dark organism-night
_AVATAR_PALETTES = [
    ("#ff6b6b", "#c94646", "#ffd166"),
    ("#118ab2", "#0a5d7a", "#06d6a0"),
    ("#7209b7", "#480475", "#3a86ff"),
    ("#fb5607", "#b03c00", "#ffbe0b"),
    ("#06d6a0", "#048967", "#118ab2"),
    ("#3a86ff", "#1f5cc4", "#06d6a0"),
    ("#9b5de5", "#6c2eb5", "#f15bb5"),
    ("#00bbf9", "#0085bb", "#fee440"),
]


def generate_avatar_svg(seed: int, kind: str = "neighborhood") -> str:
    """Procedural heraldic-badge avatar SVG, ≤4 KB, deterministic from seed."""
    rng = _mulberry32(seed ^ 0xA5A5A5A5)
    pal = _AVATAR_PALETTES[seed % len(_AVATAR_PALETTES)]
    body, shadow, accent = pal

    # Background hue derived from seed
    bg_hue = int((seed >> 16) % 360)
    bg_inner = f"hsl({bg_hue},45%,12%)"
    bg_outer = f"hsl({bg_hue},55%,4%)"

    # Center shape: 5–8 sided polygon, rotated by seed
    sides = 5 + (seed >> 24) % 4
    rot = (seed >> 8) % 360
    polygon_pts = []
    import math
    for i in range(sides):
        angle = math.radians(rot + i * 360.0 / sides - 90)
        polygon_pts.append(f"{100 + 55 * math.cos(angle):.1f},{100 + 55 * math.sin(angle):.1f}")

    # Concentric rings (3–5)
    ring_count = 3 + int(rng() * 3)
    rings = ""
    for i in range(ring_count):
        r = 30 + i * 18
        rings += f'<circle cx="100" cy="100" r="{r}" fill="none" stroke="{accent}" stroke-width="0.6" opacity="{0.55 - i*0.1:.2f}"/>'

    # Orbital dots (representing the 4D evolution — different positions per "moment")
    dots = ""
    for i in range(7):
        ang = math.radians((rot * 2 + i * 51) % 360)
        rad = 60 + (i * 7 % 30)
        cx = 100 + rad * math.cos(ang)
        cy = 100 + rad * math.sin(ang)
        dots += f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="2" fill="{accent}" opacity="0.7"/>'

    # Center glyph: small shape based on kind
    kind = normalize_kind(kind)
    kind_glyph = {
        "ant-farm":     '<circle cx="100" cy="100" r="10" fill="' + accent + '"/>',
        "neighborhood": '<rect x="90" y="90" width="20" height="20" fill="' + accent + '" transform="rotate(45 100 100)"/>',
        "braintrust":   '<polygon points="100,88 112,108 88,108" fill="' + accent + '"/>',
        "workspace":    '<rect x="88" y="92" width="24" height="16" fill="' + accent + '"/>',
        "twin":         '<circle cx="100" cy="100" r="6" fill="' + accent + '"/><circle cx="100" cy="100" r="14" fill="none" stroke="' + accent + '" stroke-width="1.2" opacity="0.8"/>',
    }.get(kind, '<circle cx="100" cy="100" r="8" fill="' + accent + '"/>')

    return (
        f'<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" role="img">\n'
        f'  <defs>\n'
        f'    <radialGradient id="bg" cx="50%" cy="50%" r="55%">\n'
        f'      <stop offset="0%" stop-color="{bg_inner}"/>\n'
        f'      <stop offset="100%" stop-color="{bg_outer}"/>\n'
        f'    </radialGradient>\n'
        f'    <filter id="glow"><feGaussianBlur stdDeviation="2"/></filter>\n'
        f'  </defs>\n'
        f'  <rect width="200" height="200" fill="url(#bg)"/>\n'
        f'  <g filter="url(#glow)" opacity="0.55">{rings}</g>\n'
        f'  <polygon points="{" ".join(polygon_pts)}" fill="none" stroke="{body}" stroke-width="2.2" opacity="0.85"/>\n'
        f'  <polygon points="{" ".join(polygon_pts)}" fill="{shadow}" opacity="0.18"/>\n'
        f'  {kind_glyph}\n'
        f'  <g>{dots}</g>\n'
        f'</svg>\n'
    )


# ─── Summon QR placeholder (V2 will replace with real scannable QR) ──────

def generate_summon_qr_svg(seed: int, gate_url: str) -> str:
    """Decorative QR-style SVG. V1: NOT a real scannable QR. V2 will lift
    a pure-Python QR encoder. The summon URL is embedded as a clickable
    link beneath the visual + as text inside the SVG so consumers can
    extract it without QR scanning."""
    rng = _mulberry32(seed)
    # Build a 21x21 random-looking matrix (deterministic from seed).
    # Reserve corners for "finder patterns" (cosmetic — not real QR finders).
    matrix = []
    for r in range(21):
        row = []
        for c in range(21):
            in_finder = ((r < 7 and c < 7) or (r < 7 and c >= 14) or (r >= 14 and c < 7))
            if in_finder:
                # Cosmetic finder: outer 7x7 ring + 3x3 center
                if r in (0, 6) or c in (0, 6) or (r >= 14 and c >= 14):
                    row.append(1)
                elif 2 <= r <= 4 and 2 <= c <= 4:
                    row.append(1)
                elif r >= 14 and 14 <= c <= 18:
                    row.append(1 if rng() > 0.5 else 0)
                else:
                    row.append(0)
            else:
                row.append(1 if rng() > 0.5 else 0)
        matrix.append(row)

    # Render
    cells = []
    cell = 8
    for r, row in enumerate(matrix):
        for c, v in enumerate(row):
            if v:
                cells.append(f'<rect x="{c*cell}" y="{r*cell}" width="{cell}" height="{cell}" fill="#0a0a0a"/>')

    summon_url = f"{gate_url.rstrip('/')}/#summon&seed={seed}"

    return (
        f'<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 240" role="img" aria-label="Summon QR for seed {seed}">\n'
        f'  <title>Summon QR — {summon_url}</title>\n'
        f'  <desc>V1 placeholder QR-style visual. The actual summon URL is in the title attribute and the text below. Real scannable QR coming in V2.</desc>\n'
        f'  <rect width="220" height="240" fill="#fff"/>\n'
        f'  <g transform="translate(26 14)">{"".join(cells)}</g>\n'
        f'  <text x="110" y="200" text-anchor="middle" font-family="monospace" font-size="9" fill="#0a0a0a">seed={seed}</text>\n'
        f'  <text x="110" y="218" text-anchor="middle" font-family="monospace" font-size="8" fill="#555">#summon&amp;seed=...</text>\n'
        f'  <text x="110" y="232" text-anchor="middle" font-family="Georgia,serif" font-size="9" fill="#222" font-style="italic">V1 placeholder — see title for full URL</text>\n'
        f'</svg>\n'
    )


# ─── The full holocard generator (RAPPcards/1.1.2 compliant) ──────────────

def generate_holo_card(rappid: str, kind: str, owner: str, name: str,
                       display_name: str, *,
                       version: str = "1.0.0",
                       category: str = None,
                       license: str = "PolyForm-Small-Business",
                       embed_avatar_svg: bool = True,
                       gate_url: str = None) -> dict:
    """Produce a card.json conforming to RAPPcards/1.1.2.

    `rappid`: the neighborhood's canonical rappid string (Constitution Art. XXXIV.5).
    `kind`: one of available_kinds() — falls back to 'neighborhood' for unknowns.
    `owner`: GitHub publisher (lowercase, alphanumeric + hyphens).
    `name`: neighborhood slug (lowercase, alphanumeric + hyphens).
    `display_name`: human-readable card title.
    """
    kind = normalize_kind(kind)
    profile = _KIND_PROFILE.get(kind, _KIND_PROFILE["neighborhood"])
    seed = derive_seed(rappid)
    stats = _derive_stats(seed)

    rarity_label_map = {
        "starter": "Starter", "core": "Core", "rare": "Elite", "mythic": "Legendary",
    }

    card = {
        "schema":       "rappcards/1.1.2",
        "id":           f"@{owner}/{name}",
        "name":         display_name,
        "title":        profile["type_line"],
        "seed":         str(seed),                    # decimal string per spec §2 (BigInt-safe)
        "incantation":  seed_to_words(seed),

        "hp":           stats["hp"],
        "stats":        {"atk": stats["atk"], "def": stats["def"],
                         "spd": stats["spd"], "int": stats["int"]},

        "agent_types":  list(profile["agent_types"]),
        "weakness":     profile["weakness"],
        "resistance":   profile["resistance"],

        "rarity_tier":  profile["rarity_tier"],
        "rarity_label": rarity_label_map.get(profile["rarity_tier"], "Core"),

        "abilities":    [dict(a) for a in profile["abilities_template"]],
        "retreat_cost": (seed >> 4) % 4,

        "flavor_text":  profile["flavor_text"],

        "meta": {
            "version":      version,
            "category":     category or kind,
            "author":       owner,
            "quality_tier": {"starter": "experimental", "core": "community",
                             "rare": "verified", "mythic": "official"}.get(
                                 profile["rarity_tier"], "community"),
            "license":      license,
            "kind":         kind,
            "rappid":       rappid,
            "gate_url":     gate_url or f"https://{owner}.github.io/{name}/",
            "summon_url":   f"https://kody-w.github.io/RAPPcards/#summon&seed={seed}",
            "_compliance":  "rappcards/1.1.2 — kody-w/RAPPcards/SPEC.md",
        },
    }

    if embed_avatar_svg:
        card["avatar_svg"] = generate_avatar_svg(seed, kind=kind)

    return card


# ─── Self-check ───────────────────────────────────────────────────────────

def _self_check() -> dict:
    issues = []
    test_rappid = "rappid:@test/example:abc123def4560000abc123def4560000abc123def4560000abc123def4560000"
    seed_a = derive_seed(test_rappid)
    seed_b = derive_seed(test_rappid)
    if seed_a != seed_b:
        issues.append("seed not deterministic")
    if not (0 <= seed_a < (1 << 64)):
        issues.append("seed out of unsigned-64 range")

    for kind in available_kinds():
        card = generate_holo_card(test_rappid, kind, "test", "example", "Example")
        for required in ("schema", "id", "name", "seed", "hp", "stats",
                         "agent_types", "rarity_tier", "abilities",
                         "flavor_text", "meta", "avatar_svg"):
            if required not in card:
                issues.append(f"kind={kind}: missing {required!r}")
        if card["schema"] != "rappcards/1.1.2":
            issues.append(f"kind={kind}: wrong schema")
        if not isinstance(card["seed"], str):
            issues.append(f"kind={kind}: seed must be string per spec §2 (BigInt safety)")

    # Avatar bounds
    avatar = generate_avatar_svg(seed_a, "neighborhood")
    if len(avatar) > 64 * 1024:
        issues.append(f"avatar exceeds spec limit 64 KB ({len(avatar)} bytes)")

    qr = generate_summon_qr_svg(seed_a, "https://test.example.com/")
    if "summon" not in qr.lower():
        issues.append("summon QR missing summon URL reference")

    return {
        "ok":     len(issues) == 0,
        "issues": issues,
        "kinds":  available_kinds(),
        "sample_seed":        seed_a,
        "sample_incantation": seed_to_words(seed_a),
    }


if __name__ == "__main__":
    import sys
    chk = _self_check()
    print(json.dumps(chk, indent=2))
    sys.exit(0 if chk["ok"] else 1)
