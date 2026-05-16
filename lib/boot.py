"""
utils/boot.py — additive launcher that wraps the canonical kernel.

The canonical brainstem.py is the digital organism's DNA — it boots a
Flask app that serves /chat, /agents, /health, etc. It does NOT
dispatch organs, mount /web/ static assets, or add other local-repo
integrations. Per Constitution Article XXXIII, the kernel stays small
and untouched; everything around it is mutable.

This file IS that "everything around it" — a kernel-sibling launcher
that:

  1. Monkey-patches `Flask.run` BEFORE the kernel runs.
  2. Executes the canonical kernel verbatim via runpy (the kernel's
     `if __name__ == "__main__":` block runs unchanged).
  3. The patched `Flask.run` composes organs, senses, and the /web/
     static mount onto the kernel's app right before it starts
     serving.

The kernel itself never imports this file. It does not know boot.py
exists. start.sh / start.ps1 invoke `python utils/boot.py` instead of
`python brainstem.py` — that's the one piece that has to know.

Running the kernel directly (`python brainstem.py`) still works and
gives you the canonical /chat surface without organs, senses, or the
web mount — exactly what the canonical kernel promises.
"""

from __future__ import annotations

import os
import runpy
import sys


_HERE = os.path.dirname(os.path.abspath(__file__))           # utils/
_BRAINSTEM_DIR = os.path.dirname(_HERE)                      # rapp_brainstem/


def _wrap_flask_run() -> None:
    """Hook a one-time pre-serve callback into Flask.run."""
    import flask

    _real_run = flask.Flask.run

    def _wrapped_run(self, *args, **kwargs):
        # Last-mile additions, just before the kernel starts serving.
        # Make utils/ importable so `from organs import ...` works
        # whether the kernel was launched as `python utils/boot.py` or
        # via runpy from somewhere else.
        if _HERE not in sys.path:
            sys.path.insert(0, _HERE)
        if _BRAINSTEM_DIR not in sys.path:
            sys.path.insert(0, _BRAINSTEM_DIR)

        try:
            try:
                from organs import install as install_organs
            except ImportError:
                # Older clones still have body_functions_loader.py at root.
                import body_functions_loader  # type: ignore
                install_organs = body_functions_loader.install
            install_organs(self)
        except Exception as e:
            print(f"[boot] organs failed: {e}")

        try:
            from senses import install as install_senses
            install_senses(self)
        except ImportError:
            # Older clones still have senses_loader.py at root.
            try:
                import senses_loader  # type: ignore
                senses_loader.install(self)
            except Exception as e:
                print(f"[boot] senses failed: {e}")
        except Exception as e:
            print(f"[boot] senses failed: {e}")

        try:
            _mount_web_static(self)
        except Exception as e:
            print(f"[boot] /web mount failed: {e}")

        try:
            _install_snapshot_routes(self)
        except Exception as e:
            print(f"[boot] /api/snapshot routes failed: {e}")

        try:
            _install_senses_routes(self)
        except Exception as e:
            print(f"[boot] /api/senses routes failed: {e}")

        try:
            _install_workspace_routes(self)
        except Exception as e:
            print(f"[boot] /api/workspace routes failed: {e}")

        try:
            _install_preferences_routes(self)
        except Exception as e:
            print(f"[boot] /api/preferences routes failed: {e}")

        return _real_run(self, *args, **kwargs)

    flask.Flask.run = _wrapped_run


