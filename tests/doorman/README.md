# tests/doorman — headless-browser harness for the planted vbrainstems

A small Playwright wrapper that drives the doorman pages exactly the way a
phone or laptop visitor's browser would — same OAuth flow (or pre-seeded
token to skip it), same Pyodide load, same tool-calling, same memory
tiers. Lets you talk to any planted seed from the command line and chain
into automated test loops.

## Setup (one-time)

```bash
cd tests/doorman
npm install
# Playwright's chromium binary is downloaded on first install. If you
# already have one cached at ~/Library/Caches/ms-playwright/, the install
# reuses it.
```

## Talking to a doorman

```bash
# Authed — uses your `gh auth token` to skip the OAuth flow:
node chat.js https://kody-w.github.io/heimdall/doorman/ \
    --token=auto "I am a traveler. Who are you?"

# Authed against your own twin (ascended path lights up automatically
# because your token has read access to kody-w/twin-private):
node chat.js https://kody-w.github.io/kody-twin/doorman/ \
    --token=auto "What's in your private brain?"

# Anonymous — see the welcome state without sending a message:
node chat.js https://kody-w.github.io/heimdall/doorman/

# Watch the browser yourself + leave it open afterward:
node chat.js https://kody-w.github.io/heimdall/doorman/ \
    --token=auto --headed --keep-open "show me your hand"

# Verbose — pipes browser console + page errors to stderr:
node chat.js https://kody-w.github.io/heimdall/doorman/ \
    --token=auto --verbose "test"
```

Output is the conversation: `=== you ===` / assistant reply / a `=== system trace ===`
section that captures tool calls, memory saves, and agent loads when they
fire mid-turn.

### `chat.js` options

| Flag | Meaning |
|---|---|
| `--token=auto` | Use `gh auth token` (same scope as signing in via OAuth on the doorman). |
| `--token=<value>` | Provide a token explicitly. |
| (no `--token`) | Run anonymous — welcome state only, no chat. |
| `--headed` | Show the browser window. Default is headless. |
| `--keep-open` | Don't close the browser after the reply. Useful with `--headed`. |
| `--verbose` | Stream browser console + errors to stderr. |
| `--slow` | Add 100ms delay per Playwright action. Useful with `--headed`. |
| `--timeout=<s>` | Override the assistant-reply timeout (default 60s). |

## Smoke-testing the fleet

```bash
# All scenarios, authed:
node smoke.js

# Anonymous-only (welcome-state checks):
node smoke.js --anon

# One slug:
node smoke.js --only=heimdall
```

Each scenario in `smoke.js`'s `FLEET` array declares:

- `url` — the doorman URL.
- `expect_in_welcome` — substrings the welcome line must contain (any one
  matches).
- `test_message` — what to send (skipped if `--anon`).
- `expect_in_reply` — substrings the assistant reply must contain (any one
  matches).

Editing the fleet is the cheapest way to expand coverage as more seeds
get planted. The harness is one file, no test framework — read it and
adapt.

## What the harness does NOT do

- It doesn't run the OAuth web flow. The pre-seeded token shortcut is
  faster and avoids GitHub's redirect dance, which Playwright would have
  to follow. The flow itself is exercised manually in browsers; the
  harness validates everything past the auth point.
- It doesn't yet test the WebRTC tether (peer-to-peer between two browser
  instances). That's a separate harness with two browser contexts; not
  built here yet.

## Extending

Add a new scenario to `smoke.js`'s `FLEET`. Add a new flag-driven mode to
`chat.js` if you find yourself running the same one-liner repeatedly.
The harness is intentionally small (~250 lines total) — easier to hack
than to configure.
