---
title: Release Ledger
status: living
section: Plans & Ledgers
type: ledger
hook: Append-only log of what has shipped — the platform's institutional memory in operational form. Never edited, only added to.
session_id: 63243848-caa9-483c-9a8e-9bb0ee9d2849
session_date: 2026-04-24
---

# Release Ledger

> **Hook.** Append-only log of what has shipped — the platform's institutional memory in operational form. Never edited, only added to.

This is the platform's flight recorder. Every notable change — code, doc, governance — gets a line here. **Entries are append-only.** If a decision turns out to be wrong, write a *new* entry that supersedes it; never edit or delete the old one. The ledger's value is its honesty about how the platform actually evolved.

Each entry has the same shape:

```
### <ISO date> — <one-line title>

- **Type.** code · docs · governance · cleanup · removal · process
- **Scope.** What changed. File paths welcome.
- **Why.** What need it served, in one sentence.
- **Receipts.** Commit hash · PR link · file path · whatever proves it.
- **Lesson** *(optional)*. Anything worth remembering.
```

---

## 2026

### 2026-04-24 — Invention Backlog living doc

- **Type.** docs (governance + capture surface).
- **Scope.** New living doc at `pages/vault/Plans & Ledgers/Invention Backlog.md` capturing the brief on patentable inventions at the intersection of the Rappter stack and the real-estate / AI industry. Defines the 8-phase per-invention process (capture → prior art → white-space → design → claims → USPTO-ready → commercial viability → rank), a 5-axis patentability rubric (novelty × non-obviousness × utility × enablement × defensibility, score 1–3,125), and 8 *areas of intersection* phrased as **prompts** rather than enabled inventions to preserve novelty bars. Strong public-vault discipline section: implementation details, claim language, prior-art memos, and commercial viability numbers stay in private working docs; this file is the public *index*. Wired into `_manifest.json` and `_index.md` as the 7th living doc.
- **Why.** The brief was time-sensitive ("make sure it's not lost"). A vault-side capture surface ties the prompt to the platform's existing memory discipline. Public framework + private specifics is the right shape for IP-adjacent work — the framework is reusable across many candidate inventions, while the specifics carry filing-clock risk in jurisdictions without a US-style grace period.
- **Receipts.** `pages/vault/Plans & Ledgers/Invention Backlog.md`. `node tests/vault-check.mjs` post-add: 54 notes, 734 wikilinks resolve, 0 PII, 0 failures.
- **Lesson.** The platform's vault discipline already separates *what's safe to publish* from *what's still hot*. Extending it to IP work is a small step: same append-only ledger pattern, same session-pointer convention, same wikilink graph — with a clear *public-vault discipline* line drawn between *areas* (publishable) and *implementations* (private until filed).

### 2026-04-24 — installer/shortcuts/ scaffold + Apple Shortcuts MCP

