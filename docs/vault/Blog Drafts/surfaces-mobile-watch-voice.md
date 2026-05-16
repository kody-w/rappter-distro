---
title: Surfaces — mobile, watch, voice. Where the same agent travels next.
status: shipped
published_url: https://kody-w.github.io/2026/04/24/surfaces-mobile-watch-voice/
section: Blog Drafts
hook: A single Python file is the agent. It runs on a laptop today. The same file should run on a phone, on a watch, in voice — without rewriting. What it would take, and what we won't bend to get there.
date: 2026-04-24
sources:
  - "[[Surfaces — Mobile, Watch, Voice]]"
class: semi-evergreen
decay: medium
---

# Surfaces — mobile, watch, voice. Where the same agent travels next.

The platform's design contract is that one Python file is the agent, and that file runs unmodified on three tiers: a local Flask brainstem, an Azure Functions deployment, and a Microsoft Copilot Studio harness. Same file, three runtimes. The portability is load-bearing.

What's beyond Tier 3? The natural answer — and the one we keep getting asked — is *"can it run on my phone? On my watch? Through Siri?"* The honest answer is: yes, with discipline, and only if the discipline holds.

This post is about what that discipline looks like.

## The portability promise, restated

The single-file agent contract is precise:

- One file named `*_agent.py`.
- A class extending `BasicAgent`.
- `self.name`, `self.metadata` (an OpenAI-style function-calling schema), and `self.perform(**kwargs) -> str`.

That's the surface. Anything inside the file is up to the author — file I/O, HTTP calls, Python libraries, even shelling out. Freedom inside; discipline at the boundary. The runtime adapts to the agent, not the other way around.

The bet new surfaces will have to win is whether they can host this contract without forcing the agent to change. If a "mobile RAPP" requires every agent to declare its iOS-compatible subset, the bet is broken — agents stop being portable, and the whole platform's value collapses.

## What "mobile" would mean

The honest answer for iOS and Android is that you can't run arbitrary Python in the user's pocket without choosing one of three architectures, each with tradeoffs:

**Architecture A — PWA shell talking to a remote brainstem.** The phone is a browser. The agents run on the user's laptop, on Tier 2 cloud, or on a relay. The phone is just the chat surface. The single-file contract is preserved exactly because the agents never leave the trusted runtime. Cost: the agents need network reach to wherever the runtime lives.

**Architecture B — local Python via embedded interpreter.** Pythonista, Pyto, BeeWare. Agents would run locally on the device. This *technically* preserves the contract but introduces fragmentation: which Python version, which library subset, which IO permissions. The dependency declaration `# requires: foo` (which the desktop runtime auto-installs) becomes "foo, but only if the embedded interpreter knows it." That's a leak the contract can't tolerate.

**Architecture C — agent transpilation.** Source-to-source translate the Python file into something the device can run (Swift, Kotlin, Wasm). This breaks the contract immediately — *the file you ship is not the file that runs*. The point of single-file agents is that the file IS the agent IS the documentation IS the contract. A transpiled artifact is none of those.

The platform's bet for mobile is **A**. The phone is a *thin* surface that talks to a *real* brainstem. The PWA already exists in the project's history (the browser-only brainstem is shipped, with bring-your-own API key). On a phone, the browser-only mode plus a remote brainstem option covers the use cases without breaking anything.

## What "watch" would mean

A watch is more constrained still. No keyboard, small screen, intermittent connectivity. The interaction shape isn't *"chat with an agent"* — it's *"glance at a digit, accept a suggestion, swipe to next."*

The Twin pattern in the platform's UX vocabulary anticipates this. The `|||TWIN|||` slot in every agent response carries calibration-shaped content — short predictions about the user, with action chips that fire on tap. *"You said you'd reply to Jordan today — send the draft?"* On a phone, that's a notification. On a watch, that's a glance + tap. Same payload, different surface.

The watch surface doesn't run agents. It renders Twin output and round-trips taps back to the brainstem. The agent file doesn't change; the rendering layer does. The single-file contract holds because the watch is upstream of the contract — it's a face on the runtime, not a runtime variant.

The Apple Shortcuts integration that's on the roadmap is this in concrete form: a Shortcut talks to the local brainstem on the user's network, sends voice or tap input, renders the response. Agents don't know they're being invoked from a watch. They emit `|||TWIN|||` chips, and the Shortcut renders them as a glance.

## What "voice" would mean

Voice is interesting because the contract already has the slot. `|||VOICE|||` was the *first* delimited output slot the platform added — months before `|||TWIN|||`. Agents that want to "speak" the result emit a TTS-friendly version inside that slot, and the runtime ships it to whatever speaker is listening.

The voice surface — Siri, Alexa, Google Assistant, any AT-friendly screen reader — consumes `|||VOICE|||` directly. The agent doesn't have to know which voice surface it's reaching. The runtime translates between the surface's wakeword/intent system and the agent's tool-call format.

The discipline this requires:

- `|||VOICE|||` stays *only* a TTS line. Never a "short summary" or a fallback. If voice grows new affordances (whispered context, speed cues, emotion tags), they live as XML-style tags inside the slot. The slot itself is fixed forever.
- Voice surfaces don't get to introduce new agent contracts. If an agent works on a desktop chat, it works through voice. If it doesn't translate well, that's a content problem (the agent is producing something a voice user can't consume), not a runtime problem.
- The Copilot Studio harness, which already speaks through Microsoft's voice products, is the proof point: agents authored locally, deployed to Studio, voice-rendered through Microsoft's stack — all without the agent file knowing.

## What we will NOT bend to get there

Three commitments that the surface expansion has to honor:

1. **Single-file agents stay single-file.** No "manifest your agent for iOS." No "declare your watch-compat subset." If the file you ship to a teammate doesn't run unchanged on every supported surface, the surface failed the test, not the file.

2. **Slots stay fixed.** `|||VOICE|||` and `|||TWIN|||` are the canonical output slots. New surfaces use existing slots or new sub-tags inside them. A new surface does not earn a new top-level slot just because the surface is new — that bar is reserved for fundamentally new real estate the existing slots cannot serve.

3. **Tier portability remains the contract.** An agent runs unchanged across Tier 1 (local), Tier 2 (cloud), and Tier 3 (Copilot Studio). Mobile/watch/voice surfaces are above Tier 3 in the stack — they consume the same agent output. They don't define a new tier with new rules.

These three commitments are the whole reason a watch port doesn't fragment the platform. The agent file is the constant. Surfaces are the variable. Anything that flips that relationship is rejected, no matter how nice the demo looks.

## When a surface earns its place

The platform doesn't add surfaces for completeness. A surface earns inclusion when:

- An agent worth running has a use case the existing surfaces can't reach (a worker's hands are full, the user is mid-stride, the screen is unavailable).
- The surface can be reached *without changing the agent contract.*
- A demo path exists that takes a working desktop agent and shows it running on the new surface without modification.

When those three conditions hold, the surface is a thin renderer over a runtime that already exists. When they don't, the surface is a request to fragment the platform — and the answer is no, even if the demo would be impressive.

## Receipts

- The slot contract: `CONSTITUTION.md` Articles I and II in [github.com/kody-w/RAPP](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md).
- The portability guarantee: Article III.3.
- The vault note: [[Surfaces — Mobile, Watch, Voice]] under `pages/vault/Architecture/`.
- The browser-only brainstem (Architecture A demonstrated): `rapp_brainstem/web/index.html`.

The platform's working knowledge: *new surfaces are renderers, not runtimes.* The agent file is the constant. Surfaces argue at the boundary. The contract holds.
