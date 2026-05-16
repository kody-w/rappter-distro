---
title: Building a static site in pure HTML/CSS/JS in 2026 — the anti-framework case
status: shipped
published_url: https://kody-w.github.io/2026/04/24/static-site-pure-html-2026/
section: Blog Drafts
hook: A real multi-section site with shared chrome, theming, a docs viewer, a vault renderer, and zero build step. Why "vanilla" is more capable than the framework discourse suggests, and why we'd reach for it again.
date: 2026-04-24
class: evergreen
decay: low
---

# Building a static site in pure HTML/CSS/JS in 2026 — the anti-framework case

The framework landscape in 2026 is a parade of confident answers to a question most projects don't have. *"How should you build a static site?"* gets answers ranging from "use Astro" to "use Eleventy" to "you'll regret not using Next.js" to "Hugo is faster than all of them." Each comes with a release cadence, an ecosystem, a community, and a permanent maintenance liability you've now signed up for.

There's a different question worth asking: *what would it take to build the same site without any of them?* The answer is shorter than the framework discourse suggests, and the result is more durable than the framework alternatives.

This post is about a real working multi-section website built with vanilla HTML, CSS, and JavaScript — no bundler, no framework, no SDK — and the case for why this is a defensible default in 2026.

## What "the same site" means

The reference implementation has all the things a multi-section static site is expected to have:

- A landing page with sections, audience routing, and an install command.
- An audience site sectioned into `about/`, `product/`, `release/`.
- A docs site with a markdown viewer, table of contents, scroll-spy, and theme integration.
- A vault — long-form decision narratives, ~50 markdown notes — with wikilinks, backlinks, search, and JSZip export.
- A 404 page with sitemap fallback.
- A persistent dark/light theme with no flash on load.
- Mobile-responsive nav.
- Shared chrome that updates everywhere when the partial changes.
- A site manifest that drives nav highlighting and (planned) search.

The site has ~15 pages today and is designed to scale to dozens. It runs on GitHub Pages with zero build configuration. Open any HTML file directly via `file://` and it renders. The repo is public; the source is the artifact.

## What it took

Roughly:

```
pages/_site/
  css/
    tokens.css       (~70 lines — design variables)
    base.css         (~70 lines — reset + body)
    components.css   (~200 lines — header, nav, footer, cards, btn)
    doc.css          (~120 lines — markdown render styling)
  js/
    theme.js         (~25 lines — synchronous theme init + toggle)
    site.js          (~100 lines — partial injection, nav highlight)
    doc-viewer.js    (~140 lines — fetch + marked.js + ToC builder)
  partials/
    header.html      (~25 lines)
    footer.html      (~50 lines)
  index.json         (the site manifest)
```

About 800 lines of CSS, 270 lines of JS, 75 lines of HTML for the partials. One CDN dependency (marked.js, only used by the docs viewer) loaded on demand. That's the entire "framework" for the site.

Each individual page is then ~60-200 lines depending on layout. A typical page is two `<link>` tags for the shared CSS, one `<script>` tag for theme.js (synchronous), one `<div id="site-header">` placeholder, the page's unique content, one `<div id="site-footer">`, and a deferred `<script>` tag for site.js. That's it.

## Why this works in 2026

Three things that weren't true in 2014, when the bundler discourse first hardened, and that *are* true now:

**Browsers are very capable.** CSS custom properties (variables) make design tokens trivial. CSS grid + flexbox handle layouts that would have required JavaScript before. `fetch()` is universal. `IntersectionObserver` for scroll-spy. `localStorage` for theme persistence. Mobile browsers caught up. The DOM has stabilized. Everything you need is in the browser, no transpilation required.

**ES modules are mature.** You can write modern JavaScript and ship it directly. No Babel. No webpack. No "but how do I import in the browser?" — the answer is `<script type="module">` or `<script src="...">` and your code runs.

**CDN-loaded utility libraries are reliable.** marked.js from jsdelivr at a pinned version is one line, no install, no version drift. The loadtime cost is negligible (10s of KB, gzipped, cached cross-origin). For specific needs (markdown rendering, zip handling), CDN-loaded libraries beat the bundling-the-world approach hands down.

The combined effect: most of what frameworks were solving in 2018 is now solved by the platform. The frameworks didn't go away because they're still useful for many things — but the *baseline assumption* that you reach for one is no longer load-bearing.

## What you give up

Honesty about the tradeoffs:

