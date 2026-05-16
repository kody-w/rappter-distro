---
title: Major Moments
status: published
section: Foundations
hook: A code-anchored timeline of moments worth remembering. No personal dates — every entry points at a file, a deletion, or a constitutional change.
---

# Major Moments

> **Hook.** A code-anchored timeline of moments worth remembering. No personal dates — every entry points at a file, a deletion, or a constitutional change.

This is a *public* timeline. Each entry references something that exists in the public repository — a deletion, a constitutional addition, a file that did or didn't ship. Personal dates and incidents are deliberately absent.

For the operational ledger of what's currently happening, see [[Release Ledger]]. For the forward-looking plan, see [[Documentation Roadmap]].

## The platform's biggest deletions

Deletions matter more than additions for understanding the platform. Each of these was load-bearing in its day; each was killed because the shape was wrong, not the intent.

| Artifact | Lines | What it taught |
|---|---|---|
| `rapp_brainstem/agents/experimental/hatch_rapp_agent.py` | 2,138 | Mega-agents are multiple agents wearing one filename. → [[Why hatch_rapp Was Killed]] |
| `rapp_brainstem/swarm_server.py` | 1,736 | "Support modules" with their own ports break tier portability. → [[Why t2t and swarm_server Are Gone]] |
| `rapp_brainstem/agents/pitch_deck_agent.py` | 1,087 | Template-shaped agents drift toward unmaintainable. |
| `rapp_brainstem/agents/experimental/brief_writer_agent.py` | 196 | Specialist chains with overlapping triggers fail. → [[The experimental Graveyard]] |
| `rapp_brainstem/agents/experimental/brief_strategist_agent.py` | 164 | Same. |
| `rapp_brainstem/agents/experimental/brief_analyst_agent.py` | 157 | Same. |
| `rapp_brainstem/agents/experimental/brief_scout_agent.py` | 154 | Same. |
| `rapp_brainstem/agents/save_memory_agent.py` | 142 | CRUD-shaped sibling agents lose to consolidation. → [[From save_recall to manage_memory]] |
| `rapp_brainstem/agents/recall_memory_agent.py` | 136 | Same. |
| `rapp_brainstem/agents/experimental/exec_brief_agent.py` | 130 | Pioneered the live-card pattern; failed at internal state machines. |
| `rapp_brainstem/agents/experimental/copilot_research_agent.py` | 74 | Provider-specific code in agents breaks the abstraction. |
| `rapp_brainstem/workspace.py` | 161 | Workspace as a top-level module belongs in `agents/` organization, not in code. |
| `rapp_brainstem/chat.py` | 342 | The chat surface is `brainstem.py`'s — separate file was redundant. |
| `rapp_brainstem/t2t.py` | 337 | Twin-to-twin is a tag vocabulary, not a transport. |

Total: ~7,000 lines of code deleted in the consolidation that produced the current shape. Every line had a reason; every reason is documented in a vault note.

## The platform's structural moves

Reorganizations that changed how the repo is read:

- **`rapp_brainstem/{llm.py, local_storage.py, twin.py, _basic_agent_shim.py}` → `rapp_brainstem/utils/`.** The shared utilities directory was created to separate the engine surface from one-off scripts. See [[Local Storage Shim via sys.modules]].
- **The repo-root cleanup of April 2026.** 12 marketing pages and aux docs moved out of root into `pages/` and `pages/docs/`. CONSTITUTION Article XVI extended to ratify the routing rules. → [[Roots Are Public Surfaces]].
- **The vault came online.** `vault/` directory created at root, governed by CONSTITUTION Article XXIII. The static viewer at `pages/vault/` ships with it.

## The platform's constitutional additions

Each of these moments was a *new article* added to the constitution — not a tweak, but a load-bearing rule:

- **Article XV — Tier Parity Is a /chat Contract** ratified that the same agent file works across tiers via the `/chat` route, not via a transport-level abstraction. → [[Three Tiers, One Model]].
- **Article XVI — The Root Is the Engine's Public Surface** ratified the brainstem-root cleanliness rule, then was extended to cover the repo root. → [[Roots Are Public Surfaces]].
- **Article XVII — `agents/` IS the User's Workspace** ratified the user-organized directory model, distinct from the brainstem's flat discovery glob.
- **Article XX — UI Defaults to Beginner-First** ratified the calibration-aware UI default posture.
- **Article XXI — Every Twin Surface Is a Calibration Opportunity** turned the twin's tag vocabulary into a UX rule. → [[Every Twin Surface Is a Calibration Opportunity]].
- **Article XXIII — The Vault Is the Long-Term Memory** ratified this vault. → [[Roots Are Public Surfaces]].

## The platform's biggest *non-additions*

Things the platform deliberately didn't ship, despite the temptation:

- **A workflow / DAG editor.** Pipelines are emergent through agent composition; there is no graph. → [[Engine, Not Experience]].
- **A vector database.** Memory is a JSON file in Tier 1; Azure File Storage in Tier 2/3. RAG is an agent's choice, not a platform feature. → [[What You Give Up With RAPP]].
- **A `|||DEBUG|||` or `|||TOOLS|||` slot.** Tag vocabulary inside existing slots covers it. → [[Voice and Twin Are Forever]].
- **A package on PyPI / npm.** GitHub Pages + raw URLs are the distribution. → [[Why GitHub Pages Is the Distribution Channel]].
- **A "configure your preferences" page.** Behavioral calibration replaces it. → [[Calibration Is Behavioral, Not Explicit]].
- **A built-in framework on top of the LLM.** The LLM is the framework; `data_slush` is the wire. → [[Data Sloshing]].

## Files that proved a pattern

Files that didn't get deleted because they showed the right shape — worth pointing at as canonical examples:

- **`rapp_brainstem/agents/basic_agent.py`** (51 lines). The base class. Smaller is better; growing it is a tax on every agent. → [[The Single-File Agent Bet]].
- **`rapp_brainstem/utils/llm.py`** (247 lines, 4 providers). The provider-dispatch pattern. The fake provider lives next to the real ones, not in a test folder. → [[The Deterministic Fake LLM]].
- **`rapp_brainstem/agents/manage_memory_agent.py`** (79 lines). The post-consolidation memory agent. Tight, single-purpose, operative metadata. → [[From save_recall to manage_memory]].
- **`rapp_swarm/_vendored/`** (the vendored Tier 2 tree). Duplication-as-receipt. → [[Vendoring, Not Symlinking]].

## How to add an entry

When something happens that's worth remembering on this scale:

1. The artifact must exist in the public repo (a file, a deletion, a constitutional article).
2. The entry must be code-anchored — a path, a line count, an article number.
3. No personal dates. The git log has dates; this note has *moments*.
4. Append the entry under the appropriate section. If there's no appropriate section, add a section heading.

## What this is not

- Not a changelog. `VERSIONS.md` and the release-notes page do that.
- Not a personal memoir. The platform's history; not anyone's story.
- Not a roadmap. The forward-looking version is [[Documentation Roadmap]].
- Not a release notes page. The user-facing version is `pages/release/release-notes.html`.

## Related

- [[Release Ledger]]
- [[Documentation Roadmap]]
- [[Why hatch_rapp Was Killed]]
- [[The experimental Graveyard]]
- [[Roots Are Public Surfaces]]
- [[Three Tiers, One Model]]
