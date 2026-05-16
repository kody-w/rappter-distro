---
title: The Brainstem Tax
status: published
section: Founding Decisions
hook: Every line in brainstem.py is a line every agent now pays for. Article I told as economics, not edict.
---

# The Brainstem Tax

> **Hook.** Every line in `brainstem.py` is a line every agent now pays for. Article I told as economics, not edict.

## The economy

There is a fixed budget of complexity in any platform. That budget is divided across two ledgers:

- **The brainstem ledger.** Code in `rapp_brainstem/brainstem.py` and the small set of shared utilities under `utils/`. Every line here is read, vendored to Tier 2, packaged in Tier 3, and present in every agent's runtime. It is shared cost — every agent author pays for it whether they wanted it or not.
- **The agent ledger.** Code in `rapp_brainstem/agents/*.py` and the rapp store. Each line costs only the agent that contains it. Authors choose to pay; consumers choose to copy.

The platform's job is to keep the brainstem ledger small. **Every feature in the brainstem is a tax on every agent.**

## Why this is economics, not aesthetics

CONSTITUTION Article I (*The Brainstem Stays Light*) reads as dogma. The economic framing is more useful in arguments:

- A 30-line addition to `brainstem.py` is read by every agent author trying to understand the platform — multiplied across all readers, that's not 30 lines of cost, it's 30 × N.
- An agent that adds a 30-line capability is read only by people who use it. The cost is bounded.
- Worse: a feature in the brainstem becomes implicit. It looks like "how RAPP works." Removing it later is harder than removing an agent — and shared code that isn't critically reviewed becomes load-bearing by accident.

The brainstem tax is the rate at which "small" additions to the kernel become permanent.

## The forcing question

When a request would add to the brainstem, the first question is always: **could this be an agent instead?**

The forcing question has historical receipts:

- **Memory** is an agent (`agents/manage_memory_agent.py`, `agents/context_memory_agent.py`), not a brainstem feature.
- **Workspace inbox / WorkIQ** is an agent (`agents/workiq_agent.py`), not a brainstem route.
- **Swarm production** is a rapp store agent (`rapp_store/swarm_factory/swarm_factory_agent.py`), not a built-in.
- **The dashboard, the kanban, the webhook intake** — all rapp store agents, not brainstem routes.
- **Twin calibration** lives in `system_context()` injection (the per-agent hook on `BasicAgent`) plus tags inside the TWIN slot (see [[Voice and Twin Are Forever]]). The brainstem only knows the slot delimiter.

Each of those started as a request to extend the brainstem. Each was redirected into an agent. The brainstem stayed light.

## What the brainstem actually owns

The brainstem's responsibilities are a closed list:

1. **Agent discovery.** Glob `agents/*_agent.py`, instantiate, expose as tools. (`brainstem.py:765`)
2. **Soul + system-context assembly.** Load `soul.md`, append every loaded agent's `system_context()` output. (`brainstem.py:913-927`)
3. **LLM dispatch.** Call the configured provider via `utils/llm.py`. (`brainstem.py:786` `call_copilot()`)
4. **Tool-call execution.** When the LLM emits tool calls, run the corresponding agents and append results to the message stream. Up to 3 rounds in Tier 1. (`brainstem.py:866`, `brainstem.py:957-972`)
5. **Slot splitting.** Partition the final response on `|||VOICE|||` and `|||TWIN|||`. (`brainstem.py:984-998`)
6. **Auth.** GitHub-token cascade and Copilot-token exchange. (`brainstem.py:183-310`, see [[The Auth Cascade]])
7. **The shim layer.** `_register_shims()` (`brainstem.py:648`) — the import hijack that lets agents stay portable. See [[Local Storage Shim via sys.modules]].
8. **A small set of routes** — `/chat`, `/login`, `/models`, `/voice`, `/twin`, `/agents/files`, plus static serving for the web UI.

That's it. Every other capability lives in an agent.

## What this rules out

- ❌ Adding a "convenience" method to `BasicAgent` because two agents would benefit. If two agents would benefit, share via `utils/`. If only two agents need it, it's not a base-class concern.
- ❌ A built-in router/dispatcher/pipeline framework. The LLM routes via tool selection; agents pipe via [[Data Sloshing]]. The framework was deleted (see [[Why t2t and swarm_server Are Gone]]) and is not coming back.
- ❌ Brainstem-level UI features. The web UI is HTML+JS that calls `/chat`. Anything that "feels like a brainstem feature" but is really a UI feature lives in HTML.
- ❌ Provider-specific behavior in the brainstem. The LLM provider abstraction (`utils/llm.py`) is the entire vocabulary; the brainstem talks only OpenAI-shape messages.

## When to reconsider

The only legitimate reasons to grow the brainstem:

1. **A new top-level slot** (Sacred Constraint #3) — the test in [[Voice and Twin Are Forever]].
2. **A new tier** — and only the brainstem code that all tiers must share.
3. **A correctness bug** in agent discovery, tool execution, or slot splitting.

Anything else, the answer is "make it an agent."

## The discipline

- Every PR that touches `brainstem.py` answers the question *"could this be an agent instead?"* in writing.
- The growth rate of `brainstem.py` is a metric. v0.4 was ~1,100 lines; v0.12 is ~1,650. Every increment had a load-bearing reason. No casual additions ever.
- When tempted to add to the brainstem because "the agent layer is too constraining," remember that the constraint is the product. See [[Engine, Not Experience]].

## Related

- [[Engine, Not Experience]]
- [[The Engine Stays Small]]
- [[Voice and Twin Are Forever]]
- [[The Single-File Agent Bet]]
- [[Data Sloshing]]
