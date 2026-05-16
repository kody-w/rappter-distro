---
title: The Twin Offers, The User Accepts
status: published
section: Twin and UX
hook: The asymmetry that defines RAPP's UX. The twin proposes; the user disposes. The twin never asks; the user never has to configure.
---

# The Twin Offers, The User Accepts

> **Hook.** The asymmetry that defines RAPP's UX. The twin proposes; the user disposes. The twin never asks; the user never has to configure.

## The principle

In every UI surface RAPP ships, the rule is the same:

> **The twin offers — the user accepts, ignores, or corrects. The twin never demands an answer. The user is never required to configure.**

This is the difference between *pulling* a user through a flow ("first, set your preferences") and *placing offers in front of them* ("here's what I'd do; you can take it or change it").

The principle has three corollaries:

1. The twin's default behavior is its current best guess, not a blank slate awaiting input.
2. Every "are you sure?" prompt is a failure mode in this model — corrections come *after* the action, not gating it.
3. Configuration screens are anti-patterns. Behavior is calibrated by what the user accepts and ignores, not by what they tick.

This is not a UX preference. It is the load-bearing assumption behind the entire platform's twin layer.

## What it looks like in code

Inside `chat()` (`rapp_brainstem/brainstem.py:931-950`), the system prompt teaches the model how to populate the TWIN slot:

> *"Speak FIRST-PERSON as the user, TO the user — one or two short observations, hints, risks, or questions about what was just said. Short is a feature. Silent is allowed — leave empty if there's nothing worth saying. Do NOT re-answer the question. The twin comments ON the turn, it does not replace any part of it."*

Three properties matter:

- **First-person, to the user.** The twin is a model of the user's own thinking, talking *back* to them — not a separate persona, not an "assistant's helper."
- **Silent is allowed.** A turn with nothing useful to add produces an empty twin block. The twin doesn't fill space.
- **Hints, risks, questions — never demands.** The twin can ask a question, but never blocks on the answer. The user can ignore it.

The TWIN slot's tag vocabulary supports the principle directly: `<action kind="send|prompt|open|toggle|highlight|rapp" target="..." label="...">body</action>` — this is *literally* an offer, with a label, that the UI surfaces as a one-click affordance the user can accept or ignore.

## Why this matters

The conventional UX move is to ask first: "What's your name?" "What are your preferences?" "Are you sure?" Each ask scales linearly with attention — every question costs the user a thought. A system that asks for ten things has used the user's first ten attention tokens before delivering any value.

The twin's approach scales with *trust* instead. The twin offers a default; the user lets it stand or corrects it. Each acceptance is a calibration signal (see [[Calibration Is Behavioral, Not Explicit]]) — the twin learns it was right. Each correction is also a calibration signal — the twin learns it was wrong, and adjusts.

A system that learns from acceptances scales sub-linearly: the better the twin gets, the less correction is needed. A system that asks scales linearly forever.

## The rewrite test

Every UI surface in RAPP is checked against the rewrite test:

- **Is there a confirm dialog?** Replace it with: do the action, surface a one-click *undo* in the TWIN slot.
- **Is there a settings page?** Replace it with: track the user's behavior in the binder; the twin's offers update accordingly.
- **Is there an "are you sure?" prompt?** Replace it with: don't ask; do; let the user reverse it after.
- **Is there a wizard / multi-step flow?** Replace it with: produce the artifact with reasonable defaults on the first turn; let the user iterate.

If a screen survives the rewrite test, it stays. If it doesn't, it's a UX failure mode masquerading as a feature.

## What this rules out

- ❌ Modal dialogs that block the conversation. The twin can offer; it cannot block.
- ❌ "Onboarding flows" that ask the user to configure things before doing the work. The work *is* the configuration.
- ❌ Required form fields anywhere except where the *agent's tool schema* demands a parameter the LLM can't infer. Even there, the LLM is supposed to ask in natural language inside the response, not pop a form.
- ❌ "Save your preferences" as a feature. Preferences are emergent from behavior; they are not entered.
- ❌ "Tell me more about yourself" prompts as the first interaction. The first interaction is the user's actual goal; the twin learns from that.

## Where the principle gets violated (and why)

Every constraint has its edge cases. The platform's known violations:

- **Auth flow (`/login`).** The user must explicitly initiate device-code OAuth — the brainstem cannot offer a token without the user's deliberate action. This is correct; auth is one of the few places where the user must *act first*. The discipline is: minimize what counts as auth, don't expand the category.
- **`.env` file.** Configuration of providers, ports, etc. lives in `.env`. This is configuration, not user-facing UX — the user touches it once, before launching. The discipline: don't bring `.env`-style config into the UI.
- **The agent metadata schema.** When an agent's `parameters` schema requires a field, the LLM may need to ask the user for it. This is *correct asking* — the agent's contract demands it. The discipline: don't expand `required` parameters lazily; every required field is a question the user has to answer.

Each of these is a deliberate exception. Adding new exceptions requires the same justification as adding a new top-level slot ([[Voice and Twin Are Forever]]).

## What this enables

When the twin offers and the user accepts, the platform gets:

- **Defaults that improve over time.** Every accepted offer is data; every ignored offer is data; every correction is data. The system tunes itself without a settings page.
- **Surfaces that stay calm.** No modals, no wizards, no required steps. The interface holds still while the conversation runs.
- **Honest calibration signals.** What the user *did* is signal. What they *would have done* on a settings page is hypothesis. The twin acts on the former, not the latter.

## Discipline

- Before adding any UI element that asks for input, write the offer-shaped alternative.
- "Are you sure?" prompts are rejection-shaped UI. Replace them with reversibility (undo) plus telemetry (so the twin learns when the action was unwanted).
- The TWIN slot's `<action>` tag is the canonical offer mechanism. Use it.
- New twin behaviors prove themselves via behavioral signal, not via a feature flag the user toggles.

## Related

- [[Calibration Is Behavioral, Not Explicit]]
- [[Every Twin Surface Is a Calibration Opportunity]]
- [[Voice and Twin Are Forever]]
- [[Engine, Not Experience]]
