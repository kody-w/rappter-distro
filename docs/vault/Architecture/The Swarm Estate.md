# The Swarm Estate — Rappid-Indexed Identity Across Public + Private + Live + Frozen

> *Vault note. The full protocol for treating an AI organism as an estate — a rappid-indexed portfolio of brainstems, eggs, and broadcasts that operate as one identity in many places. Synthesizes the lessons from Signal, Matrix cross-signing, Keybase sigchains, and DID:web, applied to RAPP's single-file-everything ethos. **Constitutionally ratified as Article XXXVI** ([CONSTITUTION.md](../../../CONSTITUTION.md)).*

> **Canonical rappid spec**: [[Rappid]]. There is one rappid format, ratified 2026-04-30. This protocol describes the cryptographic backing for organisms whose `<kind>` is `organism` / `twin` / `swarm` / `rapplication`. The format is shared with code variants (Article XXXIV) and the species root.

The original `Twin-Patterns.md` answered "how does one twin run on many machines?" That question presumes the twin is a runtime artifact and the machines are the substrate. This note flips it: **the twin is the estate, and a brainstem is a temporary mouthpiece**. The brainstem comes and goes; the estate persists and grows.

What makes the estate one *thing* — instead of a scattered pile of eggs, vaults, and broadcasts — is that every artifact carries the same rappid. The rappid is the index of a living portfolio.

> **Organs vs body_functions vs services.** This protocol historically referenced "single-file services" (`*_service.py` under `utils/services/`), then "body_functions" (`*_body_function.py` under `utils/body_functions/`). Current canonical: **organ** (`*_organ.py` under `utils/organs/`). Same contract; biological metaphor. Read all three terms as equivalent.

---

## The four channels of the estate

Every twin holding lands on one of two axes — **persistence** (frozen vs. live) and **visibility** (public vs. private). The four-quadrant grid is the entire estate.

|  | **Public** | **Private** |
|---|---|---|
| **Frozen** (git history) | RAPP_Store, public twin vaults, RAR registry — `raw.githubusercontent.com` | `kody-w/twin_vault`, gh-auth'd repos, internal swarm vaults |
| **Live** (real-time) | PeerJS public room broadcasting RAPPID + incarnation | PeerJS private room with cross-signed entry |

```
                      visibility
                  PUBLIC         PRIVATE
              ┌────────────────┬────────────────┐
        FROZEN│ raw.github     │ private vault  │  ← anyone with URL    ← credentials only
              │ RAR registry   │ internal repo  │
   persistence├────────────────┼────────────────┤
        LIVE  │ public PeerJS  │ private PeerJS │  ← active brainstem,  ← active brainstem,
              │ room (open)    │ room (signed)  │     anyone joins         signed entry required
              └────────────────┴────────────────┘
```

A complete swarm estate has holdings in all four quadrants. The RAPPID resolves them as one entity.

---

## What "operable whole" means

An estate is enumerable, inheritable, and queryable as one thing. That changes what verbs scoped to "I" mean.

| Verb | Old meaning (brainstem-scoped) | New meaning (estate-scoped) |
|---|---|---|
| *Back me up* | dump this brainstem's `.brainstem_data/` | push active state to my private estate, propagate to live peers |
| *Restore me* | unpack one egg into one brainstem | reconstruct from any holding in the estate, by RAPPID |
| *What do I know?* | read this brainstem's memory.json | query the union of memory holdings under my RAPPID |
| *Where am I?* | this brainstem's URL | every live brainstem broadcasting my RAPPID |
| *Find my kin* | n/a | walk the lineage tree via `parent_rappid` |
| *Speak as me* | this chat session | any cross-signed brainstem can field the call |

The estate is the subject. Brainstems are voices.

---

## Prior art

The swarm estate is an **identity-across-many-devices-publicly-verifiable** problem. Three existing systems have solved pieces of it:

