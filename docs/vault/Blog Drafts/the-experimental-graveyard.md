---
title: The experimental graveyard — what we tried, what we cut, and why we kept the bones
status: shipped
published_url: https://kody-w.github.io/2026/04/24/the-experimental-graveyard/
section: Blog Drafts
hook: An "experimental_agents/" folder that the auto-loader explicitly skips. The rule that produces it. The lesson it teaches every time someone asks why a file is gone.
date: 2026-04-24
sources:
  - "[[The experimental Graveyard]]"
  - "[[Why hatch_rapp Was Killed]]"
class: evergreen
decay: high
---

# The experimental graveyard — what we tried, what we cut, and why we kept the bones

Most projects delete failed experiments and pretend they didn't happen. The git history holds the bones, technically, but only someone who already knows the file existed will go looking. The next contributor walks past the gap entirely, oblivious — and often re-creates the same experiment, because the lesson it taught was never carried forward.

We do something different. The platform's `agents/` directory has a sibling: `experimental_agents/`. The auto-loader explicitly *skips* it. Files that landed there once worked, sort of, and aren't loaded anymore. They're memorial — and they're load-bearing for the way the platform learns from itself.

## The rule that produces it

Article XVII of the project's CONSTITUTION says: *"`agents/` IS the user's workspace."* Two subdirectory names are reserved by the engine and never auto-load — `experimental_agents/` (in-flight or parked work) and `disabled_agents/` (turned off). Everything else under `agents/` recursively loads.

The reserved names are not styling. They're a contract. The brainstem's `load_agents()` function walks the directory and explicitly filters out paths containing those names. An agent that lives in `experimental_agents/` cannot be invoked by the LLM; it can be hand-loaded for testing, then promoted into the live tree once it earns its place.

That's the operational use. The deeper use is what happens when an agent *fails* its place.

## How a file ends up there

The motion looks like this:

1. **Idea.** Someone writes a new agent — `vibe_classifier_agent.py`, say. It does something experimental, plausible, maybe useful.
2. **Try.** The agent goes live. It runs. The LLM picks it up. The team observes whether it earns its keep.
3. **Verdict.** Either it does (great, it stays in the live tree) or it doesn't (the LLM ignores it; the operator notices it firing on irrelevant turns; it interferes with another agent's claim).
4. **Move.** Verdict-negative agents go to `experimental_agents/`. They keep their full source. The auto-loader stops finding them. The capability disappears from the LLM's tool list.
5. **Memorial.** A vault note in `pages/vault/Removals/` captures *why* it was moved. What hypothesis was being tested. What signal made the verdict.

The operative discipline: **delete completely, or move to memorial. Never half-delete.** The Constitution Article XIII (Reversibility) is the underlying rule — every feature must be cleanly removable. Half-torn-out code with `# TODO: remove this` comments is the failure mode this prevents.

## Why memorial beats deletion

When we kill an agent and write the memorial, three things happen that don't happen when we just `git rm`:

**The why outlasts the code.** A commit message captures *what* was removed in 50 characters. A vault note captures the hypothesis, the signal that disconfirmed it, and the rule it produced. Six months later, when someone has a similar idea, they don't have to re-derive the answer.

**The shape is preserved.** Future versions of the platform might revisit a question we couldn't answer with the technology we had. A memorial keeps the file readable. *"We tried this. Here's exactly what we wrote. Here's why it didn't work in 2026. If you're reading this in 2028 and the model is smarter, you might want to look at it again."*

**The graveyard is teaching material.** New contributors browsing `experimental_agents/` see what's been tried and what didn't land. That's a faster education than reading post-mortems — they read working code that almost-but-not-quite earned its place. The seams are visible. The boundary between "good idea" and "ships" is observable.

## What's in there

A representative slice from the current graveyard, with one-line memorials:

- **`hatch_rapp_agent.py`** — 2,138 lines. Tried to be a mega-agent that orchestrated other agents internally instead of letting the LLM do it. Killed because the orchestration layer was duplicating what the brainstem's tool-calling loop already did, with worse error handling. See [[Why hatch_rapp Was Killed]].
- **A pair of swarm/server consolidation agents** — pre-dated the realization that swarms are directories, not runtime objects. Killed in a 6,500-line merge that collapsed three competing patterns into one. See [[Why t2t and swarm_server Are Gone]].
- **The split memory agents** (`save_memory_agent.py`, `recall_memory_agent.py`) — merged into `manage_memory_agent.py` once we noticed the LLM was disambiguating between them on every turn. See [[From save_recall to manage_memory]].

Each of these failures produced a rule. *Don't build orchestration layers that duplicate the tool-calling loop. Swarms are directories, not classes. Agent boundaries should match decision boundaries.* The rules made it into the Constitution. The bones are still in `experimental_agents/`. Both are load-bearing.

## The pattern generalizes

You don't need an agent platform to use this discipline. Any project with abandonable units — feature flags, micro-services, plugin folders, alternate algorithms — benefits from a graveyard separate from a deletion. Three things make it work:

1. **An explicit rule that the runtime doesn't read the graveyard.** No risk of accidental revival.
2. **A memorial format that travels with the code.** A vault note, a `WHY-DELETED.md`, a structured PR description — the form matters less than the discipline of writing one.
3. **A naming convention that makes the graveyard browsable.** `experimental_*`, `archived_*`, `_deprecated_*` — pick one and stick with it.

The cost is a folder you don't use much. The benefit is institutional memory that doesn't decay when the people who made the decisions move on.

## Receipts

- The reserved-name rule: `CONSTITUTION.md` Article XVII in [github.com/kody-w/RAPP](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md).
- The reversibility rule: Article XIII.
- The graveyard itself: `rapp_brainstem/agents/workspace_agents/experimental_agents/` — sibling to the live tree.
- Memorials: [[Why hatch_rapp Was Killed]], [[Why t2t and swarm_server Are Gone]], [[From save_recall to manage_memory]] in `pages/vault/Removals/`.

The platform's bet: *the things you abandoned are part of how you learn. Burying them is wasteful. Memorializing them is cheap.* The graveyard is the proof.
