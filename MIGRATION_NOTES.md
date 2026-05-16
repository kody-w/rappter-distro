# Migration notes — rappter-distro extracted from kody-w/RAPP

Originally everything in this repo lived inside `kody-w/RAPP`'s monorepo. Per the [Mirror Spec](https://github.com/kody-w/RAPP/blob/main/pages/vault/Architecture/Mirror%20Spec.md), a *valid mirror* of the grail kernel keeps the three sacred kernel files byte-identical to grail and ships a thin re-fetcher installer. RAPP was already mirroring grail's `brainstem.py` / `VERSION` / `basic_agent.py` correctly, but had accumulated agents, organs, senses, lib, UI, deployment infra, and narrative docs around the kernel files. This repo is the relocation target for that accumulated material.

## What moved out of RAPP

| RAPP path | rappter-distro path |
|---|---|
| `rapp_brainstem/agents/swarm_factory_agent.py` | `agents/@rappter/` |
| `rapp_brainstem/agents/learn_new_agent.py` | `agents/@rappter/` |
| `rapp_brainstem/utils/reserved_agents/upgrade_agent.py` | `agents/@rappter/` |
| `rapp_brainstem/utils/{bond,boot,egg,frames,index_card,lineage,lineage_check,llm,peer_registry,rappid,twin,workspace}.py` | `lib/` |
| `rapp_brainstem/utils/organs/*.py` | `organs/` |
| `rapp_brainstem/utils/senses/*.py` | `senses/` |
| `rapp_brainstem/index.html` (223 KB rich UI) | `ui/index.html` (replaces grail's smaller index.html on distro install) |
| `rapp_brainstem/utils/web/*` | `ui/web/` |
| `rapp_brainstem/tls_proxy.py` | `ui/tls_proxy.py` |
| `rapp_swarm/*` | `tier2/` |
| `worker/*` + `installer/MSFTAIBASMultiAgentCopilot_*.zip` | `tier3/` |
| `tools/*` | `tools/` |
| `examples/*` | `examples/` |
| `rapp_kernel/` (alt versioned-archive scheme) | `rapp_kernel/` |
| Root narrative docs (ECOSYSTEM, HERO_USECASE, ANTIPATTERNS, NEIGHBORHOOD_PROTOCOL, OSI, ECOSYSTEM_MAP, MASTER_PLAN, COMMERCIAL, SURVIVAL, TRADEMARK, DEFINITION_OF_DONE, LEXICON, TEMPLATE) | `docs/` |
| `pages/vault/*` (Obsidian vault — Rappter narrative; also stays in RAPP per the mirror's pages prerogative) | `docs/vault/` |
| `installer/{plant.sh,plant.html,plant_qr.html,seed.html,azuredeploy.json,initialize-variant.sh,install-swarm.sh,start-local.sh,test_plant.sh,integration_plant.sh,hatchling/,shortcuts/}` | `installer/` |
| `pitch-playbook.html` | `docs/` |
| `tests/*` | `tests/` |

## What stays in RAPP (the mirror)

- `rapp_brainstem/brainstem.py` — grail kernel (byte-identical to `kody-w/rapp-installer` main)
- `rapp_brainstem/VERSION` — kernel version (matches grail main)
- `rapp_brainstem/agents/basic_agent.py` — agent ABI (byte-identical to grail)
- `rapp_brainstem/utils/local_storage.py` — storage shim at the kernel's expected location
- `rapp_brainstem/agents/{context_memory,manage_memory,hacker_news}_agent.py` — grail-bundled agents
- `rapp_brainstem/{requirements.txt, start.sh, start.ps1, soul.md, .env.example, .gitignore, index.html, README.md, CLAUDE.md, CONSTITUTION.md}`
- `installer/install.{sh,ps1,cmd}` — thin re-fetchers of the grail installer (with `--rappter` flag)
- `pages/` — Rappter audience-facing site (Mirror Spec lists pages/ as free-to-change)
- `CONSTITUTION.md`, `pages/docs/SPEC.md`, `pages/vault/Architecture/Mirror Spec.md` — protocol DNA
- `rappid.json` — species root identity for the entire RAPP family tree

## Kernel features the distro relies on (no kernel changes required)

The kernel ships with two extension hooks the distro uses, and neither requires modifying `brainstem.py`:

1. **`sys.modules` shims** for the `utils` and `utils.azure_file_storage` namespaces (auto-installed before agent discovery). Anything dropped into `~/.brainstem/utils/` imports transparently.
2. **Agent discovery** via `importlib.util.spec_from_file_location` over `agents/*_agent.py`. Drop `agents/@rappter/*.py` and they load on next request.

Plus the `boot.py` wrapper pattern (in `lib/boot.py`) monkey-patches `Flask.run` before runpy executes brainstem.py, then composes organs/senses onto the kernel's app — without touching `brainstem.py` at all. This is the load-bearing trick that makes the distro work.

## How to verify the kernel is still a valid mirror

After installing the distro:

```bash
for f in rapp_brainstem/brainstem.py rapp_brainstem/VERSION rapp_brainstem/agents/basic_agent.py; do
  diff <(curl -fsSL "https://raw.githubusercontent.com/kody-w/rapp-installer/main/$f") "$HOME/.brainstem/$(basename $f)" \
    || echo "DRIFT: $f"
done
```

Three silent diffs = the distro layered on cleanly without corrupting the kernel.
