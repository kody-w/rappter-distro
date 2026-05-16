"""
utils/senses — additive sense composer.

`from utils.senses import install` is the API. Boot calls it with the
kernel's Flask app; this package discovers `*_sense.py` files that
live alongside, augments the kernel's soul cache with each sense's
`system_prompt`, and installs an `after_request` hook that splits
`/chat` responses on each sense's delimiter, exposing the parsed
segment under its `response_key`.

A sense is a single-file unit:
    name: str               # e.g. "twin"
    delimiter: str          # e.g. "|||TWIN|||"
    response_key: str       # e.g. "twin_response"
    wrapper_tag: str        # e.g. "twin"
    system_prompt: str      # appended to the soul on every chat turn

The canonical kernel hardcodes only `|||VOICE|||` (when VOICE_MODE=true).
This package makes every sense in `utils/senses/` participate without
modifying the kernel: senses are discovered at boot, their prompts
augment `_soul_cache` once, and the response splitter handles all
configured delimiters uniformly.

Running the kernel directly (`python brainstem.py`) skips this loader
and leaves the kernel's hardcoded VOICE-only behavior intact.
"""

from __future__ import annotations

import glob
import importlib.util
import json
import os
import sys
import traceback


_HERE = os.path.dirname(os.path.abspath(__file__))           # utils/senses/
_UTILS_DIR = os.path.dirname(_HERE)                          # utils/
_BRAINSTEM_DIR = os.path.dirname(_UTILS_DIR)                 # rapp_brainstem/


def _discover_sense_files() -> list[str]:
    if not os.path.isdir(_HERE):
        return []
    return sorted(glob.glob(os.path.join(_HERE, "*_sense.py")))


def _import_sense(filepath: str, idx: int):
    if _BRAINSTEM_DIR not in sys.path:
        sys.path.insert(0, _BRAINSTEM_DIR)
    base = os.path.basename(filepath).replace(".", "_")
    module_name = f"_sense_{idx}_{base}"
    try:
        spec = importlib.util.spec_from_file_location(module_name, filepath)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    except Exception as e:
        print(f"[boot] sense failed to import {filepath}: {e}")
        traceback.print_exc()
        return None


def _is_valid_sense(module) -> bool:
    return all(
        isinstance(getattr(module, attr, None), str) and getattr(module, attr)
        for attr in ("name", "delimiter", "response_key", "system_prompt")
    )


def discover() -> list:
    """Return the list of valid sense modules under utils/senses/."""
    senses = []
    for idx, filepath in enumerate(_discover_sense_files()):
        module = _import_sense(filepath, idx)
        if module is None:
            continue
        if not _is_valid_sense(module):
            continue
        senses.append(module)
    return senses


def _find_kernel_module():
    """Locate the running kernel module — runpy ran it as __main__."""
    main = sys.modules.get("__main__")
    if main and hasattr(main, "_soul_cache") and hasattr(main, "load_soul"):
        return main
    for mod in list(sys.modules.values()):
        try:
            f = getattr(mod, "__file__", "") or ""
            if f.endswith("/brainstem.py") and hasattr(mod, "_soul_cache"):
                return mod
        except Exception:
            continue
    return None


def install(app, senses: list | None = None) -> int:
    """Augment the kernel's soul cache with sense prompts and install
    the response splitter on app's /chat route. Returns the number
    of senses installed.
    """
    if senses is None:
        senses = discover()
    if not senses:
        print("[boot] no senses found under utils/senses/")
        return 0

    kernel = _find_kernel_module()
    if kernel is None:
        print("[boot] senses: could not locate kernel module")
        return 0

    base_soul = kernel.load_soul() or ""
    sense_prompts = "\n\n".join(s.system_prompt for s in senses)

    kernel._soul_cache = base_soul.rstrip() + "\n\n" + sense_prompts.strip()

    print(f"[boot] {len(senses)} sense(s) composed into soul: {[s.name for s in senses]}")

    from flask import request

    @app.after_request
    def _split_senses(response):
        try:
            if request.path != "/chat":
                return response
            if not response.is_json:
                return response
            if response.status_code != 200:
                return response
            data = response.get_json(silent=True)
            if not isinstance(data, dict):
                return response
            reply = data.get("response", "") or ""
            changed = False
            for sense in senses:
                delim = sense.delimiter
                if delim and delim in reply:
                    head, tail = reply.split(delim, 1)
                    reply = head.strip()
                    data[sense.response_key] = tail.strip()
                    changed = True
            if changed:
                data["response"] = reply
                response.set_data(json.dumps(data))
                response.headers["Content-Length"] = str(len(response.get_data()))
        except Exception as e:
            print(f"[boot] senses splitter error: {e}")
        return response

    return len(senses)


__all__ = ["install", "discover"]
