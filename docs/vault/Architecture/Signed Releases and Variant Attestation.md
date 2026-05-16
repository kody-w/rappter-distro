---
title: Signed Releases and Variant Attestation
status: living
section: Architecture
hook: The data model for cryptographically anchored kernel releases and parent-attested variant lineage. Schema is shipped today; signing infrastructure is opt-in and rolls in as variants adopt it.
---

# Signed Releases and Variant Attestation

> **Hook.** The data model for cryptographically anchored kernel releases and parent-attested variant lineage. Schema is shipped today; signing infrastructure is opt-in and rolls in as variants adopt it.

## Why this exists

`rapp_kernel/v/<n>/checksums.txt` defends against on-disk corruption — if a downloaded file's bytes don't match the recorded sha256, you know something went wrong. It does **not** defend against:

1. **A malicious commit that updates both `brainstem.py` and `checksums.txt` in lockstep.** Anyone with push access (or who compromises one) can ship a backdoored kernel that passes every check we have today.
2. **A variant repo claiming any rappid as its parent.** The `parent_rappid` in `rappid.json` is just a string; nothing prevents a forked variant from forging its lineage.

These are the same problems the broader software supply-chain world has spent the last decade solving (Sigstore, signed git tags, minisign, npm provenance, etc.). RAPP's response is a small, opt-in schema: kernel releases get signed; variant masters carry an attestation from their parent. The data fields are in place today (with `null` values); each variant adopts signing on its own timeline.

## Schema (already shipped)

### `rapp_kernel/manifest.json`

```jsonc
{
  "schema": "rapp-kernel/1.1",
  "files": [...],
  "latest": "0.12.2",
  "signing": {
    "method": null,             // one of "gpg", "sigstore", "minisign", null
    "key_id": null,             // public-key fingerprint (40-hex for gpg, sigstore identity URI, etc.)
    "verification_uri": null    // human-readable URL describing how to verify
  },
  "versions": [
    {
      "version": "0.12.2",
      "path": "v/0.12.2",
      "released_at": "2026-04-28",
      "attestation": null       // future: URL of a sigstore bundle / detached sig file
    }
  ]
}
```

### `rappid.json` (root, master, or variant)

```jsonc
{
  "schema": "rapp-rappid/2.0",
  "rappid": "rappid:v2:<kind>:@<pub>/<slug>:<hash>@<host>",
  "parent_rappid": "<parent v2-format string or null>",
  "parent_repo": "https://...",
  "parent_commit": "<sha>",
  "attestation": null           // future: envelope signed by parent's release key
}
```

The schema field is what consumers check first; clients that understand `2.0` know how to interpret the v2-format string and the new fields. Pre-2026-04-30 seeds on `rapp-rappid/1.1` with bare-UUID rappids remain valid (Art. XXXIV.5 — never regenerate); their UUID hex is the hash field of an equivalent v2 string.

## What an attestation is

A variant's `attestation` (when present) is an envelope signed by the **parent's release key** that asserts:

```
issuer:        <parent rappid>
parent_repo:   https://github.com/kody-w/RAPP
parent_commit: <sha at fork time>
child_rappid:  <variant rappid>
issued_at:     <iso timestamp>
signature:     <bytes, format determined by manifest.signing.method>
```

The variant publishes this in its `rappid.json`. Anyone walking the lineage can fetch the parent's `manifest.json`, find the parent's signing key fingerprint, and verify the signature on the child's attestation. If the signature checks out, the variant's claim of parentage is cryptographically supported. If not, the chain is broken — the variant is lying about its lineage, or has been tampered with.

The attestation does NOT need to live in git. It can live anywhere addressable (a sigstore bundle, an HTTP URL, etc.). The `attestation` field stores either the envelope inline or a URL to it.

## Adoption path

Signing is opt-in per variant. The schema accepts `null` everywhere today; nothing breaks for unsigned variants. Adoption looks like:

### 1. Generate a signing key (per variant master)

For GPG:
```
gpg --quick-generate-key 'RAPP Releases <PLACEHOLDER ADDRESS>' rsa4096 sign 5y
gpg --armor --export <KEY-ID> > release-key.pub
```

For sigstore (keyless OIDC):
- Configure GitHub Actions OIDC → sigstore for tag pushes.
- No long-lived key to manage; identity is the GH repo + tag.

For minisign:
```
minisign -G -p release.pub -s release.key
```

### 2. Update `manifest.json`

```jsonc
"signing": {
  "method": "gpg",
  "key_id": "0123456789ABCDEF0123456789ABCDEF01234567",
  "verification_uri": "https://keys.openpgp.org/vks/v1/by-fingerprint/0123456789ABCDEF0123456789ABCDEF01234567"
}
```

### 3. Sign each new release

When `v/0.13.0/` lands:
- `git tag -s brainstem-v0.13.0` — signed git tag, verifies via `git tag -v`.
- Optionally: produce a sigstore bundle that signs `v/0.13.0/checksums.txt` and publish at `https://kody-w.github.io/RAPP/rapp_kernel/v/0.13.0/sigstore.bundle`.
- Set `versions[].attestation` to that URL in `manifest.json`.

### 4. Sign variant attestations

When a user lays an egg (variant), the parent's release key signs an envelope asserting their child's lineage, and the variant commits that envelope into its own `rappid.json`'s `attestation` field.

`hatchling lay-egg <new-repo-url>` (future capability) will orchestrate this: generate the envelope, request a signature from the parent's release key (interactively or via CI), commit the variant repo with the signed envelope baked in.

## Verification today (`hatchling verify`)

The `hatchling verify` command (shipped) reports lineage health for the current organism:

```
$ hatchling verify
organism rappid: <UUID>
clutch: 3 generation tag(s)
  gen 1   generations/<rappid>/1   stateful  unsigned
  gen 2   generations/<rappid>/2   stateful  unsigned
  gen 3   generations/<rappid>/3   stateful  unsigned
variant attestation: missing (this repo is not yet signed by its parent)
parent rappid: 0b635450-c042-49fb-b4b1-bdb571044dec
verify: ok
```

`unsigned` and `attestation: missing` are advisory today — the architecture wants signing but doesn't yet require it. Once a variant adopts signing, `hatchling verify` flips to:

```
  gen 3   generations/<rappid>/3   stateful  signed (issuer: kody-w/RAPP, key 01234567...)
variant attestation: present (issuer=...)
verify: ok
```

Future: a `--strict` flag that turns missing signatures into hard failures, suitable for production environments that cannot tolerate unsigned organisms.

## What this fixes from the version-hell review

| Review item | Status |
|---|---|
| Frozen bytes can be tampered with | Schema in place; signing rolls in per variant |
| Variant ancestry is unverifiable | `attestation` field shape + parent signing the envelope |
| Lineage walks have no integrity | Each step in the parent chain is cryptographically anchored once attestations exist |

It does not fix:
- Frozen bytes ≠ runnable bytes (Python deprecation, dep evolution) — that's an environment-freezing problem.
- State-snapshot integrity — `~/.brainstem/generations/<n>/state.tar.gz` is local, not signed; the threat model is malicious-on-disk, which is out of scope for now.

## See also

- [Constitution Article XXXIV](../../../CONSTITUTION.md) — Rappid + Variant Lineage. The lineage system this signs.
- [[The Species DNA Archive — rapp_kernel]] — what the archive provides; what signing adds on top.
- [[Boot Sidecar — Integrating Utils Without Modifying the Kernel]] — additive integration pattern; signing follows the same shape (no kernel edit required).
