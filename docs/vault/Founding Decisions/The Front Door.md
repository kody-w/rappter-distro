---
title: The Front Door
status: published
section: Founding Decisions
hook: A planted RAPP mirror is its operator's AI's front door on the public internet — claimed real estate, owned forever, customizable behind the threshold. "Mirror" is the technical contract; "Front Door" is what it means to the human who plants one. Both names live, used in different rooms.
---

# The Front Door

> **Hook.** A planted RAPP mirror is its operator's AI's front door on the public internet — claimed real estate, owned forever, customizable behind the threshold. "Mirror" is the technical contract; "Front Door" is what it means to the human who plants one. Both names live, used in different rooms.

## The decision

When a person publishes a kernel-compliant mirror to the network — running `plant.sh` to push a fresh repo to GitHub Pages — they are not "installing software." They are putting up their AI's *front door* on the global internet. That phrase is the platform's user-facing language for this artifact, and it is load-bearing.

The technical name for the same artifact is **mirror** — defined in [[Mirror Spec]]. *Mirror* is precise: byte-identical kernel files plus a thin installer wrapper, anything else customizable. *Mirror* is what auditors, contributors, and the drift-check command care about.

*Front Door* is what the operator cares about. Their address. Their threshold. Their visible space on the public network. The same artifact, two readings, both real.

This note is the second reading — the human one.

## Why we chose this framing

For most of computing history, the metaphors have been mechanical: install, deploy, configure, host, instance. Those words describe what the computer does. They do not describe what the human gets. For a network whose dominant adoption motion is *individuals choosing to publish their own AI in public*, mechanical metaphors leave the meaning on the table.

Real-estate metaphors carry the weight that mechanical ones don't:

- A front door is **owned.** It does not expire when a vendor pivots. The kernel discipline guarantees this — see [[Mirror Spec]] for why a kernel-compliant front door cannot be deprecated by the maintainers.
- A front door has a **threshold.** The operator decides who crosses it, what they see, what is said.
- A front door **gets better with time.** Decoration accumulates. A year-five front door is richer than a year-one front door. The single-file agent contract makes additions trivial — see [[The Single-File Agent Bet]].
- A front door has **neighbors.** Mirrors form a network; mirrors find each other; the city of front doors is the platform's social fabric.
- A front door is **flexibly public.** A personal home, a storefront, a museum, a public kiosk, a memorial — the same primitive, the operator's choice.

"Mirror" tells you what the machine is. "Front Door" tells you why a person walks toward planting one.

## The metaphor stack

The metaphor extends cleanly across what the platform already does:

| Concept | Front-door reading |
|---|---|
| Frozen kernel | Building code / structural spec — same in every house, never changes |
| The mirror's `installer/install.sh` | The deed-and-permit chain that proves the foundation is to code |
| Planting (`plant.sh`) | Putting up the door, claiming the lot |
| The mirror's `agents/` directory | The furnishings inside — what visitors see |
| `soul.md` | The house's vibe; how the door greets you |
| Twins | Family, pets, lodgers — characters living inside |
| Rappid (UUIDv4) | The deed / property ID |
| GitHub handle + URL | Mailing address |
| Display name | Name on the mailbox |
| QR scan | Knocking at the door |
| Tether (WebRTC) | Having someone over |
| Neighborhood swarm | The street / the block |
| Place-brainstem at a venue | Public buildings — cafés, libraries, museums |
| The egg hub | The community bulletin board |
| Collected eggs | Gifts left on the stoop / souvenirs from a visit |
| `?from=<other-mirror>` lineage | "We were neighbors; she helped me move in" |

Every primitive maps. Engineers can ignore the right column; humans can lean on it.

## What it means to plant a front door

`plant.sh` is the act. In about a minute it:

1. Pulls the canonical kernel from the grail (per [[Mirror Spec]]).
2. Wraps the kernel in the operator's chosen identity — slug, display name, freshly-minted rappid.
3. Creates a public GitHub repo and enables Pages.
4. Returns one URL: the operator's new address.

That URL is not a temporary instance. It is a claimed location on the public internet, kernel-compliant by structural fact, owned by whoever holds the GitHub handle. The platform makes no claim on it. The maintainers cannot revoke it. Other mirrors cannot displace it. The operator can rename, redirect, or relocate it; the kernel discipline keeps any move valid.

When someone says *I have a front door at `<their-name>.github.io/<their-mirror>`*, they are describing real estate, not a SaaS account.

## What lives behind the door

Kernel files are non-negotiable; everything else is the operator's. What they put behind the door is what visitors find:

- **`agents/`** — the operator's chosen agents. Twins, services, capabilities, place-knowledge, whatever they want available to anyone who walks in. These are the furnishings.
- **`soul.md`** — the system prompt the front door's twins greet visitors with. The vibe. The voice. The opinions.
- **UI surfaces** — `index.html`, twin chat surfaces, custom views. Decoration on the walls.
- **Twins** — the named characters that live in the house. Visitors can chat with them.
- **Optional place metadata** — if this front door is at a real-world venue, location info that makes it a POI on the network's map.

None of this is mandatory. A blank front door is a valid front door — just an entryway with the kernel running and nothing customized. Some operators will keep theirs sparse; others will fill them with a hundred agents. Both are fine.

## How visitors arrive

A visitor finds a front door three ways:

- **By URL.** Someone shared the link directly. Visitors paste the address in a browser.
- **By QR.** A planter prints a QR or shows it on a screen. Anyone scans to arrive.
- **By neighborhood.** A visitor at one front door discovers another via a `.well-known` file each mirror publishes naming related or nearby front doors.

