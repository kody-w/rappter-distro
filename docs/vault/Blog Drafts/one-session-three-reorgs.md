---
title: One session, three reorgs — a real-time view of design iteration
status: shipped
published_url: https://kody-w.github.io/2026/04/24/one-session-three-reorgs/
section: Blog Drafts
hook: A directory created in the morning, removed in the afternoon. A doc moved into a subfolder, then restored to root. A vault split into two paths, then unified. From the inside it felt chaotic. The diff is clean. Here's what each reversal taught.
date: 2026-04-24
class: timely
decay: high
---

# One session, three reorgs — a real-time view of design iteration

Most write-ups of project decisions are retrospectives. They're written after the dust settles, the diff is clean, and the maintainer has a coherent story about what was decided. The story is true at that point but it's smoothed — the false starts have been edited out, the reversals presented as confident moves, the iteration disguised as a single decision.

This is the un-smoothed version, written during the same session it describes. It documents three deliberate reversals — *we moved this, then unmoved it; we created this directory, then folded it into another; we split this into two surfaces, then merged it into one* — and what each reversal taught.

The point isn't *we made mistakes.* The point is that **session-scale design iteration is the right shape for shaping a project's foundations**, and the reversals are evidence the shape is working — not evidence it's broken.

## Reversal 1 — the Tier 3 directory that lasted half a day

**Morning:** The repo's root was bloated. A constitutional cleanup moved install scripts into `installer/`, governance docs into `docs/`, and the Microsoft Power Platform `.zip` (a Tier 3 Copilot Studio bundle) into a new `rapp_studio/` directory at root. Three tier directories, three numbered tiers, visible symmetry.

**Afternoon:** The user looked at the new layout and said: *"put the rapp studio under the installer. We don't need it to have its own folder. It just needs a place on the public github repo for people to pull down."*

That sentence dissolved the symmetry argument. We folded `rapp_studio/MSFTAIBASMultiAgentCopilot_*.zip` into `installer/MSFTAIBASMultiAgentCopilot_*.zip`, deleted the empty directory, rewrote the Constitution amendment, rewrote the vault note. The empty directory had existed for about eight hours.

**The lesson:** *A directory at root earns its place by holding running code. An artifact does not earn a directory just because it completes a numbered list.*

The pull toward symmetry was strong. *Three tiers, three folders, same shape.* The pull was wrong because it would have created a one-file directory whose only justification was completing a sequence. Tier 1 has running code. Tier 2 has running code. Tier 3 runs in Microsoft's cloud, not in this repo — what ships here is a download. Downloads don't earn directories.

Article XVI of the Constitution now spells this out: *"code earns a directory; artifacts don't."* The lesson is in the rule. The rule prevents the next contributor from re-creating `rapp_studio/` because they think it would tidy things up.

## Reversal 2 — CONSTITUTION.md to docs/, and back

**Mid-session:** The cleanup moved `CONSTITUTION.md` from root into `docs/CONSTITUTION.md`, alongside SPEC.md, ROADMAP.md, AGENTS.md. The reasoning was clean: governance and reference are both "long-form contracts written for contributors"; they can live together in a documentation directory.

**Same session:** The user said: *"reoutput the constitution as the root... that is important."*

We moved it back. The Constitution is now at root, peer to README.md. Article XVI got an explicit "what's at root and why" entry that names CONSTITUTION.md as load-bearing root residence:

> Governance is part of the catalog card, not reference material. GitHub recognizes top-level governance files (LICENSE, CODE_OF_CONDUCT, CONTRIBUTING) as community-standards anchors; this article holds CONSTITUTION.md to the same level. A visitor who lands on the repo page sees *what this is* (`README.md`) and *the rules it lives by* (`CONSTITUTION.md`) at the same scroll depth.

**The lesson:** *Which docs sit at root is a positioning decision, not just a tidiness decision.*

The two-second test from the [[Roots Are Public Surfaces]] manifesto applies here. A visitor landing on the repo page should see, in two seconds, *what this is* and *that this project takes its rules seriously.* If the constitution is buried under a `docs/` click, the seriousness signal is buried with it. The trade isn't *clutter vs. organization.* The trade is *the visitor's first impression vs. tidy taxonomy.* First impression wins.

The reversal taught a finer-grained version of Article XVI: not just *what belongs at root* (the closed list), but *why root residence is a positioning act, not an organizational one*.

## Reversal 3 — vault data and viewer, in one directory

**Mid-session:** The vault — the project's long-form decision narratives — lived at `vault/` in the repo root. The static SPA viewer that renders the same notes for browser visitors lived at `pages/vault/`. Two surfaces, one for the data, one for the rendering. The split read clean in Article XXIII of the Constitution.