def _mount_web_static(app) -> None:
    """Serve static files from utils/web/ at /web/<path>.

    The canonical kernel's `/` already serves index.html. /web/ is for
    organ viewers (neighborhood.html, etc.) and any future static UI
    an organ wants to ship alongside its handler.
    """
    web_dir = os.path.join(_HERE, "web")
    if not os.path.isdir(web_dir):
        return

    from flask import send_from_directory, abort

    def web_view(rest: str = ""):
        if not rest:
            # /web/ — serve a directory index if present
            index = os.path.join(web_dir, "index.html")
            if os.path.exists(index):
                return send_from_directory(web_dir, "index.html")
            return abort(404)
        # Refuse any path traversal
        full = os.path.normpath(os.path.join(web_dir, rest))
        if not full.startswith(web_dir + os.sep) and full != web_dir:
            return abort(403)
        if not os.path.exists(full) or os.path.isdir(full):
            # Try directory index inside the requested path
            if os.path.isdir(full):
                idx = os.path.join(full, "index.html")
                if os.path.exists(idx):
                    return send_from_directory(os.path.dirname(idx), "index.html")
            return abort(404)
        return send_from_directory(os.path.dirname(full), os.path.basename(full))

    web_view.__name__ = "_boot_web_view"
    app.add_url_rule("/web", endpoint="_boot_web_root", view_func=web_view, methods=["GET"])
    app.add_url_rule("/web/", endpoint="_boot_web_root_slash", view_func=web_view, methods=["GET"])
    app.add_url_rule("/web/<path:rest>", endpoint="_boot_web_path", view_func=web_view, methods=["GET"])
    print(f"[boot] /web mounted from {web_dir}")


def _install_snapshot_routes(app) -> None:
    """Always-on .egg export/import — basic backup the chat UI depends on.

    Lives in the boot wrapper rather than an organ so it works OOTB with
    no organ wiring required. Same kernel-untouched contract as /web/.

        GET  /api/snapshot/export  → application/zip with the organism egg
        POST /api/snapshot/import  → body { content_b64, filename? }
                                     hatches the egg over this brainstem
    """
    from flask import request, jsonify, make_response
    import base64
    from datetime import datetime, timezone

    try:
        import bond  # type: ignore
    except Exception as e:
        print(f"[boot] /api/snapshot disabled — bond import failed: {e}")
        return

    def _rapp_home() -> str:
        return os.environ.get("RAPP_HOME") or os.path.join(os.path.expanduser("~"), ".brainstem")

    def _kernel_version() -> str:
        vfile = os.path.join(_BRAINSTEM_DIR, "VERSION")
        try:
            with open(vfile, "r", encoding="utf-8") as f:
                return f.read().strip()
        except OSError:
            return "0.0.0"

    def _sanitize_rappid_for_filename(rappid):
        """Make the rappid safe to use as a filename across macOS / Linux /
        Windows / FAT. Replaces colons and slashes (path separators on
        every major OS) and anything non-alphanumeric+@.+_- with a dash;
        collapses runs and trims leading/trailing separators. Returns ''
        if the input is empty or unusable."""
        if not isinstance(rappid, str) or not rappid:
            return ""
        out = []
        for ch in rappid:
            if ch.isalnum() or ch in "@._-":
                out.append(ch)
            else:
                # ':' (rappid section separator), '/' (owner/name separator),
                # spaces, anything else → dash
                out.append("-")
        s = "".join(out)
        # Collapse multi-dashes and trim
        while "--" in s:
            s = s.replace("--", "-")
        return s.strip("-._")

    def _export_view():
        try:
            blob = bond.pack_organism(_rapp_home(), _BRAINSTEM_DIR, _kernel_version())
        except Exception as e:
            return jsonify({"error": f"pack failed: {e}"}), 500
        # Filename is <sanitized-rappid>__<utc-stamp>.egg so multiple
        # organism eggs in a Downloads folder are uniquely identifiable
        # on sight (rappid encodes machine + lineage) and chronologically
        # sortable. The double underscore between the two halves is the
        # only never-occurs-in-rappid sentinel so a parser can split the
        # rappid back out cleanly. Falls back to "brainstem" if the
        # rappid file is missing (very early in an organism's life).
        slug = "brainstem"
        try:
            ident = bond._read_json(bond._rappid_path(_rapp_home())) or {}
            rappid = ident.get("rappid") or ""
            sanitized = _sanitize_rappid_for_filename(rappid)
            if sanitized:
                slug = sanitized
        except Exception:
            pass
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
        filename = f"{slug}__{stamp}.egg"
        resp = make_response(blob, 200)
        resp.headers["Content-Type"] = "application/zip"
        resp.headers["Content-Disposition"] = f'attachment; filename="{filename}"'
        resp.headers["X-Egg-Filename"] = filename
        resp.headers["Content-Length"] = str(len(blob))
        return resp

    def _import_view():
        body = request.get_json(silent=True) or {}
        b64 = body.get("content_b64")
        if not isinstance(b64, str) or not b64:
            return jsonify({"error": "missing content_b64"}), 400
        try:
            blob = base64.b64decode(b64)
        except Exception as e:
            return jsonify({"error": f"invalid base64: {e}"}), 400
        try:
            counts = bond.unpack_organism(blob, _rapp_home(), _BRAINSTEM_DIR)
        except ValueError as e:
            return jsonify({"error": str(e)}), 400
        except Exception as e:
            return jsonify({"error": f"hatch failed: {e}"}), 500
        return jsonify({
            "status": "ok",
            "counts": counts,
            "filename": body.get("filename") or None,
        }), 200

    _export_view.__name__ = "_boot_snapshot_export"
    _import_view.__name__ = "_boot_snapshot_import"
    app.add_url_rule("/api/snapshot/export",
                     endpoint="_boot_snapshot_export",
                     view_func=_export_view, methods=["GET"])
    app.add_url_rule("/api/snapshot/import",
                     endpoint="_boot_snapshot_import",
                     view_func=_import_view, methods=["POST"])
    print("[boot] /api/snapshot/export + /api/snapshot/import wired")


