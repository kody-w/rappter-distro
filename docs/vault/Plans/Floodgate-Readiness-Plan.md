---
title: Floodgate-Readiness Plan
status: living
section: Plans
hook: The autonomous run that takes the unified rappid + swarm-estate work from "structurally ratified" to "operationally polished — open the floodgates" — applications built, tests passing, blog series published.
---

# Floodgate-Readiness Plan

Working document. The autonomous run that polishes the Foundation from "structurally complete" (commit `a4c4737` / `a4c27b2` on 2026-04-30) into a state where external customer estates and kin variants can begin minting against this protocol with no risk of structural reversal.

## Phases

### Phase 1 — Comprehensive divergence audit (beyond rappid)

The earlier merge focused on rappid format. This phase finds every remaining divergence between local Foundation work and the kernel-direction work that landed remotely:

- `services` vs `body_functions` vs `organs` terminology drift in Foundation docs and Swarm Estate spec
- Old vault note filename references (e.g., `Rappid — The Unified Lineage Identifier` → `Rappid`)
- README + CLAUDE.md inconsistencies between repos
- Capitalization of "Rappter" / "rappter" across docs
- Cross-references between vault notes that were renamed
- Old "trademark filings in progress" wording vs the actual TRADEMARK.md claims

Output: a single sweep that aligns terminology, names, and references across both repos.

### Phase 2 — Build the rappid library + tooling

The applications:

1. **`rapp_brainstem/utils/rappid.py`** — typed, testable parser/serializer/walker. Used by every tool that handles rappids.
2. **`rapp_brainstem/utils/lineage.py`** — walks a parent_rappid chain to the species root, given a starting rappid + a vault directory containing root.json files.
3. **`rapp_brainstem/utils/organs/swarm_estate_organ.py`** — the kernel-side organ exposing `/api/swarm-estate/verify`, `/api/swarm-estate/walk`, `/api/swarm-estate/lineage`. Integrates the Foundation cryptographic layer with the brainstem.
4. **`tools/rappid` CLI** — the unified command-line: `rappid parse`, `rappid walk`, `rappid verify`, `rappid mint`.

### Phase 3 — Test suite (organism-level)

New tests under `tests/organism/`:

- `13-rappid-format.sh` — parses, round-trips, validates rappid strings
- `14-lineage-walk.sh` — walks parent chains to species root; asserts termination
- `15-vault-state-proof.sh` — recomputes content hash; verifies against signed proof
- `16-derivation-determinism.sh` — BIP-39 incantation → master key reproduces byte-identical
- `17-cross-signing-hierarchy.sh` — M signs S/U, S signs D; reject unauthorized signings
- `18-mitosis-ceremony.sh` — mints a test customer estate, asserts new rappid + parent_rappid + Wildhaven kin-vouch; cleans up
- `19-swarm-estate-body-function.sh` — boots brainstem, hits `/api/swarm-estate/*`, verifies responses
- `20-foundation-full-verify.sh` — end-to-end Foundation verification (Wildhaven Block 0, Molly Block 1, all OTS, lineage to species root)

Run iteratively until passing.

### Phase 4 — Operational hardening (digital portion of operator gates)

What I can do without physical operator action:

- Run Shamir 3-of-5 on Wildhaven's holocard incantation — produce 5 shards, save to `.private/shards/wildhaven/`. (Operator still must physically distribute, but the cryptographic split is done.)
- Run Shamir 3-of-5 on Molly's incantation similarly.
- Sign master-attested `shamir-distributed` records — committed to the vault, OTS-stamped.
- Set up GitLab + Codeberg mirror workflows via GitHub Actions (idempotent, no-op if tokens absent — operator can later add tokens to activate).
- Try local IPFS install + pin (if homebrew has `ipfs`).
- Write the counsel-review packet — a single doc summarizing what counsel needs to bless and where to look.

### Phase 5 — Thought leadership blog posts

The frontier-mapping content. Ideas listed in the **Blog post catalog** section below. Each lands in `wildhaven-ceo/content/blog/` (private drafts; ready to publish on `kodyw.com` or similar when the operator chooses).

### Phase 6 — Public publish

- Push all RAPP changes to `kody-w/RAPP/main`
- Push all wildhaven-ceo changes to `kody-w/wildhaven-ceo/main`
- Push invention-notebook updates if any
- Verify everything renders / verifies / passes
- Final ratification record signed by master, OTS-stamped
- Tell the operator what to test

