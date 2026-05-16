---
title: Engine, Not Experience
status: published
section: Founding Decisions
hook: RAPP ships infrastructure, not an opinionated UI. The platform's job is to make agents possible — not to decide what an agent feels like.
---

# Engine, Not Experience

> **Hook.** RAPP ships infrastructure, not an opinionated UI. The platform's job is to make agents possible — not to decide what an agent feels like.

## The commitment

Every platform that ships agents has the same temptation: ship the experience that makes the platform feel finished. A chat UI with the right gradients. A workflow editor with snap-to-grid nodes. A template gallery so the first-run experience writes itself. A "best practices" section that quietly ossifies into a framework.

RAPP rejects all of that. The repo ships:

- A Flask server (`rapp_brainstem/brainstem.py`, ~1,650 lines) that loads agents from disk on every request, wires them as OpenAI-format tools, dispatches an LLM call, splits the response on two delimiters, and gets out of the way.
- A 51-line base class (`rapp_brainstem/agents/basic_agent.py`) that defines the agent contract: a name, a metadata dict, a `perform(**kwargs)` method, and an optional `system_context()` hook.
- A web UI (`rapp_brainstem/web/index.html`) that is explicitly a *view onto agents*, not the product itself.

That's the engine. Everything else is the user's choice.

## What was rejected

The rejected directions weren't bad ideas in the abstract. They were rejected because shipping them would have made the platform decide what an agent is *for* — and that's the user's job, not the platform's.

- **A workflow / DAG editor.** Tempting, especially because LLMs do well with graphs. But every workflow editor encodes a model of "what an agent is" — a node, a trigger, a transition. RAPP's model is a Python file. There is no graph, because the user might not want one.
- **A template gallery.** The repo ships starter agents in `rapp_brainstem/agents/` — `manage_memory_agent.py`, `context_memory_agent.py`, `workiq_agent.py`. They are *examples*, not *templates*. There is no "new from template" button anywhere, because the repo is the gallery.
- **A built-in pipeline framework.** `data_slush` (see [[Data Sloshing]]) is the entire pipeline mechanism — a JSON dict that one agent returns and the next agent reads. There is no chain, no DAG, no orchestrator. Pipelines are emergent, not declared.
- **A settings / preferences UI.** Configuration goes in `.env` and the user's filesystem. Behavioral calibration goes in the twin (see [[Calibration Is Behavioral, Not Explicit]]). Anything in between is a category error.

## How the line is held

The engine-vs-experience line is enforced by **CONSTITUTION Article I — The Brainstem Stays Light**. The only legitimate change to `brainstem.py` is adding a new top-level output slot, and that is so expensive it has happened twice in the platform's history (`|||VOICE|||` and `|||TWIN|||`).

For everything else, the question is inverted: instead of "what feature does the brainstem need?" the question is "what agent does the user need?" That inversion is the whole platform.

Concretely, when a request would add to `brainstem.py`, the test is:

1. Could this be an agent in `rapp_brainstem/agents/` instead?
2. Could it be a tag inside an existing slot rather than a new slot?
3. Could it be a single-file HTTP service (per Constitution Sacred Constraint #2) rather than a brainstem route?

If the answer to any of those is yes, the brainstem doesn't change. The result is a kernel that looks identical at v0.4.0 and v0.12.1 — by design.

## The view, not the product

The web UI at `rapp_brainstem/web/index.html` is a chat interface. It is also a deliberate non-product. It exists so the platform is *usable* during development; it does not exist to be the user's eventual home.

Tier 3 (Power Platform) targets Microsoft Copilot Studio. Tier 2 (Azure Functions) is consumed by whatever the customer's tenant routes to it. Tier 1 (the local brainstem) ships a UI because a local Flask server with no UI would be hostile to the workshop loop. None of these is the product. The product is the agent file.

## When this rule should be reconsidered

The line moves *outward* (toward more engine, less experience) more often than inward. The historical examples:

- **Removed:** `swarm_server.py` (1,736 lines) and `t2t.py` (337 lines) — both reclaimed scope back into the brainstem's existing contract. See [[Why t2t and swarm_server Are Gone]].
- **Removed:** the entire `agents/experimental/` directory of brief-pipeline specialists — too much workflow opinion for a single capability. See [[The experimental Graveyard]].
- **Removed:** `pitch_deck_agent.py` (1,087 lines) — too much template opinion for a single agent.

If the line ever needs to move inward (more experience, less engine), the test is: would the move still pass through Tier 2 and Tier 3 unchanged? Most experience-shaped features fail this test by construction.

## Discipline

- New code defaults to a new agent, not a new brainstem feature.
- New agent defaults to a single file with a metadata dict and a `perform()` body — no companion modules.
- New UI defaults to a *view*, never a *product*. Anything labeled "the user's home" is the wrong shape.
- When tempted to ship "the experience that makes the platform feel finished," remember: the platform feels finished when the agents finish things, not when the platform does.

## Related

- [[The Brainstem Tax]]
- [[The Single-File Agent Bet]]
- [[The Engine Stays Small]]
- [[Voice and Twin Are Forever]]
