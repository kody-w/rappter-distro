---
title: The Single-File Agent Bet
status: published
section: Founding Decisions
hook: One file, one class, one perform(), one metadata dict. The constraint that makes RAPP portable, distributable, and reviewable in the same breath.
---

# The Single-File Agent Bet

> **Hook.** One file, one class, one `perform()`, one metadata dict. The constraint that makes RAPP portable, distributable, and reviewable in the same breath.

## The contract

A RAPP agent is exactly this:

- One file in `rapp_brainstem/agents/`, named `*_agent.py`.
- One class extending `BasicAgent` (the 51-line base in `agents/basic_agent.py`).
- One `metadata` dict — an OpenAI function-calling schema, used to expose the agent as a tool to the LLM.
- One `perform(**kwargs) -> str` method — the body of the work, returning a string (often JSON).
- Optionally: a `system_context() -> str | None` method that injects context into the system prompt every turn.

That is the entire surface area. There are no decorators, no registries, no entry points, no plugin manifests. The brainstem discovers agents by globbing `agents/*_agent.py` (`rapp_brainstem/brainstem.py:765` `load_agents()`) and instantiating any class that subclasses `BasicAgent`.

## Why a single file

The single-file constraint isn't aesthetic. It's load-bearing on three independent properties of the platform.

**1 — Drag-and-drop distribution.** An agent is a unit of work the user can copy from one repo to another. A single file copies cleanly; a package needs a build step, a manifest, a name resolution. The install one-liner (`curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash`) and the rapp store (`rapp_store/`) both depend on this — every entry in the store is a directory, but the *agent itself* is one file inside it.

**2 — Tier portability.** The vendoring mechanism in Tier 2 (`rapp_swarm/build.sh`) and the solution packaging in Tier 3 both treat the agent file as the unit of transit. A multi-file agent would have to declare its file set somewhere, and that "somewhere" would itself be a build artifact. The constraint avoids the problem entirely. See [[Vendoring, Not Symlinking]] and [[Three Tiers, One Model]].

**3 — Review by every audience.** The same `*_agent.py` file is read by the PM (metadata description), the developer (`perform()` body), the partner pricing the project (inputs and outputs), and the customer validating intent (system prompt and parameters). One file. Four readings. No translation. See [[The Agent IS the Spec]].

## What was rejected

- **Sibling imports.** An agent cannot `from .helper import foo`. Helpers go inline, or the agent splits into two top-level agents that talk through the LLM. The ban exists because sibling imports turn the agent from a transit unit into a coupled package — and the moment that coupling exists, the drag-and-drop story collapses.
- **Decorator-based plugin systems.** No `@register_agent`, no `@tool`. The brainstem inspects classes that inherit `BasicAgent`, and that's the registry. Adding a decorator layer would mean every consumer of the agent (Tier 2's vendoring, Tier 3's packaging, the rapp store's enumeration) would also have to know about the decorator.
- **Multi-class agents.** One file, *one* class extending `BasicAgent`. Multiple classes would force the discovery loop to pick a winner; that's the wrong shape.
- **External configuration files.** No `agent.yaml`, no `manifest.json` per agent. The metadata dict in the Python file *is* the manifest. (The `rapp_store/` packages do have a `manifest.json`, but that's the *package*'s metadata, not the agent's.)

## The minimum bar

Constitution Article III spells out what an agent must do; here is the readable version:

```python
from agents.basic_agent import BasicAgent

class HelloAgent(BasicAgent):
    def __init__(self):
        self.name = "Hello"
        self.metadata = {
            "name": self.name,
            "description": "Says hello to a person.",
            "parameters": {
                "type": "object",
                "properties": {"who": {"type": "string", "description": "Who to greet"}},
                "required": ["who"],
            },
        }
        super().__init__(name=self.name, metadata=self.metadata)

    def perform(self, **kwargs):
        return f"hello, {kwargs.get('who', 'world')}"
```

That file in `rapp_brainstem/agents/hello_agent.py` is a complete, deployable RAPP agent. It works in Tier 1 immediately. It works in Tier 2 after `rapp_swarm/build.sh`. It works in Tier 3 after a Power Platform solution rebuild. No other file changes anywhere.

## The escape hatches

The constraint has two intentional escape hatches that don't break it:

- **`utils/`** — shared utilities that *every* agent can import. These are part of the brainstem's contract, not part of any single agent. New utilities go here only if every tier vendors them (see `rapp_swarm/_vendored/utils/`).
- **The data slush** — multi-step pipelines compose from multiple single-file agents through the `data_slush` JSON channel. There is no orchestration framework; the LLM picks which agent to call next based on the deterministic state in the previous agent's return value. See [[Data Sloshing]].

## Discipline

- When an agent grows past ~300 lines, the question isn't "how do we split this file?" — it's "what are the two agents hiding in here?"
- When you need a helper, write it inline. If the helper grows, ask whether it's *the agent* or *a different agent*.
- When tempted to add a decorator, a registry, or a manifest layer, ask: "would this still work if I copied just the `*_agent.py` file to a new repo?"
- The single-file rule is checked by the brainstem, not by humans — `_load_agent_from_file()` (`brainstem.py:604`) is the only loader, and it doesn't read anything besides the agent file.

## When to reconsider

The single-file rule survives every contested call so far. The only credible challenge would be an agent so large that a single file becomes unreadable — and the platform's record (the deletion of `hatch_rapp_agent.py` at 2,138 lines, the deletion of `pitch_deck_agent.py` at 1,087 lines) shows that "unreadable" is the signal to *split into more agents*, not to relax the rule. See [[Why hatch_rapp Was Killed]].

## Related

- [[Engine, Not Experience]]
- [[The Agent IS the Spec]]
- [[Self-Documenting Handoff]]
- [[Data Sloshing]]
- [[Three Tiers, One Model]]
- [[Why hatch_rapp Was Killed]]
