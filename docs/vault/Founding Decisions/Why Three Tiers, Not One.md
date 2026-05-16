---
title: Why Three Tiers, Not One
status: published
section: Founding Decisions
hook: One tier would have been simpler. Three tiers is what makes the same agent file deployable from a laptop to an enterprise tenant without a rewrite.
---

# Why Three Tiers, Not One

> **Hook.** One tier would have been simpler. Three tiers is what makes the same agent file deployable from a laptop to an enterprise tenant without a rewrite.

## The structure

RAPP ships three independently-runnable surfaces, each in its own top-level directory:

| Tier | Directory | Runtime | Job |
|------|-----------|---------|-----|
| Tier 1 — Local | `rapp_brainstem/` | Flask on `:7071` | Build, iterate, demo, share with the user in the room |
| Tier 2 — Cloud | `rapp_swarm/` | Azure Functions | Multi-tenant, scheduled, behind a customer's gateway |
| Tier 3 — Enterprise | `MSFTAIBASMultiAgentCopilot_*.zip` + `worker/` | Power Platform + Cloudflare | Distribute as a published solution into a tenant the user already trusts |

The contract that ties them together is **Sacred Constraint #4 — Tier portability guarantee**: an agent file that runs in Tier 1 must run unmodified in Tier 2 and Tier 3.

## Why not one tier?

A single tier would have been easier to ship. The version that almost happened was Tier 1 only — a local Flask server, copy your agents in, demo it, done. Three reasons it wasn't enough:

1. **A laptop is not an audit boundary.** Customers ask "where does the data go?" and a local server's answer is fine for development but unacceptable for production. Tier 2 puts the answer inside the customer's Azure tenant, behind their identity and governance.

2. **A laptop is not a scheduler.** Real workloads are not interactive — they're cron-shaped. Workspace inboxes, periodic refreshes, batch pipelines. Tier 2's Azure Functions runtime makes "schedule this agent every 4 hours" a one-line change, which Tier 1 cannot.

3. **A laptop is not a distribution channel.** The hardest moment in any agent project is *partner handoff* — taking the working agent and putting it in a customer's hands without a discovery call. Tier 3's Power Platform packaging turns the agent file into an installable solution; the customer never sees the Python.

## Why not one tier per audience?

The opposite mistake — three independent codebases, one per audience — would have given each tier the freedom to evolve at its own pace. The platform rejected it.

The reason is the **portability proof**. The single most credible thing RAPP can claim is *"the same agent file runs in three places."* That claim collapses the moment any tier drifts from the contract:

- Tier 1 cannot offer convenience APIs that Tier 2 can't honor.
- Tier 2 cannot accept agent shapes Tier 1 doesn't support.
- Tier 3 cannot strip features Tier 2 depends on.

Every feature is gated by all three tiers. The result is a smaller feature surface than any single tier would have wanted, in exchange for the only thing that actually makes the platform unique.

## How the contract is enforced

Three mechanisms keep the tiers honest:

- **Vendoring (`rapp_swarm/build.sh`).** Tier 2 doesn't import from `rapp_brainstem/`. It copies the brainstem's core files into `rapp_swarm/_vendored/`. The duplication is the receipt — every cross-tier change is an explicit, reviewable sync. See [[Vendoring, Not Symlinking]].
- **The local storage shim.** Agents import `from utils.azure_file_storage import AzureFileStorageManager`. In Tier 1, the brainstem hijacks that import via `sys.modules` and provides a JSON-file backend (`rapp_brainstem/utils/local_storage.py`). In Tier 2 and Tier 3, the real Azure module is loaded. The agent never knows. See [[Local Storage Shim via sys.modules]].
- **Provider dispatch (`rapp_brainstem/utils/llm.py`).** A 247-line module with four providers: Azure OpenAI, OpenAI, Anthropic, and a deterministic fake. Selection is by env vars; the agent cannot tell which is active.

Together these mean that the `BasicAgent`-extending file you wrote in Tier 1 — with its imports, its metadata dict, its `perform()` body — keeps working across all three deploy targets without a line of conditional code.

## What each tier *can't* do

Tier portability cuts both ways. Each tier inherits the limits of the others:

- **Tier 1 can't** schedule workloads, isolate tenants, or offer the customer their own audit log.
- **Tier 2 can't** support drag-and-drop agent edits at runtime — Azure Functions packaging requires a deploy, not a file save. The fast iteration loop is Tier 1's job.
- **Tier 3 can't** call out to arbitrary internet endpoints without going through the worker (`worker/`) — it lives inside the customer's network, under their connectors and their identity.

The platform is honest about each of these and routes work to the tier where it belongs.

## When to reconsider

The three-tier model would be reconsidered if any of these became true:

- A customer segment emerges that doesn't need any of {iterate, schedule, distribute}. Then a single tier might be enough.
- A new tier becomes load-bearing — for example, an on-device tier with no network. The model accommodates a new tier as long as the portability contract still holds across all of them.
- The portability tax (the conveniences each tier walks away from) starts costing more than the proof is worth. So far the portability claim has won every contested call.

## Discipline

- New features must clear all three tiers or they don't ship.
- Tier-specific code is allowed only at the *boundaries* (auth, storage, deploy), never in agent surface area.
- When a feature feels like it belongs in only one tier, the right answer is usually that the feature is the wrong shape — split it into a portable core and a tier-specific edge.

## Related

- [[Three Tiers, One Model]]
- [[The Single-File Agent Bet]]
- [[Vendoring, Not Symlinking]]
- [[Local Storage Shim via sys.modules]]
- [[What You Give Up With RAPP]]
