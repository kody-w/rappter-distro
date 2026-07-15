"""import_peer_egg — sneakernet federation (Article XLVII.5.3).

Per the Charizard use case (HERO_USECASE.md): two devices with no shared
network at all, just exchanging files (USB stick, link cable, SD card,
QR-paired Bluetooth, paper printout someone OCRs, etc.).

This script takes an egg received via any non-network medium, extracts
it to a known location under ~/.brainstem/peers/<handle>/, and adds a
file:// federation hint to ~/.brainstem/network-seed.json so the
operator's sniffer (--via raw --seed-url file://~/.brainstem/network-seed.json)
walks the imported peer as a real federated node.

Asynchronous + symmetric:
  Device A packs egg-A → sneakernet → Device B  →  B imports egg-A
  Device B packs egg-B → sneakernet → Device A  →  A imports egg-B
  Both operators now have each other in their local seed; sniff sees both.

Each egg is a STATIC snapshot of the peer at pack time. Refresh by
exchanging fresh eggs. The sniff record's `substrate` will read `file`,
so consumers know it's a snapshot vs. live LAN/github data.

USAGE:
    python3 tools/import_peer_egg.py <path-to-egg>
    python3 tools/import_peer_egg.py <path-to-egg> --seed ~/.brainstem/network-seed.json

Stdlib only.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import zipfile
from pathlib import Path


_BRAINSTEM_DIR = Path(os.path.expanduser("~/.brainstem"))
_PEERS_DIR     = _BRAINSTEM_DIR / "peers"
_SEED_PATH     = _BRAINSTEM_DIR / "network-seed.json"

_BEACON_PATH = ".well-known/rapp-network.json"


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def import_egg(egg_path: str, seed_path: Path = _SEED_PATH) -> dict:
    """Extract the egg + register the peer in the local seed file.

    Returns a result envelope. Idempotent: re-importing the same handle
    overwrites the extracted dir + refreshes the seed entry.
    """
    egg = Path(os.path.expanduser(egg_path))
    if not egg.exists() or not egg.is_file():
        return {"ok": False, "error": f"egg not found: {egg}"}
    if not zipfile.is_zipfile(egg):
        return {"ok": False, "error": f"{egg} is not a valid zip-format egg"}

    # Read manifest + identity FIRST, before extracting (so a bogus egg
    # doesn't pollute the peers/ directory)
    with zipfile.ZipFile(egg) as z:
        names = z.namelist()
        if "manifest.json" not in names:
            return {"ok": False, "error": "egg missing manifest.json"}
        try:
            manifest = json.loads(z.read("manifest.json"))
        except Exception as e:
            return {"ok": False, "error": f"manifest.json malformed: {e}"}

        if not str(manifest.get("schema", "")).startswith("brainstem-egg/"):
            return {"ok": False, "error": f"unsupported schema: {manifest.get('schema')}"}

        if "rappid.json" not in names:
            return {"ok": False, "error": "egg missing rappid.json (no operator identity to import)"}
        try:
            rappid_meta = json.loads(z.read("rappid.json"))
        except Exception as e:
            return {"ok": False, "error": f"rappid.json malformed: {e}"}

        rappid = rappid_meta.get("rappid", "")
        if ":@" not in rappid:
            return {"ok": False, "error": f"egg's rappid.json has no self-locating rappid: {rappid[:60]}"}

        # Derive the peer's handle from the rappid. The self-locating segment is
        # `:@<owner>/<slug>` in the canonical form (spec §6.1); stdlib-only inline
        # parse (Article XLVI parser would be nicer but this must stay dep-free).
        try:
            handle = rappid.split(":@", 1)[1].split("/", 1)[0]
        except Exception:
            return {"ok": False, "error": f"could not derive handle from rappid: {rappid[:60]}"}

        # Extract to peers/<handle>/
        dest = _PEERS_DIR / handle
        dest.mkdir(parents=True, exist_ok=True)
        # Wipe existing extraction (idempotent) — do it carefully
        if dest.exists() and any(dest.iterdir()):
            for child in dest.rglob("*"):
                if child.is_file() or child.is_symlink():
                    try:
                        child.unlink()
                    except Exception:
                        pass
            for child in sorted(dest.rglob("*"), reverse=True):
                if child.is_dir():
                    try:
                        child.rmdir()
                    except Exception:
                        pass

        z.extractall(dest)

    # Confirm beacon exists in the extracted content
    beacon_in_egg = dest / _BEACON_PATH
    if not beacon_in_egg.exists():
        # Some eggs only have rappid.json; synthesize a minimal beacon so
        # the federation walker can include this peer
        well_known = dest / ".well-known"
        well_known.mkdir(exist_ok=True)
        synthesized = {
            "schema":          "rapp-network-beacon/1.1",
            "operator_rappid": rappid,
            "github":          handle,
            "estate_url":      f"file://{(dest / 'estate.json').resolve()}",
            "grail_url":       "",
            "protocol": {
                "spec_version":  "rapp-protocol/1.0",
                "estate_schema": "rapp-estate/1.1",
                "implements":    manifest.get("implements", []),
            },
            "discovery": {
                "indexable":         True,
                "consent":           "sneakernet-import-ok",
                "federation_hints": [],
                "_note":             "Synthesized at import time from egg rappid.json (no .well-known/ in egg).",
            },
            "private_estate_pointer":   "",
            "private_estate_commitment": "",
            "private_door_count":       0,
            "minted_at":                _now_iso(),
        }
        beacon_in_egg.write_text(json.dumps(synthesized, indent=2))
        beacon_was_synthesized = True
    else:
        beacon_was_synthesized = False

    # Build the file:// URLs the seed will reference
    beacon_url = f"file://{beacon_in_egg.resolve()}"
    estate_path = dest / "estate.json"
    estate_url  = f"file://{estate_path.resolve()}" if estate_path.exists() else ""

    # Update the local seed file (additive; preserves existing entries)
    seed_path = Path(os.path.expanduser(str(seed_path)))
    seed_path.parent.mkdir(parents=True, exist_ok=True)
    if seed_path.exists():
        try:
            seed = json.loads(seed_path.read_text())
        except Exception:
            seed = {}
    else:
        seed = {}

    if seed.get("schema") != "rapp-network-seed/1.0":
        seed = {
            "schema":   "rapp-network-seed/1.0",
            "_note":    "Local sniffer seed — includes sneakernet-imported peers (Article XLVII.5.3)",
            "operators": [],
        }

    # Replace any existing entry for this handle (idempotent re-import)
    operators = [op for op in seed.get("operators", [])
                 if not (isinstance(op, dict) and op.get("github") == handle)
                 and not (isinstance(op, str) and op == handle)]

    operators.append({
        "github":     handle,
        "beacon_url": beacon_url,
        "estate_url": estate_url,
        "_imported":  {
            "via":             "sneakernet-egg",
            "egg_origin":      str(egg),
            "imported_at":     _now_iso(),
            "egg_packed_at":   manifest.get("exported_at"),
            "egg_host":        manifest.get("host"),
            "kernel_version":  manifest.get("kernel_version"),
            "synthesized_beacon": beacon_was_synthesized,
        },
    })

    seed["operators"]   = operators
    seed["updated_at"]  = _now_iso()
    seed_path.write_text(json.dumps(seed, indent=2))

    return {
        "ok":             True,
        "schema":         "rapp-import-egg-result/1.0",
        "handle":         handle,
        "rappid":         rappid,
        "extracted_to":   str(dest),
        "beacon_url":     beacon_url,
        "estate_url":     estate_url,
        "seed_updated":   str(seed_path),
        "synthesized_beacon": beacon_was_synthesized,
        "implements":     manifest.get("implements", []),
        "next_step":      f"python3 tools/sniff_network.py --via raw --seed-url file://{seed_path.resolve()}",
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("egg", help="path to the .egg file you received via sneakernet/USB/etc.")
    ap.add_argument("--seed", default=str(_SEED_PATH),
                    help=f"local seed file to update (default {_SEED_PATH})")
    args = ap.parse_args()

    out = import_egg(args.egg, Path(args.seed))
    print(json.dumps(out, indent=2))
    return 0 if out.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
