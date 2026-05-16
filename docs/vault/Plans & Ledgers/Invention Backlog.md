---
title: Invention Backlog
status: living
section: Plans & Ledgers
type: backlog
hook: A capture surface for novel, patentable inventions at the intersection of the Rappter stack and the real-estate / AI industry. Append-only. Public framework, private specifics.
session_id: 63243848-caa9-483c-9a8e-9bb0ee9d2849
session_date: 2026-04-24
---

# Invention Backlog

> **Hook.** A capture surface for novel, patentable inventions at the intersection of the Rappter stack and the real-estate / AI industry. Append-only. **Public framework, private specifics.**

This is the platform's running list of *candidate inventions* — ideas that may be patentable, that emerge naturally from the Rappter stack's intersection with a target industry, and that need formal prior-art evaluation before any filing.

## The brief

Verbatim, so it's not lost:

> *Generate a novel, patentable invention in the intersection of RAPPTER STACK + real-estate / AI industry. For each: analyze prior art (search 50M+ patents), identify white space, design the invention (technical specifications, diagrams, use cases), write patent claims (independent + dependent), create USPTO-ready applications (background, summary, detailed description, claims, drawings), assess commercial viability (market size, competitive advantage, implementation cost), and rank by patentability score. Focus on truly novel combinations no one has connected before.*

That's the charter. This document captures it; the per-invention work happens in the workflow described below, with **the actual disclosure-level details kept in a private location until filed** (see *Public-vault discipline* at the bottom).

## Why this intersection

The Rappter stack has architectural properties most agent platforms don't:

- **Single-file agents** that ship as one Python file across local / cloud / Copilot Studio without rewrite ([[The Single-File Agent Bet]], [[Three Tiers, One Model]]).
- **Deterministic inter-agent state** via `data_slush` — pipelines compose without an orchestration framework ([[Data Sloshing]]).
- **Tier portability** — same agent in customer's laptop, customer's Azure tenant, customer's Microsoft Copilot Studio ([[Three Tiers, One Model]]).
- **Twin calibration** as the UX model — behavioral signal, not settings pages ([[The Twin Offers, The User Accepts]]).
- **Federated agent registry** with no central server ([[Federation via RAR]]).
- **AI-readable agent manifests** via `skill.md` — other AI assistants discover and recommend ([[The skill.md Pattern]]).

Real estate as an industry has properties that *interact non-obviously* with the above:

- **High-stakes transactions** — closings, contingencies, escrows. Determinism matters.
- **Heterogeneous data sources** — MLS, public records, lender feeds, county assessor APIs, listing photos, historical comps. Multi-agent territory.
- **Strict regulatory surfaces** — fair housing, RESPA, state-specific licensing, state-specific contract forms. Audit + tier-portability matter.
- **Multi-party handoffs** — buyer agent → seller agent → lender → title → escrow → recorder. Self-documenting handoff matters ([[Self-Documenting Handoff]]).
- **Voice-shaped moments** — at the front door, on the phone, in the car. Shortcuts + voice-slot matter ([[Surfaces — Mobile, Watch, Voice]]).
- **Trust-bounded workflows** — a real-estate professional's reputation depends on consistency. Twin calibration matters.

The novelty is rarely in *Rappter alone* or *real estate alone* — it's in the *combination*: applying a Rappter property to a real-estate failure mode in a way no existing patent has connected.

## The process per invention

Each backlog entry moves through these phases:

| Phase | What | Output |
|---|---|---|
| **1. Capture** | One-line hook + the failure mode it addresses + which Rappter property creates the white space. | Backlog entry below, status `scoped`. |
| **2. Prior art** | Search USPTO PatFT, Google Patents, EPO Espacenet for the closest existing patents. **50M+ corpus is the public surface; the *real* search is the corpus filtered by the specific intersection.** Document what's already covered. | Prior-art memo (private). Status → `prior-art-done` or `precluded` (if too crowded). |
| **3. White-space** | The diff between the closest prior art and the proposed invention. Concrete: what claim language *exists* vs. what claim language *we'd add*. | White-space memo (private). |
| **4. Design** | Technical specifications (architecture, data flow, sequence diagrams), use cases (3+ concrete scenarios), edge cases, alternative embodiments. | Design doc (private). Status → `designed`. |
| **5. Claims** | Independent claims (broadest defensible scope) + dependent claims (narrower variations the specification supports). Typical: 1–3 independent + 15–20 dependent. | Claims doc (private). |
| **6. USPTO-ready application** | Background, summary, detailed description, claims, drawings, abstract. Per USPTO formatting (37 CFR 1.71 et seq.). | Filed application (private + USPTO). Status → `filed`. |
| **7. Commercial viability** | TAM / SAM / SOM, competitive moat, implementation cost, time-to-revenue. Independent of patentability — a strong patent on a small market still ranks below a weak patent on a large one. | Viability memo (private). |
| **8. Rank** | Combined score = **patentability × commercial viability**. Used to decide which to file first. | Ranking row updated below. |

