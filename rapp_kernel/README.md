# `rapp_kernel/` — The Species DNA Archive

> **Public source of truth for the RAPP digital-organism kernel.**
>
> Every released version of the kernel is preserved here at a stable URL forever. This repo is publicly load-bearing: any organism in the wild — at any version, on any machine — can fetch its exact ancestral DNA from this directory.

## What this directory contains

The four files that make up a brainstem's DNA:

| File | Role |
|---|---|
| `brainstem.py` | The kernel — Flask server, Copilot auth, agent loader, LLM tool-call loop. |
| `basic_agent.py` | The base class every agent extends. |
| `context_memory_agent.py` | Persistent memory contributor (system_context every turn). |
| `manage_memory_agent.py` | Save / recall / list memory under tool-call. |

Per **Constitution Article XXXIII §1**, these four files together are the
**species DNA**. Body functions, senses, agents beyond the memory pair,
boot wrappers, and everything else mutable lives outside.

## Layout

```
rapp_kernel/
├── README.md             ← this file
├── manifest.json         ← machine-readable index of versions
├── latest/               ← always the current canonical (stable URL)
│   ├── brainstem.py
│   ├── basic_agent.py
│   ├── context_memory_agent.py
│   ├── manage_memory_agent.py
│   └── VERSION
└── v/
    └── 0.12.2/           ← immutable per-version snapshot
        ├── brainstem.py
        ├── basic_agent.py
        ├── context_memory_agent.py
        ├── manage_memory_agent.py
        ├── VERSION
        └── checksums.txt ← sha256 of each file (drift / tampering detection)
```

`latest/` rolls forward as new versions are released. `v/<version>/` is
**frozen** — once a directory exists under `v/`, its contents are not
modified, ever. New versions add new directories; they do not edit old
ones.

## Stable URLs (load-bearing)

Per **Constitution Article V** (the install one-liner is sacred), URLs
under this directory are publicly load-bearing for the lifetime of the
project. Examples:

- `https://kody-w.github.io/RAPP/rapp_kernel/latest/brainstem.py`
- `https://kody-w.github.io/RAPP/rapp_kernel/v/0.12.2/brainstem.py`
- `https://kody-w.github.io/RAPP/rapp_kernel/v/0.12.2/checksums.txt`
- `https://kody-w.github.io/RAPP/rapp_kernel/manifest.json`

Variant repos that fork from `kody-w/RAPP` (per Article XXXIV) inherit
the same shape. A user pinned to a specific kernel version can fetch
that version's files at the same path under their variant repo.

## Relationship to `rapp_brainstem/`

| `rapp_kernel/` | `rapp_brainstem/` |
|---|---|
| The species DNA archive — pure, versioned, public, immutable per version | The runtime install — kernel + body functions + senses + agents + state + UI |
| 4 files per version | The full living organism |
| Read-only reference | Where the brainstem actually runs |
| Stable URLs forever | Local-first per machine |

The kernel files in `rapp_brainstem/` should match `rapp_kernel/latest/`
exactly. Drift is caught by `tests/organism/09-rapp-kernel-archive.sh`,
which compares each file pair byte-for-byte.

## How a new kernel version lands here

When the kernel is updated (rare — Article XXXIII §4 keeps the bar
high):

1. Bump `rapp_brainstem/VERSION` to the new number.
2. Copy the four canonical files from `rapp_brainstem/` into
   `rapp_kernel/latest/`.
3. Create a new directory `rapp_kernel/v/<new-version>/` with the same
   four files plus a fresh `checksums.txt`.
4. Append the new entry to `manifest.json` and update its `latest`
   field.
5. **Never** modify any existing `rapp_kernel/v/<old>/` directory.

The previous version's directory becomes a permanent historical
artifact — the species' fossil record.

## What to fetch when

| Need | Use |
|---|---|
| The latest kernel — install one-liner default | `latest/` |
| A pinned kernel version — reproducible installs, forensics, rollback | `v/<version>/` |
| Which version is current — programmatic discovery | `manifest.json` (`.latest`) |
| All known versions — variant tooling, lineage walks | `manifest.json` (`.versions[].version`) |
| Verify a downloaded copy hasn't been tampered with | `v/<version>/checksums.txt` |

## What this directory is not

- **Not the runtime.** `python brainstem.py` is run from `rapp_brainstem/`,
  not from here. This directory is reference, not execution.
- **Not exhaustive.** It contains the four files Article XXXIII §1 names
  as kernel. Body functions, senses, sense viewers, agents beyond the
  memory pair, the boot wrapper, and everything else mutable are not
  here — they live in `rapp_brainstem/` (per organism) or in their own
  catalog repos.
- **Not editable.** Once a `v/<version>/` directory is committed, its
  contents are locked. If you need to fix a bug in 0.12.2, the fix
  becomes 0.12.3; 0.12.2 stays exactly as it shipped.

## See also

- [Constitution Article XXXIII](../CONSTITUTION.md) — Digital Organism. Defines the kernel as DNA.
- [Constitution Article XXXIV](../CONSTITUTION.md) — Rappid + Variant Lineage. Variant repos inherit this archive shape.
- [Constitution Article V](../CONSTITUTION.md) — The Install One-Liner Is Sacred. URL stability promise.
- [Vault: The Species DNA Archive](../pages/vault/Architecture/The%20Species%20DNA%20Archive%20—%20rapp_kernel.md) — long-form essay on why this directory exists.
