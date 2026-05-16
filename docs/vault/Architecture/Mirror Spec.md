---
title: Mirror Spec
status: published
section: Architecture
hook: The frozen-kernel pattern. Anyone can mirror RAPP, but every mirror's installer must re-fetch the grail's installer at runtime and every mirror's kernel files must be byte-identical to grail v0.6.0. Drift is forbidden, and the check is one shell command.
---

# Mirror Spec

> **Hook.** The frozen-kernel pattern. Anyone can mirror RAPP, but every mirror's installer must re-fetch the grail's installer at runtime and every mirror's kernel files must be byte-identical to grail v0.6.0. Drift is forbidden, and the check is one shell command.

## Why this exists

The brainstem is a static kernel — a game-console BIOS, not an application. v0.6.0 in `kody-w/rapp-installer` (the *grail*) is the immutable version. It is never updated again. Everything new ships as agents, not as kernel changes.

This sounds restrictive until you ask the question that forced it: *what happens when two brainstems on different devices, or one brainstem found years later in a hostile network, need to interop?* If every brainstem is on a different version, agents can't bootstrap reliably across them. The only universal compatibility guarantee is a kernel that does not change.

Once the kernel is frozen, distribution becomes the next risk. A frozen kernel that gets re-downloaded from a maintainer's working tree is only as frozen as that working tree's discipline. This note specifies what a *valid mirror* looks like, so the freeze survives copying.

## The decision: brainstem is frozen at v0.6.0 grail

The brainstem stops here. v0.6.0 of `rapp_brainstem/brainstem.py` in the grail repo is the canonical kernel. Treat it like a console's BIOS:

- One BIOS, forever. Future generations of agents target the same surface.
- Agents bring their own everything: deps (auto-installed at import), UI (services), storage (the local-storage shim), even crypto and identity.
- A probe-class device can ship with this kernel and still run agents written years later by people who never met its builders. That is the design target.

The drift this prevents is real. Before this spec, a working copy of the kernel had accumulated roughly +1000 lines of post-v0.6.0 accretion — features that should have been agents. The mirror reset captures the moment "the engine stays small" became *enforced*, not aspirational. See [[The Engine Stays Small]] for the manifesto, [[The Single-File Agent Bet]] for the extension model, and [[The Brainstem Tax]] for what the kernel intentionally refuses to do.

## What the mirror pattern is

A mirror has two cooperating halves, and both must be present.

**1. The installer is a sync wire, not an installer.**

`installer/install.sh` is a thin shell wrapper that, on every run, `curl`s the grail's installer from `https://raw.githubusercontent.com/kody-w/rapp-installer/main/install.sh` and pipes it to `bash`. The mirror's installer cannot drift, because it does not *contain* the install logic — it only fetches it. The grail is the source of truth at install time. The wrapper is a few lines:

```bash
#!/bin/bash
set -e
GRAIL_INSTALLER_URL="https://raw.githubusercontent.com/kody-w/rapp-installer/main/install.sh"
curl -fsSL "$GRAIL_INSTALLER_URL" | bash -s -- "$@"
```

**2. The kernel files are a failover copy.**

`rapp_brainstem/brainstem.py`, `rapp_brainstem/VERSION`, and `rapp_brainstem/agents/basic_agent.py` in the mirror are byte-identical to grail v0.6.0. If the raw GitHub URL is unreachable — temporarily down, blocked by a network policy, or permanently gone in some far future — the mirror has a working offline copy. Clone the repo, `python3 rapp_brainstem/brainstem.py`, and you have the canonical brainstem. No network round-trip.

These two halves give "many birds, one stone": sync at install time, mirror for failover, comparison copy for verifying claims about the kernel, and a clean place to iterate on agents/UI/services without touching the grail.

## What makes a mirror *valid*

A mirror is a copy of RAPP that respects the kernel-binding contract. The minimum surface:

| File | Constraint |
|------|------------|
| `installer/install.sh` | Re-fetches grail's `install.sh` from the raw GitHub URL on every run. No other install logic permitted. |
| `rapp_brainstem/brainstem.py` | Byte-identical to grail's `brainstem.py` for the version the mirror tracks. |
| `rapp_brainstem/VERSION` | Matches grail's `VERSION` for the version the mirror tracks. |
| `rapp_brainstem/agents/basic_agent.py` | Byte-identical to grail's. |

What a mirror is **free** to change:

