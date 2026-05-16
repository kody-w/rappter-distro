---
title: Boot Sidecar — Integrating Utils Without Modifying the Kernel
status: published
section: Architecture
hook: The kernel is sacred DNA. Organs, /web mount, and future utils/ integrations attach to its Flask app via boot.py — a kernel-sibling launcher that runs the kernel verbatim and monkey-patches Flask.run to inject additions just before serving.
---

# Boot Sidecar — Integrating Utils Without Modifying the Kernel

> **Hook.** The kernel is sacred DNA. Organs, /web mount, and future utils/ integrations attach to its Flask app via boot.py — a kernel-sibling launcher that runs the kernel verbatim and monkey-patches Flask.run to inject additions just before serving.

## The constraint

Per **Constitution Article XXXIII §4**, AI assistants — and contributors generally — must not edit `brainstem.py`. The kernel is universal DNA, drop-in replaceable across all installs. Yet the kernel as canonically shipped does very little: it serves `/chat`, `/agents`, `/health`, `/version`, voice slot splitting, and Copilot auth. It does **not** dispatch organs (`/api/<name>/<path>` routes), does **not** mount static `/web/<path>` assets, and does **not** know about senses, twin frames, index_card, or any other module under `utils/`.

The question this note answers: **how does the rest of the platform get wired in without ever touching brainstem.py?**

## The pattern: a kernel-sibling launcher

`rapp_brainstem/utils/boot.py` is a sibling of the kernel — DNA-adjacent, not part of the mutation surface. It does three things:

1. **Monkey-patches `flask.Flask.run`** before the kernel runs. The patched version installs organ routes (and any other late-bound integrations) on the Flask app, then hands control to the original `run`.
2. **Executes the canonical kernel verbatim** via `runpy.run_path("brainstem.py", run_name="__main__")`. The kernel's `if __name__ == "__main__":` block runs unchanged — banner, soul load, agent load, the works.
3. **Discovers and registers** organs via `organs.install(app)` at the moment Flask is about to serve. Same for `/web/<path>` static handling.

```python
# rapp_brainstem/utils/boot.py (essence)
import flask, runpy
_real_run = flask.Flask.run
def _wrapped_run(self, *args, **kwargs):
    organs.install(self)   # /api/<name>/...
    _mount_web_static(self)               # /web/<path>
    return _real_run(self, *args, **kwargs)
flask.Flask.run = _wrapped_run
runpy.run_path("brainstem.py", run_name="__main__")
```

That's the whole mechanism. The kernel never imports boot.py. The kernel never knows boot.py exists.

## What this earns us

| Capability | Where it lives | How the kernel knows |
|---|---|---|
| `/chat`, `/agents`, `/health`, `/version` | `brainstem.py` | Kernel ships these. |
| Voice slot splitting (`|||VOICE|||`, when `VOICE_MODE=true`) | `brainstem.py` | Kernel ships this. |
| Organ dispatch (`/api/<name>/<path>`) | `utils/organs/__init__.py` + `utils/organs/*_organ.py` | Doesn't. Boot sidecar attaches. |
| Static `/web/<path>` mount | `boot.py` + `utils/web/*` | Doesn't. Boot sidecar attaches. |
| **Sense composition** (any `*_sense.py` → soul prompt + delimiter splitter) | `senses_loader.py` + `utils/senses/*_sense.py` | Doesn't. Boot sidecar attaches. |
| **vBrainstem** (the simulator UI — Pyodide sandbox + in-browser agent runtime) | `utils/web/index.html`, served by the existing `/web/` mount at `/web/index.html` | Already addressable through the static mount; no extra route needed. |
| Twin frames, index_card polling, egg packing | `utils/{frames,index_card,egg}.py` + organs that consume them | Future — boot sidecar can attach more. |

The kernel stays exactly as small as Article XXXII demands ("kernel is what /chat requires"). The body grows around it.

## Sense composition (how it actually works)

The canonical kernel only knows `|||VOICE|||`, and only when `VOICE_MODE=true`. Every other sense — `|||TWIN|||`, future delimiters — is invisible to the bare kernel. The sidecar makes them participate:

1. **Discovery.** `senses_loader.discover()` globs `utils/senses/*_sense.py`. Each sense file declares `name`, `delimiter`, `response_key`, `wrapper_tag`, and `system_prompt`.
2. **Soul augmentation.** Right before `Flask.run`, the sidecar calls `kernel.load_soul()` to populate `_soul_cache`, then concatenates each sense's `system_prompt` and writes the augmented prompt back into `_soul_cache`. The kernel's chat handler reads `_soul_cache` on every turn — so every turn now carries every sense's instruction.
3. **Response splitting.** The sidecar registers a Flask `after_request` hook that scans `/chat` JSON responses for each sense's delimiter. When a delimiter appears, the trailing segment is peeled into the sense's `response_key` (e.g., `voice_response`, `twin_response`). Senses split in discovery order, so the order of `*_sense.py` files determines splitting precedence. The kernel's hardcoded VOICE block (when `VOICE_MODE=true`) handles voice early; the sidecar handles whatever the kernel left in place.

