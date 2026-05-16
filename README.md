# rappter-distro

> The **Rappter distro** — organism layer on top of the RAPP grail kernel.

> **Why hatch the distro?** The kernel already runs agents. The distro lets agents *have an identity, find each other, and persist their lineage* — twins, neighborhoods, bonds, eggs, the rich UI. Useful when one brainstem isn't enough and your organism needs to live among others. If you just want to run agents locally, the bare kernel is plenty.
>
> *Looking for the canonical reading order of the whole platform?* Start at the [**Kernel hub**](https://kody-w.github.io/RAPP/pages/kernel.html) in the mirror repo — trilogy, law, specs, vault Reading Paths in one rendered page.

The RAPP kernel ([`kody-w/rapp-installer`](https://github.com/kody-w/rapp-installer), mirrored at [`kody-w/RAPP`](https://github.com/kody-w/RAPP)) ships the full three-tier Stack: Brainstem (Tier 1), Swarm/Azure Functions (Tier 2), Copilot Studio (Tier 3). That stack is the kernel's identity — nothing in this distro displaces it.

What this distro adds is the **organism layer** that grew on top of the kernel after the three tiers stabilized: organs (HTTP route extensions under `/api/<name>/*`), senses (response channels like `|||VOICE|||` and `|||TWIN|||`), lineage / bonding / egg-cartridge lib, the rich web UI, the Rappter narrative docs (ECOSYSTEM, HERO_USECASE, ANTIPATTERNS, NEIGHBORHOOD_PROTOCOL, OSI, vault prose), the post-kernel agents (swarm_factory, learn_new, upgrade), and the Rappter-specific ops tooling.

Like a Linux desktop environment on top of a kernel that already does plenty on its own — opt-in.

## Install

After installing the kernel (which already gives you Brainstem + Swarm + Copilot Studio):

```bash
# 1. Kernel (includes T1/T2/T3 narrative + deploy artifacts)
curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash

# 2. Hatch the Rappter organism layer
curl -fsSL https://raw.githubusercontent.com/kody-w/rappter-distro/main/install.sh | bash
```

## What this distro adds (on top of the kernel)

| Layer | Adds |
|---|---|
| Agents | `swarm_factory`, `learn_new`, `upgrade` (`agents/@rappter/`) — beyond grail's bundled set |
| Lib | `bond`, `egg`, `lineage`, `rappid`, `frames`, `peer_registry`, `twin`, `llm`, `workspace`, `index_card`, `boot` launcher (`lib/`) |
| Organs | estate, lifecycle, neighborhood, neighborhood-membership, swarm-estate (`organs/`) — `/api/<organ>/*` routes |
| Senses | voice, twin (`senses/`) — `|||VOICE|||` / `|||TWIN|||` channels |
| UI | rich `index.html` (223 KB), web assets, PWA manifest, `tls_proxy.py` HTTPS wrapper (`ui/`) |
| Tools | ecosystem_audit, ecosystem_graph, rebuild_estate, sign_release, etc. (`tools/`) |
| Examples | `rapp-commons` neighborhood (`examples/`) |
| Docs | ECOSYSTEM, HERO_USECASE, ANTIPATTERNS, NEIGHBORHOOD_PROTOCOL, OSI, ECOSYSTEM_MAP, MASTER_PLAN, COMMERCIAL, SURVIVAL, TRADEMARK, DEFINITION_OF_DONE, LEXICON, TEMPLATE + Obsidian vault (`docs/`) |

## What this distro does NOT add (because the kernel already has it)

- Tier 1 Brainstem (`rapp_brainstem/`) — grail kernel
- Tier 2 Swarm — grail's `azuredeploy.json` + `deploy.sh` + RAPP's `rapp_swarm/` Python impl
- Tier 3 Copilot Studio — grail's `MSFTAIBASMultiAgentCopilot_*.zip` Power Platform solution
- Cloudflare Worker auth bridge — `worker/` in RAPP
- `community_rapp/` — grail's community-side install surface

## Kernel compatibility

Tracks grail at the version pinned in `distro.json`. The Mirror Spec drift-check one-liner against grail's three sacred files still applies — the distro never modifies them.

See [`MIGRATION_NOTES.md`](./MIGRATION_NOTES.md) for the full extraction history.

## Other distros

The kernel's three-tier story doesn't need this distro to function. Other distros can layer different organism shapes on the same kernel without forking it. The contract for a valid distro: never modify the three sacred kernel files.
