# Hero Use Case — Shareable Digital Organisms

> *"Picture you have two phones and through a QR code where it's on your device because it's all local first... so if you have the Internet, if you have a local model, it will run just the same. It won't be as good. So it's like degrading... It's not like a constant cutoff. It's like, 'Hey, I lost access to the best model, but I'm still here for you where I can.'"*
>
> — the operator, on the canonical scenario this platform must satisfy

This document defines the hero scenarios the RAPP platform must satisfy. Every architectural decision is judged against whether it makes these stories work. They are checked-in here so the bar doesn't drift.

---

## 1. Charizard in the Woods (the offline-share canon)

**The story.** Two friends are in the woods. No internet. Each has a phone. One of them has a useful agent — call it Charizard — and the other one needs it. They open their RAPP front doors on their phones, scan each other's pairing QR codes (Game-Boy-linked-cable style), and the agent transfers device-to-device over WebRTC. The receiver runs the agent locally on their device with whatever local model they have. Both organisms accumulate their own offline experiences. When the network returns, useful mutations rejoin the canonical lineage via PR.

**What must work, end-to-end:**

| Requirement                                      | Implementation                                      | Status |
|---                                               |---                                                  |---     |
| Both phones reach a chat surface offline         | Doorman page (`installer/plant.sh`) + new public `pages/vbrainstem.html` — both fully static + Pyodide + cached | ✅     |
| Pair-by-QR (no copy-paste IDs)                   | `📱 Pair with another device` → autoRenderTetherQR (doorman); **Generate QR** button + 6-digit safety code (vbrainstem.html, ECDSA P-256 keypair fingerprint embedded) | ✅     |
| Cross-device WebRTC channel (DTLS encrypted)     | PeerJS (broker only for handshake) — same in both surfaces | ✅     |
| Agent transfers device-to-device                 | `🥚 Send my egg →` button on tether pane streams chunked egg over the open WebRTC channel; receiver auto-saves after sha256 verify | ✅ ([test](../tests/doorman/tether-egg.mjs)) |
| Receiver runs agent locally                      | Pyodide loads agent .py from local filesystem (doorman); Pyodide loads `basic_agent.py` + `hacker_news_agent.py` + memory agents from `raw.githubusercontent.com/kody-w/RAPP/main/rapp_brainstem/agents/` (vbrainstem.html in `?copilot=1` mode) | ✅     |
| Live tethered group chat (vs. one-way egg trade) | `pages/vbrainstem.html` — both screens stay synced as the Coordinator twin drives a multi-step workflow. Operator-mic interjection takes priority. Transcript is the canonical state; both peers append-only-dedupe by event_id. Shipped 2026-05-10 (SPEC §18.11). | ✅     |
| Graceful degrade when no network                 | `cachedGhJson` returns last-cached state; vbrainstem falls back to in-memory mirror when Edge Tracking Prevention blocks localStorage | ✅     |
| Local model fallback                             | Doorman config supports custom Copilot endpoint; vbrainstem.html `?brainstem=URL` override + localhost-7071 default | ⚠ partial — works for self-hosted endpoint, no offline LLM yet |
| Mutations stay local until bonded back           | `state_at_seal` + `data/frames.json` in egg; PRs are explicit consent. Session cartridges (`brainstem-egg/2.3-session`) carry transcript + sha256-pinned runtime end-to-end. | ✅     |
| One hatcher routes any cartridge kind            | `rapp_brainstem/agents/egg_hatcher_agent.py` (kernel) introspects manifest schema/type and routes: organism / rapplication / session / neighborhood (planned) / estate (planned). Refuses on unknown kinds. | ✅     |

**Acceptance criteria.** Two devices, both in airplane mode, can:
1. Open their front doors and chat with each other through the tether QR (no internet, no broker once the channel is open)
2. Trade an `.egg` over the tether
3. Each receiver hatches the egg and reads the trade card / persona / agent inventory from the egg's `state_at_seal` block — no GitHub call required
4. The receiver runs at least one of the agents in the egg via Pyodide locally
5. *(2026-05-10 addition)* Either operator can run a live tethered group-chat session (vbrainstem.html) where their Coordinator twin executes a structured workflow on their behalf, both screens synced turn-by-turn — the **session itself is portable** as a `.egg` cartridge.

