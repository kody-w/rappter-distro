# RAPP Ecosystem — End-to-End Layout

> The complete picture of a planted RAPP organism: what it's made of, where it lives, how it moves, how it evolves, how it talks to the rest of the species. This document is the architecture-level companion to [`HERO_USECASE.md`](./HERO_USECASE.md). Read both before proposing structural changes.

---

## 0. The atom

A RAPP **organism** is a public GitHub repository with a specific file layout. The repo IS the organism — its identity (`rappid`), its voice (`soul.md`), its memory (`.brainstem_data/`), its body (`agents/`), and its skin (`index.html`, `doorman/`) all live as committed files. There is no server. The repo is served via GitHub Pages; clients run the surfaces in their browser; the doorman authenticates against the visitor's own GitHub Copilot subscription.

```
github.com/<user>/<seed>     ← canonical lineage (the trunk)
       │
       └── served at <user>.github.io/<seed>/         ← the front door (public profile)
                                       /doorman/      ← chat surface (Copilot device-code auth)
```

Every operation in the ecosystem can be expressed in terms of this atom: planting clones the atom, eggs serialize it, hatching reconstitutes it elsewhere, the Dream Catcher merges divergent copies back into it.

---

## 1. The lifecycle

```
  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
  │  PLANT   │ →  │  HATCH   │ →  │   LIVE   │ →  │  MUTATE  │ →  │ REASSIM. │
  └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
   one-liner       egg → device   accumulates       commits/PRs    Dream Catcher
   plant.sh        local bstem    memories,         add agents,    folds parallel
   on GitHub       or browser     conversations     edit soul,     dimensions back
                                                    save mem        via PR
                                       │
                                       ↓
                                  ┌──────────┐
                                  │  STASIS  │  no commits 3+ years
                                  └──────────┘  MMR floored, organism
                                                preserved as artifact
```

The lifecycle is non-linear: an organism can be hatched many times in parallel (each device = one parallel dimension), each accumulates its own mutations, and the Dream Catcher reassimilates them via PR.

---

## 2. File layout of a planted organism

What `installer/plant.sh` writes into a fresh seed:

```
<seed>/
├── rappid.json                     identity + lineage + kind
├── soul.md                         the AI's voice (spec-compliant Identity block)
├── README.md                       repo landing for GitHub visitors
├── card.json                       optional — operator override of trade-card copy
├── index.html                      the front door (public profile / MySpace)
├── .nojekyll                       so Pages serves dot-prefixed paths
├── .gitignore                      keep secrets out, keep public state in
├── .brainstem_data/
│   └── memory.json                 public memory — facts known to anyone
├── agents/
│   ├── basic_agent.py              base class, never overridden
│   ├── manage_memory_agent.py      doorman tier — save/recall public memories
│   └── context_memory_agent.py     doorman tier — track conversation context
├── doorman/
│   └── index.html                  chat surface (Copilot device-code, Pyodide)
├── installer/
│   └── install.sh                  one-liner kernel installer (visitor flow)
└── rapp_brainstem/
    ├── brainstem.py                frozen kernel (v0.6.0 grail)
    ├── VERSION
    └── agents/basic_agent.py       reference copy
```

Files added by visitors over time:
- `agents/<custom>_agent.py` — new agents proposed via PR
- `data/frames.json` — frame log (when the doorman writes one)
- `.brainstem_data/memory.json` accumulates facts as conversations happen

Per-user private memories live in **GitHub Issues** on the seed repo (label `private-memory`). They are not files in the repo; the doorman reads/writes them via the Issues API for authenticated visitors.

---

## 3. Identity stack — everything traces back to the rappid

All visual and computed properties of an organism derive from a single UUIDv4 `rappid` minted at first plant. This is the species identity contract — the rappid IS the organism, every visual is a refraction of it.

