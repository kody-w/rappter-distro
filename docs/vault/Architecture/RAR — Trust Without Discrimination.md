---
title: RAR — Trust Without Discrimination
status: published
section: Architecture
hook: How this repo interacts with the RAR registry (which lives in its own repo). Defines only the integration surface — manifest fields binder reads, the env var that points at the registry, the behavior on verify, and the inviolable principle that an agent meeting the v0 contract loads forever, signed or not.
---

# RAR — Trust Without Discrimination

> **Hook.** How this repo interacts with the RAR registry (which lives in its own repo). Defines only the integration surface — manifest fields binder reads, the env var that points at the registry, the behavior on verify, and the inviolable principle that an agent meeting the v0 contract loads forever, signed or not.

**RAR is its own repo with its own design, governance, and lifecycle.** Nothing about how RAR works internally — publisher onboarding, key generation, key rotation, registry structure — belongs in this repo. This note defines only the surface where this repo touches RAR: what fields we read from the manifest, where we look for verification material, and what binder does with the result.

## The integration surface

### 1. Manifest fields binder reads

Per-version manifests in `rapp_store/<pkg>/versions/<X.Y.Z>/manifest.json` may carry these optional fields. They are additive to the existing `rapp-version/1.0` schema (bumping to `1.1` when used):

```json
{
  "schema": "rapp-version/1.1",
  "id": "binder",
  "version": "1.0.0",
  "agent":   { "filename": "binder_agent.py",   "sha256": "...", "rar_sig": "<base64>" },
  "service": { "filename": "binder_service.py", "sha256": "...", "rar_sig": "<base64>" },
  "rar_publisher": "<publisher identifier per RAR's convention>",
  "rar_manifest_sig": "<base64>"
}
```

This repo's responsibility ends at "binder reads these fields if present." How `rar_sig` and `rar_manifest_sig` are computed, what `rar_publisher` strings look like, and how publishers are issued — all of that is RAR's repo to define.

### 2. Where binder fetches verification material

```
RAR_REGISTRY_URL  (env var, optional)
  default = whatever RAR's repo documents as the canonical registry URL
```

Same pattern as `RAPPSTORE_URL` — overridable so distros can point at their own RAR mirror. The exact URL shape RAR uses for keys, identities, and revocation is RAR's concern; this repo only knows the env var and that the result is consumable per RAR's published spec.

### 3. What binder does with the result

```
binder install <id>:
  1. Fetch catalog → get entry
  2. Download files → verify SHAs against per-version manifest (existing)
  3. If manifest has rar_publisher + rar_sig:
       a. Fetch verification material from RAR_REGISTRY_URL
       b. Verify per RAR's spec
       c. Record verification result in binder.json: {verified: true | false}
     Else:
       Record {verified: unsigned} in binder.json
  4. Install — always.
```

**Step 4 is non-negotiable.** Install always happens. Verification populates an audit field; it never gates execution.

## The non-negotiable: no discrimination

This is the part most likely to get "fixed" by a well-meaning contributor. Don't.

**An agent.py that meets the v0 contract loads. Forever. No exceptions.** That contract is small:

- Filename matches `*_agent.py`
- Contains a class extending `BasicAgent`
- Defines a `metadata` dict
- Defines a `perform(**kwargs) -> str` method

If those four conditions are met, the agent loads. RAR is *additional information about provenance*, not a precondition for execution.

Specifically:

- **No prompts. None.** Not "Install anyway?", not "This package is unverified, continue?", not anything. The user clicked install — that IS the consent. Asking again is friction theater. Signed and unsigned packages install identically and silently.
- **No "official"/"unofficial" badges that imply hierarchy.** A "verified" checkmark next to signed packages is fine; the absence of one is just absence, not a status flag.
- **No "hard mode" toggle that refuses unsigned agents.** There is no hard mode. There is no soft mode. There is just loading.
- **The brainstem's agent loader never gates on signature.** It only checks the v0 contract. RAR is binder's concern; the kernel doesn't know RAR exists.
- **Dev agents, WIP agents, hand-rolled agents, agents from a backup tape, agents written in a workshop ten years from now** — all welcome, all equal, all just code that meets the contract.

## Why no discrimination

Same doctrine as Article XXV ("chat is the only wire") applied to agents instead of the wire. The principle:

> **The user is the final authority on what runs on their machine. RAR provides verification metadata; it never blocks.**

A v0 brainstem from years ago still chats with current → a v0 agent from years ago still loads on current. The wire is forever; the agent contract is forever. RAR is information that helps consumers reason about provenance — it is not a permission gate.

## Threat coverage from binder's perspective

| Threat | Without RAR | With RAR |
|--------|-------------|----------|
| Single file tampered, catalog SHA still good | Catalog SHA catches | Catalog SHA + RAR sig both catch |
| Catalog AND file tampered by repo writer | **Not caught** — repo writer sets new SHA | RAR sig requires offline publisher key; repo writer can't forge |
| Locally-dropped agent in `agents/` | Loads | Loads (Article XVII — user's workspace) |
| Edge brainstem from before RAR existed | Loads agents fine | Loads agents fine (additive schema) |

## Time-travel safety

RAR fields are purely additive (Article XXV — additive-only schema evolution, no removals or renames). Old brainstems without RAR support ignore the new manifest fields and install as before. New brainstems verify when present and record provenance. Signed and unsigned packages coexist in the same catalog. Same wire, same contract, same loading discipline — RAR adds metadata to the install audit trail without changing anything that already works.

## What lives where

| Concern | Lives in |
|---------|----------|
| Manifest fields binder reads | This repo (rapp_store/) |
| Binder's verify-and-record behavior | This repo (rapp_store/binder/) |
| `RAPPSTORE_URL` and `RAR_REGISTRY_URL` env vars | This repo (brainstem.py + binder) |
| The no-discrimination principle | This repo (this vault note + binder behavior) |
| Publisher identities, key formats, registry structure | RAR's own repo |
| Key rotation, revocation, trust roots | RAR's own repo |
| How signatures are produced | RAR's own repo |
| Publisher onboarding workflow | RAR's own repo |

## What to build (when the next session implements binder verification)

Strictly the integration side:

1. **Add `RAR_REGISTRY_URL` env var** to brainstem and binder, default = whatever RAR's repo publishes as canonical
2. **Bump per-version manifest schema** from `rapp-version/1.0` to `rapp-version/1.1` to allow `rar_sig` / `rar_publisher` / `rar_manifest_sig` fields
3. **Teach binder to read those fields, fetch material from `RAR_REGISTRY_URL`, verify, and record result in `binder.json`** — install always succeeds; verification populates an audit field
4. **One acid test** (`tests/e2e/13-rar-supply-chain.sh`) — install a tampered file → binder records `verified: false` and **still installs**; install an unsigned package → binder records `verified: unsigned` and **still installs**; install a signed-and-untampered package → binder records `verified: true`

That's it. Everything else — keys, registry structure, publisher onboarding, signing tooling — happens in the RAR repo.

## What this is NOT

- **Not a license check.** RAR doesn't validate that you're allowed to use a package; it validates who shipped it.
- **Not DRM.** It doesn't prevent copying, modifying, or redistributing.
- **Not a permission system.** The user's workspace is sovereign.
- **Not a rating or review system.** Signatures are about provenance, not quality.

## Status

Integration surface defined. Binder implementation deferred. The principles in this note are inviolable; the implementation order is recommended but flexible. When in doubt: **we don't discriminate.**
