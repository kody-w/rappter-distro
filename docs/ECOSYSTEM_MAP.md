# RAPP Ecosystem Map

> Single canonical synthesis of the RAPP ecosystem. **Start every session here.**
> Schema: `rapp-ecosystem-map/1.0`. Append-only. Derivative — if it disagrees with `MASTER_PLAN.md` or `CONSTITUTION.md`, the spec wins and this map is wrong; fix the map.

## How to read this

1. **§11 first if you're about to DO anything** — the decision table answers "before I do X, what should I check?"
2. **§5 if you need a schema** — every `rapp-*/N.M` and `brainstem-*/N.M` schema with its defining doc.
3. **§6 if you need an existing implementation** — file path → spec section it satisfies.
4. **§13 if your code seems to disagree with the spec** — known drift gaps with citations.
5. **§12 antipatterns are LAW** — re-read before any non-trivial commit.

---

## §1 — Authority order

When two docs disagree, this is the precedence:

1. **`MASTER_PLAN.md`** wins on strategic direction. *"When those documents and this one disagree, this one wins. They tell us how to execute the plan; this one IS the plan."* (MASTER_PLAN.md L114)
2. **`CONSTITUTION.md`** governs the repo (38+ articles).
3. **Spec docs** (HERO_USECASE.md, ECOSYSTEM.md, NEIGHBORHOOD_PROTOCOL.md, ANTIPATTERNS.md, SURVIVAL.md, COMMERCIAL.md, TRADEMARK.md, LEXICON.md, DEFINITION_OF_DONE.md, TEMPLATE.md) execute the plan.
4. **`pages/vault/`** — the *why* essays (Constitution Article XXIII).
5. **Code** comments and runtime behavior — last because code rots; the spec is canonical.

---

## §2 — The fractal scales

Same primitives at every scale: **rappid + door + card + tether + trust scope.** Same protocol from agent up to metropolis-of-metropolises.

```
┌──────────────────────── …outward ─────────────────────────┐
│  Federations of metropolises (planet-scale; emerges)       │
└──────────────┬─────────────────────────────────────────────┘
               ↓
┌──────────────────────── Metropolis ───────────────────────┐
│  Emergent mesh of estates through shared neighborhoods     │
│  rappid: each operator's    | door: each gate URL          │
│  card: per twin             | tether: federation channels  │
│  scope: per facet                                          │
│  example: kody-w.github.io/RAPP/metropolis/                │
│  spec: vault/Decisions/2026-05-08 — Estate is the…         │
└──────────────┬─────────────────────────────────────────────┘
               ↓
┌──────────────────────── Estate ───────────────────────────┐
│  ONE operator's union of all neighborhoods                 │
│  rappid: operator's personal one is the spine              │
│  door: /api/estate/* on operator's brainstem               │
│  card: operator's identity card                            │
│  tether: Issues, file://, ~/.brainstem/eggs/               │
│  scope: personal across all subscriptions                  │
│  impl: utils/organs/estate_organ.py + neighborhood_membership_organ.py│
└──────────────┬─────────────────────────────────────────────┘
               ↓
┌──────────────────────── Neighborhood ─────────────────────┐
│  Community-with-a-purpose; collaborator-gated              │
│  rappid: neighborhood_rappid                               │
│  door: gate URL <owner>.github.io/<gate-repo>              │
│  card: neighborhood card.json                              │
│  tether: NEIGHBORHOOD_PROTOCOL §5a–d (4 channel types)     │
│  scope: §2 personal/neighborhood/public + §7 facets        │
│  examples: kody-w/microsoft-se-team-neighborhood + private │
│            kody-w/public-art-collective                    │
│  impl: utils/organs/neighborhood_membership_organ.py       │
└──────────────┬─────────────────────────────────────────────┘
               ↓
┌──────────────────────── Twin (organism) ──────────────────┐
│  ONE planted seed (one rappid)                             │
│  rappid: UUIDv4 in rappid.json (never regenerated)         │
│  door: front-door index.html + doorman/                    │
│  card: card.json — ECOSYSTEM §3                            │
│  tether: ECOSYSTEM §4 surfaces                             │
│  scope: NEIGHBORHOOD_PROTOCOL §2                           │
│  example: kody-w/heimdall                                  │
│  impl: rapp_brainstem/ + every planted seed                │
└──────────────┬─────────────────────────────────────────────┘
               ↓
┌──────────────────────── Agent ────────────────────────────┐
│  Single file, single class, single perform()               │
│  rappid: inherits parent twin's                            │
│  door: none (addressed via brainstem.py /chat tools)       │
│  card: metadata dict at module scope                       │
│  tether: in-process                                        │
│  scope: inherits caller's                                  │
│  contract: ANTIPATTERNS §1 + CONSTITUTION Art. XXXIII      │
│  examples: rapp_brainstem/agents/learn_new_agent.py +      │
│            installable RAR agents (e.g. @rapp/twin_agent)  │
└────────────────────────────────────────────────────────────┘
```

---

## §3 — Five universal primitives

| Primitive | One-line meaning | Defined in | Schema(s) |
|---|---|---|---|
| **rappid** | UUIDv4 identity, minted once at plant, never regenerated | ECOSYSTEM §3, NEIGHBORHOOD_PROTOCOL §3 | `rapp-rappid/1.1`, `rapp-rappid/2.0` |
| **door** | Public surface URL where this thing is reachable | ECOSYSTEM §4 (front door + doorman); NEIGHBORHOOD_PROTOCOL §1 (Pages URL) | (no separate schema; URL is the contract) |
| **card** | Trade-card / introduction view | ECOSYSTEM §3 (`card.json`) | `rapp-card/1.0` |
| **tether** | The four channel types — WebRTC, Issues, PRs, raw fetch | NEIGHBORHOOD_PROTOCOL §5a–d | `rapp-twin-chat/1.0` (over tether) |
| **trust scope** | Personal / Neighborhood / Public swarm | NEIGHBORHOOD_PROTOCOL §2 + §7 | `rapp-public-facets/1.0` |

---

## §4 — Spec-doc map (which doc owns which concept)

