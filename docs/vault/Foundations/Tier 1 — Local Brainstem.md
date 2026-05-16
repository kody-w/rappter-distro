---
title: Tier 1 — Local Brainstem
status: published
section: Foundations
hook: A Flask server on :7071. Edit an agent, save, run a chat. The development tier — and the only one with the iteration loop.
---

# Tier 1 — Local Brainstem

> **Hook.** A Flask server on `:7071`. Edit an agent, save, run a chat. The development tier — and the only one with the iteration loop.

## What it is

Tier 1 is the local brainstem — a Python Flask server in `rapp_brainstem/`. Single dependency: a GitHub account with Copilot access (the auth cascade handles the rest — see [[The Auth Cascade]]).

The server runs on `:7071`. The web UI at `/` is served by `rapp_brainstem/web/index.html`. Agents live in `rapp_brainstem/agents/`. Every chat request reloads agents from disk, so editing a file and saving is enough to test the new behavior. No restart. No build step. No deploy.

This is the only tier where the **fast iteration loop** exists, and that's its job.

## Where it lives in the repo

```
rapp_brainstem/
  brainstem.py            # ~1,650-line Flask server (the core engine)
  soul.md                 # default system prompt
  agents/                 # auto-loaded agents (flat directory)
    basic_agent.py        # base class
    context_memory_agent.py
    manage_memory_agent.py
    workiq_agent.py
    ...
  utils/                  # shared utilities, vendored to Tier 2
    llm.py                # provider dispatch (Azure OpenAI / OpenAI / Anthropic / fake)
    local_storage.py      # local backend for the storage shim
    twin.py               # twin-related helpers
    _basic_agent_shim.py  # legacy compatibility
  web/                    # the UI surface
    index.html            # main chat UI
    manage.html           # agent management
    onboard/              # onboarding
    mobile/               # mobile UI
  start.sh, start.ps1     # launchers (one-liner-callable)
  requirements.txt
  VERSION                 # currently 0.12.x
```

## What it can do

- Run any agent that respects the platform contract.
- Reload agents from disk per request — the workshop iteration loop.
- Provide voice mode (TTS-friendly response shaping) and twin mode (digital-twin reflection in `|||TWIN|||`).
- Auth via the GitHub Copilot API, Azure OpenAI, OpenAI, Anthropic, or a deterministic fake (`LLM_FAKE=1`).
- Persist memory locally under `rapp_brainstem/.brainstem_data/` (the local backend of the storage shim — see [[Local Storage Shim via sys.modules]]).

## What it can't do

- Schedule cron-shaped workloads. Tier 1 is interactive only.
- Multi-tenant isolation. The server is one process, one user.
- Survive a customer's audit boundary. A laptop is not a tenant.
- Distribute the agent file to a known user population. That's Tier 3's job.

These limits are deliberate; addressing any of them is what Tiers 2 and 3 exist for. See [[Why Three Tiers, Not One]].

## Why it ships a UI

Tier 1's web UI (`rapp_brainstem/web/index.html`) is a chat interface. It is a *view*, not a product. The reason it exists at all:

- A local Flask server with no UI is hostile to the workshop loop.
- Customers in the room need to *see* the conversation happen.
- The UI needs to render the three response slots (main, voice, twin) cleanly.

The UI is not the product. It is the surface that makes Tier 1's iteration loop usable. See [[Engine, Not Experience]] for why this distinction matters.

## How agents reach storage

Agents call `from utils.azure_file_storage import AzureFileStorageManager`. In Tier 1, the brainstem hijacks that import via `sys.modules` (`brainstem.py:648` `_register_shims()`) and provides a JSON-file backend in `utils/local_storage.py`. The agent's source code is identical to what would run in Tier 2 / Tier 3; only the import resolves differently.

This is the mechanism that makes the platform's portability claim honest in Tier 1. See [[Local Storage Shim via sys.modules]].

## How it picks an LLM provider

`utils/llm.py`'s `detect_provider()` selects the first available:

1. `LLM_FAKE=1` → deterministic fake (test mode).
2. Azure OpenAI creds → Azure OpenAI.
3. OpenAI creds → OpenAI.
4. Anthropic creds → Anthropic.
5. None → fall back to fake.

Tier 1 is the only tier that *also* knows how to talk to GitHub Copilot's API (via the auth cascade in `brainstem.py:183-310`). Tier 2 doesn't, because Azure Functions deployments don't ship the GitHub auth flow. The Copilot path is Tier 1's specific shortcut for local-dev convenience.

## How tool calls work

When the LLM returns a `tool_calls` field, `run_tool_calls()` (`brainstem.py:866`) executes the corresponding agents and appends results to the conversation history. The brainstem loops up to **3 rounds** before giving up. (Tier 2 allows 4 rounds — same code, different limit, because Azure Functions has different timeout characteristics.)

## How responses split

The final assistant message is partitioned on `|||VOICE|||` and `|||TWIN|||` (`brainstem.py:984-998`). The HTTP response has three keys: `response`, `voice_response`, `twin_response`. The UI renders three regions. The slots are forever (see [[Voice and Twin Are Forever]]).

## How to start it

```bash
cd rapp_brainstem
./start.sh
```

`start.sh` creates a venv if needed, installs dependencies, and runs `python brainstem.py`. The server logs its port and is reachable at `http://localhost:7071`.

For a fresh install on a clean machine, the install one-liner does this end-to-end:

```bash
curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash
```

## What's in `.brainstem_data/`

Runtime state lives under `rapp_brainstem/.brainstem_data/` (gitignored). Memory files, session state, anything the brainstem produces that isn't agent source code. Constitution Article XVI separates *the engine's surface* (clean, reviewed, committed) from *the brainstem's workspace* (scratch, gitignored). `.brainstem_data/` is the workspace.

## Discipline

- New agents go in `agents/` flat. The `agents/experimental/` directory is intentionally excluded from auto-load.
- Edits to `brainstem.py` are reviewed against [[The Brainstem Tax]] — could this be an agent instead?
- The web UI is `web/`'s problem, not the brainstem's. Routes that serve UI assets are minimal; everything else lives client-side.
- Tier 1 changes that affect Tier 2 require a `rapp_swarm/build.sh` re-run in the same change. See [[Vendoring, Not Symlinking]].

## Related

- [[Tier 2 — Cloud Swarm]]
- [[Tier 3 — Enterprise Power Platform]]
- [[Three Tiers, One Model]]
- [[The Auth Cascade]]
- [[Local Storage Shim via sys.modules]]
