---
title: The experimental Graveyard
status: published
section: Removals
hook: Six specialist agents, all deleted in one cut. Specialists with overlapping triggers don't survive contact with the model.
---

# The experimental Graveyard

> **Hook.** Six specialist agents, all deleted in one cut. Specialists with overlapping triggers don't survive contact with the model.

## What was removed

The `rapp_brainstem/agents/experimental/` directory existed precisely so the brainstem's auto-loader (`load_agents()` at `brainstem.py:765`) would not pick up agents that hadn't proven themselves. Six agents lived there at the end of their life. All were deleted in the same fast-forward pull (`c1b4a2f`):

| File | Lines | Role |
|------|-------|------|
| `brief_scout_agent.py` | 154 | Stage 1 of the brief pipeline — gather raw inputs |
| `brief_strategist_agent.py` | 164 | Stage 2 — frame the strategy |
| `brief_analyst_agent.py` | 157 | Stage 3 — analyze the framed strategy |
| `brief_writer_agent.py` | 196 | Stage 4 — produce the final brief |
| `copilot_research_agent.py` | 74 | Standalone — surface GitHub Copilot research |
| `exec_brief_agent.py` | 130 | Precursor to the live index card pattern |
| **Total** | **875** | |

`hatch_rapp_agent.py` (2,138 lines) was also in `experimental/`; its story is in [[Why hatch_rapp Was Killed]].

## The brief pipeline experiment

The four `brief_*` agents were a test of an idea that sounded clean: **decompose a complex output (a written brief) into a chain of specialists**, each responsible for one stage. The LLM would call them in order; `data_slush` would carry the intermediate state.

The structure was textbook:

1. `brief_scout` — given a goal, gather raw context and stash it in `data_slush.context`.
2. `brief_strategist` — read `data_slush.context`, frame a strategy, stash it in `data_slush.strategy`.
3. `brief_analyst` — read both, analyze, stash conclusions.
4. `brief_writer` — read all three, write the final document.

In testing, every individual agent worked. End-to-end, the pipeline failed in two distinct ways.

## Failure mode 1 — overlapping triggers

The four agents' metadata descriptions were tuned to make the LLM call them in order. In practice, the descriptions overlapped enough that the LLM regularly called them out of order or skipped stages.

- The scout's description said *"gather inputs for a brief."*
- The strategist's said *"frame the strategy for a brief."*
- The analyst's said *"analyze options for a brief."*
- The writer's said *"produce the final brief."*

A user who said "write me a brief on X" should, in theory, have triggered all four in sequence. In practice, the LLM frequently went straight to the writer (because the writer's description matched "write a brief" most directly), or skipped the analyst (because "frame" and "analyze" are linguistically close).

This is the same failure mode as [[From save_recall to manage_memory]], at four-agent scale instead of two. The lesson generalizes: **overlapping triggers are the LLM's confusion surface, regardless of how many siblings overlap.**

## Failure mode 2 — pipeline brittleness

When the LLM *did* call the agents in the right order, the result was technically correct but stylistically inconsistent. The scout's tone bled into the strategist; the strategist's framing constrained the analyst; the analyst's wording locked the writer's voice. Each handoff lost subtlety.

The deeper issue: a brief is not a four-stage pipeline. It is a single *act* that benefits from internal structure. A specialist chain forced an artificial seam at every stage boundary, and the seams were visible in the output.

## The replacement

A single `brief_writer` agent — well, conceptually; this hasn't been re-implemented yet — would have done as well or better. The brief-pipeline experiment was deleted because the pipeline shape itself was wrong, not because the implementation was wrong.

The capability is now considered an unsolved problem rather than a solved one with the wrong implementation. That is the right state for it to be in.

## What `copilot_research_agent` and `exec_brief_agent` taught

The two non-pipeline experimental agents had different lessons.

- **`copilot_research_agent`** wanted to surface GitHub Copilot research results inside the chat. It worked, but it depended on a specific Copilot endpoint shape that the platform doesn't control. Provider-specific behavior in agent code is exactly what the LLM dispatch layer (`utils/llm.py`) is meant to abstract away. The agent was deleted because it broke the abstraction.
- **`exec_brief_agent`** was the first attempt at the "live index card" pattern — an agent that emits an artifact at every step of its work. It pioneered the artifact-from-chat-autolinker idea (see commit `6f02ab8`) but had too much state machine inside its `perform()` (failure mode 1 of [[Why hatch_rapp Was Killed]]). The pattern survived; this implementation did not.

## The principle

> **Specialists with overlapping triggers don't survive contact with the model. Either consolidate (one agent, parameters) or differentiate (orthogonal triggers).**

This is the consolidation principle of [[From save_recall to manage_memory]] applied to chains rather than pairs.

## What this rules out

- ❌ Multi-agent pipelines whose stages are described in similar verbs ("gather," "frame," "analyze," "write"). The LLM cannot distinguish them reliably.
- ❌ Specialist agents that depend on a specific provider's surface area. Provider-specific behavior lives in `utils/llm.py`, not in agent code.
- ❌ Internal state machines inside a single agent's `perform()` — see [[Why hatch_rapp Was Killed]].
- ❌ "Experimental" as a permanent home. Either the agent earns its way out of `experimental/`, or it gets deleted. The graveyard is not a museum.

## When to keep `experimental/`

The directory itself is still useful — for staging an in-development agent that isn't ready for the auto-loader's scrutiny. The discipline:

- Each experimental agent has an exit criterion stated up front.
- Experimental agents that miss their exit criterion get deleted in the next sweep.
- The graveyard exists so the auto-loader stays clean. It does not exist to hold work that *might* someday matter.

## Discipline

- Before adding stage N+1 to a multi-agent pipeline, run end-to-end with a real prompt and watch the LLM's tool-call sequence. If the order isn't right reliably, the stages overlap.
- Provider-specific code is a smell wherever it appears outside `utils/llm.py`.
- Experimental agents are dated. If a year passes and the agent is still in `experimental/`, it is dead — bury it.

## Related

- [[Why hatch_rapp Was Killed]]
- [[From save_recall to manage_memory]]
- [[Data Sloshing]]
- [[The Single-File Agent Bet]]
- [[The Deterministic Fake LLM]]
