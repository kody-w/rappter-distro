---
title: Blog Roadmap
status: living
section: Plans & Ledgers
type: roadmap
hook: 28 blog posts for the main blog (kody-w.github.io tagged "rapp"). Each mirrored to its vault source so writing is "externalize the essay," not "draft from scratch."
session_id: 63243848-caa9-483c-9a8e-9bb0ee9d2849
session_date: 2026-04-24
---

# Blog Roadmap

> **Hook.** 28 blog posts for the main blog (kody-w.github.io tagged "rapp"). Each mirrored to its vault source so writing is "externalize the essay," not "draft from scratch."

This roadmap is the **public-facing companion** to the [[Documentation Roadmap]]. The Documentation Roadmap covers internal docs (READMEs, SPEC, agent guides, vault notes); this one covers external blog posts that ride on top of vault content.

The principle: **write the high-decay ones now, before the build memory fades.** Evergreen posts can wait; the lessons from removed code and just-shipped designs cannot.

## How posts are classified

| Class | Meaning | Decay risk |
|---|---|---|
| **Evergreen** | Manifesto-shaped; the lesson is permanent. | LOW |
| **Semi-evergreen** | Architecture or positioning that ages with the codebase or industry. | MEDIUM |
| **Timely** | Anchored to a release, an event, a moment. | HIGH after the moment |

**Decay risk** is independent of class — it asks *"will the relevant context still exist if we don't write this in 30 days?"* Removal stories are evergreen *as a lesson* but high-decay *as a write* because the code is already gone and only memory holds the reasoning.

## Drafts live at `pages/vault/Blog Drafts/`

When a post moves from "planned" to "drafting," its working copy lives at `pages/vault/Blog Drafts/<title>.md` until publication. Drafts have `status: draft` in their frontmatter so the link checker tolerates them and the viewer styles them distinctly. Once published to the blog, the draft moves to the **Shipped** section below with a link to the live post.

---

## Now — write within 30 days (highest decay)

### 1. We Killed a 2,138-Line Mega-Agent

- **Class.** Evergreen.
- **Decay.** HIGH.
- **Hook.** When an agent's `perform()` body becomes unreviewable, the question isn't *"how do we organize this?"* — it's *"what are the agents hiding in here?"*
- **Source.** [[Why hatch_rapp Was Killed]].
- **Why now.** Code is gone. Reasoning lives only in the vault and in fading memory.

### 2. We Just Deleted 6,500 Lines in One Merge

- **Class.** Timely.
- **Decay.** HIGH.
- **Hook.** `hatch_rapp` (2,138), `swarm_server` (1,736), `t2t` (337), `pitch_deck` (1,087), the brief-pipeline four-agent chain (875), `save_memory` + `recall_memory` (278). One omnibus on what each taught us about scope discipline.
- **Source.** [[Major Moments]] + [[Why hatch_rapp Was Killed]] + [[Why t2t and swarm_server Are Gone]] + [[The experimental Graveyard]] + [[From save_recall to manage_memory]].
- **Why now.** Ride the cleanup moment; the deletion volume is concrete and unrepeatable.

### 3. We Built a Public Vault for an AI Agent Platform — Here's the Layout

- **Class.** Semi-evergreen.
- **Decay.** HIGH.
- **Hook.** 47 notes, 608 wikilinks, a static viewer that pulls live from GitHub, a PWA, a link/PII checker. The gardener loop you can copy.
- **Source.** [[Vault Build-Out Plan]] + [[How to Read This Vault]] + [[Roots Are Public Surfaces]].
- **Why now.** The build is fresh; the design choices are still ours to articulate.

### 4. Apple Shortcuts as the watchOS Path

- **Class.** Semi-evergreen.
- **Decay.** MEDIUM.
- **Hook.** Watch + Siri brainstem client with **zero native code, zero App Store review, zero per-OS regression testing**. The protocol shape, the distribution mechanics.
- **Source.** [[Surfaces — Mobile, Watch, Voice]].
- **Why now.** The design is in our heads; write before we forget what tradeoffs we considered.

### 5. The PWA Bet — Why We Skipped a Cross-Platform Desktop App

- **Class.** Semi-evergreen.
- **Decay.** MEDIUM.
- **Hook.** Three OS toolchains, three signing stories, three sets of bug reports — or one `manifest.webmanifest`.
- **Source.** [[Surfaces — Mobile, Watch, Voice]].
- **Why now.** We just shipped both PWAs; the moment is now.

