# RAPP Survival Contract

> *"This needs to survive nuclear blasts, not tip over in a second."*
> — the operator, 2026-05-08

The platform's claim is local-first survival. This document **enumerates the failure modes**, **states what survives each one**, and **points at the test that verifies the claim**. If a row says ✓ but the test fails, that's a bug. If a row says ✗, that's an honest acknowledgment of where we don't have coverage yet.

## What survives what — verified contract

| Failure scenario | What survives | Why | Verified by |
|---|---|---|---|
| **One neighborhood repo deleted from GitHub** | ✓ all cached subscribers (read-only); ⚠ no new joins until a mirror appears | Brainstems hold local cache (`~/.brainstem/neighborhoods/<slug>/`). Reads continue against cache. | `tests/scenarios/15-offline-snapshot-dream-catcher.sh` |
| **`kody-w/RAPP` repo deleted** | ✓ already-installed brainstems; ✓ all 5 planted neighborhoods (they live as their own repos); ⚠ install one-liner needs a mirror URL | Each neighborhood is self-contained: own `basic_agent.py`, own `neighborhood.json`, own agents. The platform's substrate is GitHub, not RAPP-the-repo. | scenario 17 (survival) |
| **All `kody-w/*` repos deleted** | ✓ all cached + offline brainstems; ⚠ new operators need a mirror | Eggs are content-addressed and portable. Any operator can re-host. | scenario 17 (survival) |
| **GitHub Pages goes down** | ✓ everything except the gate UIs | Gates are just HTML; agents are Python files served via `raw.githubusercontent.com` (different subsystem). | manual: brainstem `/api/neighborhoods/*` works without Pages |
| **`raw.githubusercontent.com` goes down** | ✓ for cached state; ⚠ for fresh fetches | `cachedGhJson` returns last-cached value with a stale pill. | `cachedGhJson` test in `tests/run-tests.mjs` |
| **GitHub APIs go down** | ✓ for read against cache; ⚠ for write (PRs/Issues queue locally) | Membership organ uses cached `members.json`; sync defers until APIs return. | manual: `_verify_membership` returns offline reason gracefully |
| **GitHub entirely offline** | ✓ live WebRTC tethers; ✓ cached subscriptions; ✓ file:// local subscriptions | Tether bypasses GitHub once handshake done. file:// mode never touches GitHub. | scenario 13 (Charizard) + scenario 1 (local-on-device) |
| **Operator's brainstem dies (hardware lost)** | ✓ as long as a recent egg exists somewhere | Eggs are SHA-256 sealed cartridges. Any other brainstem hatches → identical organism, same rappid. **2026-05-10 family expansion:** the same `.egg` extension now carries 5 cartridge kinds (organism / rapplication / session / neighborhood / estate). The kernel `egg_hatcher_agent.py` introspects + routes by kind. **The estate cartridge** (`brainstem-egg/2.3-estate`, planned) is the disaster-recovery primitive for the operator's *whole multi-tier identity* — public discovery + private bones + on-device PII pointer all in one re-anchorable egg. See [SPEC §18.10](./pages/docs/SPEC.md). | scenario 13 (Charizard) + scenario 15 (offline snapshot) |
| **Internet entirely down** | ✓ for local-only neighborhoods + cached state | file:// subscriptions work offline. Local frame logs continue accumulating. Dream Catcher reconciles when back online. | scenario 1 (local-on-device) + scenario 15 (offline snapshot) |
| **Operator removed from a neighborhood** | ✓ network adapts (synthesis ships with what's home); past contributions remain | Synthesizer never blocks on absent contributors; removed-collaborator is identical to offline-now. | scenario 5 step 7 (adapt-to-whats-home) |
| **Half a neighborhood offline** | ✓ remaining members federate normally | Quorum defaults to 1; absent contributors don't block. | scenario 5 step 8–9 |

## The redundancy stack (defense in depth)

When the operator runs `brainstem join <neighborhood>`, the following copies materialize:

1. **In the brainstem's process memory** — agents are loaded fresh per request
2. **In `~/.brainstem/neighborhoods/<slug>/`** — cached file copy of seed contents
3. **On the brainstem's machine via git clone** (Phase 2: `brainstem sync` will full-clone)
4. **As an exportable egg** via `brainstem egg` — portable cartridge
5. **On GitHub** as the canonical version

A failure has to take out all five for the operator to lose access. Most operators have at least three concurrent copies at any time.

## The "RAPP itself goes down" answer

The single most common worry: *what if `kody-w/RAPP` itself goes offline?*

**Short answer:** the platform keeps running. The kernel is already installed on every operator's machine. Every neighborhood lives as its own GitHub repo. Eggs are portable. The only thing that breaks is the install one-liner URL — which can be rehosted at any mirror.

**Long answer:** the install path is `curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash`. If that URL 404s, the platform's *new-user onboarding* breaks. Existing users keep running. The install script + kernel can be re-served from any mirror — including any operator's own `~/.brainstem/installer/install.sh` (it's checked in alongside the kernel). This is why Constitution Article XXXV (License Stability) matters: licenses can only be relaxed; the install URL is sacred (Article V); kernel files are already mirror-replicated on every brainstem out there.

If GitHub itself goes down: WebRTC tethers + file:// subscriptions + local memory continue working. Operators can still trade eggs face-to-face. Dream Catcher resyncs when GitHub returns. The platform is degraded, not dead.

## What this document is NOT

- **Not a guarantee.** Specific failures may surface bugs. The contract is what we *intend* to survive, verified by the listed tests.
- **Not exhaustive.** New attack surfaces emerge with new features. This file is append-only — entries get added as we discover new failure modes.
- **Not infinite.** A determined adversary with enough resources can break any system. The contract is *survives common civic-scale outages*, not *resists nation-state APT*.

## How to test the contract

Run the survival scenario:

```bash
bash tests/scenarios/17-survival.sh
```

This walks through the rows above that are mechanically testable — verifies eggs hatch on disconnected brainstems, cached state continues serving when GitHub-equivalent operations are simulated offline, and frame logs accumulate locally.

## Where each failure mode is exercised

| Failure mode | Scenario file |
|---|---|
| Local-only operation | `tests/scenarios/01-local-on-device.sh` |
| Egg-based offline transfer | `tests/scenarios/13-charizard-in-the-woods.sh` |
| Neighborhood-as-egg + dimension merge | `tests/scenarios/15-offline-snapshot-dream-catcher.sh` |
| Adapt-to-whats-home synthesis | `tests/scenarios/05-braintrust.sh` (steps 7–9) |
| RAPP-offline + new-install path | `tests/scenarios/17-survival.sh` |

## The "neighborhood seeds in main RAPP repo" question

**Resolved 2026-05-08:** seeds do NOT live in this repo. Like a planted twin (e.g. `kody-w/heimdall`), every neighborhood is its own GitHub repo: `kody-w/microsoft-se-team-neighborhood`, `kody-w/public-art-collective`, `kody-w/braintrust-template`, etc. RAPP holds the **kernel + spec only** (the parent species root). If RAPP goes offline:

1. Live neighborhoods continue — they're independent repos
2. Template repos (`is_template=true` on GitHub) remain forkable
3. The kernel (already installed on every brainstem) keeps running
4. Only impact: install-one-liner URL needs a mirror

This is what makes the repo survive nuclear blasts: zero single-point-of-failure for any planted seed.

## Cross-references

- [`MASTER_PLAN.md`](./MASTER_PLAN.md) — the first-principles north star (local-first is non-negotiable)
- [`DEFINITION_OF_DONE.md`](./DEFINITION_OF_DONE.md) — verification discipline
- [`HERO_USECASE.md`](./HERO_USECASE.md) — the canonical scenarios this contract serves
- [`pages/vault/Field Notes/2026-05-08 — Adapt-to-whats-home is the only consensus protocol that scales off-grid.md`](./pages/vault/Field%20Notes/) — distributed-systems framing