- **Type.** code + docs.
- **Scope.**
  - `installer/shortcuts/` directory created with `README.md` (authoring workflow), `protocol.md` (the 5-action contract every brainstem-compatible Shortcut implements), `sign.sh` (one-line wrapper around `shortcuts sign --mode anyone` — defaults to *people-who-know-me*, which makes hosted shortcuts uninstallable for strangers), `index.html` (landing page with cards for *Brainstem Voice* + *Brainstem Capture* + *Brainstem Brief* as the catalog grows).
  - `installer/shortcuts/brainstem-voice/` subdirectory with `README.md` (install paths + 5-minute build walkthrough) and `index.html` (numbered action-by-action page styled to match the install widget). Status banner makes it clear the `.shortcut` binary isn't authored yet.
  - Linked from `index.html` (root landing — new "Apple Shortcuts ↗" CTA) and `installer/index.html` (the install widget — new nav entry).
  - **Apple Shortcuts MCP server installed** — `claude mcp add apple-shortcuts -- npx -y mcp-server-apple-shortcuts` (recursechat's implementation, the most popular). Connected and registered. Tools are `list_shortcuts`, `run_shortcut`, `view_shortcut` — useful for chat-side verification of authored Shortcuts. **None of the available MCPs creates Shortcuts** because the underlying macOS `shortcuts` CLI doesn't expose creation; Apple keeps authoring inside Shortcuts.app GUI and the `.shortcut` binary format is undocumented. Documented in `installer/shortcuts/README.md` under *MCP integration (optional)*.
- **Why.** Apple Shortcuts is the platform's path to **Apple Watch + Siri + iPhone + iPad + Mac + HomePod + CarPlay** with zero native code, zero App Store review, zero per-OS-version regression testing. The brainstem already emits the `|||VOICE|||` slot designed for TTS, so the Shortcut is just a 5-action harness over the existing `/chat` contract. The constitutional posture is captured in [[Surfaces — Mobile, Watch, Voice]].
- **Receipts.** 7 new files under `installer/shortcuts/`. `claude mcp list` shows `apple-shortcuts: ✓ Connected`. The `.shortcut` binary is still author-pending — follow the walkthrough at `installer/shortcuts/brainstem-voice/index.html` (5 minutes on a Mac with Shortcuts.app).
- **Lesson.** The line between *what an MCP can give you* and *what the platform underneath can give you* is sharp. Three independent MCP implementations all wrap the same `shortcuts` CLI; none of them transcends its limits. When evaluating an MCP, look at the underlying tool's surface area first — the wrapper inherits everything below it, capability and limitation alike.

### 2026-04-24 — Session-pointer frontmatter convention

- **Type.** docs (governance / convention).
- **Scope.** Two new optional frontmatter fields — `session_id` (UUID) and `session_date` (YYYY-MM-DD) — added to 9 notes that came out of decision-shaped or living-doc work this session: the 5 living docs (Vault Build-Out Plan, Documentation Roadmap, Release Ledger, Blog Roadmap, Content Strategy) plus 4 decision-shaped notes (Repo Root Reorganization 2026-04-24, Surfaces — Mobile Watch Voice, The skill.md Pattern, Federation via RAR). `tests/vault-check.mjs` extended to validate the field shape if present; the fields are never required. [[How to Read This Vault]] gained a "Session pointers" section explaining the convention.
- **Why.** Living docs and decision records benefit from a verifiable pointer back to the Claude Code session that produced them — if a future contributor needs context for *why* a decision came out the way it did, the UUID lets them navigate to the right session in their local Claude Code store. **No conversation content is stored** in the vault, the repo, or anywhere else; only the pointer. The platform's posture: traceability without exposure.
- **Receipts.** `tests/vault-check.mjs` lines 84–93 validate the new fields. 9 notes have `session_id: 63243848-caa9-483c-9a8e-9bb0ee9d2849` + `session_date: 2026-04-24`. `node tests/vault-check.mjs` post-change: 52 notes, 697 wikilinks resolve, 0 PII, 0 failures.
- **Lesson.** When tempted to store conversation content (encrypted or otherwise) in a public repo, ask whether a *pointer* would do. For traceability needs, the answer is almost always yes — the UUID is enough.

### 2026-04-24 — PWA on both web surfaces

- **Type.** code.
- **Scope.**
  - `pages/vault/manifest.webmanifest`, `pages/vault/sw.js`, `pages/vault/icon-192.svg`, `pages/vault/icon-512.svg` — vault is now installable on every desktop + mobile browser. Offline-readable: stale-while-revalidate caches all 47 markdown notes + `_manifest.json`; the viewer shell + marked.js + JSZip are precached on install.
  - `rapp_brainstem/web/manifest.webmanifest`, `rapp_brainstem/web/sw.js`, two SVG icons — desktop chat surface is now installable. SW caches the static UI shell but explicitly passes `/chat`, `/api/*`, `/login`, `/voice/*`, `/twin/*`, `/agents/files`, `/models/*` through to the network so live brainstem behavior never goes stale.
  - iOS meta tags (`apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style`, `apple-mobile-web-app-title`, `apple-touch-icon`) on both surfaces so the install experience is native-feeling on iPhone/iPad.
  - SW registration scripts at the bottom of both `index.html` files (best-effort — if registration fails, the surfaces still work fully online).
- **Why.** Cross-platform desktop apps would require three signing/notarization stories and three sets of OS-specific bug reports for an audience PWA can serve at zero maintenance cost. The platform's posture: reach new form factors with web tech, not native code.
- **Receipts.** `pages/vault/{manifest.webmanifest,sw.js,icon-*.svg}`, `rapp_brainstem/web/{manifest.webmanifest,sw.js,icon-*.svg}`. The mobile twin (`rapp_brainstem/web/mobile/`) was already a PWA; verified intact. New vault note [[Surfaces — Mobile, Watch, Voice]] captures the constitutional posture.
- **Lesson.** PWA is the right "desktop app lite" because it preserves the *audit the install path* property — there's no binary, the SW and manifest are reviewable JS/JSON, and the install URL is the same as the website. A native desktop app would have introduced opacity for marginal "feels native" gains.

### 2026-04-24 — Root cleanup pass 2 (vault + docs under pages/)

- **Type.** cleanup.
- **Scope.** `vault/` (46 markdown notes + 10 section folders) merged into `pages/vault/` alongside the viewer files; `docs/` (7 files) moved to `pages/docs/`. Root reduced from 14 entries to 12. `installer/` kept at root because the install one-liner URL is sacred per Article V. `tests/` kept at root because tests aren't pages. All references updated: `pages/vault/vault.js` fetch paths, `pages/vault/_manifest.json` `vault_path`, `tests/vault-check.mjs` scan path, README, `pages/docs/SPEC.md`, `pages/docs/skill.md` canonical URLs, `.gitignore`, every internal cross-reference in vault notes.
- **Why.** A second application of the [[Roots Are Public Surfaces]] discipline. Earlier-today's restructure left `vault/` and `docs/` at root; both are public-facing content that fits cleanly under `pages/` (which means "everything served from GitHub Pages").
- **Receipts.** `node tests/vault-check.mjs` post-move: 47 notes, 604 wikilinks resolve, no PII. `bash tests/e2e/08-html-pages.sh` still passes. Local static-server smoke tests for `pages/vault/`, `pages/docs/SPEC.md`, etc. all return 200.
- **Lesson.** When in doubt about whether a directory belongs at root, the test is "does this earn the catalog-card spot?" `installer/` and `tests/` earned theirs (sacred URL, not page content). `vault/` and `docs/` didn't — they're page content and belong under `pages/`.

### 2026-04-24 — "RAPP monorepo" → "RAPP platform"

- **Type.** docs (terminology).
- **Scope.** Replaced "RAPP monorepo" with "RAPP platform" across `CLAUDE.md`, `CONSTITUTION.md`, `README.md`, vault notes, the vault viewer's chrome, and `pages/docs/SPEC.md`. The single remaining "monorepo" in SPEC's reference-implementation row became "one repository."
- **Why.** "Monorepo" is an implementation detail; "platform" describes what the repo *is*. The platform's surface area extends beyond one repo (the rapp store, future federated publishers, the vault export pattern). The term should reflect that.

### 2026-04-24 — Vault build-out (Phases 1–8)

- **Type.** docs + code + governance.
- **Scope.**
  - **Phase 1 — Voice sweep.** Removed founder/PII references from existing 28 notes. Locked third-person platform voice as the rule.
  - **Phase 2 — 26 published essays.** Every stub from the original list converted to a 700–1200-word published note: 6 founding decisions, 4 removals, 4 architecture, 3 positioning, 3 twin/UX, 3 process, 3 manifestos. Cross-linked aggressively (570 wikilinks total).
  - **Phase 3 — 9 foundational notes.** [[Glossary]], [[How to Read This Vault]], [[The Platform in 90 Seconds]], [[The Sacred Constraints]] (rewritten to 6 constraints after the post-restructure CLAUDE.md added single-file services and the agent-first rule), three tier notes, [[Constitution Reading Order]], [[Major Moments]].
  - **Phase 4 — 5 reading paths.** Engineer (8 notes), Architect (6), Partner (5), Exec (3), New Contributor (7+).
  - **Phase 5 — Viewer polish.** Keyboard nav (`j`/`k`/`/`/`g i`/`r`/`m`/`g`/`o`/`?`), per-heading anchor + copy-link buttons, *Open in Obsidian* via `obsidian://`, mobile breadcrumb + slide-in nav, reading-mode toggle, vanilla-SVG graph view with hover-to-highlight neighbors.
  - **Phase 6 — Link/PII checker.** `tests/vault-check.mjs` walks every note, validates frontmatter + manifest coverage, asserts every wikilink resolves (skipping code spans), and scans for PII patterns (email regex, real-name fragments, phone numbers) with an allowlist for the public `kody-w` GitHub handle.
  - **Phase 7 — Tied back into the repo.** README's "The vault" section, `pages/docs/SPEC.md`'s audience-pages table cross-references, vault link in 10 marketing pages' `sr-only` nav, visible "Read the vault ↗" link on the GitHub Pages landing.
  - **Phase 8 — Final pass.** All checks green: 46 notes, 570 wikilinks resolve, no PII detected, marketing-page tests still pass.
- **Why.** The platform's accumulated *why* had no canonical home. The vault now holds it; the constitution ratifies it; the checker enforces the public-vault property; the viewer makes it readable.
- **Receipts.** `vault/` (46 .md files), `pages/vault/` (index.html + vault.css + vault.js), `tests/vault-check.mjs`. Updated: `README.md`, `pages/docs/SPEC.md`, `index.html`, all 10 marketing pages in `pages/`, `vault/Plans & Ledgers/Vault Build-Out Plan.md` (all phase boxes checked), `vault/Plans & Ledgers/Documentation Roadmap.md` (Shipped section).
- **Lesson.** A vault is only as useful as its discipline. The PII checker + the link checker + the manifest validation are what make the vault *trustably public*; without them, the public-vault property quietly regresses one PR at a time. Future PRs that touch the vault must keep `node tests/vault-check.mjs` green.

### 2026-04-24 — Repo restructure (post-vault landing)

- **Type.** cleanup + governance.
- **Scope.** Major reorganization landed mid-vault-build: install scripts moved from repo root to `installer/` (`install.sh`, `install.ps1`, `install.cmd`, `install-swarm.sh`, `start-local.sh`, `azuredeploy.json`); platform docs moved from repo root to `pages/docs/` (`SPEC.md`, `CONSTITUTION.md`, `ROADMAP.md`, `AGENTS.md`, `VERSIONS.md`, `skill.md`, `rapplication-sdk.md`); Tier 3 Studio zip moved from repo root to `installer/MSFTAIBASMultiAgentCopilot_1_0_0_5.zip` alongside the install scripts (briefly tried `rapp_studio/`, folded back into `installer/` same session — a `.zip` is an install artifact, not running code). CLAUDE.md updated to reflect the new layout and to expand sacred constraints from 4 to 6 (added single-file services + agent-first rule). Install one-liner URL changed from `https://kody-w.github.io/RAPP/install.sh` to `https://kody-w.github.io/RAPP/installer/install.sh`. Each kept top-level subdir (`pages/docs/`, `pages/`, `installer/`, `tests/`) gained a `README.md` with local scale rules.
- **Why.** Repo root had crept up to ~40 entries again. The new layout cleans root down to a handful of tier directories + landing pages + key files, with everything else routed into a named subdirectory.
- **Receipts.** `git log` across this date; `installer/` and `pages/docs/` now contain the moved files (no `rapp_studio/` — folded into `installer/`); `CLAUDE.md` lines 12, 73, 85–98 reflect the new structure; [[Repo Root Reorganization 2026-04-24]] captures the why and the lesson on overfitting symmetry.
- **Lesson.** The repo-root discipline ([[Roots Are Public Surfaces]]) was applied a second time within a week of the first. The constitutional rule is doing its job — when bloat appeared, the cleanup was a single pass with explicit routing rules. Two cleanups in a week is the rule paying off.

### 2026-04-24 — Vault and constitutional extension

- **Type.** governance + docs + code.
- **Scope.**
  - `CONSTITUTION.md` — Article XVI extended with repo-root discipline (allowlist of root residents, routing rules, the *git pull pollution* failure mode); new Article XXIII — *The Vault Is the Long-Term Memory*; old Article XXIII (Amendments) renumbered to XXIV.
  - `vault/` — 28 markdown notes seeded (26 stubs across Founding Decisions, Removals, Architecture, Positioning, Twin and UX, Process, Manifestos; plus `README.md` and `_index.md`).
  - `pages/vault/` — static SPA viewer with fetch-from-GitHub renderer, wikilink resolution, backlinks panel, search, JSZip export to Obsidian-compatible vault, drop-zip import to local mode, localStorage cache.
  - `CLAUDE.md` — Key Directories table updated with `vault/` (with the *write the why here* instruction), `pages/`, `pages/docs/`.
  - `.gitignore` — `vault/.obsidian/` and `vault/.trash/` added.
- **Why.** The accumulated *why* behind the platform's decisions had no canonical home and was rotting in commit messages and conversations. The vault is the home; the constitution is the discipline that keeps it load-bearing.
- **Receipts.** Local working tree, uncommitted as of this entry. Filed for commit on the same day under two grouped commits: (1) `repo-root cleanup + pages/docs reorg`, (2) `vault scaffold + Article XXIII`.
- **Lesson.** Doing the cleanup first, then ratifying the discipline, then building the vault on top of the ratified rule produced a clean three-step ladder. Doing them in any other order would have introduced a chicken-and-egg.

### 2026-04-24 — Repo-root cleanup

- **Type.** cleanup.
- **Scope.** Moved 10 marketing HTMLs (`faq.html`, `faq-slide.html`, `leadership.html`, `one-pager.html`, `partners.html`, `process.html`, `release-notes.html`, `roadmap.html`, `security.html`, `use-cases.html`) → `pages/`; moved 2 documents (`rapplication-sdk.md`, `skill.md`) → `pages/docs/`. Updated all `og:url` and `canonical_url` meta tags in moved HTML; updated `tests/e2e/08-html-pages.sh` test paths; updated `SPEC.md` audience-one-pagers table.
- **Why.** The recent fast-forward pull added 12 files at the repo root, taking total root entries from ~28 to ~40. Root signals project shape; bloat signals "unfinished."
- **Receipts.** `git mv` history visible in the next commit; `bash tests/e2e/08-html-pages.sh` passes (76 content-anchor checks, 10 page parses, 10 file existence checks).
- **Lesson.** A `git pull` is the single most reliable way to bloat a root. Future cleanups will be faster now that Article XVI ratifies the routing rules.

### 2026-04-24 — Fast-forward pull from origin/main (80 commits)

- **Type.** code (third-party — landed merged work).
- **Scope.** Pulled commits `2a35c22..c1b4a2f` from `origin/main`. Adds: 10 marketing HTML pages; `rapp_brainstem/web/manage.html` (1548 lines); `rapp_swarm/_vendored/` complete tree; new agents (`context_memory`, `manage_memory`, `workiq`); rapp store entries (`dashboard`, `kanban`, `vibe_builder`, `webhook`). Removes: `rapp_brainstem/chat.py` (342 lines), `swarm_server.py` (1736 lines), `t2t.py` (337 lines), `workspace.py` (161 lines), `pitch_deck_agent.py` (1087 lines), `recall_memory_agent.py`, `save_memory_agent.py`, all of `agents/experimental/` (six agents totaling ~2900 lines). Renames `rapp_brainstem/{llm.py,local_storage.py,twin.py,_basic_agent_shim.py}` → `rapp_brainstem/utils/`.
- **Why.** Local branch was 80 commits behind. Resolved via stash → fast-forward → manual `.gitignore` merge.
- **Receipts.** `git log 2a35c22..c1b4a2f`; the merged `.gitignore` retains both upstream additions and the local `rapp_brainstem/.brainstem_data/` line.
- **Lesson.** The deletion volume here (~6,500 lines across 8+ files) is the kind of evidence that should fan out into vault notes — see stubs [[Why hatch_rapp Was Killed]], [[Why t2t and swarm_server Are Gone]], [[The experimental Graveyard]].

---

## How to read this ledger

- **Top is most recent.** Add new entries at the top of the most recent year's section.
- **Years are headers.** When the year rolls over, add a new `## YYYY` section above the previous one.
- **Receipts are non-negotiable.** Every entry needs at least one path or hash that future-you can verify against.
- **Lessons are optional but valuable.** A line of "what we learned" beats a paragraph of "what changed."

## Related

- [[Documentation Roadmap]] — what we plan to ship.
- [[Vault Build-Out Plan]] — current active build.
- [[Roots Are Public Surfaces]] — the discipline behind the 2026-04-24 cleanup.
