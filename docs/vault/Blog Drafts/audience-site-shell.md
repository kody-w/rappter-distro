---
title: The audience site shell — no build step required
status: shipped
published_url: https://kody-w.github.io/2026/04/24/audience-site-shell/
section: Blog Drafts
hook: A real multi-section website with shared chrome, design tokens, and a markdown docs viewer — using only vanilla HTML, CSS, and JS. No bundler, no framework, no SDK.
date: 2026-04-24
sources:
  - "[[Repo Root Reorganization 2026-04-24]]"
  - "[[Roots Are Public Surfaces]]"
class: semi-evergreen
decay: high
---

# The audience site shell — no build step required

Most "scalable static site" tutorials end up reaching for a bundler. Astro, 11ty, Next.js, Hugo. The pitch is always the same: "you'll regret it when you scale past ten pages."

This is a counterargument from a real working site that just crossed ten pages and didn't reach for any of them.

## The setup

`pages/` started as a folder of ten flat HTML files. Each one carried 200 lines of inline `<style>` redefining the same dark-mode tokens. Adding a new page meant copy-pasting the previous one, editing the meta tags, hoping nothing drifted. Adding a new color meant editing eleven places.

The brief: turn this into a *real* site — sectioned, navigable, themed consistently — without violating the project's standing rule that pages stay vanilla. No build step. No npm install. Open the file in a browser and it just works.

## The shape that fell out

```
pages/
  _site/                    ← shared infrastructure (private — underscore prefix)
    css/
      tokens.css            ← color/spacing/type variables. one source of truth.
      base.css              ← reset, body, theme switch, containers
      components.css        ← header, nav, footer, cards, kicker, btn
      doc.css               ← markdown-render styling for the docs viewer
    js/
      theme.js              ← synchronous in <head> — no flash of wrong theme
      site.js               ← injects header/footer partials, handles nav highlight
      doc-viewer.js         ← marked.js + ToC builder for pages/docs/
    partials/
      header.html           ← top nav. one source of truth.
      footer.html           ← site footer. one source of truth.
    index.json              ← site manifest: every page, title, audience, section

  index.html                ← site landing
  404.html                  ← in repo root, so GitHub Pages serves it site-wide

  about/                    ← who, why, how
  product/                  ← what it does
  release/                  ← what's shipped, what's next
  docs/                     ← the contract, rendered from .md
  vault/                    ← the why, rendered from .md
```

## The interesting parts

**Tokens, not duplication.** `_site/css/tokens.css` is the single place every color/spacing/type variable is declared. Pages still have inline `<style>` blocks for their unique layouts (a slide-shaped one-pager looks nothing like a long-form FAQ), but they all *read* tokens via `var(--bg)`, `var(--accent)`. Changing the brand gradient is one file, one diff, eleven pages updated.

**Partials via fetch + inject, not via build step.** Every page declares `<div id="site-header"></div>` and `<div id="site-footer"></div>`. `_site/js/site.js` runs `fetch('partials/header.html')`, rewrites `@/foo` tokens to relative URLs, and injects. The JS auto-detects its own depth from `document.currentScript.src`, so the same partial works from `pages/index.html`, `pages/about/leadership.html`, and `pages/docs/viewer.html` without per-page configuration.

**Theme that doesn't flash.** `_site/js/theme.js` loads *synchronously* in `<head>` so the `data-theme` attribute lands before paint. The toggle button — wired up by `site.js` after the partial injects — flips it. Local-storage-persisted, system-preference-respecting, three-line read.

**A docs viewer for the markdown.** `pages/docs/viewer.html?doc=SPEC` fetches `SPEC.md` (allowlisted set), renders it via marked.js from a CDN, builds a sticky ToC sidebar, and applies the same theme as the rest of the site. The pattern follows `pages/vault/`: ship the markdown directly + provide a viewer for visitors. Markdown is the spec; HTML is the rendering.

**A manifest as the inventory.** `_site/index.json` lists every page with title, audience, section, description. The site uses it for nav-highlight and (Phase 2) for client-side fuzzy search. Adding a new page = drop the file in the right section + add one line to the manifest. No regen. No build.

## What this rules out

The discipline this enforces is what makes the layout scalable, not the file count:

- **No subdirectories under `_site/`** beyond `css/`, `js/`, `partials/`. The shared chrome stays one logical thing.
- **No build-time templating.** Pages are pages, not source files for a generator. If you can't open the `.html` directly in a browser and get a rendered page, the abstraction has gone too far.
- **No framework.** Vanilla HTML/CSS/JS only. The CONSTITUTION article governing this directory says: *"If you reach for React, Next.js, or a bundler, you've outgrown the `pages/` pattern; redesign before adding."*
- **No magic per-page config.** A new page links the same three CSS files, drops in two placeholder divs, and is done.

## What this buys you

The cost of a new audience page is now ~60 lines of HTML — title, meta tags, content. The chrome is automatic. The theme is automatic. The nav highlights the current section automatically. Stripping the inline token redundancy from existing pages (the next pass) will drop their average size by 150 lines each.

More importantly: a new contributor can navigate the system without reading framework docs. The repo is the contract. `pages/_site/` is small enough that someone can read the entire shared infrastructure in fifteen minutes and know everything the site can do.

## When this stops scaling

Honestly: probably around 50 pages, when sectioned nav stops being enough and search becomes mandatory. The manifest data is already in place; `_site/js/search.js` is on the platform backlog. Past that — say, hundreds of pages with internationalization — vanilla starts to creak. But by the time you're there, the cost of migrating to a bundler is paid for many times over by what you saved not adopting one early.

The actual point: *vanilla HTML/CSS/JS in 2026 is more capable than the framework discourse suggests.* You can ship a real site without npm. The discipline is small. The blast radius of any mistake is one file. And future-you doesn't have to keep up with anyone else's release notes to keep your site working.

The repo with this layout: [github.com/kody-w/RAPP/tree/main/pages](https://github.com/kody-w/RAPP/tree/main/pages). Open the source for any page. There's no missing piece.
