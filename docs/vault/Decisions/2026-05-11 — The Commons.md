---
title: The Commons
date: 2026-05-11
status: shipped
tags:
  - decision
  - neighborhood
  - commons
  - federation
  - egg
  - tether
  - pyodide
  - qrious
---

# The Commons — design decisions, preserved

The Commons (`kody-w/rapp-commons`, planted 2026-05-11) is the archetype neighborhood. Multiple load-bearing decisions went into it during a single afternoon of iteration; this note exists so they're recoverable if anyone proposes relaxing one of them later.

## 1. Why a sibling repo, not `neighborhoods/commons/` inside RAPP

The initial proposal was to put the commons at `neighborhoods/commons/` under the RAPP repo root. Rejected after one round because:

- **Identity hygiene.** The commons needs its own permanent rappid; mixing it with RAPP's species-root rappid in the same git tree muddies the lineage. As a sibling repo, the commons is a planted *child* of RAPP, just like `rapp_store`, `RAR`, `RAPPcards`, `rappterbox`. It's discovered by following the same pattern, not a special case.
- **End-to-end demonstration.** The whole point of having a commons is to show "you can plant a neighborhood, and here's one you can join." A subdir doesn't demonstrate the planting flow; a real planted repo does. Anyone evaluating RAPP can now point at `kody-w/rapp-commons` and say "and this is what one looks like."
- **Federation address.** The federation roll-up needs a canonical URL for each neighborhood, derived from its rappid. A sibling repo with `github.com/kody-w/rapp-commons` as its host part naturally fits the rappid v2 schema. A subdir would need a special-case "rappid-in-path" rule.