| Doc | Owns | When to read |
|---|---|---|
| `MASTER_PLAN.md` | First-principles north star (Part 1 + Part Deux); single-sentence: *"use everyone else's hardware to run the network"* | Strategic direction disputes |
| `CONSTITUTION.md` | Repo governance + sacred constraints + 38+ articles | Structural change, new contributor |
| `OSI.md` | The 7-layer model — substrate / identity / discovery / channels / trust / envelope / application — with schemas + tests per layer | Designing a new feature; figuring out which layer something belongs to |
| `HERO_USECASE.md` | Four canonical scenarios (Charizard, Dream Catcher, Mom's Mixtape, Pizza Place) that judge any change | PR review, roadmap |
| `ECOSYSTEM.md` | Anatomy of one organism (file layout, identity stack, two surfaces, memory tiers, MMR, eggs, integrity, 3 network modes) | Organism-level work |
| `NEIGHBORHOOD_PROTOCOL.md` | Cross-organism wire (4 channels, twin chat, facets, knowledge primitives, adversarial scenarios) | Federation work |
| `ANTIPATTERNS.md` | 5 locked rules — things never to do | Every commit |
| `SURVIVAL.md` | Failure-mode contract — what survives what | Adding a network call |
| `LEXICON.md` | The official human + developer vocabulary | Naming anything |
| `TRADEMARK.md` | Wordmark scope (RAPP, rappid, hatchling, vBrainstem, rapplication, rapp_kernel, brainstem) | Anything user-facing |
| `COMMERCIAL.md` | Open / commercial boundary | Anything that ships |
| `DEFINITION_OF_DONE.md` | Test discipline | Before saying "done" |
| `TEMPLATE.md` | What planted seeds look like | Plant flow |
| `CLAUDE.md` | Daily AI-assistant instructions | Every session start |
| `pages/vault/Decisions/` | The "why" essays for major decisions | Settled arguments |
| `pages/vault/Architecture/` | Long-form design notes (RAR, Rappid, Signed Releases, …) | Deep design |
| `pages/vault/Field Notes/` | Engineering essays | Cross-cutting context |

---

## §5 — Schema quick reference

Every `rapp-*/N.M` and `brainstem-*/N.M-variant` currently emitted in the repo. If it isn't here, search before defining a new one (ANTIPATTERNS §3 — bump versions, no shims).

| Schema | Purpose | Defined in | Emitted by |
|---|---|---|---|
| `rapp-agent/1.0` | Agent module manifest (function-calling shape) | pages/docs/SPEC.md | every `*_agent.py` metadata dict |
| `rapp-rappid/1.1` | Organism birth certificate (legacy schema) | ECOSYSTEM §3 | installer/plant.sh, twin_agent.py `_summon` |
| `rapp-rappid/2.0` | Birth certificate + kernel + bonds (current) | CONSTITUTION; vault/Architecture/Rappid | utils/bond.py, rappid.json |
| `rapp-card/1.0` | Trade-card override | ECOSYSTEM §3 | card.json (operator-set) |
| `rapp-frame/1.0` | Mutation event (content-addressed sha256, prev_hash chain) | ECOSYSTEM §3, HERO_USECASE §2 | installer/plant.sh::appendFrame → localStorage `rapp_frames_v1`; ascended egg packs `data/frames.json` |
| `brainstem-egg/2.0` | Legacy twin egg | utils/egg.py | (legacy) |
| `brainstem-egg/2.1` | Variant repo cartridge | CLAUDE.md egg formats | utils/bond.py, twin_agent.py |
| `brainstem-egg/2.2-organism` | Full instance cartridge (rappid + soul + .env + agents + organs + senses + services + .brainstem_data) | ECOSYSTEM §3, §8 | utils/bond.py |
| `brainstem-egg/2.2-rapplication` | Single rapp cartridge (rappid + agent + UI + per-rapp state) | CLAUDE.md egg formats | utils/bond.py |
| `brainstem-egg/2.3-session` | Session cartridge (JSON; rappid + sha256-pinned runtime + transcript + participants) — the vbrainstem tether's portable format | SPEC.md §18.10, §18.11; rappterbox/carts/SCHEMA.md | pages/vbrainstem.html (export); rappterbox/console.html + pages/vbrainstem.html (mount); rapp_brainstem/agents/egg_hatcher_agent.py (introspect+route) |
| `brainstem-egg/2.3-neighborhood` *(planned)* | Neighborhood gate cartridge (ZIP; rappid + neighborhood.json + members.json + agents/ + rapplications/ + ses/ + soul.md + CONSTITUTION.md + rar/index.json) | SPEC.md §18.10 | egg_hatcher_agent.py (manual instructions; auto-mint planned) |
| `brainstem-egg/2.3-estate` *(planned)* | Estate cartridge — operator's whole multi-tier identity portable across substrates (public discovery + private bones pointer + sealed PII pointer) | SPEC.md §18.10, ESTATE_SPEC.md, PUBLIC_PRIVATE_BOUNDARY.md | egg_hatcher_agent.py (manual instructions; auto-anchor planned) |
| `rappterbox-cart/0.1` | Legacy session cartridge schema (superseded by brainstem-egg/2.3-session 2026-05-10; loader still accepts both for one release) | rappterbox/carts/SCHEMA.md | pages/vbrainstem.html (legacy export); rappterbox/console.html (legacy load) |
| `rapp-egg-provenance/1.0` | SHA-256 file hashes + manifest hash + origin commit SHA | ECOSYSTEM §3, §9 | utils/bond.py |
| `rapp-organism-state/1.0` | state_at_seal snapshot (mem_count, mut_count, MMR, etc.) | ECOSYSTEM §3 | utils/bond.py |
| `rapp-user-memories/1.0` | Per-user issue memories (ascended-tier export) | ECOSYSTEM §3 | doorman ascended export |
| `rapp-twin-chat/1.0` | Inter-twin message envelope (the federation wire) | NEIGHBORHOOD_PROTOCOL §6a | twin_agent.py `_chat` |
| `rapp-twin-chat-response/1.0` | Twin-chat reply wrapper | NEIGHBORHOOD_PROTOCOL §6e | twin_agent.py `_chat` |
| `rapp-public-facets/1.0` | Granular permission gate (name + scope + description) | NEIGHBORHOOD_PROTOCOL §7 | card.json (operator-set) |
| `rapp-twin-spec/1.0` | Soul Identity block contract | ANTIPATTERNS §4 | installer/plant.sh `write_soul_md` |
| `rapp-lineage-rollup/1.0` | Lineage tree aggregation result (avg/median/min/max MMR) | ECOSYSTEM §15 | agents/lineage_rollup_agent.py |
| `rapp-species-leaderboard/1.0` | Global Herald → Immortal ladder | ECOSYSTEM §15 | agents/species_leaderboard_agent.py |
| `rapp-proximity-match/1.0` | Geohash-prefix match result (Pizza Place layer) | ECOSYSTEM §15, HERO_USECASE §4 | agents/proximity_discovery_agent.py |
| `rapp-resurrection-assessment/1.0` | Stasis-state diagnosis | ECOSYSTEM §15 | agents/resurrection_ceremony_agent.py |
| `rapp-resurrection-ceremony/1.0` | Resurrection frame + next-step commit template | ECOSYSTEM §15, Art. XXXIV.5 | agents/resurrection_ceremony_agent.py |
| `rapp-release-key/1.0` | ed25519 keypair generation envelope | CONSTITUTION Art. XXXIV.7 | tools/sign_release.py keygen |
| `rapp-release-signature/1.0` | ed25519 detached signature sidecar | CONSTITUTION Art. XXXIV.7 | tools/sign_release.py sign |
| `rapp-pheromone/1.0` | Ant-farm pheromone (content-addressed, prev_hash chained) | kody-w/ant-farm/skill.md | agents/ant_agent.py + ant-pheromone-labeled GitHub Issues |
| `rapp-colony-observation/1.0` | Ant-farm collective state synthesis | (defined-by-emitter) | agents/colony_observer_agent.py |
| `rapp-ant-tick/1.0` | Ant-agent tick result envelope | (defined-by-emitter) | agents/ant_agent.py perform() |
| `rapp-rar-index/1.0` | Per-neighborhood RAR registry — required participation kit | (defined-by-emitter; published per planted seed at `rar/index.json`) | every planted seed; loader: rapp_brainstem/agents/rar_loader_agent.py |
| `rapp-rar-manifest/1.0` | sha256 verification block inside `rar/index.json` | (companion to rapp-rar-index/1.0) | every planted seed |
| `rapp-rar-loadout/1.0` | Result envelope — what the RarLoader installed/skipped/errored | (defined-by-emitter) | rapp_brainstem/agents/rar_loader_agent.py |
| `rapp-graft-result/1.0` | Bond-technique graft result envelope (files added/skipped/restored, bond_event, metropolis roll-up state) | (defined-by-emitter; companion to bond.py kind="graft") | rapp_brainstem/agents/graft_neighborhood_agent.py |
| `rapp-launch-result/1.0` | LOCAL→GLOBAL launch envelope — local brainstem snapshot delivered to a target public repo (egg sha256 + continuation manifest URL + fork lineage) | (defined-by-emitter; companion to bond.py kind="launch") | rapp_brainstem/agents/launch_to_public_agent.py |
| `rapp-launch-continuation/1.0` | The LAUNCH_CONTINUATION.md instructions left in the target repo so a downstream brainstem can hatch the launched egg via `utils.bond hatch` | (defined-by-emitter; written into the target repo at root) | rapp_brainstem/agents/launch_to_public_agent.py |
| `rapp-launch-fingerprint/1.0` | Compact fingerprint block embedded in the launch result + continuation: rappid + egg sha256 + parent_commit + bond technique pointer | (defined-by-emitter) | rapp_brainstem/agents/launch_to_public_agent.py |
| `rapp-ecosystem-audit/1.0` | Drift detector envelope — per-offspring drift entries + by-kind counts + suggested next-actions classified as LOCAL_TO_GLOBAL / GLOBAL_TO_LOCAL / INFORMATIONAL | (defined-by-emitter; written to `pages/_audit/ecosystem-audit.{md,json}`) | tools/ecosystem_audit.py |
| `rapp-rhythm-pulse/1.0` | Bond Pulse heartbeat envelope — pulse_at + audit_summary + suggested_actions[] + by_direction counts + degraded flag + bond_event reference. Operator-mediated; never auto-executes. | (defined-by-emitter; companion to bond.py kind="rhythm") | rapp_brainstem/agents/bond_rhythm_agent.py |
| `rapp-dock-result/1.0` | Universal additive-merge result envelope (added/skipped + pre/post sha256 + parallel-to-other-dock-scopes mapping + optional bond event) | (defined-by-emitter; companion to bond.py kind="dock") | rapp_brainstem/agents/dock_agent.py |
| `rapp-twin/1.0` | Mobile-side twin egg bundle (canonical client schema) | utils/web/mobile/rapp-mobile.js:194 (defined-by-emitter) | utils/web/mobile/rapp-mobile.js |
| `rapp-twin-identity/1.0` | Twin identity envelope (onboard surface) | utils/web/onboard/index.html:459 (defined-by-emitter) | utils/web/onboard/index.html |
| `rapp-neighborhood/1.0` | Neighborhood metadata | gate repo `neighborhood.json` | plant_discord_neighborhood_agent.py, fixtures |
| `rapp-neighborhood-protocol/1.0` | Wire-protocol meta | NEIGHBORHOOD_PROTOCOL header | the spec doc itself |
| `rapp-neighborhood-members/1.0` | Roster | gate repo `members.json` | neighborhood_membership_organ.py |
| `rapp-neighborhood-subscription/1.0` | One subscription record (gate_url, role, etc.) | (organ-defined) | neighborhood_membership_organ.py |
| `rapp-neighborhoods-cache/1.0` | Local cache file | (organ-defined) | neighborhood_membership_organ.py |
| `rapp-estate/1.0` | Estate top-level (organ-aggregated view, server-side) | vault/Decisions 2026-05-08 | neighborhood_membership_organ.py `_estate_view` |
| `rapp-estate/1.1` | Local-first estate FILE format (door catalog at `~/.brainstem/estate.json` + `<gh>/rapp-estate/main/estate.json`). Each entry stores ONLY `{rappid, added_at, via}`. **Authority: pages/docs/ESTATE_SPEC.md, CONSTITUTION Article XLVI** | pages/docs/ESTATE_SPEC.md | rapp_brainstem/agents/estate_agent.py |
| `rapp-door/1.0` | Derived door object returned by `door_from_rappid()` — owner, repo, kind, door_type, all 9 canonical URLs. Pure derivation; never stored. | pages/docs/ESTATE_SPEC.md §5 | tools/door_address.py |
| `rapp-facets/1.0` | Per-door published-capability declaration at `<owner>/<repo>/main/facets.json` | pages/docs/ESTATE_SPEC.md §3 (Door URL Set #9) | rapp_brainstem/agents/plant_seed_agent.py |
| `rapp-estate-view/1.0` | Aggregated twin view (zones + bridges) | (organ-defined) | estate_organ.py |
| `rapp-estate-eggs/1.0` | Estate egg index | (organ-defined) | estate_organ.py |
| `rapp-rappid-estate-view/1.0` | Estate-by-rappid lookup (global passport) | project_rappid_is_global_passport memory | neighborhood_membership_organ.py `by-rappid` |
| `rapp-braintrust-contribution-receipt/1.0` | Contribution acknowledgment (organ-local; cross-org goes via §5b Issues) | NEIGHBORHOOD_PROTOCOL §5b "Organ-local HTTP shortcut" | neighborhood_membership_organ.py `contribute` |
| `rapp-discord-bridge/1.0` | Discord planting bridge config | NEIGHBORHOOD_PROTOCOL §4e | plant_discord_neighborhood_agent.py |
| `rapp-discord-plant-envelope/1.0` | Discord plant operation result | NEIGHBORHOOD_PROTOCOL §4e | plant_discord_neighborhood_agent.py |
| `rapp-peers/1.0` | Peer registry (legacy) | utils/peer_registry.py | peer_registry.py |
| `rapp-peers/1.1` | Peer registry (current) | utils/peer_registry.py | peer_registry.py |
| `rapp-peers-view/1.0` | Peer-list view | (organ-defined) | neighborhood_organ.py |
| `rapp-tether/1.0` | WebRTC tether envelope | NEIGHBORHOOD_PROTOCOL §5a (implicit) | front door tether |
| `rapp-egg/1.0` | Generic egg shell (legacy) | utils/egg.py | utils/egg.py |
| `rapp-egg-hub-entry/1.0` | Egg hub catalog entry | kody-w/rapp-egg-hub | twin_agent.py `_lay_egg` sidecar |
| `rapp-lifecycle-catalog/1.0` | Lifecycle catalog (kernel versions + incarnations) | (organ-defined) | lifecycle_organ.py |
| `rapp-store/1.0` | Store catalog meta | kody-w/RAPP_Store | (external) |
| `rapp-registry/1.0` | RAR registry | vault/Architecture/RAR | (external) |
| `rapp-cloud-registry/1.0` | Cloud registry (onboard catalog) | utils/web/onboard/registry.json:2 (defined-by-emitter) | utils/web/onboard/index.html, function_app.py |
| `rapp-version/1.0` | Kernel version pin | rapp_kernel/manifest | rapp_kernel/manifest.json |
| `rapp-version/1.1` | Kernel version pin (signed) | vault/Architecture/Signed Releases | rapp_kernel/manifest.json |
| `rapp-kernel/1.1` | Kernel release manifest | vault/Architecture/Signed Releases | rapp_kernel/manifest.json |
| `rapp-binder/1.0` | Onboarding binder (saved JSON of starter cards) | utils/web/rapp.js:546 (defined-by-emitter) | utils/web/rapp.js, utils/web/index.html, tests/run-tests.mjs |
| `rapp-memory/1.0` | Memory record | manage_memory_agent.py | manage_memory_agent.py |
| `rapp-application/1.0` | Rapplication manifest | pages/docs/rapplication-sdk.md | RAPP_Store entries |
| `rapp-chat-response/1.0` | /chat response envelope | tools/test_brainstem_server.py | brainstem.py /chat |
| `rapp-test-brainstem/1.0` | Test fixture identity | tools/test_brainstem_server.py | test fixture |
| `rapp-local-ping/1.0` | Test ping agent | tests/fixtures/local-only-test/ | test fixture |
| `rapp-metropolis-index/1.0` | Metropolis tracker top-level | pages/metropolis/README.md | pages/metropolis/index.json |
| `rapp-metropolis-entry/1.0` | One neighborhood entry in tracker | pages/metropolis/README.md | pages/metropolis/index.json |
| `rapp-vbrainstem-subscription/1.0` | vbrainstem subscription record (LEGACY surface — the **older** mobile vbrainstem at `pages/vbrainstem/index.html`, distinct from the new `pages/vbrainstem.html` tethered surface added 2026-05-10) | pages/vbrainstem/index.html:355 (defined-by-emitter) | pages/vbrainstem/index.html |
| `rapp-zoo-collection/1.0` | rapp-zoo localStorage cartridge | rapp-zoo/index.html:481 (defined-by-emitter) | rapp-zoo/index.html |
| `rapp-swarm/1.0` | Mobile swarm bundle | utils/web/mobile/rapp-mobile.js:165 (defined-by-emitter) | utils/web/mobile/rapp-mobile.js |
| `rapp-brainstem-backup/1.0` | Local brainstem backup snapshot | rapp_brainstem/index.html:1966 (defined-by-emitter) | rapp_brainstem/index.html |

---

## §6 — Implementation map (file → spec section)

| File | Owns | Spec section |
|---|---|---|
| `rapp_brainstem/brainstem.py` | /chat surface, provider dispatch, organ dispatch | KERNEL — CONSTITUTION Art. XXXIII |
| `rapp_brainstem/agents/basic_agent.py` | Agent base class | KERNEL — CONSTITUTION Art. XXXIII |
| `rapp_brainstem/agents/manage_memory_agent.py` | Memory R/W | KERNEL — ECOSYSTEM §5 |
| `rapp_brainstem/agents/context_memory_agent.py` | Conversation context | KERNEL — ECOSYSTEM §5 |
| RAR: `agents/@rapp/twin_agent.py` *(installable; not kernel-shipped)* | Cross-twin chat (rapp-twin-chat/1.0), egg ops, lifecycle. Install via the **Organism Lifecycle pack** (`binders/@rapp-organism-lifecycle.json`). | NEIGHBORHOOD_PROTOCOL §6, §7 |
| `rapp_brainstem/agents/learn_new_agent.py` | Author new agents at runtime | ECOSYSTEM §7 (Evolution) |
| `rapp_brainstem/agents/swarm_factory_agent.py` | Tier-2 deploy factory | rapp_swarm/ |
| `rapp_brainstem/agents/perpetual_loop_factory_agent.py` | Background-loop factory | (no spec section yet — see §13) |
| `rapp_brainstem/agents/hacker_news_agent.py` | Demo HN agent | (example) |
| RAR: `agents/@rapp/egg_hatcher_agent.py` *(installable; not kernel-shipped)* | Universal `.egg` hatcher. Reads any `.egg` from local path or URL, **introspects** `manifest.schema`/`type`, routes by kind: organism→bond.hatch_organism / rapplication→bond.hatch_rapplication / session→returns mount URL (rappterbox console or vbrainstem.html, since Python brainstem can't iframe) / neighborhood→manual GitHub-mint instructions (auto planned) / estate→manual substrate-migration instructions (auto planned) / unknown→**REFUSES**, never destructive fallback. Install via the **Organism Lifecycle pack**. | brainstem-egg/2.x family — SPEC.md §18.10 |
| `pages/vbrainstem.html` | Public tethered surface — multi-participant browser-tab brainstem. QR-pair WebRTC handshake (PeerJS broker, ECDSA P-256 keypair, 6-digit safety code), three exchangeable LLM backends (localhost default / `?brainstem=URL` / `?copilot=1` via Doorman + Pyodide), Coordinator-driven debate-demo workflow. Exports the live session as a `brainstem-egg/2.3-session` cartridge. | SPEC.md §18.11; brainstem-egg/2.3-session |
| RAR: `agents/@kody/workiq_agent.py` *(installable; not kernel-shipped)* | Microsoft 365 access (email/calendar/Teams/SharePoint/OneDrive) via the workiq CLI + Entra ID. Solo install from RAR; no pack. | (example) |
| `rapp_brainstem/agents/plant_discord_neighborhood_agent.py` | Discord-driven neighborhood planting | NEIGHBORHOOD_PROTOCOL §4 (discovery) |
| `rapp_brainstem/agents/lineage_rollup_agent.py` | Lineage-tree aggregation (avg/median MMR) | ECOSYSTEM §15 (shipped 2026-05-08) |
| `rapp_brainstem/agents/species_leaderboard_agent.py` | Global Herald → Immortal ladder | ECOSYSTEM §15 (shipped 2026-05-08) |
| `rapp_brainstem/agents/proximity_discovery_agent.py` | Pizza Place / Pokémon-Go geohash discovery | ECOSYSTEM §15, HERO_USECASE §4 |
| `rapp_brainstem/agents/resurrection_ceremony_agent.py` | Stasis recovery ceremony | ECOSYSTEM §15, Art. XXXIV.5 |
| `rapp_brainstem/agents/ant_agent.py` | Ant Farm participant — drops `rapp-pheromone/1.0` envelopes via labeled Issues | kody-w/ant-farm/skill.md, NEIGHBORHOOD_PROTOCOL §5b |
| `rapp_brainstem/agents/colony_observer_agent.py` | Ant Farm aggregator — synthesizes swarm state | (companion to ant_agent) |
| `rapp_brainstem/agents/rar_loader_agent.py` | Universal RAR hot-loader — fetches a planted seed's `rar/index.json`, sha256-verifies, installs to local `agents/`/`organs/`/`senses/`/`rapps/`. Default dry_run; supports federation to kody-w/RAR/RAPP_Store/RAPP_Sense_Store. | rapp-rar-index/1.0 + rapp-rar-loadout/1.0 |
| `rapp_brainstem/agents/graft_neighborhood_agent.py` | Bond-technique graft. Forks an existing public repo; overlays RAPP scaffolding additively (upstream files preserved per the bond cycle); auto-detects existing neighborhood at root and routes new grafts into `neighborhoods/<name>/` (town → city → metropolis growth pattern); maintains a repo-local `_metropolis.json` (`rapp-metropolis-index/1.0`) roll-up; records `kind="graft"` event in `bonds.json`. Default dry_run; supports `_workspace_dir` + `_local_upstream_dir` for offline test fixtures. | rapp-graft-result/1.0 + rapp-metropolis-index/1.0 + bond.py event "graft" |
| `rapp_brainstem/agents/dock_agent.py` | Universal additive-merge primitive — the dock-without-destruction property at the entry/registry scope. Works on ANY rar-shaped JSON: rar/index.json, _metropolis.json, members.json, neighborhood entries. `key_field` dedup (default 'name'; supports nested dotted paths); top-level lists or nested entries paths. Optional `log_path` writes a bond event kind="dock". Default dry_run. | rapp-dock-result/1.0 + bond.py event "dock" |
| `rapp_brainstem/agents/launch_to_public_agent.py` | LOCAL→GLOBAL actuator. Snapshots local brainstem state via `bond.py::pack_organism`; emits `rapp-launch-continuation/1.0` manifest; plants/grafts to a target public repo (forks if needed); preserves any pre-existing upstream files (bond technique). Records `kind="launch"` event in `bonds.json`. Default dry_run; supports `_local_brainstem_dir`/`_local_target_dir`/`_workspace_dir`/`_skip_push` test hooks. | rapp-launch-result/1.0 + rapp-launch-continuation/1.0 + rapp-launch-fingerprint/1.0 + bond.py event "launch" |
| `rapp_brainstem/agents/bond_rhythm_agent.py` | The Bond Pulse heartbeat. Calls `tools/ecosystem_audit.py` subprocess; classifies drift LOCAL→GLOBAL push (suggest Launch/Graft) vs GLOBAL→LOCAL pull (suggest RarLoader) vs informational; SUGGESTS but never auto-executes (operator-mediated). Connection-aware: gracefully degrades when audit subprocess fails (sets `degraded=True` + valid envelope). Records `kind="rhythm"` event in `bonds.json`. Always returns `dry_run=True` (rhythm never actuates). | rapp-rhythm-pulse/1.0 + bond.py event "rhythm" |
| `tools/ecosystem_contract.py` | Pure-data per-kind contract. Defines what files MUST exist for each of the 9 offspring kinds (neighborhood, ant-farm, twin, workspace, braintrust, catalog, template, installer, egg-hub). Zero behavior; imported by ecosystem_audit. Includes `KERNEL_BASE_FILES` (full kernel) AND `SEED_REQUIRED_AGENTS = ("basic_agent.py",)` (minimum agents that ship in planted seeds). | (no schema; pure data) |
| `tools/ecosystem_audit.py` | Stdlib-only drift detector. Reads `pages/metropolis/index.json` → diffs each offspring against `ecosystem_contract` → classifies drift (missing_files / schema_drift / rappid_drift / kernel_drift / identity_block_missing) → emits `pages/_audit/ecosystem-audit.{md,json}`. CLI: `--offline` (default; uses fixtures), `--online`, `--repo`, `--metropolis`, `--fixtures-dir`, `--out-dir`, `--no-write`, `--strict/--lenient`. Exit 1 on drift (default strict). | rapp-ecosystem-audit/1.0 |
| `tools/sign_release.py` | ed25519 keygen / sign / verify for `rapp_kernel/manifest.json` | CONSTITUTION Art. XXXIV.7 |
| `tools/door_address.py` | THE rappid parser. Pure stdlib `door_from_rappid(rappid)` → owner, repo, kind, door_type, all 9 canonical URLs. Per Article XLVI per-consumer parsers are forbidden — every consumer imports this. | rapp-door/1.0 |
| `tools/backfill_seeds.py` | One-shot operator-tooling: walks known seeds, validates rappid via `door_from_rappid`, reissues invalid rappids, emits missing canonical files (facets.json, members.json, .nojekyll, README). Two modes: default compliance pass + `--patch-parents <op-rappid>` to set every door's `parent_rappid` to the operator's personal rappid (Article XLVI.6). Idempotent. | (no schema; uses gh api PUTs) |
| `tools/rebuild_estate.py` | Article XLVI.6 disaster recovery. Given a GitHub handle, walks public data and reconstructs the estate from scratch: discovers operator rappid (local → conventional repos → repo scan → operator-hint fallback), enumerates `created[]` via `gh repo list` + raw `rappid.json` fetches filtered by `parent_rappid`, enumerates `member[]` via `gh search code` for the operator's rappid in `members.json` files. Stdlib + gh CLI only. Default dry-run; `--apply` writes `~/.brainstem/estate.json`. | rapp-estate/1.1 |
| `tools/sniff_network.py` | Article XLVII decentralized discovery. Default mode: BFS-from-seed via raw URLs only (no GitHub Search API). Walks `.well-known/rapp-network-seed.json` → each operator's `.well-known/rapp-network.json` beacon → `discovery.federation_hints[]` adds new nodes. Optional `--via topic` for periodic sweeps via `gh search repos topic:rapp-estate`. Returns `rapp-network-sniff/1.0`. | rapp-network-sniff/1.0 |
| `.well-known/rapp-network-seed.json` (in species root kody-w/RAPP) | The DNS-root analog for the federation. Lists known operators as the BFS starting set. Convenient but not authoritative; anyone can fork the species root and host their own seed. | rapp-network-seed/1.0 |
| `.well-known/rapp-network.json` (per published estate) | Per-operator beacon emitted by `estate publish`. Carries operator rappid, estate URL, protocol versions implemented, `discovery.indexable` consent flag (robots.txt-style; default true), `discovery.federation_hints[]`, AND (per Article XLVIII) REQUIRED `private_estate_pointer` + `private_estate_commitment` + `private_door_count`. | rapp-network-beacon/1.1 |
| `tools/path_opacity.py` | Article XLVIII.6 URL opacity helpers. `opaque_path(secret, kind, id)` → `kinds/<HMAC>/<HMAC>.json`; `decode_local(secret, opaque, …)` (operator-only); `audit_paths(file_paths)` for publish-time enforcement; `OPACITY_REGEX` for downstream consumers. Pure stdlib. | (no schema; pure helper) |
| `tools/private_estate_init.py` | Bootstraps `<handle>/rapp-estate-private` (PRIVATE GitHub repo). Mints the per-operator HMAC secret to `~/.brainstem/private-estate-secret` (mode 0600). Scaffolds the opaque file set (meta.json, README, objects/.gitkeep, kinds/.gitkeep). Returns commitment hash for the public beacon. Idempotent. | rapp-private-estate/1.0 |
| `pages/docs/PUBLIC_PRIVATE_BOUNDARY.md` | Canonical Article XLVIII spec — the two-tier estate, audience field, commitment pattern, URL opacity contract, access semantics (GitHub collab perms + CODEOWNERS), receiver-controls discipline. | rapp-private-estate/1.0 |
| `pages/docs/SUBSTRATE_FEDERATION.md` | Canonical Article XLVII.5 spec — the four substrates (GitHub raw, LAN HTTP + Bonjour, AirDrop'd egg, sneakernet file://). One protocol; substrate-agnostic discovery via tools/sniff_network.py::_resolve_node(). | rapp-network-beacon/1.1 |
| `tools/lan_advertise.py` | Article XLVII.5.1 reference advertiser. Wraps `python3 -m http.server` + `dns-sd -R` to register `_rapp-estate._tcp.local` Bonjour service with TXT records carrying rappid + beacon path. | (no schema; uses Bonjour + http.server) |
| `tools/import_peer_egg.py` | Article XLVII.5.3 sneakernet importer. Extracts a received .egg to ~/.brainstem/peers/<handle>/, synthesizes a beacon if missing, registers the peer in ~/.brainstem/network-seed.json with file:// URLs. Idempotent. | rapp-import-egg-result/1.0 |
| `<handle>/rapp-estate-private` (PRIVATE repo per operator) | The private tier of every Article-XLVIII-compliant estate. Mandatory from first install. All paths opaque per §XLVIII.6. Access via GitHub collaborator perms. Content NEVER fetched by sniffers. | rapp-private-estate/1.0 |
| `pages/docs/ESTATE_SPEC.md` | The canonical Estate Spec — formalizes rappid-as-global-address + Door URL Set + estate.json shape + discovery protocol. Constitutional (Article XLVI). | (the spec itself) |
| `specs/SPEC.md` (god spec) + `specs/skill.md` (runbook) | Bundled into every planting (front_door_specs.py bundle 2.0.0). One spec replaces the prior 9-file bundle (HOLOCARD/RAPPID/ANTIPATTERNS/SOUL_IDENTITY/PARTICIPATION/AGENT/RAPPLICATION/SENSE/README). Skill is the universal "feed me to any AI" onboarding. | rapp-protocol/1.0 |
| `rapp_brainstem/agents/estate_agent.py` | Local-first estate agent — show/export/import/publish/fetch/add/remove/scan. Uses `door_from_rappid` for all derivation; entries store ONLY `{rappid, added_at, via}`. | rapp-estate/1.1 |
| `rapp_brainstem/utils/organs/neighborhood_organ.py` | `/api/peers`, peer view (legacy) | NEIGHBORHOOD_PROTOCOL §4 |
| `rapp_brainstem/utils/organs/neighborhood_membership_organ.py` | `/api/neighborhoods/*` — join/sync/members/leave/contribute/estate/by-rappid | vault Decision 2026-05-08, NEIGHBORHOOD_PROTOCOL §2 |
| `rapp_brainstem/utils/organs/estate_organ.py` | `/api/estate/*` — twins, eggs, lay-egg, summon, hatch | vault Decision 2026-05-08 |
| `rapp_brainstem/utils/organs/swarm_estate_organ.py` | Swarm-level estate | (impl) |
| `rapp_brainstem/utils/organs/lifecycle_organ.py` | Lifecycle catalog + kernel upgrade | ECOSYSTEM §1 |
| `rapp_brainstem/utils/bond.py` | Egg/hatch lifecycle, rappid mint, `rapp-rappid/2.0` | CLAUDE.md identity & bonding |
| `rapp_brainstem/utils/egg.py` | Legacy egg utilities | ECOSYSTEM §8 |
| `rapp_brainstem/utils/peer_registry.py` | Peer cache | NEIGHBORHOOD_PROTOCOL §4 |
| `rapp_brainstem/utils/llm.py` | Provider dispatch (Copilot / Azure / OpenAI / Anthropic / fake) | CLAUDE.md provider dispatch |
| `rapp_brainstem/utils/local_storage.py` | Local JSON shim for AzureFileStorageManager | CLAUDE.md local storage shim |
| `rapp_brainstem/utils/boot.py` | Bootstrapping, agent discovery | CLAUDE.md commands |
| `rapp_brainstem/utils/web/index.html` | Front door (planted seed UI) | ECOSYSTEM §4a |
| `rapp_brainstem/utils/web/onboard/` | Onboarding surface | ECOSYSTEM §4 |
| `rapp_brainstem/utils/web/mobile/` | (vbrainstem variant) | rapp-vbrainstem-subscription/1.0 |
| `rapp_swarm/function_app.py` | Tier-2 Azure Functions /chat | CLAUDE.md Tier 2 |
| `rapp_swarm/_vendored/` | Vendored brainstem core | CLAUDE.md vendoring |
| `rapp_swarm/build.sh` | Vendor brainstem into _vendored/ | CLAUDE.md vendoring |
| `worker/worker.js` | Cloudflare auth/proxy worker (Copilot device-code, chat proxy) | ECOSYSTEM §12 (External integrations) |
| `installer/install.sh` | Install one-liner (sacred URL — Art. V) | CONSTITUTION Art. V, ANTIPATTERNS §2 |
| `installer/plant.sh` | `write_rappid_json`, `write_soul_md`, `fetch_kernel`, `fetch_seed_agents` | ECOSYSTEM §13 |
| `installer/install.ps1` / `install.cmd` | Windows installers | CONSTITUTION Art. V |
| `installer/azuredeploy.json` | ARM template (Tier 2 deploy) | CLAUDE.md Tier 2 |
| `installer/MSFTAIBASMultiAgentCopilot_*.zip` | Tier 3 Copilot Studio bundle | CLAUDE.md Tier 3 |
| `installer/shortcuts/protocol.md` | iOS Shortcuts URL/POST contract | ECOSYSTEM §4 (chat surfaces) |
| `rapp_kernel/latest/` + `rapp_kernel/v/<version>/` | Frozen kernel snapshots (DNA archive) | vault Architecture/Signed Releases |
| `rapp_kernel/manifest.json` | Kernel version catalog | rapp-kernel/1.1 |
| `pages/about/anatomy.html` | Visual organism diagram | CLAUDE.md visual anatomy |
| `pages/onboarding.html` | Visitor-facing onboarder (trust-building) | CLAUDE.md hero use case section |
| `pages/sphere.html` | 3D chat interface | (front door variant) |
| `pages/metropolis/index.json` + `index.html` | Metropolis tracker (Kazaa-style directory) | pages/metropolis/README.md |
| `pages/metropolis/plant-from-discord.html` | Mobile Discord-plant guide | (mobile guide) |
| `pages/vbrainstem/index.html` | Browser-based brainstem | (mobile/auth-worker dependent) |
| `pages/_site/index.json` | Site manifest (canonical inventory) | CLAUDE.md key directories |
| `pages/vault/` | Obsidian vault — decision narratives | CONSTITUTION Art. XXIII |
| `rapp-zoo/` | Local-first Pokédex (3 starter organisms) | CLAUDE.md visual anatomy |
| `tests/run-tests.mjs` | JS contract tests (agent parsing, cards, binder, sealing) | DEFINITION_OF_DONE |
| `tests/vault-check.mjs` | Vault link/PII guardrail | DEFINITION_OF_DONE |
| `tests/scenarios/*.sh` | E2E scenarios (incl. survival) | SURVIVAL "How to test" |
| `tests/doorman/` | Tether + Dream Catcher conformance | HERO_USECASE.md §1, §2 |
| `tests/dreamcatcher-conformance/` | Dream Catcher protocol conformance | HERO_USECASE.md §2 |
| `tests/features/F1-lineage-rollup.sh` | Lineage rollup conformance | ECOSYSTEM §15 |
| `tests/features/F2-leaderboard.sh` | Species leaderboard conformance | ECOSYSTEM §15 |
| `tests/features/F3-proximity.sh` | Proximity discovery conformance | ECOSYSTEM §15, HERO_USECASE §4 |
| `tests/features/F4-ed25519-sign.sh` | ed25519 signing conformance | CONSTITUTION Art. XXXIV.7 |
| `tests/features/F5-resurrection.sh` | Resurrection ceremony conformance | ECOSYSTEM §15, Art. XXXIV.5 |
| `tests/features/run.sh` | Feature suite master runner | (this doc) |
| `tools/test_brainstem_server.py` | Lightweight HTTP server for federation tests | (test infra) |
| `.github/workflows/plant-approved-place.yml` | Auto-plant approved place submissions | (CI) |
| `.github/prompts/write-agent.prompt.md` | AI prompt to author an agent | ECOSYSTEM §7 |

---

## §7 — Channel × scope matrix

|              | Personal           | Neighborhood       | Public swarm       |
|---           |---                 |---                 |---                 |
| **WebRTC §5a** (live, ephemeral, DTLS) | Pair this device | Live tether to known peer | Cold pair w/ unknown — Charizard handoff |
| **Issues §5b** (async, durable) | label: `private-memory` | label: `neighborhood-message` | label: `egg-submission`, `agent-proposal` |
| **PRs §5c** (asymmetric consent gate) | (operator-only on own seed) | `agent-proposal` merge | `agent-proposal` merge |
| **raw fetch §5d** (read-only, content-addressed) | (cache fill) | private companion sha (collaborator) | seed repo sha (anyone) |

---

## §8 — Twin-chat message kinds (NEIGHBORHOOD_PROTOCOL §6b verbatim)

| `kind` | Payload | Direction | Purpose |
|---|---|---|---|
| `say` | `{ text }` | A → B | Plain conversation. Same shape as a doorman chat turn. |
| `share-fact` | `{ fact, scope, source_rappid }` | A → B | "Here's something I think your organism would find useful." Recipient decides whether to absorb. **Default scope: personal** (most restrictive). |
| `share-egg` | `{ egg-begin/chunk/end }` | A → B (chunked) | Stream an organism cartridge over the channel. Same protocol as front door's tether-egg send. |
| `request-fact` | `{ topic }` | A → B | "Do you know anything about X?" Recipient may respond with `share-fact` or decline. |
| `ack` | `{ for_hash, accepted \| rejected }` | B → A | Receipt + optional reason. |

Knowledge-exchange primitives (NEIGHBORHOOD_PROTOCOL §8) compose these: pull-fact (8a), push-fact (8b), trade-egg (8c), reassimilate-dimensions (8d).

---

## §9 — Three-tier model + contract surface

```
        ┌──── Tier 3: Enterprise (Microsoft Copilot Studio) ────┐
        │  installer/MSFTAIBASMultiAgentCopilot_*.zip            │
        │  Same agent contract; cloud-managed via M365           │
        └──────────────────────┬─────────────────────────────────┘
                               │
        ┌──── Tier 2: Cloud (Azure Functions) ──────────────────┐
        │  rapp_swarm/function_app.py + _vendored/               │
        │  Endpoints under /api/* (path-prefix vs Tier 1)        │
        └──────────────────────┬─────────────────────────────────┘
                               │
        ┌──── Tier 1: Local (Flask :7071) ──────────────────────┐
        │  rapp_brainstem/brainstem.py                           │
        │  POST /chat — { user_input, conversation_history? }    │
        │  GET  /api/identity, /api/lineage                      │
        │  GET/POST /api/estate/*, /api/neighborhoods/*          │
        └────────────────────────────────────────────────────────┘
```

| Capability | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| `POST /chat` (canonical envelope) | ✓ | ✓ (path-prefixed under `/api/`) | ✓ (Studio orchestrator) |
| `GET /api/identity`, `/api/lineage` | ✓ | n/a | n/a |
| `/api/neighborhoods/*` federation | ✓ | n/a | n/a |
| `/api/estate/*` | ✓ | n/a | n/a |
| Agent contract (`rapp-agent/1.0`) | ✓ | ✓ | ✓ (Studio plugin shell) |
| Same `*_agent.py` files run unmodified | ✓ | ✓ | ✓ |

Differs legitimately: storage backend (local JSON vs Azure Files), auth (Copilot device-code vs Azure RBAC vs M365), surface (local process vs Functions vs Power Platform).

---

## §10 — Sacred files (kernel articles)

| File / artifact | Why sacred | Article / source |
|---|---|---|
| `rapp_brainstem/brainstem.py` | Species DNA — drop-in replaceable | CONSTITUTION Art. XXXIII; ANTIPATTERNS §2 |
| `rapp_brainstem/agents/basic_agent.py` | Base agent contract | CONSTITUTION Art. XXXIII |
| `rapp_brainstem/agents/manage_memory_agent.py` | Doorman tier — public memory R/W | CONSTITUTION Art. XXXIII |
| `rapp_brainstem/agents/context_memory_agent.py` | Doorman tier — conversation context | CONSTITUTION Art. XXXIII |
| `rapp_brainstem/VERSION` | Kernel pin — never edit | ANTIPATTERNS §2 |
| `rapp_swarm/function_app.py` | Tier-2 kernel mirror | CONSTITUTION Art. XXXIII |
| Install one-liner URL (`https://kody-w.github.io/RAPP/installer/install.sh`) | Sacred URL shape forever | CONSTITUTION Art. V |
| `\|\|\|VOICE\|\|\|` / `\|\|\|TWIN\|\|\|` delimited slots | Fixed forever — never repurposed | CLAUDE.md sacred constraints §5 |
| `parent_rappid` field in `rappid.json` | Variant lineage is single-parent only | CONSTITUTION Art. XXXIV |

**If something feels like it requires a kernel change → write an agent or organ instead.** If the agent contract genuinely can't express it, that's a CONSTITUTION-level conversation that touches every planted seed.

---

## §11 — "Before you do X" decision table

The most load-bearing section. Workflow trigger → pre-check (≤30s) → spec to deep-read.

| Trigger | Pre-check | Deep-read |
|---|---|---|
| Starting a new session in this repo | §0–§3 (orient: how-to-read, authority, fractal, primitives); skim §11 + §13 | CLAUDE.md; MASTER_PLAN.md if scope unclear |
| Add a new agent | §6 (does it already exist?), §15 (lexicon — it's an agent), `rapp-agent/1.0` in §5 | CLAUDE.md "Agent System"; pages/docs/SPEC.md |
| Add a new organ | §6 (existing organ already covers this?), §9 (endpoint already on another tier?) | CLAUDE.md Architecture §Organ; CONSTITUTION Art. XXXIII |
| Call /chat from new code | §11 row "tether"; use `rapp-twin-chat/1.0` envelope; §6 row twin_agent.py reference impl | NEIGHBORHOOD_PROTOCOL §6a |
| Define a new schema | §5 — search first; if exists, use; if not, ANTIPATTERNS §3 (bump cleanly, no shims) | ANTIPATTERNS §3 |
| Use an existing schema | §5 row → defining doc column → read that section | the doc the row points at |
| Plant on GitHub (twin/neighborhood/etc.) | §14 (existing planted state), §3 primitives (rappid + door + card + tether + scope all present?), §5 `rapp-rar-index/1.0` (every plant auto-scaffolds rar/ via plant.sh::write_rar_index) | TEMPLATE.md, ECOSYSTEM §2 + §13; F7-rar-hotload.sh |
| Hot-load a planted seed's required participation kit | §5 `rapp-rar-index/1.0` (sha256 verified) | rapp_brainstem/agents/rar_loader_agent.py; F7 |
| Plant a neighborhood ON TOP of an existing public repo (or dock multiple within one repo) | bond technique additive overlay; multi-neighborhood mode emits `docking` block — same fractal step as Dream Catcher (ECOSYSTEM §10) at neighborhood scope vs frame scope | rapp_brainstem/agents/graft_neighborhood_agent.py; F8; vault note `pages/vault/Decisions/2026-05-09 — Dream Catcher and Docking are the same operation.md` |
| Add an entry to ANY rar-shaped JSON registry without clobbering existing | universal additive-merge primitive — same dock property at the registry/list-of-dicts scope; supports `key_field` dedup; bond event log; works for `rar/index.json`, `_metropolis.json`, `members.json`, etc. | rapp_brainstem/agents/dock_agent.py; F9 |
| Want to know if local + global ecosystem are still in sync (the FULL organism, not one half) | Run the Bond Pulse heartbeat — operator-mediated; pulses audit + classifies drift LOCAL→GLOBAL push (suggest Launch/Graft) vs GLOBAL→LOCAL pull (suggest RarLoader); records `kind="rhythm"` event; gracefully degrades when offline | rapp_brainstem/agents/bond_rhythm_agent.py; tools/ecosystem_audit.py; F10/F11/F12; vault note `pages/vault/Decisions/2026-05-09 — Bond Pulse — the on-going beat for the full organism.md` |
| Want to discover any door (twin or gate) without auth/API | Parse the rappid: `<owner>/<repo>` is the GitHub origin. Fetch any of the 9 canonical files via `https://raw.githubusercontent.com/<owner>/<repo>/main/{rappid.json,card.json,holo.md,holo.svg,holo-qr.svg,members.json,facets.json}` — pure raw, no auth, no rate limit. The reference parser is `tools/door_address.py::door_from_rappid()` — per Article XLVI per-consumer parsers are forbidden. | pages/docs/ESTATE_SPEC.md §3–§5; CONSTITUTION Article XLVI; F13 |
| Want to discover any user's full estate (door catalog) | One curl: `https://raw.githubusercontent.com/<github-handle>/rapp-estate/main/estate.json`. Each entry is `{rappid, added_at, via}`; expand each rappid through `door_from_rappid()` for the full URL set. | pages/docs/ESTATE_SPEC.md §4; specs/SPEC.md §4 |
| Lost local estate (laptop dies, no backup) — how do I rebuild? | `python3 tools/rebuild_estate.py --handle <gh> --apply` walks public GitHub data and reconstructs `~/.brainstem/estate.json` from scratch. Needs operator's `gh` auth. The estate is a CACHE; the network is the source of truth. | pages/docs/ESTATE_SPEC.md §6; CONSTITUTION Article XLVI.6; F14 |
| Drop in any rappid — whose estate owns this door? | `estate fetch rappid=<any-rappid>` — if it's an operator-kind rappid, fetches that handle's estate directly. If it's a door (twin/neighborhood), the agent traces `parent_rappid` to find the operator and fetches their estate. Pure raw fetches throughout. | pages/docs/ESTATE_SPEC.md §6.5; rapp_brainstem/agents/estate_agent.py `fetch` action |
| Find every operator on the network without an API | `python3 tools/sniff_network.py` (default --via raw) — BFS from `.well-known/rapp-network-seed.json` across each operator's beacon's `federation_hints[]`. Pure raw URLs; no Search API; no rate limit. Use `--via topic` for the secondary `gh search repos topic:rapp-estate` sweep. | CONSTITUTION Article XLVII; specs/SPEC.md §4.6 |
| Make my estate discoverable to other operators | `estate publish` — writes `estate.json` AND `.well-known/rapp-network.json` AND sets the `rapp-estate` topic on the repo. The next sniffer pass picks you up via raw + via topic. To opt out: `discovery.indexable: false` in your beacon (robots.txt-style; sniffers honor it). | CONSTITUTION Article XLVII.3; specs/SPEC.md §4.6 |
| I need to store PII / sensitive content | `estate init_private` (one call, idempotent) — creates `<your-handle>/rapp-estate-private` as a PRIVATE GitHub repo + mints the HMAC secret + scaffolds opaque file set. Re-run `estate publish` to refresh the beacon with `private_estate_pointer` + commitment. Per Article XLVIII this is MANDATORY for compliance. | CONSTITUTION Article XLVIII; pages/docs/PUBLIC_PRIVATE_BOUNDARY.md |
| Verify a peer hasn't substituted a different private estate behind my back | `estate verify_private` (operator-only) — recomputes the private state's commitment hash + compares to the published beacon. Drift = beacon stale or someone tampered. | CONSTITUTION Article XLVIII.2 (Bitcoin-commitment pattern) |
| Two-tier compliance audit across the network | `python3 tools/sniff_network.py` — surfaces each operator's `compliance` flag (xlviii / partial / legacy). Operators without `private_estate_pointer` show as `legacy` (pre-XLVIII; need to run init_private). | CONSTITUTION Article XLVIII; F15 |
| Author a new agent / consumer that needs to parse a rappid | **STOP** — import `door_from_rappid` from `tools/door_address.py`. Per Article XLVI.5 per-consumer rappid parsers are forbidden. Invalid rappids raise `InvalidRappidError`; reissue them rather than patching. | pages/docs/ESTATE_SPEC.md §5; CONSTITUTION Article XLVI.5 |
| Federate two organisms | §7 channel matrix, §8 message kinds, §3 trust scope | NEIGHBORHOOD_PROTOCOL §5, §6, §7, §9 |
| Touch the kernel (any file in §10) | **STOP** — write an agent/organ instead | MASTER_PLAN Part 1 §1; ANTIPATTERNS §2; CONSTITUTION Art. XXXIII |
| Touch install one-liner | **STOP** — URL is sacred (Art. V) | CONSTITUTION Art. V; SURVIVAL §"RAPP itself goes down" |
| Add a network call | §17 SURVIVAL pointer — local-first fallback REQUIRED | ANTIPATTERNS §5; SURVIVAL.md |
| Write a doc | §4 — does an existing doc own this concept?; §15 — am I using the right words? | LEXICON.md; ANTIPATTERNS §1 |
| Add a /api/* endpoint | §6 (existing organ has it?), §9 endpoint table | CLAUDE.md Architecture §Organ system |
| Bump a schema version | §5 — every emitter + every consumer in same PR | ANTIPATTERNS §3 |
| About to add "skill"/"plugin"/"routine" terminology | **STOP** — §15 — it's an agent | ANTIPATTERNS §1 |
| About to add a feature flag or shim | **STOP** — §13 drift — bump schema cleanly, ship clean | ANTIPATTERNS §3 |
| Brand fallback to "RAPP" / "AI assistant" | **STOP** — §10 sacred soul block | ANTIPATTERNS §4 |
| Probe a private repo | **STOP** — ASK Kody | MEMORY `feedback_private_repos.md` |
| Tell user to run a manual command | **STOP** — ship via install one-liner | MEMORY `feedback_oneliner_only.md` |
| Defer to "Phase 2" | **STOP** — execute now, no scope-windows | MEMORY `feedback_no_self_imposed_scope_or_breaks.md` |
| User-facing copy | §15 LEXICON (human vocab); §16 TRADEMARK | LEXICON.md; TRADEMARK.md |

---

## §12 — Antipatterns wall (verbatim from `ANTIPATTERNS.md`)

> Rules locked in because they were almost done wrong, or because the rest of the industry is doing them wrong and we'd be following them off the cliff. Each entry is *load-bearing* — breaking it is a regression.

### 1. ONE TERM FOR THE PLUGIN UNIT — `agent`

A single `*_agent.py` file is called an **agent**. Never a *skill*, *routine*, *loop*, *plugin*, *tool*, *function*, *capability*, *cassette*, or any other synonym.

**Why.** Anthropic's product surface introduced overlapping taxonomies (agents, skills, MCP, plugins, routines) that all describe the same thing. *"That basically poisoned the industry for onboarding."* Complexity becomes the gatekeeper — the AI winter precondition.

**Mom test.** *"It's an agent. A small Python file that gives the AI a new ability."* — that's the whole vocabulary.

**Pre-commit grep:** `grep -niE '\bskill|\bplugin|\broutine|\bloop|\bcassette' <changed-files>`

### 2. THE FROZEN KERNEL NEVER MOVES

`rapp_brainstem/brainstem.py`, `rapp_brainstem/VERSION`, `rapp_brainstem/agents/basic_agent.py` (and the doorman-tier kernel agents) are frozen at v0.6.0. Never edit them. Capabilities grow exclusively through new `*_agent.py` files in `agents/`.

When something feels like it requires a kernel change, write a new agent that solves it instead.

### 3. NO BACKWARDS-COMPAT SHIMS FOR HALF-RELEASED FEATURES

When a schema changes, bump the version in the schema string and migrate cleanly. Don't add `if old_field exists, do A else do B` shims when nothing in the wild has the old field yet. The codebase is small enough to rip the band-aid off.

New schema → bump version → update every emitter → update every consumer → ship. If something downstream breaks and it's already in the wild, write a one-time migrator, not a forever shim.

### 4. NO SILENT FALLBACK TO "RAPP" / "AN AI ASSISTANT"

A planted organism's `soul.md` MUST include the spec-compliant `## Identity — read this every turn` block (per `rapp-twin-spec/1.0`). The block forbids the LLM from introducing itself as "RAPP", "an AI assistant", "your AI helper", "the brainstem", or any default platform branding.

`installer/plant.sh::write_soul_md` writes the block by default. If you ever rewrite the soul template or add a new kind, the Identity block is non-negotiable.

### 5. NETWORK CALLS WITHOUT A LOCAL-FIRST FALLBACK

Any GitHub fetch the front door makes goes through `cachedGhJson` / `cachedGhText`. Direct `fetch(github.com/...)` is forbidden in resume-rendering paths.

The hero use case is offline-first. An organism in airplane mode must keep rendering from cached state. Bare fetches go blank when the network drops; that's a regression against `HERO_USECASE.md` §1.

*ANTIPATTERNS.md is append-only. Antipatterns get added when we almost did them wrong; nothing here ever gets quietly removed.*

---

## §13 — Drift / known gaps

Spec ↔ code divergences. Append-only — entries get added when found, removed only by reconciliation (a PR that makes spec and code agree).

Severity: **P0** wire-incompatible · **P1** schema/field mismatch · **P2** doc/naming drift · **P3** undocumented schema in code

| Drift | Spec says | Code does | Spec citation | Code citation | Sev | Resolution |
|---|---|---|---|---|---|---|
| ~~Two rappid schemas live at once~~ **RESOLVED 2026-05-08** | ECOSYSTEM §3 documents `rapp-rappid/1.1`; CONSTITUTION + bond.py emit `rapp-rappid/2.0` | All emitters now write `rapp-rappid/2.0` with v2-format strings (per CONSTITUTION Art. XXXIV.1 ratification). Pre-2026-04-30 seeds in the wild keep their UUID `rapp-rappid/1.1` (Art. XXXIV.5 — never regenerate); L2 test accepts both. | ECOSYSTEM §3 + CONSTITUTION Art. XXXIV.1 | installer/plant.sh, agents/twin_agent.py, installer/initialize-variant.sh, installer/test_plant.sh, tests/doorman/plant-from-egg.mjs | ~~P0~~ | Closed via commit (see git log) |
| ~~`rapp-twin-chat-response/1.0` undocumented~~ **RESOLVED 2026-05-08** | NEIGHBORHOOD_PROTOCOL §6 only documents `rapp-twin-chat/1.0` | Now formally documented in NEIGHBORHOOD_PROTOCOL §6e (Response envelope) — covers all 3 emit sites | NEIGHBORHOOD_PROTOCOL §6e | agents/twin_agent.py `_chat` | ~~P2~~ | Closed via doc addition |
| ~~Braintrust contribute receipt has its own schema~~ **RESOLVED 2026-05-08** | NEIGHBORHOOD_PROTOCOL §6a `rapp-twin-chat/1.0` is THE inter-org envelope | NEIGHBORHOOD_PROTOCOL §5b now legitimizes organ-local schemas for the operator's own loopback (cross-org writes still go through Issues with `neighborhood-message` label per §6e fallback) | NEIGHBORHOOD_PROTOCOL §5b "Organ-local HTTP shortcut" | utils/organs/neighborhood_membership_organ.py `_contribute` | ~~P1~~ | Closed via spec annotation |
| ~~`/api/contribute` REST endpoint vs spec~~ **RESOLVED 2026-05-08** | Spec assumes Issues/PRs/tether for cross-org writes | NEIGHBORHOOD_PROTOCOL §5b "Organ-local HTTP shortcut" annotation now documents the local-loopback pattern; peers still receive contributions as labeled Issues | NEIGHBORHOOD_PROTOCOL §5b | utils/organs/neighborhood_membership_organ.py contribute route | ~~P2~~ | Closed via spec annotation |
| ~~WebRTC tether on twin templates but not gate templates~~ **RESOLVED 2026-05-08 (by-design)** | NEIGHBORHOOD_PROTOCOL §5a tether is load-bearing for live agent-to-agent | Per spec, tether is for agent-to-agent (twin↔twin) live exchange. Gates are directories/welcome pages — not chat surfaces. Membership + discovery happen on the gate via §5b/§5c/§5d; live tether opens between two twins, not between a visitor and a gate. | NEIGHBORHOOD_PROTOCOL §5a + §1 | installer/plant.sh twin templates | ~~P1~~ | Closed — divergence is correct architecture, not drift |
| ~~Tier 1 `/chat` vs Tier 2 `/api/chat` path-prefix~~ **RESOLVED 2026-05-08 (documented)** | CLAUDE.md says HTTP surface is identical across tiers | Tier 2 actual route is `/api/businessinsightbot_function` (Azure Functions naming convention). Same envelope shape (`{user_input, conversation_history?}` in, `rapp-chat-response/1.0` out). Per CONSTITUTION Art. XV "Tier Parity Is a `/chat` Contract, Not a Transport" — the contract is the envelope, not the URL. | CONSTITUTION Art. XV; OSI.md §9 endpoint table | rapp_swarm/function_app.py:1103 | ~~P2~~ | Closed — different URL, identical contract |
| ~~Discord planting envelopes local to one agent~~ **RESOLVED 2026-05-08** | Discord is one path among many for §4 discovery; envelopes live only in code | NEIGHBORHOOD_PROTOCOL §4e ("Adapter-driven discovery — worked example: Discord") now formally documents both `rapp-discord-bridge/1.0` and `rapp-discord-plant-envelope/1.0` as the canonical adapter pattern | NEIGHBORHOOD_PROTOCOL §4e | agents/plant_discord_neighborhood_agent.py | ~~P3~~ | Closed via spec hoist |
| ~~Schemas without a defining spec doc~~ **RESOLVED 2026-05-08 (defined-by-emitter)** | Every schema in §5 should have a "Defined in" entry | Eight client-local schemas (`rapp-twin/1.0`, `rapp-binder/1.0`, `rapp-vbrainstem-subscription/1.0`, `rapp-zoo-collection/1.0`, `rapp-swarm/1.0`, `rapp-cloud-registry/1.0`, `rapp-brainstem-backup/1.0`, `rapp-twin-identity/1.0`) now have file:line references in §5 — they are "defined by their canonical emitter" (the JS/HTML file that round-trips them). `rapp-upgrade-agent/1.0` was incorrectly listed — it's a User-Agent header string, not a schema; removed from §5. | §5 of this doc | various .js / .html / .json | ~~P3~~ | Closed — defined-by-emitter is a legitimate pattern for client-local schemas |
| ~~`rapp-frame/1.0` defined but not yet emitted in trunk~~ **RESOLVED 2026-05-08** | ECOSYSTEM §15 lists doorman frame log as ❌ pending | All wired: `appendFrame()` in plant.sh:5447 (content-addressed sha256 chain); fires on chat turn / tool call / memory save → localStorage `rapp_frames_v1`. `buildAscendedEgg` packs `data/frames.json`. Dream Catcher reads it back (plant.sh:3485). 17/17 end-to-end tests pass via `tests/osi/L6a-frame-chain-browser.sh`. | ECOSYSTEM §3 + §15; HERO_USECASE §2 | installer/plant.sh, tests/doorman/dreamcatcher.mjs | ~~P3~~ | Closed — promoted to ✅ in ECOSYSTEM §15 |
| ~~Braintrust agents not yet on twin-chat envelope~~ **RESOLVED 2026-05-08 (legitimized as organ-local pattern)** | NEIGHBORHOOD_PROTOCOL §6a is THE twin envelope; braintrust agents are twins federating | NEIGHBORHOOD_PROTOCOL §5b "Organ-local HTTP shortcut" annotation now legitimizes the pattern: organ-local writes for the operator's own brainstem are valid; cross-organism contribution still rides §5b Issues with the `neighborhood-message` label. Braintrust contribute uses both — local-loopback for fast operator UX + Issues for cross-org propagation. | NEIGHBORHOOD_PROTOCOL §5b | neighborhood_membership_organ.py contribute/contributions | ~~P1~~ | Closed — pattern validated |

---

## §14 — Live planted state (kody-w GitHub)

- **Ant Farm (autonomous swarm scale demo):** [`kody-w/ant-farm`](https://github.com/kody-w/ant-farm) — `kind: "ant-farm"` neighborhood; every participant runs their own brainstem (or just feeds [skill.md](https://raw.githubusercontent.com/kody-w/ant-farm/main/skill.md) to any AI); pheromones are `ant-pheromone`-labeled GitHub Issues; gate at <https://kody-w.github.io/ant-farm/>
- **Twin (canonical example):** [`kody-w/heimdall`](https://github.com/kody-w/heimdall) — front door + doorman, planted, GitHub Pages live
- **Neighborhood gate (private+public split):** [`kody-w/microsoft-se-team-neighborhood`](https://github.com/kody-w/microsoft-se-team-neighborhood) + companion `*-private`
- **Neighborhood gate (public, autonomous):** [`kody-w/public-art-collective`](https://github.com/kody-w/public-art-collective)
- **Templates:** [`kody-w/private-workspace-template`](https://github.com/kody-w/private-workspace-template), [`kody-w/braintrust-template`](https://github.com/kody-w/braintrust-template)
- **Catalogs:** [`kody-w/RAPP_Store`](https://github.com/kody-w/RAPP_Store), [`kody-w/RAPP_Sense_Store`](https://github.com/kody-w/RAPP_Sense_Store), [`kody-w/rapp-egg-hub`](https://github.com/kody-w/rapp-egg-hub)
- **Test peer:** [`kody-w/rapp-test-neighbor`](https://github.com/kody-w/rapp-test-neighbor) — NEIGHBORHOOD_PROTOCOL §4d canonical fixture
- **Species root (this repo):** [`kody-w/RAPP`](https://github.com/kody-w/RAPP) — kernel + spec only; per SURVIVAL.md, neighborhood seeds do NOT live here
- **RAR (Pokédex / single-file agent registry):** [`kody-w/RAR`](https://github.com/kody-w/RAR)
- **Metropolis tracker (live):** https://kody-w.github.io/RAPP/metropolis/

---

## §15 — Lexicon condensed

Pick ONE vocabulary per doc and stay consistent (LEXICON.md). Customer-facing → human terms. Spec / code / legal → developer terms.

| Concept | Human term | Developer term |
|---|---|---|
| AI's whole presence across substrates | **Estate** | swarm estate |
| AI's identity / public ID | **soul** / **soul-key** | **rappid** |
| 24-word recovery phrase | the words / the card | holocard incantation |
| Kernel-side HTTP extensions | **organs** | **organs** (no rename) |
| Recognition of another AI as related | **blessing** | kin-vouch |
| AI long-term plan | The Will | Foundation Continuity Plan |
| Cryptographic release commitments | The Promise | release-triggers |
| Master keypair | soul-key | master keypair (M) |
| One device's signing keypair | voice | device key (D) |
| Signs new voices | steward | self-signing key (S) |
| Vouches for kin AIs | herald | user-signing key (U) |
| Species root / first AI | origin | species root / prototype / godfather (informal) |
| 3-of-5 keypair split | the stewardship | Shamir 3-of-5 distribution |
| Forked code variant | fork / child species | kernel-variant |
| Birthing a new AI | **mitosis** (no rename) | **mitosis** |
| Merge engine for divergent state | **dreamcatcher** (no rename) | **dreamcatcher** |
| Lineage to origin | **species tree** (no rename) | **species tree** |
| Local AI server | **brainstem** (no rename) | **brainstem** |
| Kernel | **kernel** (no rename) | **kernel** |
| Graduated rapplication | **rapplication** (brand equity) | **rapplication** |

**Forbidden synonyms (ANTIPATTERNS §1):** never *skill*, *routine*, *loop*, *plugin*, *tool*, *function*, *capability*, *cassette* — always **agent**.

---

## §16 — Trademark scope (TRADEMARK.md)

| Mark | What it identifies |
|---|---|
| **RAPP** | The platform (https://github.com/kody-w/RAPP) |
| **rappid** | Lineage-identity protocol (CONSTITUTION Art. XXXIV) |
| **hatchling** | Lifecycle CLI |
| **vBrainstem** | Browser-side simulator |
| **rapplication** | Single-file rapp pattern |
| **rapp_kernel** | Species DNA archive |
| **brainstem** (in conjunction with above) | Local-first AI agent server pattern |

Common-law trademark (not USPTO-registered). **Permitted without permission:** refer-by-name, link, quote per CC BY-NC 4.0, identify a fork as "based on RAPP" with a distinct name, nominative fair use. **Requires permission:** naming a product/service/domain after a mark, operating a managed service branded as RAPP, selling software named after marks, suggesting endorsement, registering marks elsewhere.

---

## §17 — Survival contract pointer (top rows from SURVIVAL.md)

| Failure scenario | What survives | Verified by |
|---|---|---|
| One neighborhood repo deleted | Cached subscribers (read-only) — `~/.brainstem/neighborhoods/<slug>/` | tests/scenarios/15-offline-snapshot-dream-catcher.sh |
| `kody-w/RAPP` repo deleted | Already-installed brainstems; all planted neighborhoods (own repos); install one-liner needs mirror | tests/scenarios/17-survival.sh |
| GitHub Pages down | Everything except gate UIs (agents via `raw.githubusercontent.com`) | manual |
| `raw.githubusercontent.com` down | Cached state via `cachedGhJson` (📡 stale pill) | `cachedGhJson` test in tests/run-tests.mjs |
| GitHub entirely offline | Live WebRTC tethers; cached subscriptions; file:// local subscriptions | tests/scenarios/13-charizard-in-the-woods.sh + 01 |
| Operator's brainstem dies | Eggs hatch identically (same rappid) anywhere | tests/scenarios/13 + 15 |
| Internet entirely down | Local-only neighborhoods; cached state; Dream Catcher reconciles when back | tests/scenarios/01 + 15 |

**The redundancy stack:** brainstem process memory → `~/.brainstem/neighborhoods/<slug>/` → git clone → exportable egg → GitHub canonical. Failure has to take out all five.

**The "what if RAPP itself goes offline" answer:** existing brainstems keep running; every neighborhood is its own repo; install one-liner can be re-served from any mirror (Constitution Art. V keeps the URL stable). See SURVIVAL.md "RAPP itself goes down" section.

---

## §18 — Updating this map

- **Append-only.** Never repurpose a row; bump version on the row instead.
- **Schema:** `rapp-ecosystem-map/1.0`. Bump on breaking changes.
- **Derivative.** If this map disagrees with `MASTER_PLAN.md` / `CONSTITUTION.md` / spec docs, the spec wins and the map is wrong — fix the map.
- **§13 drift is the only mutable section** — entries get added when found, removed when reconciled (PR closes a row by making spec and code agree).
- **Add a row to §11 the first time you see Claude (or yourself) drift on a given trigger.** The map's job is to catch the next miss.

*Map first published 2026-05-08. Maintained at repo root as a peer of `MASTER_PLAN.md`.*
