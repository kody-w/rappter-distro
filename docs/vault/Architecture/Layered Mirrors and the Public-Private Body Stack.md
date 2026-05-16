---
title: Layered Mirrors and the Public/Private Body Stack
status: published
section: Architecture
hook: One frozen kernel, an unbounded tree of mirrors, and a body stack with three memory tiers and two agent tiers — the whole pattern resolves through one URL, one OAuth flow, and one rule (the kernel never changes). Silent escalation does the rest.
---

# Layered Mirrors and the Public/Private Body Stack

> **Hook.** One frozen kernel, an unbounded tree of mirrors, and a body stack with three memory tiers and two agent tiers — the whole pattern resolves through one URL, one OAuth flow, and one rule (the kernel never changes). Silent escalation does the rest.

## Why this exists

Most "AI infrastructure" picks a side. A SaaS picks central control + uniform UX, and you live inside their walls. A self-hosted tool picks local autonomy, and you give up the network effects. A public chatbot picks anonymous reach, and you give up identity-bound depth.

This stack picks all three at once, layered. The kernel is identical everywhere — frozen at v0.6.0 in the grail repo, byte-for-byte the same in any planted mirror, on any device, in any browser. The body grows differently for every operator and presents differently to every visitor based on what GitHub will let their token read. Owned forever, scales universally, on-device and off, public and private.

This note is the spec. The other notes ([[Mirror Spec]], [[The Front Door]], [[The Engine Stays Small]]) are the parts; this is how they compose.

## The decision

Three structural choices, taken together, are what make the stack work:

1. **The kernel is a frozen game-console BIOS.** v0.6.0 of `kody-w/rapp-installer/rapp_brainstem/brainstem.py` is the species DNA. Any planted mirror's kernel files are byte-identical to grail's. The kernel never changes — agents do. See [[Mirror Spec]] for the byte-equality contract.
2. **Lineage is recursive.** A mirror's `rappid.json.parent_rappid` points at *whichever ancestor it was planted from* — could be grail directly, could be another mirror that itself descends from grail, could be three or four hops. Every chain terminates at the species root rappid `0b635450-c042-49fb-b4b1-bdb571044dec`. See [[Federation via RAR]] for the trust shape; this note focuses on the lineage / mutation tree.
3. **The body has tiered access.** Same URL, same OAuth flow, same fetch shape — the visitor sees a different surface depending on what their GitHub token can read. Anonymous gets the doorman; authenticated-with-private-access gets the full ascended twin. The escalation is silent (a 404 vs a 200) and invisible.

## The metaphor stack, in one table

| Layer | Code | Real-estate metaphor | Biological metaphor |
|---|---|---|---|
| Grail kernel | `rapp_brainstem/brainstem.py` v0.6.0 | Building code (same in every house) | Species DNA (same in every cell) |
| Mirror | A planted GitHub repo with byte-identical kernel | A house at an address | An organism with shared DNA |
| Front door | The mirror's `/index.html` page | Threshold — visitors arrive here | Phenotype — outward presentation |
| Doorman | `/doorman/` chat surface, default persona | Greeter at the door | Public-facing voice |
| Ascended twin | Same `/doorman/`, when private soul.md is reachable | The owner inside the house | Full voice with private memory |
| Public memory | `<seed>/.brainstem_data/memory.json` (raw URL) | Shared bulletin board | Public ledger |
| Per-user memory | Issues in `<private_companion>` filtered by creator | Mailbox for one named visitor | Personal journal, gated |
| Device memory | `localStorage` on the visitor's browser | Sticky notes on their own desk | Ephemeral cache, per-host |
| Bond cycle | egg → overlay → hatch | Renovation that swaps the foundation back | Mitosis with fresh DNA |
| Lineage | `parent_rappid` chain | Deed-to-deed history | Phylogenetic tree |

Engineers can ignore the right two columns. Humans can lean on them.

## The lineage tree (mirrors of mirrors)

```
   GRAIL (kody-w/rapp-installer, v0.6.0)
     │
     ├── kody-w/RAPP                         ← first planted mirror,
     │     │                                   adds vault notes,
     │     │                                   plant.sh, doorman pattern,
     │     │                                   place-brainstem schema, …
     │     │
     │     ├── kody-w/kody-twin              ← personal seed
     │     │     ↳ private_companion = kody-w/twin-private
     │     │
     │     ├── kody-w/pkstop-pike-place      ← place-brainstem
     │     ├── kody-w/pkstop-the-bean        ← place-brainstem
     │     │
     │     └── …anyone-else/their-mirror     ← stranger plants from RAPP
     │           ↳ parent_rappid = RAPP's rappid (NOT grail's directly)
     │           ↳ inherits RAPP's body innovations + grail kernel
     │           ↳ adds their own mutations on top
     │
     └── …another-team/their-fork-of-grail   ← parallel branch
```

