---
title: Content Strategy
status: living
section: Plans & Ledgers
type: strategy
hook: One source of truth (the vault), distributed in the shape each medium rewards. Newsletter, YouTube, TikTok, X, LinkedIn, Instagram — each gets a different cut of the same essay.
session_id: 63243848-caa9-483c-9a8e-9bb0ee9d2849
session_date: 2026-04-24
---

# Content Strategy

> **Hook.** One source of truth (the vault), distributed in the shape each medium rewards. Newsletter, YouTube, TikTok, X, LinkedIn, Instagram — each gets a different cut of the same essay.

This is the platform's plan for reaching audiences beyond the GitHub repo and the kody-w.github.io blog. It's a living document — channels and cadences will shift as evidence comes in. The principle stays fixed.

## The principle

Each channel has its own physics: TikTok rewards a 2-second hook; LinkedIn rewards business framing; X rewards real-time conversation; YouTube rewards demonstration; the newsletter rewards depth. **Posting the same content to every channel is the failure mode.** Re-shape per channel; never copy-paste.

The source of truth is always the vault note. The waterfall:

```
Vault note (source of truth)
  → Blog post (kody-w.github.io tagged "rapp")
    ├→ Newsletter issue (full essay or excerpt + this-week section)
    ├→ X thread (5-10 tweets summarizing the argument)
    ├→ LinkedIn post (B2B-shaped excerpt with partner framing)
    ├→ YouTube video (visual / demo if applicable)
    ├→ TikTok or Reel (60-second hook moment)
    └→ Instagram post (visual artifact, code screenshot, before/after)
```

The vault note is written first (or already exists). The blog post anchors the week. The other channels are *projections* of the blog post — same argument, different audience, different shape.

## Channel principles

### Newsletter

> **The deep, considered channel. A direct subscriber relationship.**

- **Cadence:** monthly (1 deep issue) — call it *"From the RAPP Vault"*.
- **Length:** 1,500–3,000 words. The full blog post + a short *"what shipped this week"* footer + a single CTA.
- **Voice:** third-person platform voice (same as the vault).
- **Hosting:** Substack, Buttondown, or owned (depending on tooling preference). Migration cost is low if we change later.
- **Subscribe surface:** README, kody-w.github.io landing, every blog post footer.
- **Best for:** manifestos, removal stories, architecture deep-dives — anything the reader will spend 10+ minutes on.
- **Differentiator vs blog:** owned subscriber list. Algorithms can't deplatform an email list.

### YouTube

> **The visual / demonstrative channel. Workshops and architecture explainers.**

- **Cadence:** 1–2 long-form videos per month + occasional YT Shorts.
- **Long-form length:** 15–30 minutes. Two recurring formats:
  - **"Build an agent in 60 minutes"** — the workshop, recorded. Show the file appearing in the editor; show the chat hitting it; show the customer-style validation.
  - **"Why we did X"** — architecture explainers with diagrams. Anchor to a vault note ([[Data Sloshing]], [[The Single-File Agent Bet]], etc.).
- **Voice:** instructional but still engineer's-notebook — opinion is welcome, tutorial-speak is not.
- **Production:** every video links back to the vault note in the description; embeds the corresponding blog post as the canonical reference.
- **Shorts (60 sec, vertical):** moments — *"we deleted 2,138 lines and here's what we learned in one minute."*
- **Best for:** showing the file. Always show real code. Never use stock footage or generic AI imagery.

### TikTok

> **The hook-first algorithmic channel. Short, visual, shareable.**

- **Cadence:** 2–3 videos per week to feed the algorithm.
- **Length:** 30–90 seconds, vertical, hook in the first 2 seconds.
- **Recurring formats:**
  - **"60-second build"** — time-lapse of a workshop session compressed into a minute.
  - **"We deleted X lines"** — diff visualization with a one-line takeaway.
  - **"Watch this agent ship"** — chat input → agent runs → output appears → caption explains what happened.
  - **"Why we don't have a settings page"** — UX-philosophy hot takes.
- **Voice:** punchy, slightly performative, hook-first. Still honest — no clickbait that doesn't deliver.
- **Audience:** broader and younger than X or LinkedIn; less technical depth, more curiosity.
- **Crossposting:** TikTok content republishes as Instagram Reels and YouTube Shorts the same day. The vertical format ports.

