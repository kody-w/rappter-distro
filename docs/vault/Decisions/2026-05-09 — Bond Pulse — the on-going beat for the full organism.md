# Bond Pulse — the on-going beat for the full organism

**Date:** 2026-05-09
**Status:** Adopted — first heartbeat shipped

## What this is

The **Bond Pulse** is the on-going beat that keeps the FULL organism in
alignment. Not just one body part — the organism is BOTH halves at once:

> **Global body** — the GitHub-substrate offspring repos
> (`kody-w/ant-farm`, `heimdall`, `microsoft-se-team-neighborhood`,
> `public-art-collective`, `private-workspace-template`,
> `braintrust-template`, `RAR`, `RAPP_Store`, `RAPP_Sense_Store`,
> `rapp-egg-hub`, `rapp-installer`)
>
> **Local body** — the operator's brainstem at `~/.brainstem/`
> plus the local RAPP repo

One organism, two body parts, one heartbeat. Each pulse reconciles them.
When connection drops the heart keeps beating local-only; when
connection returns, the next pulse catches the body up.

## Operator's framing (load-bearing)

> *"this is like the digital organism pulsing from its global body to
> the edge parts of its body and back again in a loop to keep them
> aligned when it is possible (connection is available)"*
>
> *"you can call this the on-going Bond Pulse: Bond Rhythm — local↔global
> on a beat pulse for the FULL organism (global + local)"*

The metaphor is the contract. Every implementation choice routes back
through it: heartbeat (not poll), pulse (not request), full organism
(not "the local copy" or "the deployment").

## Architecture — four pieces

The Bond Pulse is one heartbeat made of four pieces:

| Piece | File | Role |
|---|---|---|
| **Contract** | `tools/ecosystem_contract.py` | Pure data. Per-kind expectations: what files MUST exist for each of the 9 offspring kinds (neighborhood, ant-farm, twin, workspace, braintrust, catalog, template, installer, egg-hub). Zero behavior. |
| **Detector** | `tools/ecosystem_audit.py` | Stdlib-only drift detector. Reads `pages/metropolis/index.json` → diffs each offspring against the contract → emits `rapp-ecosystem-audit/1.0`. CLI: `--offline` (default; uses fixtures), `--online` (gh api + raw fetches). Exit 1 on drift. |
| **Actuators** | `launch_to_public_agent.py` (LOCAL→GLOBAL push), `graft_neighborhood_agent.py` (LOCAL→GLOBAL push, additive), `rar_loader_agent.py` (GLOBAL→LOCAL pull) | The three muscles. Each uses the bond technique (egg → overlay → hatch back; preserve-local) so neither side ever clobbers the other. |
| **Heartbeat** | `bond_rhythm_agent.py` | The pulse itself. Calls audit subprocess → classifies drift as `LOCAL_TO_GLOBAL` / `GLOBAL_TO_LOCAL` / `INFORMATIONAL` → SUGGESTS which actuator to invoke (operator-mediated; never auto-executes) → records `kind="rhythm"` event in `~/.brainstem/bonds.json` → returns `rapp-rhythm-pulse/1.0`. Default `dry_run=True` (and dry_run is enforced — the rhythm itself never actuates). |

## Why operator-mediated (never auto-execute)

The heartbeat detects, classifies, and SUGGESTS. The operator decides
whether to push (Launch / Graft) or pull (RarLoader). Three reasons,
each load-bearing:

1. **Auto-actuation is the wrong default for the FULL organism.**
   When global + local diverge, "who's right" is a judgment call only
   the operator can make. The audit knows what's different; only the
   operator knows what's RIGHT.

2. **Connection-aware degradation requires human latency anyway.**
   If the pulse runs while offline, it captures local state and
   suggests catch-up actions for "next pulse with connection." That
   queue is meaningless if a different process is already firing
   actuators in the background.

3. **The actuators all use the bond technique already.** They preserve
   local mutations, write append-only bond events, and refuse to
   clobber upstream. Auto-firing them isn't UNSAFE — it just dilutes
   the audit trail with rhythm-driven events that the operator never
   chose. Operator-mediated keeps `bonds.json` honest.

## Connection-aware degradation

The pulse is OPPORTUNISTIC, not REQUIRED. Pseudocode:

```
def pulse_once(allow_online=False):
    audit = run_audit(online=allow_online)            # may fail / timeout
    if audit_failed:
        degraded = True
        audit = empty_envelope                         # 0 offspring, 0 drift
    classify(audit) → suggested_actions
    record bonds.json event(kind="rhythm", degraded, drift_count, ...)
    return rapp-rhythm-pulse/1.0 envelope
```

Result: the pulse always returns a valid `rapp-rhythm-pulse/1.0`
envelope. `degraded=True` flags "I couldn't see the global body this
time." The next pulse with connection sees full state and the body
catches up — no data loss, no clobbering.

