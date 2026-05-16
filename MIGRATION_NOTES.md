# Migration notes — rappter-distro extracted from kody-w/RAPP

Originally everything in this repo lived inside `kody-w/RAPP`'s monorepo. This repo is the relocation target for the **organism layer** that grew on top of the RAPP kernel after the three-tier Stack (Brainstem / Swarm / Copilot Studio) stabilized. The Stack itself is the kernel's identity and stays in RAPP.

## What moved out of RAPP into this distro

| RAPP path | rappter-distro path | Reason |
|---|---|---|
| `rapp_brainstem/agents/swarm_factory_agent.py` | `agents/@rappter/` | Post-kernel agent |
| `rapp_brainstem/agents/learn_new_agent.py` | `agents/@rappter/` | Post-kernel agent |
| `rapp_brainstem/utils/reserved_agents/upgrade_agent.py` | `agents/@rappter/` | Post-kernel agent |
| `rapp_brainstem/utils/{bond,boot,egg,frames,index_card,lineage,lineage_check,llm,peer_registry,rappid,twin,workspace}.py` | `lib/` | Organism library — not part of the kernel's three tiers |
| `rapp_brainstem/utils/organs/*.py` | `organs/` | HTTP route extensions added post-kernel |
| `rapp_brainstem/utils/senses/*.py` | `senses/` | Response channels (voice, twin) added post-kernel |
| `rapp_brainstem/index.html` (223 KB rich UI) | `ui/index.html` | Rich UI on top of grail's smaller bundled UI |
| `rapp_brainstem/utils/web/*` | `ui/web/` | Web assets added post-kernel |
| `rapp_brainstem/tls_proxy.py` | `ui/tls_proxy.py` | HTTPS wrapper added post-kernel |
| `tools/*` | `tools/` | Ops scripts (ecosystem_audit, graph, rebuild_estate, sign_release) |
| `examples/*` | `examples/` | Sample neighborhoods (rapp-commons) |
| `rapp_kernel/` | `rapp_kernel/` | Alternate versioned-archive scheme (not in grail) |
| Root narrative docs (ECOSYSTEM, HERO_USECASE, ANTIPATTERNS, NEIGHBORHOOD_PROTOCOL, OSI, ECOSYSTEM_MAP, MASTER_PLAN, COMMERCIAL, SURVIVAL, TRADEMARK, DEFINITION_OF_DONE, LEXICON, TEMPLATE) | `docs/` | Post-kernel Rappter narrative |
| `pages/vault/*` (Obsidian vault — Rappter narrative; also stays in RAPP per the mirror's pages prerogative) | `docs/vault/` | Long-form decision archive |
| `installer/{plant.sh,plant.html,plant_qr.html,seed.html,initialize-variant.sh,start-local.sh,test_plant.sh,integration_plant.sh,hatchling/,shortcuts/}` | `installer/` | Post-kernel install surfaces |
| `pitch-playbook.html` | `docs/` | Rappter pitch |
| `tests/*` | `tests/` | Rappter integration suite |

## What stays in RAPP (because the kernel ships it)

- `rapp_brainstem/{brainstem.py, VERSION, agents/basic_agent.py, ...}` — kernel files
- `rapp_swarm/` — Tier 2 Azure Functions Python implementation
- `worker/` — Tier 3 Cloudflare Worker auth bridge
- `installer/{install.sh,install.ps1,install.cmd,azuredeploy.json,install-swarm.sh,MSFTAIBASMultiAgentCopilot_*.zip}` — kernel installer + T2/T3 deploy artifacts
- `community_rapp/`, `docs/`, `blog.html`, `release-notes.html`, `skill.md`, `deploy.{sh,ps1}`, `install.command` — grail-canonical files
- `pages/` — Rappter audience site (mirror prerogative per Mirror Spec)
- `CONSTITUTION.md`, `pages/docs/SPEC.md`, `pages/vault/Architecture/Mirror Spec.md` — protocol DNA
- `rappid.json` — species root identity

## Kernel features the distro relies on (no kernel changes required)

1. **`sys.modules` shims** for the `utils` and `utils.azure_file_storage` namespaces — anything dropped into `~/.brainstem/utils/` imports transparently.
2. **Agent discovery** via `importlib.util.spec_from_file_location` over `agents/*_agent.py` — drop `agents/@rappter/*.py` and they load on next request.
3. **`boot.py` wrapper pattern** (in `lib/boot.py`) — monkey-patches `Flask.run` before runpy executes brainstem.py, then composes organs/senses onto the kernel's app without touching `brainstem.py`.

## How to verify the kernel is still a valid mirror after installing the distro

```bash
for f in rapp_brainstem/brainstem.py rapp_brainstem/VERSION rapp_brainstem/agents/basic_agent.py; do
  diff <(curl -fsSL "https://raw.githubusercontent.com/kody-w/rapp-installer/main/$f") "$HOME/.brainstem/$(basename $f)" \
    || echo "DRIFT: $f"
done
```

Three silent diffs = the distro layered on cleanly.
