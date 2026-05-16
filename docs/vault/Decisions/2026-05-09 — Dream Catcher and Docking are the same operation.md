# Dream Catcher and Docking are the same operation at different scopes

**Date:** 2026-05-09
**Status:** Adopted as design-by-emergence framing

## What this is

The graft operation introduced today (`graft_neighborhood_agent.py`) is
the **docking** primitive at the neighborhood-within-a-repo scope. It is
the same operation the Dream Catcher (`installer/plant.sh::dream_catcher`
+ ECOSYSTEM §10) does at the frame-within-an-organism scope.

| Property | Dream Catcher (frame scope) | Docking / Graft (neighborhood scope) | Bond cycle (kernel scope) | DockAgent (registry scope) | rar_loader (file/install scope) | ant_agent (pheromone scope) |
|---|---|---|---|---|---|---|
| Unit | one `rapp-frame/1.0` | one neighborhood (rappid + agents + rar/) | the entire kernel (brainstem.py + agents/) | one entry inside any rar-shaped JSON | one agent/organ/sense file (sha256-verified) | one `rapp-pheromone/1.0` |
| Container | a planted organism | a single GitHub repo | a brainstem install on one machine | any list-of-dicts JSON registry | the local brainstem's `agents/`/`organs/`/etc. | `ant-pheromone`-labeled GitHub Issues |
| Identity preserved | yes — content-addressed `hash` | yes — each neighborhood's `rapp-rappid/2.0` | yes — `~/.brainstem/rappid.json` | yes — `key_field` dedup (default `name`; supports `sha256`) | yes — sha256 must match published manifest | yes — content-addressed via `hash` + `prev_hash` chain |
| Merge rule | UTC-first canon; same `(utc, frame_n)` different content → contradiction (preserved) | additive only — sha256-verified; existing files preserved; new files added | additive only — `unpack_organism` preserves any file the egg doesn't mention | additive only — duplicate `key_field` SKIPPED, never overwrites | additive only — install only if file absent OR sha256 matches | additive only — every pheromone is a new Issue |
| Append-only log | `data/frames.json` (chain via `prev_hash`) | `_metropolis.json` (entries[]) + `bonds.json` (events[]) | `bonds.json` (events[]) | `bonds.json` event kind="dock" | (the install IS the log) | the GitHub Issues list IS the log |
| Operator control | reassimilation Issue (label: `dream-catcher`) | re-grafting (event kind: `graft`) | re-running install one-liner (event kind: `bond`) | calling DockAgent.perform | calling RarLoader.perform | calling Ant.perform |
| Lost data? | never — contradictions preserved as alternate-dimension data | never — `bond_preserve_local` block + restore-from-backup if anything clobbered | never — `unpack_organism`'s "additive on the kernel side" property | never — duplicates skipped; pre/post sha256 stamped | never — sha256 mismatch refuses install | never — Issues are immutable; "closed" pheromones are still in history |
| Cross-scope chain | each frame → its parent in `prev_hash`; back to the organism's first frame | each neighborhood → species root via `parent_rappid`; up to global metropolis via `_metropolis.json.federated_trackers` | each install → its parent kernel commit via `parent_commit` in rappid.json | the dock event records pre/post sha256 | the rar/index.json chains back to its emitter | each pheromone's `prev_hash` → previous in chain |

All three are instances of the same architectural primitive:

> **Preserve a long-evolved local mutation; bring it back into the wider
> structure additively; record the act in an append-only log; never
> destroy what was already there.**

## Why this matters

The fractal isn't decoration — it's load-bearing. When an operator
"reestablishes active control" of a long-evolved local neighborhood,
they don't have to choose between "wipe and re-plant" vs "leave alone
forever." The docking pattern (= graft) gives them a third option:
**merge the latest global estate scaffolding back in, additively, with
the local organism intact.**

This is the same third option the Dream Catcher gives an operator
returning to a parallel-dimension egg. And the same third option the
bond cycle gives an operator running the install one-liner against a
locally-customized kernel. **One technique, three scopes.**

## How this surfaces in the agent

`graft_neighborhood_agent.py` emits a `docking` block in its
`rapp-graft-result/1.0` envelope when the graft lands in a repo that
already has a neighborhood. The block names the parallel:

```json
{
  "docking": {
    "is_docking": true,
    "docked_neighborhoods": ["second-neighborhood", "third-neighborhood"],
    "preserved_local_neighborhoods": ["first-town"],
    "parallel_to_dreamcatcher": {
      "dream_catcher_scope": "frame within an organism (rapp-frame/1.0 chain)",
      "docking_scope": "neighborhood within a repo (rapp-rappid/2.0 each)",
      "shared_property": "additive, content-addressed, append-only, identity preserved"
    }
  }
}
```

The test (`tests/features/F8-graft.sh` step 9c2) verifies the block
appears + has the expected shape — so this framing is enforced, not
just documented.

## Design-by-emergence

Operators don't pre-plan whether their repo will hold one neighborhood
or twenty. They graft, observe, graft again, watch what emerges. Town →
city → metropolis growth happens because the substrate enforces blind-
safe overlay at every step. The structure is the cumulative result of
operator decisions over time, not a top-down architecture document.

This is exactly the property Dream Catcher gives at frame scope: the
operator doesn't pre-plan which mutations stay local vs. bond back to
canon. They observe the local frame log; pick what's worth bonding;
reassimilate via PR.

Same property. Different scope. Same primitive.

## How things literally "grow" in these repos

> *"this is how things will literally grow in these repos"* — operator,
> 2026-05-09

The dock-without-destruction primitive is the **growth mechanism** of a
RAPP digital organism — at every scale of the fractal:

```
   one cell (a single agent.py)
        │  add another agent → dock into agents/ (sha256-verified)
        ▼
   multi-cell (multiple agents in one brainstem)
        │  add a brainstem.py → dock as neighborhood at root
        ▼
   single brainstem (one brainstem.py + tiny scaffolding = neighborhood)
        │  add another neighborhood → dock into neighborhoods/<name>/
        ▼
   town (root neighborhood + sibling neighborhoods)
        │  add more siblings → _metropolis.json grows
        ▼
   city (multi-neighborhood repo as self-contained metropolis)
        │  federate to other repos via federated_trackers
        ▼
   metropolis (this repo + N other federated repos)
        │  metropolises mesh through shared neighborhoods
        ▼
   global swarm (the operator's full estate across many repos)
```

At every step the same primitive applies:

- **Read** the existing state (egg the local mutations).
- **Add** new content additively (overlay).
- **Verify** nothing was clobbered (hatch back the egg if it was).
- **Log** the addition in an append-only ledger (bonds.json + _metropolis.json + …).

This is what `dock_agent` makes generic: any rar-shaped registry, any
list-of-dicts JSON file, any append-only ledger gets the same property
for free. Together with the per-scope dockers (`ant_agent`,
`rar_loader_agent`, `graft_neighborhood_agent`, `bond.py`, Dream Catcher),
the entire RAPP stack supports growth-without-destruction at every level.

**The repo doesn't get architected. It grows.**

## Related

- `installer/plant.sh` — write_rar_index (sha256-verified per-seed RAR)
- `rapp_brainstem/utils/bond.py` — kind="graft" added to record-bond
- `rapp_brainstem/agents/graft_neighborhood_agent.py` — the docking implementation
- `tests/features/F8-graft.sh` — 13/13 conformance including the docking-semantic test
- ECOSYSTEM.md §10 — Dream Catcher original spec
- HERO_USECASE.md §2 — the parallel-dimension reassimilation use case
- ECOSYSTEM_MAP.md §6 — the universal-RAR + graft agent rows
