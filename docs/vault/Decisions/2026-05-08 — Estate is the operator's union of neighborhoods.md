# Estate is the operator's union of neighborhoods (the metropolis model)

**Date:** 2026-05-08
**Status:** Adopted as platform north-star

## What changed

The neighborhood layer being added to RAPP is not a single-membership feature ("you join one neighborhood per brainstem"). It is multi-tenant from day one. Every brainstem holds N subscriptions, and the union of those subscriptions IS the operator's **estate**.

When estates mesh through shared neighborhoods, the result is an **AI metropolis** — emergent topology, no central declaration, exactly like physical urban zoning is emergent from individual property/community choices rather than top-down planning.

## The four-layer stack

```
   ┌──────────────────── Metropolis ──────────────────────┐
   │   (emergent mesh of estates through neighborhoods)    │
   └────────────────────────┬──────────────────────────────┘
                            ↓
   ┌─────────────────── Estate ─────────────────────────┐
   │   ONE operator's union of all neighborhoods         │
   │   they're in (local + cross-device, pub + priv)     │
   │   Identity primitive: operator's personal rappid    │
   └────────────────────────┬────────────────────────────┘
                            ↓
   ┌─────────────────── Neighborhood ───────────────────┐
   │   A community with a purpose; collaborator-gated    │
   │   public gate + private companion (or single repo)  │
   │   Identity primitive: neighborhood_rappid           │
   └────────────────────────┬────────────────────────────┘
                            ↓
   ┌─────────────────── Personal organism ──────────────┐
   │   ONE planted seed (heimdall, etc.)                 │
   │   Identity primitive: rappid                        │
   └─────────────────────────────────────────────────────┘
```

## Why this matters

Without explicitly modeling **estate** as a layer, the natural failure mode is to build per-neighborhood UI/API surfaces that don't compose. The operator would have to context-switch between "I'm now in the SE Team" and "I'm now in the family-photos" mode like switching apps. That's exactly the smartphone-app-store mental model the platform is trying to *replace*.

The estate model says: there is one operator. Their identity is constant. Neighborhoods are scopes that overlay. Agents in those scopes work on the operator's behalf — and crucially, asynchronously. The operator doesn't have to be in the loop at the moment work is happening; results land back in their inbox, attributed to their rappid, and they pick them up when they next look.

This is what makes the "use everyone else's hardware to run the network" vision tractable. The hardware is owned by N operators in M neighborhoods, but the work attribution is always clean because operator identity is the spine.

## Cross-estate meshing — what physical zoning gets right

Real cities don't have one central planner deciding which kinds of communities exist. Zoning enables emergence: residential here, commercial there, mixed-use along this corridor — but the *people* fluidly move between zones based on need. A person isn't "the residential person" or "the commercial person"; they're a person who participates in multiple zones depending on context.

The metropolis pattern replicates this for agents-on-behalf-of-people:
- A user joins multiple neighborhoods (zones) for different purposes
- Their agents do work in each zone
- Results route back to the user across zones
- When their estate brushes up against another user's estate through a shared neighborhood, that's the meshing point — bounded by the neighborhood's `public_facets`

## What this implies for the build order

The keystone built on 2026-05-08 (gate + private companion + membership organ + agents) supports this model from day one because:

1. `~/.brainstem/neighborhoods.json` holds an *array* of subscriptions, not one
2. Every `members.json` entry carries the operator's rappid — work attribution is intrinsic
3. `GET /api/neighborhoods/estate` synthesizes the union view (zones + bridges)
4. The async loop-back is provided by the Issues + `neighborhood_subscribe_agent` primitive (just unscoped to one neighborhood — Phase 2 makes it estate-wide)

What still needs to land for full metropolis support:
- Operator inbox aggregating async results across all subscriptions
- Estate-level personal memory that follows the operator across zones
- Cross-neighborhood agent invocation respecting operator-identity-preservation
- Inter-estate meshing protocol implementation (the doc exists; the wire is unbuilt)
- Topology view (the "map of the city")

## Source

Established in the rappter1 + kody-w design session, 2026-05-08, when the operator explicitly named the metropolis-of-estates pattern after the gate + private companion architecture had been scaffolded. The user's framing: *"just like real communities do… that is the model we need to replicate but for agents on behalf of people for the work."*

## The pattern is fractal

Same primitives at every scale — **rappid** (identity) + **door** (gate URL or summon mechanism) + **card** (presentation layer — `card.json` per ECOSYSTEM §3) + **tether** (WebRTC §5a + Issues §5b + PRs §5c + raw fetch §5d) + **trust scope** (§2 personal/neighborhood/public).

```
agent    (single file, single function)        ← smallest unit
twin     (one organism — e.g. kody-w/heimdall) ← single brainstem
neighborhood  (multiple twins federating)      ← e.g. kody-w/microsoft-se-team-neighborhood
metropolis    (multiple neighborhoods)         ← e.g. kody-w.github.io/RAPP/metropolis/
…outward                                       ← federations of metropolises
```

Every level uses the same protocol. Every level is its own GitHub repo. RAPP holds the kernel + spec; everything planted is its own thing.

## Related

- The first canonical neighborhood lives as its own repo at [`kody-w/microsoft-se-team-neighborhood`](https://github.com/kody-w/microsoft-se-team-neighborhood) (gate) + [`kody-w/microsoft-se-team-neighborhood-private`](https://github.com/kody-w/microsoft-se-team-neighborhood-private) (private companion) — same pattern as a planted twin like [`kody-w/heimdall`](https://github.com/kody-w/heimdall)
- `rapp_brainstem/utils/organs/neighborhood_membership_organ.py` — the runtime; carries `_estate_view()`
- [`NEIGHBORHOOD_PROTOCOL.md`](../../../NEIGHBORHOOD_PROTOCOL.md) — the wire-level companion
- [`HERO_USECASE.md`](../../../HERO_USECASE.md) — needs a new §6 "Cross-Estate Metropolis" once Phase 2 lands