```
                              rappid (UUIDv4)
                                    │
       ┌──────────────┬─────────────┼─────────────┬──────────────┐
       ↓              ↓             ↓             ↓              ↓
     sigil        card visuals   stream_id    deep-verify    parent_rappid
   (gradient +    (pip, P/T,    (frame log    anchor (with    chain back to
    shape +       rarity —      partition     origin_commit   species root)
    accents)      hash-derived) per dimension) _sha)
```

**Schemas** in this stack:

### `rappid.json` (`rapp-rappid/2.0`)
The organism's birth certificate. Written once at plant time, never regenerated.
Per CONSTITUTION Article XXXIV.1 (2026-04-30 ratification) the schema is
`rapp-rappid/2.0` and the `rappid` field carries the v2-format string
`rappid:v2:<kind>:@<pub>/<slug>:<hash>@<host>`. Pre-ratification seeds
on `rapp-rappid/1.1` with bare UUIDs are still valid (their UUID hex,
dashes stripped, IS the hash field of their v2 string by the documented
migration rule).
```json
{
  "schema": "rapp-rappid/2.0",
  "rappid": "rappid:v2:mirror:@<gh_user>/<repo>:<32-hex-hash>@github.com/<gh_user>/<repo>",
  "kind": "personal" | "place" | "experiment" | "mirror",
  "name": "<repo-slug>",
  "display_name": "<Human Readable>",
  "github": "https://github.com/<user>/<repo>",
  "url":    "https://<user>.github.io/<repo>",
  "parent_rappid": "<uuid of parent organism>",
  "parent_repo":   "https://github.com/kody-w/rapp-installer",
  "planted_by":    "<gh-user>",
  "planted_at":    "<iso8601>",
  "kernel_version": "0.6.0",
  "location":      "<optional human-readable location>",
  "private_companion": {
    "repo":    "<github URL>",
    "purpose": "<why this exists>",
    "auth":    {"scheme": "github_token", "scope_required": "..."}
  }
}
```

### `card.json` (operator override, optional)
Customizes the trade-card copy. All fields optional; missing fields fall through to kind-defaults.
```json
{
  "title": "<one-line subtitle>",
  "type_line": "Front Door — <Whatever>",
  "rarity": "core" | "uncommon" | "rare" | "mythic",
  "abilities": [
    { "kw": "<Keyword>", "text": "<what this does>" }
  ],
  "flavor_text": "<the italicized one-liner>"
}
```

### Frame (`rapp-frame/1.0`)
The unit of mutation. Every meaningful event becomes a frame.
```json
{
  "stream_id": "<rappid-prefix>:<short-instance-id>",
  "frame_n":   <integer, monotonic per stream>,
  "utc":       "<iso8601 timestamp>",
  "kind":      "memory_added" | "agent_loaded" | "soul_edited" | "commit" | ...,
  "payload":   { "...kind-specific data..." },
  "prev_hash": "<sha256 of previous frame in this stream>",
  "hash":      "<sha256 of {prev_hash + utc + frame_n + kind + payload}>"
}
```

### Egg manifest (`brainstem-egg/2.2-organism`)
A self-describing portable cartridge of an organism. Two tiers.
```json
{
  "schema": "brainstem-egg/2.2-organism",
  "type":   "organism",
  "tier":   "doorman" | "ascended",
  "exported_at":   "<iso8601>",
  "exported_from": "<seed URL>",
  "rappid":        "<uuid>",
  "parent_rappid": "<uuid>",
  "parent_repo":   "<github URL>",
  "kind":          "personal" | "place" | ...,
  "display_name":  "<name>",
  "incarnations_at_egg": <int>,
  "counts": {
    "agents": <n>, "organs": 0, "senses": 0, "services": 0,
    "data": <n>, "soul": <n>, "env": 0, "rappid": 1, "card": <n>,
    "private_files": <n>, "user_memories": <n>
  },
  "provenance": {
    "schema": "rapp-egg-provenance/1.0",
    "scheme": "sha256",
    "file_hashes":     { "<path>": "<sha256>", ... },
    "manifest_hash":   "<sha256 of canonical hash table>",
    "origin_url":      "<seed URL at seal time>",
    "origin_repo":     "<github URL>",
    "origin_commit_sha": "<git sha at seal time>",
    "origin_owner":    "<gh-user>",
    "origin_repo_name": "<repo-slug>",
    "sealed_at":       "<iso8601>",
    "sealed_by_rappid": "<uuid>",
    "state_at_seal": {
      "schema":             "rapp-organism-state/1.0",
      "mem_count":          <int>,
      "mutation_count":     <int>,
      "fork_count":         <int>,
      "custom_agent_count": <int>,
      "age_days":           <float>,
      "last_commit_at":     "<iso8601>",
      "activity_kind":      "active" | "slowing" | "dormant" | "stasis",
      "mmr":                <int>,
      "recent_mutations":   [{ "sha", "message", "date" }, ...]
    }
  }
}
```

