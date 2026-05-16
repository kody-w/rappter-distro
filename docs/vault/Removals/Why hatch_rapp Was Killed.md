---
title: Why hatch_rapp Was Killed
status: published
section: Removals
hook: 2138 lines deleted in one cut. The mega-agent that birthed agents was the wrong answer to "how does the platform produce more agents?"
---

# Why hatch_rapp Was Killed

> **Hook.** 2,138 lines deleted in one cut. The mega-agent that birthed agents was the wrong answer to "how does the platform produce more agents?"

## What it was

`rapp_brainstem/agents/experimental/hatch_rapp_agent.py` was, at its peak, a 2,138-line single agent whose job was to *generate other agents*. The user described a goal in natural language; `hatch_rapp` walked them through a multi-step internal flow — discovery, scoping, code generation, validation — and emitted a finished `*_agent.py` file ready to drop into `agents/`.

In the recent fast-forward pull (commit `c1b4a2f`), the file was removed in its entirety. So were the four sibling agents that supported it (the brief-pipeline specialists; see [[The experimental Graveyard]]).

## What was right about it

The vision was correct: *the platform should be able to produce more agents*. That capability is now realized in the rapp store, in `rapp_store/swarm_factory/swarm_factory_agent.py`, in `rapp_store/vibe_builder/vibe_builder_agent.py`. The need was real.

The first attempt also got a lot of things right within the file:

- It used `data_slush` correctly to pipe state across its internal stages.
- It produced agent files that conformed to the single-file rule (see [[The Single-File Agent Bet]]).
- It captured the user's words verbatim into the system prompt of the produced agent — a pattern that survived into the next generation.

## What was wrong

The 2,138-line size was the symptom. The cause was a single architectural mistake: **`hatch_rapp` was multiple agents wearing one filename.**

Inside the file, you could see them: the discovery agent, the scoper, the prompt drafter, the parameter extractor, the file writer, the validator. Each had its own state machine, its own prompt template, its own error handling. The single `perform()` entry point was a dispatcher to internal phases.

Three failure modes followed:

**1 — Reviewability collapsed.** When an agent's `perform()` body becomes unreviewable, the spec property of "the agent IS the spec" is gone. See [[The Agent IS the Spec]]. A partner reading `hatch_rapp_agent.py` could not estimate scope without running it. That alone disqualifies the shape.

**2 — The LLM lost its job.** The platform's bet is that **the LLM picks, deterministic plumbing carries** (see [[Data Sloshing]]). Inside `hatch_rapp`, a state-machine variable picked which phase to run; the LLM was demoted to a single-purpose text generator inside each phase. The platform's central abstraction had been re-implemented inside one file, badly.

**3 — Internal errors had no agent boundary.** When phase 4 of 7 failed, the logs said "hatch_rapp failed" — even though the actual problem was in the parameter extractor. The error message had no native granularity. Splitting into multiple agents would have made every failure say *which* agent.

## The replacement

The capability is now spread across:

- `rapp_store/swarm_factory/swarm_factory_agent.py` — produces multi-agent workspaces.
- `rapp_store/vibe_builder/vibe_builder_agent.py` — generates agent files from a design brief.
- `rapp_store/learn_new/learn_new_agent.py` — adds capability via teach-by-example.

Each is a single-file agent. Each has a focused `perform()` body. Each fails with its own name in the agent log. The previous mega-agent's vision is preserved; its shape is not.

## The lesson

The lesson is older than RAPP: *every monolith is multiple things wearing one name*. What's specific to the platform is the **rule**:

> **When an agent's `perform()` body becomes unreviewable, the question is not "how do we organize it?" — the question is "what are the agents hiding in here?"**

Reviewability is a hard constraint, not a soft one. The single-file constraint is what makes the platform portable, distributable, and reviewable in one breath (see [[The Single-File Agent Bet]]). An agent that breaks reviewability has broken the platform's deal with itself, regardless of whether it works.

## What this rules out

- ❌ Agents whose `perform()` is a state machine with multiple phases. If you need phases, you need multiple agents and a deterministic channel between them ([[Data Sloshing]]).
- ❌ Splitting one agent into helper modules to "manage size." A 2,000-line agent needs to become four 500-line agents in `agents/`, not one 500-line agent plus three helpers.
- ❌ Building an internal LLM dispatcher inside an agent. The brainstem is the dispatcher. An agent that calls the LLM directly to pick its next move is re-implementing the brainstem inside itself.

## When to reconsider

The 300-line ceiling on agent size is not a hard limit — `rapp_brainstem/agents/learn_new_agent.py` (vendored from the rapp store) was over 1,100 lines and still readable because it had a single, narrow contract. The real test is not line count; it is: *can a partner pricing this agent understand its inputs and outputs in under five minutes?*

If the answer is yes, the size is fine. If the answer is no, the agent is `hatch_rapp` again, regardless of what it's named.

## Discipline

- Read the agent's `perform()` aloud before merging. If you can't follow it without holding state in your head, split.
- When tempted to add a "phase" to an existing agent, write the new agent first and pipe through `data_slush`. Inline phases are how mega-agents are born.
- The agent log should always identify *which agent* failed, not just *which entry point*. A long log of "hatch_rapp failed (phase 4)" is the smell.

## Related

- [[The Single-File Agent Bet]]
- [[The Agent IS the Spec]]
- [[The experimental Graveyard]]
- [[Data Sloshing]]
- [[Engine, Not Experience]]
