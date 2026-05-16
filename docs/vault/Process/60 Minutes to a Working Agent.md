---
title: 60 Minutes to a Working Agent
status: published
section: Process
hook: 10 minutes goal-setting · 40 minutes agent emerging in front of the customer · 10 minutes validation. The hour that proves the platform.
---

# 60 Minutes to a Working Agent

> **Hook.** 10 minutes goal-setting · 40 minutes agent emerging in front of the customer · 10 minutes validation. The hour that proves the platform.

## The claim

A RAPP workshop produces a working agent — a real `*_agent.py` file that the customer has touched, validated, and watched run on their own input — in 60 minutes. Not a slide. Not a spec. Not a prototype. A file that runs.

This is the platform's central operational claim. Every other piece of the platform exists to support it.

## The 60 minutes

The pacing is deliberate. The phases are not equal in length because they don't do equal work.

**Minutes 0–10 — The goal.** The customer describes what they want, in their own words. No structured discovery, no requirements doc, no "let me ask you 30 questions." The goal is captured in a single sentence ideally, a short paragraph at most. *"Score every inbound lead by likelihood to close, given our pipeline data."* That kind of thing.

The facilitator's job in this phase is to **stop the customer from over-specifying**. Asking for the spec up front is the discovery-driven mistake the workshop is built to avoid. The agent's `metadata` description, written collaboratively in the next phase, is the spec.

**Minutes 10–50 — The agent emerges.** This is where the platform earns its claim. The facilitator opens `rapp_brainstem/agents/`, creates `<their_thing>_agent.py`, and starts writing. The customer is in the room, watching the file appear.

The phase has a shape:

1. The class skeleton + the metadata description (5 minutes). The metadata description is the *contract*. Read it aloud to the customer; refine it until they agree it captures the goal.
2. The parameter schema (10 minutes). Every parameter is a question the LLM will need answered. "How does the LLM know which lead to score?" → that's a parameter. Walk through them with the customer.
3. The `perform()` body (20 minutes). Here is where the file moves from skeleton to working. Pull data via the storage shim, compute, format the response, optionally `data_slush` for downstream agents. The customer is reading along; their corrections are the signal.
4. First runs (5 minutes). Restart? — no, the brainstem reloads agents from disk on every request. The customer types into the chat. The agent runs. They see real output, on their data, in their browser.

This phase succeeds when **the customer has corrected the agent at least once**. Not when the agent is perfect; when the customer has been *in the loop*. The corrections are how the agent file becomes theirs.

**Minutes 50–60 — Validation.** The customer brings input they prepared before the workshop — a real lead, a real document, a real customer record. The agent runs against it. The customer reads the output. They say *"yes, this is what I want"* or *"no, here's what's still off."* If it's the latter, ten minutes is enough to refine and re-run.

The artifact at minute 60 is `rapp_brainstem/agents/<their_thing>_agent.py`. That file leaves with the customer. It is what they bought.

## Why an hour is enough

Three things make the hour possible:

- **No build step.** The brainstem reloads agents from disk per request (`brainstem.py:765` `load_agents()`). Save the file, run a chat, see the new behavior. There is no compile, no restart, no deploy. The iteration loop is *seconds*. Most of the 40-minute middle phase is conversation between iterations.
- **The single-file constraint.** The whole agent fits in one file the facilitator and the customer can both see at once. Multi-file agents would force the facilitator to switch contexts; the customer would lose track of where the work is happening. See [[The Single-File Agent Bet]].
- **Tier portability.** The file the workshop produces is the same file that ships in Tier 2 and Tier 3. There is no "we'll productionize this later" caveat that secretly means "we'll rewrite this later." The customer's confidence in the artifact comes from knowing it's the *real thing*, not a prototype. See [[Three Tiers, One Model]].

## What does not happen

The pacing depends on what the workshop *doesn't* do:

- **No discovery deck.** The customer's words become the agent's metadata description. Discovery happened in the conversation; the file is its receipt.
- **No requirements document.** The agent IS the spec ([[The Agent IS the Spec]]). If a stakeholder needs to read the requirements, they read the file.
- **No estimate.** The agent's parameters and `perform()` body make scope obvious to a partner pricing the work. See [[Self-Documenting Handoff]].
- **No "we'll send a proposal next week."** The artifact exists at minute 60. The proposal, if needed, is written *with the file open*.

The absence of these steps is what creates the time budget. They aren't omitted because they're hard; they're omitted because the agent file does their job better.

## What a successful workshop looks like

The signals that say it worked:

- The customer touched the file. They edited the system prompt, or fixed a parameter description, or pointed out a wrong assumption in `perform()`.
- The customer ran the agent against their own input. Not the facilitator's demo input; theirs.
- The customer can read the metadata description aloud and agree it describes their goal.
- A copy of the file is on the customer's machine, at the end of the hour.

The signals that say it didn't work:

- The customer was a passive observer. ("That looks great, send us the slides.")
- The agent only ran on synthetic data.
- The customer left without a copy of the artifact.
- The conversation drifted into "we should also do X next time" — that means the *current* agent didn't earn the room's attention.

## What the facilitator needs

The facilitator's prep is small but specific:

- A clean Tier 1 instance (start `rapp_brainstem` fresh; auth pre-completed).
- An empty `agents/` modulo the platform's defaults — no clutter.
- A blank text editor pointed at `rapp_brainstem/agents/`.
- Knowing the platform's contract well enough to write `metadata` and `perform()` without lookup.
- The discipline to *not* over-engineer. The workshop's failure mode is the facilitator showing off rather than producing.

## What this rules out

- ❌ "Let's spend the first hour on discovery." Discovery happens in the agent file's metadata.
- ❌ "We'll show you a demo, then build yours next week." The customer's *own* agent is what proves the platform.
- ❌ "We'll wireframe a UI." The chat is the UI. The artifact is the deliverable.
- ❌ Workshops that stretch to two hours because the facilitator wanted to "polish." Sixty minutes is the constraint that forces the agent to be small enough to be real.

## When the workshop fails

It fails when any of these is true:

- The goal didn't compress into a sentence (the customer's problem is too broad — split it).
- The customer didn't have real input to bring (the platform can't substitute for their data).
- Auth wasn't pre-completed (10 minutes lost = the workshop is a 50-minute workshop, which doesn't fit the shape).
- The facilitator added too many agents (more than one new agent in 60 minutes is a flag — see [[Why hatch_rapp Was Killed]] and [[The experimental Graveyard]]).

## Discipline

- Sixty minutes, not ninety. The constraint is the feature.
- One agent per workshop, not three.
- The customer holds the keyboard at least once. If they don't, the file isn't theirs.
- The validation step is non-negotiable. A workshop without minute 50–60 is a demo, not a workshop.

## Related

- [[The Agent IS the Spec]]
- [[Self-Documenting Handoff]]
- [[The Single-File Agent Bet]]
- [[Three Tiers, One Model]]