| System | What it solves well | What we steal | What we don't |
|---|---|---|---|
| **Signal** | E2E messaging crypto, OS-keychain key storage, post-quantum migration (PQXDH 2023) | Private-key-never-leaves-device discipline; clean-break default for new devices | Phone-number-as-identity, central server, 1-to-1 message focus |
| **Matrix cross-signing** | Multi-device public verification, three-role key hierarchy, canonical JSON, federated identity | The whole hierarchy; canonical JSON for signed records; emoji-verification UX | Homeserver-as-hub assumption |
| **Keybase sigchain** | Public append-only ledger of identity events, social-proof linking, anyone-can-verify | The ledger-as-files-in-git pattern (we already have this shape with twin_vault); chain-reset semantics | Centralized server, social-proof model |

The right cousin is **Matrix**. Signal optimizes for private messaging on a central server; we need public verification across distributed substrates. Matrix's cross-signing protocol is almost exactly the swarm-estate problem, just renamed.

---

## Rappid — home-vault-URL bound into the identifier

The v1 RAPPID format was:

```
rappid:twin:@anon/kody:8844d5fe99cb77b6
```

Three holes:
1. The `home_vault_url` (where the canonical sigchain lives) is not part of the identifier — anyone can claim to be the home for any RAPPID.
2. The publisher slug `@anon` is unsigned — no proof the original brainstem actually claimed that name.
3. No version field — future format migrations are a flag day.

The v2 format binds the home vault URL into the RAPPID and includes an explicit version:

```
rappid:v2:twin:@kody/personal:8844d5fe99cb77b6@github.com/kody-w/twin_vault
                │   │   │       │                │
                │   │   │       │                └── home_vault_url (canonical sigchain location)
                │   │   │       └── identity hash (sha256 of master pubkey, truncated)
                │   │   └── publisher slug
                │   └── kind (twin | rapp | snapshot)
                └── format version
```

**Verification rule**: a manifest claiming this RAPPID is only honored if its master pubkey hash matches the embedded hash AND the `home_vault_url` resolves to a `root.json` whose pubkey also matches. Two independent checks against two channels — RAPPID strings can't be forged into existing identities.

**Migration**: existing v1 RAPPIDs continue to resolve. New mints use v2. A v1 RAPPID can be promoted to v2 by minting a `migration` record signed by the v1 master pubkey, claiming the new home_vault_url. Verifiers accept v1 → v2 mappings only if the migration record is in the home vault.

---

## The handshake (one shape, two transports)

Whether the channel is PeerJS (live) or git (frozen), the handshake is the same:

1. **Exchange manifests** — each side sends `{rappid_v2, master_pubkey_fingerprint, device_pubkey_fingerprint, incarnation, agents_count, hatched_on, parent_rappid, last_seen, alg, signature}`.
2. **Compare RAPPIDs** —
   - Identical → same lineage, possibly same self at different incarnations
   - Different but `parent_rappid` chains match → kin (your twin hatched from my snapshot)
   - Same root `@publisher/slug`, divergent suffix → forks within a lineage
   - No relation → strangers
3. **Verify signatures** — see *Cross-signing hierarchy* below. Without verification, the handshake is informational only; the peer cannot act *as* your RAPPID.

The git-channel version is just the asynchronous form: `*.manifest.json` files in vault repos *are* the handshake artifact, frozen in commit history. Anyone reading them is doing a one-sided handshake against frozen counterparts of you.

---

## The cross-signing hierarchy (Matrix-pattern)

> The RAPPID alone is not authority. RAPPID identifies; the cross-signing chain authorizes. A copied twin egg gives you the *memory* of the twin but not the *voice* — only signed device keys speak as the RAPPID on the live network.

Three roles, separated keys, depth-limited authority. This solves the "any blessed key can bless others" exponential-trust hole that a flat blessing graph creates.

