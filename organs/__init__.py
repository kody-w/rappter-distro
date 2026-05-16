"""
utils/organs — additive organ dispatcher.

`from utils.organs import install` is the API. Boot calls it with
the kernel's Flask app; this package discovers `*_organ.py` files
that live alongside, attaches `/api/<name>/<path>` routes, and the
kernel never has to know.

Organ contract (Constitution Article XXXII / XXXIII):
    name: str
    handle(method: str, path: str, body: dict) -> (dict, int)

The contract has been renamed twice: it began as "service"
(`*_service.py` under `utils/services/`), was renamed to
"body_function" (`*_body_function.py` under `utils/body_functions/`),
and is now "organ" (`*_organ.py` under `utils/organs/`). All three
suffixes refer to the same single-file unit; the loader supports all
three so older installs and template clones keep working through the
rename windows.
"""

from __future__ import annotations

import glob
import importlib.util
import os
import sys
import traceback
from typing import Any


_HERE = os.path.dirname(os.path.abspath(__file__))           # utils/organs/
_UTILS_DIR = os.path.dirname(_HERE)                          # utils/
_BRAINSTEM_DIR = os.path.dirname(_UTILS_DIR)                 # rapp_brainstem/


def _candidate_dirs() -> list[str]:
    """Canonical first, then transitional, then legacy."""
    return [
        _HERE,
        os.path.join(_UTILS_DIR, "body_functions"),
        os.path.join(_UTILS_DIR, "services"),
    ]


def _candidate_files(directory: str) -> list[str]:
    if not os.path.isdir(directory):
        return []
    files: list[str] = []
    files.extend(glob.glob(os.path.join(directory, "*_organ.py")))
    files.extend(glob.glob(os.path.join(directory, "*_body_function.py")))
    files.extend(glob.glob(os.path.join(directory, "*_service.py")))
    return sorted(set(files))


def _import_organ(filepath: str, idx: int) -> Any | None:
    """Load an organ module from disk."""
    # Make sure utils/ is importable so organs can do `from utils import ...`
    if _BRAINSTEM_DIR not in sys.path:
        sys.path.insert(0, _BRAINSTEM_DIR)

    base = os.path.basename(filepath).replace(".", "_")
    module_name = f"_organ_{idx}_{base}"
    try:
        spec = importlib.util.spec_from_file_location(module_name, filepath)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    except Exception as e:
        print(f"[boot] organ failed to import {filepath}: {e}")
        traceback.print_exc()
        return None


def _register_routes(app, organ_name: str, organ_handle) -> None:
    """Add /api/<name>, /api/<name>/, and /api/<name>/<path:rest> rules."""
    from flask import request, jsonify

    def make_view(rest_default: str = ""):
        def view(rest: str = rest_default):
            body = request.get_json(silent=True) or {}
            try:
                result, status = organ_handle(request.method, rest, body)
            except Exception as e:
                traceback.print_exc()
                return jsonify({"error": f"organ {organ_name} crashed: {e}"}), 500
            if isinstance(result, dict) or isinstance(result, list):
                return jsonify(result), status
            return result, status

        return view

    methods = ["GET", "POST", "PUT", "PATCH", "DELETE"]

    app.add_url_rule(
        f"/api/{organ_name}",
        endpoint=f"_organ_{organ_name}_root",
        view_func=make_view(""),
        methods=methods,
    )
    app.add_url_rule(
        f"/api/{organ_name}/",
        endpoint=f"_organ_{organ_name}_root_slash",
        view_func=make_view(""),
        methods=methods,
    )
    app.add_url_rule(
        f"/api/{organ_name}/<path:rest>",
        endpoint=f"_organ_{organ_name}_path",
        view_func=make_view(),
        methods=methods,
    )


def install(app) -> int:
    """Discover organs and register their routes on `app`.

    Returns the number of organs successfully registered. Idempotent
    on a fresh app; Flask refuses duplicate endpoints if install()
    runs twice against the same app.
    """
    seen_names: set[str] = set()
    count = 0
    for directory in _candidate_dirs():
        files = _candidate_files(directory)
        if not files:
            continue
        for idx, filepath in enumerate(files):
            module = _import_organ(filepath, idx)
            if module is None:
                continue
            organ_name = getattr(module, "name", None)
            organ_handle = getattr(module, "handle", None)
            if not organ_name or not callable(organ_handle):
                continue
            if organ_name in seen_names:
                # Newer location wins; skip the legacy duplicate.
                continue
            try:
                _register_routes(app, organ_name, organ_handle)
            except Exception as e:
                print(f"[boot] could not register routes for organ {organ_name}: {e}")
                continue
            seen_names.add(organ_name)
            count += 1
            print(f"[boot] organ ready: {organ_name} ({os.path.basename(filepath)})")
    print(f"[boot] {count} organ(s) wired into /api/<name>/...")
    return count


__all__ = ["install"]