def _install_senses_routes(app) -> None:
    """Always-on sense file install/list/remove. Senses live under
    utils/senses/<id>_sense.py and are auto-composed at request time.
    The chat UI's RAPP_Store senses tab posts here.

        GET    /api/senses              → list installed sense files
        POST   /api/senses/install      → { filename, content }
        DELETE /api/senses/<filename>   → remove
    """
    from flask import request, jsonify

    senses_dir = os.path.join(_HERE, "senses")

    def _safe_filename(filename):
        if not isinstance(filename, str) or not filename:
            return None
        if "/" in filename or "\\" in filename or filename.startswith("."):
            return None
        if not filename.endswith("_sense.py"):
            return None
        return filename

    def _list_files():
        if not os.path.isdir(senses_dir):
            return []
        out = []
        for name_ in sorted(os.listdir(senses_dir)):
            if not name_.endswith("_sense.py"):
                continue
            full = os.path.join(senses_dir, name_)
            try:
                st = os.stat(full)
                out.append({
                    "filename": name_,
                    "id": name_[:-len("_sense.py")],
                    "bytes": st.st_size,
                    "mtime": int(st.st_mtime),
                })
            except OSError:
                continue
        return out

    def _list_view():
        return jsonify({"senses": _list_files(), "dir": senses_dir})

    def _install_view():
        body = request.get_json(silent=True) or {}
        filename = _safe_filename(body.get("filename"))
        content = body.get("content")
        if not filename:
            return jsonify({"error": "invalid filename — must be <id>_sense.py"}), 400
        if not isinstance(content, str) or not content.strip():
            return jsonify({"error": "missing content"}), 400
        os.makedirs(senses_dir, exist_ok=True)
        target = os.path.join(senses_dir, filename)
        try:
            with open(target, "w", encoding="utf-8") as f:
                f.write(content)
        except OSError as e:
            return jsonify({"error": f"write failed: {e}"}), 500
        return jsonify({"status": "ok", "filename": filename, "path": target})

    def _delete_view(filename):
        f = _safe_filename(filename)
        if not f:
            return jsonify({"error": "invalid filename"}), 400
        target = os.path.join(senses_dir, f)
        if not os.path.isfile(target):
            return jsonify({"error": "not found"}), 404
        try:
            os.remove(target)
        except OSError as e:
            return jsonify({"error": f"delete failed: {e}"}), 500
        return jsonify({"status": "ok", "filename": f})

    _list_view.__name__ = "_boot_senses_list"
    _install_view.__name__ = "_boot_senses_install"
    _delete_view.__name__ = "_boot_senses_delete"
    app.add_url_rule("/api/senses",
                     endpoint="_boot_senses_list",
                     view_func=_list_view, methods=["GET"])
    app.add_url_rule("/api/senses/install",
                     endpoint="_boot_senses_install",
                     view_func=_install_view, methods=["POST"])
    app.add_url_rule("/api/senses/<filename>",
                     endpoint="_boot_senses_delete",
                     view_func=_delete_view, methods=["DELETE"])
    print("[boot] /api/senses* wired")


