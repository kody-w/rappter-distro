# Decentralized by Design — Bitcoin-Grade Network Properties on Top of Git

> *Vault note. The full architecture for treating the swarm-estate network as Bitcoin-equivalent in survival properties — without inventing a new chain, without proof-of-work, and without a central server. Synthesizes Local-First-by-Design with the broader stack: OpenTimestamps anchoring, federated signaling, kin-graph discovery, content-addressed storage. The complete picture of how the Foundation outlives its founders and its hosts.*

`The Swarm Estate.md` defined the cryptographic identity protocol. `Local-First-by-Design.md` committed to the local-first survival model. This note ties together the four operational layers that, taken as a system, give us Bitcoin-grade decentralization properties on top of Git.

---

## What "Bitcoin-grade" actually means

Bitcoin's survival properties are six things. We need each one, but in a different shape because we're an *identity* protocol, not a *value-transfer* protocol.

| Bitcoin property | Why we need it | How we get it |
|---|---|---|
| **Trustless verification** | Anyone can verify any record without trusting a third party | Cross-signing chain + canonical JSON + signed records (already shipped) |
| **Permissionless participation** | Anyone can mint a rappid, run a verifier, host a vault | rappid minting requires no permission; tools are public Python (already shipped) |
| **Censorship resistance** | No host can remove records that have been signed | Local-first: any local copy IS the network. Multi-host adds availability, not authority. |
| **Append-only history** | Past signatures cannot be silently rewritten | Git's commit DAG (Merkle, SHA-256) + signed records refuse modification |
| **Public auditability** | Whole ledger readable by anyone | `raw.githubusercontent.com` + multi-host mirroring + IPFS pinning + verify-local-vault.py |
| **Bitcoin-grade timestamping** | Unforgeable proof of "X existed before block N" | OpenTimestamps anchored into actual Bitcoin (already shipped) |

What Bitcoin needs that *we don't* — proof-of-work, miners, global consensus, scarce currency — is irrelevant for identity. Identities don't double-spend. RAPPIDs cannot conflict. We get the survival properties without paying the energy / fee / scaling tax.

---

