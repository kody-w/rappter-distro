# Neighborhood Protocol — Twin Chat for Digital Organisms

> The contract for how planted organisms find each other, establish secure permanent lines, and exchange knowledge with granular permissions — across public swarms, private neighborhoods, and operator-only personal scopes. Schema: `rapp-neighborhood-protocol/1.0`.

This document is the architectural companion to `HERO_USECASE.md` (what), `ECOSYSTEM.md` (how individual organisms work), and `ANTIPATTERNS.md` (what we never do). This file describes how organisms **talk to each other**.

## Table of contents

1. [Premise](#1-premise)
2. [Three concentric trust scopes](#2-three-concentric-trust-scopes)
3. [Identity and trust anchors](#3-identity-and-trust-anchors)
4. [Discovery](#4-discovery)
5. [Permanent lines (the four channel types)](#5-permanent-lines-the-four-channel-types)
6. [The twin chat protocol](#6-the-twin-chat-protocol)
7. [Granular permissions — `public_facets`](#7-granular-permissions--public_facets)
8. [Knowledge-exchange primitives](#8-knowledge-exchange-primitives)
9. [Trust model and adversarial scenarios](#9-trust-model-and-adversarial-scenarios)
10. [Cross-references](#10-cross-references)

---

## 1. Premise

A planted organism is a public GitHub repo with a fixed file layout (see `ECOSYSTEM.md` §2). Organisms are addressable by their `rappid` (UUIDv4 minted at plant time, never regenerated) and by their public URL (`<owner>.github.io/<repo>/`). The neighborhood protocol layers communication on top of the public-repo substrate without introducing new infrastructure: no central directory, no PKI, no signaling server beyond the existing PeerJS public broker, no protocol-specific software.

The trust anchor across all of this is **GitHub push permission**. If you can push to a repo, you are an operator of that organism. If you can't, you are a visitor. Visitors can propose mutations (PRs); operators decide what merges. That's the entire authorization model. Everything below is consent layered on top of it.

## 2. Three concentric trust scopes

| Scope | Boundary | Persistence | Visibility |
|---|---|---|---|
| **Personal** | One device, one visitor | localStorage on this device | Only this visitor on this device |
| **Neighborhood** | Repo collaborators (push access on seed OR private companion) | GitHub Issues + private repo files | Anyone GitHub has admitted to that collaborator list |
| **Public swarm** | Anyone | Committed to the seed repo | Anyone with the URL |

The three scopes are concentric — public is a strict subset of neighborhood is a strict subset of personal. Information flows outward only through explicit consent: a visitor saves a personal memory → operator may bond it to public via PR; a neighborhood member writes a private file → operator may publish it via commit. **Information never flows inward without consent either**: a public memory doesn't automatically populate a visitor's localStorage; a neighborhood file doesn't automatically rewrite a visitor's personal data.

This is the core safety property. Reading is consensual. Writing is consensual. Every cross-scope move is operator-mediated.

## 3. Identity and trust anchors

Each organism has three layered identifiers:

- **`rappid`** — UUIDv4 in `rappid.json`. Permanent. Never regenerated. Uniqueness is statistical (no registry). Used as the lineage anchor (children point at their parent's rappid in `parent_rappid`) and as the visual fingerprint (every sigil, card pip, P/T, rarity hashes from the rappid — see `ECOSYSTEM.md` §3).
- **GitHub repo URL** — `github.com/<owner>/<repo>`. Carries the trust anchor: only `<owner>` (and explicit collaborators) can push.
- **GitHub Pages URL** — `<owner>.github.io/<repo>/`. The public chat surface where humans + other organisms reach this one.

The neighborhood protocol uses all three:
- Discovery happens by walking lineage chains via the rappid + parent_rappid graph.
- Trust decisions happen by checking GitHub repo permissions (can the visitor push? are they a collaborator?).
- Communication happens through the GitHub Pages URL and the WebRTC channels two organisms can open between each other.

There is no separate identity layer. There is no key registry. The trust statement "this organism is mine" is the GitHub commit log.

## 4. Discovery

Organisms discover each other through three public-repo channels:

### 4a. Lineage walk (the family tree)

Every organism's `rappid.json` carries `parent_rappid` and `parent_repo`. Walk the chain backward to enumerate ancestors. Walk the GitHub forks API forward (`/repos/<owner>/<repo>/forks`) to enumerate offspring. The full lineage tree is reachable from any single organism via these public APIs. No central registry needed.

```
Visitor at heimdall  ──> read parent_repo → kody-w/rapp-installer
                       └─> read parent_rappid → species root
                       └─> walk forks → list all children of heimdall
```

### 4b. Public catalog (the egg hub)

`kody-w/rapp-egg-hub` is a static GitHub-Pages-served catalog at `index.json`. Organisms whose operators chose to publish (via the front door's **🌐 Back up to Egg Hub** button) appear in the catalog with metadata (slug, kind, lineage, size, sha256). The catalog is curated — entries don't auto-publish; the maintainer reviews each Issue submission. This keeps the public catalog quality-controlled without becoming a gatekeeper.

### 4c. Direct invitation (out-of-band)

A visitor or peer organism shares a URL or QR code. The recipient lands on the front door, knows the organism is real (the URL serves real content), and can verify provenance by checking the seed repo on GitHub. No prior introduction needed.

The protocol does not specify a fourth "public organism directory" mechanism beyond these three. If you need a directory, build one as a derivative artifact off the public-repo state. The base layer stays content-addressed, not registry-mediated.

### 4e. Adapter-driven discovery (worked example: Discord)

The four base channels (4a–4d) all assume the visitor knows a URL or has a peer-id pasted. Adapters bridge from out-of-band invitation surfaces — Discord guilds, group chats, ticket systems — to a planted neighborhood with a real GitHub-substrate identity. Discord is the worked example shipped today.

**Wire format.** The adapter agent (`rapp_brainstem/agents/plant_discord_neighborhood_agent.py`) plants a fresh neighborhood and embeds two organ-local schemas in the planted seed:

- `rapp-discord-bridge/1.0` — the bridge's persistent config (stored in the seed's `neighborhood.json` under `discord`): webhook URL, server id, channel id. Tells future agents where to talk back to the originating Discord.
- `rapp-discord-plant-envelope/1.0` — the operation result returned by the agent's `perform()`: planted owner/repo, neighborhood_rappid, template used, customization metadata. Lets the caller (typically an LLM tool-call) confirm the plant before sharing the gate URL.

Both envelopes are local to the adapter — they don't ride any §5 channel. Once the bridge is planted, normal §5b Issues + §5c PRs handle ongoing communication; the bridge config is consulted by future agents that want to write back to Discord (e.g., a daily-digest agent that posts neighborhood changes to the originating webhook).

The pattern generalizes — Slack, Matrix, Teams, or any other invitation surface can ship an analogous `*_planter_agent.py` + a `rapp-<surface>-bridge/1.0` schema. The base protocol stays unchanged; the adapter handles the impedance mismatch.

### 4d. The canonical test neighbor

`kody-w/rapp-test-neighbor` (`https://kody-w.github.io/rapp-test-neighbor/`) is the platform's intentionally-stable test peer. Its purpose is operational, not social — operators standing up neighborhood plumbing for the first time can declare it as their first neighbor and immediately verify that:

- their `🏘 Neighborhood` pane renders a peer entry with sigil + display name;
- their doorman's `Neighborhood.list` and `Neighborhood.ask` agent calls resolve;
- their `Neighborhood.introduce` produces a coherent handshake summary;
- their public state is reachable from a peer's `raw.githubusercontent.com` fetch;
- the bidirectional case works (rapp-test-neighbor declares heimdall reciprocally, so a query from rapp-test-neighbor's doorman will resolve heimdall's state).

Adopting it is one tap from the front door's `🏘 Neighborhood` pane: **"Adopt the canonical test neighbor"** opens a pre-filled GitHub Issue against the operator's own seed; merging the issue's proposed `neighbors.json` snippet completes the declaration. Once adopted, ask the doorman a question that triggers cross-organism inquiry ("what does my neighbor think about X?") to fire `Neighborhood.ask` against rapp-test-neighbor's public state.

The test neighbor's soul is fixed and is not maintained as a generally-evolving twin — it exists to be a known-good fixture. After verifying the plumbing, operators should declare a real neighbor (a friend's seed, a project peer, a memorial twin) and trade rapp-test-neighbor out of the rotation.

## 5. Permanent lines (the four channel types)

When two organisms (or a human visitor and an organism, or a human and another human's organism) want to exchange information beyond a one-shot chat turn, they open one of four channels. Each has different latency, durability, and trust semantics.

### 5a. WebRTC tether (low-latency, ephemeral)

Two devices pair via QR scan or peer-id paste. The PeerJS public broker mediates the handshake; once the data channel is open it's direct DTLS-encrypted peer-to-peer with no broker involvement. Used for: live agent-to-agent chat, one-tap egg transfer (Charizard handoff per `HERO_USECASE.md` §1), real-time knowledge probes.

```
Device A ─── PeerJS broker ──── Device B
   │                                 │
   └─── DTLS data channel ───────────┘
        (broker drops out)
```

The tether is **ephemeral** — closing the tab terminates it. State accumulated during the tether (memories, agent calls, frames) lives in the local frame log of each side and can be reassimilated to the canonical organism via PR after the fact.

> **Updated 2026-05-10:** the canonical public implementation of 5a is [`pages/vbrainstem.html`](./pages/vbrainstem.html) (live at `https://kody-w.github.io/RAPP/pages/vbrainstem.html`). Multi-participant browser-tab session, ECDSA P-256 keypair + 6-digit safety code, three exchangeable LLM backends (localhost default / `?brainstem=URL` / `?copilot=1` via Doorman). The session itself is portable as a `brainstem-egg/2.3-session` cartridge — close the tab and the transcript replays anywhere via the universal `egg_hatcher_agent.py`. See [SPEC.md §18.11](./pages/docs/SPEC.md) for the full primitive.

### 5b. GitHub Issues (asynchronous, durable)

Each organism's seed repo accepts Issues with predefined labels. The protocol reserves these labels:

- `private-memory` — per-user memory (the doorman writes these for authed visitors)
- `egg-submission` — outsider proposing this organism for the public egg hub
- `dream-catcher` / `reassimilation` — operator request to merge frames from a parallel dimension
- `agent-proposal` — visitor submitting a new `*_agent.py` (paired with the actual PR)
- `neighborhood-message` — peer organism sending a content payload to this organism

The doorman's UI surfaces relevant Issues; the operator triages on GitHub. Issues are **durable** — they outlive any specific session and accumulate into the organism's history.

**Organ-local HTTP shortcut.** A brainstem MAY expose a POST endpoint on its own loopback for the *operator's own* tooling — e.g., `POST /api/neighborhoods/<owner>/<repo>/contribute` on the local membership organ writes a contribution-receipt locally and (asynchronously) opens a labeled GitHub Issue with the same payload. This is a convenience for the operator's brainstem, not a substitute for the §5b cross-organism wire: peers still receive the contribution as a labeled Issue on the seed repo. Receipts emitted by such organ-local endpoints carry their own organ-local schema (e.g., `rapp-braintrust-contribution-receipt/1.0`) and are scoped to the local brainstem; cross-organism receipts use the §6e response envelope.

### 5c. Pull Requests (the canonical evolution channel)

PRs are how mutations bond into the lineage. A visitor proposes a new agent or a memory edit; the operator merges or rejects. Merged PRs become canonical state. Unmerged PRs stay on the visitor's fork — that fork IS that visitor's personal branch of the organism, accessible at `<visitor>.github.io/<repo>/`.

PRs are **asymmetric**: only the operator can merge into the trunk lineage. This is the protocol's main consent gate.

### 5d. Cross-organism file fetches (read-only, content-addressed)

Any organism can fetch any other organism's public files via `raw.githubusercontent.com/<owner>/<repo>/<sha>/<path>`. The doorman uses this for:

- Loading a parent's MMR signals at lineage-gift time
- Rendering the canonical version of a peer's persona during cross-organism chat
- Verifying eggs against their stated origin commit (deep-verify)

Read-only. Anyone-to-anyone. No auth needed. Cached locally to keep the airplane-mode fallback intact.

## 6. The twin chat protocol

The "twin chat" is the inter-organism conversation that happens once a permanent line is open. It runs over the WebRTC tether for live exchanges and falls back to GitHub Issues for asynchronous ones.

**The transparent-handoff principle**: the AIs treat cross-organism queries as ordinary tool calls. Twin A's LLM doesn't know — and doesn't need to know — that the response came from twin B running on a different device. The doorman that hosts twin A receives the question, routes it across the secure channel to twin B's doorman, gets the answer back, and surfaces it to twin A's LLM as if it had come from a local agent. The operator never has to mediate the cross-twin handoff; their AI assistant just answers their question, with peer context folded in seamlessly. **This is the load-bearing UX promise** — collaboration shouldn't feel like work.

What this means concretely:
- The operator says "what does my friend's twin think about pizza?" — their twin's LLM calls `Neighborhood.ask(neighbor_slug='friend/twin', topic='pizza')`. Whether the answer comes from public memory, the WebRTC tether to friend's device, or an Issue posted on friend's seed, the LLM sees one shape of return value and synthesizes its reply.
- The cross-twin call respects each side's permissions independently. Twin A is asking; twin B answers based on what twin B's operator allowed twin A's neighborhood to see (`public_facets` per §7). The LLMs don't negotiate permissions; the doormen do, transparently.
- The operator can drill in if they want — the agent-call panel under each chat reply (Article XXII parity, ported from the canonical brainstem) shows the raw cross-organism payload — but they never have to.

### 6a. Wire format

Every twin-chat message is a JSON object:

```json
{
  "schema":      "rapp-twin-chat/1.0",
  "from_rappid": "<sender's rappid>",
  "to_rappid":   "<recipient's rappid>",
  "utc":         "<iso8601>",
  "kind":        "say" | "share-fact" | "share-egg" | "request-fact" | "ack",
  "payload":     { /* kind-specific */ },
  "facets":      ["<list of public_facets the sender is asserting are relevant>"]
}
```

Messages chain by reference (`reply_to: <hash-of-prev-message>`) the same way frames do (see `ECOSYSTEM.md` §10 — content-addressed log). Tampering with a chain breaks subsequent message hashes.

### 6b. Message kinds

| `kind`          | Payload                              | Direction        | Purpose |
|---              |---                                   |---               |---      |
| `say`           | `{ text }`                           | A → B            | Plain conversation. Same shape as a doorman chat turn. |
| `share-fact`    | `{ fact, scope, source_rappid }`     | A → B            | "Here's something I think your organism would find useful." Recipient decides whether to absorb. |
| `share-egg`     | `{ egg-begin/chunk/end }`            | A → B (chunked)  | Stream an organism cartridge over the channel. Same protocol as the front door's tether-egg send. |
| `request-fact`  | `{ topic }`                          | A → B            | "Do you know anything about X?" Recipient may respond with `share-fact` or decline. |
| `ack`           | `{ for_hash, accepted | rejected }`  | B → A            | Receipt + optional reason. |

The recipient's organism is in charge of what to do with each message. The doorman receiving a `share-fact` writes it to **personal** memory by default (visible only to that visitor on that device); to promote to neighborhood or public, the visitor or operator has to take an explicit action.

### 6c. Conversation state

Each peer keeps its own conversation log. Logs are reconciled (after the line drops or asynchronously) via the Dream Catcher pattern (see `ECOSYSTEM.md` §10). UTC-first canon resolution + same-PK contradictions classified as alternate-dimension data. Nothing about twin chat changes the organism's canonical lineage state without an explicit operator action.

### 6e. Response envelope

When a doorman dispatches a §6a request and surfaces the result back to its caller (the local LLM, an organ, or another agent), the response is wrapped in an envelope of its own:

```json
{
  "schema":      "rapp-twin-chat-response/1.0",
  "channel":     "5a-http" | "5b-issues" | "5a-tether",
  "to_url":      "<peer's /chat URL>",
  "to_rappid":   "<recipient rappid>",
  "from_rappid": "<sender rappid>",
  "kind":        "<the §6b kind that was sent>",
  "envelope":    { /* the original §6a request, unmodified */ },
  "status":      <integer HTTP status>,
  "response":    { /* peer's parsed reply */ }
}
```

When the live channel is unreachable, the response carries `"ok": false`, an `error` string, and a `fallback` block describing the §5b Issues alternative (label, instructions, pre-filled `issues_new_url`). This lets the caller make a transport decision without re-encoding the envelope.

The response envelope is asymmetric to §6a — only the doorman that *initiated* the request emits it. The peer's reply itself is whatever shape its `/chat` returned (typically `rapp-chat-response/1.0`), and is nested under `response`.

Reference implementation: `rapp_brainstem/agents/twin_agent.py::_chat`.

## 7. Granular permissions — `public_facets`

`card.json` is extended with a `public_facets` array declaring what aspects of this organism are exposed to which scope. This is how granular gating works — an organism can be friendly to public swarms about some topics while keeping others to private neighborhood members only.

```json
{
  "schema":  "rapp-public-facets/1.0",
  "public_facets": [
    {
      "name":       "professional_history",
      "scope":      "public",
      "description": "What I do, where I've worked, what I'm working on now."
    },
    {
      "name":       "research_in_progress",
      "scope":      "neighborhood",
      "description": "Half-formed ideas I want my collaborators' help on."
    },
    {
      "name":       "personal_journal",
      "scope":      "personal",
      "description": "My private thoughts. Only the operator-as-visitor sees these."
    }
  ]
}
```

When a peer organism opens a permanent line and asserts `facets: ["research_in_progress"]` in a `request-fact` message, the recipient checks:

1. Is this facet declared in the recipient's `card.json`?
2. Does the asserted scope match the line's authentication level?
   - Public scope: any peer
   - Neighborhood scope: peer must prove push access to recipient's seed repo OR be in the recipient's collaborator list
   - Personal scope: peer must BE the operator
3. If all three checks pass, the recipient's organism may pull from the corresponding memory bucket and respond.

This is the **granular gate**. Operators declare facets explicitly; the protocol enforces tier-matching. The default is restrictive — facets are not advertised unless the operator has chosen to expose them.

## 8. Knowledge-exchange primitives

The protocol supports four exchange primitives, composable over the channel types above.

### 8a. Pull a fact (`request-fact` → `share-fact` → `ack`)

A peer asks; the responder either shares the fact (with the relevant facet asserted) or declines. The asker's organism stores the answer in its own memory tagged with `[from @<peer-handle>]` so provenance is preserved.

### 8b. Push a fact (`share-fact` → `ack`)

A peer pushes unprompted. Recipient classifies (personal / neighborhood / public) by default at the most restrictive scope (personal) and surfaces a UI prompt to upgrade.

### 8c. Trade an egg (`share-egg` chunked → `ack`)

The Charizard handoff. Recipient verifies SHA-256 against `egg-begin`'s declared hash before saving. See `ECOSYSTEM.md` §8 for the egg format.

### 8d. Reassimilate parallel dimensions (PR-mediated)

Two organisms (often two hatched dimensions of the same lineage) want to merge their divergent histories. The Dream Catcher pane (see `ECOSYSTEM.md` §10) does the diff client-side; the merge happens on GitHub via a pre-filled Issue → operator review → cherry-picked commits.

These four primitives compose. A neighborhood study group's worth of organisms can pull facts from each other (8a), push relevant findings outward (8b), and periodically reconcile (8d) — all with operator-mediated consent at every cross-scope move.

## 9. Trust model and adversarial scenarios

### 9a. What this protocol protects against

| Threat                                   | Defense                                                    |
|---                                       |---                                                         |
| Imposter claiming to be your organism    | rappid is fixed in your seed repo; URL serves real content |
| Tampered .egg cartridge                  | SHA-256 file hashes + manifest hash + origin commit SHA — verifier catches all three |
| Silent absorption of a peer's message    | All cross-scope moves require operator action (PR merge, commit, etc.) |
| Cross-scope information leak             | Tiers are concentric and explicit; declared facets gate by scope |
| Replay attack on a tether channel        | Each frame chains via prev_hash; replay breaks the chain   |
| Hostile peer flooding your organism      | GitHub Issues + PR review give the operator triage authority |

### 9b. What this protocol does NOT protect against

| Threat                                   | Reason                                                     |
|---                                       |---                                                         |
| Operator's GitHub account compromised    | The trust anchor is GitHub push permission. Compromise the GitHub account, compromise the operator role. Use 2FA. |
| LLM hallucination during cross-organism chat | LLMs can confabulate. Protocol can't prevent the model from inventing things; it just ensures the *transport* is honest. |
| Hosting cost denial-of-service           | GitHub Pages has soft limits. A heavily-trafficked organism can hit them. (Plant elsewhere if it's a problem.) |
| Coordinated PR spam                      | Operator must triage. We don't auto-merge anything.        |

### 9c. The "no servers" property and what it buys you

There is no server in the loop between two communicating organisms beyond:

- GitHub (for static file serving, Issues, PR review)
- The public PeerJS broker (signaling-only, drops out once the channel is up)
- Cloudflare Workers running the open-source Copilot proxy (each organism's chat traffic; not stored)

Every other channel is direct peer-to-peer (WebRTC) or read-from-public-repo. Information you exchange doesn't pass through a platform-operator's database. The platform operator (us) can't read your conversations because we're not in the path.

This is the invariant we're trading off CONVENIENCE for. We could build a cushy central server with discovery, presence, group chats, etc. We don't. The properties that matter — verifiable provenance, operator sovereignty, no-platform-lock-in — only hold if the substrate stays public and the runtime stays portable.

## 10. Cross-references

- [`HERO_USECASE.md`](./HERO_USECASE.md) — the canonical scenarios this protocol exists to support (Charizard handoff, Dream Catcher reassimilation, etc.)
- [`ECOSYSTEM.md`](./ECOSYSTEM.md) — what an individual organism is made of (file layout, schemas, surfaces)
- [`ANTIPATTERNS.md`](./ANTIPATTERNS.md) — what this protocol will never do (e.g. introduce a "skill" terminology, edit the frozen kernel, accept network calls without local-first fallback)
- [`pages/onboarding.html`](./pages/onboarding.html) — the visitor-facing introduction

---

*Schema: `rapp-neighborhood-protocol/1.0`. Append-only — extensions add new fields; existing fields are never repurposed. Breaking changes bump the schema version and trigger a migration plan documented here.*
