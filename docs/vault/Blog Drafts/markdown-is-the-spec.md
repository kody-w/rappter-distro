---
title: Markdown is the spec; HTML is the rendering
status: shipped
published_url: https://kody-w.github.io/2026/04/24/markdown-is-the-spec/
section: Blog Drafts
hook: Two viewers in the same project. Both ship raw markdown plus a tiny HTML/JS shell that renders it. Why this pattern beats either "ship docs as HTML" or "ship docs as markdown only."
date: 2026-04-24
class: evergreen
decay: low
---

# Markdown is the spec; HTML is the rendering

Most projects pick one of two extremes for their docs:

**Option A — ship raw markdown, let GitHub render it.** The repo's `docs/` folder has `.md` files. GitHub renders them on the web. Anyone offline gets plain text. The project doesn't own the rendering; GitHub does.

**Option B — ship a docs site.** Mkdocs, Docusaurus, Astro, Nextra. The repo has source markdown in some folder, plus a build step that turns it into a styled, navigable site with search and theming. The project owns the rendering — but now the project also owns a build step, a static-site generator's release cycle, and a deployment pipeline.

The project this article documents picked a third option: ship raw markdown, *and* ship a tiny HTML/JS shell that renders it. The markdown stays the source of truth. The HTML shell is a rendering layer over the same files. Two viewers, same data, no build step.

This post is about why that combination is the right answer for a community-facing platform.

## The pattern

`pages/docs/` contains seven files: `SPEC.md`, `ROADMAP.md`, `AGENTS.md`, `VERSIONS.md`, `skill.md`, `rapplication-sdk.md`, and a `README.md` for the directory. They're plain markdown. Nothing prevents a reader from opening one in a text editor or in GitHub's renderer. The files are the source of truth; nothing is generated.

