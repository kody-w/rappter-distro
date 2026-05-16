---
title: From save_recall to manage_memory — agent consolidation as discipline
status: shipped
published_url: https://kody-w.github.io/2026/04/24/from-save-recall-to-manage-memory/
section: Blog Drafts
hook: We had two memory agents. One saved, one recalled. The split read clean in the SPEC and got messy in the LLM. We merged them — and learned something about when to consolidate.
date: 2026-04-24
sources:
  - "[[From save_recall to manage_memory]]"
  - "[[The experimental Graveyard]]"
class: evergreen
decay: high
---

# From save_recall to manage_memory — agent consolidation as discipline

The single-file agent contract is small enough to count: extends `BasicAgent`, sets `self.name`, sets `self.metadata`, implements `perform()`. Everything else is freedom inside the file. The contract gets out of your way so you can write capabilities without writing infrastructure.

That same minimalism makes it tempting to fragment. Each agent is so cheap to add that *more* agents looks like *better* organization. Save and recall are clearly different operations — save mutates state, recall reads it — so they should be different agents. Right?

For three months, that's what we ran with. `save_memory_agent.py` and `recall_memory_agent.py`, side by side in the starter set. Then we merged them into one agent: `manage_memory_agent.py`. This is the post about why.

## How the split looked from the SPEC

Clean. Beautiful, even. Two agents with two clear responsibilities:

```python
# save_memory_agent.py
class SaveMemoryAgent(BasicAgent):
    name = 'SaveMemory'
    metadata = {
        "name": "SaveMemory",
        "description": "Persist a fact, preference, insight, or task...",
        "parameters": { "memory_type": ..., "content": ..., "importance": ... }
    }
    def perform(self, **kw): write_to_disk(...)

# recall_memory_agent.py
class RecallMemoryAgent(BasicAgent):
    name = 'RecallMemory'
    metadata = {
        "name": "RecallMemory",
        "description": "Read previously-saved memories matching a query...",
        "parameters": { "query": ..., "memory_type": ... }
    }
    def perform(self, **kw): read_from_disk(...)
```

Each file was tight. Each metadata schema was focused. The starter directory listing read like good documentation: *here's how to save things, here's how to recall things, study this pattern.*

## How the split looked from the LLM

Less clean. The LLM got two tools whose descriptions, on inspection, said roughly the same thing: *"this agent does memory."* Differentiation lived in the verb. The LLM-side reasoning that needed to happen on each turn was: *"the user just said something memory-shaped. Is this a save or a recall? Sometimes both?"*

That decision — save vs. recall — was the model's to make from the user's natural language. Mostly correct. Occasionally wrong in ways that produced silent dropped writes ("the user said remember this *and* tell me what we know about X" — model picked recall, save never happened). The bug shape was confusing because the user had clearly *said* the magic word "remember," and the agent layer had been trained to handle exactly that.

The deeper issue: the LLM's tool-calling vocabulary collapsed our two-agent intent into one decision boundary anyway. Splitting them at the file level didn't propagate cleanly to the model's representation of the operation. Two tools with overlapping descriptions caused the *model* to do disambiguation work that should have been *our* problem, in code, where it could be tested.

## The merge

`manage_memory_agent.py` exposes one tool with one schema and one `perform()`. The schema parameter `action: save | recall | search` makes the operation explicit at the call site:

```python
class ManageMemoryAgent(BasicAgent):
    name = 'ManageMemory'
    metadata = {
        "name": "ManageMemory",
        "description": "Persist or retrieve typed memories...",
        "parameters": {
            "action": { "enum": ["save", "recall", "search"] },
            "memory_type": ...,
            "content": ...,
            "query": ...,
        }
    }
    def perform(self, action, **kw):
        if action == 'save':   return self._save(**kw)
        if action == 'recall': return self._recall(**kw)
        if action == 'search': return self._search(**kw)
```

The model now sees one tool with three named modes. The call shape carries the intent explicitly. The bug class — silent dropped writes from misclassified intent — disappears, because there's no longer a classification step. The model writes `action: "save"` or it doesn't.

This isn't an argument for collapsing every related pair of agents. It's an argument that *agent boundaries should match decision boundaries*. When two agents handle conceptually-paired operations and the LLM has to pick between them on each turn, the boundary is doing harm. Move the choice into the schema and let the call site name it.

## When to split, when to merge

The discipline that fell out of this:

- **Split when the operation, the inputs, the outputs, or the side-effects are genuinely different.** A weather agent and a calendar agent share nothing meaningful; they should be separate files, full stop.
- **Split when the consumer wants to invoke them in different contexts.** Some teams need the calendar without the weather; the split lets them.
- **Merge when the agents conceptually answer one question with different verbs.** Memory was always "what does the user want done with their memory store?" — a save/recall/search trinity. Splitting it shifted the question into the LLM.
- **Merge when the metadata descriptions start saying the same thing.** That's the smell. If you can't write a description for `agent_A` that doesn't apply equally well to `agent_B`, the boundary is doing zero work.

The merge wasn't a refactor for size or for performance. It was a recognition that the *decision* belongs in the call, not in the routing. The agent's job is to do work; the LLM's job is to decide *what* work; the schema is where the LLM and the code agree about how that conversation goes.

## The lesson the file is teaching

Single-file agents make multiplying agents nearly free. That makes them an excellent vehicle for *iterating* — try the split, see if it lands, merge if it doesn't. The cost of being wrong is one file rename and a schema update. The cost of being right is a system the LLM can reason about cleanly.

Three months running the split was not a mistake. It was the experiment that made the merge legible. We learned the seam by trying to use it. The vault note [[From save_recall to manage_memory]] memorializes the *why* so the next contributor doesn't try to re-introduce the split as cleanup.

## Receipts

- The merged agent: [`rapp_brainstem/agents/manage_memory_agent.py`](https://github.com/kody-w/RAPP/blob/main/rapp_brainstem/agents/manage_memory_agent.py).
- The vault note: [[From save_recall to manage_memory]] under `pages/vault/Removals/`.
- The experimental graveyard, which holds adjacent removal stories: [[The experimental Graveyard]].

The platform's working knowledge: *agent boundaries should match decision boundaries.* When they don't, the LLM does the disambiguation work, and the bugs hide there.
