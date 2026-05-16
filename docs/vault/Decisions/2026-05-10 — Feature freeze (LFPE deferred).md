# Feature freeze — Local-First Private Estate (LFPE) deferred

**Date:** 2026-05-10
**Status:** Deferred under feature freeze
**Authority:** operator decision (`feedback_feature_freeze.md` in auto-memory)

## What happened

In a single afternoon a long stream of additions landed on the platform:
the ecosystem viz (260 nodes), an 80-entry prompt ledger, and finally a
draft constitutional amendment (Article XLVIII.7 — Local-First Private
Estate) that would have made the local device the canonical home of the
private estate and reduced the GitHub-private repo to encrypted transport.

The operator named the trap directly: feature overload kills networks
in the cradle. The platform doesn't yet have the regulated-industry
buyers whose objections LFPE was being designed to answer. Building the
spec ahead of those users is anticipatory waste — it would either rot
before the buyers arrived, or worse, become prematurely opinionated
about a problem the actual buyers will frame differently.

## The wedge that's actually being shipped

> "Drop your existing `agent.py` into the Copilot Studio harness and it
> just works."

That's the v0 pitch. Single-file agent contract, hot discovery, tier
portability T1→T2→T3 unmodified. The wider network primitives
(bilateral channels, secret ballots, cross-org ratification, two-tier
estate evolutions) are dormant power, NOT user-facing pitch.

## What's frozen

Three concentric rings:

- **Ring 1 (frozen hard):** kernel, agent contract, Copilot Studio
  harness path, install one-liner URL, slot delimiters, the
  constitution as it stands today.
- **Ring 2 (frozen by default):** public estate, rappid, chain rule,
  Bond Pulse, egg lifecycle, planting, existing organs and senses,
  `pages/`. Bug fixes and polish OK; new schemas/articles/spec docs
  not OK without explicit go.
- **Ring 3 (open, but only if it helps the wedge land):** chat UI for
  first-timers, install experience, Copilot Studio path docs,
  reducing existing surface area.

**Explicitly off the table during the freeze:** new constitutional
articles, new spec docs in `pages/docs/`, new federation primitives,
new estate features, new "while we're here" anything.

## When the freeze lifts

The freeze lifts when the operator says it does. Plausible triggers:
- First paying buyer
- First regulated-industry buyer raising the GitHub-private objection
  (would unfreeze LFPE specifically)
- Deliberate decision that the wedge has landed and additional surface
  area is now warranted

Until then, default to no.

## What was preserved (not built)

The LFPE spec was drafted before the freeze decision. The text is
preserved below verbatim so the thinking isn't lost; if/when the
freeze lifts on this specific feature, this document is the starting
point for ratification rather than a re-derivation.

The spec was NOT committed to `pages/docs/` (that would have made it
a published authority document, contradicting the freeze). It was
NOT registered in `pages/_site/index.json`. No code, no tests, no
schema migration, no constitutional amendment to `CONSTITUTION.md`
was written.

