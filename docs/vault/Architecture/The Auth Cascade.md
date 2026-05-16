---
title: The Auth Cascade
status: published
section: Architecture
hook: GITHUB_TOKEN env → .copilot_token file → gh auth token CLI. Three steps, three personas, no silent prompts.
---

# The Auth Cascade

> **Hook.** `GITHUB_TOKEN` env → `.copilot_token` file → `gh auth token` CLI. Three steps, three personas, no silent prompts.

## The cascade

Tier 1's default LLM provider is the GitHub Copilot API, which requires a GitHub token that has Copilot access. Acquiring that token is a chain (`rapp_brainstem/brainstem.py:183-310`):

```
get_github_token():
  1. Read os.environ["GITHUB_TOKEN"]            # CI / explicit
  2. If empty, read .copilot_token file         # device-code OAuth
  3. If empty, shell out to `gh auth token`     # local dev
  4. If still empty, raise — no auth available
```

The GitHub token is then exchanged for a short-lived **Copilot API token** (`brainstem.py:292` `_exchange_github_for_copilot()`), which is cached in `.copilot_session` with auto-refresh on expiry.

Two tokens, three sources for the first, one source for the second.

## Why three sources for the GitHub token

Each step serves a specific persona. The order is the order of "least magic to most magic."

**Step 1 — `GITHUB_TOKEN` env var.** This is the explicit path. If the variable is set, the brainstem uses it without questioning. The persona is *automation*: CI pipelines, scripted deploys, container images. Setting the env var is the deliberate "I know what I'm doing" signal.

**Step 2 — `.copilot_token` file.** The brainstem can complete a device-code OAuth flow from `/login` (`brainstem.py:431` `start_device_code_login()`). The user opens a browser, enters a code shown by the brainstem, GitHub returns a token, the brainstem writes it to `.copilot_token`. Subsequent runs read it back. The persona is *long-running local installation*: the user did OAuth once, the token persists across reboots until revoked.

**Step 3 — `gh auth token` CLI.** If neither of the above is available, the brainstem shells out to GitHub's CLI to ask for the token the CLI is already managing. The persona is *local developer with `gh` installed*: they're already authenticated, they don't want to do it twice. This step is last because shelling out to a CLI is the most magical of the three — it works only if the CLI is installed, only if the user is already logged in, and only if the token has Copilot scope. The user sees the magic when it works; they get a clear failure when it doesn't.

If all three fail, the brainstem returns a clean "no auth" error. **No silent prompts. No browser pop-ups without explicit user action.** Every step is observable.

## Why this order

The order is not arbitrary. It encodes priority:

- **Explicit beats implicit.** If both an env var and a CLI token exist, the env var wins. This means a user can override the CLI for a specific run without uninstalling anything.
- **Persistent beats ephemeral.** The `.copilot_token` file is checked before `gh auth token` because it's the brainstem's *own* OAuth state — the user signed in to the brainstem, not to a separate tool.
- **Last-resort is most magical.** `gh auth token` is the friendliest path for someone who already has `gh` set up, and the most surprising path for someone who doesn't. So it goes last, where it can save effort without being the default.

Reordering would change behavior in ways the user can't predict. The current order is an explicit choice each time.

## The Copilot token exchange

Once a GitHub token is in hand, the brainstem exchanges it for a short-lived Copilot API token (`brainstem.py:292`). This is the actual credential used to call `https://api.githubcopilot.com/...`. Three properties matter:

- **Short-lived.** Copilot tokens expire in minutes, not hours. The cache in `.copilot_session` stores the token, the endpoint, and the expiry timestamp.
- **Cached.** Without the cache, every chat request would do a token exchange first. The cache makes the brainstem cold-start path one HTTP call (the actual chat) instead of two (exchange + chat).
- **Auto-refreshed.** When the cache shows the token is within a refresh window of expiry, the next request triggers `_exchange_github_for_copilot()` again before the chat call. The user sees no interruption.

This second-level caching is invisible to the rest of the platform; agents and the chat loop never see the Copilot token directly. They go through `call_copilot()` at `brainstem.py:786`, which handles the token lifecycle internally.

## Why no provider also gets a cascade

The other providers (Azure OpenAI, OpenAI, Anthropic — see `utils/llm.py`) have a flat config: env vars or nothing. Why is GitHub special?

Because GitHub's OAuth + Copilot exchange is the only provider whose *acquisition* is a multi-step process the brainstem can usefully assist with. Azure OpenAI keys come from a portal; OpenAI keys come from a dashboard; Anthropic keys come from a console. The brainstem cannot simplify any of those — the user pastes the key into `.env` and that's the end of the story.

GitHub is different because Copilot access is gated by *user identity*, not by a key. The OAuth flow can be initiated and completed without ever leaving the brainstem. So the cascade exists.

## What this rules out

- ❌ Adding a fourth source to the cascade ("read this file too"). Each new source is a guessing game for the user. Three is the limit.
- ❌ Browser pop-ups outside the explicit `/login` flow. The brainstem never opens a browser unless the user asked it to.
- ❌ Provider-specific cascades for non-GitHub providers. The other providers are key-based; multi-step acquisition is wasted complexity.
- ❌ Hiding which step succeeded. The brainstem logs which source produced the token (`telemetry.jsonl` records this); the user can audit the chain after the fact.

## When to reconsider

The cascade would need a fourth source if Microsoft Entra ID or a similar identity provider became a primary auth path. The shape would be similar — explicit credential first, persisted token second, CLI fallback third — but with a different vocabulary.

The cascade would *not* be reconsidered for "convenience" reasons (e.g., "let's auto-detect from a .ssh key"). Convenience is the failure mode this design avoids.

## Discipline

- New auth paths are added with a clear persona: who is the user that this path serves, and what do the existing paths fail to do for them?
- The order of the cascade is documented behavior; reordering breaks user expectations and is treated as a breaking change.
- The Copilot token exchange's caching is an implementation detail; if it ever needs to surface to the user, it's because something is broken.

## Related

- [[The Deterministic Fake LLM]]
- [[Local Storage Shim via sys.modules]]
- [[Why GitHub Pages Is the Distribution Channel]]
- [[Three Tiers, One Model]]