def _install_workspace_routes(app) -> None:
    """Always-on per-rapp workspace file IO. Mirrors what the legacy
    binder service exposed at /api/binder/workspace/<id>/*, but lives
    in the boot wrapper so the chat UI's iframe bridge works without
    any binder dependency.

        GET    /api/workspace/<id>/info        → { path, mode, file_count }
        GET    /api/workspace/<id>/list        → { files: [...] }
        GET    /api/workspace/<id>/file/<name> → raw bytes
        PUT    /api/workspace/<id>/file/<name> → { content, encoding } → { name, size }
        DELETE /api/workspace/<id>/file/<name>
        POST   /api/workspace/<id>/reveal      → opens folder in OS file manager
    """
    from flask import request, jsonify, send_from_directory, abort
    import mimetypes
    import subprocess
    import sys as _sys

    try:
        import workspace as _ws  # type: ignore
    except Exception as e:
        print(f"[boot] /api/workspace disabled — workspace import failed: {e}")
        return

    def _info(rapp_id):
        path = _ws.ensure_workspace(rapp_id)
        if path is None:
            return jsonify({"error": "invalid rapp id"}), 400
        try:
            files = _ws.list_workspace(rapp_id)
        except Exception:
            files = []
        return jsonify({
            "path": str(path),
            "mode": "local",
            "file_count": len(files),
        })

    def _list(rapp_id):
        try:
            return jsonify({"files": _ws.list_workspace(rapp_id)})
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    def _file_get(rapp_id, name):
        target = _ws.safe_workspace_path(rapp_id, name)
        if target is None:
            return jsonify({"error": "invalid path"}), 400
        if not target.is_file():
            return jsonify({"error": "not found"}), 404
        mime, _ = mimetypes.guess_type(str(target))
        return send_from_directory(str(target.parent), target.name,
                                   mimetype=mime or "application/octet-stream")

    def _file_put(rapp_id, name):
        target = _ws.safe_workspace_path(rapp_id, name)
        if target is None:
            return jsonify({"error": "invalid path"}), 400
        body = request.get_json(silent=True) or {}
        content = body.get("content", "")
        encoding = body.get("encoding", "utf-8")
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            if encoding == "base64":
                import base64
                target.write_bytes(base64.b64decode(content))
            else:
                target.write_text(str(content), encoding="utf-8")
        except OSError as e:
            return jsonify({"error": f"write failed: {e}"}), 500
        return jsonify({"name": name, "size": target.stat().st_size})

    def _file_delete(rapp_id, name):
        target = _ws.safe_workspace_path(rapp_id, name)
        if target is None:
            return jsonify({"error": "invalid path"}), 400
        if not target.exists():
            return jsonify({"error": "not found"}), 404
        try:
            if target.is_dir():
                import shutil
                shutil.rmtree(target)
            else:
                target.unlink()
        except OSError as e:
            return jsonify({"error": f"delete failed: {e}"}), 500
        return jsonify({"status": "ok"})

    def _reveal(rapp_id):
        path = _ws.ensure_workspace(rapp_id)
        if path is None:
            return jsonify({"error": "invalid rapp id"}), 400
        try:
            if _sys.platform == "darwin":
                subprocess.run(["open", str(path)], check=False)
            elif _sys.platform.startswith("win"):
                subprocess.run(["explorer", str(path)], check=False, shell=False)
            else:
                subprocess.run(["xdg-open", str(path)], check=False)
        except Exception as e:
            return jsonify({"error": f"reveal failed: {e}"}), 500
        return jsonify({"status": "ok", "path": str(path)})

    _info.__name__ = "_boot_ws_info"
    _list.__name__ = "_boot_ws_list"
    _file_get.__name__ = "_boot_ws_file_get"
    _file_put.__name__ = "_boot_ws_file_put"
    _file_delete.__name__ = "_boot_ws_file_delete"
    _reveal.__name__ = "_boot_ws_reveal"
    app.add_url_rule("/api/workspace/<rapp_id>/info",
                     endpoint="_boot_ws_info",
                     view_func=_info, methods=["GET"])
    app.add_url_rule("/api/workspace/<rapp_id>/list",
                     endpoint="_boot_ws_list",
                     view_func=_list, methods=["GET"])
    app.add_url_rule("/api/workspace/<rapp_id>/file/<path:name>",
                     endpoint="_boot_ws_file_get",
                     view_func=_file_get, methods=["GET"])
    app.add_url_rule("/api/workspace/<rapp_id>/file/<path:name>",
                     endpoint="_boot_ws_file_put",
                     view_func=_file_put, methods=["PUT"])
    app.add_url_rule("/api/workspace/<rapp_id>/file/<path:name>",
                     endpoint="_boot_ws_file_delete",
                     view_func=_file_delete, methods=["DELETE"])
    app.add_url_rule("/api/workspace/<rapp_id>/reveal",
                     endpoint="_boot_ws_reveal",
                     view_func=_reveal, methods=["POST"])
    print("[boot] /api/workspace/<id>/* wired")


