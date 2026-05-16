# Brainstem-Compatible Shortcut Protocol

Every Shortcut in this directory implements the same protocol so that a Shortcut authored against one brainstem works against any brainstem (Tier 1 local, Tier 2 cloud, Tier 3 Copilot Studio behind the worker).

## The contract

A brainstem-compatible Shortcut does five things, in this order:

1. **Get user input.** Either via Siri dictation, the *Ask for Input* action, or the Shortcut's input parameter (when triggered from Watch / Share Sheet).
2. **POST to the brainstem `/chat` endpoint** with the input as the `user_input` field of a JSON body.
3. **Parse the response** as a dictionary.
4. **Extract the voice slot** — either the `voice_response` field directly, or strip everything before `|||VOICE|||` from the `response` field.
5. **Speak the result** via the *Speak Text* action.

That's the whole thing.

## The HTTP shape

### Request

```http
POST {brainstem_url}/chat
Content-Type: application/json
Authorization: Bearer {token}        # optional; required for Tier 2 cloud

{
  "user_input": "<the user's question>",
  "conversation_history": [],
  "session_id": "<optional UUID for multi-turn>"
}
```

### Response

```json
{
  "response": "<main response>",
  "voice_response": "<TTS-ready, 2-3 sentences>",
  "twin_response": "<digital-twin reaction; usually empty for voice surfaces>",
  "agent_logs": "<one tool call per line>",
  "voice_mode": true,
  "twin_mode": false,
  "session_id": "<UUID for follow-ups>"
}
```

The Shortcut feeds `voice_response` to *Speak Text*. It can ignore the rest.

### Why the voice slot

The brainstem emits the voice slot specifically so TTS surfaces don't have to summarize. The main `response` is shaped for visual scanning (markdown, lists, code) — hostile when spoken aloud. The voice slot is shaped for the listener. See the vault's [Voice and Twin Are Forever](../../pages/vault/Founding%20Decisions/Voice%20and%20Twin%20Are%20Forever.md) for why this slot is sacred.

## Required configuration

Every Shortcut prompts the user **once** for the brainstem URL on first run, then stores it as a Shortcut variable. Subsequent runs skip the prompt.

Two URL shapes the user might enter:

| Where the brainstem lives | Example URL |
|---|---|
| Tier 1, same Wi-Fi network | `http://192.168.1.42:7071` |
| Tier 1 via a tunnel (Tailscale, ngrok, Cloudflare) | `https://my-brainstem.example.com` |
| Tier 2 cloud | `https://my-rapp-swarm.azurewebsites.net` |

For Tier 2, the Shortcut also asks once for an auth token and stores it.

## The actions, in order

Build these in `Shortcuts.app` on macOS or iOS:

### 1. *Ask for Input*

- **Prompt:** "What do you want to ask?"
- **Input Type:** Text
- (When triggered from Siri or Watch, this becomes the dictation prompt automatically.)

### 2. *Get Contents of URL*

- **URL:** the brainstem URL stored in the variable, with `/chat` appended.
- **Method:** `POST`
- **Headers:**
  - `Content-Type: application/json`
  - (Tier 2 only) `Authorization: Bearer <stored token>`
- **Request Body:** JSON
  - `user_input`: *Provided Input* (from action 1)
  - `conversation_history`: empty list `[]`

### 3. *Get Dictionary Value*

- **Get:** Value
- **Key:** `voice_response`
- **From:** *Contents of URL* (the response from action 2)

### 4. *If* (fallback when `voice_response` is empty)

The brainstem returns an empty `voice_response` when voice mode is off. Fall back to the main `response`:

- **If** *Dictionary Value* is empty:
  - *Get Dictionary Value* with key `response` from the same source.

### 5. *Speak Text*

- **Text:** *Dictionary Value* (the result of action 3 or 4)
- **Voice:** system default
- **Wait Until Finished:** ✅ (so the Shortcut doesn't end before the speech does)

That's the whole Shortcut. Five actions; one optional `If` branch.

## Optional polish

- **Show conversation in a notification** when running on iPhone (not Watch) — *Show Notification* action with the response.
- **Save the conversation** to a Note for later — *Append to Note* action.
- **Surface the agent log** if the user wants to see which agents fired — *Show Result* with `agent_logs`.

These are nice-to-have. The 5-action core is the entire required protocol.

## Triggering surfaces

Once authored, the Shortcut is invocable from every Apple surface:

| Surface | How |
|---|---|
| **iPhone / iPad** | Tap in Shortcuts.app, or "Hey Siri, run *Brainstem Voice*". |
| **Apple Watch** | Long-press digital crown → Siri → "ask Brainstem". Or open Shortcuts on Watch. |
| **macOS** | Menu bar → Shortcuts → run by name. Or via global keyboard shortcut. |
| **HomePod** | "Hey Siri, ask Brainstem [thing]" — runs the Shortcut on a paired iPhone, speaks the result on the HomePod. |
| **CarPlay** | Voice-only via Siri. |

The surfaces inherit the protocol. No per-surface code.

## Naming convention

Shortcut names should be invocable by Siri without ambiguity. *Ask Brainstem*, *Brainstem Voice*, *Quick Ask* — short, unambiguous, no symbols.

The corresponding subdirectory in `installer/shortcuts/` uses kebab-case: `brainstem-voice/`, `quick-ask/`.

## Signing

By default, Shortcuts.app exports `.shortcut` files signed for *people who know me* (only installable by people in your iCloud contacts, basically). To make a Shortcut installable by anyone, run:

```bash
bash installer/shortcuts/sign.sh <input>.shortcut <output>.shortcut
```

…which wraps `shortcuts sign --mode anyone`.

## Distribution

Two equally valid paths:

1. **iCloud share link.** Shortcuts.app → Share → *Copy iCloud Link*. Paste in the Shortcut's `README.md`. Users tap the link → Shortcuts opens → Install. Easiest path for users.
2. **Hosted `.shortcut` file.** Drop the signed file into the Shortcut's subdirectory. Users tap the GitHub Pages URL (`https://kody-w.github.io/RAPP/installer/shortcuts/<name>/<name>.shortcut`) → Shortcuts opens → Install. Audit-friendly path.

Both are documented in each Shortcut's `README.md`. Most Shortcuts ship with both.

## Related

- [`README.md`](README.md) — the directory overview and authoring workflow.
- [`brainstem-voice/`](brainstem-voice/) — the canonical first-shortcut implementation.
- [`pages/vault/Architecture/Surfaces — Mobile, Watch, Voice.md`](../../pages/vault/Architecture/Surfaces%20%E2%80%94%20Mobile,%20Watch,%20Voice.md) — the constitutional posture on form factors.
- [`pages/vault/Founding Decisions/Voice and Twin Are Forever.md`](../../pages/vault/Founding%20Decisions/Voice%20and%20Twin%20Are%20Forever.md) — why the voice slot exists.
