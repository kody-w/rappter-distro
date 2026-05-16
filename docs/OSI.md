# RAPP OSI — the AI stack as 7 layers

> A planted RAPP organism is a stack. Each layer abstracts the one below it. The agent at the top doesn't know whether the bytes it reads came from a local file or a peer's GitHub Pages — same way a browser doesn't know if its TCP segments rode Ethernet, Wi-Fi, or LTE. **This document maps the OSI model onto RAPP's primitives so every layer has a defining schema, an implementation, and a test.**
>
> Schema: `rapp-osi/1.0`. Read alongside `ECOSYSTEM_MAP.md` (the index) and `NEIGHBORHOOD_PROTOCOL.md` (the wire spec).

## Why this exists

The OSI framing makes one thing precise that the prose specs leave implicit: **what each layer is responsible for, and what it can assume about the layers above and below it.** Without this discipline, code drifts — schemas that should live at L6 leak into L7 application logic; trust scope checks that belong at L5 get skipped at the application level. The OSI map is a lint check on architecture. Every test suite (`tests/osi/L<n>-*.sh`) verifies one layer in isolation.

The model is **fractal**: the same 7 layers apply at every scale (agent / twin / neighborhood / metropolis). An agent's L6 envelope is `rapp-agent/1.0` metadata; a twin's L6 envelope is `rapp-twin-chat/1.0`; a neighborhood's L6 envelope is the same `rapp-twin-chat/1.0` plus `rapp-neighborhood-members/1.0`. The schemas change; the responsibilities don't.

---

## L1 — Substrate (the physical layer)

**Purpose.** The bytes have to live somewhere. L1 is the substrate that stores and transports them.

**RAPP analogue.** GitHub (repos + Pages + Issues + PRs API), `raw.githubusercontent.com` (content channel), the public PeerJS broker (signaling for L4a tether), the local filesystem (`~/.brainstem/`, `.brainstem_data/`), and Cloudflare Workers (auth proxy in `worker/`).

**Schemas.** None — this layer is "the medium." Schemas start at L2.

**Implementation.**
- GitHub Pages: every planted seed at `<owner>.github.io/<repo>/`
- raw fetch: `raw.githubusercontent.com/<owner>/<repo>/<sha>/<path>`
- PeerJS: `unpkg.com/peerjs@1.5.4` + the public broker at `peerjs.com`
- Local FS: `~/.brainstem/`, `.brainstem_data/memory.json`, `~/.rapp/twins/`
- Cloudflare auth worker: `worker/worker.js`

**Tests.** `tests/osi/L1-substrate.sh` — verifies (a) local FS is writable; (b) GitHub Pages serves `https://kody-w.github.io/RAPP/` with a 200; (c) `raw.githubusercontent.com` reachable; (d) PeerJS broker reachable. With `--offline`, every L1 check that touches the network must fall back to cached state without erroring.

**What L1 does NOT do.** No identity, no schemas, no trust. Just "can these bytes get from here to there?"

---

## L2 — Identity (the rappid layer)

**Purpose.** Address an organism uniquely. The identity is the organism's birth certificate — minted once, never regenerated, content-addressed in a public file so no central registry is needed.

**RAPP analogue.** `rappid` (UUIDv4 in `rappid.json`). `parent_rappid` for lineage. `kernel_version` for substrate compatibility.

**Schemas.**
- `rapp-rappid/1.1` (legacy, ECOSYSTEM §3)
- `rapp-rappid/2.0` (current — adds kernel + bonds, CONSTITUTION canonical)

**Implementation.**
- `rapp_brainstem/utils/bond.py` — mints + serializes
- `rapp_brainstem/utils/rappid.py` — schema R/W
- `rappid.json` at the root of every planted seed
- `~/.brainstem/rappid.json` for the operator's own brainstem
- `~/.brainstem/bonds.json` — append-only lineage log

**Tests.** `tests/osi/L2-identity.sh` — verifies (a) UUIDv4 mint; (b) `rapp-rappid/2.0` schema string; (c) `parent_rappid` chain integrity (must point to a real rappid in the lineage walk); (d) re-running `boot.py` does NOT regenerate rappid; (e) bonds.json is append-only.