---

## 2. The Dream Catcher (parallel-dimension reassimilation)

**The story.** Once an organism is hatched on a device, it lives its own offline life. Memories accumulate, mutations happen. Eventually it comes back online. Multiple parallel hatched dimensions exist — same rappid lineage, divergent histories. The Dream Catcher folds them back into the canonical organism without losing anything: UTC-first frames are canon, contradictions are preserved as alternate dimensions, the operator chooses what bonds back.

**The doctrine** (from the transcript, lines 67–78):

> *"Whatever frame hit the UTC one first, that's canon, and then anything that doesn't contradict that. I'm going to layer on that... There are contradictions, so that doesn't get synced. It gets put into a different dimension of that aspect of that life, so you don't lose that data."*

**What must work:**

| Requirement                                       | Implementation                                          | Status |
|---                                                |---                                                      |---     |
| Frames are content-addressed                      | `rapp-frame/1.0` schema with `prev_hash` + `hash` chain | ✅     |
| PK = (utc, frame_n)                               | both fields in every frame                              | ✅     |
| Eggs carry their frame log                        | `data/frames.json` in egg, fallback to `state_at_seal.recent_mutations` synthesized from Git history | ✅     |
| Diff two parallel dimensions visually             | `🕸️ Dream Catcher` pane — drop both eggs, see diff      | ✅     |
| UTC-first canon resolution                        | timeline sorted by UTC ascending; same-hash frames classified `shared`; same-PK-different-hash classified `contradiction` | ✅ ([test](../tests/doorman/dreamcatcher.mjs)) |
| Contradictions saved as alternate dimensions      | parallel-only frames with PK collision rendered as ⚡ contradiction (alternate-dimension data); not auto-merged | ✅ ([test](../tests/doorman/dreamcatcher.mjs)) |
| Doorman writes a frame log offline                | `appendFrame()` on chat turn / tool call / memory save → localStorage `rapp_frames_v1`; ascended egg packs `data/frames.json` | ✅     |
| Reassimilation via PR                             | "Open reassimilation issue on GitHub →" pre-fills issue | ✅     |
| Cross-species check (same rappid required)        | lineage warning fires when rappids differ               | ✅     |

**Acceptance criteria.** Drop two eggs of the same lineage into the Dream Catcher:
1. Frames common to both render greyed-out (shared canon)
2. Frames only in the parallel egg render highlighted (reassimilation candidates)
3. If two frames share `(utc, frame_n)` PK but have different payload hashes → flagged as contradiction; both kept, marked as alternate-dimension data
4. Operator can open a pre-filled GitHub Issue listing every parallel-only frame as a reassimilation candidate

---

## 3. Mom's Mixtape (the accessibility floor)

**The story.** From the transcript, line 137:

> *"If you can share your mix tape with your mom, and she can use it, that opens up everyone."*

**What must work:** every step of the canonical paths above must be doable without:
- Opening a terminal
- Knowing what a brainstem is
- Understanding GitHub mechanics
- Reading documentation

**The accessibility test:**

| Path                                        | Steps for a non-technical user               |
|---                                          |---                                            |
| Talk to a planted organism                  | Open URL → click "Talk to X" → chat          |
| Show its trade card                         | Click "🃏 Show my card" → tap card to flip   |
| Pair with another device                    | Click "📱 Pair" → other device scans QR      |
| Back up the organism                        | Click "🥚 Export .egg" → file downloads      |
| Verify an egg isn't tampered                | Click "🔬 Verify" → drag egg in              |
| Submit a useful mutation back to lineage    | Click "🌱 Propose an agent" → fill form → submit |
| Reassimilate parallel dimensions            | Click "🕸️ Dream Catcher" → drag both eggs in |

**Acceptance criteria.** A user with no programming background can complete the full Charizard-in-the-woods loop on a phone in under 5 minutes from first visit.

