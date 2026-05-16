---
title: Local Storage Shim via sys.modules
status: published
section: Architecture
hook: Agents import `from utils.azure_file_storage import AzureFileStorageManager`. The brainstem hijacks the import. The agent never knows.
---

# Local Storage Shim via sys.modules

> **Hook.** Agents import `from utils.azure_file_storage import AzureFileStorageManager`. The brainstem hijacks the import. The agent never knows.

## The mechanism

Open any RAPP agent that persists data — `agents/manage_memory_agent.py` is a fine example — and you'll see this near the top:

```python
from utils.azure_file_storage import AzureFileStorageManager
```

In Tier 2 and Tier 3, that import resolves to the real Azure File Storage SDK module: a network-backed implementation that talks to a customer's Azure Storage account.

In Tier 1, that import resolves to `rapp_brainstem/utils/local_storage.py` — a 111-line JSON-file backend that reads and writes under `rapp_brainstem/.brainstem_data/`. The agent's source code is identical. The behavior is identical from the agent's perspective. The Azure SDK is not installed and is not needed.

The trick is in `_register_shims()` (`rapp_brainstem/brainstem.py:648`). Before any agent file is imported, the brainstem populates `sys.modules` with synthetic modules:

```python
afs_mod = types.ModuleType("utils.azure_file_storage")
afs_mod.AzureFileStorageManager = LocalStorageManager  # the local implementation
sys.modules["utils.azure_file_storage"] = afs_mod
```

When the agent's `import` statement runs, Python checks `sys.modules` first. The synthetic entry is there. Python returns it. The Azure import never reaches the filesystem. The agent author wrote portable code by writing a normal-looking import.

## Why this matters

The platform's central claim — *the same agent file runs in three places* — depends on this. Without the shim, an agent author would have to choose between:

1. **Conditional imports.** `if os.environ.get("AZURE_STORAGE_KEY"): from utils.azure_file_storage import ... else: from local_storage import ...`. Every agent is now tier-aware. Tier portability is dead.
2. **An abstraction layer.** A `Storage()` factory that picks an implementation based on environment. Every agent now imports `Storage`, the brainstem grows a config layer, and the contract grows a vocabulary.
3. **One real implementation, faked at the boundary.** This is what RAPP does. Agents look like they import the real Azure module. The brainstem makes that import resolve to whatever the tier needs.

Of those three, option 3 is the only one where the *agent's source code is identical across tiers*. That property is the point.

## What other shims exist

The shim layer is a small handful of modules, all set up in `_register_shims()`:

- **`agents` and `agents.basic_agent`.** The brainstem ensures `from agents.basic_agent import BasicAgent` resolves the same way regardless of how the brainstem was launched (working directory, package install, etc.). The shim creates the `agents` package node if it isn't already there.
- **`openrappter` namespace.** Some legacy agents from upstream community projects use `from openrappter.agents.basic_agent import ...`. The shim aliases that path to the same `BasicAgent` class. Old agents still load.
- **`utils.azure_file_storage`.** The headline shim, described above.
- **`utils.dynamics_storage`** and **`utils.storage_factory`.** Companion shims for related Microsoft storage modules that occasionally appear in vendored agents.

All shims share a property: **they make portable agents look like normal Python**, and they're set up *once*, before any agent loads. There is no runtime branching, no per-call dispatch, no environment-checking inside agents.

## What the local backend looks like

`rapp_brainstem/utils/local_storage.py` is small enough to read end-to-end. Its job is to mirror the API the upstream `AzureFileStorageManager` exposes — `set_memory_context()`, `read_json()`, `write_json()`, `read_file()`, `write_file()`, `list_files()`, etc. — backed by JSON files under `.brainstem_data/`:

- Shared memory: `.brainstem_data/shared_memories/memory.json`
- Per-user memory: `.brainstem_data/memory/<guid>/user_memory.json`

The data layout *also* matches the Azure layout (under different paths), so memory written in Tier 1 and later migrated to Tier 2 lands in equivalent shape. The shim doesn't just preserve the API — it preserves the data shape, which is what makes the migration story credible.

## Why this beats the alternatives

The shim looks like magic the first time you read it. It's not a hack. Each alternative was considered and rejected:

- **Abstract base classes.** Every agent extends a `StorageBackend` protocol; the brainstem injects an implementation. Rejected because every agent now has an extra abstraction layer to learn, and the protocol becomes a forever-versioned interface.
- **Dependency injection.** The brainstem passes a storage instance into agent constructors. Rejected because agents would have to be aware of injection (constructor signatures grow), and the LLM-facing tool definition would have to know about injection too. Plus it doesn't survive vendoring (Tier 2's vendoring would need to re-wire the injection).
- **A separate module name per tier.** Agents import `tier1_storage` in Tier 1, `tier2_storage` in Tier 2. Rejected because that explicitly makes agents tier-aware. The whole point is that they aren't.
- **Lazy imports.** Each agent does `def perform(self, ...): import storage_thing; ...` to defer resolution. Rejected because the import-time check is what gives the brainstem control; deferring it pushes the failure mode to per-call.

The shim wins because it preserves *one source-code shape* — `from utils.azure_file_storage import AzureFileStorageManager` — and lets the brainstem decide what that shape *means* at boot time.

## What this rules out

- ❌ Agent code that branches on tier. If an agent writes `if os.environ.get("LOCAL"):`, the shim has been bypassed and the agent is no longer portable.
- ❌ New module shims without a portability story. Every shim must answer: *what would an agent that uses this look like, and does it look identical across tiers?*
- ❌ Letting the local backend's API drift from the Azure API. The shim's value depends on the two backends being interchangeable. Drift breaks the deal.
- ❌ Adding shims that "feel useful." Each shim is a maintenance load. Three shims today is the right count, not because three is magic but because each one earned its place.

## When to add a new shim

The bar is high. New shims are justified only when:

1. There is an upstream module (Azure, Dynamics, Microsoft Graph, etc.) that agents would otherwise import directly.
2. That module's behavior in a local context can be faithfully reproduced with a small implementation.
3. Multiple agents would benefit, not just one.
4. The Tier 2 and Tier 3 deploy paths can transparently swap to the real module without agent edits.

If any of those is missing, the agent should access the underlying capability through `utils/` directly, not through a shim.

## Discipline

- Read `_register_shims()` before adding storage-adjacent code.
- Keep `local_storage.py` small. Every method added becomes a method the Azure backend must also satisfy.
- When testing agents in Tier 1, occasionally test under `LLM_FAKE=1` with no Azure creds — that's the proof that the shim is doing its job.

## Related

- [[Vendoring, Not Symlinking]]
- [[The Single-File Agent Bet]]
- [[Three Tiers, One Model]]
- [[The Deterministic Fake LLM]]
- [[Why Three Tiers, Not One]]
