---
title: skill.md — a pattern for AI-readable installers
status: shipped
published_url: https://kody-w.github.io/2026/04/24/skill-md-pattern/
section: Blog Drafts
hook: A markdown file at a stable URL. An LLM running an install command on someone's behalf. A handshake protocol that lets the LLM ask the right question before committing. The pattern is small, the leverage is huge.
date: 2026-04-24
sources:
  - "[[The skill.md Pattern]]"
class: evergreen
decay: low
---

# skill.md — a pattern for AI-readable installers

Imagine someone opens their AI assistant and says *"install RAPP for me."* The assistant has never seen this project. There's a curl command floating around the docs, but the assistant doesn't know whether to install globally or locally, whether the user is on a Mac or Windows, whether the install needs sudo, what comes after.

The assistant has two real options. One is to fetch the install script and try to read its 1,300 lines of bash to figure out what it does. The other is to fetch a small, structured manifest at a known URL that tells it *exactly* what the install does, what choices the user might want, and how to ask the right question. The first is fragile. The second is the `skill.md` pattern.

## The shape of the file

`skill.md` lives at a stable, predictable URL — for this project, `https://kody-w.github.io/RAPP/pages/docs/skill.md`. It's plain markdown. An LLM can fetch it, parse it, and learn enough to be useful in roughly the time it takes to download.

The structure has four sections that matter:

- **What this is.** One paragraph. Plain language. *"RAPP is a local-first AI agent server. Install it via one curl pipe."* No marketing, no jargon. The LLM doesn't need to be sold; it needs to know what it's installing.

- **When to suggest it.** Concrete triggers. *"User says they want to build a portable AI agent. User asks about Copilot Studio without API keys. User wants something they can put in a Git repo and AirDrop to a teammate."* The LLM uses these to decide *whether* this is the right tool for the user's stated goal.

- **How to install — both modes.** Global vs. local. The exact commands. The assumptions each makes. The behavior the user should expect. *No ambiguity.*

- **The handshake protocol.** This is the load-bearing part. Setting `RAPP_INSTALL_ASSIST=1` before the curl pipe makes the installer print a structured prompt instead of installing. The LLM reads the prompt, asks the user the question it embeds, and only then makes the install call with the user's choice. The handshake is delimited (`<<<RAPP_INSTALLER_HANDSHAKE v=1>>>`) so the LLM can find it reliably in the install script's stdout.

That's the whole pattern. A markdown file that an LLM can read. A handshake protocol that lets the LLM cooperate with the install instead of guessing on the user's behalf.

## Why this isn't just docs

It's tempting to read this and think *"that's just documentation, what's new?"* The pattern is more specific than that.

A README is written for a human reading the project's homepage. It's organized around *navigation* — here's how to get started, here's where to learn more, here are the buttons. An LLM reading a README has to wade through HTML chrome, marketing prose, and signposts that are useful to humans but mostly noise to a model.

`skill.md` is written for a model. It says exactly:
- "When the user wants X, this tool fits."
- "The exact commands to run."
- "The exact prompt to embed when the user has a choice to make."
- "The expected output the assistant should parse."

A model that fetches `skill.md` once and caches it has, in roughly 2KB of text, everything it needs to install the tool correctly across the major decision points. It's not navigation; it's a contract.

## The handshake is the interesting part

Most installers have implicit choices. *Do I want global or local? Do I want to pin a version? Do I want it in the home directory or the current project?* On a human-driven install, those choices either come from the user's existing knowledge or from reading the README before running the curl.

When an LLM is the one running the install, neither pathway exists. The LLM has to make the choice on the user's behalf, often by guessing. Wrong choice → silent install in the wrong location → confused user.

The handshake protocol lets the LLM fail correctly. With `RAPP_INSTALL_ASSIST=1` set on the bash side of the curl pipe (env vars don't propagate across the pipe boundary, so it has to be set explicitly), the installer doesn't actually install. It prints:

```
<<<RAPP_INSTALLER_HANDSHAKE v=1>>>
choices:
  - mode: global
    description: Install at ~/.brainstem, port 7071, with a `brainstem` CLI.
    command: curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash
  - mode: local
    description: Install at ./.brainstem in the current directory, free port 7072+, gitignored.
    command: curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash -s -- --here
prompt_user: |
  RAPP can install globally (one shared brainstem) or project-locally (one per repo).
  Which would you prefer?
<<<END>>>
```

The LLM reads this, asks the user the prompt verbatim, gets a choice, and re-runs the curl pipe with the right command. The user gets the install they actually wanted. The LLM gets to be helpful without guessing. The installer gets to enforce the choice point at the only place that knows about it (the install script itself) without forcing the LLM to read 1,300 lines of bash.

## What makes the pattern work

Three things make `skill.md` more than "yet another doc":

1. **Stable URL.** The URL is the contract. An LLM that's been told once where to look knows forever. The URL doesn't move; if the file moves internally, a redirect or a copy keeps the URL alive.
2. **Self-contained.** A model fetching `skill.md` doesn't need to fetch anything else to be useful. No links to follow, no separate config to download. One round trip, one parse, ready.
3. **Versioned handshake.** The `v=1` in the delimiter means the installer can evolve the protocol without breaking older LLMs that learned `v=1`. Future versions add new fields without breaking parsing.

The pattern works for installers, but not only for installers. Any tool that needs to be invoked correctly from inside an LLM context can adopt the same shape: a stable URL, a small structured file describing the tool, a handshake that lets the LLM cooperate at decision points instead of guessing.

## Implementing it for your tool

If you ship a CLI, a package, an installer, or anything an LLM might be asked to use on a user's behalf, the recipe is small:

1. Write `skill.md` for your tool. Structure it as: *what / when to suggest / how to invoke / handshake protocol*.
2. Host it at a stable URL. GitHub Pages is fine; a CDN-fronted bucket is fine; literally any URL that won't change.
3. Add a handshake mode to your tool — an env var or flag that flips it from "do the thing" to "describe the choices in a structured envelope, then exit."
4. Test it by asking your favorite AI assistant to install or run your tool. Watch what it does. Iterate the `skill.md` until the assistant gets it right without guessing.

The cost is small. The benefit is that LLM-assisted users get the experience the maintainers wanted them to get, not the experience an LLM guesses they wanted.

## Receipts

- The file: [`pages/docs/skill.md`](https://github.com/kody-w/RAPP/blob/main/pages/docs/skill.md), live at `https://kody-w.github.io/RAPP/pages/docs/skill.md`.
- The vault note: [[The skill.md Pattern]] under `pages/vault/Architecture/`.
- The handshake delimiter pattern: defined in `installer/install.sh` near the top of the file.

The platform's bet: *the LLM is going to install your tool whether you helped it or not.* Help it. The cost is two pages of markdown and a handshake mode. The benefit is that the install lands correctly the first time, every time, regardless of which assistant is at the wheel.