### User memories (`rapp-user-memories/1.0`, ascended-tier only)
Per-user private memories captured from GitHub Issues.
```json
{
  "schema": "rapp-user-memories/1.0",
  "source_repo": "<owner>/<repo>",
  "exported_at": "<iso8601>",
  "facts": [
    { "login": "<gh-user>", "body": "<fact>",
      "issue_number": <n>, "issue_url": "<url>",
      "created_at": "<iso8601>" }
  ]
}
```

---

## 4. The two surfaces

### 4a. Front door — `/index.html`
Public profile. Anonymous-friendly. No auth required for any action on this page.

| Element | Purpose | Driven by |
|---|---|---|
| Hero (sigil + name + handle + place + blurb + CTA) | Identity moment | rappid (sigil) + display_name + kind (blurb defaults) |
| Hero stats chips | Signs of life | memory.json + age + frozen-kernel marker |
| **Track Record / What I bring to the table** | The resume | All sources below |
| ⌬ **MMR + tier** | Single global rating | Live formula — see §6 |
| **Agents** | What capabilities exist | `agents/` listing via Contents API (cached) |
| **Achievements** | Milestones earned | Derived from mem count + age + mut count |
| **Mutation log** | Live evolution feed | Last 5 commits via Commits API (cached) |
| **Lineage** | Where this organism descends from | rappid.parent_repo + parent_rappid |
| 🃏 Show my card | Trade card overlay | Auto-derived; tap to flip → QR back |
| 📱 Pair with another device | WebRTC tether | PeerJS broker → DTLS, QR auto-renders |
| 🌱 Propose an agent | The lineage-evolution path | Pre-fills GitHub create-file URL |
| 🥚 Export .egg | Doorman-tier cartridge | Self-contained organism backup |
| 🔬 Verify an .egg | Non-GMO check | sha256 against manifest + deep-verify against repo |
| 🕸️ Dream Catcher | Parallel-dimension reassimilation | Diff two eggs, surface candidate frames |
| 🌐 Back up to Egg Hub | Public catalog submission | Pre-fills GitHub Issue at egg-hub |
| 💻 Install kernel locally | Hatch into a local brainstem | Copy curl one-liner |
| Front-door details (collapsed) | Engineering trivia | Slug, rappid, kernel, lineage HTML |

### 4b. Doorman — `/doorman/index.html`
Chat surface. Auth via Copilot device-code flow. Pyodide loads agents in-browser.

| Element | Purpose |
|---|---|
| Persona header (name + location + AT THE FRONT DOOR badge) | Identity context for the visitor |
| Chat log (markdown rendered) | Two-way conversation; assistant messages render with marked.js |
| Typing-dots loading bubble | Visible state while LLM thinks; labels itself "calling X…" during tool calls |
| Auth pane → Copilot device-code modal | First-visit sign-in; matches canonical brainstem modal exactly |
| Memory pane (Save a memory) | Manual override; visitor can write public OR per-user-private memory |
| Model selector | Pulls live Copilot catalog via `/api/copilot/models`, persists choice in localStorage |
| Chat actions row | Save memory · Clear chat · Export ascended .egg (operator only) · Sign out |
| 🥚 Export ascended .egg | Full organism + private layer + per-user issues — operators / private-companion access only |
| Private indicator badge | ✓ ascended — full twin voice loaded · or · public · or · device-only |
| Pyodide agent loader | Loads doorman + ascended agents from `kody-w/RAPP/main/rapp_brainstem/agents/` |

