---
title: Writing for the AI reader — CLAUDE.md, AGENTS.md, skill.md, and the contract with assistants
status: shipped
published_url: https://kody-w.github.io/2026/04/24/writing-for-the-ai-reader/
section: Blog Drafts
hook: Three small files at the repo root tell three different AI audiences exactly how to read and edit your project. Together they're a contract that makes the codebase friendly to autonomous edits without giving anything up.
date: 2026-04-24
class: evergreen
decay: low
---

# Writing for the AI reader — CLAUDE.md, AGENTS.md, skill.md, and the contract with assistants

Most projects are written for two audiences: humans contributing today, and humans contributing in two years. Both read the same README, the same CONTRIBUTING.md, the same code comments. The audience is implicit; the writing serves it implicitly.

Sometime in the last year, a third audience showed up: AI assistants editing your code on a contributor's behalf. Cursor. Codex. Claude Code. The growing list of agentic tools that read repositories, propose changes, and sometimes ship them. The new audience reads everything the human audience reads — and one important thing the human audience doesn't bother with: instruction files written *for it specifically*.

This post is about three small files at the repo root that compose a contract with that audience. They're cheap to write. The leverage is real.

## The three files

**`AGENTS.md`** — the file Cursor, Codex, and other agentic editors look for first. Generic enough that any reasonable AI editor can use it. Tells the AI what's sacred about the codebase, what to avoid, what conventions matter.

**`CLAUDE.md`** — Claude Code specifically reads this from the project root. Tells Claude how the project is structured, what commands run, what the architecture is, and what constraints to honor.

**`skill.md`** — different audience: an AI assistant *invoking* the project (running its installer, calling its CLI) on the user's behalf. Lives at a stable URL so the assistant can fetch it without cloning the repo. Documents how the tool works and what choices it offers.

Three files, three audiences, one consistent contract: *here is what we want you to do; here is what we want you to not do; here is how we want you to ask when you're not sure.*

## Why these are different from a README

A README is for humans landing on the GitHub page. It opens with marketing — *what this project is and why you might care.* It progresses through getting started, install instructions, conceptual overviews, links to deeper docs. The shape is "convince and orient."

An AI assistant reading a README has to do filtering work. Most of what's in the README is signposting for humans (look at this badge, scroll to that section, click here for the install command). The AI's question is much more specific: *given that I'm editing files in this repo right now, what rules should I follow?* The README mostly doesn't answer that.

The three AI-reader files answer it directly. They skip the marketing. They state the rules. They name the destinations. They're written in the voice of *"do this, not that"* because that's exactly what an AI editor needs to hear.

## What goes in `AGENTS.md`

The shape that's worked:

```markdown
# AGENTS.md

This is the contract for AI tools editing this repository.

## Sacred constraints (these cannot be relaxed)

1. <constraint>
2. <constraint>
3. <constraint>

## Conventions

- <convention with explicit rule>
- <convention with explicit rule>

## Where things live

| If you want to add | Put it in |
|---|---|
| <X> | <path> |
| <Y> | <path> |

## What this rules out

- ❌ <forbidden pattern>
- ❌ <forbidden pattern>

## When in doubt

- Read [SPEC.md](./pages/docs/SPEC.md) for the wire contract.
- Read [CONSTITUTION.md](./CONSTITUTION.md) for the rules.
- Don't introduce new top-level files without justification.
```

Two things make this work:

**The sacred constraints come first.** AI editors are biased toward making changes. A bullet at the top that says *"single-file agents are sacred; don't introduce a build step"* prevents an entire category of well-intentioned-but-wrong refactor.

**The destinations are explicit.** *"If you want to add a marketing page, put it in `pages/<section>/<file>.html`. Not at root."* Specific routing means the AI doesn't have to guess.

## What goes in `CLAUDE.md`

Claude Code reads this on every session. It's the project's brief to Claude:

```markdown
# CLAUDE.md

## Project overview

<one paragraph>

## Commands

```bash
<the actual commands>
```

## Architecture

<short essay on how the system works — request flow, agent system, key files>

## Sacred constraints

<numbered list, same shape as AGENTS.md but tier-specific>

## Key directories

<table>

## Environment

<env vars>

## Vendoring

<if applicable>
```