Phases 2–7 are gated by competent counsel review. The platform's role is to *capture, structure, and rank* — not to prosecute.

## Patentability scoring (working rubric)

Each invention scored 1–5 across five axes; product is the score:

| Axis | 1 | 5 |
|---|---|---|
| **Novelty** | Crowded prior art, narrow distinguishing features. | No close prior art; the combination is unprecedented. |
| **Non-obviousness** | A skilled artisan would arrive at this routinely. | The combination requires deliberate insight that prior art teaches *away* from. |
| **Utility** | Marginal improvement. | Solves a meaningful, named industry failure mode. |
| **Enablement** | Hard to specify what's claimed. | Reduces to practice cleanly with the Rappter stack we already ship. |
| **Defensibility** | Easy design-around in claim language. | The independent claim has a load-bearing structural element no design-around can replicate without the same insight. |

*Score* = product of the five axes (1–3,125). Anything ≥ 200 is a *file* candidate; ≥ 800 is a *file fast* candidate.

## Areas of intersection

Current candidate areas live in the maintainer's private workbook outside this repo. Reach out if you have a specific direction to evaluate or a prior-art lead worth chasing.

## Backlog (entries)

*Append-only. Specifics live in private working documents; this row is the index entry.*

| Title (slug) | Hook (1 line) | Status | Score | Filed |
|---|---|---|---|---|
| *(seed entries land here as Phase 1 captures begin)* | | | | |

To add an entry: append a row with `status: scoped` and a one-line hook. Detailed work goes into a private working doc; this row updates as phases complete.

## Public-vault discipline

This file is in a public Git repo. **Implementation details, claim language, and prior-art memos must NOT live here**. They go in a private location (a separate repo, a private notes vault, a sealed working doc) until the application is filed and the patent is published.

Why: in some jurisdictions, public disclosure starts a clock against the inventor's own filing rights. The US has a 1-year grace period; many other jurisdictions do not. The conservative posture: keep specifics private until filed, then publicize freely.

What's safe to publish here:

- ✅ The framework (this document).
- ✅ Areas of intersection (above) — phrased as *prompts*, not as enabled inventions.
- ✅ The backlog *index* — title, slug, status, score.
- ✅ Public artifacts after filing (USPTO publication number, abstract, link).

What stays private:

- ❌ Independent or dependent claim language.
- ❌ Detailed technical specifications, sequence diagrams, alternative embodiments.
- ❌ Prior-art memos that name closest hits.
- ❌ Commercial viability numbers (those signal where the platform sees the moat).

## How to use this with Claude Code

When the brief comes up in a future session:

1. **Open this file as the charter.** Confirm the current state of the backlog.
2. **Pick an area of intersection** (or a freshly captured one) to push to Phase 2.
3. **Move per-invention work into a private working doc** (e.g., `~/.invention-workbook/<slug>/` outside the repo). Reference the slug here only; never mirror specifics back.
4. **Update the backlog row** as phases complete. The score column lets ranking emerge over time.
5. **Engage counsel** at Phase 6. The platform's role ends at Phase 5 deliverables; filings are attorney-driven.

## Related

- [[Vault Build-Out Plan]] — the vault's own plan; same append-only discipline.
- [[Documentation Roadmap]] — internal docs companion.
- [[Blog Roadmap]] — public blog companion. Patent-shaped content goes through the [[Content Strategy]] mill *only after a patent application is filed*.
- [[Federation via RAR]] · [[The skill.md Pattern]] · [[Three Tiers, One Model]] · [[Data Sloshing]] · [[Self-Documenting Handoff]] · [[Surfaces — Mobile, Watch, Voice]] — the Rappter properties most likely to anchor patent claims at this intersection.
