# Dreamcatcher Conformance Suite

> *Public test suite for any merge engine claiming compatibility with the Dreamcatcher reconciliation pattern. The Dreamcatcher engine itself (in `kody-w/rappter`) is a Wildhaven trade secret; this suite is the public contract any compatible implementation must satisfy.*

## Purpose

The swarm-estate protocol's open seam (`/eggs/assimilate`, `/eggs/summon`, the egg cartridge format) is publicly specified. The merge engine that reconciles divergent twin streams is private. Without a conformance suite, any third party claiming "compatible Dreamcatcher implementation" can ship arbitrary semantics — including buggy or malicious ones — without anyone being able to verify their claims.

This suite is the verification layer. An implementation is *conformant* if it produces the canonical merged state for every test case below.

## Test case shape

Each test case is a directory under `cases/<case-name>/`:

```
cases/
  001-empty-merge/
    README.md            # describes the scenario
    base.json            # the common ancestor state
    ours.json            # local divergent state
    theirs.json          # incoming divergent state
    expected.json        # the canonical merged state
    rationale.md         # why expected.json is correct
```

A conformant implementation, given `(base, ours, theirs)`, must produce a state byte-equivalent to `expected.json`.

## Categories of test cases

### Category A — Trivial cases

These exercise the basic merge logic.

- `001-empty-merge`: base, ours, theirs are all `{}`. Expected: `{}`.
- `002-no-divergence`: ours = theirs (both diverged identically). Expected: ours/theirs.
- `003-only-ours-changed`: theirs = base, ours has changes. Expected: ours.
- `004-only-theirs-changed`: ours = base, theirs has changes. Expected: theirs.

### Category B — CRDT-aware merges

These exercise the type-aware merge semantics.

- `010-monotonic-set`: memory-style fields where union is correct. Expected: union of ours and theirs.
- `011-last-write-wins`: settings-style fields where most recent wins. Expected: based on `updated_at` timestamps.
- `012-counter-sum`: numeric counters that accumulate. Expected: `ours + (theirs - base)`.

### Category C — Conflict resolution

These exercise the disagreement-handling.

- `020-different-values-same-key`: both edit same field to different values. Expected: documented per type.
- `021-deletion-vs-modification`: one side deletes, other modifies. Expected: documented (typically modification wins).
- `022-renames`: structural rearrangement. Expected: documented.

### Category D — Frame-level scenarios

These exercise frame replay semantics specific to twin egg merging.

- `030-replay-no-duplicates`: incoming frames already present locally. Expected: no duplication.
- `031-replay-respects-order`: incoming frames must be applied in their virtual-time order.
- `032-cross-incarnation-attribution`: provenance preserved per stream_id.

### Category E — Adversarial cases

These exercise behavior under attacker-supplied inputs.

- `040-malformed-json`: incoming state has invalid JSON. Expected: reject with documented error.
- `041-signature-mismatch`: incoming state's signature doesn't verify. Expected: reject before merge.
- `042-rappid-mismatch`: incoming state claims a different RAPPID. Expected: reject before merge.

## How to run the suite

```bash
# Reference runner (Python; reads cases/ and shells out to your implementation)
python3 tests/dreamcatcher-conformance/runner.py --engine /path/to/your/dreamcatcher

# Wildhaven's canonical engine: run against this suite, must pass all cases
# (Suite is public; engine is private; all are testable.)
```

The reference runner is in this directory; the test cases will be filled in over time.

## Status

**This is a skeleton.** Test cases are not yet populated. The suite exists at this path so that:
1. Third parties can fork and contribute test cases
2. The directory structure is reserved (no namespace squatting)
3. Wildhaven can publish a complete suite over time without retroactively claiming the path

Conformance for any specific implementation requires the suite to be complete, which it is not yet. Treat this as defensive prior art for now: the *contract* exists publicly, even if the test cases are still being written.

## Why this exists

If [Trigger T1, T2, or T3 in the Wildhaven Foundation's release-triggers](../../../wildhaven-ceo/blessings/144d673475618dfbc9710e999e7d2907/release-triggers.json) (private) fires, the Dreamcatcher engine source becomes Apache-2.0 public domain. At that moment, the conformance suite is what lets the network verify that a published engine matches the specification. Without the suite, "released to public domain" doesn't guarantee compatible behavior across implementations.

This suite is the **interoperability commitment**, separate from the engine release. It can — and should — be populated *before* any release-trigger fires.

## Related

- [Local-First-by-Design](../../pages/vault/Architecture/Local-First-by-Design.md) — context for why merge matters
- [The Swarm Estate](../../pages/vault/Architecture/The Swarm Estate.md) — protocol spec including the open seam
- [Twin-Patterns](../../pages/vault/Architecture/Twin-Patterns.md) — what a divergent twin stream looks like