**Same session:** The unifying rule articulated itself: *"anything served from GitHub Pages lives somewhere under `pages/`."* That rule directly contradicted the data-at-root, viewer-under-pages split.

We moved the entire vault into `pages/vault/` so the data and the viewer share one directory. The viewer's path resolution simplified (it now reads sibling markdown instead of cross-directory). The Constitution's two-surface section was rewritten to *two faces, one directory*. Both faces preserve their job; they just live together now.

**The lesson:** *When a unifying rule emerges, apply it everywhere — even if it contradicts a previous decision that worked.*

The two-surface split worked. There was nothing operationally wrong with it. But the split *implied* that the data and the rendering were different categories of thing — and once we wrote the rule *"anything served lives in `pages/`,"* the split became contradictory. The rule won; the split moved.

This pattern is worth naming explicitly: **rules emerging mid-session sometimes invalidate earlier decisions in the same session.** Apply the rule. The earlier decision was the experiment that produced the rule; the rule is the lesson that emerged from the experiment. Holding to the earlier decision because it was already made is sunk-cost reasoning — and at the structural level, it's actively harmful, because every contradiction with the rule produces a future cleanup.

## Why three reversals look like progress, not chaos

A diff at the end of the session, viewed by someone who wasn't in it, looks like a clean reorganization with a coherent thesis. The reorgs that didn't survive are invisible — they're temporary states between commits, not artifacts in the final tree. From the outside, the work looks decisive.

From the inside, the work was *iterative.* Each reversal was a small experiment that produced a sharper rule. Each rule made the final shape more correct than the rule that came before. The reversals weren't bugs; they were the mechanism by which the shape converged.

Three things make this iteration shape produce good outcomes instead of churn:

**1. The session is short enough that the iteration cost is low.** A reversal made in the same hour costs an hour. A reversal made the next month costs a month — because everyone has built mental models on the old state, and unbuilding those is its own work. Session-scale iteration is the cheapest design surface.

**2. Each rule that emerges gets memorialized immediately.** The Constitution amendment for *code earns a directory* was written before the session ended. The vault note explaining the unification of vault data + viewer was published the same day. Future sessions don't have to re-derive these lessons; they're already rules.

**3. The iteration is visible only when documented as iteration.** The smoothed retrospective hides the reversals; the live capture exposes them. Both are true accounts; the live one is more useful for the next person facing a similar decision, because they see the *path* that produced the answer, not just the answer.

## What this reads like to a stranger

Someone reading the project's `CONSTITUTION.md` six months from now will see Article XVI's "what this rules out" section memorialize the rapp_studio reversal: *"was briefly placed in `rapp_studio/` on 2026-04-24 and folded back into `installer/` the same day."* They'll see Article XXIII's "two faces, one directory" framing, with a wikilink to the [[Repo Root Reorganization 2026-04-24]] vault note that explains the unification.

Both memorials are short. Both are pinned in the most-read documents in the project. The lesson is impossible to miss; the iteration that produced it is right there in the prose. A future contributor tempted to re-create `rapp_studio/` for symmetry, or to split the vault data from the viewer for cleanliness, reads the memorial and reconsiders. The rule did its job; the iteration that produced the rule is preserved as proof that the alternative was tried.

That's the deliberate output of session-scale iteration: not just the right shape, but the *visible reasoning* for why other plausible shapes are wrong. The reversals are the receipts.

## What to do with this if you're shaping a project

Three habits worth adopting:

**Treat reversals as data, not failure.** A reorg that didn't survive a session is the cheapest kind of disconfirmation. You learned the shape doesn't fit, in hours instead of months. Capture the lesson; don't hide the reversal.

**Memorialize immediately.** Don't wait for the retrospective. Vault notes, constitutional amendments, README changes — write them in the same session that produced the lesson. Future-you will be grateful.

**Look for unifying rules.** The most leverage in a session comes from rules that emerge late and apply broadly. *"Code earns a directory."* *"Anything served lives in pages/."* When one shows up, apply it everywhere — even if it contradicts decisions made an hour earlier.

## Receipts

- The session itself: 2026-04-24, captured live in [[Repo Root Reorganization 2026-04-24]] under `pages/vault/Architecture/`.
- Article XVI's *code earns a directory* clause: [`CONSTITUTION.md`](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md), the "what this rules out" section.
- Article XXIII's *two faces, one directory* framing.
- The constitutional amendments that landed during the session: visible in `git log` between commits 2026-04-24.

The platform's working knowledge: *session-scale iteration is the right shape for shaping foundations.* The reversals aren't noise. They're the mechanism. Capture them, memorialize the lessons, and let the next contributor read the receipts.

This post will age fast — the iteration it describes is specific to one session. The pattern it documents is the part that doesn't decay.
