---
title: Self-Documenting Handoff
status: published
section: Process
hook: A partner can take a *_agent.py file and price the work without a discovery call. That property is the platform's biggest delivery shortcut.
---

# Self-Documenting Handoff

> **Hook.** A partner can take a `*_agent.py` file and price the work without a discovery call. That property is the platform's biggest delivery shortcut.

## The shortcut

In traditional delivery, the partner-handoff phase is where projects die slowly. The customer signs a discovery contract; weeks pass; a SOW arrives; the SOW underspecifies because the agent doesn't exist yet; scope creeps; the relationship sours.

RAPP collapses this phase. After a workshop ([[60 Minutes to a Working Agent]]), the customer hands a file — `<their_thing>_agent.py` — to the partner. The partner reads it. They estimate scope. They reply with a price. No discovery call.

This is not magic. It's a *property* of the agent file format, made possible by the disciplines below.

## What a partner needs to estimate

A scope estimate requires four things, in order of importance:

1. **What does it do?** The metadata description.
2. **What does it need from the customer's environment?** Input parameters + dependencies.
3. **What does it produce?** The return shape (often JSON, sometimes with `data_slush`).
4. **How does it integrate?** Auth, storage, downstream agents.

For a RAPP agent, all four are visible in the file:

- **(1) The metadata description.** The agent's purpose in plain English, operative for both the LLM and human readers. From [[The Agent IS the Spec]]: this is the customer-readable contract.
- **(2) The parameters schema.** Required vs. optional, types, enumerations. A partner reading this knows what data flows in.
- **(3) The `perform()` body and its return statement.** The output shape is right there. If `data_slush` is in play, the keys are explicit.
- **(4) The imports.** The file's import list reveals dependencies — the storage shim, any HTTP libraries, any specific Microsoft/Azure services. Imports that aren't already in `requirements.txt` reveal the integration surface.

A partner experienced with RAPP can extract all four in 5 minutes. That's the shortcut.

## The before/after

**Without RAPP:**
- Discovery call (1 hour).
- Discovery write-up (3 days).
- Customer review (1 week).
- SOW draft (3 days).
- SOW negotiation (1 week).
- Total: ~3 weeks before any code is written. The agent built afterward will reveal misunderstandings the SOW didn't catch.

**With RAPP:**
- Workshop (1 hour).
- File handoff (5 minutes).
- Partner reads file (5 minutes).
- Partner replies with price (1 day).
- Total: ~1 day. The agent file is the contract; misunderstandings are already filtered out by the customer's workshop participation.

The savings are not from automation; they're from the artifact carrying the information that discovery normally has to extract. The workshop puts the customer in the loop; the file captures the loop's output; the partner reads the output directly.

## Why partners trust the file

A partner accepting a file as a scope artifact is trusting that the file *means what it says*. RAPP earns that trust through structural discipline:

- **The metadata description is operative.** It's not aspirational marketing; it's what the LLM reads to decide when to invoke the agent. If the description is wrong, the agent doesn't work. So the description is true.
- **Required parameters are required.** The platform's tool-dispatch layer enforces the schema. Optional parameters can be skipped; required ones cannot. The partner reading "required" can trust it.
- **The `perform()` body is the implementation.** No external "actual implementation" file exists. What's in the file is what runs. Period.
- **Tier portability.** The file the partner reads is the file that ships in Tier 1, Tier 2, and Tier 3. There's no "we'll add the production version later" caveat that hides scope. See [[Three Tiers, One Model]].
- **No sibling imports.** The single-file constraint ([[The Single-File Agent Bet]]) means the partner doesn't have to chase imports across the codebase. Helpers are inline; standard utilities are in `utils/` and shared across all agents.

Each of these is a property the platform's design produces — not a guarantee the partner has to take on faith.

## The "with / without RAPP" beat

The marketing pages (`pages/about/partners.html` in particular) compress this into a single before/after image:

> **Without RAPP:** discovery call → spec → estimate → build → review → revise. 3 weeks before working software.
>
> **With RAPP:** working agent → file handoff → estimate → ship. 1 hour to working software. 1 day to estimate.

The compression is real. The shortcut is the file format.

## What this rules out

- ❌ Agents whose behavior depends on environment configuration not declared in the file. If env variables matter, the metadata description must say so.
- ❌ Agents that secretly call external services through deeply-nested helpers. The integration surface must be visible in the imports + `perform()` body.
- ❌ Agents that lie about their parameters. *"Optional"* must mean optional in `perform()`; *"required"* must mean required.
- ❌ Returning unstructured data when the consumer needs structured data. If the agent's output is consumed downstream, the shape is part of the contract — document it via `data_slush` keys, JSON schema notes, or both.
- ❌ "We'll productionize this in a follow-up rewrite." The agent the partner reads is the agent that ships.

## The agent self-document checklist

For an agent to honestly serve as its own SOW, it must:

- [ ] Have an operative metadata description (3+ sentences, names the trigger conditions, names the persistence side effects).
- [ ] Use a complete parameter schema (no untyped catch-all blobs).
- [ ] Return a structured response (JSON preferred; document the keys).
- [ ] Declare `data_slush` keys explicitly if downstream agents depend on them.
- [ ] Keep the `perform()` body readable in one screen (or document why not).
- [ ] List dependencies cleanly (no hidden runtime imports).
- [ ] Not lie. Required is required. Optional is optional. Side effects are described.

When all checks pass, the agent is a partner-readable spec. When any fails, the spec property is broken — fix the agent before handing it off.

## When this fails

The handoff fails when:

- The agent grew past one-screen readability and the partner has to "study" it. (Split or simplify — see [[Why hatch_rapp Was Killed]].)
- The customer's data isn't accessible to the partner without additional integration work that the file doesn't document. (Integration is a known scope item; the file should mention it.)
- The agent is a research-quality prototype, not a production-shaped artifact. (Workshop produced something incomplete; not a partner-handoff condition.)

The discipline: **don't hand off broken self-document checklists.** A file that doesn't pass the checklist isn't a SOW; it's a draft.

## Discipline

- Run the self-document checklist on the workshop's output before sending. If anything's missing, fix it before the handoff.
- "We'll explain on a call" is the rejection of self-documenting handoff. If a call is needed, the file is incomplete.
- Partners new to RAPP need their first 2-3 file-handoffs accompanied by a brief on what to look for; once they internalize the pattern, the call disappears.

## Related

- [[The Agent IS the Spec]]
- [[The Single-File Agent Bet]]
- [[60 Minutes to a Working Agent]]
- [[Three Tiers, One Model]]
- [[Why hatch_rapp Was Killed]]
