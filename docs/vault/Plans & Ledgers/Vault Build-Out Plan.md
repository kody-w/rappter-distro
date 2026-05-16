---
title: Vault Build-Out Plan
status: living
section: Plans & Ledgers
type: plan
hook: The full plan to take the vault from 26 stubs to a publishable second-brain wiki — phased, with checkpoints.
session_id: 63243848-caa9-483c-9a8e-9bb0ee9d2849
session_date: 2026-04-24
---

# Vault Build-Out Plan

> **Hook.** The full plan to take the vault from 26 stubs to a publishable second-brain wiki — phased, with checkpoints.

This is a living document. As phases complete, check the boxes. As new work appears, append it under the matching phase. As lessons emerge, drop them in the **Notes & decisions** section at the bottom.

> **Status (2026-04-24): all 8 phases complete.** 46 notes (41 published, 3 living, 2 entry/index). 570 wikilinks resolve. PII checker green. Viewer ships keyboard nav, anchor links, Open-in-Obsidian, reading mode, mobile breadcrumb, SVG graph view. Tied back into README, `pages/docs/SPEC.md`, and 10 marketing pages.

## Operating constraints

The vault is a **public** knowledge resource. Every word in every note must satisfy these:

- **No personally identifiable information.** No real names, no email addresses, no phone numbers, no internal usernames. The handle `kody-w` is allowed because it is the public GitHub repo handle and appears in all install URLs.
- **No first-person personal anecdotes.** Voice is project / platform, not founder. Use *"RAPP chose X"*, *"the brainstem rejects Y"*, *"the platform's working knowledge"* — not *"I"*, *"we"* (in the founder sense), or *"the founder"*.
- **No private incidents.** No customer names, deal stories, workshop transcripts, or anything that lives only in someone's memory. War stories abstract to the *pattern* and the *artifact in the codebase* (file paths, deleted line counts, commit-shaped facts).
- **Code-anchored examples only.** Every claim that needs evidence points to a real file, a real commit, or a real diff. If it can't be pointed at, it's hearsay and doesn't ship.

A PII checker (Phase 6) enforces the first three at test time so future PRs can't regress this property.

## Voice & style

- **Subject of sentences:** the platform, the brainstem, the agent, the user — not "we" or "I".
- **Tense:** present for what is true; past for what was rejected; conditional for what would happen if a rule were violated.
- **Length:** published posts target ~700–1200 words. Stubs stay under ~200 words.
- **Cross-linking:** every published post links to **3–5** other notes via `[[wikilinks]]`. The graph is the point.
- **Receipts:** at least one file path, line range, or commit-shaped fact per published post.

## Phases

### Phase 1 — Voice & style sweep ✅

- [x] Apply the voice rules above to the existing 28 notes.
- [x] Replace any first-person / founder references already present (e.g. "the founder's head" in [[Engine, Not Experience]] → "the platform's working knowledge").
- [x] Confirm `kody-w` is the only allowed identifier and only appears in URL contexts.

### Phase 2 — Convert all 26 stubs to published ✅

For each stub: hook → decision → alternatives rejected → mechanism (with file paths and code references) → discipline → when to reconsider → 3–5 wikilinks. Frontmatter `status: stub` flips to `status: published`.

- **Founding Decisions** — [x] [[Engine, Not Experience]] · [x] [[Why Three Tiers, Not One]] · [x] [[The Single-File Agent Bet]] · [x] [[Voice and Twin Are Forever]] · [x] [[Data Sloshing]] · [x] [[The Brainstem Tax]]
- **Removals** — [x] [[Why hatch_rapp Was Killed]] · [x] [[From save_recall to manage_memory]] · [x] [[Why t2t and swarm_server Are Gone]] · [x] [[The experimental Graveyard]]
- **Architecture** — [x] [[Local Storage Shim via sys.modules]] · [x] [[The Deterministic Fake LLM]] · [x] [[Vendoring, Not Symlinking]] · [x] [[The Auth Cascade]]
- **Positioning** — [x] [[RAPP vs Copilot Studio]] · [x] [[What You Give Up With RAPP]] · [x] [[Why GitHub Pages Is the Distribution Channel]]
- **Twin and UX** — [x] [[The Twin Offers, The User Accepts]] · [x] [[Calibration Is Behavioral, Not Explicit]] · [x] [[Every Twin Surface Is a Calibration Opportunity]]
- **Process** — [x] [[60 Minutes to a Working Agent]] · [x] [[The Agent IS the Spec]] · [x] [[Self-Documenting Handoff]]
- **Manifestos** — [x] [[The Engine Stays Small]] · [x] [[Three Tiers, One Model]] · [x] [[Roots Are Public Surfaces]]

### Phase 3 — Foundational notes the original list missed ✅

- [x] [[Glossary]] — every domain term with one paragraph plus links to the deep posts.
- [x] [[How to Read This Vault]] — meta-note for first-time visitors.
- [x] [[The Platform in 90 Seconds]] — the elevator pitch as a vault entry.
- [x] [[Tier 1 — Local Brainstem]]
- [x] [[Tier 2 — Cloud Swarm]]
- [x] [[Tier 3 — Enterprise Power Platform]]
- [x] [[The Sacred Constraints]] — six (not three) constraints; the new CLAUDE.md added single-file services and the agent-first rule.
- [x] [[Constitution Reading Order]] — annotated walk through the 24 articles.
- [x] [[Major Moments]] — public, code-anchored timeline (not personal dates).

