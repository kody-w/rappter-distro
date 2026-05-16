---
title: Glossary
status: published
section: Foundations
hook: Every domain term, with one paragraph and a link to the deep post. The shortest path to fluent.
---

# Glossary

> **Hook.** Every domain term, with one paragraph and a link to the deep post. The shortest path to fluent.

Skim once. Refer back as needed. Each entry links to the note that expands it.

## Agent

A single Python file in `agents/` (Tier 1) or `_vendored/agents/` (Tier 2), defining one class extending `BasicAgent` with a metadata dict and a `perform(**kwargs) -> str` method. The unit of capability the platform ships. → [[The Single-File Agent Bet]], [[The Agent IS the Spec]].

## BasicAgent

The 51-line base class every agent extends (`rapp_brainstem/agents/basic_agent.py`). Defines the agent contract: `name`, `metadata`, `perform()`, optional `system_context()`. → [[The Single-File Agent Bet]].

## Binder

The per-session, per-user state file (`.binder.json`) where the twin caches its current working hypotheses about the user. Read into the system prompt every turn. Updated by behavioral signal — accepted offers, rejected offers, edits to artifacts. → [[Calibration Is Behavioral, Not Explicit]].

## Brainstem

The platform's kernel. `rapp_brainstem/brainstem.py` (~1,650 lines) hosts the Flask server, agent discovery, tool dispatch, slot splitting, and the auth cascade. The brainstem is shared cost — every line is paid by every agent. → [[The Brainstem Tax]], [[Engine, Not Experience]].

## Brainstem workspace

`.brainstem_data/` (and similar). Where the brainstem dumps runtime state — memory files, session logs, calibration. Gitignored. Distinct from the *engine surface* (clean, committed, reviewed). → [[Roots Are Public Surfaces]].

## Calibration

The twin's behavioral learning loop. Each `<probe>` tag is a hypothesis; each `<calibration>` tag is the verdict from a later turn. The twin's understanding of the user is built from these signals — never from a settings page. → [[Calibration Is Behavioral, Not Explicit]], [[Every Twin Surface Is a Calibration Opportunity]].

## Card / Index card

A live artifact emitted by an agent at every step of a multi-step process. The card pattern (commits `dd1434b`, `f397b67`) provides a canonical surface where the user can track an agent's work and intervene. The pattern is calibration-shaped. → [[Every Twin Surface Is a Calibration Opportunity]].

## Constitution

`CONSTITUTION.md` and inside `rapp_brainstem/`. The governance document. Currently 24 articles plus the closing flourish. The vault expands the *why* behind the rules. → [[Constitution Reading Order]].

## Data slush

The optional `data_slush` key inside an agent's JSON return value. The downstream agent reads `self.context.slush` deterministically — no LLM interpretation. The mechanism that makes pipelines composable without an orchestration framework. → [[Data Sloshing]].

## Discovery

In RAPP terms, *agent discovery* — the brainstem globs `agents/*_agent.py` and instantiates `BasicAgent` subclasses. There is no registry; the filesystem is the registry. → [[The Single-File Agent Bet]].

## Engine

The brainstem + the small set of shared utilities (`utils/`). Distinct from the *agents*, which are user code. The engine stays small so agents can be everything. → [[The Engine Stays Small]].

## Fake LLM / `LLM_FAKE=1`

A deterministic provider in `utils/llm.py` (`chat_fake()`). When tools are available, calls the first one with empty arguments; otherwise echoes the last user message. Load-bearing for the test suite — it makes pipelines testable without a real LLM. → [[The Deterministic Fake LLM]].

## Hatch / hatch_rapp

The (deleted) 2,138-line mega-agent that tried to *generate* other agents. Killed because it was multiple agents wearing one filename. The pattern survived in `swarm_factory_agent.py` and `vibe_builder_agent.py`. → [[Why hatch_rapp Was Killed]].

## Install one-liner

`curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash`. The platform's distribution channel. Sacred per CONSTITUTION Article V. → [[Why GitHub Pages Is the Distribution Channel]].

## LLM dispatch / `utils/llm.py`

The 247-line provider abstraction. Four providers (Azure OpenAI, OpenAI, Anthropic, fake), one entry point (`chat()`), one return shape. Selection by env vars; the agent doesn't know which is running. → [[The Deterministic Fake LLM]].

## Manifest (rapp store)

A `manifest.json` inside a `rapp_store/<package>/` directory. Declares the package's metadata — author, version, agents, services. Distinct from an agent's *metadata dict*, which is the agent's own contract. → [[Self-Documenting Handoff]].

## Memory