def _lineage_guard() -> None:
    """Refuse to boot if rappid.json identity doesn't match git location.

    A template clone that hasn't run initialize-variant.sh carries the
    parent's rappid in a non-parent location — running the brainstem on
    that workspace would corrupt the lineage chain. The guard runs
    before the kernel and any sibling loaders.

    Bypass: RAPP_SKIP_LINEAGE_CHECK=1 (logged, for emergency repair).
    """
    try:
        if _HERE not in sys.path:
            sys.path.insert(0, _HERE)
        from lineage_check import assert_initialized  # type: ignore
        assert_initialized()
    except SystemExit:
        raise
    except Exception as e:
        print(f"[boot] lineage check skipped: {e}")


def _install_preferences_routes(app) -> None:
    """User-scoped runtime preferences that need to survive a restart
    of the kernel. Today: which model the chat UI selected. Tomorrow:
    other "I picked this once, don't make me pick it again" knobs.

    Stored under ~/.brainstem/preferences/<key>.txt — plain files, one
    value per file, easy to inspect and back up. _seed_env_from_prefs
    runs at boot.py main() before runpy and bridges these into the
    kernel's environment view.

        GET  /api/preferences          → all known prefs as JSON
        GET  /api/preferences/<key>    → { value }
        POST /api/preferences/<key>    body: { value }
        DELETE /api/preferences/<key>  reset to default
    """
    from flask import request, jsonify

    prefs_dir = os.path.join(os.path.expanduser("~"), ".brainstem", "preferences")
    # Whitelist of keys so an open POST endpoint can't be used to write
    # arbitrary files via path traversal. New prefs land here as we add
    # them.
    _ALLOWED = {"model"}

    def _safe_path(key):
        if not isinstance(key, str) or key not in _ALLOWED:
            return None
        return os.path.join(prefs_dir, f"{key}.txt")

    def _read_pref(key):
        p = _safe_path(key)
        if not p:
            return None
        try:
            with open(p, "r", encoding="utf-8") as f:
                return f.read().strip()
        except OSError:
            return None

    def _write_pref(key, value):
        p = _safe_path(key)
        if not p:
            return False
        os.makedirs(prefs_dir, exist_ok=True)
        try:
            with open(p, "w", encoding="utf-8") as f:
                f.write(str(value).strip())
            return True
        except OSError:
            return False

    def _delete_pref(key):
        p = _safe_path(key)
        if not p:
            return False
        try:
            os.remove(p)
            return True
        except OSError:
            return False

    def _list_view():
        out = {}
        for k in _ALLOWED:
            v = _read_pref(k)
            if v is not None:
                out[k] = v
        return jsonify({"preferences": out, "dir": prefs_dir})

    def _get_view(key):
        if key not in _ALLOWED:
            return jsonify({"error": f"unknown preference '{key}'"}), 404
        return jsonify({"key": key, "value": _read_pref(key)})

    def _post_view(key):
        if key not in _ALLOWED:
            return jsonify({"error": f"unknown preference '{key}'"}), 404
        body = request.get_json(silent=True) or {}
        value = body.get("value")
        if not isinstance(value, str) or not value.strip():
            return jsonify({"error": "missing 'value' in body"}), 400
        if not _write_pref(key, value):
            return jsonify({"error": "could not persist"}), 500
        # For the model preference, reflect the change into the live
        # process env too, so the kernel's MODEL global picks it up
        # next time chat.py reads os.environ. The kernel's /models/set
        # already mutated the in-memory MODEL — this just keeps the
        # ambient env in sync for any code path that re-reads.
        if key == "model":
            os.environ["GITHUB_MODEL"] = value.strip()
        return jsonify({"key": key, "value": value.strip()})

    def _delete_view(key):
        if key not in _ALLOWED:
            return jsonify({"error": f"unknown preference '{key}'"}), 404
        _delete_pref(key)
        return jsonify({"key": key, "value": None})

    _list_view.__name__ = "_boot_prefs_list"
    _get_view.__name__ = "_boot_prefs_get"
    _post_view.__name__ = "_boot_prefs_post"
    _delete_view.__name__ = "_boot_prefs_delete"
    app.add_url_rule("/api/preferences",
                     endpoint="_boot_prefs_list",
                     view_func=_list_view, methods=["GET"])
    app.add_url_rule("/api/preferences/<key>",
                     endpoint="_boot_prefs_get",
                     view_func=_get_view, methods=["GET"])
    app.add_url_rule("/api/preferences/<key>",
                     endpoint="_boot_prefs_post",
                     view_func=_post_view, methods=["POST"])
    app.add_url_rule("/api/preferences/<key>",
                     endpoint="_boot_prefs_delete",
                     view_func=_delete_view, methods=["DELETE"])
    print("[boot] /api/preferences/* wired")