### 6. The Repo Root Is a Catalog Card

- **Class.** Evergreen.
- **Decay.** MEDIUM.
- **Hook.** How a `git pull` bloated our root, how we cleaned it up *twice in one week*, and why the discipline became constitutional.
- **Source.** [[Roots Are Public Surfaces]] + [[Repo Root Reorganization 2026-04-24]].
- **Why now.** Both cleanups are recent; the playbook is concrete.

### 29. The Audience Site Shell — No Build Step Required

- **Class.** Semi-evergreen.
- **Decay.** HIGH (the building-while-fresh story; pattern part is durable).
- **Hook.** A real multi-section website with shared chrome, design tokens, and a markdown docs viewer — using only vanilla HTML, CSS, and JS. No bundler, no framework, no SDK.
- **Draft.** [[audience-site-shell]] · [[Repo Root Reorganization 2026-04-24]].
- **Status.** Draft written 2026-04-24.

### 30. Two Cleanups in One Week — When the Constitutional Rule Pays Off

- **Class.** Semi-evergreen.
- **Decay.** MEDIUM.
- **Hook.** We wrote the rule about repo-root residence before the bloat. Five days later we applied it twice. The post that doesn't get written: the third cleanup that didn't have to happen.
- **Draft.** [[two-cleanups-one-week]].
- **Status.** Draft written 2026-04-24.

### 31. From save_recall to manage_memory — Agent Consolidation as Discipline

- **Class.** Evergreen (lesson) / High decay (the war story rotting fast).
- **Hook.** Two memory agents merged into one. The split read clean in the SPEC and got messy in the LLM. When to split, when to merge.
- **Draft.** [[from-save-recall-to-manage-memory]] · [[From save_recall to manage_memory]].
- **Status.** Draft written 2026-04-24.

### 32. The Experimental Graveyard — What We Tried, What We Cut, and Why We Kept the Bones

- **Class.** Evergreen. **Decay.** HIGH.
- **Hook.** An `experimental_agents/` folder the auto-loader explicitly skips. The rule that produces it. Memorial-not-deletion as institutional memory.
- **Draft.** [[the-experimental-graveyard]] · [[The experimental Graveyard]].
- **Status.** Draft written 2026-04-24.

### 33. Code Earns a Directory; Artifacts Don't

- **Class.** Evergreen. **Decay.** MEDIUM.
- **Hook.** We created a tier-3 directory in the morning and folded it back into installer/ in the afternoon. Eight hours, one constitutional amendment, lesson on overfitting symmetry.
- **Draft.** [[code-earns-a-directory]] · [[Repo Root Reorganization 2026-04-24]].
- **Status.** Draft written 2026-04-24.

---

## Next — write within 60 days (manifestos + architecture deep-dives)

### 7. Engine, Not Experience — The Constraint That Defined the Platform

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[Engine, Not Experience]].
- **Hook.** We rejected the workflow editor, the template gallery, the settings page, the graph DAG. Here's why.

### 8. The Single-File Agent Bet (And What We Walked Away From)

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[The Single-File Agent Bet]].
- **Hook.** One file, one class, one `perform()`, one metadata dict. Sibling imports are banned. Here's the bet and what it cost.

### 9. Three Tiers, One Model — Same Python File from Laptop to Copilot Studio

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[Three Tiers, One Model]] + [[Why Three Tiers, Not One]].
- **Hook.** Vendoring, the storage shim, the deterministic fake. The mechanism behind the central claim.

### 10. Data Sloshing — Multi-Agent Pipelines Without an Orchestration Framework

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[Data Sloshing]].
- **Hook.** Agents return JSON. The next agent reads it deterministically. The LLM is not load-bearing for inter-agent state.

### 11. A Local Storage Shim via `sys.modules` — A Field Report

- **Class.** Evergreen. **Decay.** MEDIUM. **Source.** [[Local Storage Shim via sys.modules]].
- **Hook.** Agents import the Azure SDK; the brainstem hijacks the import; the agent never knows.

### 12. The Deterministic Fake LLM Is Not a Hack — It's the Test Suite's Backbone

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[The Deterministic Fake LLM]].
- **Hook.** 22 lines of Python. Picks the first available tool. Drives full pipelines end-to-end without an LLM.

### 13. Vendoring as Discipline

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[Vendoring, Not Symlinking]].
- **Hook.** Symlinks die in Azure Functions packaging. Submodules add friction. Duplication is the receipt that someone considered the cross-tier impact.

