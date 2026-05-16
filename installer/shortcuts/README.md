# installer/shortcuts/

Apple Shortcuts that turn the brainstem into a voice / wrist / Siri client. **Zero native code, zero App Store, zero per-OS regression** — see [`pages/vault/Architecture/Surfaces — Mobile, Watch, Voice.md`](../../pages/vault/Architecture/Surfaces%20%E2%80%94%20Mobile,%20Watch,%20Voice.md) for the full reasoning.

## What's in here

| Path | What |
|---|---|
| `index.html` | Landing page listing all brainstem-compatible Shortcuts. Served at `https://kody-w.github.io/RAPP/installer/shortcuts/`. |
| `protocol.md` | The protocol every brainstem-compatible Shortcut implements. POST shape, voice-slot extraction, auth header conventions. |
| `sign.sh` | Wrapper around `shortcuts sign --mode anyone` so authored `.shortcut` files become installable by anyone (not just *people-who-know-me*). |
| `brainstem-voice/` | First shortcut. Siri / Watch / iPhone client that asks the brainstem questions and speaks the answer. |

## How to author a new Shortcut

1. Open `Shortcuts.app` on macOS or iOS.
2. **File → New Shortcut.** Name it.
3. Add the actions documented in [`protocol.md`](protocol.md) — at minimum: get input, POST to brainstem `/chat`, extract `voice_response`, speak the result.
4. Test it: tap the play button. Say something. Confirm the response is spoken.
5. **File → Export…** → save as `<name>.shortcut`.
6. From the repo root: `bash installer/shortcuts/sign.sh <name>.shortcut` to sign it for anyone (otherwise only people who know your iCloud account can install it).
7. Drop the signed file into a new `installer/shortcuts/<name>/` subdirectory alongside its own `README.md` describing what it does, its config knobs, and which devices it supports.
8. Add it to the table in `index.html`.

## How to install a Shortcut on your devices

For each Shortcut subdirectory, the `README.md` includes:
- The iCloud share link (if the author published one).
- A direct download link to the signed `.shortcut` file.
- Configuration notes (brainstem URL, optional auth header, voice mode).

Tap the iCloud link or open the `.shortcut` file on iOS/macOS and Shortcuts.app prompts to install.

## Why Shortcuts and not a native app

Shortcuts gives the brainstem an Apple Watch surface, a Siri surface, an iPhone surface, an iPad surface, and a Mac surface — all from one bundle, with zero code signing, zero App Store review, and zero per-OS-version regression testing. The protocol stays the same as the brainstem's HTTP `/chat` contract, so no changes to the brainstem are ever required. See the [Surfaces vault note](../../pages/vault/Architecture/Surfaces%20%E2%80%94%20Mobile,%20Watch,%20Voice.md) for the full argument.

## MCP integration (optional)

If you use Claude Code or Claude Desktop and want to interact with these Shortcuts from chat (run them, list them, verify a build), install the [`mcp-server-apple-shortcuts`](https://github.com/recursechat/mcp-server-apple-shortcuts):

```bash
claude mcp add apple-shortcuts -- npx -y mcp-server-apple-shortcuts
```

That gives Claude three tools: `list_shortcuts`, `run_shortcut`, `view_shortcut`. Useful for verifying a freshly-built Shortcut without leaving chat.

**What it doesn't do.** No MCP can *create* shortcuts. The underlying macOS `shortcuts` CLI only supports `run` / `list` / `view` / `sign` — Apple doesn't expose authoring programmatically, and the `.shortcut` file format is undocumented. Authoring stays a Shortcuts.app GUI exercise (5 minutes per shortcut). The MCP is for everything *after* authoring.

## Related

- [`installer/`](../) — the platform's public install surface (one-liners, ARM templates, Tier 3 bundle).
- [`installer/automations/android/`](../automations/android/) — *(planned)* the parallel surface for Android Tasker / Google Assistant routines.
- [`pages/docs/skill.md`](../../pages/docs/skill.md) — the AI-readable agent skill protocol.
