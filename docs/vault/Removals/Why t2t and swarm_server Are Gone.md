---
title: Why t2t and swarm_server Are Gone
status: published
section: Removals
hook: 2,073 lines deleted across two files. Anything that wanted its own process, port, or routing layer was leaving the brainstem's contract by definition.
---

# Why t2t and swarm_server Are Gone

> **Hook.** 2,073 lines deleted across two files. Anything that wanted its own process, port, or routing layer was leaving the brainstem's contract by definition.

## What was removed

In the same fast-forward pull that consolidated the memory agents, two large brainstem-adjacent files were removed:

- `rapp_brainstem/swarm_server.py` (1,736 lines) — a separate server process that managed swarm sessions, exposed its own routes, and ran alongside the main brainstem.
- `rapp_brainstem/t2t.py` (337 lines) — a "twin-to-twin" module that brokered communication between two users' twin instances.

Both files have no replacements at the brainstem level. Whatever capability they offered now lives inside the existing `/chat` flow, behind agents that talk to each other through the LLM and through `data_slush` (see [[Data Sloshing]]).

## What `swarm_server.py` was trying to be

The intent was reasonable: a "swarm" is a set of agents collaborating on a goal, and the original belief was that a swarm needed its own session lifecycle, its own port, its own route surface. So the file grew:

- Endpoints for creating, listing, joining, dissolving swarms.
- A session manager that tracked which agents belonged to which swarm.
- Inter-process communication between the main brainstem and the swarm server.
- Custom auth headers for swarm-scoped operations.

By the time it was 1,700 lines, the swarm server had grown most of a second platform inside a "support module."

## What `t2t.py` was trying to be

`t2t.py` was the cross-user twin protocol. The story was: if user A's brainstem can describe user A's preferences, and user B's brainstem can describe user B's, then a "twin-to-twin" handshake could pre-negotiate context before two humans interacted. It wanted to be a transport.

In practice, every t2t feature could be expressed as: *one twin emits a TWIN-block tag; the other twin reads it on the next turn.* Twin-to-twin was a *vocabulary* inside the existing TWIN slot, not a new transport.

## The principle

> **Anything that wanted its own process, port, or routing layer was leaving the brainstem's contract — and that contract is what makes the platform portable.**

The brainstem's contract is one route, `/chat`, that takes user input and returns a response with up to two delimiter-separated slots. Tier 2 (Azure Functions) honors that contract; Tier 3 (Power Platform) honors that contract; Tier 1's web UI honors that contract.

A separate server process or a separate route surface forces every tier to either:

1. Replicate the new surface (Tier 2 and Tier 3 each grow another endpoint), or
2. Drop the feature in tiers that can't replicate it (and the portability claim collapses).

Neither was acceptable. The conclusion: the feature was either (a) the wrong shape, or (b) needed to fit inside `/chat`. In both cases, the giant module was wrong.

## Where the capability went

**Swarms.** A swarm is now a *directory* of agents inside a workspace (see Constitution Article XIV — *Swarms Are Directories, Not Routes*). The brainstem's existing agent discovery handles swarm membership; the LLM picks which agents in the swarm to call. No new routes, no swarm sessions, no IPC. The capability collapsed to "agents are files; swarms are folders."

**Twin-to-twin.** Cross-user twin signal lives in the existing TWIN slot. A twin tagging a `<probe>` or emitting a `<calibration>` is the same wire format whether the audience is the same user (most common) or another user (rare, expressed via the workspace's storage). One channel, one vocabulary.

## What this taught

Three durable lessons:

1. **The brainstem's contract is small for a reason.** Every "support" file that grows its own contract is on the path to being its own platform. The first sign is "this needs its own port" or "this needs its own route prefix."
2. **A long file is sometimes the wrong file.** `swarm_server.py` was not a single agent (which would have failed [[The Single-File Agent Bet]] reviewability test); it was a *proto-platform*. Big proto-platforms are harder to fix than big agents.
3. **Capabilities don't need transports if they fit inside a slot.** The TWIN slot's tag vocabulary covered everything `t2t.py` was trying to do, with no transport, no protocol negotiation, no second server.

## What this rules out

- ❌ Adding a separate server process to handle a "specialized" workload. The brainstem is the server.
- ❌ Reserving a route prefix (`/swarm/`, `/twin/`, `/admin/`) for a capability cluster. New capabilities are *agents called inside `/chat`*, not new route surfaces.
- ❌ A "support module" with its own auth headers, its own session lifecycle, its own database. If the capability needs those, it needs to be inside the brainstem's existing contract or it doesn't ship.
- ❌ Treating "long file" as an excuse to reach for transport-level abstractions. Long files are sometimes correct (one focused agent, one focused module). Transports are almost never correct outside the brainstem's existing route set.

## When to reconsider

The only situation that would justify a new top-level module of this size is a new tier — for example, an on-device tier that genuinely cannot use HTTP. Even there, the new module would inherit the brainstem's route contract, not invent its own.

## Discipline

- Before writing a "support" file, ask whether the capability is (a) an agent, (b) a tag inside an existing slot, or (c) a single-file HTTP service under the rapp store's service discipline.
- A growing file is a smell only if its *contract* is growing. A 1,000-line agent with a single narrow contract is fine; a 200-line file that owns its own port is not.
- "We need a new server" is the loudest possible signal to stop and ask why.

## Related

- [[Engine, Not Experience]]
- [[The Brainstem Tax]]
- [[The Single-File Agent Bet]]
- [[Voice and Twin Are Forever]]
- [[Three Tiers, One Model]]