Persisted state about the user. Two agents handle it: `manage_memory_agent.py` (writes) and `context_memory_agent.py` (injects relevant memory into the system prompt). Storage is via the shim — local JSON in Tier 1, Azure File Storage in Tier 2/3. → [[From save_recall to manage_memory]].

## Metadata (agent)

The dict on every agent declaring its `name`, `description`, and `parameters` schema. OpenAI function-calling shape. Operative — the description determines when the LLM calls the agent. → [[The Agent IS the Spec]].

## Power Platform solution

The Tier 3 distribution artifact. A `.zip` the customer imports into their Microsoft tenant. → [[Tier 3 — Enterprise Power Platform]].

## Probe

A `<probe>` tag inside the TWIN slot. The twin marking a claim with a unique id and confidence — something it can be wrong about. Closed by a later `<calibration>` tag. → [[Every Twin Surface Is a Calibration Opportunity]].

## Provider

An LLM backend supported by `utils/llm.py`. Currently: `azure-openai`, `openai`, `anthropic`, `fake`. Add a provider by extending `chat()`'s dispatch and conforming to the existing input/output shape. → [[The Deterministic Fake LLM]].

## Rapplication

A single-file *composed pipeline* — one `*_agent.py` that orchestrates other agents internally via tool dispatch and `data_slush`. Distributed via the rapp store. The constitution insists rapplications stay one file. → [[The Single-File Agent Bet]].

## Rapp store / `rapp_store/`

The catalog of community-publishable agents and services. Each entry is a directory with a `manifest.json`. → [[Roots Are Public Surfaces]].

## Sacred constraint

One of the six inviolable rules that the platform's claims depend on: single-file agents, single-file services, agent-first rule, brainstem light, slots forever, tier portability. → [[The Sacred Constraints]].

## Service (rapp store)

A single-file HTTP service in a `rapp_store/<package>/` directory. Constitution Sacred Constraint #2 — services serve UIs; agents serve LLMs. They never overlap. → [[The Sacred Constraints]].

## Shim / sys.modules shim

The mechanism by which agents look like they import Azure SDKs but actually get a local backend in Tier 1. Set up in `_register_shims()` (`brainstem.py:648`). Preserves portability without making agents tier-aware. → [[Local Storage Shim via sys.modules]].

## Slot

A delimited region of an LLM response. RAPP has two: `|||VOICE|||` (TTS-ready) and `|||TWIN|||` (digital twin reaction). Forever per CONSTITUTION Article II. → [[Voice and Twin Are Forever]].

## Slush

Short for `data_slush`. See: data slush.

## Soul / `soul.md`

The default system prompt loaded on every chat request. Defines the assistant's voice and posture. Per-agent additions come via `system_context()`. → [[The Twin Offers, The User Accepts]].

## Swarm

A *directory* of agents working toward a goal. CONSTITUTION Article XIV — swarms are directories, not routes. The `swarm_factory_agent` produces them. → [[Why t2t and swarm_server Are Gone]].

## System context

An optional method on `BasicAgent` (`system_context() -> str | None`) that injects text into the system prompt every turn. Used by `context_memory_agent` to surface relevant memory. → [[Calibration Is Behavioral, Not Explicit]].

## Tier 1 / 2 / 3

The three runtime targets — local Flask, Azure Functions, Power Platform. Same agents, different deploy paths. → [[Three Tiers, One Model]].

## Tool / Tool call

The OpenAI function-calling shape. Each loaded agent becomes a tool the LLM can invoke. `BasicAgent.to_tool()` produces the schema. → [[The Single-File Agent Bet]].

## Twin

The user's digital twin — a model of their thinking, talking back to them in first-person. Lives in the `|||TWIN|||` slot. Offers, never demands. → [[The Twin Offers, The User Accepts]].

## Vendoring

Tier 2's mechanism for sharing code with Tier 1. `rapp_swarm/build.sh` copies brainstem core files into `rapp_swarm/_vendored/`. The duplication is the receipt. → [[Vendoring, Not Symlinking]].

## Voice

The `|||VOICE|||` slot — a TTS-ready, 2-3 sentence version of the response. Different audience from the main response (auditory listener vs. visual reader). → [[Voice and Twin Are Forever]].

## Workspace

A user-organized directory inside `agents/` for grouping related agents. CONSTITUTION Article XVII — `agents/` IS the user's workspace. → [[Roots Are Public Surfaces]].

## Related

- [[How to Read This Vault]]
- [[The Sacred Constraints]]
- [[The Platform in 90 Seconds]]
- [[Constitution Reading Order]]