**What L2 does NOT do.** No discovery (that's L3). No trust decisions (that's L5). The identity is just the address — what you do with it is upper-layer business.

---

## L3 — Discovery (the lineage + catalog layer)

**Purpose.** Given a rappid, find the organism. Given an organism, walk the family tree. Discovery is the routing layer — it answers "who exists, and how do I reach them?"

**RAPP analogue.** Four discovery channels per NEIGHBORHOOD_PROTOCOL §4:
- 4a — Lineage walk (parent_rappid backward, GitHub forks API forward)
- 4b — Public catalog (`kody-w/rapp-egg-hub/index.json`)
- 4c — Direct invitation (URL or QR shared out-of-band)
- 4d — Canonical test neighbor (`kody-w/rapp-test-neighbor`)

Plus the metropolis tracker pattern (`pages/metropolis/index.json`, schema `rapp-metropolis-index/1.0`) — Kazaa-style federated trackers can list neighborhoods, and trackers can list each other.

**Schemas.**
- `rapp-rappid/2.0` `parent_rappid` field (lineage walk)
- `rapp-metropolis-index/1.0` (federated tracker)
- `rapp-metropolis-entry/1.0` (one neighborhood entry)
- `rapp-egg-hub-entry/1.0` (egg catalog)
- `rapp-rappid-estate-view/1.0` (estate-by-identity lookup, the global passport)

**Implementation.**
- `pages/metropolis/index.json` + `index.html` — the live tracker
- `pages/metropolis/README.md` — protocol + federation rules
- `rapp_brainstem/utils/organs/neighborhood_membership_organ.py::_estate_view` + `by-rappid` route
- `rapp_brainstem/utils/peer_registry.py` — local peer cache
- GitHub forks API + Contents API (cached via `cachedGhJson`)

**Tests.** `tests/osi/L3-discovery.sh` — verifies (a) metropolis index validates against `rapp-metropolis-index/1.0`; (b) lineage walk works (parent_rappid resolves to a known repo or graceful "not-found"); (c) by-rappid lookup returns an estate view; (d) `kody-w/rapp-test-neighbor` reachable when network is up.

**What L3 does NOT do.** No content delivery (that's L4). No trust enforcement on what the discovered organism exposes (that's L5).

---

## L4 — Channels (the transport layer)

**Purpose.** Move bytes between two organisms. Different channels have different latency, durability, and consent properties — pick the right one for the message.

**RAPP analogue.** Four channel types per NEIGHBORHOOD_PROTOCOL §5:

| Channel | Latency | Durability | Trust semantics |
|---|---|---|---|
| **4a — WebRTC tether** | live | ephemeral | DTLS encrypted, broker drops out after handshake |
| **4b — GitHub Issues** | minutes-hours | durable | label-routed (`private-memory`, `egg-submission`, `dream-catcher`, `agent-proposal`, `neighborhood-message`) |
| **4c — Pull Requests** | minutes-hours | durable + canonical | asymmetric — only operator can merge into trunk |
| **4d — raw fetch** | network-dependent | cached for offline | content-addressed via `raw.githubusercontent.com/<owner>/<repo>/<sha>/<path>` |

**Schemas.**
- `rapp-tether/1.0` (4a — WebRTC envelope, implicit in NEIGHBORHOOD_PROTOCOL §5a)
- (Issues/PRs/raw use HTTP/JSON; no RAPP-specific transport schema)

**Implementation.**
- 4a tether: `installer/plant.sh` writes the pair button + autoRenderTetherQR (doorman). `pages/vbrainstem.html` is the public canonical implementation — multi-participant, ECDSA P-256 keypair + 6-digit safety code, host-owns-LLM relay (see SPEC §18.11). Both use the PeerJS public broker.
- 4b Issues: `cachedGhJson('/repos/.../issues?labels=...')`
- 4c PRs: `gh pr create` from `learn_new_agent.py` and the front door's "Propose an agent" pane
- 4d raw fetch: `cachedGhJson` / `cachedGhText` wrappers — REQUIRED per ANTIPATTERNS §5

