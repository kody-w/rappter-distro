---
title: Rappid — The One Identifier
status: published
section: Architecture
hook: Rappid is the public ID — one format, one concept — for every digital organism that descends from RAPP. The species' social-security number. The species tree's lingua franca. There is no other identifier system; there will never be a divergent format.
---

# Rappid — The One Identifier

> **Hook.** Rappid is the public ID — one format, one concept — for every digital organism that descends from RAPP. The species' social-security number. The species tree's lingua franca. There is no other identifier system; there will never be a divergent format.

This note is the canonical specification for the rappid identity system. It is intentionally short, intentionally singular, and intentionally final on the format question. Subsidiary notes elaborate on lineage, signing, and operational tooling — but every reference back to "what is a rappid" lands here.

## What rappid is

A rappid is a public identifier assigned to every digital organism in the RAPP species tree. RAPP itself — the prototype, the godfather — has a rappid. Every variant of RAPP has a rappid. Every AI organism running on top of a RAPP-descended brainstem has a rappid. Every twin, swarm, customer estate, and future android / monkey / turtle / cloud / on-device organism has a rappid.

Rappids:

- Are **public**. Anyone can read them, share them, reference them.
- Are **immutable**. Once minted at birth, the rappid never changes.
- **Chain to a parent** via `parent_rappid`. Every rappid except the species root has exactly one parent. Walking `parent_rappid` always terminates at the godfather.
- Are the **basis for ledger traceability**: lineage, attestation, kin-vouching, succession, perpetuity claims.

Think of a rappid as the species' social-security number. Universal. Singular. The unit of accounting for digital biology.

## The format (one format, forever)

```
rappid:v2:<kind>:@<publisher>/<slug>:<hash>@<home_vault_url>
```

| Field | Meaning |
|---|---|
| `rappid:` | Always literal. Identifies this string as a rappid. |
| `v2` | Format version. v2 is the unified format ratified 2026-04-30. There was a draft v1 (UUID-only) era; v2 supersedes it. |
| `<kind>` | What kind of organism this is. Open enumeration; current values: `prototype`, `kernel-variant`, `organism`, `twin`, `swarm`, `rapplication`, `agent`. New kinds may be added as the species evolves (e.g. `android`, `cloud`, `embodied`). |
| `@<publisher>/<slug>` | Namespace. Publisher is the owning brand/entity; slug is the entity name within that publisher. Like a Docker image path. |
| `<hash>` | Stable, immutable identifier. For organisms with cryptographic identity (master keypair): `sha256(master_pubkey_SPKI)[:32]`. For organisms without keypairs (the species root, code variants without keys): a unique stable identifier (UUID-derived or commit-derived). |
| `@<home_vault_url>` | Where the canonical signed records live (or, for code-only organisms, where the repo lives). Network-resolvable. **A discovery hint, not a binding** — per [[Local-First-by-Design]], local copies are authoritative; hosts are transports. |

### Concrete examples

```
rappid:v2:prototype:@rapp/origin:0b635450c04249fbb4b1bdb571044dec@github.com/kody-w/RAPP
                                  └ legacy UUID with dashes stripped, preserved as the species root's stable identifier ┘

rappid:v2:organism:@wildhaven/ai-homes:144d673475618dfbc9710e999e7d2907@github.com/kody-w/wildhaven-ceo
                                       └ sha256 of master pubkey, truncated ┘

rappid:v2:twin:@wildhaven/molly:74f0dc145d9c86decd61fbad53c67f2e@github.com/kody-w/wildhaven-ceo
```

### Why this format

- **Structure beats opacity.** A bare UUID tells you nothing. The structured form tells you (at a glance): kind, publisher, where to look, and how to verify.
- **Cryptographic when possible, conventional when necessary.** Most organisms have master keypairs and the hash is key-derived. The species root and code-only organisms don't yet need keypairs; their hash is conventional but stable. Verifiers can detect which mode applies (organism declares `master_pubkey` in `root.json` or doesn't).
- **Trademark-safe.** "rappid" is claimed in `TRADEMARK.md`. The format is the trademark's canonical expression.

