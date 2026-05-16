---
title: Data Sloshing
status: published
section: Founding Decisions
hook: Agents return JSON. The next agent reads it directly. The LLM is not load-bearing for state — it's load-bearing for choice.
---

# Data Sloshing

> **Hook.** Agents return JSON. The next agent reads it directly. The LLM is not load-bearing for state — it's load-bearing for choice.

## The mechanism

A RAPP agent's `perform()` method returns a string. By convention, that string is JSON, and that JSON may include a `data_slush` key whose value is an arbitrary object:

```python
def perform(self, **kwargs):
    return json.dumps({
        "summary": "Found 14 candidate leads",
        "data_slush": {
            "leads": [...],
            "filter_used": "industry=fintech",
            "next_step_hint": "score_lead_agent",
        }
    })
```

When the LLM decides to call a *next* agent on the same turn, the brainstem makes that `data_slush` available to the next agent on `self.context.slush`. The downstream agent reads it deterministically — no LLM interpretation between the two — and writes its own `data_slush` for whatever might follow.

The state pipes through agents on a deterministic channel. The LLM's job is to pick *which* agent to call next, not to summarize and re-emit what the previous one produced.

## Why this matters

The default pattern in multi-agent frameworks is the opposite: each agent's output becomes a chat message, the LLM reads it, the LLM summarizes it back into the next agent's input. Three failure modes follow.

**1 — Information loss.** A 14-row data table goes in; the LLM's summary of "14 leads in fintech" comes out. The next agent has lost the rows. To recover, the framework adds tool-call results, scratchpads, or a retrieval layer. RAPP solves it by never letting the LLM be the channel.

**2 — Token cost.** Every hop through the LLM costs tokens proportional to the data being passed. Long pipelines become expensive precisely because the data has to be re-read each time. Data sloshing pipes the data on the side, at zero token cost.

**3 — Determinism.** When the LLM is the channel, the same input can produce different downstream behavior on different runs. When the channel is JSON, the same input produces the same downstream input. Tests work. Replays work. Debugging is possible.

## What the LLM is for

The platform is explicit about the LLM's role: **the LLM picks; deterministic plumbing carries.** That division comes through in three places:

- **Tool dispatch.** The LLM decides which agent to call next from the available set, based on the prompt + the previous agent's *summary*. (`rapp_brainstem/brainstem.py:866` `run_tool_calls()`).
- **Voice and twin shaping.** The LLM produces the human-facing language — see [[Voice and Twin Are Forever]]. Format is the LLM's job; data is not.
- **Calibration.** The LLM tags probes, judges them on later turns, and emits actions inside the TWIN slot. See [[The Twin Offers, The User Accepts]].

Everything else — what data made it from agent A to agent B, what state persists across turns, what tier the agent is running on — is deterministic.

## How agents read the slush

The base class (`agents/basic_agent.py`) holds the contract: agents have access to `self.context` (the conversation state for the current turn) which includes `self.context.slush`. In practice, agents inspect `kwargs` for parameters supplied by the LLM *and* `self.context.slush` for state piped from the previous agent — both are inputs.

This makes agent composition easy: agent A produces `{"data_slush": {"X": ...}}`, the LLM is told "if X exists, call agent B," agent B reads `self.context.slush["X"]`. No middleware, no router, no graph.

## What this rules out

- ❌ Routing data through the LLM. If a previous agent already produced the bytes you need, the next agent reads them directly. The LLM never re-emits data it already produced.
- ❌ Persistent global state for inter-agent communication. The slush exists for the current turn's pipeline, not as a sneaky session cache. Persistence goes through the storage shim ([[Local Storage Shim via sys.modules]]).
- ❌ Defining a graph of agent transitions in code. The graph is implicit in (a) which agents exist and (b) the LLM's tool-call choices. There is no `pipeline.add_edge(A, B)` anywhere because that would be experience, not engine. See [[Engine, Not Experience]].
- ❌ Slush-as-config. The slush is *data being processed*, not configuration for downstream agents. Configuration goes in `.env` or in agent metadata.

## What this enables

- **Replay.** Capture all agent inputs and outputs (including `data_slush`) for a turn. Replay deterministically without an LLM call.
- **Provider swap.** The fake LLM (`utils/llm.py:191` `chat_fake()`) can drive a pipeline end-to-end because it just picks the first available tool, and the tools talk to each other through deterministic JSON. See [[The Deterministic Fake LLM]].
- **Tier portability.** The slush mechanism is identical across Tier 1, 2, 3. Deterministic plumbing has no environment dependence; it's just a Python attribute.

## When to reconsider

The slush mechanism survives every contested call. The risk is **abuse** — an agent stuffing its return into the slush so densely that it becomes a hidden API surface between two specific agents. The discipline:

- The slush is *data*, not a custom protocol between specific agent pairs. If two agents need a private protocol, they probably want to be *one* agent.
- Schemas at the agent boundary are a smell. If you're tempted to write a schema for `data_slush` between A and B, that's the moment to ask whether A and B should split or merge.

## Discipline

- Return data; don't paraphrase it for the next agent.
- Treat `data_slush` as a deliberate channel, not a side effect — name your keys for what's in them, document them in the agent's metadata description.
- When tempted to add a "router agent" or "orchestrator agent," remember that the LLM is the router, and the deterministic channel is the orchestrator.
- When debugging a multi-agent pipeline, dump the slush at every step — that's the audit trail.

## Related

- [[The Single-File Agent Bet]]
- [[The Deterministic Fake LLM]]
- [[The Brainstem Tax]]
- [[Engine, Not Experience]]