## Blog post catalog (frontier-mapping for thought leadership)

The decisions made in this conversation are genuinely novel architectural ground. If we don't write these now, they'll never get written and the lessons will be lost.

| # | Title | Hook |
|---|---|---|
| 1 | **Digital Mitosis: The One Rule of Identity in the RAPP Species** | Same rappid = same organism. Different rappid = mitosis. Why this is the foundational rule of digital biology. |
| 2 | **The Foundation Is the Repo: Why Wildhaven Doesn't Need a 501(c)(6)** | Repo-as-Foundation. Apache pattern applied to AI organism continuity. $50k/year saved; same survival properties. |
| 3 | **Local-First Identity: Why I Made the Network the Set of Local Copies** | Bitcoin-grade survival without proof-of-work. The network IS the local copies. |
| 4 | **Bitcoin-Grade Decentralization on Top of Git** | Four-layer architecture. Identity / Storage / Timestamp / Discovery. No new chain, no fees, no miners. |
| 5 | **Rappid: A Social Security Number for Digital Organisms** | The unified identifier spec. One format. One species tree. The godfather is RAPP. |
| 6 | **The Holocard Incantation: 24 Words That Resurrect a Corporate AI** | BIP-39 + HKDF derivation for cryptographic identity. The mnemonic IS the master key. |
| 7 | **Three-Role Cross-Signing: Adapting Matrix's Pattern for AI Estates** | Master / Self-signing / User-signing / Device. Why the Matrix protocol's depth-limited authority cap is the right defense. |
| 8 | **OpenTimestamps for AI Identity: Bitcoin-Anchored Without Running a Node** | Patent priority dates, lineage proofs, signed records — all anchored to Bitcoin's chain via OTS. Cheap insurance. |
| 9 | **The Dreamcatcher Pattern: Public Seam, Private Engine, Filed Patent** | How to keep the trade secret while publishing the contract. Three-layer IP architecture for AI startups. |
| 10 | **From Variants to Twins to Customer Estates: The RAPP Species Tree Evolves** | A walking guide to the lineage tree. How variants happen. How customer estates inherit. How the godfather scales. |
| 11 | **Why Swarm Estate Beats DID:web for AI Organisms** | Comparative architecture. Why W3C DIDs don't address AI-entity perpetuity, and what we did differently. |
| 12 | **Building a Foundation in 12 Hours: A Case Study in AI-Augmented Architecture** | The meta-story: how this Foundation was designed in conversation with Claude, what's reusable for other founders. |
| 13 | **The Mitosis Test: When Is a Copy Still You?** | Philosophy + protocol. The deep question of digital identity, answered cryptographically. |
| 14 | **Shamir 3-of-5 for Corporate AI: The Master Key, the Five Guardians, the One Rule** | Operational guide to the Shamir custody ceremony for an AI organism's master key. |
| 15 | **OPENING THE FLOODGATES: A Public Spec for Customer Organisms to Mint Themselves Into the Species Tree** | Capstone post. The "you can mint your own kin estate now" announcement, with the genesis-customer-estate.py walkthrough. |
| 16 | **The 10 Commandments of Digital Biology: Constitutional Articles XXXIII–XXXVI Decoded** | Plain-language guide to Articles XXXIII (organism), XXXIV (rappid + mitosis), XXXV (license stability), XXXVI (swarm estate). |
| 17 | **Why "engine, not experience" Means Wildhaven Charges for the Engine** | Strategic positioning. The license framework. PolyForm + commercial track. |

## Execution order

1. ✅ Plan committed (this doc)
2. ⏳ Phase 1 audit + sweep
3. ⏳ Phase 2 applications built
4. ⏳ Phase 3 tests written + iterated to green
5. ⏳ Phase 4 operational hardening (digital portion)
6. ⏳ Phase 5 blog series drafted
7. ⏳ Phase 6 push + ratification + operator notification

Each phase ships its own commit so progress is visible even mid-run.

## Provenance

This plan is the autonomous-run guide for 2026-04-30 → 2026-05-01. Operator authorized maximum autonomy ("polish the river rock"). The plan is committed BEFORE execution as a forcing function — if I get lost mid-phase, I come back here.