### 14. 60 Minutes to a Working AI Agent — A Workshop Walk-Through

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[60 Minutes to a Working Agent]].
- **Hook.** 10 minutes goal-setting. 40 minutes the agent emerges in front of the customer. 10 minutes validating against their own input.

### 15. The Agent IS the Spec

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[The Agent IS the Spec]].
- **Hook.** One file. Four readings. PM reads metadata; dev reads `perform()`; partner reads parameters; customer reads the system prompt.

### 16. Self-Documenting Handoff — Pricing an AI Agent from a File in 5 Minutes

- **Class.** Semi-evergreen. **Decay.** LOW. **Source.** [[Self-Documenting Handoff]].
- **Hook.** The estimation checklist. What to read in metadata, what to read in the body, what to read in the imports.

### 17. RAPP vs Copilot Studio — Sequential, Not Versus

- **Class.** Semi-evergreen. **Decay.** MEDIUM. **Source.** [[RAPP vs Copilot Studio]].
- **Hook.** Upstream of Copilot Studio, not competing. The honest framing for a Microsoft-aligned partner.

### 34. Roots Are Public Surfaces

- **Class.** Evergreen. **Decay.** LOW.
- **Hook.** A repo's root is not a folder. It is a storefront. The discipline that flows from that distinction is what separates a project that scales from one that quietly accumulates clutter.
- **Draft.** [[roots-are-public-surfaces]] · [[Roots Are Public Surfaces]].
- **Status.** Draft written 2026-04-24.

### 35. skill.md — A Pattern for AI-Readable Installers

- **Class.** Evergreen. **Decay.** LOW.
- **Hook.** A markdown file at a stable URL. An LLM running an install command on someone's behalf. A handshake protocol for the choice point. Small pattern, huge leverage.
- **Draft.** [[skill-md-pattern]] · [[The skill.md Pattern]].
- **Status.** Draft written 2026-04-24.

### 36. Surfaces — Mobile, Watch, Voice. Where the Same Agent Travels Next.

- **Class.** Semi-evergreen. **Decay.** MEDIUM.
- **Hook.** What it would take to extend the single-file agent contract to mobile, watch, and voice without breaking portability. What we won't bend to get there.
- **Draft.** [[surfaces-mobile-watch-voice]] · [[Surfaces — Mobile, Watch, Voice]].
- **Status.** Draft written 2026-04-24.

### 37. The Directory-README Pattern — Per-Folder Scale Rules as the Rib of Organizational Discipline

- **Class.** Evergreen. **Decay.** LOW.
- **Hook.** A README in every kept top-level subdirectory, declaring its local rule of residence. New contributors don't grep the constitution; they read the local README.
- **Draft.** [[directory-readme-pattern]].
- **Status.** Draft written 2026-04-24.

### 38. Markdown Is the Spec; HTML Is the Rendering

- **Class.** Evergreen. **Decay.** LOW.
- **Hook.** Two viewers in one project. Both ship raw markdown plus a tiny HTML/JS shell that renders it. Why this beats either "ship docs as HTML" or "ship docs as markdown only."
- **Draft.** [[markdown-is-the-spec]].
- **Status.** Draft written 2026-04-24.

### 18. What You Give Up With RAPP — The Anti-Pitch

- **Class.** Semi-evergreen. **Decay.** MEDIUM. **Source.** [[What You Give Up With RAPP]].
- **Hook.** No graph editor. No vector DB. No general-purpose framework. Here's when you should *not* use this.

---

## Later — forever-essays; write when the right week arrives

### 19. The Twin Offers, The User Accepts — A UX Manifesto

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[The Twin Offers, The User Accepts]].
- **Hook.** Why every settings page is a failure mode.

### 20. Calibration Is Behavioral, Not Explicit

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[Calibration Is Behavioral, Not Explicit]].
- **Hook.** Users don't update preferences pages. They update behavior. Read from behavior.

### 21. Every Twin Surface Is a Calibration Opportunity

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[Every Twin Surface Is a Calibration Opportunity]].
- **Hook.** Help-shaped UI is wrong. Calibration-shaped UI is right.

### 22. The Brainstem Tax

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[The Brainstem Tax]].
- **Hook.** Every line in the kernel is a line every agent now pays for.

### 23. The Engine Stays Small — The Conservation Law

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[The Engine Stays Small]].
- **Hook.** A fixed budget of complexity. We spend it on the agents, not on the engine.