def _seed_env_from_prefs() -> None:
    """Bridge the chat UI's per-user model pick into the kernel.

    The kernel reads MODEL from os.environ['GITHUB_MODEL'] once at
    module import. .env's default ("gpt-4o") is loaded by python-dotenv
    inside the kernel before that read. The chat UI persists the user's
    selected model into ~/.brainstem/preferences/model.txt on every
    /models/set; we splice that file's contents into the environment
    BEFORE runpy executes the kernel so the boot banner, the first
    /chat after restart, and every internal reference to MODEL all line
    up with the user's pick.

    Falls back silently if the prefs file is missing — kernel default
    wins. Refusing to overwrite an explicit env-passed GITHUB_MODEL so
    `GITHUB_MODEL=foo brainstem run` still works as an override.
    """
    if os.environ.get("GITHUB_MODEL"):
        return
    pref_file = os.path.join(
        os.path.expanduser("~"), ".brainstem", "preferences", "model.txt"
    )
    try:
        with open(pref_file, "r", encoding="utf-8") as f:
            model = f.read().strip()
        if model:
            os.environ["GITHUB_MODEL"] = model
    except OSError:
        pass


def main() -> None:
    _lineage_guard()
    _seed_env_from_prefs()
    _wrap_flask_run()
    # Run the canonical kernel as if launched directly.
    kernel_path = os.path.join(_BRAINSTEM_DIR, "brainstem.py")
    runpy.run_path(kernel_path, run_name="__main__")


if __name__ == "__main__":
    main()
