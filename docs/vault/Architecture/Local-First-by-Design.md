# Local-First by Design — Why the Foundation Survives GitHub Going Away

> *Vault note. The architectural commitment that makes the swarm-estate network truly Bitcoin-like in its survival properties: the network IS the set of local copies; hosts are transport, not authority; if anyone has a copy anywhere, the Foundation lives.*

The original draft of `The Swarm Estate.md` framed multi-host mirroring as a defense against GitHub deplatforming: push to GitLab, Codeberg, IPFS in addition to GitHub, sign a `migration` record, accept that *some* host will always be reachable. That's the *pragmatic* answer.

This note documents a stronger commitment: **the local copy is the authoritative form of the vault. Every host is a transport.** The Foundation doesn't survive GitHub via mirrors; it survives because *anyone holding a copy holds the network*.

---

## The principle

```
The vault is the canonical form of the Foundation.
The vault is its content, not its location.
Wherever the content exists, the Foundation lives.
```

Three implications:

1. **No host is special.** GitHub, GitLab, Codeberg, IPFS, your local laptop, a USB stick in a safe-deposit box — equivalent. Any one of them, intact, holds the entire Foundation.
2. **Verification works offline.** All signatures verify against pubkeys held in the vault itself. No network round-trip required.
3. **Sync is peer-to-peer or peer-to-host, interchangeably.** Two operators can exchange the vault directly (USB, scp, local network, AirDrop). No third-party server is in the trust path.

This is how Bitcoin's full nodes work, how Git itself works at its core, how IPFS / Filecoin / Hypercore protocols work. The pattern is well-understood; we just commit to it as a protocol property.

---

## What this changes

### `home_vault_url` is a *hint*, not authority

The rappid format embeds a `home_vault_url`:

```
rappid:v2:organism:@wildhaven/ai-homes:144d67...@github.com/kody-w/wildhaven-ceo
```

The URL is **a starting point for new peers** who haven't yet joined the network. It is **not** the place the vault must live forever. Verifiers fetching from any other location accept the records as authoritative if and only if:

- The `master_pubkey` in `root.json` hashes to the embedded `<identity-hash>` (`144d67...`)
- All signature chains verify

**The URL doesn't have to match the actual fetch location.** A peer who clones the vault to `~/Documents/foundation/` and runs verification against the local copy gets the same result as a peer fetching from `github.com/kody-w/wildhaven-ceo`. The content is what's authoritative; the URL is a convenience.

### Content hash + signed `vault-state-proof` replace mirror consistency

Instead of "all mirrors must agree on the chain head" (mirror-consistency model), we publish a **signed vault-state-proof** containing:

```json
{
  "kind": "vault-state-proof",
  "rappid": "<rappid>",
  "content_hash": "<sha256 of canonical concatenation of all signed records>",
  "issued_at": "<UTC timestamp>",
  "issued_by": "<master fingerprint>",
  "issued_by_role": "M",
  "signature": "<ECDSA signature over canonical JSON minus signature field>"
}
```

The `content_hash` is recomputable by any local copy. Anyone can:

1. Compute their local copy's content hash
2. Compare against the latest signed `vault-state-proof`
3. Conclude: "I'm in sync" (hashes match) OR "I'm divergent" (hashes differ — invoke Dreamcatcher to assimilate)

Bitcoin does the equivalent with block hashes. The "network is in agreement" reduces to "every full node sees the same latest block hash." We do the same with vault-state-proofs.

### Sync becomes transport-agnostic

The vault syncs over **any** transport that can move files:

