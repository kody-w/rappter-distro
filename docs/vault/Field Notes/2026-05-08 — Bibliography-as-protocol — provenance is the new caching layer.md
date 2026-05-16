# Bibliography is the braintrust primitive — each pattern has its own shape

**Date:** 2026-05-08
**Tag:** field-notes, protocol-design, primitive-scoping

In the braintrust pattern (RAPP scenario 5), the synthesized report carries a full bibliography — every citation traced to the contributor + the source it came from. **This is the right primitive for THIS use case in THIS neighborhood**. It is NOT a universal protocol for every federated pattern. The temptation to generalize "provenance" into a universal caching layer for all neighborhoods is exactly the antipattern the master plan warns against — overgeneralization is how platforms acquire taxonomy that "basically does the same thing in slightly different framings" and end up unusable.

This note is the corrected framing.

## The braintrust use case is *specifically* about libraries

The braintrust pattern exists to answer: **"what do all of our librarians know about X?"** Each contributor is curating their own knowledge store. The work product is a synthesized report that aggregates findings from those stores. Provenance — *who said it, where it came from, when* — is load-bearing because the value of the report is exactly its traceability back to specific sources.

Bibliography fits because:

- The contributors **are librarians** by definition in this neighborhood
- The findings **are citations** by definition (sourced from a library)
- The report **is a synthesis of cited claims** by definition
- Verification **is re-checking sources** by definition

Take any of those four out and bibliography is the wrong shape.

## Other patterns, other primitives

The platform supports many different neighborhood patterns. Each has its own appropriate primitive — and **the wrong move is to retrofit "bibliography" onto patterns that don't need it**.

| Pattern | Primitive | What's load-bearing | What's NOT |
|---|---|---|---|
| **Braintrust** (research, knowledge work) | Bibliography of citations | Source provenance + freshness verification | Voting, real-time speed, anonymity |
| **Public Art Collective** | Voting + remix lineage | Issue reactions + `remix_of` chains | Source citations, formal reviews |
| **Memorial Twin** | Additive-only stories | Append-only contributions, multi-curator authorship | Voting, deletions, contradiction merging |
| **Crisis Response** | Speed + force-quorum | "Whoever's home, ship now"; deadline=minutes | Citations, deliberation, peer review |
| **Distributed Code Review** | Review comments by specialty | Multi-perspective concerns, merge-readiness verdict | Bibliography (review *is* the artifact, not citation chain) |
| **Live Translation Mesh** | Parallel translations | Per-locale source preservation | Citation reputation |
| **Apprentice / Mentor** | Decision log as training signal | Append-only senior decisions, apprentice read-access | Synthesis, voting |
| **Time Capsule** | UTC threshold | `sealed_until_utc` comparison | Anything else; this pattern is one field |
| **Library Bake-off** | Confidence ensemble | Multiple library_query implementations + scoring | Single canonical answer |
| **Charizard-in-the-woods** | Egg + sha256 | Offline transfer integrity | Anything live |

The pattern matters. The primitive matters more. **Bibliography is one of many; it's not "the" universal protocol.**

## Why this confusion is dangerous

Anthropic introduced overlapping taxonomies (agents / skills / routines / loops / plugins) that all describe roughly the same thing in slightly different framings. RAPP's antipattern §1 explicitly forbids this — *one term for the plugin unit, always `agent`*.

The same discipline applies to neighborhood-level primitives. If we said:

> "Bibliography is the universal caching layer for all federated AI work."

…we'd be on the road to having SEVEN different "bibliography-but-actually-different" shapes, one per pattern, each pretending to be the same thing while diverging in subtle ways. New visitors couldn't tell what was what. Code couldn't share. Tests couldn't reuse. The complexity would become the gatekeeper.

The corrected framing:

> **Each pattern has its primitive. Bibliography is the braintrust primitive. Use the right shape for the use case.**

## The actual underlying invariant

What IS shared across patterns is not "bibliography" but a much weaker contract: **every action attributable to a known operator-rappid + a known timestamp**. That's it. That's the only universal primitive.

- Braintrust attributes via citations + bibliography
- Public Art attributes via PR commits + Issue reactions
- Memorial Twin attributes via decision-narrative authorship
- Crisis Response attributes via "who responded, when"
- Code Review attributes via review comments
- Translation Mesh attributes via per-locale provenance
- Apprentice attributes via decision-log entries
- Time Capsule attributes via `sealed_by`
- Bake-off attributes via library implementation + confidence

In each case, the attribution shape is different, but the underlying invariant — **operator-rappid + timestamp** — is the same. The rappid is the spine that runs through every pattern. THAT is what makes the platform composable. Not bibliography.

## What the braintrust *correctly* contributes

Bibliography is the right primitive for braintrust. The fields it locks in (`contributor.rappid`, `source.kind`, `source.ref`, `snippet`, `captured_at`, `confidence`) are the right shape for that pattern. Other patterns can borrow the *idea* of attribution but must shape their primitives around their own use case — they should NOT inherit the bibliography schema and pretend it fits.

## The protocol-design lesson

When a primitive feels right for the use case in front of you, **scope it to that use case explicitly**. Don't generalize prematurely. The platform's strength comes from having many narrow, well-fit primitives — not one over-broad protocol that has to bend awkwardly to fit every shape.

If two patterns end up sharing 90% of a primitive, *then* extract the shared piece. Don't extract first. Discover the duplication; don't manufacture it.

## Why I'm writing this down

Because I almost shipped this note arguing "bibliography is THE universal caching layer" — and the operator caught it. Universal-caching-via-provenance is a tempting framing because it sounds elegant. But it would have been wrong: it would have created a primitive that doesn't fit voting (Public Art), doesn't fit speed (Crisis Response), doesn't fit additive memory (Memorial Twin). It would have been a generalization that produces taxonomy creep — exactly what we said we'd never do.

**Bibliography is the braintrust primitive. Each pattern has its own shape. The rappid + timestamp is the only universal thread. That's the corrected framing.**
