---
title: Reading Path — New Contributor
status: published
section: Reading Paths
hook: 7 notes + the constitution. The onboarding read for someone about to contribute to the platform itself.
---

# Reading Path — New Contributor

> **Hook.** 7 notes + the constitution. The onboarding read for someone about to contribute to the platform itself.

## Who this is for

You've been added to the project. You're going to write code, propose changes, or ship rapplications to the rapp store. You want to know what's expected and what's load-bearing before you submit your first PR.

This path is the canonical onboarding read.

## The 7 notes

Read in order. Don't skim. The notes that follow assume context from earlier ones.

### 1. [[How to Read This Vault]]

How the vault works — markers, sections, status conventions. Five minutes; lets the rest of the read flow.

### 2. [[The Platform in 90 Seconds]]

The pitch. You need to be able to say this in your own words by the end of week one.

### 3. [[The Sacred Constraints]]

The six rules that don't bend. Memorize the names. When you propose a change, the first question reviewers will ask is: *"does this respect all six?"*

### 4. [[The Engine Stays Small]]

The conservation law. This is the platform's posture. Every PR will be reviewed against the question *"could this be an agent or a service instead?"* Know that question; don't be surprised by it.

### 5. [[The Brainstem Tax]]

The economic argument. Read this with [[The Engine Stays Small]] still in mind — they're a pair. After this note, you should be able to predict what the reviewers will say to a "I added this to the brainstem" PR.

### 6. [[The Single-File Agent Bet]]

The agent format. If you're shipping rapplications, this is your contract. If you're touching the brainstem, this is what your changes must keep true.

### 7. [[Roots Are Public Surfaces]]

The directory hygiene rules. Where files go, why, and what's allowed at each root. Saves you a "this should be in `pages/`" review comment in your first PR.

## Then: the constitution

After the 7 notes, read `CONSTITUTION.md` end to end. Use [[Constitution Reading Order]] for the suggested traversal — about 90 minutes if you read carefully. Skim is not enough; the constitution is the rule book and reviewers will cite specific articles.

## What you'll know after

- The platform's claims and the mechanisms behind them.
- The six sacred constraints and why each one matters.
- The directory hygiene rules.
- The constitution's 24 articles, well enough to know which one applies to a given change.

## Optional deep-dives by area

Once the foundation is in place, pick the area you'll work in:

**Brainstem / kernel:**
- [[The Brainstem Tax]] (re-read)
- [[Voice and Twin Are Forever]]
- [[Local Storage Shim via sys.modules]]
- [[The Auth Cascade]]
- [[Why t2t and swarm_server Are Gone]]

**Agents / rapp store:**
- [[The Agent IS the Spec]]
- [[Self-Documenting Handoff]]
- [[Why hatch_rapp Was Killed]]
- [[The experimental Graveyard]]
- [[From save_recall to manage_memory]]

**LLM / providers:**
- [[The Deterministic Fake LLM]]
- [[Data Sloshing]]

**Tier 2 / cloud:**
- [[Tier 2 — Cloud Swarm]]
- [[Vendoring, Not Symlinking]]

**Tier 3 / Copilot Studio:**
- [[Tier 3 — Enterprise Power Platform]]
- [[RAPP vs Copilot Studio]]

**UX / twin / UI:**
- [[The Twin Offers, The User Accepts]]
- [[Calibration Is Behavioral, Not Explicit]]
- [[Every Twin Surface Is a Calibration Opportunity]]

**Workshop / process:**
- [[60 Minutes to a Working Agent]]
- [[The Agent IS the Spec]]
- [[Self-Documenting Handoff]]

## How to write your first PR

After the foundation read:

1. **Pick a small change first.** A doc fix. A test addition. An agent in `rapp_store/`. Don't open with a brainstem PR.
2. **Read the relevant area's deep dives.** If you're editing an agent, read the agent area. If you're touching the brainstem, read the brainstem area.
3. **Run the test suite.** `node tests/run-tests.mjs` and any e2e tests relevant to your change. The fake LLM (`LLM_FAKE=1`) makes most tests local and fast.
4. **Write the PR description against the relevant articles.** Cite the article numbers. Reviewers will appreciate the alignment.
5. **Anticipate the *could-this-be-an-agent* question.** Answer it in the PR description, not in review.

## What to never do

- ❌ Submit a brainstem PR without addressing why it can't be an agent or service.
- ❌ Add a top-level file without the routing rules of [[Roots Are Public Surfaces]].
- ❌ Add a sibling import to an agent.
- ❌ Repurpose a slot. Add a tag inside.
- ❌ Add code that branches on tier (`if os.environ.get("LOCAL"):` inside an agent).

## The vault is also yours

If you contribute knowledge — a new pattern, a removed antipattern, a workshop story — write it as a vault note. Use [[Vault Build-Out Plan]]'s template. Update the manifest. The vault is how the platform's *why* survives contributors.

See [CONSTITUTION](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md) Article XXIII (`CONSTITUTION.md`) for why this matters.

## Discipline

- Read the constitution before your first PR. It's shorter than it looks.
- When in doubt about a constraint, the safer default is "yes, my change violates it." The constitution is conservative by design.
- The vault is for *why*, not *how*. How-tos go in `pages/docs/` or per-tier READMEs.

## Related

- [[How to Read This Vault]]
- [[The Sacred Constraints]]
- [[Constitution Reading Order]]
- [[Vault Build-Out Plan]]
- [[Reading Path — Engineer Evaluating RAPP]]
