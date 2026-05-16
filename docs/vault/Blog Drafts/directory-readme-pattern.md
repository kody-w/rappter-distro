---
title: The directory-README pattern — per-folder scale rules as the rib of organizational discipline
status: shipped
published_url: https://kody-w.github.io/2026/04/24/directory-readme-pattern/
section: Blog Drafts
hook: A README in every kept top-level subdirectory, declaring its local rule of residence. Small artifact, fractal discipline. New contributors don't grep the constitution; they read the local README.
date: 2026-04-24
sources:
  - "[[Roots Are Public Surfaces]]"
  - "[[Repo Root Reorganization 2026-04-24]]"
class: evergreen
decay: low
---

# The directory-README pattern — per-folder scale rules as the rib of organizational discipline

A repo's root rule says *what belongs at root.* That's the spine. It's necessary and not sufficient. The moment a contributor steps one level down — into `docs/`, `pages/`, `installer/`, `tests/` — the spine offers no guidance. The next file they're about to add could land in any of half a dozen places. They guess. Sometimes they guess right. Sometimes the next maintainer cleans up after them.

The fix is small and underused: every kept top-level subdirectory has a `README.md` that states its local scale rule. What belongs here. What doesn't. What naming convention to follow. Why the rule exists.

The repo-root rule is the spine. The per-directory README is the rib. Together they make the discipline fractal — every level has the same shape, the same set of questions, the same closed list.

## What a directory README contains

The shape that's emerged from running this pattern:

```markdown
# `<dirname>/` — <one-line purpose>

<paragraph: what this directory is, in plain language>

## What's here

| File | What |
|---|---|
| ... | ... |

## What belongs here

A file earns a place in `<dirname>/` when ALL of these are true:

1. <criterion 1>
2. <criterion 2>
3. <criterion 3>

## What does NOT belong here

- ❌ <bad pattern>. Goes here instead: `<elsewhere>`.
- ❌ <bad pattern>. Goes here instead: `<elsewhere>`.

## Conventions

- <naming rule>
- <cross-link convention>
- <numbering or versioning rule>

## Scale rule

When you're about to add a file here, ask:
1. <question that filters in>
2. <question that filters out>
3. <question that routes to the right destination>

## Related

- <link to the spine — repo-root rule>
- <link to adjacent directory READMEs>
```

Every section earns its place. *What's here* is current state. *What belongs* is the inclusion test. *What does NOT* is the exclusion test, with explicit redirection — *not "no" without "yes here instead."* Conventions are the small-rules that prevent drift. The scale rule is the decision tree someone reads in 30 seconds before adding their file.

The Related section is the rib pointing back to the spine. The directory README is local; the constitutional article is global. Both are load-bearing; the rib never claims to be the spine.

## Why this beats a bigger central rule

The temptation is always to make the root rule bigger — write Article XVI of your CONSTITUTION longer, enumerate every subdirectory's local conventions in one place. Don't.

A central rule that covers every case is a rule no one reads. Contributors don't open the constitution to add a file; they're already in the directory they're about to add to. The rule has to *meet them where they are*. A README in their immediate working context is read; a constitution five clicks away is not.

A central rule that grows with every new directory becomes brittle. Update the directory's structure → update the central rule → forget to update one of the two → drift.

A central rule that tries to legislate per-directory naming conventions becomes a contradiction surface. `pages/` wants lowercase-hyphen filenames; `docs/` wants UPPERCASE.md for governance and lowercase.md for reference; `installer/` is fixed-filename forever. These aren't compatible because they shouldn't be. Each directory has its own job.

The fractal solution: spine names the closed list of subdirectories and ban the rest. Each rib names its own conventions. The two never need to coordinate beyond *"this directory exists and is governed by its own README."*

## What a good directory README rules out

The discipline is largely *the things that don't end up in the directory.* Some examples from the project this article documents:

**`docs/` README rules out:**
- Decision narratives. Those go in the vault, not `docs/`.
- Status updates and in-flight notes. PR descriptions, not the repo.
- Per-tier deep dives. Tier-internal docs live in the tier directory.
- Tutorials and audience-shaped content. That's `pages/`.

**`installer/` README rules out:**
- Tier-internal source code. Goes in the tier directory.
- Marketing or audience HTML. Goes in `pages/`.
- Auxiliary scripts not user-facing. Stay in their tier.
- Documentation about installation. Goes in `docs/` or vault.

**`tests/` README rules out:**
- Tier-specific unit tests. Live with the tier.
- One-off scripts dressed as tests. *"A debugging shell file that prints stuff isn't a test — tests assert."*
- Tests that depend on credentials or external services.
- Mocked-database tests. Per the project's standing rule, integration tests hit real storage.

**`pages/` README rules out:**
- Internal documentation.
- The repo landing page (must be at root for GitHub Pages).
- The grandfathered exception (`pitch-playbook.html`).
- Anything that needs a build step.

Each of these exclusion lists is the README's most useful section. New contributors don't find out *I shouldn't put this here* by writing the file and getting a PR comment. They find out by reading three lines before they start. The cost of the exclusion list is small; the cost of the bad PR is not.

## When a directory deserves a README

Not every directory needs one. The pattern earns its place when:

- The directory holds *contributions* — files multiple people will add over time. Internal-only directories that one person owns rarely need it.
- The directory has a *naming convention worth enforcing.* If filenames are arbitrary, no convention to write down.
- The directory has *an exclusion list* — things that look like they belong but actually go elsewhere. This is the most useful signal.

A `node_modules/` doesn't need a README — nothing about its rules is interesting. A `cmd/` directory in a Go project might need one, depending on whether the project runs multiple binaries. A `migrations/` directory definitely needs one — naming rules, ordering rules, what doesn't go there.

The test isn't *"is this directory important?"* — it's *"could the next contributor add the wrong thing here without knowing?"* If yes, the README earns its place.

## A trick that scales: the README is the index too

The README's *What's here* section is the directory's table of contents. If the directory has six files, the README lists six rows. Adding a new file means adding a row. The README is now a manifest for the directory's current contents — useful for new contributors, useful for code review (*"why isn't this listed?"* is a fast review question), useful for the next maintainer in three years who's wondering whether some file is still relevant.

This works recursively. A `pages/docs/` README lists the docs files; a `pages/_site/` README lists the shared chrome it provides; a `pages/_site/css/` README (if it grows complex enough to deserve one) lists the four CSS files. The directory listing in `ls` and the README's table say the same thing, in different formats, and they stay in sync because the review process catches drift.

## Why this is fractal, not just hierarchical

A hierarchical organization is *spine, then branches, then sub-branches.* Each level has its own rules, but the rules don't share shape. Different levels look different.

A fractal organization has *the same shape at every level.* Closed list of residents, exclusion list, naming convention, scale rule. The repo root has those. Each kept top-level subdirectory has those. Each *meaningful* sub-subdirectory might. The shape replicates wherever the depth justifies it.

That's why the pattern scales. A new contributor walking down the tree doesn't have to learn five different organizational schemes. They learn one shape, see it at every level, and add their file confidently. The discipline is the same; only the destination differs.

## Receipts

- Article XVI of the CONSTITUTION (the spine): [github.com/kody-w/RAPP/blob/main/CONSTITUTION.md](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md).
- The four ribs in this project: `pages/docs/README.md`, `pages/README.md`, `installer/README.md`, `tests/README.md`.
- The pattern's payoff in action: [[Repo Root Reorganization 2026-04-24]] under `pages/vault/Architecture/`.

The platform's working knowledge: *the spine is the law; the rib is the front door.* New contributors meet the rib first. Make sure it's saying what you mean.
