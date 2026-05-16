---
title: Repo Root Reorganization 2026-04-24
description: The day we collapsed thirteen root files into a clean storefront, then doubled back on tier symmetry to learn that artifacts don't earn directories — only running code does.
status: published
date: 2026-04-24
session_id: 63243848-caa9-483c-9a8e-9bb0ee9d2849
session_date: 2026-04-24
section: Architecture
related:
  - "[[The Sacred Constraints]]"
  - "[[Why Three Tiers, Not One]]"
  - "[[Engine, Not Experience]]"
  - "[[Roots Are Public Surfaces]]"
  - "[[Tier 3 — Enterprise Power Platform]]"
---

# Repo Root Reorganization 2026-04-24

The repo root was bloated. Thirteen-ish files at the top level,
scrolling past the directory listing on GitHub. Article XVI of the
Constitution had been preaching *the root is the storefront, not the
junk drawer* for months while the root looked like a junk drawer. We
fixed that today — and then immediately re-fixed half of it, because
the first pass overfit a tier symmetry that didn't actually exist.

## What was at root that shouldn't have been

| Root file (before)                        | Final home (after the second pass)                           |
|-------------------------------------------|--------------------------------------------------------------|
| `install.sh`                              | `installer/install.sh`                                       |
| `install.ps1`                             | `installer/install.ps1`                                      |
| `install.cmd`                             | `installer/install.cmd`                                      |
| `install-swarm.sh`                        | `installer/install-swarm.sh`                                 |
| `start-local.sh`                          | `installer/start-local.sh`                                   |
| `azuredeploy.json`                        | `installer/azuredeploy.json`                                 |
| `MSFTAIBASMultiAgentCopilot_1_0_0_5.zip`  | `installer/MSFTAIBASMultiAgentCopilot_1_0_0_5.zip`           |
| `SPEC.md`                                 | `pages/docs/SPEC.md`                                               |
| `CONSTITUTION.md`                         | `CONSTITUTION.md` (stayed at root — see below)               |
| `ROADMAP.md`                              | `pages/docs/ROADMAP.md`                                            |
| `AGENTS.md`                               | `pages/docs/AGENTS.md`                                             |
| `VERSIONS.md`                             | `pages/docs/VERSIONS.md`                                           |

The two new conventions that came out of this:

- **`installer/` is the public install surface.** It already
  contained the Pages-served install widget (`installer/index.html`).
  Adding the launchers, the ARM template, and the Tier 3 Studio
  bundle here grouped every public-URL-anchored install artifact in
  one place. The public install URL changed from
  `kody-w.github.io/RAPP/install.sh` to
  `kody-w.github.io/RAPP/installer/install.sh`.
- **Each kept top-level subdirectory has a `README.md` that
  documents its local scale rule.** `pages/docs/`, `pages/`, `installer/`,
  and `tests/` each got a README. The repo-root rule (Article XVI)
  is the spine; the per-directory README is the rib. Future
  contributors don't have to grep the constitution to know where a
  new file goes — they read the README of the directory they're
  about to add to.

## The course-correction (this is the load-bearing lesson)

The first pass created `rapp_studio/` and put the Tier 3 Power
Platform `.zip` there. The pitch was *three-tier symmetry visible at
root*: `rapp_brainstem/` (T1), `rapp_swarm/` (T2), `rapp_studio/` (T3).

That was wrong, and we caught it in the same session.

The fix was to move the `.zip` into `installer/` alongside the install
scripts and delete the empty `rapp_studio/` directory. The reason:

> **A directory at root earns its place by holding running code.
> An artifact does not earn a directory just because it completes a
> numbered list.**

Tier 1 is a directory because Flask + agents *run in this repo*.
Tier 2 is a directory because the Azure Functions code + ARM-deploy
target *run in this repo* (well, vendored from Tier 1 and deployed
out of it). Tier 3 is *not* a directory in this repo because nothing
in this repo runs Tier 3 — Microsoft Copilot Studio runs Tier 3, in
Microsoft's cloud. What this repo ships for Tier 3 is a downloadable
bundle. A downloadable bundle is an install artifact. Install
artifacts live in `installer/`.

The pull toward symmetry was strong: *three tiers, three directories,
visible at root, easy to teach.* The pull was wrong because it would
have created a one-file directory (`rapp_studio/MSFT...zip`) whose
job is to be downloaded, not to host code. That's exactly the
"directory because nothing else fits" failure mode Article XVI bans.
The right symmetry is *one home for downloads*, not *one directory
per tier number*.