**No automatic optimization.** A bundler splits code, hashes filenames, inlines critical CSS, generates source maps. None of that happens here. The site is fast enough without it because the site is small enough not to need it. Past 100 pages or so, this changes.

**No component library.** React/Vue/Svelte's developer ergonomics — `<MyButton variant="primary" onClick={...}>` — don't exist. You write HTML. You repeat patterns across files. The shared chrome is partials-via-fetch, not components, so dynamic interactions inside the chrome are limited.

**No type checking.** JS is JS. If you want types, you're either adding TypeScript (a build step) or you're documenting the function shapes carefully and trusting your tests. For ~270 lines of JS, this is fine. For 5,000, this becomes painful.

**No hot-reload during development.** You save a file; you refresh the browser. That's the loop. It's plenty fast for content-shaped work; it's frustrating for component-shaped work.

**Frameworks make some things genuinely easier.** Form validation. Complex state management. Data fetching with caching. Server-side rendering. If your site needs these, vanilla starts to feel limiting. Most static sites don't need any of these.

## When the pattern is right

Three signals that vanilla is the right answer for your project:

1. **You're shipping content, not components.** The site is mostly long-form text, marketing pages, docs. The interactive layer is small (theme toggle, nav, search, render-markdown).
2. **You value not-having-a-build-step over framework ergonomics.** The maintenance liability of *no bundler at all* is meaningfully lower than *modest bundler* over a five-year horizon.
3. **You're comfortable with the vanilla DOM.** If you reach for jQuery's mental model in 2026, you'll still be productive without it. If you only know React, vanilla will feel hostile.

Three signals that vanilla is the *wrong* answer:

1. **The site is heavily interactive.** A SaaS dashboard, a graphical editor, a complex form. Reach for a framework.
2. **The team is large and component-based work is the dominant shape.** Component libraries are a real productivity multiplier above ~5 contributors.
3. **The content shape requires server rendering or static generation per page.** Vanilla pages are static-content-shaped; if you need to generate 1,000 pages from a JSON dataset, a build step is the right move.

## What this rules out

The pattern is a constraint that protects a property. The property is *edit a file, refresh the browser, see the change.* The constraints that protect it:

**Don't add a build step "for performance."** It almost never matters at this scale.

**Don't add a build step "for ergonomics."** The site is small enough that the ergonomics cost is real but small. Adding a build step makes the project less approachable, not more.

**Don't add server-side rendering.** GitHub Pages serves static files. Anything that requires server-side computation is the wrong shape for this stack.

**Don't centralize via JS framework.** Partials-via-fetch is the substitute. It's slightly less elegant than React components but vastly cheaper to maintain.

**Don't apologize for vanilla.** "We're using plain HTML/CSS/JS" is an architectural choice, not an oversight. Documenting it as a choice (in the project's CONSTITUTION, in the directory READMEs) prevents the next contributor from "fixing" it by introducing a framework.

## The leverage of *no build step*

The single most underrated property of this stack is the absence of a build step. It's hard to overstate how much it changes the maintenance picture:

- A 2026 contributor opens the repo. They edit `pages/about/leadership.html`. They refresh the browser. They see the change. They commit. PR review happens on the same diff they edited. Deployment is `git push`.
- A 2030 contributor opens the same repo. The npm registry has been through three controversies. The framework that was hot in 2026 has been deprecated and re-launched. The build tools that were cutting-edge are now legacy. None of this matters; the repo still builds, still deploys, still renders. The contributor opens a file, edits, refreshes, commits.
- A 2034 contributor pulls down the repo. By any reasonable measure of software entropy, half the projects from 2026 don't build anymore. This one does. Its dependency surface is the browser, which is the most stable software platform in existence.

That's the bet. Vanilla in 2026 isn't a stunt. It's a hedge against the frameworks of 2030 not existing in 2034.

## Receipts

- The reference implementation: [`pages/_site/`](https://github.com/kody-w/RAPP/tree/main/pages/_site) in the source repo.
- A typical page that uses it: [`pages/about/leadership.html`](https://github.com/kody-w/RAPP/blob/main/pages/about/leadership.html).
- The Constitution article that bans frameworks for this directory: Article XVI in [`CONSTITUTION.md`](https://github.com/kody-w/RAPP/blob/main/CONSTITUTION.md).

The platform's working knowledge: *vanilla in 2026 is the new sensible default* for static, content-shaped sites. It's not the answer for every project; it is the answer for far more projects than the framework discourse acknowledges. Try it. The cost is low. The longevity is high.
