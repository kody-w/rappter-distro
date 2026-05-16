---
title: Roots Are Public Surfaces
status: published
section: Manifestos
hook: Every root is a catalog card — repo root, brainstem root, vault root. Bloat at the root signals "unfinished." Cleanups are constitutional.
---

# Roots Are Public Surfaces

> **Hook.** Every root is a catalog card — repo root, brainstem root, vault root. Bloat at the root signals "unfinished." Cleanups are constitutional.

## The principle

A *root* in RAPP terms is the top-level directory of any surface a stranger lands on:

- The **repo root** — what someone sees on github.com/kody-w/RAPP.
- The **brainstem root** (`rapp_brainstem/`) — what a Tier 1 user clones into.
- The **vault root** (`vault/`) — what someone opens in Obsidian.
- The **rapp store root** (`rapp_store/`) — what a community publisher catalogs against.

Each of these answers the question *"what is this?"* in seconds. The answer must be visible at a glance — a catalog card, not a junk drawer.

The principle:

> **Every root is a public surface. Every file there earns its place. Bloat at any root is the signal that the discipline lapsed.**

## Why roots matter

A root is the only piece of the project a first-time visitor reads in full. They scan it; they form an opinion; they decide whether to invest more time. If the root reads as 30 cleanly-grouped artifacts, the project looks finished and the visitor opens one. If the root reads as 60 ungrouped files, the project looks unfinished and the visitor leaves.

The asymmetry is hard to overstate. Project quality elsewhere doesn't matter if the root sends people away first. Conversely, a clean root creates the goodwill that keeps people reading even when deeper layers are messy.

This isn't aesthetics. It's funnel mechanics applied to the artifact itself.

## How bloat happens

Bloat at a root has a single dominant cause: **`git pull` lands new files at the top level, and nobody re-homes them.**

In April 2026, the repo root went from ~28 to ~40 entries in a single fast-forward pull, because the upstream branch had landed a dozen marketing HTML pages alongside the existing root files. The pages were good; their location was wrong. Each page individually felt harmless to leave at root. Together, they made the repo unreadable.

The fix took 30 minutes — `git mv` the pages to `pages/`, the auxiliary docs to `pages/docs/`, update the canonical URLs and tests, ratify the routing rules in CONSTITUTION Article XVI. The bloat had taken weeks to accumulate and minutes to clear, and the discipline became the constitutional rule.

The general pattern: **bloat is cumulative**, **cleanup is one-shot**. The constitution enforces the one-shot.

## The routing rules

For the repo root, CONSTITUTION Article XVI's allowlist is the rule:

| Goes at repo root | Doesn't |
|--|--|
| Tier directories (`rapp_brainstem/`, `rapp_swarm/`, `worker/`) | Marketing HTML pages → `pages/` |
| The catalog (`rapp_store/`) | Auxiliary markdown → `pages/docs/` |
| The long-term memory (`vault/`) | Long-form decision narratives → `vault/` |
| Cross-tier infra (`installer/`, `tests/`) | Anything else doesn't get a free root pass |
| Landing pages (`index.html`, `pitch-playbook.html`) | |
| Install one-liners (`install.sh`, `install.cmd`, `install.ps1`, `install-swarm.sh`, `start-local.sh`) | |
| Platform docs (`README.md`, `CLAUDE.md`, `CONSTITUTION.md`, `SPEC.md`, `AGENTS.md`, `ROADMAP.md`, `VERSIONS.md`) | |
| Deploy metadata (`azuredeploy.json`, the published Power Platform solution zip) | |
| Repo plumbing (`.gitignore`, `.nojekyll`, `.env.example`, `.github/`, `.vscode/`, `.claude/`) | |

For the brainstem root, the allowlist is similar but tighter (Article XVI's *original* form):

- The Flask server (`brainstem.py`).
- The default soul prompt (`soul.md`).
- Build/deploy metadata (`VERSION`, `requirements.txt`).
- The launchers (`start.sh`, `start.ps1`).
- The docs (`README.md`, `CLAUDE.md`, `CONSTITUTION.md`).
- The landing UI (`index.html`).
- The agent training surface (`agents/`).
- The shared utility directories (`utils/`, `web/`).

The vault root is governed by Article XXIII; the rapp store root by the manifest discipline of each catalog entry.

## What this rules out

- ❌ Dropping the next file at root because the previous one happens to be there. New files default to a subdirectory.
- ❌ "Adding `notes-on-X.md` next to README.md because it's just one more." Auxiliary docs go in `pages/docs/` or `vault/`.
- ❌ Hardcoding root URLs in moved files. When you relocate a page, update its `og:url`, `canonical_url`, and tests so the move is honest.
- ❌ A new top-level directory because nothing else fits. Justify the new directory the same way you'd justify a new top-level slot ([[Voice and Twin Are Forever]]).
- ❌ Treating `git pull` bloat as ratified. Re-home new files; don't accept their root residence by accident.

## Today as a worked example

The April 2026 cleanup is the canonical worked example, and the receipts live in the [[Release Ledger]]:

- 10 marketing HTMLs moved to `pages/`. Their `og:url` and `canonical_url` updated.
- 2 docs (`skill.md`, `rapplication-sdk.md`) moved to `pages/docs/`. The `skill.md` `canonical_url` updated.
- The test `tests/e2e/08-html-pages.sh` updated to use the new paths.
- `SPEC.md`'s audience-one-pagers table updated.
- CONSTITUTION Article XVI extended with the repo-root rules and the routing allowlist.
- CONSTITUTION Article XXIII added — *The Vault Is the Long-Term Memory* — declaring `vault/` as the home for accumulated wisdom and ratifying its place at root.

The cleanup was not large. The constitutional change was. The principle behind both was a single sentence:

> **The root is the catalog card, not the junk drawer.**

## What this enables

When roots stay clean:

- New visitors form correct first impressions in seconds.
- Contributors know where things go without reading every directory.
- Tests can grep against stable paths.
- Documentation can refer to canonical URLs that don't drift.
- The project looks finished even when its internals are mid-refactor.

## When the rule is most fragile

The rule is most fragile right after a `git pull` or a merge that lands many files at once. The cumulative effect of "each one feels small" is the failure mode. The discipline:

- After a large pull, **scan the root**. Anything that newly lives at root either belongs there per the allowlist, or moves immediately.
- "We'll clean up later" is the rule's enemy. Later doesn't come.
- The PR that lands the new files is the right place to also re-home them.

## When to grow the allowlist

The allowlist itself can grow — but only when a new top-level directory has earned its place. The bar is the same as for a new constitutional article:

1. The directory's role is clear in one sentence.
2. No existing directory could absorb its contents without distortion.
3. The platform commits to maintaining the discipline that keeps it clean.

`vault/` cleared this bar in 2026-04. The next directory to cross it will need its own justification, and its addition to the allowlist is itself a constitutional change.

## Discipline

- Open the repo root once a week. If something looks out of place, fix it.
- Before merging a PR that adds a top-level file, ask: *does this satisfy the allowlist, or should it move?*
- Cleanups are constitutional. The rule that ratifies the cleanup is more durable than the cleanup itself.

## Related

- [[Engine, Not Experience]]
- [[The Engine Stays Small]]
- [[Why GitHub Pages Is the Distribution Channel]]
- [[Documentation Roadmap]]
- [[Release Ledger]]