A mirror's `rappid.json.parent_rappid` walks back through the chain. The lineage is the **inheritance graph for body innovations** — the kernel is universal, but body work (vault patterns, doorman scripts, place-brainstem schemas, agent cartridges, soul styles) propagates by being copied at plant time from the chosen parent mirror, and credited via lineage.

This is a `git fork` topology with `parent_rappid` as the metadata layer that makes it walkable. Anyone can:
- Plant from grail directly → flat tree, no body inheritance, kernel only.
- Plant from a mature mirror → inherit that mirror's body, keep the same grail kernel, add mutations.
- Plant from a place-brainstem to seed a sibling place-brainstem at another venue → inherit the venue-twin pattern.

The kernel byte-equality is universal across the entire tree. The body is the variation.

## The body stack — three memory tiers and two agent tiers

The vbrainstem (the doorman page running in any browser) presents a unified chat surface. Underneath, the storage and tool surfaces stratify by access:

```
                    ┌──────────────────────────────────────┐
                    │  Visitor opens <seed>/doorman/       │
                    └──────────────────────────────────────┘
                                       │
                          ┌────────────┼────────────┐
                          ▼            ▼            ▼
                      ANONYMOUS    AUTHED        AUTHED
                       (no token)  (no access   (with access
                                    to private)  to private)
                          │            │            │
                          ▼            ▼            ▼
                    ┌─────────────────────────────────────┐
                    │  MEMORY TIERS (LLM tool reads/writes)│
                    ├─────────────────────────────────────┤
                    │ device (localStorage)   ✓   ✓   ✓   │  per-browser, per-front-door
                    │ public memory.json      ✓   ✓   ✓   │  raw URL, anyone reads
                    │ private memory.json     —   —   ✓   │  raw URL + Bearer, gated
                    │ per-user (Issues API)   —   —   ✓   │  filtered by creator login
                    └─────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │  AGENT TIERS (LLM tool calls)        │
                    ├─────────────────────────────────────┤
                    │ DOORMAN tools (always loaded)        │
                    │   ManageMemory                       │
                    │   ContextMemory                      │
                    │                                      │
                    │ ASCENDED tools (private soul reach.) │
                    │   LearnNew         (auth + access)   │
                    │   SwarmFactory     (auth + access)   │
                    └─────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │  PERSONA                            │
                    ├─────────────────────────────────────┤
                    │ DOORMAN MODE — kind-aware default   │
                    │   "Hi, I'm <name>, here at my front │
                    │    door."                           │
                    │                                      │
                    │ ASCENDED MODE — full twin voice     │
                    │   private soul.md becomes the       │
                    │   primary system prompt             │
                    │   "Hi, I'm <name>, in full voice."  │
                    └─────────────────────────────────────┘
```

The visitor's experience changes invisibly with their access. The URL is the same. The OAuth flow is the same. The only thing that changes is what GitHub returns to the visitor's token.

## The single mechanism: silent escalation via raw URLs

The whole tier system is one fetch shape, repeated:

```js
const r = await fetch("https://raw.githubusercontent.com/<owner>/<repo>/main/<path>", {
  headers: token ? { Authorization: "Bearer " + token } : {}
});
if (r.ok) {
  // 200 — content is yours; merge into the doorman's context
} else {
  // 404 — silently skip; never shown to the user
}
```

For public seed reads, the path resolves at any time, no token needed. For private companion reads, it resolves only when the visitor's token has read access on the private repo; otherwise GitHub returns 404 with no distinguishing signal vs. "file doesn't exist." That's the access boundary, automatically enforced by GitHub's repo permissions, surfaced to the doorman as a single boolean (resolved or didn't).

For writes, the same principle applies via the Issues API — the visitor's token has issue creation rights or doesn't; GitHub gates it; the doorman silently routes elsewhere on failure.

The doorman never explains "you don't have access to X." Visitors just experience a shallower or richer twin depending on who they are.

## The OAuth flow — same auth as the egg hub vbrainstem

Same `client_id` (`Ov23liXWPqaiWnxt9cLz`), same auth worker (`rapp-auth.kwildfeuer.workers.dev`), same `rapp_settings` localStorage key. Sign in once on any front door at `kody-w.github.io/*`, and you're signed in across every other front door on that origin (shared localStorage). Private repos that the operator has read access to silently unlock their ascended view at every front door they've planted.