```
                            ┌─────────────────────┐
                            │  MASTER KEY  (M)    │  ← minted at RAPPID birth
                            │  (offline-capable)  │     signs S and U
                            └──────────┬──────────┘     never signs devices directly
                                       │
                ┌──────────────────────┴──────────────────────┐
                │                                              │
                ▼                                              ▼
     ┌──────────────────────┐                    ┌──────────────────────┐
     │ SELF-SIGNING (S)     │                    │ USER-SIGNING (U)     │
     │ signs YOUR devices   │                    │ signs OTHER RAPPIDs  │
     │ (estate membership)  │                    │ (kin recognition)    │
     └──────────┬───────────┘                    └──────────┬───────────┘
                │                                            │
        ┌───────┼───────┬───────┐                            ▼
        ▼       ▼       ▼       ▼                  ┌──────────────────┐
   ┌────────┐ ┌────┐ ┌────┐ ┌────┐                 │  Other RAPPIDs   │
   │ Device │ │ B  │ │ C  │ │ D  │                 │  you've verified │
   │   A    │ │    │ │    │ │    │                 │  as kin/trusted  │
   └────────┘ └────┘ └────┘ └────┘                 └──────────────────┘
```

### The four key types

| Key | Cardinality | Lifetime | Storage | Role |
|---|---|---|---|---|
| **Master (M)** | 1 per RAPPID | identity-lifetime | OS keychain or encrypted offline backup; never on a brainstem-disk that ships eggs | Signs S and U. Root of trust. |
| **Self-signing (S)** | 1 per RAPPID | rotatable, signed by M | OS keychain on the operator's primary device | Signs every device key D. Proves "this brainstem is mine." |
| **User-signing (U)** | 1 per RAPPID | rotatable, signed by M | OS keychain on the operator's primary device | Signs other RAPPIDs you recognize as kin. Proves "I trust this peer." |
| **Device (D)** | 1 per brainstem | brainstem-lifetime, signed by S | `.brainstem_data/keypair.private.json`, never bundled in eggs (added to `_NEVER_PACK`) | Signs every manifest, broadcast, and message this brainstem emits. |

### What each key does NOT do

- M never signs devices directly. (If M is compromised, only S and U get rotated; existing devices stay valid until S is reissued.)
- S never signs other RAPPIDs. (Estate-membership and kin-recognition are different authorities.)
- U never signs devices. (Other people's devices aren't yours to authorize.)
- D never signs other devices. (Solves the exponential-trust hole — devices cannot grow the estate.)

### Operations

- **Bring a new brainstem into the estate**: new brainstem mints D, displays D's fingerprint. Operator goes to a brainstem holding S (or to wherever S is stored), confirms via 6-emoji safety code (`sha256(S_pub || D_pub)` → 6 emoji, both screens show identical sequence), S signs D, signed record commits to `blessings/<rappid>/devices/<D-fingerprint>.json` in the home vault.
- **Vouch for another RAPPID**: U signs the other RAPPID's master pubkey (with a verification level: `met-in-person`, `verified-out-of-band`, `inferred-from-kin`, etc.). Record commits to `kin/<rappid>/<their-fingerprint>.json`.
- **Rotate S or U**: M signs the new key; old key is marked revoked in the same record. Anyone walking the chain prefers the latest non-revoked S/U.
- **Revoke a device**: any brainstem holding S can sign a `revoke.json` for that device fingerprint. Live peers drop the revoked key on next handshake; frozen verifiers reject it on read.

---

## Record format and signing

