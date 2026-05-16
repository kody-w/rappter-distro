"""lifecycle_organ.py — the LLM's only surface for kernel-level operations.

Routes (dispatched at /api/lifecycle/*):

    GET  /api/lifecycle/             — catalog of reserved agents (their metadata)
    POST /api/lifecycle/upgrade      — invoke upgrade_agent (action=check|apply)

The LLM reaches reserved agents (utils/reserved_agents/) ONLY through this
organ. The handshake protocol in soul.md teaches the LLM to confirm with
the user before any non-read action — and the organ enforces it on the
wire too: action="apply" without confirm=true returns a dry-run refusal.

Every call is appended to ~/.brainstem/lifecycle.log so the audit trail
exists even if the chat session is later cleared.
"""

from __future__ import annotations

import importlib
import importlib.util
import json
import os
import sys
import time
import traceback
from typing import Any

name = "lifecycle"


# Two dirname() walks: file → organs/ → utils/
_HERE = os.path.dirname(os.path.abspath(__file__))
_UTILS_DIR = os.path.dirname(_HERE)
_BRAINSTEM_DIR = os.path.dirname(_UTILS_DIR)
_RESERVED_DIR = os.path.join(_UTILS_DIR, "reserved_agents")

for _p in (_BRAINSTEM_DIR, _UTILS_DIR):
    if _p not in sys.path:
        sys.path.insert(0, _p)


def _log_path() -> str:
    """Resolve ~/.brainstem/lifecycle.log, creating the parent dir if needed."""
    home = os.environ.get("HOME") or os.path.expanduser("~")
    log_dir = os.path.join(home, ".brainstem")
    os.makedirs(log_dir, exist_ok=True)
    return os.path.join(log_dir, "lifecycle.log")


def _log(method: str, path: str, body: dict, status: int) -> None:
    """One JSON line per call — timestamp, route, body keys, exit status."""
    try:
        line = json.dumps({
            "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "method": method,
            "path": path,
            "body_keys": sorted(list((body or {}).keys())),
            "status": status,
        })
        with open(_log_path(), "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass  # logging is best-effort; never crash a request on log failure


# ── Reserved agent loading ───────────────────────────────────────────────


def _load_reserved_agent(filename: str, class_name: str):
    """Import a reserved agent module by filename + return the class.

    Reserved agents are NOT on sys.path the same way as kernel agents —
    they live at utils/reserved_agents/<file>.py. We load them via the
    `utils.reserved_agents` package so their `from utils import bond`
    imports resolve correctly.
    """
    module_path = f"utils.reserved_agents.{filename[:-3]}"  # strip .py
    try:
        mod = importlib.import_module(module_path)
        return getattr(mod, class_name)
    except Exception as e:
        traceback.print_exc()
        raise RuntimeError(f"could not load {module_path}.{class_name}: {e}")


# Lazy module-level cache so each request reuses the same instance.
_AGENT_CACHE: dict = {}


def _get_upgrade_agent():
    if "upgrade" not in _AGENT_CACHE:
        cls = _load_reserved_agent("upgrade_agent.py", "UpgradeAgent")
        _AGENT_CACHE["upgrade"] = cls()
    return _AGENT_CACHE["upgrade"]


# ── Catalog (GET /) ──────────────────────────────────────────────────────


def _catalog() -> dict:
    """List every reserved agent's metadata. The LLM fetches this when it
    needs to remember what lifecycle operations are available."""
    agents: list = []
    try:
        ua = _get_upgrade_agent()
        agents.append({
            "name": ua.metadata.get("name", ua.name),
            "route": "/api/lifecycle/upgrade",
            "description": ua.metadata.get("description", ""),
            "parameters": ua.metadata.get("parameters", {}),
        })
    except Exception as e:
        agents.append({
            "name": "upgrade_brainstem",
            "route": "/api/lifecycle/upgrade",
            "error": f"agent failed to load: {e}",
        })
    return {
        "schema": "rapp-lifecycle-catalog/1.0",
        "note": (
            "Reserved agents are invoked only on demand. Before calling any "
            "non-read action, confirm with the user (see soul.md handshake)."
        ),
        "agents": agents,
    }


# ── Upgrade route ────────────────────────────────────────────────────────


def _upgrade(body: dict) -> tuple[dict, int]:
    action = (body or {}).get("action", "check")
    confirm = bool((body or {}).get("confirm", False))
    pin = (body or {}).get("pin")

    # Wire-level safety: refuse apply without confirm:true at the organ
    # boundary too (the agent enforces it independently — defense in depth).
    if action == "apply" and not confirm:
        return {
            "ok": False,
            "error": "confirmation required",
            "hint": (
                "POST again with body { \"action\": \"apply\", \"confirm\": true } "
                "after explaining to the user what will happen and getting their yes."
            ),
        }, 400

    try:
        agent = _get_upgrade_agent()
    except Exception as e:
        return {"ok": False, "error": f"upgrade_agent unavailable: {e}"}, 500

    raw = agent.perform(action=action, confirm=confirm, pin=pin)
    try:
        payload = json.loads(raw) if isinstance(raw, str) else raw
    except Exception:
        payload = {"ok": False, "error": "agent returned non-JSON", "raw": raw}

    status = 200 if payload.get("ok", True) else 200  # agent-level errors are still 200
    return payload, status


# ── Dispatch ────────────────────────────────────────────────────────────


def handle(method: str, path: str, body: dict):
    """Organ entry point — dispatched by utils/organs."""
    p = (path or "").strip("/")
    body = body or {}

    # Catalog
    if method == "GET" and p in ("", "catalog", "agents"):
        result = _catalog()
        _log(method, p, body, 200)
        return result, 200

    # Upgrade
    if p in ("upgrade", "upgrade/"):
        if method == "POST":
            result, status = _upgrade(body)
            _log(method, p, body, status)
            return result, status
        if method == "GET":
            # GET /upgrade is read-only metadata about the route
            try:
                agent = _get_upgrade_agent()
                result = {
                    "name": agent.metadata.get("name"),
                    "description": agent.metadata.get("description"),
                    "parameters": agent.metadata.get("parameters"),
                    "hint": (
                        "POST { \"action\": \"check\" } to check for an upgrade. "
                        "POST { \"action\": \"apply\", \"confirm\": true } to apply."
                    ),
                }
                _log(method, p, body, 200)
                return result, 200
            except Exception as e:
                _log(method, p, body, 500)
                return {"ok": False, "error": str(e)}, 500

    _log(method, p, body, 404)
    return {
        "error": f"unknown route: {method} /api/lifecycle/{p}",
        "available": ["GET /", "GET /upgrade", "POST /upgrade"],
    }, 404