The doorman pages and the front-door pages are the **only** two surfaces an organism exposes by default. Both are static HTML rendered in the browser; there's no server-side code on the seed.

---

## 5. Memory — three concentric tiers

```
                ┌───────────────────────────────────────┐
                │      DEVICE LOCAL (localStorage)       │   This visitor on this device.
                │      Anonymous-friendly. No auth.       │   Survives reload, never leaves.
                └───────────────────────────────────────┘
                ┌───────────────────────────────────────┐
                │      PUBLIC (.brainstem_data/         │   Anyone who visits sees these.
                │           memory.json — git tracked)   │   Operator commits to grow.
                └───────────────────────────────────────┘
                ┌───────────────────────────────────────┐
                │      PER-USER PRIVATE (GitHub Issues)  │   Per-@login. Authed visitors only.
                │           label: private-memory        │   Surfaces as `[@login] <fact>`
                └───────────────────────────────────────┘
```

The doorman's system prompt assembles all three at chat time:
- Device-local memory: free-floating facts, no prefix
- Public memory: free-floating facts, no prefix
- Per-user private (visible only to that user): `[@<login>] <fact>` so the LLM understands the access boundary

---

## 6. MMR — single global rating, computed client-side from public signals

```
  base_mmr = 1000
           + memCount × 30          (each conversation deepens us)
           + sqrt(mutCount) × 250   (each operator commit shapes us)
           + customAgents × 350     (each new agent earned beyond defaults)
           + sqrt(ageDays) × 80     (lived time matters)
           + sqrt(forkCount) × 400  (offspring planted from this lineage)

  above_baseline = max(0, base_mmr - 1000)
  decayed         = above_baseline × activityFactor

  final_mmr      = 1000 + decayed + lineage_gift
```

| Activity | Multiplier | Trigger |
|---|---|---|
| ✓ Active | 1.00 | last commit ≤ 30 days |
| 〰 Slowing | 0.85 | 30–180 days |
| 💤 Dormant | 0.65 | 180 days–3 years |
| ❄ Stasis | 0.45 | 3+ years (floors at 1000 baseline) |

**Calibration**: the first 5 mutations OR 7 days, the organism is in placement and shows `📐 Calibrating · X% complete` instead of a tier — same idea as Dota 2's first 10 placement matches.

**Lineage gift**: `(parent_mmr - 1000) × 0.30` — the child inherits 30% of the parent's above-baseline as a head start. Sits OUTSIDE the activity multiplier so inherited cred doesn't wither under inactivity (your genes are your genes).

**Tier ladder** (Dota 2 medals — recognizable):
```
<1500   Herald
 1500   Guardian
 2000   Crusader
 2500   Archon
 3000   Legend
 3500   Ancient
 4500   Divine
 6000+  Immortal (animated rainbow text)
```

The formula is identical across all planted seeds, so a 3500 MMR Heimdall is comparable to a 3500 MMR Cloud Gate is comparable to any 3500 MMR organism on the species. No registry needed; each organism computes its own MMR live from its public state.

---

## 7. Evolution — PR-driven, frozen kernel never moves

The kernel (`brainstem.py` + `VERSION` + `basic_agent.py`) is frozen at the v0.6.0 grail. It is never edited. Capabilities grow exclusively through `agent.py` files merged into `/agents/`.

```
visitor finds useful pattern        →  packages as <name>_agent.py
                                                  │
                                                  ↓
                                       opens PR on the seed repo
                                                  │
                                       ┌──────────┴──────────┐
                                       ↓                     ↓
                              operator merges          visitor leaves PR
                              into main                 sitting on fork
                                       │                     │
                                       ↓                     ↓
                              global lineage           personal branch
                              moves forward            of this organism
                              (everyone sees           (only that visitor
                              new agent on next        sees the mutation)
                              page render)
```

