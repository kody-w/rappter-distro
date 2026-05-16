# rappter-distro

> The full-bodied **Rappter distro** for the RAPP grail kernel.

The RAPP kernel (`brainstem.py`, in [`kody-w/rapp-installer`](https://github.com/kody-w/rapp-installer), mirrored at [`kody-w/RAPP`](https://github.com/kody-w/RAPP)) is the load-bearing foundation — a Linux-kernel-style BIOS for digital organisms. It is small and stable.

**This repo is a distro on top of that kernel.** It hatches a full Rappter organism onto a vanilla brainstem install: agents for memory + swarm management + agent generation, organs for estate/lineage/neighborhood/lifecycle, senses for voice + twin, a rich UI, the lineage/bonding/egg cartridge library, Tier 2 + Tier 3 deployments, and the Rappter narrative docs.

Like Ubuntu on top of Linux — the kernel doesn't care which distro is on top, and you don't need a distro at all if you just want a bare kernel.

## Install

After installing the grail kernel:

```bash
# 1. Install grail kernel
curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash

# 2. Hatch the Rappter distro on top
curl -fsSL https://raw.githubusercontent.com/kody-w/rappter-distro/main/install.sh | bash
```

Or in one shot:

```bash
curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash -s -- --rappter
```

## What this distro adds

| Layer | Adds |
|---|---|
| Agents | `swarm_factory`, `learn_new`, `upgrade` (`agents/@rappter/`) |
| Lib | `bond`, `egg`, `lineage`, `rappid`, `frames`, `peer_registry`, `twin`, `llm`, `workspace`, `index_card`, `boot` launcher (`lib/`) |
| Organs | estate, lifecycle, neighborhood, neighborhood-membership, swarm-estate (`organs/`) — `/api/<organ>/*` routes |
| Senses | voice, twin (`senses/`) — `|||VOICE|||` / `|||TWIN|||` channels |
| UI | rich `index.html`, web assets, PWA manifest, `tls_proxy.py` HTTPS wrapper (`ui/`) |
| Tier 2 | Azure Functions swarm (`tier2/`) |
| Tier 3 | Cloudflare Worker + Copilot Studio bundle (`tier3/`) |
| Tools | ecosystem audit, graph, rebuild estate, etc. (`tools/`) |
| Examples | `rapp-commons` neighborhood (`examples/`) |
| Docs | ECOSYSTEM, HERO_USECASE, ANTIPATTERNS, NEIGHBORHOOD_PROTOCOL, OSI, vault prose (`docs/`) |

## Kernel compatibility

Tracks grail at the version pinned in `distro.json`. The drift-check one-liner from the [Mirror Spec](https://github.com/kody-w/RAPP/blob/main/pages/vault/Architecture/Mirror%20Spec.md) still applies — the distro never modifies the kernel's three sacred files (`brainstem.py`, `VERSION`, `basic_agent.py`).

See [`MIGRATION_NOTES.md`](./MIGRATION_NOTES.md) for what regressed vs. the prior monorepo, and how each Rappter-specific feature now layers onto the kernel.

## Other distros

This is one distro. The point of the kernel/distro split is that other distros can exist for different use cases — minimal/research/enterprise/etc. — without forking the kernel.
