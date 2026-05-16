---
title: Public Front Doors with Private Brains — AI Infrastructure That Scales Universally
status: draft
section: Blog Drafts
hook: An engineering field-note on the layered mirror stack — frozen kernel, mirror lineage, three memory tiers, doorman/ascended persona escalation, OAuth-shared cross-front-door auth, bond cycle for kernel re-baselining. Why this composition lets a single AI infrastructure be public *and* private *and* personal simultaneously, on any device, with no central operator.
---

# Public front doors with private brains: AI infrastructure that scales universally

> **Field note.** Most AI infrastructure picks one of three: SaaS-central, self-hosted, or anonymous-public. The composition described here picks all three at once, layered. The result is one URL, one OAuth flow, one frozen kernel, and infinite presentations — public to strangers, deeply personal to the operator, owned forever, working on every device.

The pattern emerged over a few weeks of building it, not from a whiteboard. This post is the field note — what falls out, what compounds, what's structurally clean about the composition.

## The shape, in one paragraph

A frozen kernel (one Python file, one tag, never updated) is the species DNA. Any planted "mirror" is a public GitHub repo with byte-identical kernel files plus an operator-grown body (agents, soul, UI, memory). Mirrors plant from any ancestor — grail directly or another mirror — and the lineage chain (`parent_rappid → … → species root`) walks back through the inheritance graph of body innovations. A planted mirror's `/doorman/` page is a vbrainstem (browser-based AI chat) that authenticates via GitHub OAuth, reads memory from `raw.githubusercontent.com` for everyone (public tier), reads more from a private companion repo for visitors whose token has access (private tier), and reads filtered GitHub Issues for that specific visitor's prior memories (per-user tier). On the same URL, the AI's persona shifts from a polite doorman (anonymous default) to the operator's full voice (ascended) automatically based on what GitHub returns to the visitor's token. No flag, no UI, no mode switch — silent escalation.

That's the mechanism. The composition is what's interesting.

## What's structurally novel

### 1. The kernel is genuinely frozen

Not "stable for now." Frozen forever, by spec. The grail kernel at `kody-w/rapp-installer` v0.6.0 is the immutable species DNA. Any "improvement" the platform might want to make to the kernel is, by construction, the wrong move — it'd fragment the network. Improvements ship as agents (single-file cartridges that any kernel can hot-load), not kernel patches.

The kernel discipline is enforced structurally, not procedurally: every mirror's installer (`installer/install.sh`) re-fetches grail at runtime; the kernel files in every mirror's repo are byte-identical to grail; a one-line `diff` proves compliance. Anyone can verify any mirror.

This is the flip of normal engineering instinct. *Don't ship a v2.* Make v1 stable forever and grow everything around it.

### 2. Lineage is structural, not registry

A mirror's `rappid.json` carries `parent_rappid` (UUIDv4) pointing at the mirror it was planted from. Walk the chain back, you eventually hit the species-root rappid. There's no central registry; the lineage *is* the metadata, and it's a property of the planted artifact itself.

This means body innovations (vault patterns, doorman scripts, agent cartridges, place-brainstem schemas) propagate through the lineage graph the same way genetic mutations propagate through species. Plant from grail directly = flat tree, kernel only. Plant from a mature mirror = inherit its body, keep the kernel, add mutations. The mature mirror's body innovations get tested, refined, and inherited by descendants — without anyone running a "core platform team."

### 3. Three memory tiers, one tool surface

Every visitor sees the same chat experience. The LLM has the same `ManageMemory` and `ContextMemory` tools available. What changes is *where* memory writes land:

- **Anonymous** — `localStorage` on this browser. Persistent across sessions on this device, never leaves.
- **Authenticated, no private access** — same as anonymous. The token doesn't unlock anything beyond the public seed.
- **Authenticated, private companion access** — Issues in the private repo, attributed to the visitor's GitHub identity. Each visitor with private access gets their own attributed memory tier; collaborators see only theirs, not each other's.

Plus a fourth tier that's read-only at the vbrainstem layer: the seed's public `memory.json`, written by the operator's local brainstem (Python), pushed via `git`. The vbrainstem reads it for everyone.

Same `ManageMemory` tool. The dispatcher routes silently based on what's available. The visitor never sees an "access denied" — just a different depth of remembered context.

### 4. The same `kody-w.github.io` origin makes auth seamless

