---
title: Calibration Is Behavioral, Not Explicit
status: published
section: Twin and UX
hook: A "preferences" page is a failure mode. The twin learns from what you accept, not from what you tick.
---

# Calibration Is Behavioral, Not Explicit

> **Hook.** A "preferences" page is a failure mode. The twin learns from what you accept, not from what you tick.

## The claim

The twin's understanding of the user — what they care about, how they'd phrase things, what they'd ignore, what they'd correct — is **calibrated by behavior**, never by configuration.

The platform refuses to ship a settings page. There is no preferences screen, no profile editor, no "tell me about yourself" form. Every behavioral attribute the twin uses is *inferred from what the user has done*.

## Why explicit calibration fails

Settings pages look reasonable on a feature roadmap and fail in three different ways:

**1 — Users don't update them.** A user fills out preferences once, on day one, when they don't yet know what they actually care about. By month three, their actual usage has diverged from the form they filled out. They never go back to update it. The system is now operating on stale data that the user has no memory of submitting.

**2 — Users misreport themselves.** Asked "do you prefer concise or detailed responses?", users pick "concise" because it sounds professional, then complain that responses are too short. Asked "what's your tone?", they pick whatever phrasing flatters them most. Self-report is famously unreliable as a calibration source.

**3 — The settings page accumulates entropy.** Every time a behavior could be parameterized, someone proposes a setting. Within months, the page has 40 toggles nobody understands and 5 are load-bearing. The team can't remove any of them because some user might have set them. The settings page becomes the API surface, not the behavior.

Behavioral calibration avoids all three. The user can't fail to update something they never set. The system can't be misled by self-report. Entropy accumulates *behaviorally*, in the user's actual interactions — which is the right surface to read from.

## What behavioral calibration looks like

Every interaction with the twin produces signal. The platform captures it in a few specific places:

- **Accepted vs. ignored offers.** When the twin emits an `<action>` tag, the UI surfaces it as a clickable affordance. The user clicks, ignores, or corrects. The signal lands in the binder (`.binder.json`).
- **Probe and calibration tags.** Inside the TWIN slot, the model can emit `<probe id="t-..." subject="..." confidence="0.0-1.0"/>` to flag a claim it's making, and follow it up later with `<calibration id="..." outcome="validated|contradicted|silent" note="..."/>`. The probe is the hypothesis; the calibration is the verdict from a later turn. The platform records both, plus the time gap.
- **Edits to produced artifacts.** When an agent emits a draft and the user edits it, the diff is the calibration signal. What the user kept, the twin had right; what they changed, the twin missed.
- **Tool selection patterns.** When the LLM offers a tool and the user redirects to a different one ("no, use the other agent"), that redirection is a signal that the agent metadata is mis-cued.

None of these requires the user to "configure" anything. They're emitted by the act of using the system.

## How the twin uses the signal

Behavioral signal lands in three places:

- **The binder** (`.binder.json`) — short-term, per-session state about what the twin is currently betting on. Read every turn into the twin's prompt context.
- **The twin calibration log** (`.twin_calibration.jsonl`) — append-only log of probe/calibration pairs. Used to score the twin's accuracy over time and to surface specific mis-calibrations the twin should retract.
- **Memory** (`agents/manage_memory_agent.py` + `agents/context_memory_agent.py`) — long-term facts the twin has learned about the user, injected into the system prompt by `context_memory_agent.system_context()`.

None of these is editable through a UI. They are read-only side effects of conversation. The user changes them by *doing different things*, not by ticking different boxes.

## What this rules out

- ❌ A `/settings` route, a settings panel, a preferences flow — for any property that could be inferred from behavior.
- ❌ Asking the user to choose a "tone" or a "style." Tone is something the twin learns from how the user writes, not from how they self-describe.
- ❌ A "personality" picker. The twin's personality is calibrated; it isn't selected.
- ❌ Default-overrides exposed as toggles. If a default is wrong for a particular user, behavior reveals that within a few turns; the twin updates accordingly. A toggle creates two failure modes (forgotten toggle + missing behavioral update) where there was one.
- ❌ "Apply preferences globally" — the kind of feature that suggests preferences should be portable across apps. They aren't; they're context-dependent and emergent.

## Where explicit input *is* allowed

The discipline has bounded exceptions:

- **Identity / connector setup.** OAuth flows, API key entry, tenant connection — these are auth, not preference. They are explicit because the user cannot be auto-detected.
- **One-time questions the agent's contract requires.** If a `manage_memory_agent` call requires `memory_type ∈ {fact, preference, insight, task}` and the LLM can't infer it, the agent will (in natural language) ask. That ask is part of the *agent's contract*, not a settings page.
- **Voice/Twin master toggles.** `VOICE_MODE` and `TWIN_MODE` (env-var-controlled) are explicit *because they're slot enablement*, not behavioral preferences. They turn capabilities on/off; they don't try to encode user behavior.

Each exception is bounded and named. The discipline is: don't grow the exceptions; don't pretend a preference is auth.

## What this enables

When the twin learns from behavior, the platform gets:

- **A user model that's always current.** No staleness, because the data is fresh by definition.
- **A calmer interface.** No settings page = no entropy on the surface. The product stays small.
- **Honest performance metrics.** "Did the twin's offer get accepted?" is measurable; "did the user prefer this?" (asked on a survey) is not.
- **Per-user adaptation without per-user code.** The same brainstem code serves every user; each user's binder differs; the twin's behavior differs accordingly.

## Discipline

- Before adding any "configure your X" feature, write down the behavioral signal that would let the system learn the same thing automatically. Then ship the latter.
- When tempted to expose a preference as a setting, ask: *will this preference change as the user changes? does the user know what they prefer? does the team trust their answer?* If any answer is "no," the setting is wrong.
- Calibration logs are not for the user to read directly. They are for the twin to use. UI surfacing is the twin's *offers*, not its *internal state*.

## Related

- [[The Twin Offers, The User Accepts]]
- [[Every Twin Surface Is a Calibration Opportunity]]
- [[Voice and Twin Are Forever]]
- [[Engine, Not Experience]]
