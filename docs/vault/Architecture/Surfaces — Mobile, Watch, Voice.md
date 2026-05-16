---
title: Surfaces — Mobile, Watch, Voice
status: published
section: Architecture
hook: Every form factor is a calibration opportunity. Ship them as web tech (PWAs + Apple Shortcuts) — not as native apps you have to maintain across three OSes.
session_id: 63243848-caa9-483c-9a8e-9bb0ee9d2849
session_date: 2026-04-24
---

# Surfaces — Mobile, Watch, Voice

> **Hook.** Every form factor is a calibration opportunity. Ship them as web tech (PWAs + Apple Shortcuts) — not as native apps you have to maintain across three OSes.

## The principle

The brainstem chat surface, the vault wiki, the management UI, the mobile twin — each is a *surface* onto the platform. Constitution Article XXI says every surface is a calibration opportunity. This note extends that idea to *form factor*: a desktop surface, an iPhone surface, an Apple Watch surface, a Siri surface — each gives the twin different signal quality and different intervention shape.

The discipline:

> **Reach new form factors with web tech and OS-native protocols, not native apps. The platform refuses to maintain three desktop binaries and a watchOS bundle for the same chat that already runs in a browser.**

## The surfaces today

| Surface | Where | Tech | Status |
|---|---|---|---|
| Tier 1 chat (desktop) | `rapp_brainstem/web/index.html` | HTML+JS, served by Flask | Installable as PWA (2026-04) |
| Tier 1 chat (mobile) | `rapp_brainstem/web/mobile/` | HTML+JS PWA | Already a PWA |
| Vault wiki | `pages/vault/index.html` | HTML+JS, GitHub Pages | Installable as PWA, offline-readable (2026-04) |
| Tier 1 management | `rapp_brainstem/web/manage.html` | HTML+JS | Browser-only, not yet PWA |
| Tier 3 chat | Microsoft Copilot Studio | Power Platform solution | Lives in customer's tenant |

Three of those are now installable web apps. The fourth (`manage.html`) doesn't need to be — it's a developer surface, not an end-user one.

## Why PWA, not native

The math:

| | Native desktop app | PWA |
|---|---|---|
| OSes covered by one codebase | 1 (typically) | macOS, Windows, Linux, ChromeOS, iOS, Android |
| Code signing | Apple Dev Program + Windows EV cert | None |
| Notarization | Required (macOS) | None |
| App Store review | Yes | No |
| Distribution | App stores or signed installers | Same URL as the website |
| Auto-update | Per-OS infrastructure | Service worker |
| Build infrastructure | Per-OS toolchain | None |
| Audit story | Binary | Same HTML/JS as the website (`curl … \| less`) |
| "Feels native" | Yes | Mostly yes |
| Auto-launch on boot | Yes | No |
| Push notifications | Yes | Yes (modulo iOS) |

Of those rows, only "auto-launch on boot" is a meaningful loss for the platform's user. Everything else either ties (PWA covers it well enough) or wins (the audit + zero upkeep wins are decisive).

## What was shipped (2026-04)

- **`pages/vault/`** — `manifest.webmanifest`, `sw.js`, two SVG icons, iOS meta tags, registration script in `index.html`. The vault is now installable on every modern browser and readable offline. The service worker uses stale-while-revalidate for markdown, so notes stay current online and instant offline.
- **`rapp_brainstem/web/`** — same treatment. The desktop chat surface is now installable. The SW caches the static UI shell only; `/chat`, `/api/*`, `/login`, `/voice/*`, `/twin/*`, `/agents/files`, `/models/*` all pass through to the network so live brainstem behavior never goes stale.
- **`rapp_brainstem/web/mobile/`** — already a PWA. Verified intact.

## Apple Shortcuts as the watchOS / Siri path

The platform's path to Apple Watch and Siri is **Apple Shortcuts**, not a native watchOS app.

Apple Shortcuts is Apple's first-party automation platform. It runs on iOS, iPadOS, macOS, and watchOS. A `.shortcut` file is a JSON-ish bundle that:

- Can make HTTP requests with arbitrary headers and bodies.
- Can prompt the user for input (text, voice via dictation, photos, …).
- Can speak responses aloud via the system TTS.
- Is invocable by Siri voice command (*"Hey Siri, ask Brainstem …"*).
- Runs on Apple Watch through the Watch's Shortcuts app.
- Is distributable as an iCloud share link or as a downloadable file.

The implication: **the brainstem can have an Apple Watch surface and a Siri surface without any native code.** The watch becomes a thin client that POSTs to a configurable brainstem URL (Tier 1 over local network, or Tier 2 cloud over the internet) and speaks the `|||VOICE|||` portion of the response. The user installs the Shortcut once; "Hey Siri, ask Brainstem [thing]" then works on every Apple device they own.

