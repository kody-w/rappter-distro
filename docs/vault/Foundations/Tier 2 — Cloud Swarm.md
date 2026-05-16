---
title: Tier 2 — Cloud Swarm
status: published
section: Foundations
hook: Azure Functions deploy of the same agents. Multi-tenant. Scheduled. Vendors brainstem code into _vendored/ to keep the contract honest.
---

# Tier 2 — Cloud Swarm

> **Hook.** Azure Functions deploy of the same agents. Multi-tenant. Scheduled. Vendors brainstem code into `_vendored/` to keep the contract honest.

## What it is

Tier 2 is the cloud-hosted version of the brainstem. It lives in `rapp_swarm/` and runs as an Azure Functions app. The Tier 2 deploy serves the same agents Tier 1 serves, but in a multi-tenant, scheduled, cloud-native shape.

It exists to address what Tier 1 cannot do:

- A laptop is not a tenant boundary. Tier 2 lives in the customer's Azure subscription.
- A laptop is not a scheduler. Azure Functions has cron-trigger and queue-trigger primitives that turn "run this every 4 hours" into a one-line addition.
- A laptop is not isolated. Tier 2 isolates each tenant's data using Azure File Shares scoped to identity.

See [[Why Three Tiers, Not One]] for the full reasoning.

## Where it lives in the repo

```
rapp_swarm/
  function_app.py         # the Tier 2 entry point — Azure Functions handler
  build.sh                # vendoring script: copies brainstem core into _vendored/
  host.json               # Azure Functions runtime config
  local.settings.json     # local-dev settings (gitignored)
  _vendored/              # vendored brainstem core (output of build.sh)
    agents/               # the shared agents — basic_agent, context_memory, manage_memory, workiq, etc.
    utils/                # the shared utilities — llm.py, azure_file_storage.py, twin.py, etc.
  utils/                  # Tier 2's own utilities (Azure-specific extensions)
    azure_file_storage.py # the REAL Azure File Storage backend
    copilot_auth.py
    environment.py
    local_file_storage.py # local-dev fallback
    result.py
    storage_factory.py
  README.md
```

The split between `_vendored/` (synced from Tier 1) and `utils/` (Tier 2 native) is deliberate. The vendored copy is treated as *build output* — never edited directly. The native `utils/` is for Tier 2 specifics that don't apply to Tier 1.

## How vendoring works

`rapp_swarm/build.sh` copies brainstem core files into `_vendored/`. The script's job is to make sure Tier 2 has a complete agent runtime in-tree:

- `_vendored/agents/basic_agent.py` matches `rapp_brainstem/agents/basic_agent.py`.
- `_vendored/agents/<shared_agent>.py` matches `rapp_brainstem/agents/<shared_agent>.py`.
- `_vendored/utils/llm.py` matches `rapp_brainstem/utils/llm.py`.
- ... and so on for every shared file.

After `build.sh` runs, the Azure Functions deploy package contains every dependency it needs. There are no symlinks to follow, no submodules to fetch, no relative imports that cross a directory boundary.

The duplication is intentional. It is the platform's mechanism for keeping the tiers honest about cross-tier changes. See [[Vendoring, Not Symlinking]].

## What Tier 2 can do

- Run any agent that respects the platform contract — the same agents Tier 1 runs.
- Schedule workloads via Azure Functions triggers (timer, queue, HTTP, blob).
- Multi-tenant isolation via tenant-scoped Azure File Shares.
- Run inside the customer's Azure subscription, behind their identity, in their region.
- Allow up to **4 tool-call rounds** per chat (Tier 1 allows 3) — Azure Functions has different timeout characteristics.

## What Tier 2 can't do

- Drag-and-drop agent edits at runtime. Azure Functions packaging requires a deploy. The fast iteration loop stays in Tier 1.
- GitHub Copilot API auth. The auth cascade in Tier 1 (`GITHUB_TOKEN` → `.copilot_token` → `gh auth token`) doesn't apply; Tier 2 uses Azure OpenAI, OpenAI, or Anthropic via standard env-var keys.
- Voice/Twin UI rendering. Tier 2 returns the three-slot response payload; whatever consumes it (Tier 3 connector, Tier 1 web UI proxying to Tier 2, custom client) is responsible for the rendering.

## How agents reach storage in Tier 2

Agents call `from utils.azure_file_storage import AzureFileStorageManager`. In Tier 2, that import resolves to the **real** Azure File Storage SDK module — `rapp_swarm/_vendored/utils/azure_file_storage.py` (or, more accurately, the Azure SDK as wrapped). No shim. The agent's source code is identical to Tier 1, but the import lands on the real Azure backend.

This is the mechanism that makes the portability claim work across tiers. See [[Local Storage Shim via sys.modules]].

## How it picks an LLM provider

Same `utils/llm.py` logic as Tier 1 (vendored): Azure OpenAI > OpenAI > Anthropic > fake. Selection by environment variables. The agent doesn't know which provider is running.

The expected configuration in production is **Azure OpenAI** — the customer's own deployment, in their tenant, governed by their connectors. That posture is why Tier 2 exists.

## Local development

Tier 2 can run locally via Azure Functions Core Tools:

```bash
bash rapp_swarm/build.sh                   # vendor latest brainstem core
cd rapp_swarm
func start                                 # local Azure Functions runtime
```

This is for *Tier 2 development*, not for the workshop loop. The workshop runs in Tier 1.

## Deployment

Production deployment uses the standard Azure Functions deploy paths — VS Code extension, Azure CLI (`az functionapp`), or GitHub Actions. The deploy artifact includes `_vendored/`, so the agent runtime is self-contained.

`azuredeploy.json` at the repo root provides an ARM template for one-click provisioning into a customer tenant.

## What's tested where

The contract tests (`tests/run-tests.mjs`) run against both Tier 1's `rapp_brainstem/` and Tier 2's `rapp_swarm/_vendored/`. If Tier 1 has a feature Tier 2's vendored copy lacks, the tests diverge — that's the signal to re-run `build.sh`. Test divergence is the platform's drift detector.

## Discipline

- `_vendored/` is build output. Never edited directly. The discipline is to edit Tier 1's source and re-run `build.sh`.
- Brainstem-level changes that affect Tier 2 are paired with a `build.sh` re-run *in the same commit*. This makes cross-tier impact visible to reviewers.
- Tier 2's native `utils/` is for Azure-specific extensions; anything that should run in all three tiers belongs in Tier 1's `utils/` and gets vendored.
- The `function_app.py` entry point honors the same agent contract as `brainstem.py`'s `chat()` route. Same input shape, same output shape, same slot vocabulary.

## Related

- [[Tier 1 — Local Brainstem]]
- [[Tier 3 — Enterprise Power Platform]]
- [[Three Tiers, One Model]]
- [[Vendoring, Not Symlinking]]
- [[Local Storage Shim via sys.modules]]
- [[Why Three Tiers, Not One]]
