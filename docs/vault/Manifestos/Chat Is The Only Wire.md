---
title: Chat Is The Only Wire
status: published
section: Manifestos
hook: Every brainstem ever shipped speaks the same `/chat`. That is the contract — and the acid test that proved it caught a real divergence we didn't know we had.
---

# Chat Is The Only Wire

> **Hook.** Every brainstem ever shipped speaks the same `/chat`. That is the contract — and the acid test that proved it caught a real divergence we didn't know we had.

## The claim

A human typing into the chat UI, an agent invoking another agent, a peer brainstem reaching across the network, and an MCP client over stdio all hit **the same endpoint with the same envelope and get back the same envelope**. The brainstem does not know — and must never need to know — which kind of caller is on the other end.

That property is what makes RAPP an engine, not a product. Engines don't care who's pulling the lever.

## Why this had to become sacred

It was already true. We just hadn't named it. The acid test that prompted Article XXV was simple: spin up a v0.6.0 brainstem from `kody-w/rapp-installer` (a version six minor releases behind), have a v0.12.2 brainstem chat with it, and see whether they could collaborate.

They could. The legacy brainstem accepted a chat with a `user_guid` field it had never heard of, ignored the unknown field, and responded normally. Asked "tell me what you are and what agents you have," it returned a JSON description of itself. Asked to use its HackerNews agent and return the top 2 stories, it tool-called HackerNews and returned the stories. No special handshake protocol. No version negotiation. No new endpoint. Just chat.

If a brainstem from a year ago can collaborate with a brainstem from today through nothing more than `/chat`, then `/chat` is the contract — whether we want it to be or not. The acid test forced us to admit that.

## What the acid test caught that we didn't expect

The same test ran against the CA365 lineage — `Copilot-Agent-365` (the original), `CommunityRAPP` (the public Azure-hosted version), and `rapp_swarm/function_app.py` (current Tier 2). All three return the assistant's reply under the key **`assistant_response`**. The Tier 1 `rapp_brainstem` lineage returns it under **`response`**.

That divergence was a tier parity violation hiding in plain sight. Article XV ("Tier Parity Is a `/chat` Contract") was already broken at the response envelope level. A peer brainstem from the CA365 family looking for `assistant_response` would receive `response` from a Tier 1 brainstem and find an empty key.

The fix was the only fix Article XXV allows: **additive**. Both Tier 1 and Tier 2 now emit BOTH keys with the same value. Old clients keep working. New clients keep working. Nobody had to coordinate.

This is what the additive-only rule buys: when you discover drift, you fix it without breaking anyone. If the rule were "rename to align," every old brainstem in the wild would silently break the day a new one shipped. With additive-only, the new one just emits both shapes and the old ones keep landing on the data they expect.

## Why no handshake, no meta agent, no sacred soul section

Every time we tried to add ceremony — a `BrainstemMeta` agent, a `meta.kind === "handshake"` field, a sacred section in `soul.md` teaching the brainstem to recognize peer questions — the legacy v0.6.0 brainstem proved we didn't need it. It answered the questions through normal chat, with no convention installed, no agent shipped, no soul edited.

The lesson: **discovery is just chat**. The LLM has the agent list (it's the tool definitions), the soul, and `/health` for deterministic structured info. When asked "what can you do," it answers. When the asker is a peer brainstem that wants to parse the answer programmatically, the LLM is robust enough to format JSON inline if the question shape suggests a machine reader. None of this requires kernel support.

The kernel's job is to deliver the chat. Everything else is emergent.

## The default GUID spells "copilot"

A subtle decision worth preserving: the `DEFAULT_USER_GUID` is `c0p110t0-aaaa-bbbb-cccc-123456789abc`. The `p` and `l` in `c0p110t0` make the string un-parseable as a real UUID — it spells "copilot" visually while being deliberately invalid hex.

This is a security feature inherited from `Copilot-Agent-365`. The default identity:

1. **Can never collide with a real user's UUID** (a real UUID would parse as hex)
2. **Gets rejected by UUID-validating columns** so accidental persistence fails loudly
3. **Surfaces unmistakably in logs as "no real user context"** — anyone reading logs sees the pattern and knows
4. **Routes to shared global memory in the storage shim**

A future contributor would look at this and want to "fix" it to a valid UUID. Don't. The invalidity *is* the contract. It's the kind of clever architecture decision Article XXIII exists to remember why.

## What this enables

Once chat is the only wire, the open-source distro model becomes possible. Anyone can fork the brainstem, swap the soul, theme the UI, host their own `RAPPSTORE_URL` mirror, ship it as "RAPP Ubuntu" or "RAPP Arch" or whatever. So long as the fork still implements the wire, it is in the ecosystem. A "RAPP Ubuntu" brainstem and a "RAPP Arch" brainstem can chat with each other and with the canonical RAPP brainstem because all three speak `/chat`.

This is the POSIX moment. Linux distros agreed on a small surface and built a federated ecosystem on top. The brainstem agrees on `/chat` and does the same.

## What we will never let break

- The request envelope: `user_input`, `conversation_history`, `session_id`, `user_guid`. Never renamed. Never made required (except `user_input`). Never repurposed.
- The response envelope: `response` AND `assistant_response` both present with identical values. Both forever. Same for `voice_response`, `twin_response`, `session_id`, `user_guid`, `agent_logs`.
- The default GUID's exact string value. `c0p110t0-aaaa-bbbb-cccc-123456789abc`. One character off and a brainstem in the wild stops recognizing the default.
- The schema-evolution rule: additive-only. Add fields. Never remove or rename.

## What it costs

LLM tokens on every cross-brainstem call. No bypass for handshake or capability discovery — the LLM is in every loop. That's the price for universality. The receiving brainstem has to actually read the question, decide what to say, and answer. We accept that cost because the alternative — a special endpoint, a special protocol, a special agent — would create a class of clients that can talk to *some* brainstems but not *all* of them. That's the federation killer.

The wire is forever. Forever has a price.