---

## 4. The Pizza Place / Pokémon-Go Layer (future, defined for parity)

**The story.** From the transcript, lines 38–66:

> *"I like this pizza place. I want you to check going forward where the best times are and then if there are any discounts. So your digital twin is actually planted there or a version of that digital twin in that virtual [location]... You can have intelligence swarms, location-based collaborating in public through the cloud endpoints. And then through the cloud endpoints, you can actually sync back with your digital twin on device when it comes back on device."*

**What's needed** (not yet implemented; flagged so it doesn't get reinvented):

- **Location-tied seeds** — `kind: "place"` already exists on rappid.json; need a `location_geohash` field for proximity-matching
- **Anonymous proximity swarm** — two organisms in the same geohash cell can discover each other and share what their operators have consented to share publicly
- **Public-twin consent layer** — `card.json` already supports `flavor` / `abilities`; needs an explicit `public_facets` field listing what's shareable in proximity
- **Sync-back on reconnect** — the Dream Catcher already handles reassimilation of frames; proximity-acquired frames are just another stream

**Acceptance criteria** (when implemented): a user who plants a `place` seed for the local pizza place sees, when revisiting that pizza place from another organism's front door, the public facets the operator has chosen to expose (e.g. "best times to come", aggregated visitor reactions).

---

## 5. MMR & Lineage (the cohort layer)

**The story.** Every planted organism gets a single global MMR rating (Dota-style, formula identical across the species). Children inherit a fixed snapshot of the parent's MMR-at-our-birth as a lineage gift — true epigenetics: parent regression after the child is planted doesn't reduce the child's inherited cred.

**What must work:**

| Requirement                                       | Implementation                                          | Status |
|---                                                |---                                                      |---     |
| Single global MMR formula                         | `computeMMR()` in front-door — same code on every seed  | ✅     |
| Calibration phase                                 | first 5 mutations OR 7 days → `📐 Calibrating · X%`     | ✅     |
| Activity decay                                     | last-commit recency scales above-baseline (1.0 → 0.45)  | ✅     |
| Plant-time lineage snapshot                       | `lineage_snapshot` block in rappid.json captures parent's MMR-at-our-birth at plant time | ✅ ([test](../tests/doorman/lineage-snapshot.mjs)) |
| Child reads snapshot first, falls back to live    | `_parentLineageGift` prefers `rappid.lineage_snapshot.parent_mmr_at_birth`; live fetch on older seeds | ✅     |
| Offspring boost                                   | `forks_count` adds `sqrt(forks) * 400` to MMR           | ✅     |

**Acceptance criteria.** Plant a child seed with `MIRROR_PARENT=https://github.com/<owner>/<parent-repo>`:
1. The child's `rappid.json` contains a `lineage_snapshot` block with `parent_mmr_at_birth`
2. The child's front-door resume shows the lineage gift derived from the snapshot, not a live fetch
3. Subsequent regression on the parent's MMR doesn't reduce the child's gift

---

## Test Commands

```bash
# Plant tests (syntax + file layout)
bash installer/test_plant.sh

# Frame log + Dream Catcher (Hero §2)
node tests/doorman/dreamcatcher.mjs

# Tether egg send protocol (Hero §1)
node tests/doorman/tether-egg.mjs

# Plant-time lineage snapshot (Hero §5)
node tests/doorman/lineage-snapshot.mjs
```

All four must be green before merging changes that touch the surfaces named in the rows above.

---

## How This Document Is Used

- **Every PR** that touches the front door, doorman, egg export/import, or pairing flow must declare which hero requirement it advances or preserves.
- **Every architecture proposal** that would change one of the ✅ rows must justify why the hero use case is preserved or improved, never degraded.
- **Every release** runs the acceptance criteria as an explicit smoke test (currently manual; CI'd later).

---

## Source

Hero scenarios are extracted from a private design conversation on Agent Shareability (May 2026). The conversation document lives in the operator's records; the canonical scenarios are checked in here so they're part of the repo's permanent specification.