### 24. Voice and Twin Are Forever — Two Slots, Forever

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[Voice and Twin Are Forever]].
- **Hook.** Why we never add a third top-level delimiter.

### 25. Why GitHub Pages Is the Distribution Channel

- **Class.** Evergreen. **Decay.** LOW. **Source.** [[Why GitHub Pages Is the Distribution Channel]].
- **Hook.** One curl pipe. Audit-friendly. Versioning by tag. No registry, no CDN, no installer binary.

### 39. Writing for the AI Reader — CLAUDE.md, AGENTS.md, skill.md

- **Class.** Evergreen. **Decay.** LOW.
- **Hook.** Three small files at the repo root tell three different AI audiences exactly how to read and edit your project. Together they're a contract for autonomous edits.
- **Draft.** [[writing-for-the-ai-reader]].
- **Status.** Draft written 2026-04-24.

### 40. Building a Static Site in Pure HTML/CSS/JS in 2026 — The Anti-Framework Case

- **Class.** Evergreen. **Decay.** LOW.
- **Hook.** A real multi-section site with shared chrome, theming, a docs viewer, a vault renderer, and zero build step. The case that vanilla in 2026 is the new sensible default for content-shaped sites.
- **Draft.** [[static-site-pure-html-2026]].
- **Status.** Draft written 2026-04-24.

### 41. The Vault as a Second Brain — Why Long-Form Decision Narratives Survive What Commit Messages Don't

- **Class.** Evergreen. **Decay.** LOW.
- **Hook.** Code captures what. Commit messages capture what changed. Neither captures why a decision was made the way it was. The vault is the only project memory that doesn't decay.
- **Draft.** [[vault-as-second-brain]].
- **Status.** Draft written 2026-04-24.

### 26. The Auth Cascade — `GITHUB_TOKEN` → `.copilot_token` → `gh auth token`

- **Class.** Evergreen. **Decay.** MEDIUM. **Source.** [[The Auth Cascade]].
- **Hook.** Three sources, three personas, no silent prompts.

---

## Timely — anchor to a moment

### 27. Brainstem v0.13 / v1.0 Release Post

- **Class.** Timely. **Decay.** HIGH after the next version.
- **Hook.** Release-shaped narrative tied to the version tag.
- **Source.** `pages/docs/VERSIONS.md`, `pages/release/release-notes.html`, [[Major Moments]].
- **Ready when.** Cut the next release tag.

### 28. Federating an AI Agent Registry — A Look at RAR + skill.md

- **Class.** Timely. **Decay.** HIGH after the moment.
- **Hook.** RAR — the RAPP Agent Registry — exists. `skill.md` is its protocol. How federation works without a central server.
- **Source.** [[Federation via RAR]] + [[The skill.md Pattern]].
- **Why now.** Once RAR has its first federation partner.

### 42. Pre-Launch Path Freedom — What We Changed Before the First Stranger Arrived

- **Class.** Timely. **Decay.** HIGH (ages once first user lands).
- **Hook.** Five separate "no users yet, do it now" decisions in one session. The window for changing your mind without permission closes the moment a stranger relies on a path.
- **Draft.** [[pre-launch-path-freedom]].
- **Status.** Draft written 2026-04-24. **Write timeline:** publish before first public user.

### 43. One Session, Three Reorgs — A Real-Time View of Design Iteration

- **Class.** Timely. **Decay.** HIGH (the iteration is specific to one session).
- **Hook.** A directory created in the morning, removed in the afternoon. A doc moved into a subfolder, then restored to root. A vault split, then unified. From the inside it felt chaotic. The diff is clean.
- **Draft.** [[one-session-three-reorgs]] · [[Repo Root Reorganization 2026-04-24]].
- **Status.** Draft written 2026-04-24. **Write timeline:** within 30 days.

- **Class.** Timely. **Decay.** MEDIUM.
- **Hook.** A community-publishable agent registry that doesn't centralize. `skill.md` as the manifest. How publishing works without a central server.
- **Source.** [[The skill.md Pattern]] + [[Federation via RAR]] + `pages/docs/skill.md` + `pages/docs/rapplication-sdk.md`.
- **Ready when.** RAR has a non-trivial number of publishers.

---

## Cross-cutting recommendation

The first **6 posts** ("Now" tier) are the priority — they're either highest-decay (#1, #2, #3) or freshest design (#4, #5, #6). After those land, the manifestos (#7–#13) become the platform's persistent voice; the rest are content rotation.

