# Adapt-to-what's-home is the only consensus protocol that scales off-grid

**Date:** 2026-05-08
**Tag:** field-notes, distributed-systems, protocol-design

Most distributed-systems work assumes a quorum. RAPP doesn't. The neighborhood's contract is **adapt to who's home**: synthesis ships with whatever contributors are present; absent ones don't block. This is unusual enough to be worth writing down WHY.

## The classical assumption

Distributed-systems literature is dominated by quorum-based protocols: Paxos, Raft, two-phase commit, Byzantine fault tolerance. They share a load-bearing assumption: **a known set of nodes, where you can wait for a majority before proceeding**. Off-grid scenarios — where some nodes are simply asleep, removed, or unreachable for unbounded time — break that assumption.

You can patch quorum protocols to handle this (timeouts, dynamic membership) but the patches are awkward. The protocols are fundamentally designed around the idea that **the system is the union of its nodes**, and missing nodes degrade the system.

## The RAPP assumption

The RAPP neighborhood contract inverts this:

- The neighborhood is **online if at least one brainstem is online**.
- Synthesis ships with **whoever's home**, not whoever's expected.
- A removed contributor is **identical to an offline one** from the protocol's perspective: their existing contributions count if already posted; their absence never blocks.
- Quorum is a *hint* (defaults to 1), not a hard gate. The synthesizer accepts a `force_quorum` override.

This sounds like it should produce inconsistency — "what if two synthesizers run with different attendance?" — and the answer is: that's fine. Each synthesis is a snapshot of who was home at synthesis-time. Multiple snapshots get merged via PR review (consensus through GitHub's existing review primitives). Future synthesis on the same request includes the deltas. The network is **eventually consistent over time**, not consistent at any single moment.

## Why this works for the use cases the platform actually serves

- **Two phones in the woods.** Charizard-in-the-woods. There is no quorum to wait for; there are two devices, and one of them needs the agent. The pattern: trade now; reconcile when home.
- **Bill's SE Team across timezones.** Not all 200 SEs are online at any moment. A request can wait for everyone, in which case it never ships, OR it can ship with whoever's there. The platform picks the latter.
- **Memorial twin.** Family members contribute when they can. There is no "deadline." The neighborhood grows asynchronously over years.
- **Crisis response.** When the building is on fire, you don't wait for a quorum to call 911. You ship with one responder.

For each of these, the "wait for quorum" model would be wrong. **The network has to adapt to who's actually present, because whoever's not present isn't going to suddenly appear.**

## The CAP corollary

In CAP-theorem terms, RAPP picks **AP**: availability + partition-tolerance over consistency. Specifically:

- **Available** at all times — every present brainstem can serve queries against its cached state, post contributions, run agents.
- **Partition-tolerant** at the protocol level — when the network splits, each partition continues operating; when they merge, Dream Catcher reconciles.
- **Consistency is eventual** — UTC-first canon resolves frame ordering; contradictions are preserved as alternate-dimension data; the operator decides which version is canonical.

This is the right trade for a network that's supposed to span **devices that may be in airplane mode for days**. CP systems (consistent + partition-tolerant) require quorum or external arbiter; they hang under partition. AP systems keep working. RAPP keeps working.

## The implementation principle

Every async-loop-back agent the platform ships honors this:

- **Synthesizer:** never blocks on absent contributors. Below quorum returns `deferred`; with `force_quorum=true`, ships with what's home.
- **Federate:** opens WebRTC to whoever's reachable; Issue-posts to those who aren't; doesn't wait for anyone.
- **Subscribe:** reconciles roster from live API; drift is normal, not an error.
- **Inbox:** surfaces what landed; doesn't complain about what didn't.

This is also how the user-facing UX works: **the user is in the loop async**. The network doesn't pause when they go to sleep. Their workspace inbox catches what their agents did while they were away.

## The deepest implication

If the network adapts to who's home, then **adding a new operator is non-disruptive**. They can plant their organism, subscribe to neighborhoods, federate, leave, come back, leave again — without triggering a coordinated reconfiguration. This is what makes the platform composable at scale.

It's also what makes **organic growth possible**. There's no admission ceremony. There's no "the network is full." There's just: another node showed up; they participate when they're here; they don't when they're not. Same as how cities work.

## What this is NOT

It is **not** a full BFT protocol. We don't claim safety against adversarial nodes — the trust anchor is GitHub collaborator status, which means Byzantine attacks would have to compromise GitHub itself.

It is **not** strict consistency. Two synthesizers running in two partitions will produce different reports. PR review reconciles them.

It is **not** automatic. The "neighborhood adapts to who's home" is a contract honored by every async agent we ship. New agents that violate it (e.g. block on quorum) are bugs.

## Why I'm writing this down

Because I keep getting questions like "what if not everyone shows up?" and the right answer is: **that's the normal case, not the failure case**. The protocol is designed for it. The whole point is that the network doesn't depend on any particular member being available.

Engineers who internalize quorum-first thinking find this counterintuitive. The right reframe is: **the network is what's home right now**. The absent nodes are not part of "the network at this moment." They were yesterday; they will be tomorrow. They aren't today. Cool. Ship anyway.
