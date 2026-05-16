---
title: Blog Drafts — README
status: published
section: Blog Drafts
hook: Working copies of blog posts before they ship to kody-w.github.io. One file per post; status frontmatter set to "draft".
---

# Blog Drafts

This folder holds working copies of blog posts on their way to the public blog at `kody-w.github.io` (tagged `rapp`). The roadmap of *which posts to write* lives at [[Blog Roadmap]]; this folder is where the actual prose accumulates.

## Conventions

- One file per post: `<short-title>.md`. Slugify on whitespace; keep ASCII.
- Frontmatter: `status: draft` while drafting; flip to `status: shipped` and add `published_url:` when the post lands on the blog.
- Body shape mirrors the source vault note(s) listed in [[Blog Roadmap]] — same arguments, different audience. The vault note speaks to a contributor; the blog post speaks to a curious technical stranger.
- Wikilinks back to source vault notes are encouraged inside drafts. They won't survive the export to the blog (the blog doesn't render `[[wikilinks]]`), but they help the reviewer trace claims back to the long-form essay.

## Lifecycle

1. **Draft.** Create `<short-title>.md` in this folder. `status: draft`. Iterate.
2. **Review.** Once the prose is tight, share the draft (still as a vault note) for a single review pass.
3. **Publish.** Push to `kody-w.github.io` tagged `rapp`. Add the live URL to the draft's frontmatter as `published_url:`.
4. **Mark shipped.** Flip frontmatter `status: draft` → `status: shipped`. Move the entry in [[Blog Roadmap]] from Now/Next/Later to the **Shipped** section with a link to the live post.

## Why drafts live in the vault

Three reasons:

- The vault is already the platform's writing surface; drafts inherit the link checker, the PII guardrail, the search, the viewer.
- Drafts evolve alongside the vault notes that source them — a sharper draft often surfaces gaps in the source note, and edits flow back upstream cleanly.
- The Obsidian-compatible vault is where the user already writes; one writing surface beats two.

## Status the link checker tolerates

`status: draft` is added to the valid set in `tests/vault-check.mjs`. Drafts are not required to be in the manifest (the checker only warns on filesystem-but-not-manifest); they show up in the viewer's sidebar via the manifest entry the author chooses to add when they want preview.

## Related

- [[Blog Roadmap]] — the index of which posts to write.
- [[Documentation Roadmap]] — internal docs companion.
- [[How to Read This Vault]] — meta-context for first-time vault readers.