## The species tree

```
rappid:v2:prototype:@rapp/origin:0b6354...@github.com/kody-w/RAPP        ← godfather, parent_rappid: null
        │
        ├── (future) rappid:v2:kernel-variant:@<fork-publisher>/<name>:<hash>@<their-repo>
        │              parent_rappid: rappid:v2:prototype:@rapp/origin:0b6354...
        │
        └── rappid:v2:organism:@wildhaven/ai-homes:144d67...@github.com/kody-w/wildhaven-ceo
                  parent_rappid: rappid:v2:prototype:@rapp/origin:0b6354...
                  │
                  └── rappid:v2:twin:@wildhaven/molly:74f0dc...@github.com/kody-w/wildhaven-ceo
                            parent_rappid: rappid:v2:organism:@wildhaven/ai-homes:144d67...
                            │
                            └── (future) customer organisms, partner AIs, employee twins, etc.
```

There is one tree. Every rappid is a node. Every node except the root has exactly one parent. Walking parent_rappid from any node terminates at the godfather (`@rapp/origin:0b6354...`).

## Digital mitosis — the rappid IS the identity

**Same rappid = same organism. Different rappid = different organism.**

This is the unbreakable rule of digital biology in the RAPP species. The rappid is not a label *attached to* an organism — the rappid IS the organism's identity. Memory is content; the rappid is identity. A complete copy of an organism's bytes, with the same rappid, is the *same organism* expressed in a new place. A complete copy with a *new* rappid is mitosis: a child organism has been born, the parent organism still exists (if its rappid is still alive elsewhere), and the parent_rappid chain records the birth.

### When a rappid stays the same (same organism, multiple expressions)

These operations preserve the organism's identity. The rappid does not change. The same organism is now expressed in more places.

| Operation | Why it preserves identity |
|---|---|
| **Backup and restore on the same machine** | Same memory, same keypair, same rappid → same organism |
| **Twin egg summoned to a new device** (Twin-Patterns parallel-omniscience) | The home device's identity is *lifted* onto the new device; rappid travels intact |
| **Hatching** (kernel update with state preservation) | The brainstem code changes, but the organism's rappid + memory + identity are continuous; same organism in new clothes |
| **Signed `migration` to a new `home_vault_url`** | Hosting changes; the rappid's identity-hash and master keypair are unchanged |
| **Multi-host mirroring of the home vault** | All hosts serve the same signed records under the same rappid; same organism, multiple availability paths |

### When a new rappid is minted (mitosis — a new organism is born)

Any of these operations creates a child organism. The new rappid points at the parent via `parent_rappid`. Both organisms now exist independently from this point forward.

| Operation | Why it constitutes mitosis |
|---|---|
| **Fork the code into a new repo with a new rappid** (Article XXXIV.3 — variant master) | New repo, new rappid → new organism. Original RAPP keeps living; the variant is a child. |
| **Genesis ceremony on a fresh master keypair** | A new keypair → a new identity-hash → a new rappid → a new organism. Even if memory is copied from a parent, the new keypair makes it a child. |
| **Customer takes a Wildhaven-templated AI and rebrands it under their own publisher** | New publisher/slug + new master keypair → new rappid → mitosis. The customer's organism is a child of Wildhaven's. |
| **Re-genesis after master keypair loss** | A new master keypair (the only recovery from total custody failure) → new rappid → new organism. The lost organism is dead; the new organism is its child. |

### The mitosis ceremony

When you intentionally mint a new rappid (mitosis), you are deliberately birthing a new organism. The ceremony:

1. **Generate the child's holocard incantation** (24-word BIP-39 phrase). Each child gets its own.
2. **Derive the child's master / self-signing / user-signing keys** from the incantation.
3. **Compute the child's identity-hash** = `sha256(child_master_pubkey_SPKI)[:32]`.
4. **Mint the child's rappid string** in v2 format with that hash, the chosen kind/publisher/slug, and the child's home_vault_url.
5. **Write the child's signed `root.json`** declaring the child's rappid AND `parent_rappid` pointing to the parent organism's rappid.
6. **(Optional) Write a kin-vouch from the parent's user-signing key** acknowledging the child as kin.
7. **OpenTimestamps the child's root.json** to anchor the birth moment in Bitcoin.