## Same architectural primitive as Dream Catcher / Docking / Graft

The Bond Pulse is the SAME primitive as Dream Catcher
(frame scope), Docking (registry scope), and Graft (neighborhood
scope) — applied at the **organism scope**:

> **Preserve a long-evolved local mutation; bring it back into the
> wider structure additively; record the act in an append-only log;
> never destroy what was already there.**

Where Graft handles a single neighborhood-within-a-repo and Dream
Catcher handles a single frame-within-an-organism, Bond Pulse handles
the WHOLE organism — both halves at once, on a beat, indefinitely.

| Scope | Operation | Frequency |
|---|---|---|
| Frame | Dream Catcher | when a contradiction is reassimilated |
| Neighborhood | Graft | when a new neighborhood is planted on a repo |
| Registry entry | Dock | when a new entry is added to any rar-shaped JSON |
| File / install | RarLoader | when a planted seed needs its participation kit |
| Pheromone | Ant | when state changes mid-loop |
| **Organism (global + local)** | **Bond Pulse** | **on-going beat — every pulse, on connection** |

## Vocabulary discipline

- The **WORK** is named "Bond Pulse" so the metaphor (heartbeat for
  the full organism) leads in user-facing copy.
- The **AGENT class** is `BondRhythmAgent`. (Codebase loves precision;
  "rhythm" is what the agent does — pulses on a rhythm.)
- The **bond event kind** is `"rhythm"` (added to `bond.py` line 840
  alongside `birth/bond/adoption/hatch/graft/launch/rhythm`).
- The **schema** is `rapp-rhythm-pulse/1.0` (the pulse output
  envelope).

If you say "heartbeat for the full organism" in conversation, you mean
Bond Pulse. If you say "pulse_once" or "the rhythm agent" in code, you
mean `BondRhythmAgent`. Both halves are required — the metaphor + the
class name — to keep the ANTIPATTERNS §1 vocabulary discipline.

## What ships in this PR

- `tools/ecosystem_contract.py` (~250 lines) — pure-data contract, 9 kinds
- `tools/ecosystem_audit.py` (~470 lines) — stdlib-only detector
- `rapp_brainstem/agents/bond_rhythm_agent.py` (~280 lines) — the heartbeat
- `tests/features/F10-ecosystem-audit.sh` (10/10 passing) — detector conformance
- `tests/features/F11-launch-to-public.sh` (9/9 passing) — LOCAL→GLOBAL actuator
- `tests/features/F12-bond-rhythm.sh` (10/10 passing) — heartbeat conformance
- 6 bare-UUID rappid migrations in `pages/metropolis/index.json` + the
  `local-only-test` fixture (so the audit goes 1→0 drift in this PR)
- `bond.py:840` choices list gains `"launch"` + `"rhythm"`
- `tests/features/run.sh` + `tests/osi/run.sh` wire F10/F11/F12 in

## What's NOT in this PR (deliberate scope)

1. **Auto-execution of suggested actions.** The rhythm agent SUGGESTS
   only. A future executor agent could consume `suggested_actions[]`
   and dispatch — separate PR, requires explicit operator opt-in.
2. **Fix-PR generation against offspring repos.** The audit detects
   drift but never writes outside RAPP. A `--fix-pr` flag is a future
   capability requiring `gh` write auth + dry_run safety nets.
3. **`perpetual_loop_factory` integration.** Wrapping
   `BondRhythm.pulse_once` as a perpetual loop (every N minutes) is
   the obvious next step but adds scheduler-state concerns. Operators
   compose this manually for now.
4. **Live online audit in CI.** F10 runs `--offline` against fixtures
   only. CI fragility (rate limits) makes live runs unsafe for the
   gate. Operators run `--online` locally.
5. **Cross-tracker federation in the audit.** Audit reads
   `pages/metropolis/index.json` only, not `federated_trackers[]`.
   Federated audit belongs in a separate `BondRhythmFederated` agent.

Each "out of scope" item is intentional — adding any of them now
weakens the operator-mediated property, which is the most important
property of the Bond Pulse.

## Cross-references

- `pages/vault/Decisions/2026-05-09 — Dream Catcher and Docking are the same operation.md`
  — the prior vault note that documented the same primitive at smaller
  scopes; Bond Pulse is the same primitive at organism scope
- `MASTER_PLAN.md` — Part 1 §1 (kernel sacred); the heartbeat lives in
  `agents/`, never in the kernel
- `CONSTITUTION.md` Article XXXIII — DNA / brainstem / organs /
  agents; the heartbeat is an agent
- `ECOSYSTEM_MAP.md` §5 (schemas), §6 (file map), §11 (decision table)
  — all updated in this PR
