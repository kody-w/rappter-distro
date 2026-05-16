---
title: The vault as a second brain — why long-form decision narratives survive what commit messages don't
status: shipped
published_url: https://kody-w.github.io/2026/04/24/vault-as-second-brain/
section: Blog Drafts
hook: Code captures what. Commit messages capture what changed. Neither captures why a decision was made the way it was. The vault is the discipline that closes that gap — and the only memory the project has that doesn't decay.
date: 2026-04-24
class: evergreen
decay: low
---

# The vault as a second brain — why long-form decision narratives survive what commit messages don't

A typical software project has three places where its history accumulates. The code, the commit log, and chat. Each captures something. None capture the most important thing — *why a decision was made the way it was, what was rejected, and what was learned from the things that got deleted.*

The code captures *what.* The commit log captures *what changed and when.* Chat captures *who was talking when this was happening.* All three rot fast as the people who knew the original context move on. The newcomer in two years opens the repo, sees a clever pattern, and either reverse-engineers the reasoning from scratch or "fixes" it by reverting to a more standard approach — losing the lesson the cleverness was teaching.

The fix isn't another README. It's a different artifact entirely.

## What the vault is

In this project, the artifact is `pages/vault/`. It's a real Obsidian vault — anyone can clone the repo, open the folder in Obsidian, and use it as their own second-brain workspace. It's also a static site, rendered by a small SPA at `pages/vault/index.html` so visitors can read it on the web.

The vault contains ~50 long-form notes organized into sections:

- **Founding decisions** — the rejected alternatives, the close calls.
- **Removals** — code that was deleted and the lesson it taught.
- **Architecture** — the clever tricks that look weird at first glance and would be "cleaned up" by a refactor that didn't know better.
- **Positioning** — the honest tradeoffs, the anti-pitch, the framing used with prospects.
- **Twin & UX philosophy** — the worked examples behind the platform's UI rules.
- **Process** — how a workshop runs, what makes a 60-minute session land.
- **Manifestos** — the short essays that turn one-line slogans into something a contributor can defend.
- **Plans & Ledgers** — living documents (roadmaps, backlogs, release ledger) that append continuously.

Each note has frontmatter declaring its status (`stub`, `published`, `living`), its section, and a one-line hook. Each links to 3-5 other notes via Obsidian-style `[[wikilinks]]`. The graph is the point — a note in isolation doesn't help; a note linked to its neighbors becomes navigable knowledge.

## What the vault is not

It's not documentation. Documentation answers *how* — how to install, how to call the API, how to deploy. The project has those, in a separate `docs/` folder.

It's not a wiki of the codebase. Code is its own documentation; the vault doesn't try to mirror it.

It's not a blog. Blogs are time-ordered and audience-shaped (each post a complete piece for an external reader). The vault is graph-ordered and project-shaped (each note assumes the reader has context or can follow links to it).

It's not a place for commit messages or PR descriptions. Those still exist in their own systems. The vault is for the thinking *behind* what shows up in the commit message — the kind of thinking that's lost the moment the PR merges.

## The two-state lifecycle

Every vault note has one of three states:

- **`status: stub`** — the slot is held: title, hook, pointers to related notes, why this would rot if not written. Stubs cost nothing and prevent the topic from being forgotten. The wiki saying *"this topic exists; the post hasn't shipped yet."*
- **`status: published`** — the full essay. The bar is one thing: *the why is captured well enough that someone who wasn't in the room can apply it.*
- **`status: living`** — never finishes. Roadmaps, backlogs, ledgers. Append continuously; never silently delete.

A stub becoming published is a real release. The reverse — a published note demoted back to a stub — happens only if the post was wrong; it doesn't happen because the topic became unfashionable.

## Why this beats the alternatives

**Against documentation:** Docs answer *how*. The vault answers *why*. They're different artifacts; trying to merge them produces a hybrid that's bad at both. Keep them separate.

**Against commit messages:** Commit messages have no future reader. They're optimized for "what changed," not "why we picked this option." A vault note can be 1,200 words and reference six other notes; a commit message can't.

**Against PR descriptions:** PR descriptions live in the platform, not the repo. They're searchable but not navigable. They don't get cross-linked to the next decision that depends on them.