What it would solve, summarized in one paragraph: the current
Article XLVIII makes the private tier of the estate live on a
GitHub-private repo as plaintext. That defends "private from the
public web" but NOT "private from GitHub itself." For regulated
industries (legal, healthcare, financial, defense) the second
threat model is the one that closes deals. LFPE makes the local
device canonical, the cloud mirror cryptographically blind
(ciphertext only, encrypted to the operator's `lfpe_pubkey`),
and bilateral inboxes deliverable async via that same encrypted
mirror. Cloud-side path set reduces to three filenames
(`README.md`, `state.age`, `inbox/<32hex>.age`) — semantic
metadata leak goes to zero by structure.

Five open questions were flagged for ratification review (default
mode, key rotation, multi-device key distribution, custodian
discovery for social recovery, migration deadline) — these stay
open until the spec gets revived.

## The full LFPE draft (preserved)

# LOCAL_FIRST_PRIVATE_ESTATE — The Device Is Canonical (Article XLVIII.7)

> **Schema:** `rapp-private-estate/2.0` · **Status:** Draft (proposed Article XLVIII.7) · **Authority:** this file · **First shipped:** TBD · **Bumps:** `rapp-private-estate/1.0` → `2.0`, `rapp-network-beacon/1.1` → `1.2`, `rapp-recovery-vouch/1.0` (new)

This is the spec for the platform's **local-first private estate (LFPE)**. It does not repeal Article XLVIII; it tightens it. Article XLVIII established the two-tier estate (public + private) and made the private tier mandatory. XLVIII.6 added URL opacity. XLVIII.7 finishes the job: **the private estate's source of truth is the operator's local git repository, not the GitHub-private mirror.** The mirror exists only as encrypted transport.

The goal: an operator's private substance is structurally invisible to GitHub itself, to anyone who compromises GitHub, to anyone GitHub is compelled to surrender data to, and to any future policy change in any cloud git host. The private estate becomes substrate-portable and substrate-blind in one move.

If you are writing a brainstem, an estate agent, a sync engine, a bilateral channel client, a recovery tool, or any code that touches a private estate — this is the contract.

---

## §1 — Why local-first (and why now)

Article XLVIII established that two-tier estates are mandatory. The reasoning was correct: real work needs PII; PII can't live on a public substrate; therefore the private substrate must exist from first install or it never exists.

That spec stopped one move short. It made the GitHub-private repo the canonical home of the private estate. That conflates two distinct threat models:

- **"private from the public web"** — solved by GitHub-private visibility
- **"private from GitHub itself"** — NOT solved, because GitHub holds plaintext

For consumer use cases (personal notes, casual correspondence) the first threat model is enough. For the use cases that actually monetize the platform — regulated industries, cross-org legal/financial/healthcare correspondence, M&A diligence, anything subpoenable — the second threat model is the one that matters. A GitHub admin can read your private repo. A breach of GitHub exposes your private repo. A subpoena to GitHub can extract your private repo without your knowledge. A future GitHub TOS change around content scanning lands first on the contents you most want unscanned.

**XLVIII.7 makes the local device canonical and the cloud mirror cryptographically blind.** GitHub stores ciphertext. Plaintext exists on, and only on, the operator's own machine, under their own git source control, signed by their own release key.

---

## §2 — The boundary (revised)

| Lives where | What |
|---|---|
| **Local canonical** (`~/.brainstem/private-estate/`) | The whole private estate as a plaintext git repository. Source of truth. Audit trail = `git log`. |
| **Cloud mirror** (`<handle>/rapp-estate-private`) | Encrypted blobs only. Never plaintext. Optional. |
| **Public estate** (`<handle>/rapp-estate`) | Unchanged from Article XLVI/XLVII/XLVIII — still raw, still unencrypted, still rappid-resolvable. Adds one new field: `lfpe_pubkey` for envelope encryption. |

**The constitutional move:** the cloud mirror's role flips from "the private estate" to "an encrypted transport endpoint for the private estate." Everything that previously lived in the GitHub-private repo as plaintext now lives there as ciphertext. The operator's local repo is the only place where the data is in the clear.

---

## §3 — The architecture (file layout)

```
LOCAL CANONICAL (the source of truth):
~/.brainstem/private-estate/
├── .git/                          ← full git history; commits signed with operator's
│                                    ed25519 release key (Article XXXIV)
├── meta.json                      ← schema + index pointer
├── inbox/                         ← bilateral letters received (decrypted)
│   └── <opaque-id>.json
├── outbox/                        ← bilateral letters queued for delivery
│   └── <opaque-id>.json
├── ledger/                        ← signed records, decisions, ratifications
│   └── <opaque-id>.json
├── kinds/<HMAC>/<HMAC>.json       ← all other queryable content (XLVIII.6 layout)
└── objects/<sha256>.json          ← content-addressed artifacts (XLVIII.6 layout)

LOCAL KEYS (NEVER published):
~/.brainstem/
├── private-estate-secret          ← per-operator HMAC secret (32 bytes, mode 0600)
├── private-estate-map.json        ← opaque-token ↔ semantic-name table (encrypted)
├── lfpe-key                       ← X25519 encryption private key (32 bytes, mode 0600)
└── lfpe-key.pub                   ← X25519 encryption public key (published below)

CLOUD MIRROR (ciphertext only — what GitHub holds):
<handle>/rapp-estate-private/      ← still a GitHub-private repo for access control
├── README.md                      ← "this repo's contents are encrypted; see lfpe-key.pub"
├── state.age                      ← whole local estate, encrypted to operator's lfpe-key
│                                    (one ciphertext per push — diff or snapshot)
└── inbox/                         ← bilateral letters in transit
    └── <random-32hex>.age         ← each letter encrypted to operator's lfpe-key by sender

PUBLIC ESTATE (unchanged + one field):
<handle>/rapp-estate/
└── .well-known/
    └── rapp-network.json          ← beacon (rapp-network-beacon/1.2)
        ↳ lfpe_pubkey: <base64 X25519 pubkey>          (NEW)
        ↳ lfpe_mode: "mirror" | "local-only" | "hybrid"  (NEW)
        ↳ private_estate_pointer + commitment + count   (existing XLVIII)
```

**Key invariants:**

1. **The local repo IS the audit trail.** Every commit is signed with the operator's existing ed25519 release key. `git log` is the canonical timeline of what happened, when, and authenticated by whom.
2. **The cloud mirror is opaque ciphertext to anyone but the operator.** GitHub stores ciphertext. A GitHub admin reading the repo sees a blob. A subpoena recipient (GitHub) can hand over only ciphertext.
3. **The public estate's `lfpe_pubkey` is the rendezvous point.** Senders write inbox letters encrypted to this key; the operator's brainstem decrypts on pull. Anyone can write into your inbox; only you can read.

---

## §4 — Encryption primitives

XLVIII.7 specifies cryptographic operations, not libraries. Implementations MAY use age, libsodium, NaCl `crypto_box_seal`, or any RFC-compliant equivalent.

| Operation | Primitive | Reference |
|---|---|---|
| Identity (signing) | ed25519 | RFC 8032; existing per Article XXXIV |
| Encryption keypair | X25519 | RFC 7748 |
| Key agreement | X25519 ECDH | RFC 7748 |
| Symmetric AEAD | ChaCha20-Poly1305 | RFC 8439 |
| Envelope format | age stanza format (recommended) | https://age-encryption.org/v1 |
| Hash | SHA-256 | FIPS 180-4 |

**Why these:** ed25519 is already established in the kernel (`rapp_kernel/manifest.json` declares it as preferred). X25519 is the canonical pair for ed25519 in modern crypto suites; age is the cleanest published envelope spec; ChaCha20-Poly1305 is the AEAD with the broadest correct implementation surface. No exotic choices.

**Key derivation:** the X25519 encryption keypair is generated INDEPENDENTLY from the ed25519 signing keypair (separate key material, same operator identity). Conflating signing and encryption keys is a known footgun; XLVIII.7 separates them by spec.

---

## §5 — Sync protocol

### §5.1 Push (local → cloud)

1. Operator commits a change locally. Commit is signed with ed25519 release key.
2. Sync agent computes the new repo state (snapshot of working tree at HEAD, or delta from last pushed state).
3. Sync agent encrypts the state with `age` to the operator's own `lfpe-key.pub`. Output is `state.age` — a single ciphertext blob.
4. Sync agent writes `state.age` into a clone of the cloud mirror, commits with a content-free message ("update"), and pushes.
5. Cloud mirror's git history is a sequence of opaque ciphertext snapshots. The cloud-side commit message is constant; cloud-side commit metadata reveals nothing about the contents.

### §5.2 Pull (cloud → local)

1. Sync agent fetches the cloud mirror.
2. If there's a new `state.age`, decrypt with the operator's `lfpe-key`.
3. Three-way merge between (a) the just-decrypted state, (b) the operator's local working tree, (c) the last known common ancestor.
4. **Conflict resolution rule: local commits always win.** The cloud mirror is a syndication channel, not an authority. If a conflict arises (e.g., another device pushed first), Bond Pulse surfaces the conflict to the operator; cloud cannot silently overwrite local.
5. Process new inbox letters: for each `inbox/<random-id>.age`, decrypt, validate the sender's signature against their published ed25519 key, file into local `inbox/`, then delete the cloud-side file. Inbox letters are write-once-read-once; their cloud lifetime is bounded.

### §5.3 Multi-device coherence

Operators commonly have laptop + desktop + phone. Each device runs its own local canonical. The cloud mirror is the rendezvous:

- Each device pushes its local commits as encrypted snapshots.
- Each device periodically pulls and merges via the protocol above.
- Bond Pulse heartbeats coordinate the rhythm and surface drift.
- The encryption key (`lfpe-key`) MUST be present on every device that participates in this rendezvous. Distribution: per-device generation + cross-signing, OR (Round 1) operator-mediated copy via one-time QR / sneakernet.

---

## §6 — Bilateral inbox (cross-operator delivery)

The killer constraint is async correspondence: A wants to write to B's private estate when B is offline. Three modes, operator-selected:

### §6.1 Mode A — `mirror` (default)

A's brainstem encrypts the letter to B's published `lfpe_pubkey` (read from B's public estate beacon), names the file with a random 32-hex ID (no semantic info), and pushes to `B/rapp-estate-private/inbox/<id>.age`. B's brainstem pulls on next sync, decrypts, files locally, deletes the cloud-side file.

Cloud-side observers see: a write of an opaque ciphertext to an opaque path. They learn nothing about sender, content, topic, or timing-beyond-the-write-timestamp.

### §6.2 Mode B — `local-only`

No cloud mirror exists. A's brainstem holds the letter in A's outbox indefinitely. Delivery happens when both brainstems are simultaneously reachable:
- Both online + in the same shared gate (delivery via gate's bilateral channel)
- Both on the same LAN (delivery via `lan_advertise.py` + direct push)
- Sneakernet (egg cartridge transport per Article XLVII.5)

No async. Maximum sovereignty. For correspondents who refuse cloud at any layer.

### §6.3 Mode C — `hybrid` (per-correspondent)

The operator's `facets.json` declares per-correspondent or per-gate which mode applies. High-trust correspondents (named operators, specific gates) get `local-only`; everyone else gets `mirror`. The operator's brainstem routes outbound letters according to the destination's mode.

### §6.4 What the cloud inbox is NOT

The cloud inbox is **not** a mailbox in the postal sense. It is a transient drop point. Letters land there encrypted, get pulled by the recipient, and get deleted server-side. Nothing should accumulate in `inbox/` longer than one sync cycle. A cloud inbox with 500 unread letters is a brainstem that stopped syncing — it's a liveness signal, not a feature.

---

## §7 — Migration from existing XLVIII estates

Operators with existing `rapp-private-estate/1.0` plaintext private repos migrate via `tools/lfpe_migrate.py`:

1. Generate the operator's X25519 encryption keypair if one doesn't exist.
2. Pull the existing remote private repo into a temp location.
3. For each kind/object/inbox file, re-encode under the new layout in a fresh local canonical at `~/.brainstem/private-estate/`.
4. Compose `state.age` from the new local canonical.
5. **Force-push to clear cloud-side plaintext history** — the previous git history of the private repo contains plaintext blobs that must not survive. This is the only place in the platform where force-push is mandatory rather than forbidden. The migration tool warns the operator explicitly and requires confirmation.
6. Write the new beacon with `lfpe_pubkey` and `lfpe_mode`.
7. Update local `~/.brainstem/private-estate-map.json` and HMAC secret as needed.

Migration is irreversible in the sense that the cloud history of plaintext is gone. Operators retain a local backup of the pre-migration state at `~/.brainstem/.bond/lfpe-pre-migration.tar.gz` (timestamped, kept indefinitely) so the migration is recoverable on the local side if it fails midway.

---

## §8 — Disaster recovery

LFPE explicitly trades cloud-side recoverability for cloud-side privacy. The operator chooses where on the spectrum to land.

| Scenario | Mode = `mirror` | Mode = `local-only` |
|---|---|---|
| Lost laptop, lost `lfpe-key` | Cloud holds ciphertext, no key, no read | Total loss of private substance |
| Lost laptop, key recoverable from second device | Pull from cloud mirror; full restore | Total loss; only the second device has anything |
| Lost laptop, key escrow via trust web (§8.1) | Recover key, then full restore | Recover key, but no cloud to restore from |
| GitHub deplatforms operator | Lose mirror; local canonical unchanged | No effect |
| GitHub gets subpoenaed for operator's content | Hands over ciphertext | Nothing to hand over |
| Forensic seizure of unlocked laptop with full-disk encryption disabled | Total exposure | Total exposure |

LFPE is one layer. Operators handling regulated content combine it with full-disk encryption at the OS level (FileVault, BitLocker, LUKS) and physical security of the device itself.

### §8.1 Social key recovery (`rapp-recovery-vouch/1.0`)

Optional opt-in. Operator splits their `lfpe-key` into N Shamir shares with threshold M, distributes shares to N trusted operators in their web of trust. Each share is itself encrypted to its custodian's `lfpe_pubkey`. Custodians don't know what they hold; they can't decrypt their own share without the protocol.

Recovery: operator (or operator's designated heir) requests shares from custodians via signed inbox letters. Custodians' brainstems verify the request signature, surface the request to the human custodian for approval, and on approval drop the share into the requestor's inbox. M of N shares received → key reconstructed → estate recovered.

This is the spec-level realization of prompt #62 ("Social recovery via trust web") in `pages/about/prompts.json`. The trust web becomes the recovery mechanism. No support ticket, no centralized password reset, no "verify your identity" upload.

---

## §9 — What XLVIII.6 (URL opacity) becomes under XLVIII.7

XLVIII.6 was load-bearing in the plaintext model: paths leak metadata even when content is gated. Under XLVIII.7 the cloud-side paths are reduced to two fixed shapes:

```
^(README\.md|state\.age|inbox/[a-f0-9]{32}\.age)$
```

That's it. The full opacity regex of XLVIII.6 still applies to the LOCAL canonical (where opaque kind/object paths are useful for `git log` clarity without leaking semantic info to anyone who pulls a git fork). Cloud-side opacity is now structural — nothing semantic CAN be there because everything is one of three filenames.

The validation tool `tools/path_opacity.py` gains a second mode (`--lfpe-cloud`) that audits the cloud mirror against this stricter regex. The publish-time invariant (XLVIII.4.4) refuses to push if any file outside the regex is present.

---

## §10 — Beacon changes (`rapp-network-beacon/1.2`)

The public beacon adds two new fields:

- `lfpe_pubkey` — base64 X25519 public key. Required if `lfpe_mode != "local-only"`. Senders read this to encrypt inbox letters.
- `lfpe_mode` — one of `"mirror"`, `"local-only"`, `"hybrid"`. Tells correspondents which delivery mode this operator accepts.

The beacon CANNOT contain (in addition to all XLVIII.5 prohibitions):

- The operator's `lfpe-key` private half. (Obvious, but worth stating.)
- Any custodian rappids from the social recovery quorum (knowing who holds shares is itself an attack surface).
- Any inbox URL beyond the well-known `inbox/` directory under `private_estate_pointer`.

Beacon schema bumps from `1.1` → `1.2`. Older sniffers continue to function but ignore the new fields; older brainstems can't deliver to LFPE inboxes (they don't know to encrypt). The transition window is documented in `VERSIONS.md`.

---

## §11 — Threat model

**LFPE defends against:**

- A GitHub administrator reading the private repo. Sees ciphertext only.
- A breach of GitHub. Attacker exfiltrates ciphertext, no key.
- A subpoena served to GitHub for the operator's private content. GitHub hands over ciphertext.
- A future GitHub TOS change around content scanning of private repos. Scanner sees ciphertext.
- A migration to a different cloud git host (GitLab, Codeberg, Forgejo). The encrypted blob is portable.
- A second-party leak (a collaborator on the private repo accidentally exposes it). Without the key, exposure of ciphertext is not exposure of content.

**LFPE does NOT defend against:**

- Malware running on the operator's laptop with access to `~/.brainstem/`.
- Forensic seizure of an unlocked laptop with disk encryption disabled.
- A coerced operator who decrypts their own state under duress.
- A weak choice of OS-level keychain protection for `lfpe-key`.
- An out-of-band leak of the encryption key itself.

**Defense-in-depth:** LFPE assumes the operator runs full-disk encryption at the OS layer (FileVault/BitLocker/LUKS), uses a strong account password, and keeps physical custody of their device. LFPE is the layer that matters when those defenses fail at the cloud boundary; it does not replace those defenses.

---

## §12 — Conformance

New gate: `tests/features/F16-lfpe.sh`. The gate verifies:

1. The cloud mirror's tree matches `^(README\.md|state\.age|inbox/[a-f0-9]{32}\.age)$` exactly.
2. `state.age` decrypts with the operator's `lfpe-key` and round-trips losslessly to the local canonical.
3. An inbox letter encrypted by another operator to this operator's `lfpe_pubkey` is correctly decrypted, signature-verified, filed locally, and deleted from the cloud.
4. `lfpe-key` file mode is `0600` and the file is not present in any committed tree (local OR cloud).
5. The `lfpe-key` private half does not appear in any agent log, beacon field, brainstem console output, error message, or process argument list (constitutionally enforced).
6. Beacon fields `lfpe_pubkey` and `lfpe_mode` are present and well-formed when `lfpe_mode != "local-only"`.
7. The publish-time invariant refuses pushes that violate the cloud-side opacity regex.
8. Migration from a `rapp-private-estate/1.0` estate produces a valid `2.0` estate; no plaintext from the original survives in the post-migration cloud history.
9. Conflict resolution: when local and cloud diverge, local wins; cloud cannot silently overwrite local.
10. Multi-device sync: two devices with the same `lfpe-key` converge to the same local canonical state via push/pull/merge.

The gate is added to `tests/osi/run.sh` as a required step. CI green requires F16 green.

---

## §13 — What XLVIII.7 does NOT change

To be explicit about what stays:

- **Article XLVIII still applies.** Two-tier estate is still mandatory from first install. LFPE doesn't repeal it; it tightens the private tier.
- **Article XLVI (rappid-as-URL) still applies.** Public estate URLs derive purely from the rappid. Chain rule federation walks via raw fetches.
- **Article XLVII (substrate federation) still applies.** Public estate can move between substrates; LFPE makes this even cleaner because the cloud mirror's contents are substrate-blind ciphertext.
- **Article XXXIV (signed releases / variant attestation) still applies.** The same ed25519 keys sign git commits in the local canonical and sign release manifests.
- **Bilateral channel is still bilateral.** XLVIII.7 just makes it end-to-end encrypted by spec rather than by convention.
- **The agent contract is unchanged.** No agent code needs to know LFPE exists; it's a substrate-layer concern handled by the brainstem and the sync engine.

---

## §14 — Open questions (for ratification review)

These are flagged for explicit decision before XLVIII.7 ratifies:

1. **Default mode.** Ship `mirror` (best UX, requires cloud) or `local-only` (best privacy, async correspondence breaks)? Recommendation: `mirror` default with an install-time prompt offering `local-only` for operators who know they want it.
2. **Key rotation.** How does an operator rotate `lfpe-key` after suspected compromise? Spec sketch: publish new pubkey in beacon, re-encrypt local state to new key, force-push new `state.age`, keep old key around to read still-undelivered inbox letters for a grace period.
3. **Multi-device key distribution.** Per-device keypairs with cross-signing (more secure, more complexity), or shared key replicated via QR / sneakernet at install (simpler, single point of failure)? Recommendation: shared key for v1, per-device for v2 once the substrate is mature.
4. **Custodian discovery for §8.1.** How does the operator pick custodians? Manual selection from trust web, or algorithmic suggestion based on existing membership patterns? Recommendation: manual for v1; algorithmic suggestions as a non-binding hint.
5. **Migration deadline.** How long do `rapp-private-estate/1.0` estates remain valid before federation walkers refuse to deliver to them? Recommendation: 18 months from XLVIII.7 ratification.

---

## §15 — Constitutional amendment text (for CONSTITUTION.md)

Proposed addition to Article XLVIII, immediately after XLVIII.6:

> **XLVIII.7 — The Local Device Is Canonical.** The private estate's source of truth is the operator's local git repository at `~/.brainstem/private-estate/`. The GitHub-private mirror at `<handle>/rapp-estate-private` exists only as encrypted transport; it stores ciphertext, never plaintext. Operators MAY operate fully without a cloud mirror (`lfpe_mode = "local-only"`); operators who use a mirror MUST encrypt all cloud-side content to their published `lfpe_pubkey` before pushing. The cloud-side path set is restricted to `README.md`, `state.age`, and `inbox/<random-32hex>.age` — no other paths permitted. Authority for the spec: `pages/docs/LOCAL_FIRST_PRIVATE_ESTATE.md`. Conformance gate: `tests/features/F16-lfpe.sh`. Bumps `rapp-private-estate/1.0` → `2.0` and `rapp-network-beacon/1.1` → `1.2`.
