---
title: Voice and Twin Are Forever
status: published
section: Founding Decisions
hook: Two delimited slots in every response, fixed. New capabilities go inside an existing slot — never as a third one.
---

# Voice and Twin Are Forever

> **Hook.** Two delimited slots in every response, fixed. New capabilities go inside an existing slot — never as a third one.

## The mechanism

Every assistant response from the brainstem is a string with up to two literal delimiters:

```
<main response>
|||VOICE|||
<TTS-ready, 2-3 sentence version>
|||TWIN|||
<digital twin's reaction, first-person as the user, to the user>
```

The split happens once, at the bottom of `chat()` in `rapp_brainstem/brainstem.py:984-998`, with `str.partition()` — left to right, so the twin block can never bleed into voice and voice can never bleed into main. The downstream consumer (Tier 1 web UI, Tier 2 API caller, Tier 3 Copilot Studio adapter) gets three keys: `response`, `voice_response`, `twin_response`. Each key is allowed to be empty.

That's the contract. It is **Sacred Constraint #3**. It does not change.

## Why exactly two

The platform did not pick two arbitrarily. It picked two because:

- **`|||VOICE|||`** is a different *audience* — it's TTS. A voice listener cannot scan; they must hear. The voice version exists because the same content shaped for visual scanning is hostile when spoken aloud. One delimiter, one audience.
- **`|||TWIN|||`** is a different *speaker* — it's the user's digital twin, not the assistant. First-person, addressed back to the user. Hints, risks, calibration probes. See [[The Twin Offers, The User Accepts]].

Each delimiter answers a question that no other delimiter could answer. That is the bar.

## Why not three

The temptation toward a third slot is constant. Some of the proposed (and rejected) third slots:

- **`|||DEBUG|||`** — server-side telemetry, model thoughts, intermediate state. Rejected because debug content already has a home: agent logs returned in `result["agent_logs"]` and the optional `<telemetry>` tag *inside* the twin block. Adding a top-level delimiter would have created two homes for the same content.
- **`|||TOOLS|||`** — explicit tool-call surface. Rejected because tool calls are already a structured field in the OpenAI response schema (`message.tool_calls`); they don't need a delimiter.
- **`|||SUMMARY|||`** — a TL;DR of the response. Rejected because a summary is a *shape* of the main response, not a separate audience or speaker. If the user wants summaries, that goes in the system prompt, not in a new slot.
- **`|||DRAFT|||`** — a "this is my work-in-progress" intermediate. Rejected because intermediates are streaming, not delimited; this is what server-sent events are for, not text protocol.

Every rejected slot failed the same test: *the content has another home, or it's not a different audience or speaker*.

## Why "forever"

The forever-ness is not aesthetic dogma. It's a downstream-cost argument:

- Every prompt template in `soul.md` references the slots.
- The brainstem's parser hardcodes the delimiters (`brainstem.py:988-996`).
- The Tier 1 web UI (`rapp_brainstem/web/index.html`) renders three regions.
- The Tier 2 Azure Functions JSON shape exposes them as separate keys.
- The Tier 3 Power Platform adapter splits them again at the connector boundary.
- Every test fixture matches against `|||VOICE|||` / `|||TWIN|||` literals.
- Every agent that wants to influence the slots writes a `system_context()` that respects them.

A new top-level slot would change all of these in lockstep. Because Tier 2 and Tier 3 lag Tier 1 by a deploy cycle, the migration window for a new slot is measured in *weeks*, not minutes. The platform paid that cost twice (once for VOICE, once for TWIN) and is unwilling to pay it a third time without an unprecedented justification.

## How new capabilities get added

Sub-capabilities go *inside* an existing slot via tags. The TWIN slot, as configured in `brainstem.py:931-950`, already accepts these:

- `<probe id="t-..." kind="..." subject="..." confidence="0.0-1.0"/>` — a tagged claim the twin is making, that subsequent turns can validate.
- `<calibration id="<probe-id>" outcome="validated|contradicted|silent" note="..."/>` — a judgment on a prior probe.
- `<telemetry>one fact per line</telemetry>` — server-log-only debug signal.
- `<action kind="send|prompt|open|toggle|highlight|rapp" target="..." label="...">body</action>` — a one-click UI affordance the user can accept or ignore.

Each of those is a new capability that did *not* require a new slot. The pattern is clear: the slot is the audience/speaker boundary; the tags inside are the protocol vocabulary. Vocabulary can grow indefinitely. Boundaries cannot.

## What this rules out

- ❌ Adding `|||X|||` for any X. New X goes inside an existing slot or it is structured-data outside the response string.
- ❌ Repurposing an existing slot. The voice slot will not become "voice or summary" depending on a flag — that's two slots wearing one name.
- ❌ Letting a slot's vocabulary leak across slots. The TWIN slot uses tags; the VOICE slot is plain spoken text. Mixing them breaks the parser's left-to-right invariant.
- ❌ "Soft" delimiters via formatting (e.g., `## VOICE`). The literal `|||VOICE|||` is what the parser depends on; soft alternatives invite false positives in user content.

## When to reconsider

The line moves only if a new audience or speaker emerges that no existing slot or tag can carry. Concretely, the test is:

1. Is this content addressed to a different listener than `main` (visual reader) or `voice` (auditory reader)?
2. Is this content spoken by a different speaker than the assistant or the twin?
3. Could a tag inside an existing slot carry it instead?

If the answer to (1) or (2) is yes *and* (3) is no, then a new slot is on the table. So far this has not happened.

## Discipline

- When you need to add output, default to a tag inside an existing slot.
- When you think you need a new slot, write the rejection memo before you write the code — the memo will usually convince you to use a tag instead.
- When the rejection memo *fails* to convince — that's the conversation that earns the third slot.

## Related

- [[The Brainstem Tax]]
- [[Engine, Not Experience]]
- [[The Twin Offers, The User Accepts]]
- [[Calibration Is Behavioral, Not Explicit]]
- [[Every Twin Surface Is a Calibration Opportunity]]
