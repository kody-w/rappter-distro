---
title: Two cleanups in one week — when the constitutional rule pays off
status: shipped
published_url: https://kody-w.github.io/2026/04/24/two-cleanups-one-week/
section: Blog Drafts
hook: We wrote the rule about repo-root residence before the bloat. Five days later we applied it twice. The post that doesn't get written: the third cleanup that didn't have to happen.
date: 2026-04-24
sources:
  - "[[Roots Are Public Surfaces]]"
  - "[[Repo Root Reorganization 2026-04-24]]"
class: semi-evergreen
decay: medium
---

# Two cleanups in one week — when the constitutional rule pays off

Most projects accumulate root-level junk because nobody wrote down what *should* be at the root. The repo grows; new files land where they're easy to drop; nobody notices until the directory listing scrolls past two screens on GitHub. Then, occasionally, someone files an "organize the repo" PR. The PR lands. Six months later the root is bloated again.

The pattern is predictable enough to be worth disrupting. We did. This is the field report.

## What happened

The rule landed in mid-April: Article XVI of the project's CONSTITUTION, *"the root is the storefront, not the junk drawer."* It enumerates the closed list of files and directories that earn root residence and explicitly bans new arrivals: marketing pages go in `pages/`, install scripts go in `installer/`, reference docs go in `pages/docs/`, decision narratives go in `pages/vault/`. New top-level directory? Justify it the same way you'd justify a new wire-protocol slot.

Five days later, two cleanups landed in the same session. The first move re-homed ten audience HTML files into sectioned subdirectories. The second re-homed governance docs and install scripts. Both passes were one-shot — drop the file in the right place, update internal references, done.

That's the rule paying off. The interesting part isn't the cleanups; it's the cleanup that *didn't* have to happen because the rule was already there.

## The pull toward bloat

Repo root is the path of least resistance. When you're prototyping a new feature and you want a quick `notes.md` next to your work, root is the easiest place to put it. When you're adding a new install script and there's already an `install.sh`, sticking `install-mac.sh` next to it feels obvious. When the marketing team wants a new audience page and the previous one is at root, they'll put theirs at root too.

None of these decisions are wrong individually. They're each rational. The aggregate is bloat — and once bloat exists, the cost of not-fixing-it is a permanent visual signal to every visitor that this project is unfinished.

The rule we wrote spelled out exactly *which* easy paths were forbidden, and what easy path replaced each one:

- New marketing page → `pages/<section>/<file>.html`. Not root.
- New auxiliary doc → `pages/docs/<file>.md`. Not root.
- New install file → `installer/<file>`. Not root.
- New decision narrative → `pages/vault/<section>/<file>.md`. Not root.
- New top-level directory → only with running code in this repo, and only with a `README.md` declaring its scale rule.

The pattern is *don't say "no" without saying "yes here instead."* The rule names a destination, every time.

## Two passes, no overlap

The first pass moved ten audience HTMLs from flat root-level files into `pages/`. The og:url of every moved page got updated. Test fixtures that enumerated the old paths got rewritten. A page that had been at `pages/leadership.html` was now at `pages/about/leadership.html`. The session note for that change wrote itself: *"this is what Article XVI looks like applied for the first time."*

The second pass — five days later, same week — moved install scripts (`install.sh`, `install.ps1`, `install.cmd`, `install-swarm.sh`, `start-local.sh`, `azuredeploy.json`) from root into `installer/`, and moved governance docs (`SPEC.md`, `CONSTITUTION.md` briefly, `ROADMAP.md`, `AGENTS.md`, `VERSIONS.md`) into `docs/`. Same shape: the rule pointed at the destinations; the cleanup applied the rule.

Neither pass introduced surprise paths. Neither pass required arguing about *whether* the move was correct — just verifying that the references all updated. The Constitution had pre-decided the destination.

## The post that doesn't get written

The pattern this prevents is the third cleanup. Without the rule, this is what would have happened:

- Week 1: someone adds `notes-on-X.md` next to `README.md`, "just one more."
- Week 4: someone adds `mobile-install.sh` next to `install.sh`, mirroring the existing pattern.
- Week 8: someone adds `LEADERSHIP.html` because the previous marketing page was at root.
- Week 16: bloat is real. Someone files an "organize the repo" PR.
- Week 17: the PR is contentious because there's no agreed-upon scheme.
- Week 20: the cleanup lands, often as a compromise that solves only half the problem.
- Week 28: bloat is back, because the *decisions* that produced it weren't memorialized as a rule.

What we got instead: zero contention. The rule was the answer. The cleanup was mechanical. The decision had already been made, in writing, before the bloat appeared. When the second cleanup happened, the rule had already been applied once successfully, so the path was visible.

## The lesson generalizes

This isn't really about repo organization. It's about writing rules ahead of the situations they prevent — when the cost of writing them is low (a slow Saturday, a quiet sprint) instead of when the cost of fixing the resulting mess is high (a chaotic PR, a dispute about *should we* before *how should we*).

The pattern works in code review style guides, in API design conventions, in product copy guidelines. Anywhere a small daily decision compounds into a visible mess if you let it. *The rule comes first. The mess never happens. The post about the mess doesn't have to be written.*

The "engine, not experience" project that lives behind this article has a Constitution with twenty-four articles. Article XVI is the one we exercise most often. It pays for itself every time a visitor lands on the GitHub page and sees a clean directory listing — and didn't have to be told why it looks that way.

## Receipts

- The article: `CONSTITUTION.md` Article XVI in [github.com/kody-w/RAPP](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md).
- First pass (audience HTMLs → `pages/`): commits between 2026-04-19 and 2026-04-24.
- Second pass (install scripts + governance docs): 2026-04-24 single session.
- The vault note that captures the why: [[Repo Root Reorganization 2026-04-24]] in `pages/vault/Architecture/`.

The rule wrote the cleanup. The cleanup wrote nothing back to the rule.
