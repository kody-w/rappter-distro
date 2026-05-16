---
title: Reading Path — Architect Deciding to Bet
status: published
section: Reading Paths
hook: 6 notes, ~25 minutes. For the architect deciding whether to commit a team or a quarter.
---

# Reading Path — Architect Deciding to Bet

> **Hook.** 6 notes, ~25 minutes. For the architect deciding whether to commit a team or a quarter.

## Who this is for

You make platform decisions that are hard to reverse. A team is going to commit weeks or months to a tool; you want to know what's load-bearing, what's contingent, and where the platform will break under your specific load.

The engineer-evaluation path ([[Reading Path — Engineer Evaluating RAPP]]) is about *can this work?* This path is about *should we bet on this?*

## The 6 notes

### 1. [[Engine, Not Experience]]

The platform's central commitment. Architecturally, this is the question of "what's the platform's job vs. what's the user's?" If you disagree with this division, no further reading is needed — the platform is the wrong tool for your team.

### 2. [[The Brainstem Tax]]

The economic argument behind constraint #4 (brainstem stays light). For an architect, this section's value is in the framing: every shared abstraction is a tax. RAPP is explicit about which taxes it's collecting and which it's refusing.

### 3. [[Three Tiers, One Model]]

The platform's central claim, with the mechanism. Architects need to know that the tiers are a real abstraction, not marketing. The vendoring section ([[Vendoring, Not Symlinking]] is its companion) is what makes this credible.

### 4. [[What You Give Up With RAPP]]

The anti-pitch, addressed at the architect. This note explicitly lists the cases where RAPP is the wrong tool. Reading this *first* among the positioning notes is correct — if your project matches one of the "wrong tool" criteria, the rest of the read is unnecessary.

### 5. [[Why Three Tiers, Not One]]

The reasoning behind each tier's job, and what each tier *can't* do. Architects need to know the limits as well as the capabilities. The "one tier per audience" rejection (the alternative the platform considered and didn't take) is the most architecturally interesting argument.

### 6. [[The Engine Stays Small]]

The conservation law. Read this last, when you have enough mechanism in mind to evaluate the law's claims. The argument here is structural: a small engine produces compounding benefits over time; a large engine compounds taxes.

## What you'll know after

- Where the platform's complexity is spent and where it isn't.
- Why the tiers are real, not marketing.
- Where the platform is wrong for your team (if anywhere).
- The economic argument for why a small engine is worth the constraints.

## What to also consider (not in vault)

Three platform-decision questions the vault can't answer for you:

- **Customer fit.** Does your customer base want what RAPP delivers? (Tier 1 → Copilot Studio handoff is the canonical fit; non-Microsoft tenants are a worse fit.)
- **Team fit.** Does your team's mental model match single-file agents and behavioral calibration? (Some teams want frameworks; some want maximal control. RAPP is in the middle.)
- **Time horizon.** RAPP's bet pays off over many agents. A single-agent project may not see the return on the constraints.

These questions need conversations with your team, not vault reads.

## What to skip on a first read

- The Removals section. Useful background but not decisive for a bet decision.
- The Process section. Workshop-runner content; relevant for delivery, not architecture.
- The Twin and UX section. Relevant for product feel; not load-bearing for architectural fit.

You can always come back to these.

## Optional deep-dives

If you decide to bet (or want to be sure before deciding):

- **All four foundational tier notes:** [[Tier 1 — Local Brainstem]], [[Tier 2 — Cloud Swarm]], [[Tier 3 — Enterprise Power Platform]], plus [[Three Tiers, One Model]].
- **All architecture notes:** [[Local Storage Shim via sys.modules]], [[The Auth Cascade]], [[The Deterministic Fake LLM]], [[Vendoring, Not Symlinking]] — fills in the mechanism.
- **The constitution itself:** `CONSTITUTION.md` via [[Constitution Reading Order]].

## Discipline

- A bet decision is a long-time-horizon decision. Don't make it on slogans; verify the mechanisms.
- The platform's answer to "what won't you do?" matters more than its answer to "what can you do?"
- If your team doesn't agree with the constitution after reading it, the bet is wrong. The constitution survives every contested call; teams that fight the constitution lose.

## Related

- [[Reading Path — Engineer Evaluating RAPP]]
- [[The Platform in 90 Seconds]]
- [[The Sacred Constraints]]
- [[Constitution Reading Order]]
