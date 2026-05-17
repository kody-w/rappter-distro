# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is (and isn't)

`rappter-distro` is **not a runnable application** — it is the *organism layer* that gets copied on top of an already-installed RAPP kernel (`kody-w/rapp-installer`, mirrored at `kody-w/RAPP`). Nothing in this tree is executed in-place; `install.sh` rsyncs the directories into `$HOME/.brainstem/` (or `$BRAINSTEM_HOME`), where the kernel actually lives, per the mapping in `distro.json`.

Before doing any real work, read `README.md`, `MIGRATION_NOTES.md`, and `distro.json` — they together specify what moved out of the kernel into here, the exact source → install path layout, and which kernel files the distro is forbidden from touching.

## Hard contract: never modify the kernel

The distro is a valid distro **only if the three sacred kernel files stay byte-identical to grail**:

- `rapp_brainstem/brainstem.py`
- `rapp_brainstem/VERSION`
- `rapp_brainstem/agents/basic_agent.py`

There is no `rapp_brainstem/` in this repo on purpose — those files live in the kernel repo. If a task seems to require editing them, stop and reconsider: the answer is almost always to extend via an organ, a sense, or the `lib/boot.py` wrapper instead. The drift-check one-liner in `MIGRATION_NOTES.md` is what users run to verify clean layering after install.

## Install / run

```bash
# Install onto an existing ~/.brainstem (run from inside this repo, or via the curl one-liner in README)
bash install.sh

# After install, the distro launcher is used in place of `python brainstem.py`:
python ~/.brainstem/utils/boot.py

# The bare kernel still works (no organs / senses / rich UI):
python ~/.brainstem/brainstem.py
```

`install.sh` auto-detects a local checkout (presence of `distro.json` + `lib/` + `organs/`) and copies straight from `$(pwd)`; otherwise it shallow-clones `$DISTRO_BRANCH` (default `main`) into a tempdir. Override the target with `BRAINSTEM_HOME=...`.

There are no build, lint, or test commands in this repo today (no `tests/` directory currently checked in, no `package.json`, no Python project file). The kernel's own test suite is where the cross-system integration lives.

## How the three loaders compose onto the kernel

This is the load-bearing architecture — understanding it is required for any change in `lib/`, `organs/`, or `senses/`.

The trick: **`lib/boot.py` monkey-patches `flask.Flask.run` before invoking `brainstem.py` via `runpy`**. The kernel runs verbatim, but the moment its `app.run(...)` is called, three additive installers fire onto the same `app`:

1. **`organs/__init__.py::install(app)`** — discovers `*_organ.py` files in `utils/organs/` (also legacy `body_functions/` and `services/` for back-compat), imports each, and mounts `/api/<organ.name>` + `/api/<organ.name>/<path:rest>` URL rules that dispatch into `organ.handle(method, path, body) → (dict|list|response, status)`.
2. **`senses/__init__.py::install(app)`** — discovers `*_sense.py` files, then locates the running kernel module via `sys.modules['__main__']` and **mutates `kernel._soul_cache`** to append each sense's `system_prompt`. It also registers an `after_request` hook that splits `/chat` JSON responses on each sense's `delimiter` (e.g. `|||VOICE|||`, `|||TWIN|||`) and exposes the tail under `response_key`.
3. **Always-on boot wrapper routes** in `lib/boot.py` itself: `/web/<path>` static mount, `/api/snapshot/{export,import}` (egg pack/unpack via `bond.py`), `/api/senses` install/list/remove, `/api/workspace/<rapp_id>/...`, and `/api/preferences/<key>`. These don't go through the organ system because they're foundational to the chat UI and need zero organ wiring.

Two kernel features this depends on (do not break them):

- The kernel maintains a global `_soul_cache` that senses mutate in place; senses locate it by walking `sys.modules`.
- The kernel exposes `load_soul()` to seed that cache.

`lib/boot.py::_lineage_guard()` runs before `runpy` and aborts the process if `rappid.json` identity doesn't match the git location (template clone safety). Bypass with `RAPP_SKIP_LINEAGE_CHECK=1`.

`lib/boot.py::_seed_env_from_prefs()` reads `~/.brainstem/preferences/model.txt` and seeds `GITHUB_MODEL` into the env before the kernel's module import, so the user's chat-UI model pick survives restart.

## Layout (source → install destination)

Authoritative mapping lives in `distro.json::layout`. Summary:

| Source in this repo | Installs to under `$BRAINSTEM_HOME` |
|---|---|
| `agents/@rappter/*.py` | `agents/@rappter/` |
| `lib/*.py` | `utils/` (flat — that's why organs/senses `import bond`, `import workspace`, etc. work) |
| `organs/*_organ.py` | `utils/organs/` |
| `senses/*_sense.py` | `utils/senses/` |
| `ui/web/*` | `utils/web/` |
| `ui/index.html` | `index.html` (replaces grail's smaller bundled UI — explicitly allowed by Mirror Spec) |
| `ui/tls_proxy.py` | `tls_proxy.py` |

Other top-level directories that are **not** installed by `install.sh`:

- `binders/` — manifests describing meta-installs (e.g. `@rappter-full-organism.json`).
- `examples/` — sample neighborhoods like `rapp-commons/`.
- `installer/` — alternative install surfaces (`plant.sh` plants a GitHub Pages front door; `initialize-variant.sh` is for template clones; `start-local.sh` boots the static + optional swarm dev stack).
- `rapp_kernel/` — **immutable per-version archive of the species DNA** (`latest/` + `v/<version>/`). Per Article XXXIII §1, once `v/<x>/` exists, never modify it. New versions add new dirs.
- `rapp-zoo/` — local-first "Pokédex" static page (`index.html` + `api/v1/` + `starters/*.egg`); served via GitHub Pages.
- `tools/` — ops scripts (`rebuild_estate.py`, `ecosystem_audit.py`, `sign_release.py`, sim runners, etc.).

## Writing a new organ or sense

**Organ** (`organs/<name>_organ.py`):

```python
name = "myorgan"

def handle(method: str, path: str, body: dict) -> tuple[dict, int]:
    # path is everything after /api/myorgan/
    return {"ok": True}, 200
```

The loader auto-discovers it; it will be reachable at `/api/myorgan` and `/api/myorgan/<anything>`. Organs may `import` siblings from `lib/` (which land in `utils/`) — e.g. `import peer_registry`, `import bond`, `import workspace`.

**Sense** (`senses/<name>_sense.py`):

```python
name = "myname"
delimiter = "|||MYNAME|||"
response_key = "myname_response"
wrapper_tag = "myname"
system_prompt = "After your normal reply, emit |||MYNAME|||<your data>."
```

The sense's `system_prompt` is appended to the kernel's soul once at boot; the `after_request` hook splits the reply on `delimiter` and surfaces the tail at `data[response_key]`.

## Things that look like bugs but aren't

- `organs/__init__.py` scans three candidate directories (`organs/`, `body_functions/`, `services/`) — these are historical names for the same single-file unit, retained so older installs and in-flight template clones keep working through the rename. Newer location wins on name collision.
- `lib/boot.py` catches `ImportError` for both `organs`/`senses` AND for legacy `body_functions_loader` / `senses_loader` — same back-compat reason.
- `lib/boot.py` writes `os.environ["GITHUB_MODEL"]` from a preferences file. Yes, the env var is named for GitHub even though the model itself may not be; that's the kernel's existing name and changing it would break the kernel.