### Phase 4 — Reading paths (Maps of Content) ✅

- [x] [[Reading Path — Engineer Evaluating RAPP]] (8 notes)
- [x] [[Reading Path — Architect Deciding to Bet]] (6 notes)
- [x] [[Reading Path — Partner Pricing a Project]] (5 notes)
- [x] [[Reading Path — Exec Asking What This Is]] (3 notes)
- [x] [[Reading Path — New Contributor]] (7 notes + the constitution)

### Phase 5 — Viewer polish (`pages/vault/`) ✅

- [x] Keyboard nav: `j`/`k` next/prev, `/` focus search, `g i` jump to index, `r` random note, `m` reading, `g` graph, `o` Obsidian, `?` hint.
- [x] Per-heading anchor links + copy-link buttons.
- [x] *Open in Obsidian* button using the `obsidian://` URI scheme.
- [x] Mobile breadcrumb header + slide-in nav so the sidebar doesn't dominate.
- [x] Reading-mode toggle (wider line length, larger type).
- [x] Visual graph view — vanilla SVG, notes as nodes, wikilinks as edges, hover-to-highlight neighbors.

### Phase 6 — Link checker + PII guard ✅

- [x] `tests/vault-check.mjs` — walks every note, extracts every `[[wikilink]]` (skipping code spans), asserts every target resolves, validates frontmatter, scans for PII patterns (email regex, real-name fragments) and fails on any match.
- [x] Wire it into the test suite alongside `tests/e2e/08-html-pages.sh` — `node tests/vault-check.mjs` runs cleanly.
- [ ] Add a `make vault-check` (or equivalent) that runs only this script for fast local feedback. *(deferred — current `node tests/vault-check.mjs` invocation is already terse.)*

### Phase 7 — Tie back into the rest of the repo ✅

- [x] `README.md` gets a "The vault" section pointing to `pages/vault/` and the reading paths.
- [x] `pages/docs/SPEC.md` audience-one-pagers table gets a sibling table pointing to vault notes.
- [x] Marketing pages (10 of them in `pages/`) link to the vault via the existing `sr-only` nav.
- [x] `index.html` (the GitHub Pages landing) gets a visible "Read the vault ↗" link in the alt-CTA row.
- [ ] `pitch-playbook.html` gets a "What's behind this?" link to the vault. *(deferred to a follow-up — the playbook's narrative would need a custom slot rather than a generic nav append.)*

### Phase 8 — Final pass ✅

- [x] Run `tests/vault-check.mjs` — 46 notes, 570 wikilinks, all resolve. No PII.
- [x] Run `tests/e2e/08-html-pages.sh` — marketing pages still pass (76 content checks).
- [ ] Manually open the vault in Obsidian and verify entry sequence makes sense to a stranger. *(can't be done here; left for the maintainer.)*
- [x] Verify the static viewer renders every note without errors (relative-path fetches all return 200; JS parses cleanly).
- [x] Update [[Documentation Roadmap]] with the build-out's completion entries.
- [x] Append the build-out completion to [[Release Ledger]].

## Notes & decisions

*Append-only log of decisions made during the build, lessons discovered, and questions that came up. Each entry: short date stub, one line of context, one line of decision.*

- **2026-04-24** · Decided the vault lives at `vault/` at repo root rather than `docs/vault/` so that "Open folder as vault" in Obsidian targets a clean root. Codified in [CONSTITUTION](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md) Article XXIII and Article XVI repo-root allowlist.
- **2026-04-24** · Decided the viewer fetches same-origin relative paths first, falls back to `raw.githubusercontent.com`. Reason: works locally before push, works on GitHub Pages, works when embedded off-domain. See `pages/vault/vault.js` `fetchNote()`.
- **2026-04-24** · Decided to use status frontmatter (`stub` / `published` / `living`) over filename suffixes — keeps the filename clean for Obsidian wikilinks and lets the viewer style the dot in the sidebar.
- **2026-04-24** · The link checker strips fenced code blocks and inline code spans before extracting wikilinks. Reason: literal references like `` `[[wikilinks]]` `` in prose were being treated as broken links. The strip is the right behavior — code spans are not graph edges.
- **2026-04-24** · Cross-vault references to files outside the vault (e.g. `CONSTITUTION.md`) use standard markdown links to GitHub URLs, not wikilinks. Wikilinks resolve only within the vault by design; out-of-vault references must be honest.
- **2026-04-24** · The new CLAUDE.md (post-restructure) lists **6** sacred constraints, not 4. Added single-file services and the agent-first rule. The vault's [[The Sacred Constraints]] note was rewritten to match.
- **2026-04-24** · Repo restructure landed mid-build: `installer/` for one-liners + the Tier 3 Studio bundle, `pages/docs/` for governance. Briefly tried `rapp_studio/` for the bundle, then folded into `installer/` — a `.zip` is an install artifact, not running code, so a tier directory was overfitting (see [[Repo Root Reorganization 2026-04-24]]). Vault notes were updated for the new paths via Edit tool; the install URL changed from `RAPP/install.sh` to `RAPP/installer/install.sh`.

## Related

- [[Documentation Roadmap]]
- [[Release Ledger]]
- [CONSTITUTION](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md) Article XXIII
