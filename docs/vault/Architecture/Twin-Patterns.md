# Twin Patterns — Global Parallel Omniscience

> *Vault note. The companion to `pages/docs/SPEC.md`'s constitutional articles. Explains how a digital twin lives across multiple devices simultaneously without any merge-back layer, and how it collaborates publicly when it wants to.*

The brainstem is a runtime. The egg is the digital organism. The RAPPID is the soul. **A twin is not stuck on one machine.** This note explains the patterns that make a twin universally available — phone, laptop, edge device, friend's borrowed brainstem — without losing identity, without losing parallel autonomy, and without (yet) requiring the proprietary dreamcatcher merge engine.

---

## The four patterns

### 1. Solo
One brainstem, one twin. The default. Identity minted on first call to `/identity`, persisted at `.brainstem_data/identity.json`, immortal across reboots.

```
[laptop] ──► twin (rappid:twin:@kody-w/personal:abc...)
```

### 2. Parallel omniscience
**Same twin, multiple brainstems, all running independently.** No coordination, no sync, no merge-back. Each incarnation accumulates its own divergent state. They share a RAPPID; they don't share working memory. Like ten copies of yourself solving ten different problems in parallel — same identity, different threads.

```
[laptop] ──► twin (rappid:abc...) — chats about a project
[phone]  ──► twin (rappid:abc...) — answers a question on the train
[edge]   ──► twin (rappid:abc...) — running 24/7 on a Mac mini
[work]   ──► twin (rappid:abc...) — pair-programming session
                    │
                    └── all four are the same twin, four streams,
                        four divergent states
```

How: export your twin once on the home device (`Cmd+K → 📦 Export twin egg`), publish the resulting `.egg` somewhere reachable, then on each new device summon it — `Cmd+K → 🪄 Summon egg from URL`, paste the link, hatch.

The home device's identity gets lifted onto each destination, intact. Both RAPPID and stream-distinct attribution are preserved. **No merge yet.** Each incarnation is a fully autonomous twin until dreamcatcher (Rappter engine, private) reconciles the streams.

### 3. Twin-squared (local collaboration)
**Same twin, same machine, two perspectives.** Open two chat tabs on the same brainstem. Both share the twin's identity, agents, and persistent memory, but each tab has its own conversation history. Use one tab to attack a problem from one angle, the other from another. The twin literally collaborates with itself.

```
[laptop]
   ├── chat tab A (twin viewing problem from angle X)
   └── chat tab B (twin viewing problem from angle Y)
              │
              └── share underlying memory + agents,
                  diverge at the conversation layer
```

This is not a new feature — it's just chat tabs (shipped earlier this session) used reflectively. The per-chat agent toggle even lets you scope each tab to a different agent subset, simulating two specialist viewpoints on the same body.

### 4. Cross-twin collaboration (optional)
**Twin A on Brainstem 1 talks to Twin B on Brainstem 2.** Their RAPPIDs are different. They collaborate through normal chat, exactly the way one human user would talk to another twin via the chat UI. No special protocol, no mesh network, no coordination layer. The chat IS the seam.

If your rapplication's use case requires it, your twin can call another twin's public endpoints (`GET /twin/manifest`) to discover its capabilities, then route messages to its `/chat` endpoint. From the receiving brainstem's perspective, it's just another chat client — the fact that the client is itself an AI is invisible. **There is no difference between an AI using the chat and a human using the chat. We don't change anything.**

```
[Twin A] ──chat──► [Twin B]
   │                  │
   │                  └── treats Twin A as just another user
   │
   └── treats Twin B as just another agent
```

Collaboration is **completely optional**. Most rapplications won't need it. The pattern exists because chat is universal, not because anything special was built.

---

## Summon vectors — how an egg arrives

The egg is the cartridge. Anyone with the egg URL can summon the twin. Three equivalent vectors:

| Vector | UX |
|---|---|
| **Direct URL** | Paste in `Cmd+K → 🪄 Summon egg from URL` |
| **QR code** | `Cmd+K → 🔗 Share twin via QR / link` generates the QR; recipient scans with phone, lands on `/?summon=<url>&rappid=<expected>` deep-link, confirms, hatches. |
| **RAR card incantation** | A `*_agent.py.card` whose `__card__` dict carries a `summon` URL is a card incantation. Drop it on the chat → installs the bare agent + auto-summons the embedded twin egg. The card delivers the *full* twin, not just the agent. |