A new sense is one new file. The kernel never learns about it; the sidecar discovers it on next boot.

## The vBrainstem in its simulated environment

The vBrainstem lives in `utils/web/index.html` — a self-contained browser-side simulator: Pyodide sandbox, in-browser agent runtime, catalog client. It runs standalone (fetching the catalog from GitHub Pages) or paired with the local kernel (using `/chat`, `/agents`, `/api/<name>/<path>` as its backend).

It does not need a dedicated route. The boot sidecar's `/web/` mount already serves it at `/web/index.html`, alongside the rest of `utils/web/`. The simulated environment talks to whatever kernel is hosting it; when that's the local brainstem, the simulator's `/chat` calls land on the same Flask app that served the HTML. One file, one home.

## What `python brainstem.py` still does

The canonical kernel can be launched directly without boot.py:

```bash
python brainstem.py        # bare DNA — chat, agents, voice, no organs
python utils/boot.py              # full organism — DNA + organs + /web
```

This is **load-bearing**. The drop-in fixture (Fixture 01, Article XXXIII §3) tests that the canonical kernel boots from a fresh checkout with nothing else. Organs and /web are additive — present when the launcher arranges for them, absent when the kernel runs alone. Either path is valid; they're the bare and full forms of the same organism.

`start.sh` and `start.ps1` invoke `boot.py` (with a fallback to `brainstem.py` for older organism layouts), so users who run via the launcher always get the full organism. Power users who launch the kernel directly are deliberately opting into the bare form.

## Why a launcher and not a phantom agent

An earlier draft of this design considered putting the integration code in a `*_agent.py` file under `agents/` — leveraging the kernel's existing agent-discovery mechanism. The agent's import side effects would register organ routes on the kernel's app.

Rejected because:

- **`agents/` is the user's workspace** (Article XVII). Engine plumbing doesn't belong there.
- A phantom agent has to walk `sys.modules` to find the kernel's Flask app, which is fragile.
- The phantom agent runs once during `load_agents()`, but the discovery / registration ordering is implicit. The boot sidecar is explicit: "right before `app.run`, install the additions."

The launcher pattern keeps engine plumbing out of the user's workspace and makes the integration timing explicit.

## Why a monkey-patch and not a wrapper script

An earlier draft of this design considered replicating the kernel's `if __name__ == "__main__":` block in boot.py — calling `brainstem.load_soul()`, `brainstem.load_agents()`, etc. by hand, then calling `brainstem.app.run(...)`.

Rejected because:

- The kernel's startup is detailed (telemetry hooks, banner, pending-login resume). Replicating it in boot.py creates **drift risk**: when the kernel adds a new startup step, boot.py becomes silently stale.
- `runpy.run_path(kernel, run_name="__main__")` runs the kernel's startup verbatim, every line, every time. If the kernel adds a step, boot.py picks it up automatically because boot.py doesn't replicate — it delegates.

The monkey-patch is the smallest possible interception: one Flask method, exactly one extra step, no other duplication.

## Future integrations

The boot sidecar is the natural attachment point for everything else under `utils/` that needs to wire into the kernel's HTTP surface or request lifecycle:

- **Index card** — a organ that exposes `/api/card/<turn_id>` polling the per-turn artifact.
- **Twin / frames** — a `before_request` / `after_request` hook in boot.py that records frames; or a organ for the dreamcatcher reconciliation API.
- **Senses** — sense modules contribute to the system prompt every chat turn. The kernel doesn't compose senses today; if it gains a `before_chat` hook in some future canonical update, boot.py will wire senses through it.
- **Egg packing** — a organ `/api/egg/pack` that produces a `.egg` of the running organism.

Each of these adds zero kernel lines.

## See also

- Constitution Article XXXII (Kernel is what chat requires) — the litmus test that says the kernel doesn't do this.
- Constitution Article XXXIII §4 (AI assistants do not edit DNA) — the rule that produced this pattern.
- [[Local Storage Shim via sys.modules]] — a different additive integration: agents transparently get the local backend without knowing.
- [[Fixture 01 — Canonical Kernel local_storage Drop-In]] — the architectural promise this pattern serves: drop-in compatibility.
