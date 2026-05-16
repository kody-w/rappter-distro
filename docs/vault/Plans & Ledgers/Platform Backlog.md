---
title: Platform Backlog
status: living
section: Plans & Ledgers
type: backlog
hook: Three horizons — Now / Next / Later — for everything that isn't running code yet. Code, design, infra, tooling, content discoverability. Appended freely; nothing silently deleted.
---

# Platform Backlog

> **Hook.** Three horizons — Now / Next / Later — for everything that
> isn't running code yet. Engineering, design, infra, tooling, content
> discoverability. Appended freely; nothing silently deleted.

This is the catch-all backlog for non-documentation work. The companion
to [[Documentation Roadmap]] (which tracks docs specifically) and
[[Release Ledger]] (append-only log of what shipped). When a session
ends with deferred items — *"that's real value but it's a separate
session"* — they land here so they don't evaporate.

Living document. Add entries freely. **Never silently delete** —
shipped items move to the **Done** section at the bottom so the
history is visible.

## How to add an item

```
### <Title>

- **What.** One sentence.
- **Why.** One sentence — what need it serves.
- **Where.** File paths the change touches, or "new directory" /
  "new page" / "new vault note".
- **Ready when.** The signal that says "this is ready to do" —
  a stabilized code change, a stakeholder ask, a recurring question,
  a measurable gap.
- **Effort.** S / M / L (rough hours, half-day, days).
```

Reference the article number or vault note that motivates it, where
relevant. *Why* is more important than *what* — six months from now
the *why* is the part that rots.

## Now — actively scoped

Items currently in motion or queued for the next session.

### Visual verification of the new site

- **What.** Open `pages/index.html`, every section landing, and a
  representative page from each section in a real browser. Confirm
  the shared `_site/` chrome injects, theme toggle works, mobile nav
  opens, no inline-CSS class collisions with the new shared
  `components.css` (`.kicker`, `.btn`, `.card` are defined in both
  places on some pages).
- **Why.** All tests pass and HTML parses, but no automated test
  catches *visual* regressions. The site shipped to a public audience
  with a layout glitch is the failure mode this prevents.
- **Where.** Browser. Findings filed as follow-ups in the **Now**
  bucket if anything's broken.
