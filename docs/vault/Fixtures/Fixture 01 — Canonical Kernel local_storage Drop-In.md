---
title: Fixture 01 — Canonical Kernel local_storage Drop-In
status: published
section: Fixtures
hook: The first wild encounter recorded as a permanent organism test fixture. Canonical kernel dropped onto a heavily-mutated local org failed because of a bare top-level import. The fix is purely additive — and the lesson is the architecture itself.
---

# Fixture 01 — Canonical Kernel `local_storage` Drop-In

> **Hook.** The first wild encounter recorded as a permanent organism test fixture. Canonical kernel dropped onto a heavily-mutated local org failed because of a bare top-level import. The fix is purely additive — and the lesson is the architecture itself.

## What this fixture is

Per **Article XXXIII** (Digital Organism), every weird real-world drop-in failure becomes a permanent fixture in the test suite. The suite is the species' immune memory. This is the first one on file.

The fixture replays a real session: a developer dropped the canonical kernel `brainstem.py` (1543 lines, freshly reverted) into a local organism whose installed brainstem had drifted to 2545 lines through prior assistant edits. The hatching attempt failed. This note records the encounter and the resolution shape so every future kernel can prove it survives the same situation.

## The encounter

**Local organism (recipient)**

- Installed brainstem at `~/.brainstem/src/rapp_brainstem`
- Bloated kernel: 2545 lines (had drifted from canonical through accumulated edits)
- 12 agents accumulated, body functions present at `utils/services/`
- Active session: GitHub Copilot tokens cached, soul edited, `.brainstem_data/` populated
- The organism worked: `/health`, `/chat`, `/agents`, services all answered cleanly

**Incoming generation (donor)**

- Canonical kernel: 1543 lines (the small, sacred shape)
- Imports `local_storage` as a bare top-level module:

  ```python
  # rapp_brainstem/brainstem.py:689 (canonical)
  from local_storage import AzureFileStorageManager as _LSM
  ```

- The import expects `local_storage.py` to live next to `brainstem.py` (kernel sibling).

**Layout reality**

In both the recipient organism and a fresh repo checkout, `local_storage.py` only exists at `utils/local_storage.py`, never at the top level. The bloated kernel had a kernel-side workaround:

```python
# bloated kernel had this — canonical does not
utils_dir = os.path.join(brainstem_dir, "utils")
if utils_dir not in sys.path:
    sys.path.insert(0, utils_dir)
from local_storage import AzureFileStorageManager as _LSM
```

When the canonical kernel was dropped onto the recipient organism (or any clean checkout), the import failed:

```
ModuleNotFoundError: No module named 'local_storage'
  File "rapp_brainstem/brainstem.py", line 689, in _register_shims
    from local_storage import AzureFileStorageManager as _LSM
```

The kernel could not boot. `load_agents()` is called on first request, and shim registration runs before any agent loads — so even `/health` couldn't list agents.

## Why this matters

This isn't "a bug." This is the architectural promise being tested. **Article XXXIII** says the canonical kernel must be droppable onto any organism of this species, no matter how heavily mutated, and that organism must continue to live. This drop-in failed. The architecture has to absorb the failure additively — without editing the kernel — or the whole organism model is broken.

Two ways to satisfy the promise:

1. **The kernel ships with everything it imports.** Every bare import in the kernel must resolve to a sibling file the kernel ships alongside. The kernel cannot reach into the mutation surface (`utils/`, `agents/` body, organs) for resolution.
2. **The kernel adds path manipulation before its imports.** This was the bloated-kernel approach (`sys.path.insert`). It works but it's a kernel edit — and kernel edits are how species drift accumulates.

The architecture originally chose (1): the kernel shipped its sibling deps. As of the front-porch cleanup (utils/ contains all wizardry), the storage shim resolves through `utils/local_storage.py` with a fallback to the legacy root sibling for older organism layouts. Both paths are kept on the import line so the kernel can drop onto either layout.

## The resolution shape

A purely additive sibling file:

```
rapp_brainstem/
├── brainstem.py            ← canonical kernel (untouched)
├── basic_agent.py          ← canonical kernel sibling (untouched)
├── local_storage.py        ← NEW: kernel sibling, re-exports from utils.local_storage
└── utils/
    └── local_storage.py    ← actual implementation (already here)
```

The new top-level `local_storage.py` is two lines:

```python
"""Kernel sibling — re-exports utils.local_storage so the canonical kernel's
bare `from local_storage import ...` resolves on any layout."""
from utils.local_storage import *  # noqa: F401,F403
```

This is **DNA-adjacent** (a kernel sibling), not mutation-surface. It travels with the kernel as a unit. Kernel updates that change `local_storage`'s API ship a matching shim update. Body functions and agents never depend on this file directly — they keep importing `from utils.azure_file_storage import AzureFileStorageManager`, which the kernel then routes through its `sys.modules` shim onto the local implementation.

## What the test fixture asserts

`tests/organism/test_fixture_01_local_storage.sh` will:

1. Stage a fixture organism: a fresh repo checkout (with `local_storage.py` shim in place), plus a soul edit and a custom agent file in `agents/` (representing accumulated mutations).
2. Boot the canonical kernel (`PORT=<free> python brainstem.py`).
3. Assert `/health` returns 200.
4. Assert `/health` lists the custom agent under `agents`.
5. Assert the custom agent can be invoked (using `LLM_FAKE=1` to keep tests offline).
6. Tear down the fixture organism.

The test runs against every PR forever. If a future kernel introduces a new bare top-level import without shipping its sibling, this fixture catches it before the kernel ships.

## What this fixture is not

- It is not "a bug we fixed." Bugs get a commit and disappear. Fixtures stay forever and run on every change.
- It is not specific to `local_storage`. The shape generalizes: any kernel-side bare import that doesn't resolve on a stripped layout is the same fixture pattern.
- It is not a license to add more kernel-side imports. The kernel stays small (Article I, Article XXXII). When it does import, the import must self-resolve.

## Why this is fixture #1

This is the fixture that *taught the architecture how it must behave*. Future fixtures will be more specific — a particular agent that needs a particular adapter, a particular soul edit that interacted badly with a particular slot — but this one is foundational. It established the rule: **the kernel ships with everything it imports**. Every fixture going forward exists in this rule's shadow.

## See also

- Constitution Article XXXIII (Digital Organism) — the architectural promise. See [`CONSTITUTION.md`](../../../CONSTITUTION.md).
- Constitution Article XXXIV (Rappid + Variant Lineage) — the lineage tracking.
- [[Local Storage Shim via sys.modules]] — the broader pattern of intercepting agent imports.
