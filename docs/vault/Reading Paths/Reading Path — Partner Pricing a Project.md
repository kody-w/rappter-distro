---
title: Reading Path — Partner Pricing a Project
status: published
section: Reading Paths
hook: 5 notes, ~15 minutes. The path for a partner / consultant about to estimate scope on a RAPP project.
---

# Reading Path — Partner Pricing a Project

> **Hook.** 5 notes, ~15 minutes. The path for a partner / consultant about to estimate scope on a RAPP project.

## Who this is for

You're a partner — a consulting firm, a Microsoft solution provider, an enterprise integrator. A customer hands you a `*_agent.py` file and says "we built this in a workshop. What would it cost to operationalize?"

This path is what you read once, before your first RAPP estimate. After this you can read the file directly.

## The 5 notes

### 1. [[The Platform in 90 Seconds]]

The 90-second framing. You need this so the conversation with the customer makes sense. Skip if you're already familiar.

### 2. [[The Agent IS the Spec]]

The most important note for partners. This explains *why* a partner can estimate from the file alone — what to read in the metadata, what to read in `perform()`, what to read in the parameter schema. After this, you have the four-readings framework that defines your job.

### 3. [[Self-Documenting Handoff]]

The before/after of partner-handoff in RAPP. This note has the actual checklist (the "self-document checklist") that determines whether a file is partner-ready or still a draft. Use this as your first-pass evaluation tool.

### 4. [[Three Tiers, One Model]]

The portability claim. As a partner, this matters because it tells you that the file you're reading is the file that ships in production — there's no rewrite phase you'd otherwise be sneaking into the estimate.

### 5. [[RAPP vs Copilot Studio]]

The relationship to the rest of the Microsoft AI stack. As a partner, you need this because most of your customers also have Copilot Studio engagements. Knowing how RAPP feeds into Copilot Studio (rather than competes with it) shapes your conversation with the customer about scope and downstream work.

## What you'll know after

- How to read a `*_agent.py` file as if it were a SOW.
- What questions you'd ask the customer when scope is unclear (and which questions the file already answers).
- Where Tier 3 starts and what's in scope for that phase vs. earlier phases.
- How to talk to the customer about RAPP without misframing it as a Copilot Studio competitor.

## The estimation checklist

After reading the 5 notes, when you receive a `*_agent.py` file from a customer, your scan in 5 minutes:

1. **Read the metadata `description`.** If it doesn't compress to a sentence, the agent is too broad — flag this with the customer.
2. **Read the `parameters` schema.** Every required field is data the agent needs; every optional field is a decision point. Note the integration surface.
3. **Read the `perform()` body.** Count the integration points (storage, external HTTP, downstream agents). Each integration is a scope item.
4. **Read the imports.** Anything beyond standard library + the platform's `utils/` is a dependency you'd verify.
5. **Check the file size.** If it's under ~300 lines, it's a single-week scope. If it's larger, the customer probably has *multiple* agents hiding in one file — split-suggestion is your value-add.

If the file passes the [[Self-Documenting Handoff]] checklist, your estimate can be a price. If it doesn't, your reply is the gap list, not the price.

## What to skip on a first read

For a partner-first read:

- The Twin and UX section. Customer-facing, not partner-facing.
- The Removals section. Engineering archaeology; not decisive for pricing.
- The Architecture section's deep dives. Useful if you're integrating, not if you're estimating.

## Optional deep-dives

If you decide to specialize in RAPP delivery:

- **The Process section in full** — [[60 Minutes to a Working Agent]], [[The Agent IS the Spec]], [[Self-Documenting Handoff]]. The complete delivery model.
- **All three tier notes** — to understand what changes between Tier 1 (workshop), Tier 2 (cloud), Tier 3 (Copilot Studio publish).
- **`CONSTITUTION.md`** — the rules of engagement. Customers may reference these in scope discussions.

## Discipline

- Trust the file. If the file says required, it's required. The platform's design enforces this; relying on it is what gives you the estimation speed advantage.
- Don't re-do discovery. A workshop produced the file; the workshop *was* the discovery. Adding a discovery phase is double-billing the customer.
- "We need a call" is the rejection of self-documenting handoff. Use it sparingly — every call is the platform's promise unwound.

## Related

- [[The Agent IS the Spec]]
- [[Self-Documenting Handoff]]
- [[60 Minutes to a Working Agent]]
- [[RAPP vs Copilot Studio]]
- [[Reading Path — Exec Asking What This Is]]
