"""lan_advertise — broadcast an operator's brainstem on the LAN via Bonjour/mDNS.

Per CONSTITUTION Article XLVII.5 (substrate-agnostic federation), the LAN
equivalent of GitHub's `topic:rapp-estate` discoverability is the Bonjour
service type `_rapp-estate._tcp.local`. This script:

  1. Starts a small HTTP server in ~/.brainstem/ on a chosen port.
     The operator's beacon (.well-known/rapp-network.json) and estate.json
     are already in that dir — they're now reachable to any LAN peer at
       http://<this-host>:<port>/.well-known/rapp-network.json
       http://<this-host>:<port>/estate.json
  2. Registers a Bonjour service of type `_rapp-estate._tcp` on the LAN
     with TXT records carrying the operator's rappid + canonical paths.
     Other brainstems running `dns-sd -B _rapp-estate._tcp local.` will
     see this advertisement instantly — same UX as GitHub's topic search,
     zero-config, scoped to the LAN.
  3. Cleans up both on Ctrl-C / SIGTERM.

USAGE:
    python3 tools/lan_advertise.py
    python3 tools/lan_advertise.py --port 8080
    python3 tools/lan_advertise.py --service-name "kody-brainstem"

Stdlib + macOS `dns-sd` CLI only. No new pip deps. If `dns-sd` is missing
(non-macOS), the script falls back to HTTP-only mode (LAN-discoverable to
peers who already know the URL, but not auto-discoverable via Bonjour).

CANONICAL TXT-RECORD SCHEMA (rapp-network-beacon-bonjour/1.0):
    rappid       = the operator's personal rappid (operator-kind v2)
    github       = the operator's github handle (informational; LAN doesn't need it)
    beacon_path  = "/.well-known/rapp-network.json"
    estate_path  = "/estate.json"
    schema       = "rapp-network-beacon/1.1"
    indexable    = "true" | "false"  (robots.txt-style consent flag)
    spec_version = "rapp-protocol/1.0"

A LAN sniffer's flow:
    dns-sd -B _rapp-estate._tcp local.        → list of advertised services
    dns-sd -L <name> _rapp-estate._tcp local. → resolve to host:port + TXT
    fetch http://<host>:<port>/<beacon_path>  → standard rapp-network-beacon/1.1
    BFS continues per Article XLVII (federation_hints walk works identically).
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

_BRAINSTEM_DIR = Path(os.path.expanduser("~/.brainstem"))
_RAPPID_FILE   = _BRAINSTEM_DIR / "rappid.json"
_BEACON_PATH   = ".well-known/rapp-network.json"
_ESTATE_PATH   = "estate.json"
_SERVICE_TYPE  = "_rapp-estate._tcp"


def _read_operator_rappid() -> tuple[str, str]:
    """Return (rappid, github_handle) from ~/.brainstem/rappid.json."""
    if not _RAPPID_FILE.exists():
        return "", ""
    try:
        d = json.loads(_RAPPID_FILE.read_text())
        rappid = d.get("rappid", "")
        github = d.get("github", "")
        if not github and ":@" in rappid:  # self-locating (canonical §6.1)
            try:
                github = rappid.split(":@", 1)[1].split("/", 1)[0]
            except Exception:
                pass
        return rappid, github
    except Exception:
        return "", ""


def _read_local_beacon() -> dict | None:
    """Try to load the local beacon if the brainstem has one staged."""
    p = _BRAINSTEM_DIR / "rapp-network.json"
    if not p.exists():
        # Maybe under .well-known/
        p = _BRAINSTEM_DIR / ".well-known" / "rapp-network.json"
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text())
    except Exception:
        return None


def _stage_beacon_locally(beacon_dict: dict | None, github: str, rappid: str) -> Path:
    """Make sure ~/.brainstem/.well-known/rapp-network.json exists so the HTTP
    server has it to serve. If we have a beacon dict (passed in or loaded), use
    it. Otherwise synthesize a minimal LAN-only beacon from the operator's rappid.
    Returns the path to the staged file."""
    well_known = _BRAINSTEM_DIR / ".well-known"
    well_known.mkdir(parents=True, exist_ok=True)
    target = well_known / "rapp-network.json"

    if beacon_dict is None and target.exists():
        return target  # already there

    if beacon_dict is None:
        # Synthesize a minimal LAN-only beacon. The full beacon shape is in
        # estate_agent.py; here we only need the spec-compliant fields a
        # sniffer expects to parse a node off the LAN.
        beacon_dict = {
            "schema": "rapp-network-beacon/1.1",
            "operator_rappid": rappid,
            "github": github,
            "estate_url": "",  # filled at advertise time with the LAN URL
            "grail_url": "",
            "protocol": {
                "spec_version": "rapp-protocol/1.0",
                "estate_schema": "rapp-estate/1.1",
                "implements": ["article-xlvi", "article-xlvi.6", "article-xlvii", "article-xlvii.5", "article-xlviii"],
                "spec_url": "https://raw.githubusercontent.com/kody-w/RAPP/main/specs/SPEC.md",
            },
            "discovery": {
                "indexable": True,
                "consent": "public-discovery-ok",
                "federation_hints": [],
                "_note": "LAN-substrate beacon (Article XLVII.5). Discoverable via Bonjour _rapp-estate._tcp.",
            },
            "private_estate_pointer": "",
            "private_estate_commitment": "",
            "private_door_count": 0,
            "minted_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }

    target.write_text(json.dumps(beacon_dict, indent=2))
    return target


def _detect_lan_ip() -> str:
    """Detect the primary LAN IP via the standard 'connect to a remote host
    and read the local socket' trick. Doesn't actually send any packets.
    Returns "" if no LAN-routable IP is detectable."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))  # doesn't transmit; just routing-table lookup
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return ""