- **Ready when.** Anytime — no blockers.
- **Effort.** S (~15 min if nothing's wrong; M if collisions found).

### Search across the audience site

- **What.** Client-side fuzzy search over `pages/_site/index.json`.
  Add `pages/search.html` (results page) + `pages/_site/js/search.js`
  (~80 lines of vanilla JS doing token-match against title +
  description + audience). Wire a search box into the header partial.
- **Why.** Sectioned nav scales to ~15 pages. The platform is going
  to ship more — community contributions, additional audience pages,
  more rapps with their own pages. Without search, the site stops
  being navigable somewhere around 25 pages.
- **Where.** New: `pages/search.html`, `pages/_site/js/search.js`.
  Edit: `pages/_site/partials/header.html` (search input).
- **Ready when.** Anytime — `_site/index.json` already has the
  manifest data.
- **Effort.** M (half-day with debouncing, keyboard nav, empty-state).

### Strip redundant `:root{}` tokens from sectioned pages

- **What.** Each of the 10 sectioned pages still carries 150–200
  lines of inline `<style>` redefining tokens (`--bg`, `--accent`,
  `--grad-1`, etc.) that now live in `pages/_site/css/tokens.css`.
  Remove the `:root{}` and `[data-theme="light"]` token blocks from
  each page; keep the page-unique layout CSS.
- **Why.** Right now changing a token (the brand gradient, the dark
  background) requires editing 11 places. The whole point of
  `_site/` is one source of truth — token redundancy across pages
  silently undoes that.
- **Where.** `pages/about/*.html`, `pages/product/*.html`,
  `pages/release/*.html`. Per-page diff, per-page verification.
- **Ready when.** After visual verification (above) confirms the
  shared CSS is rendering correctly. Don't strip until the safety
  net is in place.
- **Effort.** M — each page is small but there are 10.

### `rapp_brainstem/test_local_agents.py` fixture audit

- **What.** Read through `rapp_brainstem/test_local_agents.py` and
  fix any stale references to `save_memory_agent.py` /
  `recall_memory_agent.py` (renamed to `manage_memory_agent.py`
  long ago). Same bug class as the JS test fixture fix that landed
  on 2026-04-24 — high probability the Python tests have the same
  problem and just hadn't been run.
- **Why.** Tests that crash on stale fixtures are silent regressions.
  Until they run green again, contributors can't trust them — and
  the Python suite covers Tier 1 storage and agent contracts that
  the JS suite doesn't reach.
- **Where.** `rapp_brainstem/test_local_agents.py`. Possibly also
  any tier-internal fixtures it references.
- **Ready when.** Anytime — same shape as the JS fix, well-precedented.
- **Effort.** S (~30 min — find references, decide replacements,
  run, verify).

### `rapp_brainstem/CONSTITUTION.md` sync audit

- **What.** Compare the brainstem-internal constitution against the
  root `CONSTITUTION.md`. Resolve drift: stale path refs (likely
  references `docs/SPEC.md` that should be `pages/docs/SPEC.md`),
  contradictions with the updated Article XVI, and references to
  files that have moved. Decide which articles belong to brainstem
  vs. the root and reduce duplication.
- **Why.** Two constitutions both calling themselves "the rules"
  is a contradiction surface. Today's root reorganization changed
  Article XVI, Article XXIII, and several path conventions — the
  brainstem copy almost certainly didn't track. Future contributors
  reading either file should land at the same answer.
- **Where.** `rapp_brainstem/CONSTITUTION.md`. Compare with root
  `CONSTITUTION.md`. Memorialize the resolution in a vault note.
- **Ready when.** Anytime.
- **Effort.** M — diff is straightforward, but the *which-rules-
  belong-where* question is a judgment call worth thinking through.

### Manifest staleness test (`tests/site-check.mjs`)

- **What.** New test script that walks `pages/**/*.html`, asserts
  every page (other than `pages/_site/`, `pages/vault/`, and
  `pages/docs/viewer.html`) is listed in `pages/_site/index.json`.
  Mirrors the shape of `tests/vault-check.mjs`.
- **Why.** Right now adding a page silently desyncs the manifest
  — search, sitemap, and any future content discovery feature stop
  seeing the new page. Catching it at test time keeps the manifest
  honest.
- **Where.** New: `tests/site-check.mjs`. Edit: `tests/run-tests.mjs`
  to invoke it as part of the suite.
- **Ready when.** Anytime — `_site/index.json` already exists.
- **Effort.** S.

## Next — scoped, not yet started

Items the platform needs but that are blocked on something else.

### `make vault-check` (or shorter invocation)

- **What.** A short alias for `node tests/vault-check.mjs` so
  contributors can run the guardrail without remembering the path.
- **Why.** Friction-reduction. Shorter form encourages running it
  before every PR.
- **Where.** `Makefile` at repo root (would be a new file) or a
  `tests/check` shell wrapper.
- **Ready when.** Anytime. (Note: was on
  [[Vault Build-Out Plan]] Phase 6 but applies broadly — moving it
  here so it doesn't get lost when that plan closes.)
- **Effort.** S.

### Tier-internal HTML surfaces — site shell decision

- **What.** Three tier-internal HTML surfaces don't use the new
  `pages/_site/` chrome: `rapp_brainstem/index.html`,
  `rapp_brainstem/web/index.html` (browser-only brainstem), and
  `installer/index.html` (install widget). Decide their relationship
  to the site shell — three options:
  1. **Unify** — link `_site/css/*.css` and inject the shared
     header/footer. They become part of the site, navigable from
     the audience nav.
  2. **Tokens-only** — link `_site/css/tokens.css` so colors stay
     in sync, but keep their existing chrome (their audience is
     operators, not visitors).
  3. **Stay standalone** — leave them as-is. They're tier-internal,
     not part of the audience site.
- **Why.** Article XVI says *"anything served to a public visitor
  lives somewhere under `pages/`"* — but these three are *served*
  publicly from outside `pages/`. They predate the rule and are an
  acknowledged exception, but the exception isn't explicit. Making
  the call now prevents drift.
- **Where.** `rapp_brainstem/index.html`,
  `rapp_brainstem/web/index.html`, `installer/index.html`. Plus an
  Article XVI amendment memorializing whichever option wins.
- **Ready when.** Anytime — but the decision benefits from the
  visual-verification pass landing first (so we know the new shell
  is actually rendering correctly before considering whether to
  extend it).
- **Effort.** S to decide, M to execute (option-dependent).

### Sitemap.xml + robots.txt at repo root

- **What.** Generated `sitemap.xml` listing every page in
  `pages/_site/index.json` plus the root `index.html` and
  `pitch-playbook.html`. A `robots.txt` allowing all crawlers.
- **Why.** Search engines won't index the new sectioned site
  efficiently without it. Free SEO win once we want public traffic.
- **Where.** Repo root: `sitemap.xml`, `robots.txt`. Optionally a
  small `pages/_site/js/build-sitemap.mjs` that regenerates from
  the manifest (no build step in production — script is run-on-
  demand by humans).
- **Ready when.** When the URL shape is genuinely stable. Sitemaps
  pinned at the wrong URLs poison crawler caches for weeks.
- **Effort.** S.

### RSS feed for release notes

- **What.** `pages/release/feed.xml` driven from the same data
  `release-notes.html` renders. Or a static RSS that's hand-updated
  alongside release-notes.html.
- **Why.** Operators who pin `BRAINSTEM_VERSION=...` want to know
  when there's a new release. RSS is the lowest-friction
  notification channel that doesn't require a backend.
- **Where.** New `pages/release/feed.xml`. Possibly a small
  generator next to `release-notes.html`.
- **Ready when.** First external user of `BRAINSTEM_VERSION`
  pinning shows up.
- **Effort.** S.

### Docs viewer: search-within-doc + copy-section

- **What.** In-doc full-text search (Cmd-F on steroids — search
  rendered markdown, jump to heading). Per-section copy-link button
  that puts a permalink on the clipboard.
- **Why.** Long docs (SPEC, CONSTITUTION) need find-on-page that
  beats the browser's, especially on mobile. Copy-section lets
  someone share a specific clause without screenshotting.
- **Where.** `pages/_site/js/doc-viewer.js` extension.
- **Ready when.** Once SPEC + CONSTITUTION have been read by ≥10
  external readers in a quarter (signal that this discoverability
  matters at this scale).
- **Effort.** M.

## Later — known gaps not yet scoped

Items the platform should eventually have, but where the underlying
thing is still moving fast.

- **Visual graph view of section relationships** — node-link diagram
  of how `pages/about/`, `pages/product/`, `pages/docs/`,
  `pages/vault/` reference each other. Like the vault's graph but
  for the whole site. Wait until the section count stabilizes.
- **Section-internal sidebars** — `pages/docs/` and `pages/vault/`
  each have their own internal nav; `pages/about/`, `pages/product/`,
  `pages/release/` use the global header. Once any section grows
  past ~6 pages, it earns its own sidebar. Flag when triggered.
- **Internationalization shell** — i18n routing (`pages/en/...`,
  `pages/ja/...`) with a default language. Wait until a translation
  PR materializes.
- **Service authoring guide** — companion to the future agent-
  authoring guide for the single-file HTTP services in
  Constitution Article III. Wait until ≥3 services exist in
  `rapp_store/`. *(Cross-listed in [[Documentation Roadmap]].)*
- **Community contribution flow** — `CONTRIBUTING.md` at root, plus
  a `pages/contribute.html` walking through how to add an agent or
  a vault note. Wait until the first external contributor PR.
- **Tier 2 deploy walkthrough** — *Cross-listed in
  [[Documentation Roadmap]].*
- **The vibe builder, swarm factory, rapp store contract,
  card pattern** — all on [[Documentation Roadmap]] Later. Listed
  here as a pointer; the canonical entry is there.

## Done

Items that started in **Now** or **Next** and have been completed.
**Append-only — never delete from this list.** Each entry has a
date and a pointer to the artifact (commit, vault note, or path).

- **2026-04-24** · Repo root reorganization — install scripts to
  `installer/`, governance docs to `docs/` (then `pages/docs/`),
  T3 zip into `installer/`, CONSTITUTION restored to root.
  Memorialized in [[Repo Root Reorganization 2026-04-24]] and
  [[Release Ledger]].
- **2026-04-24** · Audience site shell — `pages/_site/` shared
  infrastructure (CSS tokens, base, components, doc CSS · theme,
  site, doc-viewer JS · header + footer partials · `index.json`
  manifest). 10 sectioned pages wired to it (`pages/about/`,
  `pages/product/`, `pages/release/`). New `pages/index.html`
  audience landing, `pages/docs/index.html` + `viewer.html` docs
  rendering, root `404.html` for site-wide unresolved-path
  catching. Memorialized in [[Repo Root Reorganization 2026-04-24]].
- **2026-04-24** · Test fixture fix — `tests/run-tests.mjs`
  references `manage_memory_agent.py` + `context_memory_agent.py`
  (was the deleted `save_memory_agent.py` / `recall_memory_agent.py`).
  Both starter agents got `__manifest__` blocks. 59/59 tests pass.

## Related

- [[Documentation Roadmap]] — items that produce a doc artifact.
- [[Release Ledger]] — append-only log of shipped work.
- [[Vault Build-Out Plan]] — the vault's own one-time build-out plan.
- Article XVI of `CONSTITUTION.md` — the rule that produces most of
  the items in this backlog.