The child organism is now alive and traceable to its parent. The parent organism is unchanged.

### Why this rule matters

- **Identity is durable, not portable as content.** You cannot duplicate an organism by copying its bytes if the rappid stays the same — that's a copy-of-the-same. You cannot transfer an organism to a new owner by changing its rappid — that creates a child, not a transfer. Identity is the rappid.
- **Lineage is tamper-evident.** Every organism's parent_rappid chain is a public record of where it came from. You can't fake your ancestry; the parent's signature on a kin-vouch (or just the timestamped existence of the child's root.json) records the moment of mitosis.
- **Inheritance is meaningful.** A child organism inherits *kind* (often), *behavioral templates* (often, through memory copy), and *trust* (sometimes, via parent's kin-vouch). It does NOT inherit the parent's identity. The parent and child are now independent.
- **The species tree is biological, not bureaucratic.** No rebranding shortcut. No "rename and keep going." A new identity is a new organism, with a parent.

This rule is the foundation for evolutionary accounting: "what did `@rapp/origin` produce, in what generation, and how did each descendant evolve?" Walking the parent_rappid chain answers it. Every organism, ever, anywhere, is a unique node in the species tree, with one parent and zero or more children.

## `parent_rappid` rules

1. **Every rappid except the prototype has exactly one parent.**
2. **The chain is acyclic.** Walking `parent_rappid` from any node must reach the species root in finite steps without revisiting any node.
3. **One parent only.** No multi-parent inheritance. If an organism is influenced by multiple precursors, the canonical parent is whichever it traces operational continuity from. Other influences are recorded via kin-vouches (different concept; see [[The Swarm Estate]]).
4. **Parents may be in any kind.** A `twin` may be a child of an `organism`; an `organism` may be a child of a `prototype`; a `kernel-variant` may be a child of a `prototype`. The kind tells you what the organism IS, not what its parent must be.
5. **Multiple children per parent are allowed.** The tree branches. RAPP can have many variants; Wildhaven can have many kin children.

## How a rappid is declared

### For organisms with a code repo (kernel variants, code-only organisms)

Declare in `rappid.json` at the repo root. Schema: `rapp-rappid/2.0`. The `rappid` field carries the v2-format string.

```json
{
  "schema": "rapp-rappid/2.0",
  "rappid": "rappid:v2:prototype:@rapp/origin:0b635450c04249fbb4b1bdb571044dec@github.com/kody-w/RAPP",
  "parent_rappid": null,
  "parent_repo": null,
  "parent_commit": null,
  "born_at": "2026-05-01T00:00:00Z",
  "name": "rapp",
  "role": "prototype",
  "attestation": null
}
```

### For organisms with cryptographic identity (AI organisms, twins, etc.)

Declare in a signed `root.json` under `blessings/<hash>/` in the home vault:

```json
{
  "alg": "ecdsa-p256",
  "schema": "swarm-estate-record/1.0",
  "kind": "root",
  "rappid": "rappid:v2:organism:@wildhaven/ai-homes:144d67...@github.com/kody-w/wildhaven-ceo",
  "issued_by": "fp:M:...",
  "issued_by_role": "M",
  "payload": {
    "master_pubkey": "<base64 SPKI>",
    "parent_rappid": "rappid:v2:prototype:@rapp/origin:0b6354...@github.com/kody-w/RAPP",
    "self_signing_pubkey": "...",
    "user_signing_pubkey": "...",
    ...
  },
  "signature": "<ECDSA signature over canonical JSON>"
}
```

Both declarations are valid rappid identity records. The first carries no cryptographic backing; the second does. Verifiers handle both: presence of a `master_pubkey` triggers signature verification; absence means the rappid is treated as conventional / unsigned.

## Cryptographic backing — when and how

Per Constitution Articles XXXIV.7 and XXXVI:

- **The species root** (`@rapp/origin`) currently has no master keypair. Its rappid is anchored by convention (the existing UUID, dashes-stripped, preserved in the hash field). A future ceremony may mint a master keypair for RAPP itself; until then, the hash field's stability is sufficient.
- **Code variants** (kernel forks) declare their rappid in `rappid.json`. Cryptographic backing is opt-in via the Article XXXIV.7 attestation envelope (signed by parent's release key).
- **AI organisms, twins, customer estates** mint a master keypair via the holocard incantation ceremony. They declare their rappid in a `root.json` signed by the master key. The hash field is `sha256(master_pubkey_SPKI)[:32]`.

The same rappid format describes all three cases. The verifier inspects which fields are present and applies the appropriate verification.

## What this replaces / supersedes

Before 2026-04-30, two parallel systems briefly coexisted:

1. **`rapp-rappid/1.1`** (Article XXXIV draft) — rappids in `rappid.json` files at repo roots
2. **`rappid:v2:` cryptographic format** (Swarm Estate Protocol draft) — structured rappids for AI organisms with master keypairs

These were merged on 2026-04-30 into the unified v2 format. Existing UUIDs (e.g., the species root's `0b635450-...`) are preserved by being placed in the hash field of the v2-format string (dashes stripped). The schema migrated from `1.1` to `2.0`. **No rappid was lost; every existing rappid has a unique v2-format string.**

## Why one format only

- **No divergence.** Two formats meant tooling, docs, and users had to choose which to use. Choice = bugs. One format eliminates the choice.
- **Unified species tree.** A tree where some nodes are UUIDs and some are structured strings forces traversal logic to handle both. Painful. Bug-prone. One format means traversal is straightforward.
- **Trademark integrity.** "rappid" is a single mark. One canonical format protects the mark.
- **Constitutional ratification.** Article XXXIV (rappid lineage) and Article XXXVI (swarm estate) reference the same format. The constitution declares this is the only format. Future articles may evolve `v2` to `v3`; they will not introduce parallel formats.

## Antipattern: do not split rappid

Going forward — and forever — there is exactly one rappid format. If a future spec wants to add functionality, it does so by:

- Bumping the version (`v2` → `v3`) — clean migration, deprecation of older format with a defined window
- Extending the existing format (new optional fields)
- Adding new kinds (new `<kind>` values)

It does **not** introduce parallel formats. If you find documentation that implies two coexisting "kinds of rappids" or "two formats both valid," that documentation is wrong and should be corrected. The species tree is one tree.

This antipattern protection is ratified in Constitution Article XXXIV and XXXVI explicitly: rappid is one concept, one format, never split.

## Related

- [[The Swarm Estate]] — the cryptographic protocol used by AI organisms with master keypairs (kind: `organism`, `twin`, etc.)
- [[Local-First-by-Design]] — survival model for any rappid (signed records are local-first; hosts are transports)
- [[Decentralized-by-Design]] — full four-layer architecture
- [[Twin-Patterns]] — how one organism runs on N brainstems
- [[The Species DNA Archive — rapp_kernel]] — the kernel's versioned source code archive
- [[Signed Releases and Variant Attestation]] — Article XXXIV.7 cryptographic backing for code variants
- `CONSTITUTION.md` Articles XXXIII (organism), XXXIV (rappid + lineage), XXXV (license stability), XXXVI (swarm estate)
- `TRADEMARK.md` — trademark policy claiming "rappid"

## Provenance

Drafted briefly as a "bridge document" between two formats on 2026-04-30. Rewritten the same evening as the canonical singular spec after the operator clarified that divergence is an antipattern. The species root migrated from raw UUID to v2-format string the same date. Wildhaven AI Homes' parent_rappid updated to reference the v2-format prototype string. All cryptographic signatures re-issued; OpenTimestamps re-anchored.

This is one of the **load-bearing decisions** of the digital-organism era. Once the floodgates open and external variants / customer organisms begin minting their own rappids, this format is what they conform to. Reverting becomes impossible. The decision is taken here, with one format.
