---
title: The magical install — what a first-timer should see in their terminal
status: draft
section: Blog Drafts
hook: A first-time user running your install one-liner should see five lines and a browser opening — not a dump of file paths, virtualenv locations, log directories, and HTTP routes they're supposed to memorize. The install is the membrane between non-user and user; everything you put on it is a tax the user pays before the product even starts.
date: 2026-05-02
class: timely
decay: high
---

# The magical install — what a first-timer should see in their terminal

Here's what RAPP's install one-liner used to print after a fresh `curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash`:

```
🧠 RAPP Brainstem
   Local-first AI agent server · powered by GitHub Copilot

▸ updating kernel src...
▸ installing dependencies...
▸ launching brainstem on :7071...
✓ brainstem is up at http://localhost:7071

✓ done
   src:    /Users/kodyw/.brainstem/src/rapp_brainstem
   venv:   /Users/kodyw/.brainstem/venv
   logs:   /Users/kodyw/.brainstem/brainstem.log

   ask the brainstem to upgrade itself any time — it has a lifecycle agent.
   routes: GET /api/lifecycle/  ·  POST /api/lifecycle/upgrade
```

A first-timer reads that and immediately feels like they're reading documentation instead of using software. Nine lines of post-install text. Three file paths they'll never type. An HTTP route they're not supposed to know exists. A how-to-use sentence telling them about a "lifecycle agent" before they've even said hello to the brainstem.

The install is supposed to communicate one thing: *your AI is here, click this.* Everything beyond that is friction.

## What it looks like now

Same fresh install, same one-liner, after a thirty-line cut:

```
🧠 RAPP Brainstem
   Local-first AI agent server · powered by GitHub Copilot

▸ getting code...
▸ installing dependencies...
▸ starting your brainstem...
✓ ready at http://localhost:7071
```

Then the browser opens. That's the whole experience.

A repeat install swaps `getting code...` to `getting latest...`. A `--here` install (project-scoped, power-user mode) collapses to a single ✓ line with the start command, since that audience genuinely wants a path. Nothing else.

The diff in the script was 24 lines. The diff in the user experience is the difference between "you ran a command" and "you opened software."

## What got cut and where it went

Everything that disappeared from the install output is still findable — just not at the install moment, when the user is at peak vulnerability and minimum context. The translation:

| Removed from install output | Where it lives now |
|---|---|
| `src: /Users/.../src/rapp_brainstem` | Settings panel in the chat UI; also `brainstem.log` |
| `venv: /Users/.../venv` | Settings panel; also derivable from the path the install printed once before |
| `logs: /Users/.../brainstem.log` | Settings panel; users who need it have already learned to look there |
| "ask the brainstem to upgrade itself any time..." | The brainstem itself, when the user asks. The lifecycle agent's job is to surface this on demand. |
| "routes: GET /api/lifecycle/  ·  POST /api/lifecycle/upgrade" | Internal — the LLM driving the conversation handles routing; the user never touches it |
| `✓ done` (after `✓ ready`) | Deleted as redundant. The first ✓ already said the same thing. |

The principle: *power-user info goes in logs and Settings, never in the install.* If someone needs the venv path, they've crossed into a category of user who knows where to look. If they don't need it, the install showing it to them was a tax.

## Why the bloat happened in the first place

The 2,219-line installer didn't start at 2,219 lines. It started at maybe 60. Every time a feature got added — bond cycle, autostart on login, organism backups, peer registry, project-local mode, agent handshake — the installer grew a step. Each step felt small in isolation. The install output grew with it: *this is what I just did, here are the paths, here's what to ask next.* All justified, individually.

Aggregated, the install output became a system status report sent to a user who hadn't asked for one and couldn't read it. The bicycle had grown spokes the rider didn't need to see.

The cut was possible because Article XXXIX moved everything past install into LLM-to-LLM territory. Once "ask the brainstem to upgrade itself" became a job the user does *inside chat with whatever LLM they trust*, there was no reason to advertise it in the terminal. The advertisement was the artifact of a world where users were expected to memorize commands.

## The membrane between non-user and user

The install is the *membrane*. Five seconds of curl, five lines of output, a browser opening. After that membrane, the user is inside the product. Before the membrane, they're a stranger evaluating whether to enter.

Every line on the install output is a tax the stranger pays before they're inside. Sometimes the tax is justified — a banner names the thing, progress lines confirm something is happening, a final ✓ ready confirms success. Beyond that, every line costs more than it pays.

The product teaches the user. Not the installer. The installer's only job is to be over.

---

*Source: live install rewrite, May 2 2026. The cut shipped in commit `05aac2b` ("installer: trim output to magic — no paths, no routes, no docs"). The structural cut (2,219 → 186 lines) and the constitutional permission for it (Article XXXIX, "The One-Liner Is The Only Human Surface") are companion pieces still in this drafts folder.*
