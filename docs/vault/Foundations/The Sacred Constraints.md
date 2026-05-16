---
title: The Sacred Constraints
status: published
section: Foundations
hook: Six inviolable rules. Single-file agents. Single-file services. Agent-first. Brainstem light. Slots forever. Tier portability.
---

# The Sacred Constraints

> **Hook.** Six inviolable rules. Single-file agents. Single-file services. Agent-first. Brainstem light. Slots forever. Tier portability.

## The six

The platform's `CLAUDE.md` lists six sacred constraints. They are the rules that don't bend. Every other rule in the constitution is downstream of one of these.

### 1. Single-file agents are the plugin system

> **One file = one class extending `BasicAgent` = one `perform()` = one metadata dict. No build steps, no sibling imports, no frameworks.**

This is the constraint that makes the platform portable, distributable, and reviewable in one breath. An agent is a *unit of transit* — copyable across repos, vendorable into other tiers, readable by every audience. A multi-file agent breaks all three properties at once.

See [[The Single-File Agent Bet]] for the full essay.

### 2. Single-file services are the HTTP extension system

> **One file = `name` + `handle(method, path, body) → (dict, status)`. Dispatched via `/api/<name>/<path>`. Services serve UIs; agents serve LLMs. They never overlap.**

Agents and services occupy different roles by construction. Agents are called *by the LLM* via tool dispatch; services are called *by HTTP clients* (typically the management UI or an external integration). Mixing the two would let one capability be reached two ways with two different security contexts — an architectural smell.

The single-file rule applies to services for the same reasons it applies to agents: portability, reviewability, drag-and-drop distribution.

### 3. Agent-first rule

> **Every rapplication MUST work fully through the agent alone. The service is always optional — it's a view, not the application.**

A *rapplication* is a packaged capability in `rapp_store/`. It can ship an agent, or an agent + a service, but the service is never the only entry point. If a feature requires a service to function, the feature is the wrong shape — the agent should be sufficient on its own.

This constraint preserves the "agent IS the spec" property at the rapplication level: a partner reading a rapplication should be able to evaluate it from the agent file alone, without firing up the service to see what it does.

### 4. The brainstem stays light

> **The kernel is `brainstem.py` + `basic_agent.py`. It provides agent discovery and service discovery — nothing else. New features → new agents or services, not brainstem changes.**

The brainstem is shared cost. Every line in it is a line every agent runs on top of. Growing the brainstem is taxing every agent. The forcing question is *"could this be an agent or a service instead?"* — and almost always, the answer is yes.

See [[The Brainstem Tax]] and [[Engine, Not Experience]] for the full essays.

### 5. Delimited slots are fixed forever

> **`|||VOICE|||` and `|||TWIN|||` never get repurposed or overloaded. New sub-capabilities use tags inside the slot.**

Two slots, two audiences. Voice is for TTS listeners; twin is for the user's digital twin. Adding a third slot would force every prompt template, every parser, every Tier 2/3 adapter to migrate in lockstep. The platform paid that cost twice and won't pay it again without unprecedented justification.

See [[Voice and Twin Are Forever]] for the full essay.

### 6. Tier portability is a guarantee

> **An agent that runs in Tier 1 must run unmodified in Tier 2 & 3.**

The same `*_agent.py` file in Tier 1 is byte-identical to the file in Tier 2's vendored copy and the file inside the Tier 3 Power Platform solution. The customer's workshop deliverable is the production deployable. There is no rewrite phase.

See [[Three Tiers, One Model]] and [[Why Three Tiers, Not One]] for the full essays.

## Why "sacred"

The word is used deliberately. Most platforms have *guidelines* and *recommendations*; RAPP has constraints that, if violated, break the platform's core claims:

- Violating constraint 1 breaks the workshop deliverable, the partner handoff, and the rapp store catalog all at once.
- Violating constraint 2 makes services and agents indistinguishable, eroding the boundary between LLM-callable and HTTP-callable capabilities.
- Violating constraint 3 makes the rapplication evaluation property collapse — readers can't trust that the agent file describes the whole capability.
- Violating constraint 4 makes every existing agent slower to read and harder to maintain.
- Violating constraint 5 forces a migration cost across every tier, every fixture, and every consumer.
- Violating constraint 6 means the platform's central claim ("three tiers, one model") becomes false, and the entire delivery model collapses.

