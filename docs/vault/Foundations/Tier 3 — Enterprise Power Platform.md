---
title: Tier 3 — Enterprise Power Platform
status: published
section: Foundations
hook: A published Microsoft Power Platform solution. The agent file ships into the customer's Copilot Studio environment without rewriting.
---

# Tier 3 — Enterprise Power Platform

> **Hook.** A published Microsoft Power Platform solution. The agent file ships into the customer's Copilot Studio environment without rewriting.

## What it is

Tier 3 is the enterprise-distribution tier. The unit of shipping is a **Power Platform solution** — a `.zip` package the customer imports into their tenant. Once imported, the agents run inside the customer's Microsoft Copilot Studio environment, governed by their identity, their connectors, and their data residency.

The published solution at the time of this note is `MSFTAIBASMultiAgentCopilot_*.zip`, located at `installer/` alongside the rest of the install surface. Studio runs in Microsoft's cloud, not in this repo, so there is no Tier 3 *directory* — only the bundle a customer downloads.

Tier 3 closes the loop with the rest of the Microsoft AI stack. See [[RAPP vs Copilot Studio]] for the relationship.

## Where it lives in the repo

```
RAPP/
  installer/
    MSFTAIBASMultiAgentCopilot_1_0_0_5.zip   # the published solution package
    azuredeploy.json                         # ARM template for the supporting Azure infra
    install.sh / install.ps1 / install.cmd   # Tier 1 one-liners (sibling install surface)
  worker/                                    # Cloudflare auth/proxy worker
    src/
    package.json
    wrangler.toml
    README.md
```

Tier 3 is the only tier whose primary artifact is **not** Python. The solution `.zip` is a Power Platform package; the Cloudflare worker is JavaScript. Both exist to bridge the customer's tenant to the agent runtime that Tier 2 hosts.

## What Tier 3 can do

- Distribute agents into a Microsoft tenant via the Power Platform's standard solution import flow.
- Use the customer's existing connectors — SharePoint, Dataverse, Outlook, Teams, hundreds more.
- Honor the customer's identity (Microsoft Entra ID), audit, and governance posture.
- Run as a first-class Copilot Studio surface — visible to users in the same places they already use Copilot.
- Use the customer's Azure OpenAI deployment, regional and governance-aligned.

## What Tier 3 can't do

- Iterate quickly on agent code. Solution packaging requires a build; a customer's environment requires a re-import. The dev loop stays in Tier 1.
- Replace Copilot Studio. Tier 3 *publishes into* Copilot Studio; it is not a competing surface.
- Run agents that don't fit the contract. The agent file format is Tier 1's format; Tier 3 distributes those files unchanged.

## The agent file is still the agent file

The deepest property of the platform: the same `*_agent.py` file built in a Tier 1 workshop ships into Tier 3 unchanged. See [[Three Tiers, One Model]].

The way this works at Tier 3:

1. The agent file is bundled into the solution package.
2. The Tier 3 runtime (which lives in the customer's Azure tenant, deployed alongside the solution) loads the file the same way Tier 2 does — `BasicAgent` discovery, the storage shim resolving to the real Azure backend, the LLM provider configured to the customer's Azure OpenAI deployment.
3. Copilot Studio's connector layer routes user input to the runtime's chat endpoint, receives the three-slot response, and surfaces it to the user.

The file's bytes are identical at every step. The runtime varies; the artifact does not.

## The Cloudflare worker

`worker/` is a Cloudflare Workers project that handles authentication and proxying for Tier 3. Specifically:

- Acts as the auth bridge between the Copilot Studio connector and the agent runtime in the customer's tenant.
- Provides a stable URL the connector can call, even as backend deployments change.
- Handles the JWT verification and token translation that Copilot Studio expects.

The worker's job is to make the connector's contract match what the customer's runtime exposes, with no code in either side that knows about the other.

It runs locally via:

```bash
cd worker
npx wrangler dev          # local on :8787
```

Production deployment is to Cloudflare Workers via `wrangler deploy`.

## The published solution

`MSFTAIBASMultiAgentCopilot_1_0_0_5.zip` (versioned per release) is the actual artifact a customer imports. It contains:

- The Copilot Studio agent definitions that surface in the customer's tenant.
- The connector definitions that route to the worker / runtime.
- Any required Power Platform components (custom connectors, Power Automate flows, Dataverse tables).

Customers don't open the zip; they import it via Power Platform's solution import UI. The platform's job is to make sure the zip is self-contained and version-pinned to the runtime it expects.

## Why Tier 3 exists

Without Tier 3, the platform's sequence ends at Tier 2 — a hosted Azure Function with a chat endpoint. That endpoint is callable, but it's not *integrated*. Customer users would need a custom client to talk to it; the agents wouldn't surface in Teams, in Outlook, in their existing Copilot.

Tier 3's specific contribution: **integration into the surfaces customers already use.** It is the difference between "we have a working agent in a hosted endpoint" and "the agent is a button in our employees' M365 sidebar."

That difference is why Tier 3 is non-optional for enterprise customers.

## What ships and what doesn't

- **Ships in the solution zip:** Copilot Studio agent definitions, connector configs, Power Platform components.
- **Ships in the Azure deployment (per-customer):** the runtime (Tier 2 packaging), the agent files, the storage configuration.
- **Ships in Cloudflare Workers (centrally):** the worker that bridges the connector to the runtime.

Tier 3 is the only tier whose deliverable spans three deploy targets. The Cloudflare worker is shared across customers; the Azure runtime is per-customer; the solution is what the customer imports.

## The handoff

A customer's experience of Tier 3 is the receipt of [[Self-Documenting Handoff]]:

1. Their workshop produced a Tier 1 agent file.
2. The same file (with possibly a few iterations from Tier 2 testing) goes into the next Tier 3 release.
3. The customer imports the new solution; the agent appears in their Copilot Studio.
4. End users interact with the agent in their normal Microsoft surfaces.

At no point does the agent's source code change. The customer's validation in the workshop maps directly to what end users see.

## Discipline

- Tier 3 deployments lag Tier 1 by a packaging cycle. Bug fixes that require a Tier 3 push must respect this lag.
- The solution zip is version-pinned. Customers running an older zip hit an older runtime that knows that solution's connector shape.
- The Cloudflare worker's contract is stable. Breaking changes to the worker's API are version-bumped and migrated by customers explicitly.
- New connectors are added to the solution definition, not invented in the runtime. The runtime serves agents; the solution defines the surface.

## Related

- [[Tier 1 — Local Brainstem]]
- [[Tier 2 — Cloud Swarm]]
- [[Three Tiers, One Model]]
- [[RAPP vs Copilot Studio]]
- [[Why Three Tiers, Not One]]
- [[Self-Documenting Handoff]]
