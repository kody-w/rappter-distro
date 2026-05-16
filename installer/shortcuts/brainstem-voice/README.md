# Brainstem Voice

> **The 5-action Apple Shortcut that turns Siri into a brainstem client.** Watch, iPhone, iPad, Mac, HomePod, CarPlay — every Apple voice surface, one bundle.

## What it does

You say *"Hey Siri, ask Brainstem [thing]"* (or tap the Shortcut). Siri dictates → POSTs to your brainstem's `/chat` endpoint → extracts the `voice_response` field → speaks it aloud. The brainstem already emits a TTS-shaped voice slot designed for exactly this; the Shortcut is just the harness.

## How to install

Two paths, both work:

### Path 1 — iCloud share link (easiest)

1. *(coming once authored)* Tap **`<iCloud share link>`** on iPhone or Mac.
2. Shortcuts.app opens → tap **Add Shortcut**.
3. The first run prompts for your brainstem URL (e.g. `http://192.168.1.42:7071`). Stored once; subsequent runs skip the prompt.
4. Done. Try *"Hey Siri, run Brainstem Voice"*.

### Path 2 — Hosted `.shortcut` file (audit-friendly)

1. *(coming once authored)* Download **`brainstem-voice.shortcut`** from this directory.
2. Open the file on iPhone or Mac → Shortcuts.app prompts to install.
3. Configure brainstem URL on first run.
4. Done.

## How to build it yourself

The `.shortcut` file is not yet checked in (see [the upstream note](#status)). To build it now in 5 minutes:

1. Open **Shortcuts.app** (macOS or iOS).
2. **File → New Shortcut.** Name it `Brainstem Voice`.
3. Add the 5 actions from [`../protocol.md`](../protocol.md):
   1. **Ask for Input** — prompt: *"What do you want to ask?"*, type: Text.
   2. **Get Contents of URL** — `POST` to `{your_brainstem_url}/chat`, header `Content-Type: application/json`, body JSON: `{"user_input": <Provided Input>, "conversation_history": []}`.
   3. **Get Dictionary Value** — key `voice_response`, from *Contents of URL*.
   4. **(Optional) If** *Dictionary Value* is empty → *Get Dictionary Value* with key `response`.
   5. **Speak Text** — text: *Dictionary Value*, voice: system default, *Wait Until Finished* on.
4. Test: tap the play button. Speak. Confirm the response is spoken back.
5. **File → Export…** → save as `brainstem-voice.shortcut` in this directory.
6. Sign for public install: `bash ../sign.sh brainstem-voice.shortcut`
7. Optional: **Share → Copy iCloud Link**, paste in this README under *Path 1*.

## Configuration

The Shortcut prompts once on first run and stores the answer:

| Variable | What | Example |
|---|---|---|
| `brainstem_url` | Your brainstem's HTTP root | `http://192.168.1.42:7071` (Tier 1 same Wi-Fi), `https://brainstem.example.com` (Tier 1 via tunnel), `https://my-rapp-swarm.azurewebsites.net` (Tier 2 cloud) |
| `auth_token` *(optional)* | Bearer token for Tier 2 | empty for Tier 1; required for Tier 2 |
| `voice_mode` *(optional)* | Whether the brainstem emits the voice slot | default true; set false to fall back to the main `response` |

To change later, open the Shortcut in Shortcuts.app and edit the variables directly. The Shortcut respects the new values from the next run onward.

## Compatibility

| Surface | Status | Notes |
|---|---|---|
| **iPhone / iPad** | ✅ | Tap or *"Hey Siri"*. |
| **macOS** | ✅ | Menu bar → Shortcuts. Or global keyboard shortcut. |
| **Apple Watch** | ✅ | Long-press digital crown → Siri → "ask Brainstem [thing]". The Shortcut runs on the Watch directly; the Watch needs a network path to the brainstem (Tier 2 cloud is easiest from a Watch). |
| **HomePod** | ✅ | *"Hey Siri, ask Brainstem [thing]"* — the Shortcut runs on a paired iPhone, the response speaks on the HomePod. |
| **CarPlay** | ✅ | Voice-only via Siri. The same flow. |

## Status

🟡 **Author phase.** The 5-action protocol is locked, the supporting infrastructure (sign script, hosting paths, landing page) is in place. The actual `.shortcut` file is not yet authored — it requires Shortcuts.app on the maintainer's Mac for the initial build + sign + share-link generation. The vault-side reasoning is captured at [`pages/vault/Architecture/Surfaces — Mobile, Watch, Voice.md`](../../../pages/vault/Architecture/Surfaces%20%E2%80%94%20Mobile,%20Watch,%20Voice.md).

When the `.shortcut` file lands here, this README's *Path 1* and *Path 2* sections will be filled in with the actual links.

## Why this matters

A native watchOS app would need:
- An Apple Developer Program enrollment ($99/year).
- App Store review per release.
- watchOS-specific code (a separate Xcode target).
- Per-OS-version regression testing.

This Shortcut needs **none of that**. The brainstem already emits the voice slot. The Shortcut is harness, not product. See [the constitutional posture on form factors](../../../pages/vault/Architecture/Surfaces%20%E2%80%94%20Mobile,%20Watch,%20Voice.md).

## Related

- [`../protocol.md`](../protocol.md) — the 5-action protocol every brainstem-compatible Shortcut implements.
- [`../`](../) — the directory landing page (`installer/shortcuts/index.html`).
- [`pages/vault/Architecture/Surfaces — Mobile, Watch, Voice.md`](../../../pages/vault/Architecture/Surfaces%20%E2%80%94%20Mobile,%20Watch,%20Voice.md) — the vault essay this implements.
- [`pages/vault/Founding Decisions/Voice and Twin Are Forever.md`](../../../pages/vault/Founding%20Decisions/Voice%20and%20Twin%20Are%20Forever.md) — why the voice slot exists.
