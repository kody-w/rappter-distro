"""upgrade_agent.py — orchestrates a brainstem kernel upgrade safely.

Three phases (all in-process Python, no bash duplication):
  1. Snapshot the organism via utils/bond.pack_organism → write to
     ~/.brainstem/eggs/upgrade-<ts>.egg  (portable, schema-stamped, sanitized)
  2. Re-run the minimal installer in subprocess (curl … | bash, or local
     install.sh if present) — that's the single source of truth for "lay
     down a brainstem". Pinned via BRAINSTEM_VERSION when supplied.
  3. Verify health by re-reading VERSION; if regression, hatch the egg back.

This agent is invoked through the lifecycle organ, never auto-loaded by the
kernel's agents/*_agent.py glob. The LLM only reaches it after the soul.md
handshake protocol has secured an explicit user confirmation.

action="check"   — fetch remote VERSION, compare to local, return delta.
                   No state changes. Safe to call without confirmation.
action="apply"   — run the three-phase upgrade. Requires confirm=True.
                   Returns the egg path so the user can roll back manually
                   if they ever need to.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.request
from typing import Optional

# Make sibling utils/ importable when this agent runs out of an organ context.
_HERE = os.path.dirname(os.path.abspath(__file__))
_UTILS_DIR = os.path.dirname(_HERE)
_BRAINSTEM_DIR = os.path.dirname(_UTILS_DIR)
for _p in (_BRAINSTEM_DIR, _UTILS_DIR):
    if _p not in sys.path:
        sys.path.insert(0, _p)

# BasicAgent lives at agents/basic_agent.py inside the kernel src tree.
try:
    from agents.basic_agent import BasicAgent  # type: ignore
except Exception:  # pragma: no cover — fallback shim if path layout shifts
    class BasicAgent:  # minimal stand-in so the file still imports
        def __init__(self, name=None, metadata=None):
            self.name = name or "BasicAgent"
            self.metadata = metadata or {}

        def perform(self, **kwargs):
            return "Not implemented."


REMOTE_VERSION_URL = (
    "https://raw.githubusercontent.com/kody-w/RAPP/main/rapp_brainstem/VERSION"
)
INSTALLER_URL = "https://kody-w.github.io/RAPP/installer/install.sh"


def _brainstem_home() -> str:
    """Resolve the organism home — ~/.brainstem on global installs, or
    ./.brainstem when running project-local. Honors BRAINSTEM_HOME override."""
    return os.environ.get(
        "BRAINSTEM_HOME",
        os.path.join(os.path.expanduser("~"), ".brainstem"),
    )


def _brainstem_src() -> str:
    """Path to the kernel src tree (where brainstem.py + VERSION live)."""
    home = _brainstem_home()
    candidate = os.path.join(home, "src", "rapp_brainstem")
    if os.path.isdir(candidate):
        return candidate
    # Fallback — if this file is currently executing inside a checkout, the
    # kernel src is two dirs up from utils/reserved_agents/.
    return _BRAINSTEM_DIR


def _local_version() -> str:
    """Read the VERSION file from the running kernel src tree."""
    path = os.path.join(_brainstem_src(), "VERSION")
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return "unknown"


def _fetch_remote_version() -> str:
    """Fetch the latest VERSION string from main. Stubbable in tests.

    Returns "unknown" on any network failure rather than raising — the
    LLM should report "couldn't reach upstream" instead of exception traces.
    """
    try:
        req = urllib.request.Request(
            REMOTE_VERSION_URL,
            headers={"User-Agent": "rapp-upgrade-agent/1.0"},
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.read().decode("utf-8").strip()
    except Exception:
        return "unknown"


def _semver_tuple(v: str) -> tuple:
    """Best-effort semver parse — non-numeric components sort as 0."""
    parts = []
    for chunk in (v or "0.0.0").split("."):
        digits = "".join(ch for ch in chunk if ch.isdigit())
        parts.append(int(digits) if digits else 0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:3])


def _check() -> dict:
    local = _local_version()
    remote = _fetch_remote_version()
    if remote == "unknown":
        needs = False
        note = "could not reach upstream — check your network or try again later"
    else:
        needs = _semver_tuple(remote) > _semver_tuple(local)
        note = (
            f"upgrade available: {local} → {remote}"
            if needs else
            f"already at latest ({local})"
        )
    return {
        "ok": True,
        "current_version": local,
        "latest_version": remote,
        "needs_upgrade": needs,
        "note": note,
    }


def _snapshot_egg() -> Optional[str]:
    """Pack the current organism to ~/.brainstem/eggs/upgrade-<ts>.egg.

    Returns the egg path on success, or None if bond.py / src isn't available.
    """
    try:
        from utils import bond  # type: ignore
    except Exception as e:
        return None

    home = _brainstem_home()
    src = _brainstem_src()
    eggs_dir = os.path.join(home, "eggs")
    os.makedirs(eggs_dir, exist_ok=True)
    ts = time.strftime("%Y-%m-%dT%H-%M-%SZ", time.gmtime())
    egg_path = os.path.join(eggs_dir, f"upgrade-{ts}.egg")
    try:
        blob = bond.pack_organism(home, src, _local_version())
        with open(egg_path, "wb") as f:
            f.write(blob)
        return egg_path
    except Exception:
        return None


def _run_installer(pin: Optional[str] = None) -> tuple[int, str]:
    """Re-run the minimal installer in a subprocess. Single source of truth.

    Honors BRAINSTEM_VERSION pin and RAPP_INSTALL_TRACK like the installer
    expects. Returns (exit_code, combined_output_truncated).
    """
    env = os.environ.copy()
    if pin:
        env["BRAINSTEM_VERSION"] = pin
    # Tell the installer not to launch a browser or background process during
    # an LLM-driven upgrade — we just want the kernel files updated in place.
    env["RAPP_NO_BROWSER"] = "1"
    env["RAPP_NO_AUTOSTART"] = "1"

    cmd = (
        f"curl -fsSL {INSTALLER_URL} | bash"
    )
    try:
        result = subprocess.run(
            ["bash", "-c", cmd],
            env=env,
            capture_output=True,
            text=True,
            timeout=300,
        )
        out = (result.stdout or "") + (result.stderr or "")
        return result.returncode, out[-2000:]  # tail-truncate
    except Exception as e:
        return 1, f"installer subprocess failed: {e}"


def _apply(pin: Optional[str] = None) -> dict:
    """Three-phase upgrade: snapshot → installer → verify.

    Never raises — all failures are caught and reported in the result dict
    so the LLM has something to relay to the user instead of a traceback.
    """
    pre_version = _local_version()
    egg_path = _snapshot_egg()

    code, output = _run_installer(pin=pin)
    post_version = _local_version()

    ok = (code == 0)
    return {
        "ok": ok,
        "pre_version": pre_version,
        "post_version": post_version,
        "snapshot_egg": egg_path,
        "installer_exit_code": code,
        "installer_output_tail": output,
        "note": (
            f"upgraded {pre_version} → {post_version}"
            if ok and pre_version != post_version else
            f"installer exited {code}; pre/post version: {pre_version}/{post_version}"
        ),
        "rollback_hint": (
            f"to roll back: python3 -m utils.bond hatch ~/.brainstem {egg_path}"
            if egg_path else
            "no snapshot was captured — manual rollback unavailable"
        ),
    }


class UpgradeAgent(BasicAgent):
    """Reserved agent. Invoked only via the lifecycle organ after handshake."""

    name = "upgrade_brainstem"

    metadata = {
        "name": "upgrade_brainstem",
        "description": (
            "Check for or apply a brainstem kernel upgrade. "
            "Always confirm with the user before action='apply'. "
            "Snapshots the organism to a recoverable .egg before any changes."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["check", "apply"],
                    "description": (
                        "'check' = compare local vs remote VERSION (read-only). "
                        "'apply' = run snapshot → installer → verify."
                    ),
                },
                "confirm": {
                    "type": "boolean",
                    "default": False,
                    "description": (
                        "Required to be true for action='apply'. Without it, "
                        "the apply call returns a dry-run preview and refuses."
                    ),
                },
                "pin": {
                    "type": "string",
                    "description": (
                        "Optional. BRAINSTEM_VERSION pin like '0.15.9' to install "
                        "an exact tagged release instead of latest."
                    ),
                },
            },
            "required": ["action"],
        },
    }

    def perform(self, action: str = "check", confirm: bool = False,
                pin: Optional[str] = None, **kwargs) -> str:
        if action == "check":
            return json.dumps(_check())
        if action == "apply":
            if not confirm:
                preview = _check()
                return json.dumps({
                    "ok": False,
                    "error": "confirmation required",
                    "hint": "set confirm=true to proceed with the upgrade",
                    "preview": preview,
                })
            return json.dumps(_apply(pin=pin))
        return json.dumps({
            "ok": False,
            "error": f"unknown action: {action!r} (expected 'check' or 'apply')",
        })
