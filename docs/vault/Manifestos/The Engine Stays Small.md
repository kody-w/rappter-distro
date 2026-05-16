---
title: The Engine Stays Small
status: published
section: Manifestos
hook: There is a fixed budget of complexity in any platform. RAPP spends it on agents, not on the engine.
---

# The Engine Stays Small

> **Hook.** There is a fixed budget of complexity in any platform. RAPP spends it on agents, not on the engine.

## The line

The Constitution closes with a line:

> *"The engine stays small so the agents can be everything."*

It reads as a flourish. It is actually the conservation law the entire platform is built on.

## The conservation law

Every platform that lets users build things has a fixed budget of complexity to spend. The budget is divided into two ledgers:

- **What the platform does for the user.** The engine. Code that runs once, ships once, is read by every contributor.
- **What the user does on the platform.** The agents. Code the user writes, owns, and reads.

The total budget is the user's attention. The platform decides how to split it.

A maximalist platform spends the budget on the engine — frameworks, abstractions, conventions, "best practices," opinionated workflows. The user inherits all of it. They can build very little, very fast, in the shape the platform decided.

A minimalist platform spends the budget on the user. The engine does the smallest possible thing; the user has the largest possible space to fill. They can build anything, with more effort.

Both choices are legitimate. Most platforms drift toward the maximalist end because each "small" feature added to the engine feels harmless in the moment, and "the engine is small" is hard to defend in feature-by-feature reviews.

RAPP makes the opposite drift its first principle.

## How the platform spends its budget

The engine is intentionally small. As of v0.12, `brainstem.py` is ~1,650 lines (a Flask server with chat, auth, agent loading, voice/twin slot splitting, and a small set of admin routes). `BasicAgent` is 51 lines. `utils/llm.py` is 247 lines. `utils/local_storage.py` is 111 lines.

That's the engine. Roughly 2,500 lines of shared code that every agent runs on top of.

The agents are everything else. The platform's value isn't in those 2,500 lines; it's in the agents users will write *because* the engine stays small enough not to crowd them.

The discipline that keeps this true:

- **Constitution Article I — The Brainstem Stays Light.** Adding to `brainstem.py` requires a justification stronger than convenience.
- **Constitution Sacred Constraint #1 — Single-file agents.** Agents have no framework conveniences to inherit. See [[The Single-File Agent Bet]].
- **Constitution Sacred Constraint #4 — Tier portability.** Every engine feature must work in all three tiers, which kills features that would have been engine bloat. See [[Three Tiers, One Model]].
- **The forcing question.** When a request would add to the engine, the first question is: *could this be an agent instead?* See [[The Brainstem Tax]].

## Why this works

The minimalist bet works because of three asymmetries.

**1 — Agents are cheaper to remove than engine.** A bad agent is a file the user deletes. A bad engine feature is a property all agents now depend on, removable only via deprecation. Optimizing for low removal cost means biasing toward agents.

**2 — Agents compose; engine doesn't.** Two agents can be combined via `data_slush` and the LLM's tool dispatch (see [[Data Sloshing]]). Two engine features can't be combined; they sit side by side, each demanding attention. Composition multiplies; sitting-side-by-side adds.

**3 — Agents are the user's surface; the engine is the platform's.** The user's attention scales with what they care about. They care about agents — the agent file is what they hand to a partner, what their customer reads, what they iterate on. They don't care about the brainstem. Spending budget on the engine is spending budget on a thing the user doesn't see.

## What "everything" means

The line says agents *can* be everything — not that they will. The user decides what their agents do. The platform's job is to make sure the agents *can* do what the user needs.

In practice, "everything" has covered:

- Memory (write and retrieve)
- Workspace inboxes
- Lead scoring, research summarization, brief writing, content drafts
- Multi-step pipelines via `data_slush`
- Live artifact production (the index card pattern)
- Power Platform solution generation
- Swarm composition (a swarm is a directory of agents)

Each of those is an *agent* or a *composition of agents*. None of them is an engine feature. The platform's job has been to keep the engine out of their way.

## What "small" means

Small is not a fixed line count. The engine has grown — v0.4 was ~1,100 lines; v0.12 is ~1,650. Growth happens. The discipline is that *every increment is justified*:

- New top-level slots: the bar in [[Voice and Twin Are Forever]].
- New auth paths: each new path serves a distinct persona — see [[The Auth Cascade]].
- New shim modules: each shim earns its keep by enabling agent portability — see [[Local Storage Shim via sys.modules]].

What's *not* in the engine — even though it could be:

- No router.
- No state machine framework.
- No vector DB.
- No template gallery.
- No workflow editor.
- No graph DAG.
- No marketplace UI.
- No analytics dashboard.

Each of those would have made the platform feel "more complete" in some abstract sense. Each was rejected because completeness in the engine is incompleteness in the user's space. See [[Engine, Not Experience]].

## What this rules out

- ❌ Engine growth based on "users would benefit" without an alternative-as-agent analysis. Most "users would benefit" features can be agents.
- ❌ Frameworks-inside-the-engine. The platform is the framework's deliberate refusal.
- ❌ Engine features that exist to "showcase" the platform. Showcasing is the agents' job; the engine doesn't have to look impressive.
- ❌ Branding in the engine. The brainstem doesn't display the RAPP logo, doesn't introduce itself, doesn't try to be a product. It is, by design, *infrastructure*.

## When the line moves

The engine grows when:

1. A new top-level slot is required (the high bar in Article II).
2. A new tier is added that all tiers must share code with.
3. A correctness bug in agent loading, tool dispatch, or slot splitting.
4. Auth paths or provider abstractions that no other layer can carry.

It doesn't grow for:

- Convenience.
- Better defaults that could be agent metadata.
- Features that "feel like they belong in the platform" without surviving the *could-this-be-an-agent* question.

## The closing argument

The platform's deepest claim is not that agents run unmodified across three tiers, or that workshops produce working agents in 60 minutes, or that partners can price work from a file. Those are consequences.

The deepest claim is the conservation law: **complexity spent on the engine is complexity not spent on the agents; complexity spent on the agents is complexity the user controls.** RAPP picks the side where the user wins.

Every other principle in the constitution — every article, every sacred constraint, every removed file documented in this vault — is downstream of this one.

> The engine stays small so the agents can be everything.

## Discipline

- When in doubt about any decision, ask which side of the line it falls on.
- The engine is allowed to grow when growth is forced, not when growth is convenient.
- "The platform should do X" is half a sentence. The other half is *"because no agent could."* If that other half is hard to fill in, the answer is an agent.

## Related

- [[Engine, Not Experience]]
- [[The Brainstem Tax]]
- [[The Single-File Agent Bet]]
- [[Voice and Twin Are Forever]]
- [[Three Tiers, One Model]]
