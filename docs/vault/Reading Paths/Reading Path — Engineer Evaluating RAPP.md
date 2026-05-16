---
title: Reading Path — Engineer Evaluating RAPP
status: published
section: Reading Paths
hook: 8 notes, ~30 minutes. The path for a senior engineer deciding whether the platform is worth integrating.
---

# Reading Path — Engineer Evaluating RAPP

> **Hook.** 8 notes, ~30 minutes. The path for a senior engineer deciding whether the platform is worth integrating.

## Who this is for

You write code for a living. You've been asked to evaluate RAPP, or you've stumbled onto it and want to know if it's the kind of platform you'd bet on. You want to understand the architecture, the constraints, and the tradeoffs *quickly* — without reading marketing pages.

This path is the fastest credible read.

## The 8 notes

Read in order. Each note links to others; if you go down a tangent, return here when you're done.

### 1. [[The Platform in 90 Seconds]]

The elevator pitch. If this doesn't land, none of the other notes will. Stop here if it doesn't.

### 2. [[The Sacred Constraints]]

The six rules the platform refuses to bend. These are the load-bearing claims; everything else flows from them. If any constraint feels ridiculous, this is the place to flag it before going deeper.

### 3. [[The Single-File Agent Bet]]

The constraint that defines the agent format. Read this with one of the agents open in another tab — `rapp_brainstem/agents/manage_memory_agent.py` is a good 79-line example.

### 4. [[Data Sloshing]]

How multi-agent pipelines work without an orchestration framework. Read this with the LLM-dispatch question in mind: *"would I want to build this here?"* Most engineers have an instinctive reaction to this section.

### 5. [[Local Storage Shim via sys.modules]]

The single cleverest trick in the platform. Read this to understand whether the cleverness is the kind you'd respect or the kind you'd worry about. (Spoiler: the trick is small, set up once at boot, and trivial to read.)

### 6. [[Three Tiers, One Model]]

The portability claim, with mechanism. By the end of this note, the previous five should make sense as a single design.

### 7. [[What You Give Up With RAPP]]

The anti-pitch. This is the page that says "RAPP is wrong for you if…". Read it carefully — if the criteria match your project, the answer is "don't use RAPP." That's the platform being honest.

### 8. [[The Engine Stays Small]]

The conservation law. By this point you've seen what the platform spends its complexity budget on (deliberately small) and what it doesn't spend (everything else). This is the philosophy that produces the rest.

## What you'll know after

If you've read all 8 notes:

- You can describe the agent format to a colleague in two sentences.
- You know what the platform *won't* do, and why.
- You have a credible opinion on whether the constraints are worth the conveniences they replace.
- You can decide whether to keep evaluating or move on.

## Optional next reads

If you want to keep going, three reasonable directions:

- **The architecture details:** [[The Auth Cascade]], [[Vendoring, Not Symlinking]], [[The Deterministic Fake LLM]] — three more architecture notes that fill in the technical surface.
- **The removed code:** [[Why hatch_rapp Was Killed]], [[The experimental Graveyard]], [[Why t2t and swarm_server Are Gone]] — what got cut and why. The lessons here are general engineering wisdom, not RAPP-specific.
- **The constitution itself:** `CONSTITUTION.md` — the rules in legal form. [[Constitution Reading Order]] is the suggested traversal.

## What to skip

For a *first-evaluation* read, skip:

- The Twin and UX section (relevant if you're building UI; not load-bearing for evaluation).
- The Process section (relevant if you'd run workshops; not load-bearing for evaluation).
- The Positioning section other than [[What You Give Up With RAPP]] (the rest is for sales conversations).

## Discipline

- Don't trust marketing. Read the constitution and the architecture notes.
- The evaluation question is "does the platform's claim match the platform's mechanism?" The notes above are designed to answer that.
- If a note feels like a slogan rather than a mechanism, that's the kind of feedback the platform wants — flag it.

## Related

- [[The Platform in 90 Seconds]]
- [[The Sacred Constraints]]
- [[How to Read This Vault]]
- [[Constitution Reading Order]]