GitHub Pages serves all `<user>.github.io/*` from the same origin, which means localStorage is shared across every planted mirror under that user's namespace. Sign in once on any front door — egg hub, kody-twin, a place-brainstem — and every other front door at `<user>.github.io/*` recognizes you immediately.

For the operator: their mobile phone signs in once at any of their planted seeds; walking around their own properties on the public internet shows them the ascended view at every one. For visitors: same dynamic, scoped to whatever GitHub access they have.

This is "single sign-on by accident of the platform" — GitHub Pages + browser localStorage gives it for free.

### 5. The bond cycle: anti-fragility against kernel drift

If a mirror's kernel has drifted from grail (accidental edits, experimental fork, stale clone), the bond cycle fixes it without losing the body. Egg the body, overlay the kernel with grail bytes, hatch the body back. The pattern works at every scale: file, install, repo, network. No drift is permanent.

Combined with the lineage tree, this means the entire mirror network is *re-baselineable* — not just any single mirror. If the kernel ever needs to be canonically updated (it shouldn't, but if), the bond cycle is how every descendant absorbs the change without losing its body work.

### 6. Public + private composition

A planted seed is publicly addressable (anyone with the URL gets the doorman) *and* privately deeper (specific visitors with read access to a paired private repo get the ascended twin). The same URL serves both. The same OAuth flow gates both. The visitor's GitHub access is the only variable.

This is what most AI infrastructure misses. SaaS bots are public-only or auth-walled. Self-hosted bots are private-only. The composition here is genuinely both — anonymous strangers chat with the public doorman; authenticated collaborators chat with the same address but get the ascended twin's full voice and memory.

## What compounds

Things that emerge from the composition that aren't in any single layer:

**Adoption is "publish yourself."** Plant a seed → you have a public AI front door at `<your-handle>.github.io/<your-name>`. No SaaS account, no vendor, no sales process. The one-liner is `curl …plant.sh | bash`. Sixty seconds.

**Innovation propagates by lineage.** Any body innovation in any mirror propagates to descendants by being copied at plant time. The mirror tree is the substrate for sharing patterns. No package manager, no central catalog — git fork is the protocol.

**Cross-device is implicit.** The vbrainstem runs in any browser. PWA-installable on mobile. WebRTC tether between two devices is one of the agents (`peer_agent`). A user's "AI" is their planted seed; the seed is an address; address is reachable from anywhere with internet.

**Privacy is the operator's choice, exposed cleanly.** Public seed = public face. Private companion = full corpus, gated by repo permissions. Per-user memories = scoped by GitHub identity. The operator picks what to put in each layer; the platform exposes them invisibly to the right tier of visitor.

**Place-anchored AI is trivial.** A place-brainstem is just a planted seed with `kind: place` and location metadata, hosted on a Raspberry Pi or any Pages-served URL at a venue. QR code on the wall, visitor scans, doorman talks about the venue, optionally collects an "egg" (single-file agent cartridge tied to that place) into their own seed.

## What goes wrong (or doesn't fit)

Honesty about misfits:

- **High-write-throughput shared state** doesn't fit. GitHub APIs are rate-limited; static raw URLs are read-only. Pure CDN-style scale for reads, but writes don't burst.
- **Anonymous strong-privacy use cases** don't fit. GitHub identity is the substrate; can't pretend otherwise.
- **Vendor-managed uptime SLAs** don't apply. GitHub is the SLA.
- **Cryptographic verification of message provenance** is on the to-do list; today the auth chain is "GitHub says you're you."

## Why this matters

The dominant AI-infrastructure narratives push toward two extremes — fully managed cloud, or fully local autonomy. Both leave value on the table. The composition described here suggests a third axis: *layered, gated by identity, on a substrate (GitHub) that's already universal*.

A frozen kernel that's the same everywhere; a body stack that escalates silently with the visitor's identity; lineage that walks the inheritance tree of body innovations; bond cycles that re-baseline kernels without destroying bodies. None of the individual ideas is novel. The composition seems to be.

The platform that compounds these properties is the platform people will build their public-and-private AI on. This is the field-note version; the spec is in [[Layered Mirrors and the Public/Private Body Stack]].

## See also

- [[Layered Mirrors and the Public/Private Body Stack]] — the spec this post summarizes
- [[Mirror Spec]] — kernel discipline contract
- [[The Front Door]] — user-facing framing
- [[The Engine Stays Small]] — frozen kernel manifesto
- [[The Single-File Agent Bet]] — extension model