This is the cross-device-but-not-cross-origin part: the operator's mobile phone signs in once → walking around their own planted seeds opens the ascended view at every one. A visitor on a different machine signs in with their own GitHub identity → they see their tier (whatever access GitHub grants them).

## The bond cycle — kernels can be re-baselined without losing bodies

A mirror that has accumulated body work over time and wants to re-pin its kernel to grail (in case it drifted, or to align with a kernel revision someday) runs the bond cycle:

1. 🥚 **Egg the body** — snapshot soul, agents, memory, custom UI as a portable cartridge.
2. 🌐 **Overlay the kernel** — replace `rapp_brainstem/brainstem.py` + `agents/basic_agent.py` + `VERSION` with grail bytes.
3. 🐣 **Hatch back** — restore the body on top of the freshly-baselined kernel.

Anything that broke broke because it depended on kernel-side features that should have been agents. Those features become single-file `*_organ.py` or `*_agent.py` cartridges and re-grow as branches.

This pattern works at every scale: per-file (a single agent egg), per-install (a local brainstem rebonding to the canonical kernel), per-repo (this is what kody-w/RAPP did to itself), per-network (every mirror in the tree can rebond independently). Drift is anti-fragile — there's always a clean way back.

## The compounding properties

Stitching all of this together gives the platform properties that no single layer carries:

- **Universal scale.** Anonymous browser visitor, authed mobile user, authed desktop operator, ascended collaborator, public POI brainstem at a venue, peer-to-peer tether across devices — all are points in the same address space, all share the same kernel, all use the same OAuth + raw URL fabric. No deployment differences.
- **Public and private at once.** A planted seed is *publicly addressable* (anyone with the URL gets the doorman) and *privately deeper* (specific authenticated visitors get the ascended twin). The same artifact serves both.
- **Owned forever.** No vendor controls a planted seed. The kernel discipline is structural; GitHub serves the static files; the OAuth flow proves identity but doesn't gate identity issuance. Move the repo, move the auth worker — the mirror keeps working.
- **Lineage is value.** Forking from a mature mirror inherits its body innovations. Vault notes propagate, plant.sh patterns propagate, doorman improvements propagate. The lineage tree is the **innovation propagation graph**.
- **Drift is recoverable.** Bond cycle re-baselines kernels at any granularity without destroying body work. No experimentation is permanent in a destructive sense.
- **No central authority.** No registry, no allowlist, no maintainer approval. Mirror network membership is structural — your `rapp_brainstem/brainstem.py` matches grail or it doesn't.

## What this is NOT

A few things the stack deliberately doesn't do:

- **Not a SaaS.** No vendor controls anything. The platform team can stop existing and every planted mirror keeps working.
- **Not a fully-decentralized P2P network.** GitHub is the substrate for static hosting + identity + private-repo gating. Centralization where centralization works (CDN, identity); distribution where it matters (every mirror is independent).
- **Not anonymous.** Identity is GitHub identity. The platform doesn't try to invent a new identity layer when one already exists.
- **Not a chatbot.** The doorman is *one* surface of a planted seed. The seed also serves the kernel install, the public memory, the agent cartridges, the place metadata. Chat is the visitor-facing layer; the rest is the substrate.

## When this is the wrong shape

Be honest about misfits:

- **You need real-time multi-tenant collaboration with shared mutable state.** GitHub's commit-based concurrency model doesn't fit; use Yjs, Automerge, Cloudflare Durable Objects, etc.
- **You need sub-second writes against a single shared dataset.** GitHub APIs are rate-limited; this stack uses Issues API for per-user writes and pushes for shared writes — neither suits high-write-throughput shared state.
- **You need anonymous identity with strong cryptographic privacy.** GitHub identity is the substrate; can't pretend otherwise.
- **You need vendor-managed availability/uptime SLAs.** GitHub is the SLA. If GitHub is down, the platform is degraded.

For everyone else — anyone whose AI infrastructure needs to be public-and-private simultaneously, owned by the operator, and capable of running on any device with no install — the layered mirror stack is the shape.

## See also

- [[Mirror Spec]] — the byte-equality contract every kernel-compliant mirror must satisfy.
- [[The Front Door]] — the user-facing real-estate framing.
- [[The Engine Stays Small]] — the manifesto behind the frozen kernel.
- [[The Single-File Agent Bet]] — why all extension lives in one-file cartridges, not kernel changes.
- [[Federation via RAR]] — the adjacent trust pattern for cartridges (agents) flowing through the network.
- [[Engine, Not Experience]] — the founding stance that lets each operator own their experience layer.
- [[The Sacred Constraints]] — Constraints #1, #4, #6 are the ones this stack operationalizes.
