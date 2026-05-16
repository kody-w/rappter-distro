---
title: Constitution Reading Order
status: published
section: Foundations
hook: 24 articles. Annotated. Ordered for first-time readers, not for reference.
---

# Constitution Reading Order

> **Hook.** 24 articles. Annotated. Ordered for first-time readers, not for reference.

`CONSTITUTION.md` is the platform's governance document — 24 articles, currently ~1,200 lines, organized topically. This note is a *first-read order*: a sequence that introduces concepts in dependency order, with one-line annotations and pointers into the vault.

## Read this first (the load-bearing 4)

These four articles are the constitution. If you understand them, you understand the platform.

| Order | Article | What it says | Vault deep-dive |
|-------|---------|--------------|-----------------|
| 1 | **Article 0 — The Sacred Tenet** | The single sentence the rest of the document expands. | [[The Engine Stays Small]] |
| 2 | **Article I — The Brainstem Stays Light** | Adding to `brainstem.py` requires unprecedented justification. | [[The Brainstem Tax]] |
| 3 | **Article III — Capabilities Are Files** | The single-file agent rule, in legal language. | [[The Single-File Agent Bet]] |
| 4 | **Article XV — Tier Parity Is a /chat Contract** | The tier portability guarantee, expressed as the route contract. | [[Three Tiers, One Model]] |

If you stop here, you have the four sacred constraints. See [[The Sacred Constraints]].

## Then the architectural moves (5–11)

Once the four are absorbed, the next layer explains *how* the platform stays that way:

| Order | Article | What it says | Vault deep-dive |
|-------|---------|--------------|-----------------|
| 5 | **Article II — Delimited Slots Are a Fixed Resource** | Why two slots, and why never three. | [[Voice and Twin Are Forever]] |
| 6 | **Article IV — Blast Radius** | Reversibility as a design property. | — |
| 7 | **Article V — The Install One-Liner Is Sacred** | Why `curl ... \| bash` is the distribution story. | [[Why GitHub Pages Is the Distribution Channel]] |
| 8 | **Article VI — Local First, No Phone-Home** | Telemetry posture; data residency defaults. | — |
| 9 | **Article VII — Scope Discipline** | What lives in the repo and what doesn't. | — |
| 10 | **Article VIII — Degrade Gracefully** | When dependencies are missing, fail readably. | — |
| 11 | **Article XIII — Reversibility** | Every action the user takes can be undone or redirected. | [[The Twin Offers, The User Accepts]] |

These articles are why the platform's surfaces *feel* the way they do. You can skip them on a first read; they make more sense after the operational articles below.

## Then the twin & UX layer (12–15)

The twin is a major chunk of the constitution. These four articles set the philosophy:

| Order | Article | What it says | Vault deep-dive |
|-------|---------|--------------|-----------------|
| 12 | **Article IX — The Twin Offers, The User Accepts** | The asymmetry that defines RAPP's UX. | [[The Twin Offers, The User Accepts]] |
| 13 | **Article X — Calibration Is Behavioral, Not Explicit** | Why the platform refuses to ship a settings page. | [[Calibration Is Behavioral, Not Explicit]] |
| 14 | **Article XXI — Every Twin Surface Is a Calibration Opportunity** | Help-shaped UI is wrong. Calibration-shaped is right. | [[Every Twin Surface Is a Calibration Opportunity]] |
| 15 | **Article XXII — One Twin, Two Faces** | The twin as user-model and as conversation partner. | — |

These four together are the platform's UX manifesto. If you only read these and `Article 0`, you have most of what makes RAPP feel different.

## Then the workspace & directory rules (16–20)

How the file system is organized is itself constitutional:

| Order | Article | What it says | Vault deep-dive |
|-------|---------|--------------|-----------------|
| 16 | **Article XVI — The Root Is the Engine's Public Surface** | Why roots stay clean. Repo root + brainstem root. | [[Roots Are Public Surfaces]] |
| 17 | **Article XVII — `agents/` IS the User's Workspace** | The user organizes; the brainstem discovers. | — |
| 18 | **Article XVIII — The Management UI Is a View Onto `agents/`** | The UI doesn't have its own model; it reads the filesystem. | — |
| 19 | **Article XIV — Swarms Are Directories, Not Routes** | A swarm is a folder of agents; nothing more. | [[Why t2t and swarm_server Are Gone]] |
| 20 | **Article XX — UI Defaults to Beginner-First** | Defaults are calibrated for the new user; advanced is opt-in. | — |

## Then the operational articles (21–23)

| Order | Article | What it says | Vault deep-dive |
|-------|---------|--------------|-----------------|
| 21 | **Article XI — Historical Artifacts Are Memorial** | Don't delete fossils — they teach. | [[Why hatch_rapp Was Killed]], [[The experimental Graveyard]] |
| 22 | **Article XII — Prompt Shape Is a Contract** | The system prompt's structure is normative. | — |
| 23 | **Article XIX — Versions Are Load-Bearing Rollback Points** | Why we tag aggressively. | — |

## Then the recently-added (24, plus Amendments)

The most recent constitutional changes:

| Order | Article | What it says | Vault deep-dive |
|-------|---------|--------------|-----------------|
| 24 | **Article XXIII — The Vault Is the Long-Term Memory** | The discipline that produces this vault. | [[Roots Are Public Surfaces]] |
| 25 | **Article XXIV — Amendments** | The amendment process. | — |

## Reading paths by goal

- **Just the rules:** Articles 0, I, II, III, XV. Five articles, ~10 minutes.
- **The full philosophy:** the load-bearing 4 + the twin & UX layer + Article XXIII. Nine articles, ~30 minutes.
- **The workshop facilitator brief:** Articles III, IX, XV, XVI, XVII. Five articles, ~15 minutes.
- **The architect deciding to bet on RAPP:** Articles 0, I, III, IV, VI, XV. Six articles + the [[The Sacred Constraints]] note, ~25 minutes.
- **The contributor onboarding:** all 24 articles. ~90 minutes if you read carefully.

## What the constitution doesn't cover

The constitution is rules. It is not:

- **The spec.** `pages/docs/SPEC.md` is the normative description of what the platform *does*. Read it after the constitution; the constitution explains why the spec is the way it is.
- **The narrative.** This vault is the narrative. Read the vault notes in parallel with the constitution articles for the full picture.
- **The reference docs.** `pages/docs/`, the per-tier READMEs, and the agent metadata are reference. Use as needed.

## Discipline

- Read the constitution end-to-end at least once. It's shorter than it looks.
- Use this reading order for first-time readers; use the constitution's own table of contents for reference lookups.
- When the constitution and a vault note appear to disagree, the constitution wins by default. The vault is interpretation; the constitution is rule. Conflicts should be reported as bugs.

## Related

- [[The Sacred Constraints]]
- [[How to Read This Vault]]
- [[The Platform in 90 Seconds]]
- [[The Engine Stays Small]]
