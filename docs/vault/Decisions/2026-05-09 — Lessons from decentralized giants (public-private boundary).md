---
title: Lessons from decentralized giants — the public/private boundary (Article XLVIII)
date: 2026-05-09
status: shipped
authority: pages/docs/PUBLIC_PRIVATE_BOUNDARY.md, CONSTITUTION Article XLVIII
tags: [article-xlviii, two-tier-estate, url-opacity, private-substance, federation-lessons]
---

# Lessons from decentralized giants — the public/private boundary

## What we shipped

Article XLVIII, constitutionalizing:

- **The two-tier estate is mandatory from first install.** Every operator gets BOTH `<handle>/rapp-estate` (public) AND `<handle>/rapp-estate-private` (private GitHub repo). No opt-in. The boundary is structural, not policy.
- **The public beacon commits to private state without leaking it.** `rapp-network-beacon/1.1` carries REQUIRED `private_estate_pointer` + `private_estate_commitment` (sha256) + `private_door_count`. Bitcoin-commitment pattern.
- **The URL space is opaque (XLVIII.6).** Every path inside the private repo is HMAC'd or content-addressed. A 404 to an unauthorized viewer reveals nothing about what would have been there. URLs themselves stop being metadata.
- **Receiver controls (XLVIII.4).** Senders propose to public surfaces; receivers verify and MOVE accepted content to private. No automatic flow ever crosses tiers.
- **No cross-tier smuggling (XLVIII.5).** The brainstem MUST NOT publish private content to the public estate without explicit operator action.

The shift is fundamental: the platform's promise to operators handling sensitive work — doctors, lawyers, therapists, families coordinating PII, professional networks with confidential members — is now structurally honored. Public-only mode is "legacy" (pre-XLVIII); the new floor is two-tier with opaque paths.

## Why this needed to be constitutional

Three operator framings drove it:

1. *"the mailbox one above... would need a private layer to be useful and not just a public toy."*
2. *"each estate from the start should have this public/private layer as a REQUIREMENT so this is useful beyond public interactions that everyone can see (not very useful for real work)."*
3. *"where even public links to the private repo are completely unusable to gather any information about the private data just by reading the static url even if the user doesn't have private repo access they can still see the static link that 404s and use that to gather context of what is being reached in the private repo. all of this needs to be dealt with."*

Each one is a DIFFERENT load-bearing concern that earlier drafts missed:

- (1) The federation primitives that need privacy (Inbox, Bilateral Channel, etc.) are toys without it.
- (2) Optional private = nobody migrates = leak PII when real work happens.
- (3) Even with access-gated content, the URL space itself leaks metadata. The 404 is a side channel.

## Lessons from giants (synthesized)

### Identity ≠ Address ≠ Content (Tor / hidden services)

Tor's lesson: separate the three. Onion service v2 → v3 was specifically about address leakage — hashing the public key into the address rather than carrying it directly. The lesson for RAPP: the operator's rappid is identity; the estate URL is address; the private estate is content. Three layers, three repos. Each layer can change independently.

### URL space leaks even when content doesn't (Tor onion v3 + Signal sealed sender)

Tor onion v3 made addresses opaque against descriptor enumeration. Signal sealed sender hides who sent the message even when content is encrypted. RAPP applies the same insight: a URL like `<handle>/rapp-estate-private/main/mailbox/inbox/dr-jones-oncology/2026-05-09-test-results.json` reveals (just by existing in any system that touches it) that the operator receives correspondence from dr-jones-oncology dated 2026-05-09 about test results — even if a viewer hits 404. So XLVIII.6 forbids semantic paths inside the private repo. The HMAC pattern (`kinds/<HMAC(secret,kind)>/<HMAC(secret,id)>.json`) makes the URL itself meaningless without the operator's per-install secret.

### Audience as a first-class field (ActivityPub / Fediverse)

ActivityPub's `to:`, `cc:`, `bcc:` fields treat audience as data, not implicit. Every Activity says who it's for. RAPP's audience field has two values in Round 1 (`public` lives in public estate, `private` lives in private estate); future rounds can add `followers`, `members-of-X-gate`, etc. The shift is treating audience as something the operator declares, not something that's implicitly all-or-nothing.

### Sign early — bolting on auth is painful (DKIM / DMARC)

Email had decades to add DKIM, DMARC, SPF. The lessons: bolt-on auth is harder than designed-in. RAPP's beacon includes the operator's signing-key reference from day 1 (forward-compatible; even if E2E encryption is Round 2, the substrate accepts it). Round 1 uses GitHub's collaborator perms as the access mechanism; Round 2 will layer cryptographic signatures + per-thread encryption keys. The substrate is ready.

### Public proofs of private facts (Bitcoin commitments)

A Merkle root commits to every transaction in a block without revealing any. RAPP's beacon carries `private_estate_commitment` — sha256 of the private estate's normalized state — proving the operator has SOME private state and that it's bit-for-bit consistent with what they've committed to, without revealing what. Peers with read access can re-compute and verify the operator hasn't substituted a different private estate behind their back. Operators without read access still benefit from the commitment as integrity proof.