This was the second cleanup applied to root in the same week (the
first being the move of audience HTML into `pages/`). Two consecutive
passes against the same surface, each removing things — that's the
constitutional rule paying off, but it also says the rule needs to be
sharper than just "don't bloat root." The amended Article XVI now
spells out: **code earns a directory, artifacts don't.**

## What stayed at root, and why each one earned it

- `.claude/`, `.github/`, `.vscode/`, `.gitignore`, `.nojekyll`,
  `.env` — tooling and git require these at root.
- `README.md` — GitHub renders it on the repo landing page.
- `CONSTITUTION.md` — peer of `README.md`. Briefly moved to
  `CONSTITUTION.md` on 2026-04-24 and restored same session.
  The reason for the restoration: governance is *part of the catalog
  card*, not a reference doc. GitHub treats top-level governance
  files (LICENSE, CODE_OF_CONDUCT, CONTRIBUTING) as community-
  standards anchors; a constitution at the same scroll depth as the
  README signals seriousness about the rules to a first-time
  visitor. Burying it inside `pages/docs/` made it look like reference
  material, which it isn't — it's the *contract* the repo lives
  by. The third reorg pass was triggered by the user's one-line
  feedback: *"reoutput the constitution as the root… that is
  important."* Lesson: which docs sit at root is a positioning
  decision, not just a tidiness decision.
- `CLAUDE.md` — Claude Code reads project instructions from the
  project root.
- `index.html` — GitHub Pages serves it as the site's landing page.
- `pitch-playbook.html` — **the only grandfathered marketing
  exception**. Its public URL has been shared externally with
  partners. Moving it would break those links. New audience HTML
  always goes in `pages/`; this one stays at root by exception,
  not by precedent.

The kept directories at root are the closed list:
`pages/docs/`, `installer/`, `pages/`, `rapp_brainstem/`, `rapp_store/`,
`rapp_swarm/`, `tests/`, `vault/`, `worker/`. Nine. Each one is
self-documenting via its own README (or its constitution, in the
brainstem's case).

## Why this work happened today

The user's exact phrase was: *"this is our one chance to move
things."* The platform has no public users yet, no curl-from-the-wild
installs to break. Every URL we'd otherwise have to grandfather is
still ours to update. After the first install hits a stranger's
machine, every legacy path becomes load-bearing — see
[[Why GitHub Pages Is the Distribution Channel]] for the same logic
applied to the install one-liner. The move-debt window is closing
and we used it.

## What this rules out, going forward

This reorganization isn't a one-off. It encodes a discipline that's
now load-bearing:

- New install-related file → `installer/`. Not root, not a new
  top-level directory.
- New downloadable bundle (Studio version, alternate platform
  install) → `installer/`. Not a new tier-shaped directory.
- New running-code tier → its own `rapp_<name>/` directory at root,
  but only when there's a cohesive body of code that *runs in this
  repo*. A bundle a customer downloads is not running code.
- New audience page → `pages/<file>.html`. Not root. (Yes, even if
  the previous one happened to land at root historically.)
- New auxiliary doc → `pages/docs/`. Not root.
- New top-level subdirectory → must ship with a `README.md` that
  states its local rule of residence. No README, no directory.

Article XVI was amended in the same change to make this list the
*floor* of root residence, not a starting point that grows. The
amended article also memorializes this note as the why behind the
floor.

## What was hard about the move

Two things bit us:

1. **A perl one-liner with `|` as both delimiter and content.** The
   `s|...|...|` substitution pattern collided with literal pipes in
   markdown table rows being replaced. `pages/docs/SPEC.md` got duplicated
   on every line before we caught it. We restored from
   `git show HEAD:SPEC.md` and re-applied the targeted edits via the
   `Edit` tool. **Lesson:** when content contains the character you'd
   use as a sed/perl delimiter, switch to a delimiter the content
   can't reach. `s#...#...#` would have been fine.
2. **`git mv` over files with unstaged modifications.** The original
   files had unstaged edits when we moved them, which split the
   rename detection across staged-add and unstaged-delete. The
   moves are coherent, but `git status` shows split state until
   `git add -u` finalizes the renames. Confirmed by stash-test that
   nothing was actually broken — just untidy.

## Related

- [[The Sacred Constraints]] — the discipline this strengthens.
- [[Why Three Tiers, Not One]] — the tier shape, including why
  Tier 3 is not a directory in this repo.
- [[Engine, Not Experience]] — the catalog-card root is the engine
  story; a junk-drawer root is the experience story.
- [[Roots Are Public Surfaces]] — the manifesto behind the rule.
- [[Tier 3 — Enterprise Power Platform]] — explains where the
  Studio bundle lives now and why.
- Article XVI of `CONSTITUTION.md` — the rule this honors and
  amends.
