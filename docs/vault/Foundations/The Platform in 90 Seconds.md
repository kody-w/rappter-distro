---
title: The Platform in 90 Seconds
status: published
section: Foundations
hook: The elevator pitch. Read aloud in 90 seconds. If this doesn't land, no other note will.
---

# The Platform in 90 Seconds

> **Hook.** The elevator pitch. Read aloud in 90 seconds. If this doesn't land, no other note will.

## What RAPP is

RAPP — *Rapid Agent Prototyping Platform* — is a three-tier engine for building, validating, and shipping AI agents inside Microsoft-flavored environments. The platform's job is to make a real working agent in **one hour**, in front of the customer who will use it, and ship that same agent into production without rewriting a line.

## What's distinctive

Three properties, each load-bearing:

1. **Single-file agents.** A RAPP agent is one Python file. One class extending `BasicAgent`, one metadata dict (an OpenAI function-calling schema), one `perform()` method. No build step. No sibling imports. The file the customer touches in the workshop is the file that ships in production. See [[The Single-File Agent Bet]].

2. **Three tiers, one model.** The same agent file runs unmodified in Tier 1 (a local Flask server for development), Tier 2 (Azure Functions for hosted deployment), and Tier 3 (a Power Platform solution that publishes into Microsoft Copilot Studio). Diff the bytes — they match. See [[Three Tiers, One Model]].

3. **Engine, not experience.** The platform ships infrastructure, not opinions. There is no workflow editor, no template gallery, no graph DAG. Pipelines emerge through agent composition; UX emerges through twin calibration. The platform's value is in what it *doesn't* impose. See [[Engine, Not Experience]].

## The 60-minute promise

A RAPP workshop produces a working agent — a real `*_agent.py` file the customer has touched, validated, and watched run on their own input — in 60 minutes:

- 10 minutes describing the goal in the customer's own words.
- 40 minutes watching the agent emerge in front of them, with their corrections shaping the file.
- 10 minutes validating against real input the customer brought.

The artifact at minute 60 is the agent file. It leaves with the customer. It's what they bought. See [[60 Minutes to a Working Agent]].

## How it relates to Microsoft

RAPP is *upstream* of Microsoft Copilot Studio, not competing with it. Tier 1 collapses discovery; Tier 3 hands off into Copilot Studio. The relationship is sequential, not versus. See [[RAPP vs Copilot Studio]].

## What it doesn't do

The platform makes deliberate non-promises:

- It is not a workflow editor.
- It is not a vector database / RAG framework.
- It is not a tenant-native distribution channel (Tier 3 hands that to Copilot Studio).
- It is not a general-purpose multi-agent framework like LangChain or AutoGen.

If you need any of those primarily, RAPP is the wrong tool. See [[What You Give Up With RAPP]].

## What it ships as

- **Tier 1:** clone the repo, run `./start.sh` in `rapp_brainstem/`. Flask server on `:7071`.
- **Install one-liner:** `curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash`.
- **Tier 2:** `bash rapp_swarm/build.sh && cd rapp_swarm && func start`. Azure Functions.
- **Tier 3:** import the published Power Platform solution into a customer's environment.

The distribution channel is GitHub Pages and `raw.githubusercontent.com`. No package registry. No CDN. See [[Why GitHub Pages Is the Distribution Channel]].

## Where to read next

- [[The Sacred Constraints]] — the four inviolable rules the platform is built on.
- [[The Engine Stays Small]] — the conservation law underneath every other decision.
- [[The Agent IS the Spec]] — what makes the workshop deliverable a real spec.
- [[Constitution Reading Order]] — for the deep reader.

## Related

- [[How to Read This Vault]]
- [[The Sacred Constraints]]
- [[Three Tiers, One Model]]
- [[Engine, Not Experience]]
