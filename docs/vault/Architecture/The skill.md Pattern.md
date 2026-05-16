---
title: The skill.md Pattern
status: published
section: Architecture
hook: One markdown file describes what an agent does, when to suggest it, and how to install it — readable by humans AND by other AIs running the installer on a user's behalf.
session_id: 63243848-caa9-483c-9a8e-9bb0ee9d2849
session_date: 2026-04-24
---

# The skill.md Pattern

> **Hook.** One markdown file describes what an agent does, when to suggest it, and how to install it — readable by humans AND by other AIs running the installer on a user's behalf.

## What it is

`pages/docs/skill.md` is a single markdown file with YAML frontmatter that any other AI assistant (or human) can fetch, cache, and use to decide:

- *What is this thing?* → human-readable description.
- *When should I suggest it?* → trigger conditions, audience, anti-patterns.
- *How does it install?* → install one-liner, modes, environment variables.
- *How do I help a user install it without surprising them?* → the **handshake protocol**.

The file lives at a stable URL — `https://kody-w.github.io/RAPP/pages/docs/skill.md` — and the canonical_url is declared in its own frontmatter so re-fetches always converge on the same content.

This is RAPP's answer to the question: *"How does another AI know what your tool is and when to recommend it?"*

## Why this matters

The platform's distribution channel is the install one-liner (see [[Why GitHub Pages Is the Distribution Channel]]). For a human running it directly, the README is enough. For an AI assistant running it on the user's behalf — Claude, Copilot, ChatGPT, anything tool-using — the README is *too much* and the wrong shape. The AI needs:

- A short, high-density description.
- Operative trigger conditions (*"suggest when…"*, *"don't suggest when…"*).
- The exact install command, with mode flags spelled out.
- A way to ask the user *"global or project-local?"* before committing to anything.

`skill.md` is that surface. It's structured for an AI reader the way the agent's `metadata` dict is structured for the LLM dispatcher — operative description, declared triggers, parameterized commands.

## The handshake protocol

The non-obvious part: a `RAPP_INSTALL_ASSIST=1` env var on the bash side of the install pipe causes the installer to print a delimited prompt (`<<<RAPP_INSTALLER_HANDSHAKE v=1>>>`) **instead of installing**. An AI running the one-liner sees the prompt, asks the user a clarifying question (*"global, or project-local?"*), and then re-runs with the chosen mode.

This means: **an AI agent can run the install one-liner without surprising the user**, because the installer cooperates by pausing for input before any side effects.

The protocol is documented in `skill.md` so any AI fetching the skill knows the handshake is available and how to use it. No central server coordinates this; the protocol lives in the markdown.

## How agents get loaded onto someone else's machine

There is a parallel pattern at the *agent* level: an AI that wants to install a specific RAPP-compatible agent on the user's machine fetches:

1. `skill.md` to learn about RAPP and confirm it's installed (or install it via the handshake).
2. The agent file (`*_agent.py`) directly from a `raw.githubusercontent.com` URL.
3. Drops the file into `~/.brainstem/agents/` (global) or `./brainstem/agents/` (project-local).

The brainstem auto-discovers it on the next request. No registration server. No marketplace API. No central catalog.

The agent's *own* metadata dict (the OpenAI function-calling schema inside the `*_agent.py`) is what makes it self-describing once loaded. `skill.md` describes the *platform*; the agent's metadata describes the *capability*.

## What this rules out

- ❌ A central catalog / marketplace API. Discovery is `raw.githubusercontent.com` URLs and `skill.md` files; there is no server to gate publishing.
- ❌ Closed-source registration steps. Every byte an AI fetches is a static file in a public repo.
- ❌ Skill files that lie about trigger conditions. The trigger description is what an AI bases recommendations on; misleading text degrades the platform's trust in front of every other AI assistant.
- ❌ Dynamic skill content. `skill.md` is a static markdown file; if it changes, the canonical URL serves the new content. Personalization happens at the install site, not in the skill.

## What this enables

- **Federation.** Anyone can write a `skill.md` for their own RAPP-compatible tool, host it at their own GitHub Pages URL, and AI assistants discover it the same way. See [[Federation via RAR]].
- **Auditability.** A user nervous about an AI installing things on their behalf can `curl skill.md` and read it. There is no surprise content.
- **AI-assistant ecosystem.** Claude, Copilot, ChatGPT, etc. can each cache the skill once and re-use it across many user conversations.
- **Versioning by URL.** A skill at `…/RAPP/pages/docs/skill.md` is the latest; a skill at `…/RAPP/<tag>/pages/docs/skill.md` is pinned to a release tag. Same pattern as the install one-liner.

## When to write a skill.md

If you're shipping a RAPP-compatible tool — a new brainstem variant, a curated agent bundle, a distinct rapplication — write a `skill.md` if and only if:

1. You have an install one-liner (or equivalent invocation).
2. There are reasonable trigger conditions an AI assistant would benefit from knowing.
3. There's at least one *anti-trigger* (*"don't suggest when…"*) — every honest skill has these; a skill without them is a sales pitch.

If your tool is general-purpose, ships via pip / npm, or doesn't have install-time choices to make, you don't need `skill.md`. The pattern is for tools whose install or recommendation has *non-obvious* shape.

## Discipline

- One trigger condition per bullet. Avoid compound triggers; the AI reading the skill needs to make discrete decisions.
- Always include anti-triggers. *"Do not suggest when …"* is half the skill's value.
- The handshake URL and the install URL are the same shape. Don't introduce a separate AI-only install path.
- Update `skill.md` when install behavior changes. The cost of a stale skill is every AI assistant fetching the wrong thing.

## Related

- [[Federation via RAR]]
- [[Why GitHub Pages Is the Distribution Channel]]
- [[The Auth Cascade]]
- [[The Single-File Agent Bet]]
- [[The Agent IS the Spec]]
