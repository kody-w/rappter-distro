---
title: Welcome
description: Entry point for the RAPP Vault — the second-brain wiki for the platform.
---

# RAPP Vault

This folder is a real Obsidian vault. Open it directly with **File → Open folder as vault** in any Obsidian client and it Just Works. The same files are also served through a static HTML viewer at [`pages/vault/`](../pages/vault/index.html).

## What this is

The vault is the platform's **long-term memory**. It's where the *why* behind every decision lives — the kind of knowledge that rots if it's not written down within days of the call being made:

- Founding decisions and rejected alternatives
- Architecture moments worth remembering
- Code that was deleted and the lessons it left behind
- Honest tradeoffs we don't put on the marketing pages
- Twin / UX philosophy beyond what the constitution captures
- Process stories from running real workshops

If a thought belongs in a commit message, write a commit message. If it belongs in a blog post, write it in the vault.

## How to use it

- **As a wiki**: open [`pages/vault/index.html`](../pages/vault/index.html) on GitHub Pages — it pulls the markdown live from this folder and renders backlinks, wikilinks, and full-text search.
- **As an Obsidian vault**: clone the repo, point Obsidian at this folder, edit normally. The viewer respects whatever you write.
- **Offline**: the viewer caches everything to `localStorage` on first load and supports zip export/import so you can take the whole vault home and bring it back.

## Stub vs. published

Every note has `status: stub` or `status: published` in its frontmatter. Stubs are placeholders — they hold the slot so the wiki shows the topic exists, even before someone writes the post. The bar for converting a stub to a published note is one thing: **the why is captured well enough that someone who wasn't in the room can apply it.**

## Index

See [[_index]] for the full list, organized by category.
