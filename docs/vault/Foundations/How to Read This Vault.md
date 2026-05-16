---
title: How to Read This Vault
status: published
section: Foundations
hook: A meta-note for first-time visitors. Where to start, what the markers mean, how to use the wiki vs the Obsidian vault.
---

# How to Read This Vault

> **Hook.** A meta-note for first-time visitors. Where to start, what the markers mean, how to use the wiki vs the Obsidian vault.

## What this is

This vault is the RAPP platform's **second-brain wiki** — the home for the *why* behind every decision the platform has made. It is not documentation (that lives in `pages/docs/` and the per-tier READMEs). It is not the spec (that lives in `SPEC.md`). It is the long-form reasoning, the rejected alternatives, the war stories, the manifestos.

Two surfaces hold the same content:

- **The vault folder** (`vault/` in the repo). A real Obsidian vault. Open with *File → Open folder as vault* in any Obsidian client. Wikilinks work. Search works. No plugins required.
- **The static viewer** (`pages/vault/`). A web UI that fetches the same markdown live from GitHub, renders wikilinks and backlinks, supports search, and exports the entire vault as an Obsidian-compatible zip.

Both are the same content. Read either one.

## Where to start

Three reasonable entry points depending on what you want:

- **"What is RAPP, in 90 seconds?"** → [[The Platform in 90 Seconds]].
- **"Why did the platform make the decisions it made?"** → [[The Sacred Constraints]] then the *Founding Decisions* section.
- **"I'm contributing — what do I need to know?"** → [[The Engine Stays Small]] then [[The Brainstem Tax]].

A few minutes scrolling [[_index]] is also fine. The notes are self-contained; no specific order is required.

## The markers

Each note has a status in its frontmatter, surfaced in the index and the static viewer's sidebar:

- **● Published** — a full essay. Decision captured, alternatives rejected, mechanism explained, discipline described.
- **◐ Living** — append-only. The plan, the roadmap, the ledger. Read top-down for current state; the bottom of the file is the oldest entry.
- **◯ Stub** — a slot held but the post hasn't been written. Stubs exist so the wiki names the topic; they're how the vault tells you "we know this matters but haven't written it yet."

The bar to convert a stub to published is one thing: **the why is captured well enough that someone who wasn't in the room can apply it.**

## Session pointers (optional)

Some notes — mostly the living docs and the decision-shaped entries — carry two extra frontmatter fields:

```yaml
session_id: 63243848-caa9-483c-9a8e-9bb0ee9d2849
session_date: 2026-04-24
```

These are pointers, not transcripts. The platform deliberately **does not store conversation content** in the vault, the repo, or anywhere else. The `session_id` is the UUID of the Claude Code session that produced the note; the `session_date` is when. If a future contributor needs context for *why* a decision came out the way it did, they can match the UUID against their local Claude Code store (`~/.claude/projects/<project-id>/<session-id>`) and re-read the conversation themselves.

The fields are optional. Most notes don't carry them — manifestos and architecture deep-dives are decoupled from any single conversation. The pointer is most useful for entries where *the conversation is the artifact* (plans, ledgers, decision records).

The link checker validates the field shape if present (UUID for `session_id`, ISO date for `session_date`) but never requires either.

## The graph, not the index

Every note links to 3–5 related notes via `[[wikilinks]]`. The index is a flat list; the graph is the real structure. Click forward; click back via the backlinks panel (in the viewer) or the sidebar's "Backlinks" pane (in Obsidian). The fastest way to absorb the platform's mental model is to start at any note and follow links until you stop being surprised.

## What's in each section

- **Foundations.** Reference notes — glossary, tier overviews, sacred constraints. Read these to learn the vocabulary.
- **Founding Decisions.** The platform's central principles, told as decisions with rejected alternatives.
- **Removals.** Lessons from deleted code. Highest-decay knowledge — the code is gone, so the lesson lives only here.
- **Architecture.** The clever tricks that look weird at first glance. Code-anchored.
- **Positioning.** Honest tradeoffs, comparison to neighbors, the anti-pitch.
- **Twin and UX.** The platform's UX philosophy. Why settings pages are a failure mode, why every surface is a calibration opportunity.
- **Process.** How a workshop runs, what the agent file does for stakeholders, how partner handoff works.
- **Manifestos.** The short essays that turn one-line slogans into something you can defend.
- **Plans & Ledgers.** The vault's own plan, the documentation roadmap, the release ledger. Append-only living docs.

## What this isn't

- **Not the spec.** `SPEC.md` is normative; the vault is narrative. If they ever conflict, the spec wins; treat the vault as a bug.
- **Not the constitution.** `CONSTITUTION.md` is the rules; the vault expands the *why* the rules exist. Both are load-bearing.
- **Not generated.** Every note is hand-written. There is no LLM-padded "stub" expansion; if a stub feels short, that's because nobody's written the full essay yet.
- **Not user-facing PII.** This is a public vault. No real names, no email addresses, no internal incidents. War stories abstract to the pattern and the artifact.

## Reading paths (when they exist)

[[Vault Build-Out Plan]] Phase 4 will produce curated reading paths for different audiences (engineer, architect, partner, exec, contributor). Until those land, [[_index]] is the navigation surface.

## Discipline (for contributors)

If you're adding a note:

- Use the existing template — frontmatter, hook, body, related. Match the voice (third person, project voice, no PII).
- Status starts at `stub`; promote to `published` only when the bar is met.
- Update `_manifest.json` so the viewer surfaces the note.
- Cross-link aggressively. Three to five wikilinks per published post is the floor.
- See [[Vault Build-Out Plan]] for the full writing rules.

## Related

- [[The Platform in 90 Seconds]]
- [[The Sacred Constraints]]
- [[Constitution Reading Order]]
- [[Vault Build-Out Plan]]
