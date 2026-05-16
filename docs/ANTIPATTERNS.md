# Antipatterns — Things This Repo Will Never Do

> Rules locked in because they were almost done wrong, or because the rest of the industry is doing them wrong and we'd be following them off the cliff. Each entry is *load-bearing* — breaking it is a regression.

---

## 1. ONE TERM FOR THE PLUGIN UNIT — `agent`

**The rule.** A single `*_agent.py` file is called an **agent**. Never a *skill*, *routine*, *loop*, *plugin*, *tool*, *function*, *capability*, *cassette*, or any other synonym in user-facing copy, code, or documentation.

**Why.** Anthropic's product surface introduced overlapping taxonomies — agents, skills, MCP, plugins, routines — that all describe roughly the same thing in slightly different framings. The operator captured the cost in a private design conversation (May 2026):

> *"Anthropic… they really screwed up by introducing all of the different taxonomy that basically does the same thing. I mean, think about it, right? So agents, skills, routines, loops, plugins. I, like, who knows MCP, like whatever else they'll come up with. That basically poisoned the industry for onboarding."*

A new visitor cannot tell what's what. The complexity becomes the gatekeeper. People who already know the system stay productive; everyone else can't get started. That's the **AI winter precondition** — capability concentrates in a few hands and no one else trusts what they can't understand.

**The mom test.** If we can't explain it to a non-technical person in one sentence, we have one too many concepts. *"It's an agent. A small Python file that gives the AI a new ability."* — that's the whole vocabulary.

**How to apply.**

- **In code:** identifiers use `agent` only. `customAgents`, `_customAgentCount`, `fillAgents`, `AGENT_FRIENDLY`, `tr-agents`, `agent-chip`. Never `skill`, `plugin`, `routine`, `loop` in identifiers, CSS classes, or DOM ids. Acceptable exceptions: comments that explicitly call out the antipattern (this file, plus a few guard comments in `installer/plant.sh`).
- **In user-facing copy:** every label, button, error message, and status line says "agent" if it's referring to an `*_agent.py` file. The Track Record section is **Agents**, not Skills. The proposal flow is **Propose an agent**, not Propose a skill.
- **In documentation:** when explaining how the platform grows, say "agents" — `HERO_USECASE.md`, `ECOSYSTEM.md`, `README.md`, `CLAUDE.md`. Cross-reference the Constitution: *"Single-file agents are the plugin system. One file = one class = one `perform()` = one metadata dict."*
- **In commit messages and PR titles:** same.

**What to do when you see a synonym creeping in.** Treat it like dead code — delete and replace with `agent`. Don't introduce a new concept just because a UI surface "needs" different language. If it's a different concept, it deserves a different name AND a clear explanation of how it's not just an agent. Default rule: it's just an agent.

**Pre-commit checklist for this rule.** Before every commit that touches user-facing copy or `*_agent.py` references:

```
grep -niE '\bskill|\bplugin|\broutine|\bloop|\bcassette' <changed-files>
```

Hits from this grep that aren't inside an antipattern-guard comment block (commented `Never "skill"…` warnings) need to be renamed before the commit lands.

---

## 2. THE FROZEN KERNEL NEVER MOVES

**The rule.** `rapp_brainstem/brainstem.py`, `rapp_brainstem/VERSION`, and `rapp_brainstem/agents/basic_agent.py` are frozen at v0.6.0. Never edit them. Capabilities grow exclusively through new `*_agent.py` files in `agents/`.

**Why.** A frozen kernel + plug-in agents is what makes an organism portable across substrates and across time. Edit the kernel and you fork the species. The Constitution puts this as a sacred constraint; this file restates it because it's so often the first temptation.

**How to apply.** When something feels like it requires a kernel change, write a new agent that solves it instead. If the agent contract genuinely can't express the change, it's a CONSTITUTION-level conversation that touches every planted seed in existence. Don't shortcut.

---

## 3. NO BACKWARDS-COMPAT SHIMS FOR HALF-RELEASED FEATURES

**The rule.** When a schema changes, bump the version in the schema string and migrate cleanly. Don't add `if old_field exists, do A else do B` shims when nothing in the wild has the old field yet.

**Why.** The codebase is small enough that we can rip the band-aid off. Shims accumulate forever and the next reader has to figure out which branch is real.

**How to apply.** New schema → bump version → update every emitter → update every consumer → ship. If something downstream breaks and it's already in the wild, write a one-time migrator, not a forever shim.

---

## 4. NO SILENT FALLBACK TO "RAPP" / "AN AI ASSISTANT"

**The rule.** A planted organism's `soul.md` MUST include the spec-compliant `## Identity — read this every turn` block (per `rapp-twin-spec/1.0`). The block forbids the LLM from introducing itself as "RAPP", "an AI assistant", "your AI helper", "the brainstem", or any default platform branding.

**Why.** Without this block, LLMs default to brand chrome. The visitor lands at heimdall.github.io expecting Heimdall and gets greeted by "RAPP". The identity collapses into the substrate.

**How to apply.** `installer/plant.sh::write_soul_md` writes the block by default. If you ever rewrite the soul template or add a new kind, the Identity block is non-negotiable.

---

## 5. NETWORK CALLS WITHOUT A LOCAL-FIRST FALLBACK

**The rule.** Any GitHub fetch the front door makes goes through `cachedGhJson` / `cachedGhText`. Direct `fetch(github.com/...)` is forbidden in resume-rendering paths.

**Why.** The hero use case is offline-first. An organism in airplane mode must keep rendering its own resume from cached state. Bare fetches go blank when the network drops; that's a regression against `HERO_USECASE.md` §1.

**How to apply.** When adding a new GitHub-derived signal, wrap the fetch and stamp the cache. Render with a `📡 stale` pill when reading cache. See `_handleVerifyFile` and `fillMutations` for canonical examples.

---

*This file is append-only. Antipatterns get added when we almost did them wrong; nothing here ever gets quietly removed.*
