---
title: From save_recall to manage_memory
status: published
section: Removals
hook: Three memory agents collapsed into one. When the model keeps picking the wrong sibling, the siblings were one agent all along.
---

# From save_recall to manage_memory

> **Hook.** Three memory agents collapsed into one. When the model keeps picking the wrong sibling, the siblings were one agent all along.

## The previous shape

Before the consolidation, the brainstem shipped three memory agents:

- `save_memory_agent.py` (142 lines) — accept a piece of content, persist it.
- `recall_memory_agent.py` (136 lines) — search persisted memory and return matches.
- The original `context_memory_agent.py` — inject relevant memory into the system prompt every turn.

In the recent fast-forward pull, `save_memory_agent.py` and `recall_memory_agent.py` were deleted. `context_memory_agent.py` was rewritten (now 154 lines, focused on injection only). A new `manage_memory_agent.py` (79 lines) replaced both deleted agents — it accepts a memory event and persists it in the same shape, with a clearer metadata description that tells the LLM exactly when to call it.

The line count went *down* (142 + 136 → 79) while functionality stayed equivalent.

## Why the original shape failed

The save/recall split looked clean: one verb in, one verb out, two well-named agents. The LLM disagreed.

In practice the model's failure modes formed a pattern:

- **Save when it should have called context.** The user said "I'm a vegetarian." The right behavior is to surface that fact when food comes up later — `context_memory`'s job. The model often called `save_memory` instead, treating it as a write operation, when no write was actually needed.
- **Recall when save was needed.** The user said "remember that my project ID is X." The model called `recall_memory` first ("does this exist?") and then proceeded as if it did, never persisting anything.
- **Both, in the wrong order.** The model would `recall` a related fact, see nothing, and *then* `save` — but the saved record had a slightly different shape than the original, polluting future recalls.

Each individual mistake was small. The shape of the mistake — *which sibling agent does this turn need?* — kept recurring. That recurrence is the data point.

## The principle that emerged

> **When a model has to choose between sibling agents and gets it wrong reliably, that's a smell that the siblings were one agent all along.**

The principle has two corollaries:

1. **Sibling agents must have orthogonal triggering conditions.** If both `save` and `recall` are reasonable responses to "remember that X," the siblings overlap. Overlap is the LLM's confusion surface.
2. **Operation-named agents (CRUD-shaped) usually fail this test.** `create_X`, `read_X`, `update_X`, `delete_X` all can be triggered by similar phrasing. Combining them into one agent — `manage_X` — and letting the agent's parameters distinguish operations is almost always cleaner.

## The new shape

`agents/manage_memory_agent.py` exposes one tool with a single `perform()` body:

- The metadata description is operative: *"You MUST call this tool whenever the user asks you to remember something, shares personal facts (name, preferences, birthdays, etc.), or tells you something they expect you to recall later. Do not just acknowledge — call this tool or the information will be lost."*
- The parameters carry the operation shape: `memory_type ∈ {fact, preference, insight, task}`, `content`, `importance ∈ [1,5]`, optional `tags`, optional `user_guid`.
- Storage uses the shim — `from utils.azure_file_storage import AzureFileStorageManager` — so the tier portability story is preserved (see [[Local Storage Shim via sys.modules]]).

`agents/context_memory_agent.py` covers retrieval, but it does so by injecting relevant memory into the system prompt every turn via `system_context()` — not by exposing a "recall" tool. There is no recall tool because the agent that asked for "recall" turned out to be wrong about what the model needed.

## What this rules out

- ❌ Splitting an agent into operation-named siblings (`save_X`, `read_X`) when the operations are normally implied by the same user phrasing. Combine them, parameterize the operation.
- ❌ Adding a sibling agent because "the LLM keeps mis-routing" — that's evidence the agents shouldn't have been siblings.
- ❌ Letting a metadata description say *"this tool saves and retrieves..."* — that hedge is a tell that the agent is two agents pretending.

## When to split (the inverse)

There is a real version of this lesson going the other way: **when one agent's `perform()` becomes a state machine with mutually exclusive branches that the user's parameters select between, that's the moment to split.** The signal is the opposite of the consolidation signal — *humans choose between branches via parameters*, *not the LLM via metadata*.

The asymmetry: the LLM is good at choosing between agents *if their triggering conditions are clean*. It is bad at choosing between agents whose triggering conditions overlap. So:

- Overlapping triggers ⇒ consolidate.
- Mutually exclusive operations selected by hard inputs ⇒ split.

## Discipline

- Before adding a sibling agent, write the metadata descriptions side-by-side. Read them aloud. If a user request could plausibly trigger either, the agents are one agent.
- When in doubt, ship one agent first; split only when the operations have grown distinct triggers.
- Operation-named agents are always under suspicion. `manage_X` beats `save_X`/`recall_X`/`update_X` by default.

## Related

- [[The Single-File Agent Bet]]
- [[Why hatch_rapp Was Killed]]
- [[Local Storage Shim via sys.modules]]
- [[Data Sloshing]]