Alongside the markdown sits `pages/docs/index.html` (a docs landing page with cards) and `pages/docs/viewer.html?doc=SPEC` (a viewer that renders the requested markdown file with the site's theme, a sticky table of contents, and an active-heading scroll-spy).

The viewer is ~150 lines of vanilla JavaScript plus marked.js loaded from a CDN. When a visitor lands on `?doc=SPEC`, the viewer fetches `SPEC.md`, parses it with marked.js, injects the HTML into the page, builds a ToC from the headings, and styles it with the same `_site/css/*.css` files that drive the rest of the site. The page renders in roughly the time the markdown takes to fetch.

The same pattern repeats for the project's vault — long-form decision narratives written as markdown notes. The vault has its own viewer (`pages/vault/index.html`) which is a more elaborate SPA (wikilinks, backlinks, JSZip export, search), but it's the same shape: the markdown is the source; the HTML is the rendering.

## Why this beats either extreme

**Against "raw markdown only":** GitHub-rendered markdown is fine for contributors but limited for visitors. No theming. No site nav. No search. No way to build cross-document discovery features. A visitor following a link from a marketing page lands on raw GitHub UI, which is correct for engineers and jarring for everyone else. The same content should be reachable in *both* contexts — read on GitHub for the source, read on the docs site for the visitor experience.

**Against "build-step site":** The build step is a permanent maintenance liability. Hugo's release notes. Docusaurus's Node version drift. The CI pipeline that breaks when the static-site generator updates. The deploy that needs to happen separately from the source push. None of these are individually catastrophic; collectively they're the difference between "we maintain a docs site" and "we maintain a project."

The viewer-over-raw-markdown pattern lands in between. The project owns the rendering, so visitors get a real site. The project doesn't own a build step, so the maintenance liability is roughly *one HTML file plus one JS file*. When the platform changes, the markdown changes; the viewer doesn't. When the viewer needs a new feature, only the viewer changes; the markdown stays unchanged.

## What the markdown can do that HTML can't

The choice to keep markdown as the source isn't just a matter of writing comfort. It's load-bearing for several specific reasons:

**An LLM can read it.** Markdown is what models prefer. They were trained on it. The viewer is for human visitors; the LLM fetches `SPEC.md` directly and gets clean structure. This is why `skill.md` (a separate post in this series covers it) is markdown — it's the file an AI assistant fetches when it needs to know how to install the project. If `skill.md` were HTML-only, the LLM would have to parse out the chrome before getting to the content.

**`git diff` is meaningful.** A change to `SPEC.md` shows up cleanly in code review. Adding a row to a table is one line. Changing a paragraph is the paragraph plus its context. HTML diffs are dominated by tag noise; markdown diffs are dominated by content.

**Wikilinks survive.** The vault uses Obsidian-style `[[wikilinks]]` between notes. The viewer (and Obsidian itself, when someone opens the same folder as a vault) renders them as clickable links. HTML doesn't have wikilinks; you'd need to either translate them at build time (build step!) or write JS that does it at render time (the viewer already does).

**The file IS the artifact.** Anyone who clones the repo gets the full docs offline. A Markdown file is a complete, readable, transportable artifact. An HTML file in a static-site-generator's output is incomplete — it depends on other files (CSS, JS, images) that are also part of the artifact and have their own URLs. Markdown is mailable; HTML is a website.

## What the HTML viewer can do that markdown can't

The flip side: there are real things visitors want that raw markdown doesn't deliver.

**Theming.** The viewer applies the same dark/light tokens, header, and footer as the rest of the site. A visitor jumping from the FAQ page to the SPEC doesn't experience visual whiplash.

**A table of contents.** marked.js parses headings; the viewer builds a ToC sidebar with active-heading scroll-spy. GitHub's rendered markdown has a static ToC link generator that doesn't follow the reader as they scroll.

**Cross-document navigation.** The viewer's header links to other sections of the site. GitHub's rendered markdown is terminal — every link is "leave."

**Anchor links per heading.** The viewer adds a `#permalink-1` style anchor to every heading on hover, copyable to the clipboard. Useful for linking to a specific clause in a long spec.

**Mobile-friendly typography.** The viewer's CSS targets long-form reading. GitHub's rendered markdown is designed for code review.

**Search and discovery hooks.** The viewer reads `pages/_site/index.json` (the site manifest) and can wire docs into site-wide search later. Raw markdown is opaque to that pipeline until something parses it.

## When the pattern is right

Three conditions make this pattern fit a project well:

1. **You want both an LLM-readable form and a human-friendly form, and you don't want to maintain two copies.**
2. **Your content updates more often than your viewer does.** A spec or doc that changes weekly with a viewer that changes quarterly is the right shape.
3. **You can tolerate "the viewer is JS-required."** Visitors with JS disabled see raw markdown via the file URL — which is fine, because *the markdown is the spec, the viewer is the rendering.* They get the spec. They don't get the chrome. That's correct.

If your project doesn't meet all three, pick one of the simpler extremes. Raw markdown is fine. A build-step docs site is fine. The middle path earns its complexity only when you need both.

## Implementation, in 200 lines

The total cost of the pattern in this project:

- One `viewer.html` (the shell). ~50 lines.
- One `doc-viewer.js` (loads marked.js, fetches the markdown, parses, builds ToC, scroll-spy). ~120 lines.
- The shared `_site/css/doc.css` for markdown styling. ~80 lines.
- An allowlist of `.md` filenames the viewer is willing to render (so URL params can't open arbitrary files). ~5 lines.
- A small docs landing page (`docs/index.html`) with cards linking to each doc. ~80 lines.

Around 300 lines of vanilla code, no dependencies beyond the marked.js CDN. The pattern is small enough that someone can read the whole implementation in fifteen minutes and understand exactly how the system works. No magic. No build cache. No invalidation logic. The markdown changes; the page reloads; the new content renders.

## What this rules out

Two forms of feature creep this pattern actively prevents:

**Don't add a build step "for performance."** The viewer is fast enough. marked.js parses 10KB of markdown in single-digit milliseconds. Pre-compiling the markdown into HTML at build time saves nothing the visitor would notice and adds the maintenance burden the pattern was designed to avoid.

**Don't add features that require parsing markdown server-side.** "Generate a search index from all the markdown" sounds reasonable until it requires a build step. Either build the search index manually (fast, simple, what the project's `_site/index.json` does) or skip it. Don't compromise the *no build step* property to gain a feature you can deliver another way.

The pattern is a *constraint that protects a property.* The property is "edit markdown, refresh browser, see updated content." That property is what makes contribution easy. The constraint is what keeps the property alive.

## Receipts

- The docs viewer: [`pages/docs/viewer.html`](https://github.com/kody-w/RAPP/blob/main/pages/docs/viewer.html), `pages/_site/js/doc-viewer.js`.
- The vault viewer (more elaborate, same pattern): `pages/vault/index.html`.
- The shared markdown styling: `pages/_site/css/doc.css`.
- An example doc the viewer renders: [SPEC.md](https://github.com/kody-w/RAPP/blob/main/pages/docs/SPEC.md), live at `https://kody-w.github.io/RAPP/pages/docs/viewer.html?doc=SPEC`.

The platform's working knowledge: *markdown is the spec, HTML is the rendering.* Two viewers, same data, no build step. The project owns enough to give visitors a real experience and not so much that maintenance becomes its own job.
