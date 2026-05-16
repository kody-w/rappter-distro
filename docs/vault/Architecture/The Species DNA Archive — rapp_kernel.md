---
title: The Species DNA Archive — rapp_kernel
status: published
section: Architecture
hook: rapp_kernel/ is the public, permanent, versioned source of truth for every kernel that has ever shipped. Four files per version, frozen URLs forever, drift-detected against the running brainstem. The species' fossil record.
---

# The Species DNA Archive — `rapp_kernel/`

> **Hook.** `rapp_kernel/` is the public, permanent, versioned source of truth for every kernel that has ever shipped. Four files per version, frozen URLs forever, drift-detected against the running brainstem. The species' fossil record.

## Why this directory exists

The repository at `kody-w/RAPP` is more than a place where the brainstem source lives. By **Constitution Article V** (the install one-liner is sacred) and **Article XXXIV** (rappid + variant lineage), this repo is **publicly load-bearing**: anyone in the world, on any machine, in any variant, must be able to fetch the exact bytes of any kernel version that has ever shipped. Forever.

That promise can't live inside `rapp_brainstem/` alone, because `rapp_brainstem/` is the **current runtime** — it carries one version at a time, plus all the body functions, senses, agents, and state that aren't kernel. To ship the species' history, you need an archive that is:

- **Versioned** — every release preserved at a separate URL.
- **Immutable** — old versions never edited, only added to.
- **Pure** — only the four files Article XXXIII §1 names as kernel DNA.
- **Discoverable** — a manifest you can read programmatically.
- **Verifiable** — checksums you can compare against bytes you fetched.

`rapp_kernel/` is that archive.

## Layout

```
rapp_kernel/
├── README.md
├── manifest.json
├── latest/
│   ├── brainstem.py
│   ├── basic_agent.py
│   ├── context_memory_agent.py
│   ├── manage_memory_agent.py
│   └── VERSION
└── v/
    └── 0.12.2/
        ├── brainstem.py
        ├── basic_agent.py
        ├── context_memory_agent.py
        ├── manage_memory_agent.py
        ├── VERSION
        └── checksums.txt
```

Two locations per file. `latest/` is the always-current copy; `v/<version>/` is the frozen historical snapshot. `latest/<file>` and `v/<latest-version>/<file>` are byte-identical for the current version. Older `v/<n>/` directories carry the bytes of *that* release, regardless of what the current version is.

## The four files

Per **Constitution Article XXXIII §1**, the kernel DNA is exactly:

| File | Role |
|---|---|
| `brainstem.py` | The Flask kernel: chat, agents, voice slot, Copilot auth, agent loader, LLM loop. |
| `basic_agent.py` | The base class every agent extends. Defines the `name + metadata + perform()` contract. |
| `context_memory_agent.py` | System-context contributor (every chat turn pulls long-term memory into the prompt). |
| `manage_memory_agent.py` | Tool-call interface for save / recall / list memory. |

These four files are the species. Everything else — body functions, senses, agents beyond the memory pair, the boot wrapper, web assets, state directories — is body, mutation, or musculature. They live in `rapp_brainstem/`, never in `rapp_kernel/`.

## URLs are load-bearing

Per **Constitution Article V**, URLs under this directory are **public infrastructure**. They cannot move, change shape, or be deleted. Examples:

- `https://kody-w.github.io/RAPP/rapp_kernel/manifest.json`
- `https://kody-w.github.io/RAPP/rapp_kernel/latest/brainstem.py`
- `https://kody-w.github.io/RAPP/rapp_kernel/v/0.12.2/brainstem.py`
- `https://kody-w.github.io/RAPP/rapp_kernel/v/0.12.2/checksums.txt`

A user pinned to v0.12.2 in `BRAINSTEM_VERSION` env var, the install one-liner fetching `latest/`, a forensic analysis comparing what shipped a year ago to what shipped today — all of these depend on these URLs being there. The archive is a public commitment, not a convenience.

## Variant inheritance

When a user creates a variant master per **Article XXXIV.3** (laying an egg that becomes a new species), their variant repo inherits the same `rapp_kernel/` shape. From day one, the variant has its own `rapp_kernel/v/<version>/` paths under its own GitHub Pages. Consumers of the variant get the same pinned-version contract that `kody-w/RAPP` provides — pinning is not a master-only privilege, it's a property of the platform.

## Drift detection

The fixture suite includes `tests/organism/09-rapp-kernel-archive.sh`. Every change to `rapp_brainstem/`'s kernel files must be mirrored into `rapp_kernel/latest/`, and the corresponding `v/<version>/` snapshot must validate against its `checksums.txt`. The test catches:

- Editing a kernel file in `rapp_brainstem/` without updating the archive
- Editing files inside an existing `v/<version>/` directory (which is forbidden)
- A `v/<version>/checksums.txt` whose bytes don't match the files next to it

If any of those conditions hold, the test fails. The archive cannot quietly drift.

## Adding a new version

When the kernel is updated (rare — Article XXXIII §4 keeps the bar high):

1. Bump `rapp_brainstem/VERSION` to the new number.
2. Copy the four canonical files from `rapp_brainstem/` (and `rapp_brainstem/agents/` for the memory agents) into `rapp_kernel/latest/`.
3. Create a new directory `rapp_kernel/v/<new>/` with the same four files plus a fresh `checksums.txt` (`shasum -a 256 *.py VERSION > checksums.txt`).
4. Append the new entry to `manifest.json` and update its `latest` field.
5. **Never** modify any existing `rapp_kernel/v/<old>/` directory. If 0.12.2 had a bug, the fix is 0.12.3. 0.12.2's bytes stay exactly as they were.

The fixture suite passes only when steps 1–4 are all done in the same change.

## What this directory is not

- **Not a runtime.** Nothing in `rapp_kernel/` is executed. `python rapp_kernel/latest/brainstem.py` would crash — the kernel-sibling shims and start scripts live in `rapp_brainstem/`. This is a reference archive.
- **Not exhaustive.** It contains four files. The wider rapp_brainstem ecosystem — body functions, senses, sense viewers, additional agents, the boot wrapper, the install scripts, the web UI — is not here. This directory is pure kernel DNA, not the whole organism.
- **Not editable past the latest.** Once `v/<n>/` lands, it is locked. Future PRs that need to "fix something in 0.12.2" must add 0.12.3.

## See also

- [Constitution Article XXXIII](../../../CONSTITUTION.md) — Digital Organism. Names the four files as DNA.
- [Constitution Article XXXIV §6](../../../CONSTITUTION.md) — The species DNA archive subsection.
- [Constitution Article V](../../../CONSTITUTION.md) — Install one-liner and URL-stability promise.
- [[Boot Sidecar — Integrating Utils Without Modifying the Kernel]] — how everything else gets wired in around this DNA.
- [[Fixture 01 — Canonical Kernel local_storage Drop-In]] — what happens when the archive lacks a sibling the kernel needs.
