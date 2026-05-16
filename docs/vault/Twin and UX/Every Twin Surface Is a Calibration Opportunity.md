---
title: Every Twin Surface Is a Calibration Opportunity
status: published
section: Twin and UX
hook: Help-shaped UI is wrong. Calibration-shaped UI is right. If a surface only flows information one way, it's the wrong shape.
---

# Every Twin Surface Is a Calibration Opportunity

> **Hook.** Help-shaped UI is wrong. Calibration-shaped UI is right. If a surface only flows information one way, it's the wrong shape.

## The inversion

The conventional view of a UI surface: *this is where the user gets help / sees information / completes a task.* The flow is one-directional: system → user.

RAPP inverts this. Every UI surface is a place where **the twin gets feedback**. Information flows the other way: user → system. The user's act of using the surface — clicking, ignoring, editing, redirecting — *is* the calibration signal.

> **A surface that only flows information system → user is the wrong shape.**

This isn't a stylistic preference. It is the test that determines whether a surface deserves to ship.

## The rewrite test

For every proposed UI surface, the question is:

1. **Where does the user say "yes," "no," or "close, but…"?**
2. **What does the system *do differently* tomorrow because of what the user did today?**

If either answer is "nowhere" or "nothing," the surface is help-shaped, not calibration-shaped. Either rewrite it or kill it.

## Worked examples

**The chat input.** The user types; the system responds. So far help-shaped. *But*: the user's next turn either accepts the response (silence on the topic, builds on it) or corrects it (rephrases, asks again, edits). Both are calibration signal. The twin's `<probe>` / `<calibration>` tags exist to capture exactly this — the twin *names* what it thinks is happening, and a later turn judges it. **Verdict: calibration-shaped.**

**The agent log panel.** Shows tool calls and their results. So far help-shaped — read-only telemetry. The platform's discipline turns this into calibration: an agent log entry can be reordered, retried, or marked as wrong. The user's interactions with the log feed back into agent metadata refinement. **Verdict: calibration-shaped — only after the affordances are there.**

**The live index card.** The agent emits a card at every step (commit `dd1434b`, `f397b67`). The user reads, edits, opens the underlying artifact, dismisses the card. Each interaction is signal. The card is not just "showing what the agent did"; it's *asking whether the agent is doing it right*. **Verdict: calibration-shaped by design.**

**A "release notes" panel.** Shows what's new. Read-only. The user reads or doesn't. **Verdict: help-shaped → kill it or replace it with offers ("would you like to use the new X?") that the user can take or ignore.**

**A "documentation" page.** Read-only by definition. **Verdict: help-shaped, but acceptable** — documentation is one of the few legitimate help-shaped surfaces, because the alternative (no documentation) is worse. The discipline: documentation lives in `pages/docs/` and `vault/`, not inside the product surface, and no other panel may inherit its read-only character without justification.

## Why this matters

A platform whose surfaces are help-shaped scales by adding more surfaces. Each surface is a static information flow; nothing the user does on one surface improves any other. The product gets bigger but not better.

A platform whose surfaces are calibration-shaped scales by *learning*. Each surface produces signal; the twin's offers improve everywhere; users see better defaults across the board. The product gets smaller (because individual surfaces don't have to expose every option — the twin will eventually offer the right one) and better (because every interaction makes future interactions sharper).

The asymmetry compounds. The longer a calibration-shaped product runs, the more advantage it has over a help-shaped equivalent.

## The vocabulary that enables it

The TWIN slot's tag vocabulary (see `brainstem.py:938-950`) is specifically built for calibration:

- **`<probe id="t-..." kind="..." subject="..." confidence="0.0-1.0"/>`** — *"I am betting that X."* The probe names a hypothesis the twin can be wrong about.
- **`<calibration id="<probe-id>" outcome="validated|contradicted|silent" note="..."/>`** — *"My earlier bet at id X was right / wrong / unclear."* The calibration closes the loop on a prior probe.
- **`<action kind="send|prompt|open|toggle|highlight|rapp" target="..." label="...">body</action>`** — *"Here's a one-click favor. Take it or leave it."* The action is an offer; user response is signal.
- **`<telemetry>one fact per line</telemetry>`** — server-log-only signal that doesn't appear in the UI but feeds the twin's longer-term tuning.

These tags are the calibration protocol. Every twin-emitting surface should be using at least one of them. A surface that emits twin content with no tags is missing its calibration affordances.

## What this rules out

- ❌ Read-only dashboards. If the dashboard's job is to "let users see," it's help-shaped. Either remove or add affordances.
- ❌ FYI banners ("we updated something"). FYI is help-shaped. Replace with: an `<action>` tag offering the new capability.
- ❌ Status pages without action affordances. The user's response to "your job is running" should be takeable somewhere.
- ❌ Agent output that doesn't come with a way to say "no, redo this." The redo affordance *is* the calibration.
- ❌ "Power user" panels behind a flag, full of read-only data. If it's worth showing, it's worth being calibration-shaped.

## When help-shaped is OK

The discipline is not absolute. Some surfaces are legitimately help-shaped:

- **Documentation** (the vault, README files, generated reference). Lives outside the product loop.
- **Canonical artifact viewers** (rendering a generated HTML deck, e.g.). The user's calibration happens *upstream* in the conversation, not on the artifact itself.
- **The login screen.** Auth is explicit by necessity (see [[The Twin Offers, The User Accepts]]).

Each is a bounded exception. Surfaces that try to claim "documentation" status to avoid the rewrite test are the failure mode this rule defends against.

## What this enables

When every twin-emitting surface is calibration-shaped, the platform gets:

- **A consistent user model across surfaces.** The chat, the index card, the agent log — all feed the same binder, all benefit from the same calibration.
- **Surfaces that age well.** The chat from version 1 keeps working in version 10 because the calibration vocabulary hasn't changed; only what the twin offers has.
- **A product whose UX scales with use.** First conversation is generic; tenth conversation is honed; hundredth conversation feels like the system reads minds — without any "personalization" feature ever shipping.

## Discipline

- Every new UI surface answers two questions on the PR: *what does the user say with this?* and *what changes for the twin tomorrow?*
- Every twin-emitting endpoint uses tags. Untagged twin output is the smell that calibration was forgotten.
- "Show the user X" is half a feature. The other half is "and let them tell us whether X was right."

## Related

- [[The Twin Offers, The User Accepts]]
- [[Calibration Is Behavioral, Not Explicit]]
- [[Voice and Twin Are Forever]]
- [[Engine, Not Experience]]