Crossing the threshold means landing on the mirror's `index.html` (or the operator's chosen entry surface). What's there is what the operator chose to show. Visitors can chat with twins, browse agents, collect eggs, or leave something behind. The threshold is the point of consent — the operator decides what's public on the other side.

## Identity at the front door

A front door has three identity layers, identical in shape to a twin's identity:

- **Slug** — `[a-z0-9-_]+`, lives in the URL. `corner-coffee`, `alice-mirror`, `daily-pulse`.
- **Display name** — what visitors see. "Corner Coffee — Capitol Hill", "Alice's Front Door", "The Daily Pulse".
- **Rappid** — UUIDv4, minted once at plant time, never regenerated. The deed. Used by machine-internal references, lineage chains, future cryptographic attestation.

Plus, by virtue of where the repo lives:

- **GitHub handle + repo name** — the mailing address. `<github>.github.io/<repo>`. This is what people will reference each other by in practice, the same way packages get referenced on npm.

The four layers do not compete; they layer. Engineers and machines use the rappid. Humans say the display name. URLs use the slug. Same front door, four readings.

## Front doors at venues — place-brainstems

A planted front door does not have to be a person's. The same `plant.sh` flow produces:

- A personal front door for an individual's AI.
- A storefront front door for a small business's AI.
- A public-building front door for a venue — café, library, museum, hotel lobby, conference badge.
- A memorial front door for someone who has passed.
- A project front door for an initiative that outlives any specific contributor.

When the front door is anchored to a real-world location, it becomes a **place-brainstem** — a node on the network's map at fixed coordinates. Visitors at the physical venue scan the QR sticker by the door, walk through the digital threshold, and find whatever the venue's operator has chosen to place there. The `kind: place` flag in `rappid.json` plus optional `location` metadata is all that distinguishes a place-front-door from a personal one.

The platform did not invent place-anchored AI; it just makes the act of planting one as cheap as planting a personal one.

## Devices that light up the network

A front door is reachable from any device that speaks the network's protocols. The kernel runs natively on full-power hosts (Mac, PC, Linux, Pi). It runs in WebAssembly via Pyodide on phones, tablets, and any modern browser. Watches, speakers, TVs, AR surfaces are *surfaces* of front doors — they speak the chat protocol over the network without hosting the kernel themselves.

This means the network "lights up" device by device as people install:

- Phone, tablet, laptop, desktop → the PWA *is* the front door, web-only, no app store.
- Always-on small computers at venues → place-brainstems with public-facing front doors.
- Wearables and ambient devices (watches, speakers, TVs, CarPlay) → surfaces that dial in to a paired host's front door.
- AR / spatial computing → spatial overlay of the visible front-door network.

Every device added is one more light on the map. The kernel discipline ensures that the front door at every light is the same building under the hood.

## Gifts on the stoop — eggs as souvenirs

When a visitor crosses a front door's threshold and collects an egg — a single-file agent or a twin — the collection is stamped with where it came from and when. Visitors can attach a story: why they were there, what mattered. The egg in their binder afterward carries the address, the date, and the meaning.

This makes eggs the souvenir layer of the network. Collected eggs are gifts visitors picked up at front doors they walked through. Operators choose what to leave on the stoop. The whole layer is metadata on top of the existing egg/sidecar/binder primitives — adjacent to [[Federation via RAR]].

Over time, a person's binder reads like a passport. Each egg knows where it came from and what was happening when it landed there. The platform turns out to have a sentimental layer almost by accident — because real estate has been the substrate from the beginning.

## What this is NOT

A front door is not:

- A **SaaS account.** No vendor controls it. No T&Cs revoke it.
- A **rental.** GitHub serves it for free; if GitHub disappears, the same files publish to any static host.
- A **profile.** Profiles describe their owner; front doors describe a place visitors enter.
- A **social media handle.** Handles are unique within one platform; front doors are unique URLs across the entire public internet.
- A **CDN-style mirror.** Replication mirrors all serve the same content; front-door "mirrors" each serve their operator's own.

It is one thing only: the operator's claimed real estate on the public internet, kernel-compliant by structural fact, theirs in every sense the word usually implies.

## When the front-door framing is wrong

This metaphor is a poor fit if:

- The operator wants something **transient** — a temporary instance, a scratch deployment, a build server. Use raw infrastructure tools for those; don't burn a front door.
- The operator wants **anonymous shared use** — many users on one shared brainstem with no notion of "whose door this is." A multi-tenant SaaS would handle that better; the front-door model assumes a single owner.
- The operator wants **vendor accountability** — someone to call when it breaks. The front-door model gives the operator full ownership *and* full responsibility. If they want a service contract, this is the wrong shape.

For everyone else — anyone who wants their AI's presence on the public internet to be *theirs* — the front door is the primitive.

## See also

- [[Mirror Spec]] — the technical contract behind every valid front door.
- [[The Engine Stays Small]] — the kernel-discipline manifesto that makes durable real-estate possible.
- [[The Single-File Agent Bet]] — why what's behind your door is easy to add to.
- [[Engine, Not Experience]] — the founding stance that gives the operator full control of the experience layer.
- [[Federation via RAR]] — the trust shape closest to how front-door networks compose.
- [[The Sacred Constraints]] — Constraint #4 ("Brainstem stays light") makes the front-door discipline enforceable.
- [[Roots Are Public Surfaces]] — adjacent: why the platform's surfaces live on the public internet by default.