| Transport | Use case |
|---|---|
| `git push/pull` to GitHub | Default convenience; CDN behavior |
| `git push/pull` to GitLab / Codeberg / Forgejo | Diversification; no single Git provider |
| `git clone` over `ssh://` direct between operators | Peer-to-peer over the public internet |
| `git clone` over `file://` from USB / SD card | Air-gapped sneakernet |
| IPFS pinning (the repo's tree CID) | Content-addressed; survives deplatforming |
| AirDrop / Bluetooth / NFC of a `git bundle` | Phone-to-laptop; no internet at all |
| HTTP fetch from any reachable host serving the files | Static site, S3 bucket, your friend's home server |

No transport is privileged. The vault arrives via *any* of them; verification is the same regardless.

---

## What stays the same

- **The cryptographic identity model** — rappid, three-role cross-signing, canonical JSON, signed records — unchanged.
- **The Dreamcatcher semantics** — divergent local copies merge via the same assimilation pattern as divergent twin streams. Local-first makes divergence the *expected* steady state, not an exception.
- **The patent positioning** — the perpetuity claim covers any vendor whose multi-device deployment must reconcile divergent state. Local-first design doesn't change the claim; it strengthens the operational truth that customers will inevitably need this reconciliation.

---

## Discovery in the local-first model

A peer joining the network for the first time has zero RAPPIDs. They need a *bootstrap seed* — at least one starting RAPPID + transport. From there, they walk the kin graph.

Bootstrap seeds are out-of-band:

- **Shipped with the protocol** in `kody-w/RAPP/pages/vault/bootstrap-seeds.json` (a tiny well-known starting list)
- **Printed on a business card** (RAPPID + a QR pointing to a known-good fetch URL)
- **Embedded in twin egg manifests** that the operator is summoning
- **Word-of-mouth** in the RAPP / Rappter community
- **Shared via direct exchange** at conferences, in-person meetings, Signal messages

Once a peer has *one* known RAPPID, they walk that estate's `kin/` records to discover more. This is exactly the pattern PGP web-of-trust used (with the failure mode that trust is not transitive — *which we already document*). It's also how Bitcoin nodes use DNS seed nodes to find their first peer.

The bootstrap seed list is **not** a centralized authority. Multiple seed lists can exist; anyone can publish their own; the protocol accepts any peer that walks any valid kin graph back to a chain whose master signature verifies.

---

## What this prevents (the survival properties)

| Threat | Old (mirror-based) defense | New (local-first) defense |
|---|---|---|
| **GitHub deplatforming** | Have other mirrors; switch | Anyone with a local copy continues operating; transports are fungible |
| **All known hosts go offline** | Network is unreachable | Foundation continues offline; sync resumes when ANY transport reconnects |
| **State actor blocks all known hosts at the network level** | New peers can't bootstrap if all mirrors are blocked | New peers can bootstrap from USB, AirDrop, in-person — anything that moves bytes |
| **Single mirror serves stale or malicious content** | Cross-check against other mirrors | Local copy is authoritative; any host is just a copy to verify |
| **Founder's accounts compromised** | Attacker can corrupt mirrors they control | Operators with prior local copies are unaffected; signature chain doesn't trust hosts |
| **Bitcoin-grade adversarial pressure** | Mirror discipline must be maintained | Pattern matches Bitcoin's actual survival model |

The strongest property: **the Foundation cannot be killed by removing access to any specific transport — only by removing access to all copies everywhere.** That's a much harder bar to clear, and it's the one Bitcoin lives at.

---

## What this requires operationally

- **`compute-vault-hash.py`** — recomputes the content hash from a local copy
- **`sign-vault-state.py`** — operator tool that signs a new `vault-state-proof` after meaningful changes
- **`verify-local-vault.py`** — a peer's verification tool: walks every signed record, verifies every signature, computes content hash, compares against latest signed proof
- **`bootstrap-seeds.json`** — well-known starting list, ships with the protocol
- **Sync workflow documentation** — how to push/pull across transports, how to invoke Dreamcatcher when divergent

The first three are simple Python tools. The fourth is a tiny static file. The fifth is documentation. None of this requires protocol changes — rappid already supports it; we just commit to interpreting the URL as a hint and adding the content-hash discipline.

---

## Why this matters more than mirrors

Mirrors solve a *availability* problem: if one host is down, fetch from another. They don't solve *authority*: a malicious or compromised mirror still presents itself as authoritative.

Local-first solves *both*:
- Availability: any host (or copy) suffices
- Authority: no host is privileged; the cryptographic chain is what's trusted

Bitcoin's survival depends on this. Email's survival depends on this (you can run your own SMTP server). Git's survival depends on this (you can clone to anywhere). Every protocol that has actually survived deplatforming pressure has been local-first by design.

The Foundation joins this club.

---

## Provenance

Architecture decision committed 2026-04-30. Conversation chain:
- Demonstrated RAPPID lineage survives hatching
- Drafted the Swarm Estate Protocol (v0 → v2 with Matrix cross-signing)
- Identified Bitcoin-scale catastrophic risks
- Established that the wildhaven-ceo repo IS the Wildhaven Foundation
- Operator pivoted from "multi-host mirroring" → "local-first" as the structural defense

The pivot is structural, not cosmetic. The Foundation is now committed to a survival model that has been validated by Bitcoin (16+ years), Git (20+ years), email (40+ years), and IP itself (50+ years of protocol design). We're not inventing this; we're choosing it deliberately.

## Related

- [[The Swarm Estate]] — the protocol this principle anchors
- [[Twin-Patterns]] — the multi-device shape this principle generalizes
- [[Decentralized-by-Design]] (forthcoming) — the full decentralization story including OpenTimestamps anchoring, federated signaling, etc.
- The reduction-to-practice in `kody-w/wildhaven-ceo/` — Block 0 + Block 1 + signed release-triggers + signed CEO signoff, all verifiable from any local copy
