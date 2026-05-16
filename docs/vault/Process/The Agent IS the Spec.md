---
title: The Agent IS the Spec
status: published
section: Process
hook: One file. Four readers. No translation. PM reads metadata; dev reads perform(); partner reads inputs/outputs; customer reads the system prompt.
---

# The Agent IS the Spec

> **Hook.** One file. Four readers. No translation. PM reads metadata; dev reads `perform()`; partner reads inputs/outputs; customer reads the system prompt.

## The claim

In a traditional delivery, an agent (or feature, or product) requires three artifacts:

1. A **PRD** — what the thing does, who it's for, why it matters.
2. A **dev spec** — how it's built, what it depends on, how it integrates.
3. A **partner SOW** — scope, inputs, outputs, integration surface, price.

In RAPP, all three collapse into one file: the `*_agent.py`. Each audience reads a different portion, but they're reading the same artifact at the same moment.

This is not a marketing claim. It is a property the single-file constraint produces, by design.

## The four readings

A RAPP agent file has four distinct surfaces, each addressed to a different audience. The same agent — say, `rapp_brainstem/agents/manage_memory_agent.py` — serves all four without modification.

**1 — The PM reads the `metadata` dict.** The metadata's `name` and `description` fields are the *product description*. Specifically, the description is operative: it tells the LLM (and any human reader) when the agent should be invoked. From `manage_memory_agent.py`:

```python
"description": "Saves information to persistent memory for future conversations.
You MUST call this tool whenever the user asks you to remember something,
shares personal facts (name, preferences, birthdays, etc.), or tells you
something they expect you to recall later. Do not just acknowledge — call
this tool or the information will be lost.",
```

A PM reading this knows: what the agent is for, when it kicks in, what user behavior it serves. That's the PRD's "what" and "why" in one paragraph.

**2 — The developer reads the `perform()` body.** The body is the implementation. From the same file:

```python
def perform(self, **kwargs):
    memory_type = kwargs.get('memory_type', 'fact')
    content = kwargs.get('content', '')
    importance = kwargs.get('importance', 3)
    tags = kwargs.get('tags', [])
    user_guid = kwargs.get('user_guid')

    if not content:
        return "Error: No content provided for memory storage."

    self.storage_manager.set_memory_context(user_guid)
    return self.store_memory(memory_type, content, importance, tags)
```

A developer reading this knows: what storage layer is used, what error cases are handled, what the return shape is, how the agent's parameters map to behavior. That's the dev spec.

**3 — The partner pricing the work reads the `parameters` schema.** The schema declares the agent's inputs explicitly:

```python
"parameters": {
    "type": "object",
    "properties": {
        "memory_type": {"type": "string", "enum": ["fact", "preference", "insight", "task"]},
        "content": {"type": "string"},
        "importance": {"type": "integer", "minimum": 1, "maximum": 5},
        "tags": {"type": "array", "items": {"type": "string"}},
        "user_guid": {"type": "string"},
    },
    "required": ["memory_type", "content"]
}
```

A partner reading this knows: what data the agent needs, what's required vs. optional, what enumeration constraints exist. Combined with the description and the `perform()` body, they can estimate scope without a discovery call. See [[Self-Documenting Handoff]].

**4 — The customer reads the system prompt and metadata description.** This is the part the customer should be willing to *read aloud and agree with*. The metadata description is the contract; the system prompt (`rapp_brainstem/soul.md`, plus any `system_context()` injected by the agent) is the assistant's tone and posture. The customer doesn't read code; they read the *intent*, expressed in plain English in the metadata.

In a workshop ([[60 Minutes to a Working Agent]]), the facilitator literally reads the description aloud. The customer either nods or corrects. That moment is when the agent file becomes the customer's spec, not just the developer's.

## Why this matters

Traditional delivery loses information at every translation step:

- The PRD is written by people who don't write code; the dev spec is written by people who don't talk to customers; the SOW is written by people who don't see the implementation. Every translation introduces drift.
- Three audiences each have their own artifact, kept in sync by humans. They drift; humans don't update all three simultaneously.
- A change to one of the artifacts requires updates to the other two; a change that *only* lands in code is invisible to the PM and the partner until they trip over it.

When the agent IS the spec:

- There's no translation. The PM reads the same line of code the dev writes.
- There's no drift. There's only one artifact; updating it updates everyone's view.
- There's no async sign-off. Stakeholders read the file when they need to; the file is the truth.

## The discipline that keeps this true

The property is not free. It survives only because the platform enforces a small set of disciplines:

- **The `metadata` description is the source of truth for "what the agent is."** It is not a hand-wave. The discipline is that the description is *operative* — written for the LLM but readable by every human stakeholder.
- **The `perform()` body must be readable in one pass.** When it stops being readable, the agent has become two agents, and the spec property breaks. See [[Why hatch_rapp Was Killed]].
- **Parameters mean what they say.** The parameter schema is what a partner reads to estimate scope. If the schema is "loose" (untyped strings, "data" as a catch-all), the partner can't read it; the spec property breaks.
- **The agent doesn't import sibling modules.** Every helper is in the file (or in `utils/`, which is brainstem-shared). When an agent reaches for `from .helper import X`, the spec property breaks. See [[The Single-File Agent Bet]].

## What this enables

When the agent IS the spec:

- The workshop deliverable is the file ([[60 Minutes to a Working Agent]]).
- The partner-handoff is one file ([[Self-Documenting Handoff]]).
- Tier 1 → Tier 2 → Tier 3 portability is one file ([[Three Tiers, One Model]]).
- The rapp store catalog is a directory of files, each readable on its own.
- Code review *is* PM review *is* customer review.

Every other property the platform claims about "speed of delivery" or "compression of process" depends on this one.

## What this rules out

- ❌ Hidden state in agents that the metadata doesn't describe. If the agent does X, the description must mention X.
- ❌ Parameter schemas that hide complexity behind a single string field. *"input: a JSON string"* is a smell — that JSON has structure that should be in the schema.
- ❌ Out-of-band documentation that contradicts the agent file. There is one source of truth; the docs file in `pages/docs/` only summarizes the agent's published metadata.
- ❌ Agents whose behavior depends on environment variables or external config not visible to the reader. Configuration is the agent's metadata; if the env matters, the agent's metadata says so.

## When the property breaks

It breaks when an agent crosses a complexity threshold and stops being readable. The signal is clear: a partner asks for a discovery call to estimate the agent. That call is the receipt that the spec property has been violated.

The fix is never to add documentation; the fix is to **split or simplify the agent**.

## Discipline

- Read the agent file aloud before merging — to a non-technical listener. If the metadata description doesn't track, the description is wrong.
- The partner-pricing test: if a partner couldn't price the agent in 5 minutes from the file, the file is too complex.
- When tempted to add an external README to "explain" an agent, ask whether the agent's metadata description should be updated instead.

## Related

- [[The Single-File Agent Bet]]
- [[Self-Documenting Handoff]]
- [[60 Minutes to a Working Agent]]
- [[Why hatch_rapp Was Killed]]
- [[Three Tiers, One Model]]
