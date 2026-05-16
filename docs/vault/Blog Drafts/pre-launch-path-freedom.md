---
title: Pre-launch path freedom — what to change before the first stranger arrives
status: shipped
published_url: https://kody-w.github.io/2026/04/24/pre-launch-path-freedom/
section: Blog Drafts
hook: Five separate "no users yet, do it now" decisions in a single working session. The window for changing your mind without permission closes the moment a stranger relies on a path. Here's what we used the window for.
date: 2026-04-24
class: timely
decay: high
---

# Pre-launch path freedom — what to change before the first stranger arrives

Software projects have a window most maintainers never deliberately use: the time between *we built it* and *someone else relies on it.* During that window, paths can move, URLs can change, file shapes can be rearranged, and the only people inconvenienced are the ones already in the room. After the window closes — after the first stranger pins your URL in their notes, runs your install command from a tutorial that they bookmarked, mentions your repo in a Discord thread — every path becomes load-bearing.

The window closes silently. There's no notification. One day you check your repo's traffic and someone's been using it for a week, and now their bookmarks define what counts as a valid URL.

This is the field report from a single working session that deliberately spent the closing window. Five major decisions, all of which were enabled by *no users yet, do it now.* If we'd waited another quarter, each one would have cost ten times as much.

## The session

April 24, 2026. The repo had been functional for months. The platform philosophy was settled. The code worked. The directory listing was a mess. Two weeks earlier, a constitutional rule had been written about repo-root residence — but the messy reality hadn't been cleaned up yet.

The session opened with the user saying, in effect: *we have one chance to move things. After this, every path is load-bearing.* That framing produced five concrete decisions, each in the form *"this would be expensive after launch; let's do it now."*

## The five decisions

**1. Move ~10 install scripts and ARM templates from repo root into `installer/`.**

Before: `https://kody-w.github.io/RAPP/install.sh`. After: `https://kody-w.github.io/RAPP/installer/install.sh`.

Cost after launch: every README, every blog post, every Slack pin, every cached install command pointing at the old URL. Some of these we'd find; some we'd never find. Worst case: a user runs the old curl, gets a 404, blames the project, and never tries again.

Cost during the window: an in-repo grep, a perl-replace across ~15 files, plus a redirect (or just no redirect, since nobody had used it yet).

**2. Move 5 governance docs (`SPEC.md`, `ROADMAP.md`, `AGENTS.md`, `VERSIONS.md`) from repo root into `docs/`, then later into `pages/docs/`.**

Before: `[SPEC.md](./SPEC.md)` from a README at root. After: `[SPEC.md](./pages/docs/SPEC.md)`.

Cost after launch: every external link to `SPEC.md` (in tutorials, in vendor reviews, in academic citations). Specifications get cited; cited URLs are immortal.

Cost during the window: a relative-path sweep, plus updating the in-repo cross-links.

**3. Section flat audience HTMLs (`pages/faq.html`, `pages/leadership.html`, ...) into `pages/about/`, `pages/product/`, `pages/release/`.**

Before: `https://kody-w.github.io/RAPP/pages/faq.html`. After: `https://kody-w.github.io/RAPP/pages/product/faq.html`.

Cost after launch: same as the install URL — every cached or shared link. Marketing pages get linked from social media, from email campaigns, from sales decks.

Cost during the window: 10 file moves, og:url + canonical updates, ~70 line e2e test fixture rewrite. Done in 20 minutes.

**4. Restructure the entire `pages/` directory to be a real audience site with shared chrome, a docs viewer, a vault renderer, and section subdirectories.**

This wasn't really a path migration; it was a structural change. But its blast radius is the same shape: cross-links from elsewhere in the repo, references in the test suite, mentions in the README. After launch, restructuring the site's information architecture would have meant reasoning about every external link to it.

Cost during the window: building `pages/_site/` shared infrastructure, refactoring the existing pages to use it, building new landing pages. About 2 hours of work in a single sitting.

**5. Move CONSTITUTION.md to `docs/` and then immediately back to root.**

This one is interesting because it was a non-decision: we tried moving it, the user said *"reoutput the constitution as the root... that is important,"* and we restored it. The lesson — *governance is part of the catalog card, not reference material* — is now memorialized in Article XVI. After launch, this kind of try-it-and-revert costs cycles you don't have. Pre-launch, it's just a learning iteration.

## Why these decisions were possible

The common factor across all five: *no public dependency on the existing path*. Specifically:

