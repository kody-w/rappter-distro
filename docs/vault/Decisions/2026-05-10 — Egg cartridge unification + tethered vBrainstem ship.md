# 2026-05-10 — Egg cartridge unification + tethered vBrainstem ship

**Status:** Shipped. SPEC.md §18.10–§18.12 published. RAPP@~01fddd7+, rappterbox@~16f1f75+, RAPP-private repo created.

## What we shipped

Three load-bearing primitives, one architectural lift:

1. **The `.egg` cartridge family** — same `.egg` extension now carries five kinds (`organism` / `rapplication` / `session` / `neighborhood` / `estate`), all addressable through one universal kernel `egg_hatcher_agent.py` that introspects the manifest schema/type and routes by kind. Refuses on unknown kinds; never destructive fallback.

2. **Tethered vBrainstem** — public surface at `pages/vbrainstem.html`. Multi-participant browser-tab session: QR pair → WebRTC data channel (ECDSA P-256 keypair + 6-digit safety code), host owns LLM dispatch, joiner relays. The Coordinator persona (operator's autonomous twin) drives a structured 4-step debate workflow that both screens watch live.

3. **Three exchangeable LLM backends** behind one internal `Doorman.chat({ system, history, message })` API — localhost `:7071` (default), `?brainstem=URL` override, `?copilot=1` for the Doorman + Pyodide-loaded Python agents path. Same vbrainstem.html, three transports.

## Why each decision was made

These are the WHYs that won't be in the code or the SPEC and would otherwise rot in commit messages.

### Why eggs unified — carts ARE eggs

The day started with `rappterbox-cart/0.1` as a fresh format invented in isolation. After ~6 hours of building it out, the operator asked: *"should the carts just be .eggs???"* and then expanded the same minute: *"but the .egg could also be a neighborhood, and even estate..."* — and the architecture clicked.

A cart, an organism, a rapplication, a neighborhood, an estate — all "portable bundles with manifest + payload + state." Two formats for what's structurally one thing was debt I introduced by designing the cart in isolation. Unifying:
- Single `.egg` extension across the ecosystem (sneakernet UX consistency, rappzoo Pokédex consistency)
- One universal hatcher with introspection-based routing
- Adding a new portable artifact kind = adding a row to the family table
- Each kind gets its own variant (organism+rapplication are ZIP because they have directory trees; session is JSON-only because it's runtime + transcript)

The rule we baked in: **the hatcher never guesses**. Unknown cartridge kinds get a clear "I don't know how to hatch this" reply with the family table, never a silent or destructive fallback. This is the difference between a universal tool and a footgun.

### Why localhost is the default LLM (not Copilot)

Started the day defaulting to localhost, switched to Copilot via Doorman after the operator's first phone-pair test failed (no LLM responses), then switched BACK to localhost after Copilot exchange returned 401 (Copilot subscription gate).

The operator's specific request: *"set the vbrainstem back to the localhost tether for the tab based for the collaboration to make this work better."*

Right call for tab-based collab:
- Real `/chat` with full agent tool routing — the local kernel already has every agent installed
- No Copilot subscription gate (the 401 we hit was the killer)
- Joiner (phone) relays through host over WebRTC; only host needs the brainstem
- Operator already runs brainstem.py locally; assumed-default

Copilot stays available as `?copilot=1` opt-in — for visitors who don't have a local kernel running. The Pyodide agent loader only fires when in `?copilot=1` mode (no point loading 3 Python agents into the browser when the local kernel already has them).

### Why Pyodide agents in the page (when ?copilot=1)

The operator's directive: *"these brainstems should use the pydodid to run the actual python agent.pys (which should be memory agents, basic_agent.py and hacker_news_agent.py)."*

When the page is talking to Copilot directly (no local brainstem), it still needs to provide the LLM with tools — the canonical RAPP agents. Pyodide loads `basic_agent.py` + `hacker_news_agent.py` + `manage_memory_agent.py` + `context_memory_agent.py` from `raw.githubusercontent.com/kody-w/RAPP/main/`, presents them as OpenAI tool defs, dispatches tool_calls in-browser via `agent.perform()`. The page IS the brainstem when there's no local one.

Same pattern as `pages/sphere.html` — clone the `RAPP.Doorman` namespace, reuse `localStorage.rapp_settings` (single sign-in across the kody-w.github.io origin).

### Why the Coordinator persona (and not just round-robin)

The operator described it: *"one is the twin of the user so they take the place of the user in the chat to drive the workflow autonomously while I can watch on both screens on my phone AND computer browser tab as they accomplish the task and report back in the chat for me to review their output."*

The Coordinator is the **operator's autonomous twin** — issues operator-shaped messages (that drive other twins) on the operator's behalf, so the operator can watch a workflow execute on both screens without typing every prompt. Not a special construct; just a participant with a particular persona seed and the demo state machine targets it.

Free-text composer input also routes to Coordinator by default (`@TwinName` overrides). The Coordinator is the always-available default responder.

### Why Edge Tracking Prevention forced an in-memory mirror

Edge with strict Tracking Prevention silently blocks `localStorage` on origins it heuristically classifies. We saw 12 "Tracking Prevention blocked access to storage" lines in the operator's console; their Copilot sign-in flow appeared to hang because the auth token was being saved to a blocked store and read back as null.

Fix: in-memory mirror (`_memSettings`) as the source of truth. Token lives in JS state for the session; localStorage is best-effort write for persistence. Tradeoff: token doesn't persist across reloads on Edge with strict TP (operator has to re-auth each tab open, OR add `kody-w.github.io` to Edge → Privacy → Tracking Prevention exceptions).

The page surfaces a yellow warning when storage-blocked is detected — clear path to the exception setting, OR alternative-browser pointer.

### Why we kept `pair.html` (and shipped a separate `vbrainstem.html`)

`rapp_brainstem/utils/web/pair.html` is the predecessor experiment (same PeerJS pattern, same crypto). Its docstring says "DELIBERATELY a SEPARATE file from the main vbrainstem so any breakage stays contained here." That isolation discipline is right; we extended it.

`pages/vbrainstem.html` is the *public* canonical implementation (under github.io, no install required). Different audience, different concerns. They share the crypto/handshake patterns (vbrainstem.html copied them verbatim) but live separately. The pair.html docstring's reference to "the main vbrainstem" now points at the wrong file — that comment is stale and should be updated next release.

## What the patent context is (private)

`WH-2026-002` (drafted in `kody-w/wildhaven-ceo/legal/patent/`, collaborator-gated) covers three claim families:
- §7.21 — cart-as-workflow-session-with-embedded-runtime (the format)
- §7.22 — recursive iframe sub-tether (planned, not yet shipped)
- §7.23 — multi-participant browser-tab with operator-mic priority intervention (the tether)

Filing posture: NOT Alleman Hall LLP (conflicted — they represent both MS on RAPP patent 506590-US01 AND Wildhaven on WH-2026-001). Need a non-conflicted IP boutique. Phase 1 cost estimate: $11K–18K to lock priority date before public launch.

## What we explicitly deferred

- **CONSTITUTION Article L** for the vBrainstem-tether-as-multi-participant-session-primitive — needs the operator's voice; AI shouldn't author constitutional articles.
- **Auto-hatch for `neighborhood` and `estate` cartridges** — `egg_hatcher_agent.py` returns manual instructions for these kinds. Auto-mint via `gh repo create` + scaffold is the next iteration.
- **Recursive sub-tether (§7.22)** — defer to v0.4 alongside the auto-hatch work above.
- **Sealed manifest signature using the operator's Binder ECDSA key** (per WH-2026-001 Claim 4) — defer to v0.4.
- **Old `vbrainstem.cart.json` redirect shim** — kept for one release as a polite bookmark redirect; delete on next major.
- **Edits to §0–§17 of SPEC.md** — frozen v1; addenda only in §18.

## Files touched today

- **RAPP repo:** `pages/vbrainstem.html` (new, ~1,700 lines), `tests/vbrainstem-smoke.mjs` (new), `rapp_brainstem/agents/egg_hatcher_agent.py` (new), `pages/docs/SPEC.md` (+§18.10–§18.12), `pages/docs/PUBLIC_PRIVATE_BOUNDARY.md` (§1.5–§1.8 added earlier in session, then cartridge cross-ref added), `CLAUDE.md` + `CONSTITUTION.md` (XLIX added earlier) + `ECOSYSTEM.md` + `ECOSYSTEM_MAP.md` + `HERO_USECASE.md` + `OSI.md` + `NEIGHBORHOOD_PROTOCOL.md` + `SURVIVAL.md` + `MASTER_PLAN.md` + `README.md` + `pages/docs/VERSIONS.md` + `pages/docs/AGENTS.md` + `pages/docs/skill.md` + `pages/docs/ROADMAP.md` + `pages/docs/SUBSTRATE_FEDERATION.md` + `pages/docs/ESTATE_SPEC.md` + `pages/docs/rapplication-sdk.md` + `pages/_site/index.json` + `rapp_brainstem/CLAUDE.md` (cross-references)
- **rappterbox repo:** `carts/SCHEMA.md` (rewritten as egg-family doc), `carts/vbrainstem.egg` (new), `carts/vbrainstem.cart.json` (deprecated redirect-shim), `console.html` (accept new schema + corr-id echo)
- **wildhaven-ceo repo:** `legal/patent/WH-2026-002-rappterbox-claim-cluster.md` (private, collaborator-gated)
- **RAR-private repo:** created; `agents/lawyer_agent.py` + README + .gitignore

## Reading order for archaeology

If future-us is debugging a cart or wondering why a particular decision was made:

1. `pages/docs/SPEC.md` §18.10 — cartridge family table (the contract)
2. `kody-w/rappterbox/carts/SCHEMA.md` — session-egg spec (the format authority)
3. `pages/docs/SPEC.md` §18.11 — vBrainstem tether primitive (the surface)
4. This decision note — the WHY each call went the way it did
5. `rapp_brainstem/agents/egg_hatcher_agent.py` — the routing implementation
6. `pages/vbrainstem.html` — the live implementation
