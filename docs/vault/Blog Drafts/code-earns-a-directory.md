---
title: Code earns a directory; artifacts don't
status: shipped
published_url: https://kody-w.github.io/2026/04/24/code-earns-a-directory/
section: Blog Drafts
hook: We created a tier-3 directory in the morning and folded it back into installer/ in the afternoon. The lesson took half a day and saved future-us months of confused navigation.
date: 2026-04-24
sources:
  - "[[Repo Root Reorganization 2026-04-24]]"
  - "[[Why Three Tiers, Not One]]"
  - "[[Roots Are Public Surfaces]]"
class: evergreen
decay: medium
---

# Code earns a directory; artifacts don't

Three tiers. Three top-level directories: `rapp_brainstem/`, `rapp_swarm/`, and (briefly) `rapp_studio/`. Symmetry visible at the repo root. Easy to teach. Three tier names, three folders, one mental model. Beautiful.

It was wrong, and we caught it in the same session.

## What it looked like

The morning move felt clean: cleaning up the bloated repo root, we had ten install scripts and governance docs to relocate, plus a Microsoft Power Platform `.zip` for the Tier 3 Copilot Studio harness. Tier 1 had `rapp_brainstem/`. Tier 2 had `rapp_swarm/`. The `.zip` was sitting at root, feeling like an orphan. Putting it in a new `rapp_studio/` directory completed the symmetry. Three numbered tiers, three matching directories — the layout was self-documenting.

We did it. `git mv` the `.zip` into the new directory. Update the references. Update the Constitution to memorialize the new floor. Three tier symmetry is now load-bearing in Article XVI.

The user looked at it and said: *"put the rapp studio under the installer. We don't need it to have its own folder. It just needs a place on the public github repo for people to pull down."*

That sentence dissolved the symmetry argument. We folded `rapp_studio/MSFTAIBASMultiAgentCopilot_*.zip` into `installer/MSFTAIBASMultiAgentCopilot_*.zip` and deleted the empty directory. The Constitution got rewritten. The vault note got rewritten. The lesson took eight hours from creation to retraction.

## Why the symmetry was wrong

A directory at root is a structural commitment. It says: *here is a body of code that runs in this repo, with enough internal complexity to deserve its own surface.* `rapp_brainstem/` has Flask, agents, services, web UI, tests, vendoring scripts, configuration, the lot. `rapp_swarm/` has Azure Functions code, an ARM template, vendored brainstem core, deployment scripts. They earn their directory by holding *running code*.

`rapp_studio/` would have held one file: a `.zip`. The Power Platform solution is downloaded by a customer and imported into their Copilot Studio tenant. The agent runs *in Microsoft's cloud*, not in this repo. Nothing in this repo runs Tier 3. The `.zip` is the artifact a customer pulls down.

That's a categorical difference, not a stylistic one. Tier 1 and Tier 2 ship as code that the repo runs against. Tier 3 ships as a download. Putting the download in a directory that mirrored the code-bearing tiers obscured the actual relationship.

## The rule that fell out

> A directory at root earns its place by holding running code. An artifact does not earn a directory just because it completes a numbered list.

This is now Article XVI of the Constitution, in the "what this rules out" section. The reasoning is explicit: the pull toward symmetry is strong (*three tiers, three directories, easy to teach*), and that pull is *exactly the failure mode the rule prevents.* If you let visual symmetry drive layout, you will inevitably create directories whose only contents are the rationale that justifies them.

The amended article spells out the corrective: install artifacts (downloads, ARM templates, bundles) live in `installer/` regardless of which tier they relate to. Code-bearing tiers earn their own directory. The boundary is *running code in this repo*, full stop. Tier 4, if there's ever one, gets a directory only if it has running code; otherwise its artifact ships from `installer/`.

## The cheaper lesson is the better one

We could have gotten this lesson by shipping a 12-month-old repo to a new contributor and watching them open `rapp_studio/`, see one `.zip`, and ask "why is this a directory?" That would have been the expensive version of the lesson — paid for in confused-onboarding time, wasted PR cycles, and eventually a "let's clean up the repo" effort that has to argue against an established pattern.

We got the lesson in eight hours, including the writeup. The Constitution amendment will be read by every future contributor before they're tempted to repeat the pattern. The vault note ([[Repo Root Reorganization 2026-04-24]]) captures the *why* in long form so the lesson outlives anyone who was in the room. That's a fair trade.

The cost was: one `.zip` moved twice, one directory created and removed, ~30 references updated twice, and a constitutional amendment. The benefit was: a sharpened rule that prevents a class of organizational mistake forever.

## Generalizes well beyond repos

This pattern shows up in plenty of places once you look:

- **Enums for completeness.** Adding a `STATUS_UNUSED` value to a state enum because three names looked nicer than two. The unused value will still be unused six months later, but now your switch statements have to handle it.
- **Microservices for symmetry.** Splitting a service to match an org chart instead of a workload. The service that has 12 lines of business logic and 200 lines of deployment config did not earn its own deployment surface.
- **Config files for parity.** Adding `production.yaml`, `staging.yaml`, `dev.yaml` when your dev environment is "I run it on my laptop." The third file is overhead, not abstraction.
- **API endpoints for naming.** Adding `GET /v1/widget/types` to mirror `GET /v1/widget/sizes` when the endpoint returns a four-element constant list that hasn't changed in two years.

The shape is always the same: a real category exists (running code, distinct deployment, distinct lifecycle), and we extend it past the boundary where the category does work, into territory where only symmetry justifies the extension. The corrective is also always the same: *code earns a directory, artifacts don't.* Or, more generally: *substance earns a structure, naming consistency doesn't.*

## Receipts

- The Constitution amendment: Article XVI in [github.com/kody-w/RAPP/blob/main/CONSTITUTION.md](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md), specifically the "what this rules out" entry on tier directories.
- The vault note: [[Repo Root Reorganization 2026-04-24]] under `pages/vault/Architecture/`.
- The session that produced the lesson: 2026-04-24, single working session with three reorganization passes (the Studio reversal was the second).

The platform's working knowledge: *resist the pull of symmetry.* Categorical fit is real; visual parallelism is theatre. Spend the eight hours when the move is small and the cost is just confusion and a Constitution edit. Don't pay for it later in onboarding, debate, and cleanup PRs.