Every signed record uses **Canonical JSON** (Matrix spec, [§Appendices](https://spec.matrix.org/v1.7/appendices/#canonical-json)) for the byte sequence that gets signed. This solves the "JSON isn't canonical" hole.

### Canonical JSON rules

- UTF-8 encoding, no BOM.
- Object keys sorted lexicographically (Unicode code-point order).
- No insignificant whitespace (no spaces, no newlines outside string values).
- Numbers: no leading zeros, no fractional zeros, no scientific notation, integers in `[-2^53+1, 2^53-1]`.
- No Unicode escapes for ASCII characters.

### Record envelope

Every signed record has the same envelope:

```json
{
  "alg": "ecdsa-p256",
  "schema": "swarm-estate-record/1.0",
  "kind": "device-signing | revoke | kin-vouch | migration | rotate-self | rotate-user | chain-reset",
  "rappid": "rappid:v2:twin:@kody/personal:8844d5...@github.com/kody-w/twin_vault",
  "issued_at": "2026-04-30T20:00:00Z",
  "issued_by": "<fingerprint of the signing key>",
  "issued_by_role": "M | S | U",
  "payload": { /* kind-specific */ },
  "signature": "<base64 ECDSA signature over canonical JSON of all preceding fields>"
}
```

The `alg` field is non-negotiable. Verifiers reject any record with an unknown `alg`. Future post-quantum migration adds `ml-dsa-87` or hybrid `ecdsa-p256+kyber1024` without breaking existing records.

### Example: device-signing record

```json
{
  "alg": "ecdsa-p256",
  "schema": "swarm-estate-record/1.0",
  "kind": "device-signing",
  "rappid": "rappid:v2:twin:@kody/personal:8844d5...@github.com/kody-w/twin_vault",
  "issued_at": "2026-04-30T20:00:00Z",
  "issued_by": "fp:S:af20bc91...",
  "issued_by_role": "S",
  "payload": {
    "device_pubkey": "<base64 SPKI>",
    "device_fingerprint": "fp:D:7e4a2c80...",
    "label": "kody's MBA M2",
    "scope": ["live", "frozen"],
    "expires_at": null
  },
  "signature": "MEUCIQDx...base64..."
}
```

### Verification algorithm

For any received record:
1. Strip the `signature` field, canonicalize the rest.
2. Look up `issued_by` in the home vault's chain. Must be present and not revoked.
3. Verify `issued_by_role` matches the kind: only M can issue rotate-self/rotate-user/chain-reset; only S can issue device-signing; only U can issue kin-vouch.
4. Check the signature against the canonical bytes using the algorithm in `alg`.
5. Walk the chain backward from `issued_by` to root M. If any link is broken or revoked, reject.

---

## Master-key recovery

Losing M means the estate is dead — no future S/U rotation, no migration, no chain-reset. Three approaches, listed by trade-off:

### Option A: Secure Backup (Matrix-pattern, recommended default)

Encrypt M with a high-entropy passphrase (BIP-39 wordlist, 12-24 words). Store the ciphertext in the private home vault as `recovery/master-key.enc.json`. To recover: clone vault, decrypt with passphrase.

**Pros**: simple, single-operator. No coordination required.
**Cons**: passphrase is a single point of failure. If you forget, dead.

### Option B: Shamir's Secret Sharing (paranoid mode)

Split M into `k`-of-`n` shards using Shamir. Distribute shards to trusted people, devices, or geographic locations. Recovery requires collecting `k` shards.

**Pros**: no single point of failure. Loss-tolerant up to `n - k`.
**Cons**: requires trusted holders. Coordination overhead. Risk of collusion.

### Option C: Sigchain reset (Keybase-pattern, escape hatch)

Accept loss; mint a new M; declare a `chain-reset` record signed by some social-recovery authority (e.g., a `parent_rappid` you originally hatched from, or a U-vouched kin). New M takes over the RAPPID; old chain becomes historical.

**Pros**: no preparation required. Honest about the bootstrap-of-trust problem.
**Cons**: requires a kin to vouch. Verifiers must accept that "the same RAPPID" now has a new master root, which is dangerous if abused.

The estate protocol supports all three. Default UX uses Option A. Operators with paranoid threat models opt into Option B. Option C is the documented escape hatch when nothing else worked.

---

## Verification UX (the emoji dance)

Hex fingerprints are unusable. Operators won't compare 64 hex characters by eye. Matrix shipped emoji verification because it works.

When bringing a new brainstem D into an estate signed by S:

1. Both screens compute `sha256(S_pub || D_pub)`.
2. Take the first 48 bits, split into 8 chunks of 6 bits each.
3. Map each chunk to an emoji from a 64-emoji canonical list (Matrix uses [this list](https://spec.matrix.org/v1.7/client-server-api/#sas-method-emoji)).
4. Both screens display the same 8 emoji in the same order.
5. Operator confirms aloud or visually: 🐶 🌹 🍀 🦋 🎩 🚀 🎸 🍕

If the emoji match, the channel is authentic and S signs D. If they don't, abort — there's a MITM.

This is also reusable for U-signing kin RAPPIDs: both operators see 8 emoji derived from `sha256(my_U_pub || their_M_pub)`, confirm out-of-band.

---

## What this prevents (with the new model)

| Attack | Defense |
|---|---|
| Steal a twin egg, run it, claim to be the owner | Egg has memory + RAPPID + pubkeys. Has no D private key (`_NEVER_PACK`). Cannot produce signatures matching any signed device. |
| Forge a manifest claiming a RAPPID | Manifest must be signed by a D whose chain back to M is in the home vault. Verifiers reject unsigned, unknown-D, or revoked-D records. |
| Bless yourself into someone's estate | Device-signing requires S's signature. S is held by the operator's primary device. Adversary needs S's private key, which never leaves OS keychain. |
| Compromise one device → expand to whole estate | D cannot sign new devices (only S can). One device compromise = one revocation, not a cascade. |
| MITM during pairing | 8-emoji safety code (Matrix-style) shown on both screens. Operator verifies visually before S signs. |
| Lose your laptop | Revocation: S signs a `revoke.json` for the lost device's fingerprint. Estate scanners drop revoked keys on next read. |
| Rogue vault claiming to host your rappid | rappid embeds the canonical home_vault_url. Verifiers fetch root.json from THAT url and check master pubkey hash matches the rappid. Rogue vaults can't satisfy both checks. |
| Forge JSON record with different key order | Canonical JSON forces a single byte representation. Re-canonicalization on receive catches any reordering. |
| Replay an old signed record after revocation | Records carry `issued_at`. Revocation records carry `revoked_at`. Anything signed before its key was revoked is honored; after, rejected. (Time-skew tolerance: ±5 min for live, infinite for frozen-history reads.) |
| Mint a future-incompatible algorithm | `alg` field must be in the verifier's allowlist. Unknown algorithms = automatic rejection. New algorithms ship in verifier updates first, then in records. |

---

## Why this lets the estate collaborate in public, securely

Visibility and vulnerability decouple. The cross-signing chain, the pubkeys, the manifests, the lineage tree — all of it can live in public-readable repos and broadcast on public PeerJS rooms without weakening the security model. The cryptography does the gating, not the channel.

- **Public reading is the design.** Anyone can clone `twin_vault`, scan manifests, traverse `parent_rappid` chains, watch broadcasts, and build a complete view of who-is-whom across the estate. Reading is universal; that's the *point*.
- **Acting-as remains private.** Speaking *as* a RAPPID requires producing a signature that verifies against a chain-resolved D. Reading the ledger doesn't help you forge one. A copied vault is a museum, not a costume.
- **Collaboration becomes a primitive.** Two estates can shake hands in the open: each side broadcasts its M-rooted chain; each verifies the other's chain. Strangers don't have to trust each other in advance — they trust the math, which everyone has equal access to.
- **No central authority required.** Each estate's M is its own. There is no Rappter CA, no kody-w trust hub. RAR can act as a discovery aggregator (an index of known M roots), but it never signs on anyone's behalf.

The property that makes this the right frame: **the more visible it is, the easier it gets to verify, and the easier verification gets, the safer it becomes.**

---

## What's in tree today (post-protocol)

| Building block | Status | Path |
|---|---|---|
| RAPPID v1 minting | ✅ shipped | `utils/egg.py:get_or_create_twin_rappid` |
| Lineage in manifest (`parent_rappid`, `incarnations`) | ✅ shipped | `utils/egg.py:pack_twin` |
| Lineage survives hatching (proven 2026-04-30) | ✅ proven | `/tmp/sandbox-brainstem/` test |
| Local peer registry | ✅ shipped | `utils/services/neighborhood_service.py` |
| Twin/snapshot egg roundtrip | ✅ shipped | `/rapps/export/twin`, `/agents/import` |
| Private vault prototype | ✅ shipped (2026-04-30) | `kody-w/twin_vault` |
| ECDSA P-256 keypair generation in JS | ✅ shipped (in pair.html) | `utils/web/pair.html:generateKeypair` |
| Pairing safety code (sha256-derived) | ✅ shipped (in pair.html) | `utils/web/pair.html` |
| rappid format (with embedded home_vault_url) | ❌ proposed | needs `utils/egg.py` update + v1→v2 migration |
| Master / self-signing / user-signing key hierarchy | ❌ proposed | new `utils/identity/cross_sign.py` |
| Device key (D) per brainstem, server-side | ❌ proposed | new `utils/identity/device_key.py`, must add filename to `_NEVER_PACK` in egg.py |
| Canonical JSON serializer + verifier | ❌ proposed | new `utils/identity/canonical_json.py` (~80 lines) |
| Cross-signed records ledger | ❌ proposed | `blessings/<rappid>/{root,devices/,kin/,revoke/}` in vault repos |
| 8-emoji safety code UI | ❌ proposed | reusable component, both pair.html and new estate join flow |
| Master-key Secure Backup (encrypted) | ❌ proposed | optional, encrypted with operator passphrase |
| PeerJS estate-channel service | ❌ proposed | `utils/services/swarm_channel_service.py` |
| Manifest scanner (vault crawler) | ❌ proposed | `utils/services/lineage_scanner_service.py` |
| Lineage tree visualizer | ❌ proposed | HTML face on the scanner |

The substrate is mostly here. What's missing is the connective tissue: the cross-signing identity module, the canonical JSON layer, the PeerJS estate-channel service, and the scanner.

---

## Connection to existing concepts

- **RAR** is the trust layer for *agents* (single-file skills). RAR signs `*_agent.py` files.
- **RAPPID + cross-signing** is the trust layer for *identities* (twin estates). The chain signs *brainstem device keypairs* into a RAPPID.
- They compose: a published rapplication is RAR-signed (agent provenance) and lives under some RAPPID (estate membership). Provenance answers "is this code authentic?"; cross-signing answers "is this brainstem authentic?"

- **Twin Patterns** (`Twin-Patterns.md`) describes how one twin runs on N brainstems without merging. The Swarm Estate is the *registry* of those N brainstems plus all their frozen counterparts. **The "summon and go" pattern is preserved**: hatching gives you the RAPPID + memory + read-only estate access; you can browse the public estate immediately. Speaking *as* the RAPPID requires the device-signing flow (8-emoji safety code), which is one minute of operator effort.

- **The IP designation** maps onto the public/private split of the estate exactly. Public estate is RAPP-engine territory (Microsoft Business Applications). Private estate is Wildhaven territory (Consumer / Digital Twin / Perpetuity). The trust gradient is also a business gradient.

---

## Constitutional implication

The current 32 articles cover the brainstem and the kernel. None of them yet cover the *estate* — the union across brainstems and time. This is probable Article XXXIII material:

> **Article XXXIII — The Estate Is the Twin.** Identity is not a file or a process; it is the union of every artifact bearing the same RAPPID. Live brainstems are voices for the estate, not its boundaries. Authority within the estate flows from a Master key, expressed through Self-signing (which authorizes brainstems) and User-signing (which authorizes kin RAPPIDs). RAPPID without a verified chain is identification, not authorization. The estate may live anywhere; its canonical home is bound into the RAPPID itself.

Drafting that as a real article is a follow-up commit, not this note.

---

## Known holes (honest catalogue)

The protocol above closes most of the holes the v0 design had, but not all. Some are unfixable; some are deferred.

### Closed by this revision

| Old hole | Closed how |
|---|---|
| Exponential blessing trust | Three-role split (M / S / U / D); D cannot sign other devices |
| Private key bundled in eggs | D's private key in dedicated file added to `_NEVER_PACK`; never enters egg |
| JSON canonicalization hand-wavy | Canonical JSON (Matrix spec) for every signed record |
| Canonical home URL unauthenticated | rappid embeds `home_vault_url`; root.json's pubkey hash must match RAPPID's hash field |
| No algorithm agility | `alg` field on every record; verifiers refuse unknown algorithms |
| Authority confusion (gh write vs blessings) | All records cryptographically self-validating; git is transport, not source of truth |

### Still open (acknowledged)

| Hole | Severity | Mitigation today | Future work |
|---|---|---|---|
| Metadata leakage in public manifests | medium | None — that's the design's price | Sealed Sender-style envelope encryption for sensitive fields; opt-out into private estate |
| PeerJS broker dependency | medium | Use peerjs.com default; protocol is broker-agnostic | Self-hosted signaling (Cloudflare DO, Matrix-style federation) |
| Master-key loss = estate death | medium | Secure Backup (encrypted with passphrase) by default | Shamir threshold for paranoid users; chain-reset escape hatch |
| Cross-signing UX friction | low | 8-emoji verification once per device | Auto-pairing with parent device for trusted contexts (corp deployment) |
| Reconnaissance from public manifests | inherent | None — visibility is the point | Per-quadrant opt-out (some RAPPIDs go fully private) |
| DOS on public PeerJS rooms | low-medium | Rate-limit per fingerprint; cheap rejection of unsigned records | Proof-of-work for first-contact handshakes |
| Centralization in adoption | cosmetic | Multiple PeerJS brokers viable; vault hosts are interchangeable | AT-Protocol-style account migration when home vault changes |
| Quantum-vulnerable today | low (today) | Algorithm agility lets us migrate | Ship hybrid `ecdsa-p256+kyber1024` records once standardized |

### Adoption / network-effect

| Question | Status |
|---|---|
| First incremental value at N=1? | Estate of one is just a brainstem with cross-signed devices. Ship the device-signing flow first; live broadcast and scanner come once N>1. |
| Where do RAPPIDs discover each other initially? | Bootstrap discovery via static peer URLs (you tell me you're at `vault.example.com`). RAR as a soft-aggregator index. PeerJS public room as a free-for-all later. |
| What does an unsigned peer see? | Read-only access to public estate. Cannot broadcast as a RAPPID. Mirrors RAR's "trust layer, not gate" principle. |

---

## Provenance of this note

Written 2026-04-30, then expanded the same evening into the full protocol. Chain of conversation turns:
- Demonstrated RAPPID survives hatching (`/tmp/sandbox-brainstem/`)
- Built `kody-w/twin_vault` as the private-vault prototype
- Sketched the dual-channel handshake (live + frozen)
- Crystallized "swarm estate" as the operable whole
- Mapped the security model onto the existing pair.html ECDSA pattern
- **Critiqued the v0 design — found 10 holes**
- **Studied prior art (Signal, Matrix, Keybase) and adopted Matrix's three-role cross-signing pattern**
- **Specified canonical JSON, rappid with embedded home URL, algorithm agility**
- **Catalogued remaining holes honestly**

Each step was concrete. This note is the integration. The next step is `utils/identity/cross_sign.py` — the smallest piece of code that makes any of this real.