### X (Twitter)

> **The real-time technical conversation channel. Where the AI/dev community lives.**

- **Cadence:** daily presence, ideally multiple posts. Weekly threads.
- **Recurring formats:**
  - **Threads** (5–10 tweets) — each blog post gets one. Lead with the strongest sentence, end with a link.
  - **Replies** to industry conversations (#AIagent, #LangChain, #CopilotStudio, etc.) — earn presence by being useful in others' threads.
  - **Link drops** — a one-line setup + the URL. Used sparingly; threads convert better.
  - **Build-in-public** — *"shipped X today, here's the diff"*-style updates with screenshots.
- **Voice:** opinionated, technical, in-the-conversation. The vault's third-person voice loosens slightly to first-person plural here (X expects a person, not a brand).
- **Best for:** velocity, community-building, rapid feedback on shipping work.

### LinkedIn

> **The B2B / partner channel. Microsoft consultants, enterprise leadership.**

- **Cadence:** 2–3 posts per week + occasional long-form articles.
- **Recurring formats:**
  - **Posts** (200–500 words) — partner-facing excerpts of blog content. Focus on process, partner handoff, the agent-IS-the-spec story.
  - **Articles** (long-form) — manifesto-shaped pieces, especially [[The Engine Stays Small]], [[RAPP vs Copilot Studio]], [[Three Tiers, One Model]].
  - **Newsletter cross-post** — once per month, the newsletter issue lands here as a LinkedIn newsletter article too.
- **Voice:** business-shaped but not corporate. Specifics matter — concrete numbers (60 minutes, 2,138 lines, 47 vault notes) earn trust.
- **Audience:** Microsoft Copilot Studio partners, enterprise architects, decision-makers evaluating agent tooling. Different audience from X.
- **Best for:** the *partner-pricing-an-agent* story, the *Copilot-Studio-handoff* framing, customer-shaped narratives.

### Instagram

> **The visual artifact channel. Code styled, before/after layouts, workshop moments.**

- **Cadence:** 1–2 posts per week.
- **Recurring formats:**
  - **Code screenshots** styled with the vault's accent palette (`#cba6f7` purple, `#89b4fa` blue, `#a6e3a1` green on `#1e1e2e` background).
  - **Before/after** layouts for cleanups (root before / root after).
  - **Workshop moments** — photos of the screen during the *"agent emerges"* phase.
  - **Reels** — same content as TikTok, ported.
- **Voice:** visual-first, minimal text. Captions are short.
- **Audience:** different demographic from X/LinkedIn — younger, more design-aware, less directly technical.
- **Best for:** brand presence, visual identity, the platform-feels-finished signal.

### Hacker News

> **Opportunistic launches, not a continuous channel.**

- Submit specific blog posts when they have a credible *"show HN"* angle. Architecture deep-dives ([[Local Storage Shim via sys.modules]], [[The Deterministic Fake LLM]]) tend to perform; manifestos rarely do.
- One submission per quarter, max. Saturating HN with the same author erodes trust faster than it builds it.

### Reddit

> **Niche subreddit posting; technical discussion.**

- Target subs: `r/MachineLearning`, `r/LocalLLaMA`, `r/programming`, `r/MicrosoftCopilot`, `r/sysadmin` (for the Tier 1 install story).
- One post per quarter per subreddit, max.
- Honesty wins on Reddit. The anti-pitch ([[What You Give Up With RAPP]]) lands better here than on any other channel.

### Podcasts

> **Long-form spoken; opportunistic.**

- Accept invitations from AI/dev podcasts. Don't pitch. The platform's posture is *engine, not experience* — which means the podcast circuit isn't a deliberate channel; we say yes when invited.
- Cross-promote on X, LinkedIn, and the newsletter when an episode lands.

### GitHub Discussions / Issues

> **The community surface. Continuous, but not a "content" channel in the marketing sense.**

- Maintain `Discussions` as the canonical place for ongoing community conversation.
- Issues are for bugs and feature requests; Discussions are for *"how do I…?"* and *"why does it…?"*. Don't conflate them.

## Cadence summary

| Channel | Cadence | Format anchor |
|---|---|---|
| Newsletter | Monthly | Blog-post-as-essay + this-week footer |
| YouTube long-form | 1–2 per month | 15–30 min workshop or architecture |
| YouTube Shorts | 2–4 per month | 60-sec moment |
| TikTok | 2–3 per week | 30–90 sec hook |
| Instagram Posts | 1–2 per week | Visual artifact |
| Instagram Reels | 2–3 per week | Cross-post from TikTok |
| X | Daily, threads weekly | Threads + replies + link drops |
| LinkedIn | 2–3 per week | Posts + monthly long-form article |
| Hacker News | 1 per quarter | Opportunistic launch |
| Reddit | 1 per quarter per sub | Honest deep dive |
| Podcasts | When invited | Cross-promote |

## Content matrix — which post fits which channel

Not every blog post fits every channel. Use this as a default; override when a post earns special treatment.

| Post type (from [[Blog Roadmap]]) | Newsletter | YouTube long | YT Shorts | TikTok | X thread | LinkedIn | Instagram |
|---|---|---|---|---|---|---|---|
| Removal stories (#1, #2) | ✅ | ✅ (diff visualization) | ✅ | ✅ | ✅ | ✅ | ✅ (before/after) |
| Vault / build journals (#3) | ✅ | maybe | — | — | ✅ | ✅ | ✅ (screenshots) |
| Surfaces / PWA / Shortcuts (#4, #5) | ✅ | ✅ (demo) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Manifestos (#7, #20–#24) | ✅ | maybe | — | — | ✅ thread | ✅ article | maybe |
| Architecture deep-dives (#10–#13) | ✅ | ✅ (diagram) | — | — | ✅ thread | ✅ | ✅ (code screenshot) |
| Workshop / process (#14, #15, #16) | ✅ | ✅✅ (the canonical workshop video) | ✅ | ✅ (time-lapse) | ✅ | ✅✅ | ✅ |
| Positioning (#17, #18) | ✅ | — | — | maybe | ✅ thread | ✅ article | — |
| Release posts (#27) | ✅ | maybe | ✅ | ✅ | ✅ | ✅ | maybe |
| Federation / RAR (#28) | ✅ | maybe | — | — | ✅ thread | ✅ | — |

`✅✅` = the channel where this content type performs best.

## First 30-day calendar

To prove the channels work, start with a focused 30-day push aligned to the **Now-tier blog posts** in [[Blog Roadmap]]:

### Week 1

- **Mon:** Blog post #1 *"We Killed a 2,138-Line Mega-Agent"* publishes.
  - Same day: X thread (8 tweets), TikTok (60-sec diff visualization), Instagram code-screenshot post.
- **Wed:** YouTube Short — *"How a 2,138-line agent breaks reviewability"*.
- **Fri:** LinkedIn post — partner-shaped framing of the post (*"this is what scope discipline looks like"*).
- **Sun:** Newsletter — first issue. Lead essay = post #1, this-week footer mentions the PWA ship.

### Week 2

- **Mon:** Blog post #2 *"We Just Deleted 6,500 Lines in One Merge"* publishes.
  - Same day: X thread, TikTok (carousel of deletions), Instagram before/after.
- **Wed:** YouTube long-form — *"A tour of the deletions: hatch_rapp, swarm_server, t2t, and the brief pipeline"* (15 min).
- **Fri:** LinkedIn article — long-form *"What 6,500 deleted lines teach you about agent platform design."*

### Week 3

- **Mon:** Blog post #3 *"We Built a Public Vault for an AI Agent Platform"* publishes.
  - Same day: X thread on the vault layout + the link checker; TikTok screen-recording of the viewer; Instagram screenshots of the graph view.
- **Wed:** YouTube long-form — *"Live tour of the RAPP Vault — wikilinks, backlinks, graph view, PWA install"* (10 min).
- **Fri:** LinkedIn post — *"Why we built a public vault for our platform's institutional memory"*.

### Week 4

- **Mon:** Blog post #4 *"Apple Shortcuts as the watchOS Path"* publishes.
  - Same day: X thread, TikTok (Apple Watch + Siri demo if Shortcut is built by then), Instagram.
- **Wed:** Blog post #5 *"The PWA Bet"* publishes (paired-release week).
  - Same day: TikTok — install the PWA on iPhone in 60 seconds.
- **Fri:** YouTube Short pair — Shortcuts demo + PWA install.
- **Sun:** Newsletter issue 2 — Surfaces theme. Both posts as the lead essays.

After Week 4, drop to steady cadence per the table above. Re-evaluate at Day 30: which channels produced engagement, which didn't, what to drop or double down on.

## Voice & style across channels

**The constants** (every channel):

- No real names, no PII (same rule as the vault).
- Concrete numbers preferred over generic claims (*"60 minutes"* beats *"fast"*; *"2,138 lines"* beats *"large agent"*).
- Honest tradeoffs every time (every post earns trust by naming what RAPP is *not*).
- Code-anchored examples when relevant. Show real files.

**The variations:**

- **Vault / blog / newsletter:** third-person platform voice (*"the platform chose X"*).
- **X / LinkedIn:** loosens to first-person plural in *some* contexts (*"we shipped X today"*) — these channels expect a person.
- **TikTok / Reels:** hook-first, slightly performative. Still honest.
- **Instagram:** caption is short; the visual carries the post.
- **YouTube:** instructional, but never tutorial-pitched. Engineer's notebook tone.

## Cross-promotion mechanics

- Every blog post footer links to the newsletter signup, the X account, the YouTube channel.
- Every newsletter issue links to the blog post and to the X thread (for those who want to share).
- Every YouTube video description links back to the vault note that sources it.
- TikTok / Reel captions point to the blog post URL (yes, despite the "no links in caption" friction — the link gives the curious viewer somewhere deeper to go).
- X bio links to the latest blog post + the vault.

## Analytics minimum

Don't over-instrument. The minimum signal:

- Newsletter open rate + subscriber growth.
- Blog post page views (GitHub Pages doesn't track natively; add a privacy-friendly analytics surface like Plausible if needed, or just the GitHub repo's traffic graph).
- YouTube watch-through (especially the long-form workshop video — high watch-through here is a strong signal).
- X engagement on threads (replies + bookmarks more than likes).
- LinkedIn impressions on long-form articles.

Skip vanity metrics. The question is *did this teach a real reader something they'll act on*, not *how many likes did it get*.

## What this rules out

- ❌ Posting the same content unchanged to every channel. The waterfall demands re-shaping.
- ❌ Pure marketing posts with no substance. Every channel post should reference a real artifact (file, commit, deletion, ship).
- ❌ Hijacking the vault for promotional content. The vault is platform memory; this strategy is platform reach. They feed each other but stay separate.
- ❌ A "growth hacking" mindset that breaks the platform's voice. Honest tradeoffs, code-anchored claims, no clickbait.
- ❌ Outsourcing the writing. The vault is the writer; the channels are the distributor. If a post can't trace to a vault note, it shouldn't ship.

## When to reconsider

Re-evaluate this strategy:

- **Day 30** — first calendar checkpoint. Drop channels that aren't earning attention; double down on the ones that are.
- **Day 90** — full quarter review. Adjust cadence, add channels (BlueSky, Threads, Mastodon if any of those gain real audience for the platform's content).
- **When a channel changes** — every channel will reshape its algorithm or product at some point. The strategy adapts; the principle (one source of truth, distributed in the shape each medium rewards) stays.

## Build-out tasks

Tracked in [[Documentation Roadmap]] under *Now* (channel setup) and *Next* (production templates + first long-form video). Each setup task is small but specific; together they form the ramp from "no channels" to "30-day calendar runs."

## Discipline

- The vault is the source. Every channel post answers *"what vault note does this trace to?"*
- One re-shape per channel; don't paste the blog post across all of them.
- Cadence is a contract with the audience; missed weeks erode trust faster than empty calendars build it.
- Stop a channel cleanly if it doesn't earn attention. Quitting a channel publicly is honest; running a dead channel is misleading.

## Related

- [[Blog Roadmap]] — the 28 source posts feeding this strategy.
- [[Documentation Roadmap]] — internal docs companion + channel setup tasks.
- [[Release Ledger]] — append-only record of what shipped.
- [[How to Read This Vault]] — meta-context for new contributors.
