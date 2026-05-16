---
title: Three Tiers, One Model
status: published
section: Manifestos
hook: The same agent file runs unmodified in Tier 1, Tier 2, and Tier 3. That portability is the platform's central claim.
---

# Three Tiers, One Model

> **Hook.** The same agent file runs unmodified in Tier 1, Tier 2, and Tier 3. That portability is the platform's central claim.

## The claim

> *"Three tiers, one model."*

The phrase appears in release notes, in marketing pages, and in the platform's identity. It compresses into seven syllables a property the rest of the design must protect: **the agent file is the same file in every tier**.

Not "compatible." Not "convertible." *The same file.* `rapp_brainstem/agents/<their_thing>_agent.py` in Tier 1 → `rapp_swarm/_vendored/agents/<their_thing>_agent.py` after `build.sh` in Tier 2 → packaged in the Tier 3 solution. Diff the bytes. They match.

## What "the model" is

The model — the contract every agent obeys — is small enough to enumerate:

- **Discovery.** Agents are auto-discovered by globbing `agents/*_agent.py`. (Tier 1: `brainstem.py:765`. Tier 2: vendored under `rapp_swarm/_vendored/agents/`. Tier 3: packaged inside the Power Platform solution.)
- **Inheritance.** Agents extend `BasicAgent` (51 lines, identical across tiers).
- **Metadata.** Agents declare a `metadata` dict (OpenAI function-calling shape).
- **Entry point.** Agents implement `perform(**kwargs) -> str`, optionally `system_context() -> str | None`.
- **Slot delimiters.** Responses split on `|||VOICE|||` and `|||TWIN|||` (forever; see [[Voice and Twin Are Forever]]).
- **Inter-agent state.** Pipelines compose through `data_slush` (see [[Data Sloshing]]).
- **Storage.** Agents import `from utils.azure_file_storage import AzureFileStorageManager` (the import is hijacked in Tier 1 via the shim; the real Azure module is loaded in Tier 2 and Tier 3 — see [[Local Storage Shim via sys.modules]]).
- **LLM dispatch.** Agents are *called by* the LLM via tool dispatch; they don't call the LLM directly. The LLM provider is determined by `utils/llm.py`'s `detect_provider()`.

That's the contract. Every tier honors it identically. Every agent runs against it without knowing which tier it's in.

## Why this is the central claim

Most platforms in this space make either a *local-only* claim ("we run on your laptop") or a *cloud-only* claim ("we run in your tenant"). Each is a real claim with real value, but neither is *enough* for the workflow that drives projects: build local, validate with the customer, deploy to production, distribute via the customer's platform of choice.

A platform that does only one of those forces the team into a *rewrite phase* between tiers. The Tier 1 prototype, however good, becomes a spec to be re-implemented for production. Re-implementation is where projects die — scope drifts, the customer's exact prompts vanish, the partner discovers integration surfaces nobody documented, the production version diverges from what the customer validated.

RAPP's bet is that the rewrite phase is the worst phase, and that the best way to eliminate it is to make the artifact survive the journey unchanged. The agent file built in the workshop is the agent file that ships. The customer's validation is preserved by *the file itself*, not by re-derivation.

## What enables the claim

The portability is not declarative; it's mechanical. Three subsystems make it work:

- **The local storage shim** ([[Local Storage Shim via sys.modules]]) — agents look like they import the Azure SDK. The brainstem decides what that import resolves to at boot time. Agents stay portable by *looking like normal Python*.
- **Vendoring** ([[Vendoring, Not Symlinking]]) — Tier 2 doesn't import from Tier 1's directory; it copies. The duplication is the receipt that someone considered the cross-tier impact. `rapp_swarm/build.sh` is the explicit sync point.
- **Provider dispatch** ([[The Deterministic Fake LLM]]) — `utils/llm.py` exposes Azure OpenAI, OpenAI, Anthropic, and a deterministic fake under the same `chat()` entry point. Selection is by environment. Agents don't know which provider is running.

These three subsystems are the platform's load-bearing portability machinery. Every other feature must work *within* them.

## What the claim costs

Portability is not free. The platform pays in conveniences it walks away from:

- **Frameworks.** Most agent-orchestration frameworks assume a specific runtime (a single Python process, a specific cloud, a specific package layout). RAPP can't adopt them without breaking tier portability. See [[What You Give Up With RAPP]].
- **Abstractions.** Agents in RAPP repeat patterns that a framework would factor out. The duplication is the cost of the portability proof.
- **Cross-tier code sharing.** The Tier 2 agents are *copies* of Tier 1 agents, not symlinks. Updates require an explicit `build.sh` re-run. The friction is intentional.
- **Speed of feature shipping.** Every brainstem-level feature is gated by all three tiers. Features that would be easy in one tier and hard in another don't ship.

The platform pays these costs deliberately because the alternative — a tier-specific platform that needs a rewrite phase — is worse for the customer.

## The portability test

A feature passes the portability test if the agent file using it can be:

1. Edited and tested in Tier 1.
2. Vendored to Tier 2 (`rapp_swarm/build.sh`) and run in Azure Functions.
3. Packaged in Tier 3 and run inside Microsoft Copilot Studio.

…with no source-code changes between steps. Just the file. That's the test.

Features that don't pass the test don't go in the brainstem. They might still work — as agents, with the agent author taking responsibility for the tier story.

## What this rules out

- ❌ Tier-specific brainstem features. Anything in the brainstem must work everywhere.
- ❌ Agent code that branches on tier (`if os.environ.get("LOCAL"):`). The shim layer makes this unnecessary; if an agent has it, the agent has bypassed the platform's portability machinery.
- ❌ Provider-specific behavior in agent code. Provider dispatch lives in `utils/llm.py`; agents don't reach into it.
- ❌ "Tier 2 will have a richer version" caveats. The richness gap between tiers is intentionally near-zero; if an agent needs Tier 2's environment specifically, the gap is the bug.

## When this would change

The claim would change if:

- A new tier is added that *can't* honor the contract. (So far, every proposed tier — including hypothetical on-device tiers — fits.)
- The cost of maintaining portability exceeds the value of the claim. (Hasn't happened.)
- A customer segment emerges that needs only one tier and is willing to pay the rewrite tax. (Even those customers benefit from being on a portable platform — they may not need three tiers today, but the option keeps their future open.)

So far, "three tiers, one model" has won every contested call. The model that survives every test is the model that defines the platform.

## The receipt

The most credible receipt for the claim is the file system itself. Open `rapp_brainstem/agents/manage_memory_agent.py` and `rapp_swarm/_vendored/agents/manage_memory_agent.py`. The bytes match. That's not coincidence — that's the platform's claim, made concrete.

## Discipline

- The portability test is the bar for every brainstem-level feature.
- Vendoring drift is a regression. `tests/run-tests.mjs` exercises the contract from both Tier 1 and Tier 2's vendored copy; if they diverge, the build script needs a re-run.
- "Tiers, one model" is one phrase, not three. The model is what makes the tiers honest.

## Related

- [[Why Three Tiers, Not One]]
- [[The Single-File Agent Bet]]
- [[Vendoring, Not Symlinking]]
- [[Local Storage Shim via sys.modules]]
- [[The Deterministic Fake LLM]]
- [[The Engine Stays Small]]