### Own your data; everything else is mirror (IndieWeb / POSSE)

POSSE: Publish (on your) Own Site, Syndicate Elsewhere. RAPP: the operator's local brainstem is the source; both estates are mirrors of locally-owned content. The platform doesn't host the content; it provides the substrate for publishing. Round 1's GitHub-native access model means the operator's GitHub account IS their canonical home; if they ever leave RAPP, the repos remain.

### Per-room (per-thread) access control (Matrix)

Matrix encrypts per room; servers can be compromised but rooms aren't. RAPP's CODEOWNERS-per-folder hint at per-thread access (Round 2 will formalize). The principle: access is granular; no single key compromises everything.

### Receiver controls (Webmention / IndieWeb)

Webmention: the sender notifies; the receiver verifies + decides whether to render. RAPP applies this to the public-private boundary: senders propose to public surfaces (their own outbox, then PR to the recipient's public mailbox); receivers verify, MOVE accepted content to private, optionally delete the public copy. No automatic ingestion. No surprise inbound.

### Multi-root tolerance (DNS + DHT)

DNS has alt-roots; DHTs (Kademlia) have multiple bootstrap nodes. RAPP's federation seed is convenient but not authoritative — anyone can fork the species root and host their own seed (Article XLVII.4). Removing any single repo, including kody-w/RAPP, doesn't partition the network. The same multi-root tolerance applies to private extensions: an operator's private estate can be mirrored to multiple operator-controlled URLs; the beacon picks the canonical one but redundancy is operator-controlled.

### Trust must be explicit (BGP — negative example)

BGP's default-trust caused the YouTube hijack incidents and many others. The lesson: trust must be explicit. RAPP's audience field is explicit per entry; the public/private boundary is explicit (XLVIII.5 forbids cross-tier smuggling); the consent flag in the beacon (`discovery.indexable`) is explicit. No defaults that silently expose content.

## What this enables (the federation primitives become real)

Round 1 establishes the substrate. The 8 primitives that need privacy become 30-minute follow-up builds:

1. **The Inbox.** Public-mailbox-public for proposals; private mailbox for accepted mail. Spam stays public + ignored; real mail lands private + processed.
2. **The Bilateral Channel.** `<a>/rapp-estate-private/kinds/<HMAC>/<HMAC>.json` per thread; both operators have collaborator access; URLs opaque to anyone else.
3. **Web of Trust private signals.** Trust signatures live in private; the public beacon commits to their existence + count without enumerating who's trusted.
4. **Presence opt-in.** Public beacon declares "I'm online" boolean; per-contact resolution (who's online to whom) lives private.
5. **Vote ledger secret-ballot mode.** Commit hash to public; ballot sealed in private; reveal at deadline.
6. **The Witness Cache for private content (Round 2).** Requires cryptographic redaction; not in this round but the substrate supports it.
7. **The Mirror Net for private content.** Operator-controlled mirrors of their OWN private content (cross-machine backup); peer-mirrors require key exchange (Round 2).
8. **Federated Schema Bazaar with private capabilities.** The beacon declares which schemas the operator implements; private extensions can declare additional capabilities only visible to authorized peers.

## The headline

**Public discovery, private substance, opaque URLs.** Three load-bearing constitutional facts. Together they make the platform usable for real work without sacrificing the decentralized discovery surface that makes it valuable.

The boundary is not optional. The URLs are not metadata. The private repo is not for advanced users. From day one — every operator, every estate, every URL — the substrate for sensitive work is in place.

---

## Cross-references

- Spec: [`pages/docs/PUBLIC_PRIVATE_BOUNDARY.md`](../../docs/PUBLIC_PRIVATE_BOUNDARY.md)
- Constitution: [`CONSTITUTION.md`](../../../CONSTITUTION.md) Article XLVIII
- God spec: [`specs/SPEC.md`](../../../specs/SPEC.md) §4.7
- Path opacity helper: [`tools/path_opacity.py`](../../../tools/path_opacity.py)
- Private estate init: [`tools/private_estate_init.py`](../../../tools/private_estate_init.py)
- Estate agent (init_private/verify_private): [`rapp_brainstem/agents/estate_agent.py`](../../../rapp_brainstem/agents/estate_agent.py)
- Sniffer (XLVIII surfacing): [`tools/sniff_network.py`](../../../tools/sniff_network.py)
- Conformance: [`tests/features/F15-private-estate.sh`](../../../tests/features/F15-private-estate.sh) (10 steps)
- Companion vault notes:
  - [`2026-05-09 — Estate Spec — rappid as global address`](2026-05-09%20%E2%80%94%20Estate%20Spec%20%E2%80%94%20rappid%20as%20global%20address.md) — the address layer (XLVI)
  - [`2026-05-09 — Bond Pulse — the on-going beat for the full organism`](2026-05-09%20%E2%80%94%20Bond%20Pulse%20%E2%80%94%20the%20on-going%20beat%20for%20the%20full%20organism.md) — the heartbeat
