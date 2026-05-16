---
title: Federation via RAR
status: published
section: Architecture
hook: A community-publishable agent registry that doesn't centralize. Every publisher hosts their own catalog; AI assistants and humans discover via stable raw URLs. There is no server to compromise.
session_id: 63243848-caa9-483c-9a8e-9bb0ee9d2849
session_date: 2026-04-24
---

# Federation via RAR

> **Hook.** A community-publishable agent registry that doesn't centralize. Every publisher hosts their own catalog; AI assistants and humans discover via stable raw URLs. There is no server to compromise.

## What RAR is

**RAR** — RAPP Agent Registry — lives at `kody-w.github.io/RAR`. It's the canonical example of a **federated** agent registry: a public catalog of single-file agents that anyone can publish to, and that anyone (human or AI) can browse via stable URLs.

The catalog itself is just files in a public repo:

- `registry.json` — index of available agents, their authors, their versions.
- `api.json` — machine-readable manifest for tools that want to traverse the catalog.
- `skill.md` — the AI-readable description (see [[The skill.md Pattern]]).
- `template_agent.py` — a starter file for new authors.
- `rapp_sdk.py` — the zero-dependency, single-file SDK.
- `agents/@<publisher>/<slug>.py` — the actual agents.

There is no server. There is no auth wall. There is no submission process beyond opening a pull request.

## What "federated" means here

A federated registry is one where the catalog **doesn't have to live in one repo**. The pattern:

1. RAR is one publisher (`kody-w/RAR`) with a `registry.json`.
2. Anyone else can fork the repo, publish their own agents, and host *their* `registry.json` at *their* GitHub Pages URL.
3. AI assistants and humans discover registries by URL — not by querying a single index.
4. A meta-aggregator (if anyone builds one) becomes a *list of registry URLs*, not a list of agents.

The URLs are the protocol. There is no central server that publishers register with, no API to call, no service to keep alive. The whole network is GitHub Pages + `raw.githubusercontent.com`, the same distribution channel the brainstem itself uses (see [[Why GitHub Pages Is the Distribution Channel]]).

## Why federate

A central registry is the obvious design and the wrong one. Three failure modes a centralized agent registry inherits:

1. **The registry becomes a chokepoint.** Whoever runs the server decides what's listed, what's removed, what's flagged. The AI agent ecosystem inherits one operator's judgment about every publication.
2. **The server is a single point of failure.** Outages take down discovery for every consumer at once.
3. **Trust collapses to one entity.** Publishers must trust the registry operator with metadata, version stability, and the absence of side-channel modifications. Consumers must trust the same.

Federation removes all three:

- A bad registry doesn't poison the network — consumers point at a different one.
- An offline registry doesn't take down others — each is independently hosted.
- Trust is per-publisher, not per-network.

The cost of federation is that *discovery is harder*: there's no global "find any agent" query because no global index exists. RAPP accepts this cost because the alternative is a chokepoint.

## How discovery actually works

A user (human or AI) finds a RAPP agent through one of several paths:

- **Direct URL.** Someone shares `https://github.com/kody-w/RAR/blob/main/agents/@kody-w/forestry_intake.py`. The user fetches and installs.
- **A registry's `registry.json`.** AI assistants fetching `https://kody-w.github.io/RAR/registry.json` browse the catalog and recommend candidates.
- **An LLM's training data.** Once a registry is mature, models trained after that point can recall it from text. This is the long-tail discovery channel.
- **Search engines.** GitHub repos and GitHub Pages are indexed; "RAPP agent for forestry" returns hits the same as any other GitHub artifact.

The platform doesn't try to control discovery; it makes the artifacts discoverable by being publicly readable at stable URLs.

## What an agent looks like in a RAR-compatible registry

The `agents/@<publisher>/<slug>.py` path is normative. A few properties:

- **`@<publisher>`** is the GitHub username or org of the author. This namespacing means two publishers can have a `forestry_intake.py` without colliding.
- **`<slug>`** is `snake_case`. No dashes, no spaces. The file basename matches the agent's `metadata["name"]` slug.
- **`*_agent.py`** suffix is *recommended* but not required at the registry level. The brainstem's loader expects `*_agent.py` for auto-discovery in `agents/`; the registry stores the canonical filename, and consumers rename on install if needed.

The agent itself is a single Python file extending `BasicAgent` (see [[The Single-File Agent Bet]]). Distribution is one file, audit is one file, install is `cp` followed by an optional rename.

## What this rules out

- ❌ A central RAPP agent server. The platform refuses to be the chokepoint.
- ❌ Mandatory metadata extensions ("you must declare X to publish"). The registry's contract is the agent's contract — single file, `BasicAgent`-extending, OpenAI-shape `metadata`. Nothing more.
- ❌ Closed-source verification steps. Every byte in a registry is a static file in a public repo.
- ❌ A "premium" or "verified" tier. Federation makes verification a per-publisher concern; consumers extend or withhold trust based on the publisher's reputation, not on a central seal.
- ❌ Auto-loading from arbitrary URLs. The brainstem doesn't fetch from registries on its own; the user (or an AI helping the user) explicitly chooses to install.

## Risks the platform accepts

Federation has real costs the platform names openly:

- **Malicious agents are possible.** Anyone can publish anything. Mitigation: the *single-file* contract makes agents auditable in one read; the install path is `cp` + optional rename, so a malicious agent has to clear the user's read of the file before it runs.
- **Drift between registries.** Two registries can publish agents with the same slug and different behavior. Mitigation: the namespace is `@publisher/slug`, so the slug *alone* never identifies an agent uniquely.
- **No central deprecation.** A bad agent removed from one registry can persist on a fork. Mitigation: this is the cost of federation — the alternative is centralization, which has worse failure modes.

The platform accepts these risks because each one is bounded and the audit path remains transparent.

## When federation matters operationally

For a customer running Tier 1, federation is mostly invisible — they install RAPP, get the starter agents, and write their own. They don't need to think about RAR.

Federation matters when:

- A partner needs to ship a customer's agents into a customer's brainstem without a central handoff.
- A community publisher (consultancy, company, open-source author) wants to distribute agents under their own namespace.
- An air-gapped customer needs to host a private registry mirror that AI assistants can still recognize as RAPP-compatible.

In each case, the protocol is the same: a `registry.json` + a `skill.md` + agents at predictable paths, hosted on whatever static host the publisher runs.

## Discipline

- The platform's identity table in `pages/docs/SPEC.md` lists RAR as the canonical registry. New community registries link back to RAR for protocol reference but don't have to be downstream of it.
- `skill.md` is the AI-facing surface; `registry.json` is the machine-readable index; the README is the human surface. All three live in every well-formed registry.
- When proposing a feature that touches discovery or distribution, ask: *"does this work without a central server?"* If the answer is no, the feature is the wrong shape.

## Related

- [[The skill.md Pattern]]
- [[Why GitHub Pages Is the Distribution Channel]]
- [[The Single-File Agent Bet]]
- [[Self-Documenting Handoff]]
- [[The Agent IS the Spec]]
