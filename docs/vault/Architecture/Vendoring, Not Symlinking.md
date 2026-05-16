---
title: Vendoring, Not Symlinking
status: published
section: Architecture
hook: rapp_swarm/build.sh copies brainstem code into _vendored/. Duplication is the receipt — every cross-tier change is an explicit, reviewable sync.
---

# Vendoring, Not Symlinking

> **Hook.** `rapp_swarm/build.sh` copies brainstem code into `_vendored/`. Duplication is the receipt — every cross-tier change is an explicit, reviewable sync.

## The mechanism

Tier 2 (`rapp_swarm/`) is an Azure Functions deployment. It runs the same agents that Tier 1 runs. It needs the same `BasicAgent` base class, the same `utils/llm.py`, the same shim layer.

It does not import from `rapp_brainstem/`. It vendors.

`rapp_swarm/build.sh` is the source of truth for the vendoring. When run, it copies brainstem core files into `rapp_swarm/_vendored/`:

```
rapp_swarm/_vendored/
  __init__.py
  agents/
    basic_agent.py
    context_memory_agent.py
    hacker_news_agent.py
    learn_new_agent.py
    manage_memory_agent.py
    workiq_agent.py
    workspace_agents/
      swarm_factory_agent.py
  utils/
    __init__.py
    _basic_agent_shim.py
    azure_file_storage.py
    copilot_auth.py
    environment.py
    llm.py
    local_file_storage.py
    result.py
    storage_factory.py
    twin.py
```

After `build.sh` runs, Tier 2's deploy package has every dependency it needs in-tree. There is no symlink to follow, no submodule to fetch, no relative import that crosses a directory boundary.

## Why duplicate?

The duplication is intentional. It is the platform's mechanism for keeping the tiers honest about the cost of cross-tier changes.

**1 — Azure Functions packaging is hostile to symlinks.** The deploy artifact for Azure Functions is a flattened directory. Symlinks don't survive the packaging step in any reliable way. If Tier 2 tried to symlink to `../rapp_brainstem/`, the deploy would either copy the link target (a vendoring step disguised as a symlink, but with no review surface) or break (because the symlink doesn't reach across the packaging boundary).

**2 — Submodules add friction without the right benefit.** A git submodule pointing `_vendored/` at `rapp_brainstem/` would create a revision lock — but submodules are universally hated for the friction they add to clones, branches, and merges. The friction would not be earned by a corresponding correctness benefit, because the submodule version still has to be *deployed* — i.e. unpacked into the Azure deploy artifact — at which point you're back to vendoring.

**3 — Duplication forces explicit sync.** The platform's deepest concern is *drift*. If brainstem code changes and Tier 2 doesn't notice, the platform's portability claim collapses. Vendoring makes the sync visible: re-running `build.sh` produces a diff in `_vendored/`. The diff is reviewable. The reviewer asks: *did this change preserve agent portability?*

The duplication is the receipt that someone considered the cross-tier impact.

## When to re-run `build.sh`

The rule is in the project CLAUDE.md: *"After modifying brainstem code that Tier 2 uses, re-run the build script to sync."* In practice, this includes:

- Changes to `rapp_brainstem/agents/basic_agent.py` (the contract every agent extends).
- Changes to `rapp_brainstem/utils/llm.py`, `local_storage.py`, or `_basic_agent_shim.py`.
- New shared agents that the rapp store references and Tier 2 needs to be able to load.

It does *not* include:

- Changes to `rapp_brainstem/brainstem.py` itself — Tier 2 has its own entry point (`rapp_swarm/function_app.py`) that is structurally different. The brainstem is not vendored.
- Changes to `rapp_brainstem/web/` — the Tier 1 UI is not part of Tier 2.
- Changes to user-private agents (those go in workspaces, not in the shared core).

## The drift detector

The vendoring approach has one enforced check: the test suite (`tests/run-tests.mjs`) runs against both Tier 1 (using `rapp_brainstem/`) and Tier 2 (using `rapp_swarm/_vendored/`) for the agent contract tests. If Tier 1 has a feature that Tier 2's vendored copy lacks, the test diverges. That is the signal to re-run `build.sh`.

The check is not perfect — a test that doesn't exercise a particular code path won't catch drift in that path. The discipline supplements the test: cross-tier code changes are *expected* to include the build-script re-run in the same change.

## The alternative we rejected

The cleanest alternative would have been a real shared package — `rapp_core/` at the repo root, installed as a Python package, depended on by both `rapp_brainstem/` and `rapp_swarm/`. Pros: no duplication, single source of truth, no build script to forget. Cons:

- **Install-time complexity.** Tier 1's install one-liner (`curl ... | bash`) becomes a multi-step pip install. The install one-liner is sacred (Constitution Article V).
- **Azure Functions cold-start cost.** Custom packages add to the deploy artifact and the cold-start time. Vendoring keeps the artifact tight.
- **Loss of the receipt.** A package version bump in two places is one line of code; the actual *change* across files is hidden in the package version. Vendoring forces the change to land in the diff, where it can be reviewed.

The vendoring approach is uglier in the abstract. It is more honest about what's actually shipping.

## What this rules out

- ❌ Tier 2 importing from `rapp_brainstem/` directly. Even if it would work locally, it doesn't survive Azure packaging and breaks the receipt principle.
- ❌ Symlinking `_vendored/` at `rapp_brainstem/`. Convenient locally; broken in deploy.
- ❌ A custom package (`rapp_core`) maintained as a sibling. The install story doesn't survive it.
- ❌ Manual editing of files in `_vendored/`. Files there are *outputs* of `build.sh`. Edits to them get overwritten on the next build.
- ❌ Vendoring brainstem code that doesn't have a Tier 2 use. The vendoring set is intentional; growing it without a use is taking on a sync burden for nothing.

## When to re-evaluate

The vendoring approach would be reconsidered if:

- A new tier emerges that has fundamentally different packaging constraints (and the existing approach can't extend).
- The drift detector fails repeatedly on real bugs that escape to deployment, *and* the failure is traceable to vendoring being out of sync rather than to a different cause.
- Azure Functions changes its packaging story to make symlinks/packages first-class.

So far none of these has happened.

## Discipline

- Brainstem-level changes are paired with `build.sh` re-runs in the same commit. The PR title or body should mention "re-vendored" if Tier 2 is affected.
- `_vendored/` is treated as build output, not source. Don't edit; don't review for style.
- When adding a new shared utility, decide up front whether it's vendored. If it is, add it to `build.sh` immediately, not as a follow-up.

## Related

- [[Local Storage Shim via sys.modules]]
- [[Three Tiers, One Model]]
- [[Why Three Tiers, Not One]]
- [[The Single-File Agent Bet]]
- [[Why GitHub Pages Is the Distribution Channel]]
