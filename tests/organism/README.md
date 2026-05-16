# tests/organism — Wild-encounter fixtures

> Per Constitution Article XXXIII §3: every wild-encounter that breaks the kernel's drop-in promise becomes a permanent fixture in this directory. The suite is the species' immune memory.

Each test exercises the digital-organism architecture against a real or synthetic mutation shape. Tests must:

- Be runnable in isolation (each test cleans up after itself).
- Use a temporary `HOME` so `~/.brainstem/rappid.json` from the developer's actual organism is never touched.
- Exercise additive-only fixes (no kernel edits).
- Cover the canonical kernel and its sibling deps as a unit.

## Running

From the repo root:

```bash
bash tests/organism/run-all.sh           # run every fixture
bash tests/organism/01-canonical-kernel-boots.sh
bash tests/organism/02-fixture-01-local-storage.sh
bash tests/organism/03-rappid-birth.sh
bash tests/organism/04-generation-hatch-revert.sh
```

## Fixtures

| File | What it asserts | Vault note |
|---|---|---|
| `01-canonical-kernel-boots.sh` | The canonical kernel boots from the repo, `/health` returns 200, six agents are loaded, `/version` matches `VERSION` file. | Article XXXIII §3 |
| `02-fixture-01-local-storage.sh` | The top-level `local_storage.py` shim resolves; the kernel boots; the import path is kernel-sibling, not mutation-surface. | [Fixture 01](../../pages/vault/Fixtures/Fixture%2001%20—%20Canonical%20Kernel%20local_storage%20Drop-In.md) |
| `03-rappid-birth.sh` | `hatchling stamp` writes a fresh `rappid.json` with parent_rappid pointing at the repo's `rappid.json`; running again is idempotent. | Article XXXIV §1 |
| `04-generation-hatch-revert.sh` | Generation tags are created; the clutch lists them; `revert` checks out a prior generation; the egg of generation N persists across the cycle. | Article XXXIII §2 |

## Adding a fixture

When you encounter a real-world drop-in failure:

1. Reproduce it in a temporary fixture environment (use `mktemp -d` for the org root).
2. Capture the **shape**, not the specific bug. The shape is what makes the fixture permanent.
3. Add a vault note under `pages/vault/Fixtures/` describing the encounter.
4. Add a `0N-*.sh` test under this directory that replays the shape and asserts the expected outcome.
5. Update the table above.

Fixtures are forever. Once recorded, they run on every change to the kernel or its siblings, indefinitely.