All three resolve to the same operation: fetch the egg blob, verify the RAPPID (optional pin), unpack into the brainstem. The vector is just delivery.

### Card incantation example

```python
"""kanban_agent — Trello-style kanban + twin profile."""

__manifest__ = { ... }

__card__ = {
    "name":       "Kanban",
    "rarity":     "uncommon",
    "type_line":  "Creature — Agent Productivity",
    # ── Card incantation: dropping this card on a brainstem also
    # summons the twin egg below. Without these fields, the card
    # is just a bare agent install (existing behavior). ──
    "summon":         "https://kody-w.github.io/rapp_store/apps/kanban/twin.egg",
    "summon_rappid":  "rappid:rapp:@kody-w/kanban:9d8e7f6a5b4c3d2e",
    ...
}

class KanbanAgent(BasicAgent): ...
```

Drop this card → bare agent installs to `agents/` AND the embedded twin egg unpacks (UI bundle, state, services). The card is the wormhole. Same mechanism, smaller blast radius — perfect for trading-card distribution.

---

## What makes parallel omniscience safe (without merge)

Two design choices keep N parallel incarnations from corrupting each other while waiting for the dreamcatcher:

1. **Stream IDs are per-incarnation, not packed.** Each brainstem mints its own `stream_id` (stored at `.brainstem_data/stream.json`, excluded from eggs). When Alice's egg lands on Bob's brainstem, Bob's brainstem inherits Alice's RAPPID but keeps Bob-the-machine's stream_id. Frames recorded on Bob's brainstem are *attributable* to Bob's stream — when dreamcatcher arrives, it can tell which incarnation produced which frame.

2. **Frames are append-only and atomic.** Every chat turn is a frame in `.brainstem_data/frames.jsonl`: `{frame_id, rappid, stream_id, local_vt, utc, kind, payload}`. The log is a stream-local timeline. When two incarnations export their state as eggs, the union of their frames is the full divergent history — dreamcatcher reconciles by `frame_id` (no duplicates) and `local_vt` per stream (correct ordering within each device).

The result: parallel omniscience is *lossless waiting for merge.* Nothing gets dropped. When the dreamcatcher engine connects, it has clean, attributable, ordered streams to reconcile.

---

## What's open vs. proprietary

| Layer | What | Where |
|---|---|---|
| Egg cartridge format | `brainstem-egg/2.0` zip + manifest schema | Open — `kody-w/RAPP rapp_brainstem/utils/egg.py` |
| RAPPID format | `rappid:<type>:@publisher/slug:<entropy>` | Open — same file |
| Frame schema | `{frame_id, rappid, stream_id, local_vt, utc, kind, payload}` | Open — `kody-w/RAPP rapp_brainstem/utils/frames.py` |
| Summon endpoints | `/eggs/summon`, `/agents/import` auto-detect, `/rapps/export/*` | Open — `rapp_brainstem/brainstem.py` |
| Twin manifest | `/twin/manifest` — public discovery surface | Open — same file |
| **Assimilation merge engine** | Three-way merge, CRDT-aware state, frame replay, conflict resolution | **Proprietary — Rappter engine, private** |
| Identity / ownership / IP enforcement | Wildhaven IP layer | **Proprietary — Wildhaven, private** |

The open seams are stable, defensive, and tested. The proprietary parts plug in via well-defined seams (`.brainstem_data/_versions/<entropy>/` for staging; the frame log for replay).

---

## Quick reference — the user-facing actions

| Action | Cmd+K | What it does |
|---|---|---|
| Show my RAPPID | 🪪 | Display this brainstem's twin identity |
| Export twin egg | 📦 | Download cross-agent state + agents as a `.egg` |
| Export snapshot egg | 💾 | Full brainstem dump (incl. UI + per-rapp state) |
| Summon egg from URL | 🪄 | Fetch a twin from a public URL, hatch it locally |
| Share twin via QR / link | 🔗 | Generate a summon URL + QR for your hosted egg |
| Browse RAPP_Store | 🛍 | The catalog of public rapplications (each is a summon) |

---

*The brainstem is a console. The egg is a cartridge. The RAPPID is the soul. The twin is alive on every device that hatches it. No merge yet — that's coming with dreamcatcher. Until then, parallel autonomy is enough.*