Each constraint is what makes another property true. Calling them sacred is calling them load-bearing.

## How they're enforced

The constraints are enforced at multiple layers:

- **By the loader.** `_load_agent_from_file()` (`rapp_brainstem/brainstem.py:604`) reads exactly one file and instantiates exactly the `BasicAgent` subclasses found in it. There is no facility for multi-file agents.
- **By the discovery patterns.** Agents are discovered by globbing `agents/*_agent.py` (flat). Services follow the same pattern at the rapp store level — one file declares the service.
- **By the route dispatcher.** Services live behind `/api/<name>/<path>`; agents live behind tool-call dispatch. The two surfaces are mechanically separate.
- **By the parser.** The slot delimiter split (`brainstem.py:984-998`) is hardcoded to `|||VOICE|||` and `|||TWIN|||`. New literals would require a code change in every consumer.
- **By the vendoring step.** `rapp_swarm/build.sh` copies brainstem code into Tier 2's `_vendored/` directory. Drift between Tier 1 and Tier 2 surfaces in test runs.
- **By the test suite.** `tests/run-tests.mjs` exercises the agent contract against the fake LLM (`LLM_FAKE=1`); cross-tier violations show up as test failures.

## What changing one would cost

Each constraint has been considered for relaxation at least once. Each relaxation was rejected.

- **Relaxing constraint 1** ("let agents have helper modules") would force the rapp store, Tier 2 vendoring, and Tier 3 packaging each to grow file-set semantics. The blast radius is the entire distribution chain.
- **Relaxing constraint 2** ("let services do agent things") would let the same capability be invoked through two paths with two different context shapes. The contract would have two definitions of "what an X is."
- **Relaxing constraint 3** ("let some rapplications be service-only") would give certain rapplications a UI-bound surface that no LLM can reach. The platform's central abstraction (LLM picks tools) breaks for those rapplications.
- **Relaxing constraint 4** ("let the brainstem grow this one feature") would set a precedent. The brainstem's small size is preserved by *no exceptions*, not by *small exceptions*.
- **Relaxing constraint 5** ("let's add `|||X|||`") would touch every prompt template, every parser, every fixture, every Tier 2/3 adapter. The migration cost is multi-week.
- **Relaxing constraint 6** ("let's allow tier-specific agents") would deprecate the platform's central claim. The remaining value would be a single-tier framework.

The constraints survive every contested call because their relaxation is more expensive than the convenience that motivates relaxation.

## When to reconsider

The six constraints are not equally rigid:

- Constraints 1 and 2 are fully rigid; relaxation is functionally a different platform.
- Constraint 3 is rigid; the agent-first rule is what keeps rapplications partner-readable.
- Constraint 4 is rigid; the only legitimate growth is by adding a new slot (which is constraint 5's bar).
- Constraint 5 is rigid except for the slot-addition path that has been used twice (`|||VOICE|||`, `|||TWIN|||`) and remains theoretically open.
- Constraint 6 is rigid; relaxation is conditioned on a new tier emerging that fundamentally cannot honor the contract.

In every case, the burden of proof is on the relaxer. The default is "no."

## What this rules out

- ❌ "Special exception" agents with their own multi-file packaging.
- ❌ Services that act like agents (LLM-callable through tool dispatch).
- ❌ Rapplications that ship a service with no agent.
- ❌ Brainstem features added because "they're tiny."
- ❌ Adding a slot to "make X easier."
- ❌ Tier-specific agent code paths.
- ❌ Documentation that hedges on the constraints. *"Mostly single-file"* and *"usually portable"* are not allowed; the platform either makes the claim or doesn't.

## Discipline

- New PRs that touch any of the six are reviewed against the relaxation cost listed above.
- "These are guidelines" is the failure mode. They are constraints. Treating them as guidelines is how platforms drift.
- When confused about whether a proposed change violates a constraint, the safer default is "yes, it does." The constraints are conservative by design.

## Related

- [[The Single-File Agent Bet]]
- [[The Brainstem Tax]]
- [[Voice and Twin Are Forever]]
- [[Three Tiers, One Model]]
- [[Engine, Not Experience]]
- [[The Engine Stays Small]]
