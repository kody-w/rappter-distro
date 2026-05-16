---
title: Why GitHub Pages Is the Distribution Channel
status: published
section: Positioning
hook: The install one-liner is the deployment story. GitHub is the CDN. raw.githubusercontent.com is the implicit contract.
---

# Why GitHub Pages Is the Distribution Channel

> **Hook.** The install one-liner is the deployment story. GitHub is the CDN. `raw.githubusercontent.com` is the implicit contract.

## The contract

RAPP's published install path is a single command:

```bash
curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash
```

Behind that URL is the same `install.sh` checked into the repo at the root, served verbatim by GitHub Pages. The script then references additional files (the brainstem, agents, soul prompt, web UI) by their `raw.githubusercontent.com` URLs at the same commit-pinnable path.

This is the entire distribution story. There is no package registry, no installer binary, no proprietary CDN, no release server, no OS-specific packaging. Constitution Article V calls this *sacred*: the install one-liner does not change in shape.

## Why GitHub Pages, not a package manager

The platform considered and rejected three obvious alternatives:

**1 — pip / PyPI.** A `pip install rapp-brainstem` would be the conventional choice. Rejected because:
- pip requires Python being installed already; the install one-liner can install Python on its own first if needed.
- PyPI versions are immutable, but the publish process is not transparent. With GitHub Pages, the deploy IS the commit; reviewers see the change before it ships.
- pip distributions tempt teams to break the single-file rule (a package can have submodules, sibling imports, etc.). The single-file rule is enforced by the *fetch* mechanism — agents are downloaded as one file each, not as a package.

**2 — npm / a custom JS-based installer.** Rejected for the same reasons as pip, plus the brainstem is Python; an npm-fronted installer is a mismatch of stacks.

**3 — A dedicated CDN (Cloudflare Workers, AWS, Azure CDN).** Rejected because the platform doesn't want to be in the CDN business. GitHub Pages costs nothing, scales infinitely, has uptime measured in years, and the deployment process is `git push`. A custom CDN would be a permanent maintenance burden in exchange for marginal speed gains.

GitHub Pages wins because it's *the same surface as the source*. The user reading the install URL can read the script that runs. The script references files in the same repo. Auditing the install path is a single git clone away.

## Why `raw.githubusercontent.com`

The `raw.` URL pattern is load-bearing for two reasons most users never notice:

- **Pinned versioning by tag.** `https://raw.githubusercontent.com/kody-w/RAPP/brainstem-v0.12.1/rapp_brainstem/brainstem.py` returns the file *at that exact tag*. The install script can pin to a known-good version with one URL change. Compare to a package registry where the version is a separate concept from the URL.
- **Independent of GitHub Pages routing.** GitHub Pages can redirect, route, change Jekyll configs. `raw.` is just "give me this file." The install path is robust to GitHub Pages reconfiguration in a way it wouldn't be if everything went through `<user>.github.io/<repo>/<path>`.

The platform's install URL uses `<user>.github.io` for the *entry point* (because that's the canonical GitHub Pages URL and has nice properties for sharing / bookmarking). Once the install script is running, it switches to `raw.githubusercontent.com` for everything else.

## What this trades

The trade is uptime and routing for cost and simplicity:

- **Uptime.** GitHub's uptime is measured in years, but it isn't 100%. When GitHub is down, RAPP installs are down. A dedicated CDN with multi-region failover would not have this property. The platform accepts the dependency.
- **Routing.** GitHub Pages doesn't support custom edge logic. There's no A/B testing the install script, no geo-routing, no custom error pages beyond what Jekyll allows. Acceptable, given the alternative.
- **Brand.** The install URL contains `kody-w.github.io` rather than a custom domain. Custom domains via GitHub Pages are supported but introduce DNS+TLS configuration. The platform's choice is to keep the URL boring and the deployment simple.

## What this enables

The constraints are also enablers:

- **Forking the platform is forking the install URL.** A fork at `someone-else.github.io/RAPP/install.sh` is fully self-contained — same script, same paths, no central registry coordinating versions. This is critical for offline/air-gapped customers who must mirror the install internally; they fork to a self-hosted git, point GitHub Pages (or any static host) at it, and the URL substitution is the only change.
- **`skill.md` as a fetch target.** Constitution Article XVII (`agents/` IS the user's workspace) and the rapp store discipline both rely on agents being fetchable as `https://raw.githubusercontent.com/<owner>/<repo>/<branch>/agents/<file>` URLs. The pattern generalizes to community publishers — anyone with a GitHub repo can publish RAPP-compatible content with no central coordination. See `pages/docs/skill.md`.
- **Audit-friendly.** A customer auditing the install path runs `curl https://kody-w.github.io/RAPP/installer/install.sh | less`. Every file fetched is a file in the repo. There is no opaque binary, no signed installer, no closed-source layer.

## What this rules out

- ❌ A registry server in front of GitHub. The install path stays static-file.
- ❌ Per-user install scripts (download is the same for everyone; per-user config happens after install).
- ❌ Closed-source steps in the install path. Every byte that runs as part of installation is in the repo.
- ❌ Auto-updating installers that fetch new versions silently. The user re-runs the one-liner when they want to update; the URL is the version.
- ❌ Replacing GitHub Pages with a "real" hosting tier "for serious deployments." Tier 2 deployment is a different story (Azure Functions); the *install path* stays GitHub Pages.

## When to reconsider

The model would change if any of these became true:

- GitHub revoked Pages or `raw.` access for the repo. (The platform would mirror to a static host, but the URL would change.)
- A customer segment emerges that fundamentally cannot use public GitHub. (Today, those customers fork to a private git and self-host — the platform's design supports this.)
- A new install path becomes load-bearing — for example, an `obsidian://` URI handler that fetches and installs. (That would *augment* the one-liner, not replace it.)

## Discipline

- The install one-liner doesn't change shape. Variants (`--here`, `RAPP_INSTALL_ASSIST=1`, etc.) are flags, not new entry points.
- New install assets are added to the repo at paths the one-liner already knows about, not to a separate distribution.
- When tempted to "just put this on a CDN for speed," remember the audit story.

## Related

- [[The Auth Cascade]]
- [[Roots Are Public Surfaces]]
- [[RAPP vs Copilot Studio]]
- [[Three Tiers, One Model]]
- [[Engine, Not Experience]]