The difference from AGENTS.md is depth. CLAUDE.md is allowed to be longer because Claude Code parses it on every project-load and uses it to scope what it knows. The architecture section can be a real explainer; the commands section can document non-obvious development workflows. AGENTS.md is more rule-shaped; CLAUDE.md is more context-shaped.

Both files agree on the constraints. The constraints are the load-bearing part — repeated where each audience reads, ensuring they aren't violated regardless of which tool the contributor is using.

## What goes in `skill.md`

Different audience, different shape. `skill.md` is for an LLM running the project's tool on a user's behalf — typically the installer.

```markdown
# RAPP — Skill manifest

## What it is

<one paragraph; plain language; no marketing>

## When to suggest it

- User says X
- User asks about Y without Z
- User wants A that does B

## How to install

### Global (default)

```bash
curl -fsSL .../install.sh | bash
```

### Local (project-scoped)

```bash
curl -fsSL .../install.sh | bash -s -- --here
```

## The handshake protocol

If the user might want to choose between modes, set
`RAPP_INSTALL_ASSIST=1` before the curl pipe. The installer
will print a structured prompt instead of installing. Read
the prompt, ask the user, re-run with the right command.
```

A separate post in this series covers `skill.md` in full ([[The skill.md Pattern]]). The point here is that it's the *third* file in the AI-reader contract — the one for AI tools that are *using* the project, not editing it. Same idea, different audience.

## Why three files instead of one

The temptation is to combine them. *"Just write one giant AI-editor README."* Don't. The three files exist because they have three different audiences with three different parsing strategies:

- AI editors parsing the repo (Cursor, Codex) → `AGENTS.md`. They know to look for it.
- Claude Code (and Anthropic's tools) → `CLAUDE.md`. The project-instructions convention.
- LLMs invoking the tool from outside (any chat assistant) → `skill.md` at a stable URL. They fetch, parse, act.

Combining them would force every audience to filter past content meant for the others. The three files stay small, focused, and read entirely by the audience they're for. Updating one doesn't risk drift in another, because they're literally separate documents.

The shared substance is the *constraints*. Sacred rules that any AI working on or with this project must honor. Those appear in all three files. The redundancy is intentional: you can't reach this project as an AI without seeing the constraints, regardless of which doorway you came through.

## What this buys

A repo with this contract gets three things:

**AI-assisted edits land cleanly.** When an AI editor reads `AGENTS.md` before editing, it doesn't propose a refactor that violates the project's sacred constraints. The PR comes back close-to-merge instead of close-to-revert.

**AI-assisted installs land cleanly.** When an LLM running on a user's behalf reads `skill.md`, the install lands in the right mode the first time, without the LLM guessing.

**The maintainer's review burden drops.** Without these files, an AI's PR is a bag of "we don't do that here." With these files, the AI has been pre-told. Maintainer review focuses on substance, not on patrolling the rules.

## What this costs

Roughly three afternoons:

- Half a day to write `AGENTS.md` for the project's specific constraints.
- A day to write `CLAUDE.md` with real architecture content.
- An afternoon to write `skill.md` for whatever the project's main user-facing tool is.
- An ongoing zero — these files are stable. Update them when sacred constraints change, which is rare.

The cost is small. The leverage is that *every future AI interaction with the project* benefits from the contract being in place. New AI tools that show up will probably look for `AGENTS.md` first, because that's the convention emerging across the ecosystem. The investment compounds.

## How to write them well

Three principles:

**Lead with what's sacred.** AI editors are bias-toward-action. The first thing they should read is what they cannot change.

**Name destinations explicitly.** Don't say *"organize new files appropriately."* Say *"new install scripts go to `installer/`. Not root."* Specificity is mercy.

**Use exclusion lists.** *What this rules out* is the most read section because it prevents the most failure modes. Make it a real list, not three abstract sentences.

## Receipts

- The three files in this project: [`AGENTS.md`](https://github.com/kody-w/RAPP/blob/main/pages/docs/AGENTS.md), [`CLAUDE.md`](https://github.com/kody-w/RAPP/blob/main/CLAUDE.md), [`skill.md`](https://github.com/kody-w/RAPP/blob/main/pages/docs/skill.md).
- The convention emerging across the ecosystem: many AI editors look for `AGENTS.md` at root.
- Article XVI of the project's CONSTITUTION explicitly names these files as load-bearing root residents.

The AI is going to read your repo whether you wrote for it or not. Write for it. The contract is small. The leverage is large.