**Against Slack / Discord / chat:** Chat is the fastest-decaying memory medium humans have ever invented. The relevant conversation happened. The relevant person remembers it for ~6 weeks. After that, the lesson is gone unless someone wrote it down somewhere durable.

**Against a Notion or Confluence wiki:** Those are valid. The vault uses markdown in the repo (instead of a hosted wiki) for three reasons: it travels with the code, it survives company changes (no SaaS dependency), and it's accessible to AI tools fetching the repo. None of these are dispositive — many projects do fine with Notion. The repo-based approach is one defensible answer.

## What gets memorialized

The discipline of *what to write down* is the load-bearing one. Three categories that earn vault notes:

**Decisions with rejected alternatives.** *"We picked X over Y for reason Z. Here's what Y would have given us. Here's what we lost. Here's why Z mattered more than that loss."* Without this, the next contributor sees only X, doesn't know Y was considered, and either repeats Y as if it's a new idea or "fixes" X to look more like Y.

**Removals.** Code that was deleted. The hypothesis it was testing. The signal that disconfirmed the hypothesis. The rule that came out of the lesson. Removal stories rot fastest because the code is already gone — only memory holds the reasoning, and memory is unreliable.

**Counterintuitive patterns.** A clever trick that looks weird at first glance. *"Why does the local-storage shim live in `sys.modules` instead of being a normal import? Because we needed Tier 1 and Tier 2 to read the same code path without modifying agent files."* Without the note, the next refactor "cleans up" the trick.

**Architectural moments.** Big decisions about shape — three tiers, single-file agents, fixed slot vocabulary. The rationale matters more than the rules.

**Positioning.** *"Why aren't we competing with Copilot Studio? Because Copilot Studio is the destination, not the competitor."* Strategic framing decays in chat; in the vault, it stays.

## What doesn't get memorialized

Equally important. The vault doesn't try to be the sole record of everything:

- **Day-to-day implementation.** The code shows what was implemented. No vault note needed.
- **Style preferences.** "We use 2-space indentation" is a style guide, not a decision narrative.
- **Bug fixes that were just bug fixes.** No lesson, no rule emerged. The commit speaks for itself.
- **Marketing copy.** That's `pages/`, not the vault.
- **Trivial choices.** "Should this variable be `name` or `title`?" — not vault-worthy. The vault is for decisions that produce *rules*, and rules are bigger than variable names.

## How writing it works

The discipline that's worked: *capture during the decision, not after.* In this project, when a major reorganization happened on 2026-04-24, the vault note was written *during* the same session — not as a retrospective the following week. The user explicitly said: *"make this constitutional and document in the obsidian vault."*

That ordering matters. Memory is freshest in the moment. Cleanup the next day forgets details. Cleanup the next week forgets the *feel* of why the decision mattered. Cleanup the next month is fiction.

When a session produces a decision worth remembering, the note gets written before the session closes. Even if it's a stub. Even if it's three paragraphs and a TODO list. The slot is held. The slot is what prevents forgetting.

## The vault as discipline

The vault works as a second brain only if writing into it becomes reflex. Three habits that make it sticky:

1. **Stub aggressively.** Every time you notice a decision worth memorializing, drop a stub. Don't wait for the long-form moment. Stubs cost nothing.
2. **Wikilink while writing.** A new note linking to three existing notes (and being linked from one or two) keeps the graph dense. Dense graphs are navigable; sparse graphs are dead trees.
3. **Promote stubs deliberately.** Reread the stub list periodically. Promote the one you most worry would rot if it sat another six weeks. Repeat.

The vault isn't a project; it's a practice. Each note is small. The practice compounds.

## Receipts

- The vault: [`pages/vault/`](https://github.com/kody-w/RAPP/tree/main/pages/vault) in the source repo.
- The static viewer: live at [kody-w.github.io/RAPP/pages/vault/](https://kody-w.github.io/RAPP/pages/vault/).
- The article that makes the vault constitutional: Article XXIII of [`CONSTITUTION.md`](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md).
- A representative published note: [[Repo Root Reorganization 2026-04-24]] under `Architecture/`.

The platform's working knowledge: *the most fragile thing a project owns is the why behind decisions.* Code endures. Commits endure. The reasoning behind both decays in weeks if it isn't written down. The vault is the discipline that closes the gap — and the only project memory that survives the people who made it.