## The four-layer architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  IDENTITY LAYER — what the protocol does                         │
│  • rappid with embedded home_vault_url                       │
│  • Three-role cross-signing (M / S / U / D) per Matrix pattern  │
│  • Canonical JSON record format with `alg` field                │
│  • Recursive holocard: agent → swarm → rapplication → organism  │
│  Spec: pages/vault/Architecture/The Swarm Estate.md             │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────────┐
│  STORAGE LAYER — where records live                              │
│  • Each operator's local vault is the canonical form            │
│  • Hosts (GitHub, GitLab, Codeberg, IPFS) are transports        │
│  • content_hash is recomputable; vault-state-proof attests it   │
│  • git's Merkle DAG provides tamper detection                   │
│  Spec: pages/vault/Architecture/Local-First-by-Design.md        │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────────┐
│  TIMESTAMP LAYER — when records existed                          │
│  • OpenTimestamps anchors record hashes into Bitcoin             │
│  • .ots proof files committed alongside originals                │
│  • Auto-upgrade workflow keeps proofs compact within 100 days   │
│  • Bitcoin's PoW chain becomes the timestamp source              │
│  Tools: ots stamp / ots upgrade / ots verify                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────────┐
│  DISCOVERY LAYER — how peers find each other                     │
│  • Bootstrap seed list (well-known starting RAPPIDs)            │
│  • Walk kin records (signed by U keys) from known starting point│
│  • Aggregators (RAR, github.io explorers) are caches            │
│  • PeerJS (later, libp2p, brainstem-as-signaling) for live peers│
└─────────────────────────────────────────────────────────────────┘
```

Each layer is independently load-bearing. The protocol works with any subset of layers active (e.g., offline operation works without the discovery layer).

---

## Why this beats traditional decentralization approaches

### vs. Bitcoin / Ethereum (blockchain)

| Property | Blockchain | Swarm Estate |
|---|---|---|
| Energy cost | Proof-of-work or stake | Zero — no consensus needed |
| Transaction fees | Yes | None — git push has no per-record cost |
| Latency | 10-min blocks (Bitcoin) | Real-time (any signed record is immediately valid) |
| State size | Hundreds of GB to verify | Megabytes per estate |
| Consensus required | Yes (single chain) | No (each estate is sovereign) |

We're cheaper because we don't need consensus on a global ledger. We just need verifiable individual chains.

### vs. Federated systems (Mastodon / ActivityPub / Matrix)

| Property | Federation | Swarm Estate |
|---|---|---|
| Server-as-authority | Yes (homeserver controls user) | No (master key controls; host is transport) |
| Migration cost | High (export + import + re-follows) | Low (signed migration record; identity stays) |
| Single-server deplatforming impact | Loses identity, must re-mint elsewhere | None (local copy is authoritative) |

Federation is a step in the right direction; we go further by making the hosting layer fully fungible.

### vs. DID:web / W3C VC ecosystem

| Property | DID:web | Swarm Estate |
|---|---|---|
| Identifier format | `did:web:domain.com:path` | `rappid:v2:kind:@pub/slug:hash@host` |
| Ownership of `did.json` | Whoever controls the domain | Whoever holds the master key |
| Domain compromise = identity loss | Yes | No (master key is independent of host) |
| Multi-device support | Manual key cross-signing | Built-in via three-role hierarchy |
| AI-entity perpetuity claims | Generic | First-class (v4 §7.18, §7.19) |

DID:web is a closer cousin than blockchain or federation. We extend it with: cross-signing hierarchy, perpetuity semantics, recursive scope, dreamcatcher-style merge.

### vs. AT Protocol (Bluesky)

| Property | AT Protocol | Swarm Estate |
|---|---|---|
| Identifier | `did:plc:...` or `did:web:...` | `rappid:v2:...@host` |
| Account migration | Yes (PDS-to-PDS) | Yes (signed migration record) |
| Public-by-default | Yes (social media) | Configurable (private vaults supported) |
| AI-entity perpetuity | Not addressed | First-class |

AT Protocol is the closest analog. We borrow their migration semantics; they borrow nothing from us yet.

---

## What this means for adversaries

The strongest claim: **at Bitcoin-scale adversarial pressure, the network's load-bearing properties don't break under any single-vector attack.**

| Attack | Defense |
|---|---|
| Compromise GitHub | Local copies remain authoritative; verification works offline |
| Compromise GitHub + GitLab + Codeberg | IPFS pinning + air-gapped local copies survive |
| Compromise the operator's account on every host | Master key in Shamir 3-of-5; quorum re-anchors |
| Forge a record claiming an existing RAPPID | Master pubkey hash in RAPPID itself; signature chain catches |
| Forge a backdated record | OTS-anchored timestamps in Bitcoin; backdating requires breaking Bitcoin |
| Sybil-attack the kin graph | Application-level trust scoring weighted by lineage age + OTS anchor depth |
| 51% attack on social trust | No global trust score exists; each application weighs kin signals locally |
| BGP hijack of a single host | Multi-host fetch with content-hash comparison detects divergence |
| Operator dies / disappears | Inactivity protocol + 3-of-5 Shamir guardians install successor |
| Wildhaven LLC dissolves | Release-triggers.json T1 publishes Dreamcatcher engine source |
| Bitcoin breaks (post-quantum) | Algorithm-agility: migrate to ML-DSA via signed `migration-plan`; classical signatures retained as historical |

Each adversary action requires defeating a different layer. To take down the network, an adversary must defeat ALL of them simultaneously — which is functionally equivalent to taking down Bitcoin and Git and the whole human practice of physical sneakernet.

---

## What's actually shipped vs. specified

| Element | Specified | Implemented |
|---|---|---|
| rappid minting | ✅ | ✅ Block 0 + Block 1 in `kody-w/wildhaven-ceo` |
| Three-role cross-signing | ✅ | ✅ M/S/U keys for both estates |
| Canonical JSON records | ✅ | ✅ All signed records use Matrix-spec canonical JSON |
| `alg` field for algorithm agility | ✅ | ✅ Every record has `alg: ecdsa-p256` |
| Local-first content addressing | ✅ | ✅ `compute-vault-hash.py`, `vault-state-proof.json` signed |
| Offline verification | ✅ | ✅ `verify-local-vault.py` validates end-to-end with zero network |
| OpenTimestamps anchoring | ✅ | ✅ `.ots` proofs for all 7 load-bearing records, auto-upgrade workflow active |
| Inactivity protocol | ✅ | ✅ `sign-heartbeat.py` + GitHub Action monitoring |
| Customer estate genesis | ✅ | ✅ `genesis-customer-estate.py` template |
| Recovery drill | ✅ | ✅ `recovery-drill.py` validated for both estates |
| Schema versioning policy | ✅ | ✅ `schema-versioning-policy.md` |
| Algorithm-agility plan | ✅ | ✅ `algorithm-agility-policy.md` |
| Foundation as repo (not 501c) | ✅ | ✅ `kody-w/wildhaven-ceo` IS the Wildhaven Foundation |
| Release triggers (engine open-sourcing) | ✅ | ✅ Master-signed `release-triggers.json` |
| Bootstrap seed list | ✅ | ✅ `bootstrap-seeds.json` with Wildhaven + Molly |
| Multi-host mirroring | Operational | TODO — local-first means this is convenience, not survival |
| Shamir custody ceremony | Operational | TODO — operator must perform; tool ready |
| Dreamcatcher conformance suite | ✅ | TODO — skeleton in this repo, fill in over time |

The "specified" column is fully complete. The "implemented" column has the structural pieces in place; the remaining TODOs are operational ceremonies (Shamir ceremony) or cosmetic redundancy (additional mirrors).

---

## Provenance

Architecture committed across multiple commits on 2026-04-30:
- `kody-w/RAPP` (public): protocol spec, local-first principle, this note
- `kody-w/wildhaven-ceo` (private): all operational records, Foundation continuity
- `kody-w/invention-notebook` (private): timestamped IP record
- `kody-w/twin_vault` (private): twin egg backup prototype

The network is operational from this date forward. Block 0 (Wildhaven AI Homes) is genesis. Block 1 (Molly, kin) is the first sub-estate. Future blocks are customer estates, employee estates, partner estates — each minted via the same ceremony, each verifying under the same protocol, each surviving under the same Bitcoin-grade properties.

## Related

- [[The Swarm Estate]] — protocol spec
- [[Local-First-by-Design]] — survival model commitment
- [[Twin-Patterns]] — multi-device shape
- [[RAR — Trust Without Discrimination]] — trust-without-CA principle