## How to draft

1. Pick a post from the list above.
2. Open the source vault note(s) — they hold the substance.
3. Create `pages/vault/Blog Drafts/<title>.md` with `status: draft` in the frontmatter.
4. Externalize: same arguments, different audience. The vault reader is the platform's contributor; the blog reader is a curious technical stranger. Tone shifts from *"the platform's working knowledge"* to *"here's what we learned."*
5. When publishing, push to the blog, then move the draft entry from this roadmap's **Now/Next/Later** to the **Shipped** section below.

## Shipped

Append-only. Each entry has the publish date and a link to the live post.

### 2026-04-24 — 15-post drop on platform discipline + the 2026-04-24 reorg

A single working session produced fifteen RAPP-tagged posts spanning decay-shaped war stories, evergreen platform/pattern essays, and timely pre-launch field reports. All published to `kody-w.github.io` with tag `[rapp]`. Source drafts retained at `pages/vault/Blog Drafts/` with `status: shipped` and `published_url:` set.

**Decay-shaped (captured-while-fresh):**

- #29 — [The Audience Site Shell — No Build Step Required](https://kody-w.github.io/2026/04/24/audience-site-shell/) · draft: [[audience-site-shell]]
- #30 — [Two Cleanups in One Week](https://kody-w.github.io/2026/04/24/two-cleanups-one-week/) · draft: [[two-cleanups-one-week]]
- #31 — [From save_recall to manage_memory](https://kody-w.github.io/2026/04/24/from-save-recall-to-manage-memory/) · draft: [[from-save-recall-to-manage-memory]]
- #32 — [The Experimental Graveyard](https://kody-w.github.io/2026/04/24/the-experimental-graveyard/) · draft: [[the-experimental-graveyard]]
- #33 — [Code Earns a Directory; Artifacts Don't](https://kody-w.github.io/2026/04/24/code-earns-a-directory/) · draft: [[code-earns-a-directory]]

**Evergreen — platform & pattern:**

- #34 — [Roots Are Public Surfaces](https://kody-w.github.io/2026/04/24/roots-are-public-surfaces/) · draft: [[roots-are-public-surfaces]]
- #35 — [skill.md — A Pattern for AI-Readable Installers](https://kody-w.github.io/2026/04/24/skill-md-pattern/) · draft: [[skill-md-pattern]]
- #36 — [Surfaces — Mobile, Watch, Voice](https://kody-w.github.io/2026/04/24/surfaces-mobile-watch-voice/) · draft: [[surfaces-mobile-watch-voice]]
- #37 — [The Directory-README Pattern](https://kody-w.github.io/2026/04/24/directory-readme-pattern/) · draft: [[directory-readme-pattern]]
- #38 — [Markdown Is the Spec; HTML Is the Rendering](https://kody-w.github.io/2026/04/24/markdown-is-the-spec/) · draft: [[markdown-is-the-spec]]
- #39 — [Writing for the AI Reader](https://kody-w.github.io/2026/04/24/writing-for-the-ai-reader/) · draft: [[writing-for-the-ai-reader]]
- #40 — [Building a Static Site in Pure HTML/CSS/JS in 2026](https://kody-w.github.io/2026/04/24/static-site-pure-html-2026/) · draft: [[static-site-pure-html-2026]]
- #41 — [The Vault as a Second Brain](https://kody-w.github.io/2026/04/24/vault-as-second-brain/) · draft: [[vault-as-second-brain]]

**Timely (anchor-to-a-moment):**

- #42 — [Pre-Launch Path Freedom](https://kody-w.github.io/2026/04/24/pre-launch-path-freedom/) · draft: [[pre-launch-path-freedom]]
- #43 — [One Session, Three Reorgs](https://kody-w.github.io/2026/04/24/one-session-three-reorgs/) · draft: [[one-session-three-reorgs]]

**Receipts.** Commit `6746bd2` on `kody-w/kody-w.github.io@master`. Vault `pages/vault/Blog Drafts/` carries the source drafts with `status: shipped` and `published_url` per [[Blog Drafts — README]] lifecycle.

## Related

- [[Documentation Roadmap]] — internal docs companion.
- [[Release Ledger]] — append-only record of what shipped, code/docs/governance.
- [[Vault Build-Out Plan]] — the vault's own build plan, source for several Now-tier posts.
- [[How to Read This Vault]] — meta-context for first-time vault readers.