- Other agents in `agents/` — bring whatever agents you want.
- `soul.md` — your own system prompt.
- `index.html` and other UI surfaces — your own front-end.
- `pages/`, `worker/`, services, swarm packaging — your own application atop the platform.
- README, docs, branding.

The line is: *the kernel matches grail, the application is yours.* If you change the kernel, you are not a mirror — you are a fork. Forks are allowed (it is open source), but they break the offline-interop guarantee, so they cannot call themselves RAPP-compatible.

## Why anyone can mirror

The pattern is intentionally cheap to replicate. Any fork, clone, or fresh repo can become a valid mirror by:

1. Dropping in the same `installer/install.sh` wrapper (re-fetch grail).
2. Copying the four kernel files at the version the mirror is tracking.
3. Building whatever is wanted on top.

This makes the network of mirrors arbitrarily large without needing a central registry. Mirrors do not need permission. Their alignment is verifiable in one command:

```bash
diff <(curl -fsSL https://raw.githubusercontent.com/kody-w/rapp-installer/main/rapp_brainstem/brainstem.py) rapp_brainstem/brainstem.py
```

Empty output = compliant. Anything else = the mirror has drifted and is no longer a mirror.

If grail itself ever needs to relocate (new owner, new host), the wrapper's `GRAIL_INSTALLER_URL` is a one-line change; the kernel itself is unchanged. Mirrors that re-publish the new wrapper pick up the move automatically.

## Why this isn't vendoring

[[Vendoring, Not Symlinking]] discusses Tier 2 vendoring — copying brainstem core into `rapp_swarm/_vendored/` so the cloud deployment runs without reaching back. The mirror pattern is different in intent:

- Vendoring is *local self-sufficiency at deploy time* — Tier 2 must run without depending on brainstem's source tree.
- Mirroring is *distribution synchronization at install time* — RAPP's installer must always re-fetch grail to prove it has not drifted.

Both serve "no surprises across tiers/installs," but the mechanisms point in opposite directions. A mirror's installer reaches *out* to the grail; a vendored deployment intentionally does not reach anywhere.

## Why this isn't a cathedral

Letting any party become a valid mirror, with no gate other than a `diff`, is intentional. The pattern is closer to [[Federation via RAR]] than to a controlled-distribution release process. There is no allowlist of mirrors, no approval workflow, no badge.

What there *is* is a public, verifiable correctness check. A mirror that drifts is not invalid by edict — it is invalid because its `brainstem.py` is no longer byte-identical to grail's, and that means agents written for the platform can no longer assume offline interop. The penalty is structural, not procedural.

This is consistent with the platform's [[Engine, Not Experience]] stance: the maintainers do not police the network of mirrors, but the network of mirrors polices itself by virtue of the contract being checkable.

## Drift detection: the one-liner

Anyone — a user, a CI job, an auditor — can check a mirror with:

```bash
for f in rapp_brainstem/brainstem.py rapp_brainstem/VERSION rapp_brainstem/agents/basic_agent.py; do
  diff <(curl -fsSL "https://raw.githubusercontent.com/kody-w/rapp-installer/main/$f") "$f" \
    || echo "DRIFT: $f"
done
```

Three empty diffs = compliant. Any "DRIFT:" line = the mirror has changed a kernel file and is no longer a mirror.

Adding this as a CI check on a mirror repo is recommended but not required. The constraint is structural, not procedural: a drifted kernel breaks offline interop, and breaking offline interop breaks the platform's central promise.

## What this enables next

A frozen kernel + a verifiable mirror network is the substrate for things the kernel itself does not provide:

- **Probe-class deployment.** A device shipped today, found in a decade, runs the same agents without phoning home for an update.
- **Cross-mirror agent portability.** An agent published into one mirror's `agents/` runs identically in another mirror's `agents/`, because the surface they target is the same byte-for-byte kernel.

None of this is implementable on a moving kernel. All of it falls out for free on a frozen one.

## See also

- [[The Engine Stays Small]] — the manifesto this spec enforces.
- [[The Single-File Agent Bet]] — agents are how the platform extends.
- [[Engine, Not Experience]] — the founding stance the spec is loyal to.
- [[The Brainstem Tax]] — what the kernel deliberately does not do.
- [[Vendoring, Not Symlinking]] — adjacent pattern for Tier 2 self-sufficiency.
- [[Federation via RAR]] — how trust composes across mirrors.
- [[The Sacred Constraints]] — Constraint #4 ("Brainstem stays light") is the one this spec operationalizes.
