---
title: Roots are public surfaces
status: shipped
published_url: https://kody-w.github.io/2026/04/24/roots-are-public-surfaces/
section: Blog Drafts
hook: A repo's root is not a folder. It is a storefront. The discipline that flows from that distinction is what separates a project that scales from one that quietly accumulates clutter.
date: 2026-04-24
sources:
  - "[[Roots Are Public Surfaces]]"
  - "[[Repo Root Reorganization 2026-04-24]]"
class: evergreen
decay: low
---

# Roots are public surfaces

There's a conversation happening on the GitHub repo page that the maintainers can't see and the visitor doesn't realize they're having. Within five seconds of landing, the visitor has read the directory listing, formed an opinion about whether this project is a serious thing or an experiment, and decided whether to keep scrolling. That's the conversation. The directory listing is doing the talking.

Most repos lose this conversation. Not because the project is bad — because nobody noticed the directory listing was speaking. Files accumulate at root because root is the easiest place to put them, and the resulting clutter signals "unfinished" to every visitor before they've read a single line of code.

The fix is to treat root as what it actually is: a public surface, with discipline that matches.

## What changes when you call it that

A surface has rules. A folder doesn't.

When the root is a folder, every new file is asking *"is there room for me here?"* The answer is almost always yes — there's always room for one more file in a folder. So the file lands at root. Repeat for two years. Bloat.

When the root is a surface, every new file is asking *"do I earn this real estate?"* The answer is mostly *no.* New marketing pages go to a marketing subdirectory; new install scripts go to an install subdirectory; new reference docs go to a docs subdirectory. Root residence becomes a closed list, and the closed list is the entire point.

The project this article documents has Article XVI of its CONSTITUTION pinned to this exact distinction. The article enumerates root residents (about ten files plus a handful of directories), spells out which destination each new-file class routes to, and bans new top-level directories without explicit justification. Every cleanup since has applied the rule mechanically. No debate. The rule had pre-decided the destination.

## Each subdirectory does the same job locally

The pattern works one level down too. `docs/` is a surface within `pages/`. `pages/about/` is a surface within `pages/`. Each kept top-level subdirectory has its own `README.md` declaring its local rule of residence — what belongs there, what doesn't, what naming convention to follow.

`docs/README.md` says: *governance and reference. Stable contracts. Anything narrative goes to `vault/`.*

`installer/README.md` says: *public install surface. Files here have stable URLs anchored at `kody-w.github.io/RAPP/installer/<file>`. Nothing internal.*

`tests/README.md` says: *cross-tier contract tests. Tier-internal tests live with the tier.*

Each README is the rib; the root rule is the spine. New contributors don't have to grep the Constitution to know where a file goes — they read the README of the directory they're about to add to. The discipline is fractal: every level has the same shape, the same set of questions, the same closed list.

## The two-second test

A useful question to ask of every directory in your repo, every quarter:

> If a stranger looked at this directory listing for two seconds, what would they conclude about the project?

Apply it at root: *clean catalog of tier directories + a few load-bearing files = serious project, scrolls past in two seconds.* Apply it at `installer/`: *every file is something a user installs or downloads = clear purpose.* Apply it at `pages/`: *sectioned subdirectories named for audiences = a website, not a folder.*

If the answer at any level is "I can't tell what this project is" or "this looks unfinished," you've discovered an organizational debt. Fix it now, or pay for it later in confused onboarding.

## The grandfathered exception, and the rule it teaches

There's exactly one marketing-shaped HTML file at the project's repo root: `pitch-playbook.html`. It violates the rule that says all marketing HTML lives in `pages/`. It violates the rule because its public URL was shared externally before the rule existed. Moving it would break shared links.

The Constitution memorializes this as the *only* grandfathered exception, and explicitly says: *new audience pages always go in `pages/`; this is the only marketing HTML at root, by exception rather than by precedent.*

That's an important framing. Exceptions are normal — every system accumulates them. The discipline isn't *no exceptions.* The discipline is *every exception is named, justified, and explicitly bounded so it doesn't become precedent.* Without that boundary, the next contributor sees `pitch-playbook.html` at root, doesn't know about the URL-shared history, and reasonably concludes that root is where marketing HTML goes. Now there are two. Then three. Then bloat.

## When this matters most

The pre-launch window is when path-debt is cheapest to pay down. No one has shared your URLs yet. No one has cached your install command. No `curl … | bash` is sitting in someone's notes. You can move anything, and the only people you inconvenience are the maintainers who already know.

The post-launch window is when path-debt is most expensive. Every URL change risks breaking something downstream you didn't know existed. Every directory rename risks confusing a returning contributor. The window for *changing your mind without permission* closes the moment a stranger relies on a path.

The repo this article documents is in its pre-launch window. Two cleanups landed in five days. Both were one-shot — drop the file in the right place, update internal references, commit. The next contributor will see clean directory listings at every level and absorb the discipline implicitly. They won't have to be told why the listings look that way; the listings will tell them.

## What to do with this

If you maintain a repo and you've gotten this far, three exercises are worth doing today:

1. **List your repo root.** Out loud, to a colleague who doesn't know the project. Read the names. Notice which ones make you want to explain what they are. Those are the candidates for re-homing.
2. **Write the closed list.** What *should* be at root? Tier-running code, the README, the LICENSE, governance, the entry HTML if you have one, plumbing files git/CI requires. Anything not on the list is a question.
3. **Write the rules in a real file.** A `CONTRIBUTING.md` or a `CONSTITUTION.md` or a section of your top-level README. The rule has to be writable down or the next maintainer will inherit confusion instead of discipline.

The rule we wrote — *roots are public surfaces; substance earns root residence; symmetry doesn't* — has paid for itself twice in its first week. The version of the project that didn't write it would be running on the same code, with the same features, with a directory listing that nobody enjoys looking at.

The directory listing is doing the talking. Make sure it's saying what you mean.

## Receipts

- Article XVI of the CONSTITUTION, the spine: [github.com/kody-w/RAPP/blob/main/CONSTITUTION.md](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md).
- The manifesto-shaped vault note: [[Roots Are Public Surfaces]] under `pages/vault/Manifestos/`.
- The cleanup story that this article distills: [[Repo Root Reorganization 2026-04-24]].

A closed list of root residents is one of the cheapest, highest-leverage organizational artifacts a project can adopt. Write it before you need it. Apply it whenever the listing starts feeling crowded. Don't apologize for excluding things; the exclusion is the value.