**Tests.** `tests/osi/L4-channels.sh` — verifies (a) PeerJS broker reachable for 4a handshake (browser test stubbed; can't open data channel from shell); (b) GitHub Issues API returns labeled issues correctly; (c) raw fetch through `cachedGhJson` returns cache on network failure (offline mode); (d) `rapp-tether/1.0` envelope shape from doorman frame log.

**What L4 does NOT do.** No content interpretation (that's L6 envelope + L7 application). No facet enforcement (that's L5).

---

## L5 — Trust scope (the session/auth layer)

**Purpose.** Decide who can read or write what. Three concentric scopes — personal ⊂ neighborhood ⊂ public swarm — and granular facets per `card.json`.

**RAPP analogue.** Trust scopes from NEIGHBORHOOD_PROTOCOL §2:

| Scope | Boundary | Persistence |
|---|---|---|
| **Personal** | one device, one visitor | localStorage |
| **Neighborhood** | repo collaborators (push access) | GitHub Issues + private repo files |
| **Public swarm** | anyone | committed to the seed repo |

Plus `public_facets` per §7 — operator declares which aspects of the organism are exposed at which scope.

**Schemas.**
- `rapp-public-facets/1.0` — granular facet declaration (NEIGHBORHOOD_PROTOCOL §7)
- `rapp-neighborhood-members/1.0` — roster (collaborator-status check)
- `rapp-twin-spec/1.0` — soul Identity block (per-organism identity assertion)

**Implementation.**
- `rapp_brainstem/utils/organs/neighborhood_membership_organ.py::_verify_membership` — role check via Contents API (`members.json`) + GitHub collaborators API
- `card.json` (operator-set) — `public_facets` array
- Doorman system prompt assembly — three memory tiers (device-local, public, per-user) merged with `[@<login>] <fact>` prefix to telegraph access boundary
- ANTIPATTERNS §4 — soul.md MUST include the Identity block

**Tests.** `tests/osi/L5-trust-scope.sh` — verifies (a) `rapp-public-facets/1.0` schema validates; (b) facet declared with `scope: neighborhood` blocks public-only callers; (c) collaborator check correctly classifies operator vs visitor; (d) per-user issue memories are filtered by `@<login>`.

**What L5 does NOT do.** No envelope construction (that's L6). No application semantics (that's L7).

---

## L6 — Envelope (the presentation layer)

**Purpose.** Wrap payload in a structured envelope with provenance, integrity, and routing. Envelopes are content-addressed (SHA-256) where applicable.

**RAPP analogue.** The wire formats. Twin chat envelope, egg manifest, frame log.

**Schemas.**
- `rapp-twin-chat/1.0` — inter-twin message envelope (NEIGHBORHOOD_PROTOCOL §6a). Fields: `schema`, `from_rappid`, `to_rappid`, `utc`, `kind` (one of: `say` / `share-fact` / `share-egg` / `request-fact` / `ack`), `payload`, `facets`
- `brainstem-egg/2.2-organism` — full instance cartridge
- `brainstem-egg/2.2-rapplication` — single rapp cartridge
- `brainstem-egg/2.3-session` — workflow-session cartridge (JSON; rappid + sha256-pinned runtime + transcript + participants); shipping 2026-05-10. Per SPEC §18.10–§18.11.
- `brainstem-egg/2.3-neighborhood` *(planned)* — neighborhood gate cartridge (ZIP)
- `brainstem-egg/2.3-estate` *(planned)* — operator-identity-portable cartridge (ZIP)
- `rapp-egg-provenance/1.0` — file hashes + manifest hash + origin commit SHA
- `rapp-organism-state/1.0` — state_at_seal block
- `rapp-frame/1.0` — content-addressed mutation event (prev_hash chain)
- `rapp-card/1.0` — trade-card override

**Implementation.**
- `rapp_brainstem/agents/twin_agent.py::_chat` — emits + consumes `rapp-twin-chat/1.0`
- `rapp_brainstem/utils/bond.py` — packs + verifies organism + rapplication eggs
- `rapp_brainstem/utils/egg.py` — legacy egg utilities
- `pages/vbrainstem.html::exportCart` — emits `brainstem-egg/2.3-session` cartridges
- `rapp_brainstem/agents/egg_hatcher_agent.py` — universal hatcher; introspects egg manifest schema/type and routes by kind (organism / rapplication / session / neighborhood / estate); refuses on unknown kinds
- `tests/doorman/dreamcatcher.mjs` — `rapp-frame/1.0` chain validation

**Tests.** `tests/osi/L6-envelope.sh` — verifies (a) all 5 `rapp-twin-chat/1.0` `kind` values round-trip between two test brainstems; (b) egg pack → SHA verify → hatch produces identical content; (c) `rapp-egg-provenance/1.0` hashes catch tampering; (d) `rapp-frame/1.0` prev_hash chain is unbroken (synthetic 5-frame chain). Plus `tests/osi/L6a-frame-chain-browser.sh` (Playwright, --with-browser) — drives the real `appendFrame()` in plant.sh's doorman + verifies Dream Catcher reassimilation classifies shared / new / contradiction correctly per HERO_USECASE.md §2 doctrine.

**What L6 does NOT do.** No agent invocation (that's L7). No transport selection (that's L4).

---

## L7 — Application (the agent + /chat layer)

**Purpose.** Do the work. Agents are the unit of capability; `/chat` is the only invocation surface; the response splits on `|||VOICE|||` and `|||TWIN|||`.

**RAPP analogue.** Agents (single-file `*_agent.py`), `/chat` endpoint, organs (HTTP `/api/<name>/<path>` extensions), the soul's Identity block + voice/twin slot protocol.

**Schemas.**
- `rapp-agent/1.0` — agent metadata dict (function-calling shape)
- `rapp-chat-response/1.0` — `/chat` response envelope (`{response, agent_logs, ...}`)
- `rapp-twin-spec/1.0` — soul Identity block
- `rapp-rar-index/1.0` — per-seed RAR registry declaring required agents/cards/rapps/organs/senses (sha256-pinned). Every planted seed ships one (plant.sh scaffolds it). Hot-loaders verify against the published manifest before installing. Defaults to scope-local; opt-in federation to kody-w/RAR + RAPP_Store + RAPP_Sense_Store.
- `rapp-rar-loadout/1.0` — RarLoader install-result envelope

**Implementation.**
- `rapp_brainstem/brainstem.py` — Flask + `/chat` + provider dispatch (KERNEL — Art. XXXIII)
- `rapp_brainstem/agents/basic_agent.py` — `BasicAgent` base class (KERNEL)
- `rapp_brainstem/agents/*_agent.py` — every agent (auto-discovered, reloaded per request)
- `rapp_brainstem/utils/organs/*_organ.py` — HTTP extensions
- `rapp_brainstem/soul.md` — voice/twin protocol (sacred per CLAUDE.md §5)
- `rapp_swarm/function_app.py` — Tier 2 (Azure Functions) — same agent contract, prefixed routes

**Tests.** `tests/osi/L7-application.sh` — verifies (a) `/chat` returns `rapp-chat-response/1.0`; (b) agent metadata validates as `rapp-agent/1.0`; (c) `|||VOICE|||` and `|||TWIN|||` slots are split correctly; (d) ANTIPATTERNS §4 — no fallback to "RAPP" / "an AI assistant" branding.

**What L7 does NOT do.** Don't reach into L4 transport directly — use the `Neighborhood.ask` agent / twin chat envelope. Don't redo L5 trust checks — the lower layers should have already gated.

---

## Cross-cutting concerns

These run *orthogonal* to the layer model — every layer must satisfy them.

### CC1 — Tier portability (CONSTITUTION Art. XV)

The same agent file runs unmodified on Tier 1 (Flask), Tier 2 (Azure Functions), and Tier 3 (Copilot Studio). Storage backends differ; the contract surface doesn't.

**Test.** `tests/osi/X1-tier-portability.sh` — same agent file imports + runs in both `rapp_brainstem/` and `rapp_swarm/_vendored/` contexts; `/chat` envelope is identical (modulo `/api/` path prefix on Tier 2).

### CC2 — Survival (SURVIVAL.md)

Every layer must degrade gracefully. L1 down → L4d falls back to cached. L5 down → L7 surfaces "no permission" without crashing. Ten failure-mode rows enumerated in `SURVIVAL.md`.

**Test.** `tests/osi/X2-survival.sh` — simulate L1 outage (block network); confirm cached state still serves; confirm error messages are honest, not silently degraded.

### CC3 — Egg lifecycle (HERO_USECASE.md §1)

Eggs roundtrip across all layers — L7 invokes export (agent), L6 packages with provenance, L5 enforces tier (doorman vs ascended), L4 transports (tether or attached to PR or USB), L3 verifies via deep-verify against L1 origin commit.

**Test.** `tests/osi/X3-egg-lifecycle.sh` — pack egg from a fresh seed, verify SHA, hatch into a new directory, confirm rappid + agents + soul preserved bit-for-bit.

### CC4 — Federation (NEIGHBORHOOD_PROTOCOL §6)

Two organisms exchange `rapp-twin-chat/1.0` messages over each of the four channels. The transparent-handoff principle: L7 doesn't know which channel was used.

**Test.** `tests/osi/X4-federation.sh` — boot two test brainstems on different ports; verify all 5 message kinds round-trip; verify both brainstems' `/chat` returns the canonical envelope shape.

---

## The matrix view

|             | Agent | Twin | Neighborhood | Metropolis |
|---          |---    |---   |---           |---         |
| **L1 substrate**  | local FS | local FS + GitHub | + collaborator gate | + federated trackers |
| **L2 identity**   | inherited | own rappid | neighborhood_rappid | (per twin) |
| **L3 discovery**  | in metadata | lineage walk | gate URL + members.json | tracker index |
| **L4 channels**   | in-process | tether + Issues + PRs + raw | + collaborator-gated | + cross-tracker fetch |
| **L5 trust scope**| caller's | personal/neighborhood/public | + collaborator role | + tracker reputation |
| **L6 envelope**   | rapp-agent/1.0 | rapp-twin-chat/1.0 | + members + facets | + metropolis-index |
| **L7 application**| `perform()` | `/chat` | `Neighborhood.ask` | aggregator agent |

**Reading the matrix:** every cell has a defining schema and a test. If a cell is empty, that's a gap — track it in `ECOSYSTEM_MAP.md` §13 drift.

---

## How to use this document

- **Designing a new feature?** Identify which layer it belongs to. If you find yourself writing trust-scope logic at L7, that's a smell — push it down.
- **Debugging?** Walk the layers from L7 down. The error usually surfaces several layers below where it manifests.
- **Adding a schema?** It belongs in exactly one layer. Cross-layer schemas are usually two schemas wearing a trenchcoat.
- **Writing a test?** Match it to a layer file in `tests/osi/`. If the test doesn't fit one layer, it's probably a CC test (X1–X4) or it's actually two tests.

## How to run the tests

```bash
# All layers + cross-cutting concerns
bash tests/osi/run.sh

# A single layer
bash tests/osi/L1-substrate.sh
bash tests/osi/L6-envelope.sh

# Offline mode (skip network-dependent checks)
bash tests/osi/run.sh --offline
```

The runner prints a green/red matrix: rows are layers, columns are scales (agent / twin / neighborhood). Anything red is a regression against this contract.

## Cross-references

- [`ECOSYSTEM_MAP.md`](./ECOSYSTEM_MAP.md) — the canonical synthesis index. OSI layers are §2.5 (a parallel view of the fractal); this doc is the deep-dive.
- [`NEIGHBORHOOD_PROTOCOL.md`](./NEIGHBORHOOD_PROTOCOL.md) — wire spec for L4–L6
- [`ECOSYSTEM.md`](./ECOSYSTEM.md) — anatomy of one organism (L2 + L7)
- [`SURVIVAL.md`](./SURVIVAL.md) — degradation contract (CC2)
- [`HERO_USECASE.md`](./HERO_USECASE.md) — the four scenarios this stack exists to satisfy
- [`ANTIPATTERNS.md`](./ANTIPATTERNS.md) — locked rules per layer (notably: §1 ONE term for L7 unit; §2 frozen kernel = L7 base; §5 local-first L4d fallback)

---

*Schema: `rapp-osi/1.0`. Append-only — layers don't get repurposed. New cross-cutting concerns add a new CC<n> row. Breaking changes bump the schema version.*