def _start_http_server(port: int) -> subprocess.Popen:
    """Spawn `python3 -m http.server <port>` in ~/.brainstem/."""
    return subprocess.Popen(
        ["python3", "-m", "http.server", str(port)],
        cwd=str(_BRAINSTEM_DIR),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _start_bonjour_advertisement(service_name: str, port: int, txt_records: dict[str, str]) -> subprocess.Popen | None:
    """Register a Bonjour service via `dns-sd -R`. Returns None if dns-sd missing.

    The dns-sd CLI runs in the foreground while the registration is alive;
    we keep it as a Popen and terminate on cleanup.
    """
    if not shutil.which("dns-sd"):
        return None
    txt_args = [f"{k}={v}" for k, v in txt_records.items()]
    cmd = ["dns-sd", "-R", service_name, _SERVICE_TYPE, ".", str(port), *txt_args]
    return subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--port", type=int, default=8080, help="LAN HTTP port (default 8080)")
    ap.add_argument("--service-name", default="", help="Bonjour service name (default: <handle>-brainstem)")
    ap.add_argument("--brainstem-dir", default="", help="Override ~/.brainstem location")
    ap.add_argument("--no-bonjour", action="store_true", help="Skip Bonjour advertisement (HTTP only)")
    args = ap.parse_args()

    global _BRAINSTEM_DIR, _RAPPID_FILE
    if args.brainstem_dir:
        _BRAINSTEM_DIR = Path(os.path.expanduser(args.brainstem_dir))
        _RAPPID_FILE   = _BRAINSTEM_DIR / "rappid.json"

    if not _BRAINSTEM_DIR.exists():
        print(f"error: {_BRAINSTEM_DIR} does not exist. Install the brainstem first.", file=sys.stderr)
        return 2

    rappid, github = _read_operator_rappid()
    if not rappid:
        print(f"warning: no rappid found at {_RAPPID_FILE}; advertising with empty rappid", file=sys.stderr)

    service_name = args.service_name or (f"{github}-brainstem" if github else "rapp-brainstem")

    # Stage / refresh the local beacon file with the LAN URL filled in
    lan_ip = _detect_lan_ip()
    beacon_dict = _read_local_beacon()
    if beacon_dict is None:
        beacon_dict = {}
    if lan_ip:
        beacon_dict["estate_url"] = f"http://{lan_ip}:{args.port}/{_ESTATE_PATH}"
    beacon_path_on_disk = _stage_beacon_locally(beacon_dict, github, rappid)

    # Build the TXT records (Bonjour-canonical schema for RAPP discovery)
    txt = {
        "rappid":       rappid,
        "github":       github,
        "beacon_path":  f"/{_BEACON_PATH}",
        "estate_path":  f"/{_ESTATE_PATH}",
        "schema":       "rapp-network-beacon/1.1",
        "spec_version": "rapp-protocol/1.0",
        "indexable":    "true",
    }

    # Spawn HTTP server
    print(f"  ▸ starting HTTP server on port {args.port} (serving {_BRAINSTEM_DIR})", file=sys.stderr)
    http_proc = _start_http_server(args.port)
    time.sleep(0.5)  # let it bind

    bonjour_proc = None
    if not args.no_bonjour:
        print(f"  ▸ registering Bonjour service: {service_name}.{_SERVICE_TYPE}.local. (port {args.port})", file=sys.stderr)
        bonjour_proc = _start_bonjour_advertisement(service_name, args.port, txt)
        if bonjour_proc is None:
            print(f"  ⚠ dns-sd not found; advertising HTTP only (peers must know the URL)", file=sys.stderr)

    # Print human summary
    print()
    print(f"  ╭─ LAN beacon LIVE  (Article XLVII.5 — substrate-agnostic federation)")
    print(f"  │  rappid:        {rappid[:60]}…" if rappid else "  │  rappid:        (none)")
    print(f"  │  github:        {github or '(none)'}")
    print(f"  │  HTTP base:     http://{lan_ip or '<this-host>'}:{args.port}/")
    print(f"  │  beacon URL:    http://{lan_ip or '<this-host>'}:{args.port}/{_BEACON_PATH}")
    print(f"  │  estate URL:    http://{lan_ip or '<this-host>'}:{args.port}/{_ESTATE_PATH}")
    if bonjour_proc:
        print(f"  │  Bonjour:       {service_name}.{_SERVICE_TYPE}.local. (TXT carries rappid + paths)")
        print(f"  │  Discover:      dns-sd -B {_SERVICE_TYPE} local.")
    print(f"  ╰─ Ctrl-C to stop")
    print()

    def _cleanup(*_):
        print("\n  ▸ shutting down…", file=sys.stderr)
        for p in (bonjour_proc, http_proc):
            if p is None: continue
            try:
                p.terminate()
                p.wait(timeout=2)
            except Exception:
                try: p.kill()
                except Exception: pass
        sys.exit(0)

    signal.signal(signal.SIGINT,  _cleanup)
    signal.signal(signal.SIGTERM, _cleanup)

    # Block until killed
    while True:
        time.sleep(1)
        if http_proc.poll() is not None:
            print(f"  ✗ HTTP server died (exit {http_proc.returncode})", file=sys.stderr)
            _cleanup()


if __name__ == "__main__":
    sys.exit(main())