### The protocol a Shortcut needs

A brainstem-compatible Shortcut needs:

- A configurable **endpoint URL** — e.g. `http://192.168.1.42:7071/chat` for Tier 1 on the same Wi-Fi, or a Tier 2 Azure Functions URL for off-network.
- Optional **auth header** — Bearer token for Tier 2; nothing for Tier 1 (which trusts the local network).
- A **POST body** matching the `/chat` request shape: `{"user_input": "<text>", "conversation_history": []}`.
- The **VOICE-aware response handling** — extract the `voice_response` field (or strip everything before `|||VOICE|||` from `response`) and feed it to the system "Speak" action.

The Shortcut does the voice capture (Siri dictation), the round-trip, and the speak-back. The brainstem doesn't change — it already emits a voice slot designed for TTS.

### Distribution

`.shortcut` files can be hosted at GitHub Pages URLs and installed by tap. The platform's distribution path stays consistent with everything else:

- Host the file at `installer/shortcuts/brainstem-voice.shortcut`.
- The README links to `https://kody-w.github.io/RAPP/installer/shortcuts/brainstem-voice.shortcut` with an "Install on iPhone / Watch" CTA.
- Tapping the link opens Shortcuts, asks the user to confirm, prompts for the brainstem URL once, done.

This parallels the install one-liner discipline: one URL, one tap, no app store, no signing.

### What this rules in / out

**Rules in.**
- Apple Watch as a brainstem client (Siri or tap).
- iPhone Siri as a brainstem client.
- Mac via Shortcuts.app.
- Personalization per user (each user installs their Shortcut with their own brainstem URL).

**Rules out.**
- Native watchOS app. A Shortcut + Siri covers the use case at zero maintenance cost. A native app would require an Apple Developer Program enrollment, App Store review, watchOS-specific code, and per-OS-version regression testing.
- Cross-platform "voice agent" claims. Shortcuts is Apple-only. Android's analogue (Tasker, or Google Assistant routines) is its own protocol, with its own .json shape — a separate ship if there's evidence it's worth building.

## iOS Safari quirks

PWAs on iOS Safari are real, but lag desktop browsers in a few places worth knowing:

- **Push notifications** require iOS 16.4+ and only work for installed PWAs (added to home screen). The brainstem doesn't push currently; this is a future surface.
- **Storage limits** are tighter — Safari may evict unused PWA storage after weeks of inactivity. The vault's localStorage cache survives normal use; the export-to-zip path is the durable backup.
- **Service worker scope** is sandboxed per origin/path. The vault SW at `pages/vault/sw.js` only governs `pages/vault/*`; the brainstem SW at `rapp_brainstem/web/sw.js` only governs that path. They never collide.
- **No background sync** on iOS — periodic-fetch and BackgroundSync API are not available. Anything that needs periodic check-in goes through Apple Shortcuts automations (which *do* have time- and location-based triggers) or pushes from a server.

These caveats are why the surfaces story uses *both* PWA *and* Shortcuts — the PWA covers the foreground UI; Shortcuts cover the background / automation / voice triggers that PWAs can't.

## Android

Android Chrome supports PWAs more fully than iOS Safari — push works, install prompts are louder, the install footprint is smaller. The brainstem and vault PWAs work on Android with no changes. Android-specific automation (Tasker, Routines) is parallel to Shortcuts and would be a separate parallel surface if demand emerges; today, Android users use the PWA in the browser or installed from Chrome.

## What this rules out

- ❌ A native cross-platform desktop app (Electron, Tauri-as-real-app). The PWA covers the use case.
- ❌ A watchOS native app. The Shortcut covers it.
- ❌ A platform-specific notification system. PWAs handle web push where it's available; Shortcuts handle iOS automations.
- ❌ Surface-specific protocol shapes. Every surface POSTs to `/chat` and reads the same three-slot response. New surfaces conform; the surfaces don't fork the protocol.

## Discipline

- New form factor → reach for web tech + OS automation primitives first. Native is the last resort.
- Every surface POSTs to the same `/chat` contract. The slot shape (`|||VOICE|||`, `|||TWIN|||`) is what makes voice surfaces possible without protocol changes.
- When tempted to ship a native app for *one* OS, ask whether a PWA + an Apple Shortcut + an Android automation covers 95% of it. Almost always, yes.

## Related

- [[Voice and Twin Are Forever]]
- [[Every Twin Surface Is a Calibration Opportunity]]
- [[The Twin Offers, The User Accepts]]
- [[Why GitHub Pages Is the Distribution Channel]]
- [[Three Tiers, One Model]]