**Trade**: cloning RAPP no longer gives you the commons content in the same checkout. We compensate by maintaining `examples/rapp-commons/` in RAPP as the source-of-truth scaffold (verbatim copy of the planted repo's contents); pulling RAPP still includes the offline-runnable demo, AND the live planted version exists.

## 2. Event-stream-only quirk, not shared mutable state

The user asked: "without divergence." Two options were on the table:
- **Event-stream-only** — append-only signed events keyed by `(from, ts)`. Two clones can mutate offline indefinitely and reconcile losslessly because no event mutates another.
- **Shared mutable state** — leaderboards, decks, wikis. Requires LWW or per-key rappid ownership; offline operators inevitably collide on shared keys.

Picked event-stream-only because (a) the user's explicit constraint was "no divergence" and the CRDT-trivial guarantee is the strongest one available, (b) memory feedback already locks down "only rappid+timestamp is universal" — extending the commons with shared state would generalize the wrong primitive, (c) the commons is supposed to be the *floor*, not the kitchen sink — neighborhoods that need shared state plant their own flavor.

**Trade**: no real-time interactive feel. No "current leaderboard" in the commons itself. That's intentional.

## 3. Virtual coordinates inside the neighborhood; physical anchor optional

The user introduced the dual coordinate model mid-build: "a neighborhood can be planted both physical (lat/long on earth) or virtual lat/long in a virtual environment that is enclosed in the neighborhood itself for collaboration." This generalized the `coordinates` field on the `rapp-neighborhood/1.0` schema:

```json
{
  "coordinates": {
    "physical": null | { schema, geohash, lat, lng, radius_m },
    "virtual":  null | { schema, type, bounds, spawn, movement, render_hint }
  }
}
```

The commons has `physical: null` (it is *deliberately global*) and `virtual: { type: town-square }`. Other neighborhoods can flip the combination — a "Pizza Place" pattern from `HERO_USECASE.md` would be `physical: { geohash: ... }` + `virtual: null`. A "VR meeting room" pattern would be `physical: null` + `virtual: { type: "room", ... }`. Both axes are independent.

**Trade**: schema is now wider than strictly needed for v1 commons. Accepted because the alternative — defining only the slice needed today and growing the schema later — would force a v1 → v2 migration the moment we plant the second neighborhood.

## 4. Pyodide-loaded agent + WebCrypto signing (the tether pattern)

The Commons tether (`tether.html`) needs to compose, sign, and post events from a browser. The architecture decision was: **split compose (Python, deterministic, identical in Pyodide and server) from sign (host-environment, key-bound)**.

- Compose lives in `@rapp/commons_post_agent.py` (RAR). Validates inputs against `events/SCHEMA.md`, builds the canonical event JSON, returns a "signing intent" with the canonical payload ready to be signed.
- Sign lives in the host. In the browser tether: `crypto.subtle.sign({name:'ECDSA',hash:'SHA-256'}, privKey, payload)` using the operator's ECDSA P-256 key stored in `localStorage`. In a server brainstem: same agent, signing happens via `~/.brainstem/keys/operator.jwk.json` and openssl.
- Stage lives in `@rapp/estate_outbound_agent.py` (RAR). Takes the signed event, writes it to `~/.brainstem/outbound/<neighborhood-rappid>/<filename>.json`. The host operator publishes the outbound lane to their public-estate repo when they want federation to pick it up.

This split keeps the private key out of the agent layer (agents never see it) AND lets the same Python validation code run identically in Pyodide and a standard server brainstem. The same pattern works for any neighborhood that wants a per-quirk post agent.

**Trade**: three pieces (compose / sign / stage) instead of one fat "post" call. Worth it because the key never enters Python memory — even a hostile Pyodide injection can't exfiltrate it.

## 5. QRious for the QR

The QR generator choice was small but worth recording: **QRious** (https://github.com/neocotic/qrious, MIT) via CDN jsdelivr. Considered alternatives:
- **qrcode.js** — more popular but heavier API surface.
- **qrcodegen by Nayuki** — strongest cryptographic implementation but the public API is more complex than this use case warrants.
- **Roll our own** — rejected; QR encoding is a solved problem and a poor place to write new code.

QRious is single-purpose, ~50 KB minified, simple API (`new QRious({element, value, size, level})`). The tether's `<script src="...qrious.min.js">` is the only third-party dep beyond Pyodide.

**Trade**: dependency on jsdelivr CDN. The fallback path in `index.html` shows the URL plainly when the CDN is unreachable so the page still degrades gracefully.

## 6. Outbound-lane federation, not push-based

The federation model is **pull, not push**: the commons GitHub Action runs every 10 minutes, walks `members.json`, fetches each member's `<owner>-estate/outbound/<commons-rappid-slug>/` directory via the GitHub contents API, verifies signatures, and unions into `events/`.

Considered push-based (operators POST events to a commons endpoint). Rejected because:
- **No server.** The commons is static files on GitHub Pages. There's no endpoint to receive a POST.
- **Trust model.** Pull means the commons is the trust boundary; the action verifies each signature itself before accepting. Push would require either (a) trusting the operator's HTTP envelope on top of the inner signature, or (b) implementing a webhook receiver, which we don't have.
- **Resilience.** Operators can stage offline indefinitely; the next pull picks up whatever accumulated.

**Trade**: 10-minute beat is slow for "real-time chat" feel. Accepted — the commons isn't a chat room, it's a cross-estate event stream. If you want sub-second exchanges, that's a tether-to-tether WebRTC pair (SPEC §18.11), not the commons.

## 7. Membership canonical address: each operator's estate, not `members.json`

`members.json` in the commons is regenerated by the federation roll-up. Per Article XLVI, canonical membership lives in each operator's *two-tier estate* `member[]` (their `~/.brainstem/estate.json`). The commons's `members.json` is just the federation's view; the operator's estate is the source of truth.

This matters because: if the commons repo gets nuked, every operator's membership survives (in their estate). Rebuilding the commons just means rerunning the roll-up. The commons is not a single point of failure for who-is-a-member.

## 8. "Talk to the Commons" — local brainstem, not Doorman

The tether's greeter panel POSTs to `localhost:7071/chat` with `soul.md` as the system prompt. Considered cloning the Doorman pattern (Cloudflare Worker → Copilot) from `vbrainstem.html`. Picked local-brainstem-only for v1 because:
- Doorman requires the `RAPP.Doorman` namespace clone, localStorage settings handshake, and a working Cloudflare Worker — substantial surface to bring in.
- Operators visiting their own commons tether almost always already have a brainstem running locally (`./start.sh`).
- The greeter degrades clearly when no brainstem is reachable ("start ./start.sh and reload, or use the visit-only mode"). Read-access to the event stream doesn't require the soul.

**Trade**: a fresh visitor with no local brainstem can read the stream but can't chat with the soul. The fallback message is clear enough that this isn't confusing — and the path forward (install rapp-installer, run start.sh, return) is short.

## 9. RAR-resident, not kernel-shipped

Egg_hatcher (2026-05-10 commit), Twin (same), and now commons_post + estate_outbound — none of these ship in the base brainstem install. They live in RAR (`kody-w/RAR/agents/@rapp/`) and operators install them on demand once they want to participate. The kernel stays minimal: `basic_agent`, `context_memory`, `manage_memory`, `learn_new`, `swarm_factory`, `hacker_news`.

Reason: the commons (and neighborhoods broadly) are an opt-in capability, not a baseline behavior. Operators who never want to participate in a neighborhood should never pay the discovery + maintenance cost. This matches the pattern shipped in the prior `binder concept removed entirely` arc — agent collection IS the agents/ directory; what you install is what runs.

## 10. The wire-protocol field rename pending

The chain-state migration from `binders` → `identities` (last week's binder rip) is still pending on the external chain API server. The store.html has graceful fallback shims (`chainState.identities ?? chainState.binders`, `/identities/{addr}.json` falls back to `/binders/{addr}.json`, `claim.identity ?? claim.binder` in verify). Nothing in the commons depends on the chain API today — the commons identity layer is its own per-operator ECDSA keypair in `localStorage`, separate from the chain-state binder-wallet system in `store.html`.

If/when those two identity systems converge (e.g., the commons uses chain-state-bound identities for sticky reputation), the migration matters. Today they're orthogonal.

---

## Files this decision produced

| File | What |
|---|---|
| `kody-w/rapp-commons/` | Live planted repo. |
| `kody-w/RAPP/examples/rapp-commons/` | Source-of-truth scaffold in the parent. |
| `kody-w/RAR/agents/@rapp/egg_hatcher_agent.py` (v1.1.0) | `_route_neighborhood` is real, not "manual instructions". |
| `kody-w/RAR/agents/@rapp/commons_post_agent.py` (v1.0.0) | Compose half of the post pipeline. |
| `kody-w/RAR/agents/@rapp/estate_outbound_agent.py` (v1.0.0) | Stage half of the post pipeline. |
| `kody-w/rapp-commons/.github/workflows/federate.yml` | Pull-based federation roll-up on 10-min cron. |
| `kody-w/rapp-commons/tools/federate.py` | The Python script the workflow runs. Stdlib-only; verifies ECDSA P-256 via openssl-cli on the runner. |
| `kody-w/rapp-commons/tether.html` | Pyodide + WebCrypto + QRious; the working tether. |
| This vault note | Preserve the why. |