- No external blog post linking to `https://kody-w.github.io/RAPP/install.sh`.
- No tutorial citing `SPEC.md` at the root URL.
- No bookmark on a partner's machine pointing at `pages/leadership.html`.
- No Slack pin with a curl command.
- No cached crawler entry indexed at the old URL.

We knew this because the platform had no public users yet. We had access logs (nobody hitting the URLs). We had no support inbox (nobody asking us anything). The pre-launch state was verifiable, not assumed.

That verifiability matters. The window doesn't close *gradually* — it closes the moment a single external party starts depending on a URL. After that, you're in URL-debt territory: you can change paths, but the cost is now non-zero, and it grows with every new dependency.

## The mental model

The most useful framing of the window: *every path you ship is a promise to a stranger.* Pre-launch, you haven't made any promises yet. Post-launch, every URL is a promise. The window is the time when promises are still your choice to make.

Three implications:

**Be deliberately maximalist with the window.** It's the cheapest restructuring time the project will ever have. Use it.

**Don't ship unfinished URL shapes.** Every URL you publish is a commitment. If you're not sure the URL is right, don't publish it yet.

**Document the close of the window.** The moment a stranger arrives — when your access logs show traffic from outside the team, when someone files an issue, when a tutorial cites you — write that down. It's the project's transition from "internal" to "promised." From that day forward, path debt costs real currency.

## What we didn't change

Equally important: things we considered changing and chose not to.

**`pitch-playbook.html` at the repo root.** Its URL had been shared externally with partners. Even though it violates the rule that says marketing HTML lives in `pages/`, moving it would have broken shared links. The Constitution memorializes this as the *only* grandfathered exception, with the explicit framing that future audience pages always go in `pages/` — *this is the only marketing HTML at root, by exception rather than by precedent.*

That's a clean way to handle the inevitable exceptions: name them, justify them, bound them. The grandfathering doesn't extend to new files.

**Brainstem version pinning (`BRAINSTEM_VERSION=0.11.6`).** The project's release tags are immutable per Article XIX. Even pre-launch, *re-tagging* a release is forbidden — because the rollback contract is what makes the install one-liner trustworthy long-term. So while the window allows path changes, it doesn't allow tag changes. The two are different categories of commitment.

**External dependencies.** Pinned CDN URLs (marked.js@12.0.2, JSZip@3.10.1, etc.) — these are someone else's promises, and we don't get to change them. The project's pre-launch window doesn't cover other projects' post-launch state.

## The post-launch playbook

When the window closes (and it will, soon for this project), the rules invert:

- **Path changes require redirects.** A 301 from the old URL to the new one. Maintained for the lifetime of the path.
- **URL renames are deprecations.** Announce, hold both for a release cycle, then retire the old. Article XIX-style discipline.
- **Restructuring is a project, not a session.** The "single working session that fixed everything" approach won't work; instead, each move costs investigation (who relies on this?) and notification (we're moving it, here's where it goes).
- **The Constitution's exclusion lists become more important, not less.** Pre-launch, the rule prevents bloat. Post-launch, the rule prevents path *changes* — because every changed path is a broken promise.

## The single-most useful thing to do during the window

Of the five decisions in this session, the highest-leverage one was *writing the Constitution before applying it.* The rule for repo-root residence existed before the cleanup happened. That meant the cleanup was mechanical: drop the file in the place the rule says, update the references, done. No debate.

If the rule had been written after the cleanup, every future cleanup would have to re-derive the destination. With the rule in place, future cleanups are mechanical too — and the cost of a third or fourth cleanup is just the cleanup itself, not the cleanup *plus* the meta-discussion about what the right shape is.

That's the actual leverage. Not "we moved files cheaply because nobody was using them." Bigger: *we wrote the rule that makes future moves cheap, and we wrote it during the window when even the rule itself could be iterated on freely.*

## Receipts

- The five moves landed in the session of 2026-04-24, captured in [[Repo Root Reorganization 2026-04-24]].
- Article XVI of [`CONSTITUTION.md`](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md) — the rule that the cleanup applied.
- Article XIX — the immutable-tag rule that bounds the window's scope.
- The grandfathered exception (`pitch-playbook.html`) — explicitly memorialized.

The platform's working knowledge: *the pre-launch window is the cheapest restructuring time you'll ever have. Use it deliberately. Document its closing. Plan for the post-launch reality where every path is a promise.*

This post itself ages out the moment the project has its first public user. By the time you're reading it, the window may already be closed. The lesson — *write the rule before you need it, and apply it while you can* — is the part that doesn't decay.
