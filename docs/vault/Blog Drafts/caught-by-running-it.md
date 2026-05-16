---
title: Caught by running it — three regressions in one diagnostic that the test suite missed
status: draft
section: Blog Drafts
hook: Unit tests passed. The JS contract tests passed. Lint passed. Then we ran the actual public install one-liner against a sandbox HOME, and three real regressions surfaced inside ten minutes — all of them the kind a paying user hits on day one.
date: 2026-05-02
class: timely
decay: high
---

# Caught by running it — three regressions in one diagnostic that the test suite missed

The test suite was green. Thirteen pytest cases passed against the new lifecycle-organ code. The JS contract runner passed (one pre-existing failure unrelated to the change). The bash syntax check passed. The HTML parsed clean. I'd already pushed three commits and was writing release notes when the user said: *test this out by calling the one liner yourself to see if you can fully go through all of this autonomously.*

Inside ten minutes we'd caught three real regressions. Each one was the kind of thing a brand-new user would hit on day one. None of them had any chance of being caught by the unit tests, because none of them lived in the code the unit tests covered.

## Bug #1: the installer launched the kernel directly, bypassing the launcher

The brainstem has two related Python files at its root: `brainstem.py` and `utils/boot.py`. The kernel is `brainstem.py` — bare Flask, agents, the chat endpoint. The launcher is `utils/boot.py` — it monkeypatches Flask's `run()` to add organs, senses, the `/web/` static mount, and a handful of boot-side endpoints (`/api/snapshot/*`, `/api/senses/*`, `/api/workspace/*`) just before the server starts serving. The kernel is the destination; boot.py is the wrapper that brings the rest of the platform.

The new minimal install.sh I'd just shipped — proudly cut from 2,219 lines to 186 — launched `python brainstem.py` directly. Bare kernel, no organs.

The unit tests didn't catch this because the unit tests imported the lifecycle organ as a Python module and called its `handle()` directly. They never went through the HTTP server, never went through Flask's startup sequence, never depended on `boot.py` having wrapped `Flask.run()`. The contract was correct in isolation; the wiring was broken in production.

The first diagnostic stage that ran against the live install asked the brainstem for `GET /api/lifecycle/`. It returned 404. Not just lifecycle — *every organ* was 404'ing. Estate, neighborhood, swarm-estate, lifecycle. The whole `/api/*` surface was dark. Half the platform.

Fix: install.sh now picks the launcher at install time. Use `utils/boot.py` if it exists in the cloned src tree; fall back to bare `brainstem.py` for older clones that predate the wrapper. One commit, eleven inserted lines, four deleted. The kind of thing that needs the live test to surface.

## Bug #2: git fetch silently pulled from the wrong repo

The user's machine had a real install at `~/.brainstem/`, sitting at VERSION 0.6.0. The diagnostic upgraded it. The install one-liner ran, said `✓ ready`, exited 0. Disk reality: VERSION still 0.6.0, no `utils/` directory, no new code. The "successful" install hadn't moved a byte.

The dig: their `~/.brainstem/src/.git` had `origin` pointing at the legacy `kody-w/rapp-installer` repo (the load-bearing one-liner they'd originally installed via, six months earlier). My new install.sh's `git fetch origin main` did exactly what it said — fetched main from the rapp-installer repo, not from the RAPP repo where the new lifecycle code lives. The fetch succeeded. The checkout succeeded. They just pulled real code from a real repo, just *the wrong real repo.*

This bug had a multiplier. The lifecycle organ's upgrade agent subprocess-runs the same install.sh to perform a kernel upgrade. So *every user who originally came in via the legacy installer URL* would have hit the same silent failure on their first lifecycle-driven upgrade. The agent would have reported success; the kernel would have stayed exactly where it was.

Fix: `git remote set-url origin "$REPO_URL"` before every fetch. Five lines added. Idempotent — does no harm if origin is already RAPP, fixes things if it isn't. Self-heals every legacy install on first upgrade.

The unit tests can't catch this. The unit tests don't know about anyone's leftover git state from a previous installer they used last year.

## Bug #3: the autostart plist launched the kernel directly, too

The user has a launchd plist at `~/Library/LaunchAgents/io.github.kodyw.rapp-brainstem.plist` that auto-starts the brainstem on login. The plist's `ProgramArguments` was `python brainstem.py` — same shape as the broken install.sh from bug #1. Even after the upgrade fixed everything else, the next login would have lost half the platform.

This one didn't even live in the codebase. It lived in a config file the previous installer wrote into the user's `~/Library/LaunchAgents/`. The unit tests had no way to know it existed. The diagnostic only caught it because we needed to disable it mid-test (it kept resurrecting the old brainstem the moment we killed it for the upgrade), and once we'd disabled it, the obvious follow-up question was: *what does this plist actually launch?*

Fix: rewrite the plist's `ProgramArguments` to use `utils/boot.py`. One `sed` line. Restore. Done.

## What the three have in common

None of these bugs lived in code I'd just written. They lived at the *seams* between the code and the world:
- The launch invocation chosen by the installer (bug #1)
- The git remote configured by a *previous* installer years ago (bug #2)
- The autostart config written by a *previous* installer into the user's OS (bug #3)

The unit tests were correct about the code they covered. The bugs were in the connective tissue *between* the code and the reality of a machine that had been running this software for months under a previous architecture.

The only test that catches bugs at the seams is the one that actually runs the seams. *Curl the public URL in a sandbox HOME. Boot the brainstem. Ask it for things. See what it does.*

## The /run full diagnostics ritual

We named the procedure mid-session: when the user says *run full diagnostics*, the AI assistant runs the public one-liner in a sandbox HOME, walks every critical endpoint, verifies the constitutional contracts hold, checks the audit log, and returns a single report card. The user doesn't drive any of it; they read the result.

Three regressions caught in the first run. Each one shipped as a one- or two-commit fix during the same diagnostic. By the time the report card was written, the public URL was clean.

The lesson is older than this codebase: *the build passing is not the same as the system working.* But the lesson keeps needing to be relearned because the test suite always feels like proof. It isn't. It's evidence about the slice it covers. Anything outside that slice — the install path, the launch invocation, the user's leftover state from previous architectures — needs a different kind of test, one that actually runs the path the user runs.

The good news: with an AI assistant available to run that test on demand, the cost of "actually run it" dropped to one user sentence. *Run full diagnostics.* That's the entire human surface for catching three bugs that would otherwise have ridden out to every new user on the next push.

---

*Source: live diagnostic session, May 2 2026. Bugs caught and fixed in commits `ed9edfb` (boot.py launcher selection) and `41f3c9e` (force origin URL before fetch). Procedure documented in `feedback_run_full_diagnostics.md`.*