The 🌱 Propose-an-agent pane drafts a `BasicAgent` skeleton, accepts the visitor's name + description + agent code, and opens GitHub's `/new/<branch>?filename=...&value=...` URL. GitHub auto-handles fork + branch + PR for non-collaborators. Operator reviews and decides.

---

## 8. Egg cartridges — portable organisms (and other portable units)

Eggs are zip archives matching the `brainstem-egg/2.2-organism` schema. Two tiers (front door exports doorman; doorman exports ascended).

> **Updated 2026-05-10:** the egg-cartridge family expanded. The `.egg` extension now carries five kinds, all addressable through the same kernel `egg_hatcher_agent.py` (introspects `manifest.schema`/`type`, routes by kind, refuses on unknown). See [`pages/docs/SPEC.md` §18.10](./pages/docs/SPEC.md) for the canonical family table and [`kody-w/rappterbox/carts/SCHEMA.md`](https://github.com/kody-w/rappterbox/blob/main/carts/SCHEMA.md) for the session-variant spec.
>
> | Schema | Kind | Container | Hatch destination | Status |
> |---|---|---|---|---|
> | `brainstem-egg/2.2-organism` | `organism` | ZIP | `~/.rapp/twins/<rappid>/` | shipping |
> | `brainstem-egg/2.2-rapplication` | `rapplication` | ZIP | planted rapp under host | shipping |
> | `brainstem-egg/2.3-session` | `session` | JSON | rappterbox console iframe / `pages/vbrainstem.html` | shipping |
> | `brainstem-egg/2.3-neighborhood` | `neighborhood` | ZIP | mint new GitHub repo / local mirror | planned |
> | `brainstem-egg/2.3-estate` | `estate` | ZIP | re-anchor whole identity on new substrate | planned |

### Doorman tier — anyone can export
Layout:
```
<egg>.zip
├── manifest.json     (with provenance.state_at_seal block)
├── rappid.json
├── soul.md
├── card.json         (if present)
├── agents/
│   ├── __init__.py
│   ├── manage_memory_agent.py
│   └── context_memory_agent.py
└── data/
    └── memory.json
```

### Ascended tier — operators / private-companion access only
Adds:
```
├── agents/
│   ├── learn_new_agent.py        ascended-tier
│   └── swarm_factory_agent.py    ascended-tier
├── private/
│   ├── soul.md                   from private companion
│   ├── README.md                 from private companion
│   └── .brainstem_data/memory.json
└── data/
    └── user_memories.json        all per-user issue memories
```

Any kernel that supports `brainstem-egg/2.2-organism` can hatch either tier. The `tier` field in the manifest tells receivers which extras shipped.

---

## 9. Integrity stack — non-GMO chain

Every egg seals with a multi-layer integrity envelope:

1. **Per-file SHA-256** in `provenance.file_hashes` — catches edits to any file
2. **Manifest hash** — `sha256(canonical-sorted file_hashes)` catches edits to the table itself
3. **Origin commit SHA** — pins the egg to a real commit on the public seed repo
4. **State-at-seal snapshot** — captures all state-derived signals (MMR, mutation count, fork count, recent commits) for offline rendering

The 🔬 Verify pane on the front door recomputes everything client-side. Three verdicts:
- ✓ **envelope intact** — internal hashes match
- ⚠ **partial** — missing or unexpected files
- ✗ **tampered** — at least one file edited offline

Plus 🌐 **Deep-verify against live repo** — re-fetches every file from `raw.githubusercontent.com/<owner>/<repo>/<sealed_sha>/<path>` and recomputes hashes. If matches: provably authentic, since only the seed's owner can push to the public repo. (This sidesteps phase-2 ed25519 signatures by leaning on GitHub push-permission as the trust anchor — see §11 for the airplane-mode picture.)

---

## 10. Dream Catcher — parallel-dimension reassimilation

Pattern from `kody-w/rappterbook` (`engine/merge/merge_frame.py`). Each hatched egg is a parallel dimension of the organism living its own offline life. Frames accumulate locally. When the dimension wants to bond back, the Dream Catcher folds its frame stream into the canonical lineage.

The 🕸️ pane on the front door:
1. Drop the **canonical** egg (left) and a **parallel-dimension** egg (right)
2. Frame-set diff by hash:
   - **Shared frames** (in both): grey, already in canon
   - **Parallel-only frames**: highlighted green with 🌱
3. Lineage check: rappids must match (cross-species reassimilation isn't supported)
4. **Reassimilation action**: opens a pre-filled GitHub Issue listing every parallel-only frame as a candidate. Operator reviews on GitHub and cherry-picks what's worth bonding back.

**Conflict-resolution doctrine** (per the operator's design conversation, partially implemented):
- UTC-first canon: whichever frame hit the UTC first is canonical
- Non-contradicting later frames layer on
- Contradicting frames (same `(utc, frame_n)` PK, different content): preserved as alternate-dimension data, not lost

---

## 11. The network — three modes

```
              ┌────────────────────────────────┐
              │     MODE A: ONLINE              │
              │   GitHub APIs flowing           │   Live MMR, live agents,
              │   raw.githubusercontent.com     │   live mutation log,
              │   reachable                     │   deep-verify works
              └────────────────────────────────┘
                            ↓ network drops
              ┌────────────────────────────────┐
              │     MODE B: AIRPLANE            │
              │   GitHub unreachable            │   localStorage cache
              │   localStorage cache wins       │   (24h TTL) renders
              │                                 │   stale data with 📡 pill
              └────────────────────────────────┘
                            ↓ never had network
              ┌────────────────────────────────┐
              │     MODE C: HATCHED OFFLINE     │
              │   Egg's state_at_seal block is  │   self-describing snapshot
              │   the source of truth           │   from the seal moment
              └────────────────────────────────┘
```

Every fetch the resume makes goes through `cachedGhJson` / `cachedGhText` wrappers:
- On success: cache to localStorage with timestamp
- On failure or no-network: return last-cached value with a `stale: true` flag, render with a 📡 pill

The egg's `state_at_seal` block is a third tier of fallback — for organisms that were hatched on a device that never had the network at all.

**Trust anchor matrix:**

| Mode | Authoritative source | Why |
|---|---|---|
| Online | `raw.githubusercontent.com/<owner>/<repo>/main/...` | Only operator can push |
| Airplane | localStorage cache stamped with last-sync date | Stale but real signature of last-known state |
| Hatched offline | egg manifest `state_at_seal` + `provenance.file_hashes` | Self-describing; sha256 chain catches tampering |
| Phase 2 (future) | ed25519 publisher signatures | Required for offline-only chains where neither GitHub nor recent cache is available |

---

## 12. External integrations

### GitHub Pages
Serves every planted seed at `<user>.github.io/<repo>/`. The `.nojekyll` file ensures dot-prefixed paths (`.brainstem_data/`) are served. Pages auto-deploys on every commit to `main`.

### raw.githubusercontent.com
The canonical content channel. The seed's files are fetchable at `raw.githubusercontent.com/<user>/<repo>/<branch>/<path>` — used by deep-verify, lineage gift, parent-MMR computation, and the doorman's Pyodide agent loader. Anonymous-friendly, no auth required.

### GitHub Copilot (via the auth worker)
The doorman authenticates visitors via Copilot's device-code flow:
- `POST <auth-worker>/api/auth/device` — start device flow
- `POST <auth-worker>/api/auth/device/poll` — poll for token
- `POST <auth-worker>/api/copilot/token` — exchange ghu_* for copilot session
- `POST <auth-worker>/api/copilot/chat` — chat completions
- `GET  <auth-worker>/api/copilot/models?endpoint=...` — model catalog

The auth worker (Cloudflare Worker, `worker/`) is a thin proxy — it doesn't store visitor tokens; it forwards the device-code dance and chat traffic.

### GitHub Contents/Commits/Issues APIs
Used by the front door's Track Record:
- `/repos/<owner>/<repo>/contents/agents` — list agents
- `/repos/<owner>/<repo>/commits?per_page=N` — mutation log
- `/repos/<owner>/<repo>` — fork count, repo metadata
- `/repos/<owner>/<repo>/issues?labels=private-memory&creator=<login>` — per-user memory

All wrapped through `cachedGhJson` for local-first rendering.

### kody-w/rapp-egg-hub
Public catalog of digital-twin .egg cartridges. The `🌐 Back up to Egg Hub` button on the front door pre-fills a GitHub Issue with submission metadata. The hub maintainer commits the egg + sidecar to `eggs/<slug>.egg` and updates `index.json`.

### PeerJS public broker
Used only for the WebRTC pairing handshake. Once two devices have exchanged peer IDs, the data channel is direct (DTLS encrypted) and the broker drops out.

### CDNs
- `cdn.jsdelivr.net/pyodide/v0.26.4/full/pyodide.js` — Pyodide for in-browser agent execution
- `cdn.jsdelivr.net/npm/marked/marked.min.js` — markdown rendering in chat
- `cdn.jsdelivr.net/npm/jszip@3.10.1` — egg pack/unpack
- `unpkg.com/peerjs@1.5.4` — WebRTC tether
- `api.qrserver.com/v1/create-qr-code` — QR rendering for pair + card-back

---

## 13. Component inventory — every file in `installer/plant.sh`'s output

| Path | Role | Generated by |
|---|---|---|
| `rappid.json` | identity + lineage | `write_rappid_json` |
| `soul.md` | the AI's voice (kind-aware default + Identity block) | `write_soul_md` |
| `README.md` | repo landing | `write_readme` |
| `index.html` | front door | template inline in `plant.sh`, populated by Python placeholder substitution |
| `doorman/index.html` | chat surface | `write_doorman_html` |
| `installer/install.sh` | one-liner kernel installer | `write_install_sh` |
| `.gitignore` / `.nojekyll` | Pages + git config | `write_gitignore`, `write_nojekyll` |
| `.brainstem_data/memory.json` | initial public memory file | `write_memory_json` |
| `agents/manage_memory_agent.py` | doorman tier — public memory R/W | fetched from grail by `fetch_seed_agents` |
| `agents/context_memory_agent.py` | doorman tier — conversation context | fetched from grail |
| `rapp_brainstem/brainstem.py` | frozen kernel | fetched from grail by `fetch_kernel` |
| `rapp_brainstem/VERSION` | kernel version pin | fetched from grail |
| `rapp_brainstem/agents/basic_agent.py` | base class | fetched from grail |

Files added on demand:
- `card.json` — operator commits to override card copy
- `agents/<custom>_agent.py` — visitors propose via PR
- `data/frames.json` — when the doorman writes a frame log (deferred)

---

## 14. Surface inventory — every visitor-facing affordance

### Front door (`/`)
- Hero: tap `💬 Talk to <Name>` → `/doorman/`
- 🃏 Show my card → overlay → tap card to flip → QR back → tap to flip back
- 📱 Pair with another device → broker handshake → QR auto-renders → other device scans → DTLS channel
- 🌱 Propose an agent → fill form → submits to GitHub create-file URL → PR auto-forks for non-collaborators
- 🥚 Export .egg → JSZip pack → download
- 🔬 Verify an .egg → drop in → recomputes sha256 → optional deep-verify against live repo
- 🕸️ Dream Catcher → drop two eggs → frame diff → reassimilation issue
- 🌐 Back up to Egg Hub → pre-filled GitHub Issue at `kody-w/rapp-egg-hub`
- 💻 Install kernel locally → copy curl command
- Front-door details (collapsed) → slug + rappid + kernel + lineage

### Doorman (`/doorman/`)
- Sign in with GitHub (device-code modal — not auto-popping the GitHub tab; visitor copies code, then opens GitHub)
- Chat (markdown rendered, typing dots, model selector)
- + Save a memory (public or private)
- 🥚 Export ascended .egg (operator-only)
- Clear chat
- Sign out

### What the visitor never has to do
- Open a terminal
- Read documentation
- Know what a brainstem is
- Know what a rappid is
- Understand the egg format

(See HERO_USECASE.md §3 — "Mom's Mixtape" — for the accessibility floor.)

---

## 15. What's shipped vs what's pending

✅ **Fully working today:**
- Plant flow (one-liner)
- Front door + Track Record + MMR
- Trade card (4D — rappid-locked + state-aware)
- Doorman with Copilot device-code auth
- Operator-fallback ascension
- Egg export (doorman + ascended tiers) with sha256 + state_at_seal
- Verify + deep-verify against public repo
- Dream Catcher diff (set-based by hash) + UTC-first canon resolution + contradictions-as-alternate-dimensions
- Local-first rendering (cachedGhJson)
- Propose-an-agent PR flow
- Egg Hub backup (issue-based)
- **Doorman-side `appendFrame()` writing content-addressed `rapp-frame/1.0` to localStorage `rapp_frames_v1`** (chat turn, tool call, memory save). Ascended egg packs `data/frames.json`. End-to-end conformance: `tests/osi/L6a-frame-chain-browser.sh` (drives `tests/doorman/dreamcatcher.mjs` — 17/17).

⚠ **Partial — works, can be tightened:**
- Egg send over the tether channel (today: manual paste via tether chat; should be one-tap stream)
- Local-LLM fallback in doorman (today: custom Copilot endpoints work; no offline-LLM path)
- Plant-time MMR snapshot for lineage gift (today: live-fetched at view time)

✅ **Recently shipped (2026-05-08):**
- **Lineage roll-up stats** (avg/median/min/max MMR across the lineage tree). Agent: `rapp_brainstem/agents/lineage_rollup_agent.py` (`LineageRollup` tool); test: `tests/features/F1-lineage-rollup.sh`.
- **Global leaderboard** (aggregate the species via fork-tree walking, Herald → Immortal tier ladder, 10-min cache). Agent: `rapp_brainstem/agents/species_leaderboard_agent.py` (`SpeciesLeaderboard` tool); test: `tests/features/F2-leaderboard.sh`.
- **Location-aware proximity swarm** (Pizza Place / Pokémon-Go layer). Pure-stdlib geohash + match-by-prefix; `kind: "place"` seeds get `location_geohash` written by plant.sh when `MIRROR_LOCATION_LAT` + `MIRROR_LOCATION_LNG` set. Agent: `rapp_brainstem/agents/proximity_discovery_agent.py` (`Proximity` tool); test: `tests/features/F3-proximity.sh`.
- **ed25519 publisher signatures** (offline-only verification chains per CONSTITUTION Art. XXXIV.7). Tool: `tools/sign_release.py` (keygen / sign / verify); manifest at `rapp_kernel/manifest.json` declares `signing.preferred_method = "ed25519"`. Test: `tests/features/F4-ed25519-sign.sh`.
- **Stasis recovery / resurrection ceremony**. Agent: `rapp_brainstem/agents/resurrection_ceremony_agent.py` (`Resurrection` tool — assess + compose actions); emits a `kind: "resurrection"` `rapp-frame/1.0` frame; the fresh commit lifts the activity multiplier per ECOSYSTEM §6. Test: `tests/features/F5-resurrection.sh`.

❌ **Not yet built (defined for parity):**
- (none currently — the §15 backlog is empty as of 2026-05-08)

---

## 16. Reading order for new contributors

1. [`HERO_USECASE.md`](./HERO_USECASE.md) — *what* this platform must do
2. This document — *how* the pieces fit together
3. [`CLAUDE.md`](./CLAUDE.md) — daily-work instructions
4. [`CONSTITUTION.md`](./CONSTITUTION.md) — governance + sacred constraints
5. [`pages/vault/`](./pages/vault/) — long-form essays explaining *why* each major decision was made

The first three are the contract. The last two are the context.
