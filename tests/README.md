# `tests/` — Cross-tier test runner

The contract checks that prove the engine still honors what `pages/docs/SPEC.md`
says. Cross-tier in scope: anything tier-internal lives in that
tier's own directory.

## What's here

### Top-level test runners

| File | What it runs |
|---|---|
| `run-tests.mjs` | The Node.js JS test suite. Validates SPEC §5 (single-file agent contract), card minting / mnemonic seed round-trips, binder, parser, multi-agent `data_slush` chain, and digital-twin layout file presence. **No deps** — `node tests/run-tests.mjs`. |
| `e2e/` | Shell-driven end-to-end tests. One script per scenario; each script is self-contained and self-documenting via its header. |

### Existing e2e scenarios (`tests/e2e/*.sh`)

| Script | Scenario |
|---|---|
| `06-oneliner-install.sh` | Curls the public install one-liner and verifies a clean install in a temp dir |
| `08-html-pages.sh` | Checks every page in `pages/` plus the root `index.html` and `pitch-playbook.html` for required meta tags, canonical URLs, og fields |

(See `e2e/README.md` for the full enumeration.)

### Standalone shell tests

A handful of focused shell tests live at `tests/<name>.sh` (e.g.
`test-sealing-snapshot.sh`, `test-hero-deploy.sh`, `test-llm-chat.sh`,
`test-t2t-removal.sh`). These predate the `e2e/` convention and are
kept where they are because their names are referenced from elsewhere.
**New shell tests go in `e2e/`.**

## What belongs here

A test belongs in `tests/` when:

1. **It's cross-tier.** It checks a contract that spans multiple
   tiers, the wire shape, the install surface, or static repo
   structure. Tier-internal unit tests live next to their tier's
   code (`rapp_brainstem/test_local_agents.py`, etc.).
2. **It runs without setup hacks.** The JS suite needs only Node;
   shell tests need `bash`, `curl`, and (optionally) the things
   they explicitly install. No long-lived fixtures, no ambient
   state required.
3. **A failure means a contract regressed.** Tests here are
   load-bearing for the v1 spec, the install one-liner (Article V),
   the page surface, or the agent file format.

## What does NOT belong here

- ❌ **Tier-specific unit tests.** Brainstem-only Python tests are
  `rapp_brainstem/test_local_agents.py`. Swarm-only tests live in
  `rapp_swarm/`. Don't drag tier internals into the cross-tier
  runner.
- ❌ **One-off scripts dressed as tests.** A debugging shell file
  that prints stuff isn't a test — tests assert. If it doesn't
  fail when something's wrong, it's not in `tests/`.
- ❌ **Tests that depend on credentials or external services.**
  The default suite must run on a fresh checkout with no auth.
  Provider-touching tests use `LLM_FAKE=1` (the deterministic fake)
  rather than real LLM calls.
- ❌ **Mocked-database tests.** Per the user's standing rule on
  this repo, integration tests hit real storage, not mocks (a
  mocked test once passed while the prod migration was broken).
  Use the local JSON-file shim — that's "real storage" for Tier 1.

## Conventions

- **Run all tests with `node tests/run-tests.mjs`.** That's the
  single command that validates the SPEC §5 contract end to end.
  Shell e2e scenarios run individually: `bash tests/e2e/06-oneliner-install.sh`.
- **Test files reference paths via the `ROOT` constant** (in
  `run-tests.mjs`). When the repo layout changes, only `ROOT`-rooted
  paths need updating. Don't hardcode `./SPEC.md` — write
  `path.join(ROOT, 'docs', 'SPEC.md')`.
- **e2e scripts are self-contained.** Each one has a header
  describing what it tests, the expected pass condition, and how to
  run it locally. No shared `lib/` to import from — copy the helper
  if two scripts need it.
- **A new test never silently changes coverage.** When you add an
  assertion to `run-tests.mjs`, add a label to the suite header so
  the test list stays grep-able.

## Scale rule

When you're about to add a test here:

1. *Is this checking a contract from `pages/docs/SPEC.md`,
   `CONSTITUTION.md`, the install URL, or the static page
   surface?* Yes → `tests/`. No → tier directory.
2. *Does it run with no auth and no external service?* Yes →
   `tests/`. No → reconsider, or gate behind an env var.
3. *Is it a JS contract check or a shell e2e scenario?*
   - JS contract → add to `run-tests.mjs` in the right Suite block.
   - Shell e2e → add to `e2e/` with a 2-digit prefix (next number
     in sequence).

## Known stale fixtures

- `run-tests.mjs` references `save_memory_agent.py` and
  `recall_memory_agent.py` which were merged into `manage_memory_agent.py`
  long ago (see [[From save_recall to manage_memory]] in the vault).
  The test fixtures haven't been updated. **This is the next thing
  to fix in this directory.**

## Related

- v1 contract being tested: [`../pages/docs/SPEC.md`](../pages/docs/SPEC.md).
- Install one-liner being tested:
  [`../CONSTITUTION.md`](../CONSTITUTION.md) Article V.
- Page surface being tested: `../pages/README.md`.
