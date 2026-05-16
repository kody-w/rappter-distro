---
title: What You Give Up With RAPP
status: published
section: Positioning
hook: The anti-pitch. Portability tax, no framework conveniences, single-file constraints. The honest tradeoffs.
---

# What You Give Up With RAPP

> **Hook.** The anti-pitch. Portability tax, no framework conveniences, single-file constraints. The honest tradeoffs.

## Why this exists

Every other piece of platform marketing tells the upside. This note tells the downside, in the same voice. The point is not modesty; it is *protection*. A platform whose tradeoffs aren't documented gets sold by enthusiasm and resented after onboarding. The anti-pitch is the discipline that prevents that.

If you're reading this trying to decide whether to use RAPP, this is the page that should make the decision honest.

## What you give up vs. a framework (LangChain, LangGraph, AutoGen, CrewAI)

A general-purpose multi-agent framework gives you conveniences RAPP deliberately does not:

- **A graph editor / DAG abstraction.** RAPP has no graph. Pipelines are emergent — the LLM picks tool calls; data pipes through `data_slush` (see [[Data Sloshing]]). If you want to say "agent A always feeds agent B," you express it through metadata descriptions and slush keys, not through a graph node. For some workloads, this is a worse fit. The platform won't pretend otherwise.
- **An agent class hierarchy.** `BasicAgent` is 51 lines. There is no `ChatAgent`, no `ToolUsingAgent`, no `RetrievalAgent`. If you want those abstractions, you write them — but they will not be portable across tiers, because the tier portability guarantee depends on the agent's source code being identical everywhere. See [[The Single-File Agent Bet]].
- **Built-in retries, circuit breakers, observability.** The brainstem does the bare minimum: tool-call loops up to 3 rounds in Tier 1 (`brainstem.py:957`), basic structured logging via `_tlog()`, and that's it. Production-grade resilience is the agent author's job (or the tier's hosting, e.g., Azure Functions retries). For teams that want a framework to cover this, RAPP is the wrong tool.
- **A vector database integration / RAG abstraction.** RAPP doesn't ship one. Memory is a JSON file (`rapp_brainstem/.brainstem_data/`); retrieval is whatever an agent's `system_context()` chooses to inject. If your application is fundamentally a RAG application with a vector database, the platform can host it but won't help you build it.

The general principle: **frameworks ship abstractions; RAPP ships a contract.** Abstractions are sometimes worth the lock-in. RAPP's bet is that for the workloads it targets, they aren't.

## What you give up vs. Copilot Studio

Covered in [[RAPP vs Copilot Studio]]. The short version: RAPP doesn't try to be a tenant-native distribution channel, doesn't ship governance/audit, and doesn't replace the Microsoft connector ecosystem. If you're building inside a tenant for users who already trust that tenant, Tier 3's job is to *land you there*, not to *be there.*

## What you give up vs. shipping a custom server

Some teams will be tempted to "just write a server." For them, RAPP gives up:

- **Total architectural freedom.** Your agents look the way RAPP says they look. One file, one class, one `perform()`. The metadata dict is an OpenAI function-calling schema, even if you'd prefer a different schema. If your team has strong opinions about agent architecture that don't match this, those opinions cost more than the platform saves.
- **Custom routing.** The brainstem has one chat route and a small set of administrative routes. If you want a `/research` endpoint or a `/validate` endpoint, the answer is *make a service in `rapp_store/` that respects the rapp store's contract* (Constitution Sacred Constraint #2), not *add a route to brainstem.py*. See [[The Brainstem Tax]].
- **Provider freedom inside an agent.** Agents don't call LLMs directly; they're called *by* the LLM via tool dispatch. If you want an agent that internally calls a different LLM with a different prompt strategy, you can do it (the agent's `perform()` can do anything Python can do), but you're outside the platform's central abstraction and the data sloshing model.

## What you give up vs. doing nothing

Even compared to the do-nothing alternative, RAPP costs:

- **The portability tax.** Every line of agent code obeys the constraints — single file, no sibling imports, JSON return shape, OpenAI tool schema, no provider-specific assumptions. This is duplication-over-abstraction by design (see [[Vendoring, Not Symlinking]]); the price is real and you pay it on every agent you write.
- **The cognitive cost of three tiers.** Even if you only ship Tier 1, the platform's design pressures you to consider whether your code would survive Tiers 2 and 3. That pressure is sometimes useful, sometimes annoying. It is always present.
- **The opinion budget.** RAPP has strong opinions on a small number of things — the constitution lists 24 of them. You inherit those opinions. If your team's instincts disagree with one of them, the platform won't bend.

## When RAPP is the wrong tool

This is the page that says it. RAPP is wrong for you if any of these is true:

- You need a graph-shaped workflow editor and your team's mental model is graph-first. Use a framework that thinks in graphs.
- You're building a single-tier, single-tenant SaaS and tier portability is dead weight. Use whatever your stack already loves.
- Your agents are fundamentally retrieval-shaped and you have a strong vector-database story. RAPP can host them but won't help; build on a RAG-first stack.
- You need fine-grained per-call observability (token-level traces, cost dashboards, A/B routing). Build on an observability-first agent platform; come back when you have working agents and need to ship them.
- You don't have a Microsoft customer surface and the Tier 3 packaging is wasted. Stay at Tier 1 *or* pick a different platform — don't pay the multi-tier tax for a single tier.

## When RAPP is the right tool

For symmetry: RAPP is right when *all* of these are true:

- The deliverable is one or more working agents that need to land in a customer's hands.
- The customer is in a Microsoft-flavored environment (or could be).
- The dev loop matters — being able to edit an agent in front of the customer is a feature, not a side note.
- The number of agents in scope is small (single digits to low double digits), each with a focused contract.
- You value reviewability of agent files by non-technical stakeholders.

If those describe your project, the tradeoffs above are payments worth making. If they don't, the tradeoffs above are payments you shouldn't be making.

## Discipline

- The marketing pages tell the upside. This page tells the downside. Both must be true at the same time.
- When a customer asks "what's the catch?", point them here, not at a sales rebuttal.
- When tempted to soften the constraints to widen the appeal — *"we could relax the single-file rule, just for this customer"* — reread the relevant constraint's vault note. The constraints are why the platform's claims are true.

## Related

- [[The Single-File Agent Bet]]
- [[Three Tiers, One Model]]
- [[Why Three Tiers, Not One]]
- [[The Brainstem Tax]]
- [[RAPP vs Copilot Studio]]
- [[Engine, Not Experience]]
