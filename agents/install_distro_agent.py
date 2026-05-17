"""install_distro_agent.py — single-file installer for the rappter-distro.

Drop this one file into ~/.brainstem/agents/ on any grail-kernel install and
the brainstem will hot-load it on the next request. Once loaded, the LLM
(or a direct tool-call) can invoke it to pull the full rappter-distro down
over the bare kernel — organs, senses, lib/, the rich UI, the @rappter
agents — without needing a separate curl|bash step.

The agent fetches the distro file-by-file from raw.githubusercontent.com,
driven by MANIFEST.json checked into the repo root. The fetch protocol is
two phases:

    1. GET https://raw.githubusercontent.com/kody-w/rappter-distro/<branch>/MANIFEST.json
    2. for each entry in manifest["files"]:
           GET https://raw.githubusercontent.com/kody-w/rappter-distro/<branch>/<entry["src"]>
           verify sha256, write to <brainstem_home>/<entry["dst"]>

This mirrors the "rebuild estate from pure GitHub raw data" pattern
(tools/rebuild_estate.py): the install state is provably a function of
the canonical raw URLs, with no zipball/clone hop in the middle.

Same single-file is also the manifest generator. Run it from a local
checkout with `--build-manifest` and it walks LAYOUT, computes sha256
for each file, and writes MANIFEST.json. The agent does the inverse
walk at install time.

Kernel-untouched contract: never writes to brainstem.py, VERSION, or
basic_agent.py. The drift-check one-liner in MIGRATION_NOTES.md should
still pass after running this agent.

Actions:
    check    — read-only: confirms a kernel is present, reports versions.
    status   — reports what's currently installed locally.
    dry-run  — fetches the manifest + every file, verifies hashes, but
               writes nothing; returns the exact install plan.
    install  — applies the manifest. Requires confirm=True.

Stdlib only — urllib, json, hashlib, os, shutil, tempfile, sys.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import sys
import tempfile
import urllib.error
import urllib.request
from typing import Callable, Optional


# ── BasicAgent import (with offline shim) ─────────────────────────────────
#
# When loaded by the kernel out of ~/.brainstem/agents/, agents.basic_agent
# imports cleanly. When this file is run standalone (for tests, or for the
# `python install_distro_agent.py` self-exec path), the import fails — the
# shim below keeps the module importable in both contexts.

try:
    from agents.basic_agent import BasicAgent  # type: ignore
except Exception:  # pragma: no cover — exercised by the standalone test path
    class BasicAgent:  # minimal stand-in
        def __init__(self, name=None, metadata=None):
            self.name = name or "BasicAgent"
            self.metadata = metadata or {}

        def perform(self, **kwargs):
            return "Not implemented."


# ── Configuration ────────────────────────────────────────────────────────

DISTRO_REPO = "kody-w/rappter-distro"
DEFAULT_BRANCH = "main"
USER_AGENT = "rappter-distro-installer/1.0"

# raw.githubusercontent.com base URL for the distro. Stable per Article V
# of the constitution (the install one-liner is sacred — URL shape doesn't
# move). Variant repos inherit the same shape under their own slug.
RAW_BASE = "https://raw.githubusercontent.com"

# The authoritative source-→destination map. Mirrors install.sh exactly.
# Used both for manifest-building (walking a local checkout) and for the
# source_dir test path (walking a checkout instead of network).
#
# Each entry: source pattern relative to a checkout, kind, dest relative
# to brainstem_home.
LAYOUT = [
    # kind="files":   every file in <src_dir> matching <pattern> (flat copy).
    # kind="tree":    every file under <src_dir> recursively.
    # kind="file":    a single named file.
    {"kind": "files", "src_dir": "lib",             "pattern": "*.py", "dst_dir": "utils"},
    {"kind": "files", "src_dir": "organs",          "pattern": "*.py", "dst_dir": "utils/organs"},
    {"kind": "files", "src_dir": "senses",          "pattern": "*.py", "dst_dir": "utils/senses"},
    {"kind": "tree",  "src_dir": "ui/web",                              "dst_dir": "utils/web"},
    {"kind": "file",  "src_path": "ui/index.html",                      "dst_path": "index.html"},
    {"kind": "file",  "src_path": "ui/tls_proxy.py",                    "dst_path": "tls_proxy.py"},
    {"kind": "files", "src_dir": "agents/@rappter", "pattern": "*.py", "dst_dir": "agents/@rappter"},
]

# Files the agent is forbidden from writing under any circumstance — the
# kernel-untouched contract. If a manifest entry resolves to one of these,
# the agent refuses and reports an error.
SACRED_PATHS = {
    "brainstem.py",
    "VERSION",
    "agents/basic_agent.py",
}

MANIFEST_SCHEMA = "rappter-distro-install-manifest/1.0"


# ── Path helpers ─────────────────────────────────────────────────────────

def _brainstem_home() -> str:
    """Resolve $BRAINSTEM_HOME, falling back to ~/.brainstem."""
    return os.environ.get(
        "BRAINSTEM_HOME",
        os.path.join(os.path.expanduser("~"), ".brainstem"),
    )


def _brainstem_kernel_path(home: str) -> str:
    return os.path.join(home, "brainstem.py")


def _verify_kernel_present(home: str) -> tuple[bool, str]:
    """Confirm a grail kernel exists at `home`. Returns (ok, message)."""
    kernel = _brainstem_kernel_path(home)
    if not os.path.isfile(kernel):
        return False, (
            f"no grail brainstem found at {kernel}. install the kernel first: "
            "curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash"
        )
    return True, f"found grail brainstem at {home}"


def _read_kernel_version(home: str) -> str:
    vfile = os.path.join(home, "VERSION")
    try:
        with open(vfile, "r", encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return "unknown"


# ── Raw-URL fetcher ──────────────────────────────────────────────────────

def _raw_url(repo: str, branch: str, path: str) -> str:
    return f"{RAW_BASE}/{repo}/{branch}/{path}"


def _http_get(url: str, timeout: int = 60) -> bytes:
    """GET a URL, return body bytes. Raises urllib.error on failure."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def _network_fetcher(repo: str, branch: str) -> Callable[[str], bytes]:
    """Default fetcher: pull `<src>` from raw.githubusercontent.com."""
    def fetch(src: str) -> bytes:
        return _http_get(_raw_url(repo, branch, src))
    return fetch


# ── Manifest builder (run from a local checkout) ─────────────────────────

def _sha256_bytes(data: bytes) -> str:
    h = hashlib.sha256()
    h.update(data)
    return h.hexdigest()


def _sha256_path(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _walk_layout_for_files(src_root: str) -> list[dict]:
    """Walk LAYOUT against `src_root` and produce a flat list of
    {src, dst, size, sha256} entries — the body of MANIFEST.json."""
    entries: list[dict] = []
    for spec in LAYOUT:
        kind = spec["kind"]
        if kind == "files":
            src_dir = os.path.join(src_root, spec["src_dir"])
            if not os.path.isdir(src_dir):
                continue
            pattern = spec["pattern"]
            assert pattern.startswith("*.")
            suffix = pattern[1:]
            for name in sorted(os.listdir(src_dir)):
                if not name.endswith(suffix):
                    continue
                abs_p = os.path.join(src_dir, name)
                if not os.path.isfile(abs_p):
                    continue
                rel_src = os.path.relpath(abs_p, src_root)
                rel_dst = os.path.join(spec["dst_dir"], name)
                entries.append({
                    "src": rel_src.replace(os.sep, "/"),
                    "dst": rel_dst.replace(os.sep, "/"),
                    "size": os.path.getsize(abs_p),
                    "sha256": _sha256_path(abs_p),
                })
        elif kind == "tree":
            src_dir = os.path.join(src_root, spec["src_dir"])
            if not os.path.isdir(src_dir):
                continue
            for dirpath, _, filenames in os.walk(src_dir):
                rel_subdir = os.path.relpath(dirpath, src_dir)
                for fname in sorted(filenames):
                    abs_p = os.path.join(dirpath, fname)
                    rel_src = os.path.relpath(abs_p, src_root)
                    if rel_subdir == ".":
                        rel_dst = os.path.join(spec["dst_dir"], fname)
                    else:
                        rel_dst = os.path.join(spec["dst_dir"], rel_subdir, fname)
                    entries.append({
                        "src": rel_src.replace(os.sep, "/"),
                        "dst": rel_dst.replace(os.sep, "/"),
                        "size": os.path.getsize(abs_p),
                        "sha256": _sha256_path(abs_p),
                    })
        elif kind == "file":
            abs_p = os.path.join(src_root, spec["src_path"])
            if not os.path.isfile(abs_p):
                continue
            entries.append({
                "src": spec["src_path"],
                "dst": spec["dst_path"],
                "size": os.path.getsize(abs_p),
                "sha256": _sha256_path(abs_p),
            })
        else:  # pragma: no cover
            raise ValueError(f"unknown layout kind: {kind!r}")
    # Stable order — manifests should diff cleanly.
    entries.sort(key=lambda e: (e["dst"], e["src"]))
    return entries


def build_manifest(src_root: str, *, branch: str = DEFAULT_BRANCH) -> dict:
    """Walk a local checkout at `src_root` and return the manifest dict.
    Caller writes it to MANIFEST.json at the repo root."""
    return {
        "schema": MANIFEST_SCHEMA,
        "repo": DISTRO_REPO,
        "branch": branch,
        "files": _walk_layout_for_files(src_root),
    }


# ── Manifest validator ───────────────────────────────────────────────────

def _validate_manifest(manifest: dict) -> None:
    """Sanity-check a manifest before acting on it."""
    if not isinstance(manifest, dict):
        raise ValueError("manifest must be a JSON object")
    if manifest.get("schema") != MANIFEST_SCHEMA:
        raise ValueError(
            f"unsupported manifest schema: {manifest.get('schema')!r} "
            f"(expected {MANIFEST_SCHEMA!r})"
        )
    files = manifest.get("files")
    if not isinstance(files, list) or not files:
        raise ValueError("manifest.files must be a non-empty list")
    for i, entry in enumerate(files):
        if not isinstance(entry, dict):
            raise ValueError(f"manifest.files[{i}] is not an object")
        for k in ("src", "dst", "sha256"):
            v = entry.get(k)
            if not isinstance(v, str) or not v:
                raise ValueError(f"manifest.files[{i}].{k} is missing or not a string")
        dst = entry["dst"]
        # No absolute paths, no traversal, no sacred paths.
        if dst.startswith("/") or dst.startswith("\\") or ".." in dst.split("/"):
            raise ValueError(f"manifest.files[{i}].dst is unsafe: {dst!r}")
        if dst in SACRED_PATHS:
            raise PermissionError(
                f"manifest.files[{i}].dst targets sacred kernel file: {dst}"
            )


# ── Install application ──────────────────────────────────────────────────

def _apply_manifest(
    manifest: dict,
    home: str,
    fetcher: Callable[[str], bytes],
    *,
    dry_run: bool,
) -> list[dict]:
    """Fetch every file in the manifest via `fetcher`, verify sha256, write
    to `home`/<dst>. Returns a per-entry result list (the install manifest
    the agent surfaces back to the LLM)."""
    out: list[dict] = []
    for entry in manifest["files"]:
        src = entry["src"]
        dst_rel = entry["dst"]
        expected_sha = entry["sha256"]
        dst_abs = os.path.join(home, dst_rel)

        try:
            blob = fetcher(src)
        except urllib.error.URLError as e:
            out.append({
                "src": src, "dst": dst_rel, "action": "fetch-failed",
                "error": f"network: {e}",
            })
            continue
        except Exception as e:
            out.append({
                "src": src, "dst": dst_rel, "action": "fetch-failed",
                "error": str(e),
            })
            continue

        actual_sha = _sha256_bytes(blob)
        if actual_sha != expected_sha:
            out.append({
                "src": src, "dst": dst_rel, "action": "sha-mismatch",
                "expected_sha256": expected_sha,
                "actual_sha256": actual_sha,
            })
            continue

        size = len(blob)
        existed = os.path.isfile(dst_abs)
        if dry_run:
            out.append({
                "src": src, "dst": dst_rel, "action": "would-install",
                "size": size, "sha256": actual_sha, "existed_before": existed,
            })
            continue

        try:
            os.makedirs(os.path.dirname(dst_abs) or ".", exist_ok=True)
            with open(dst_abs, "wb") as f:
                f.write(blob)
        except OSError as e:
            out.append({
                "src": src, "dst": dst_rel, "action": "write-failed",
                "error": str(e),
            })
            continue

        out.append({
            "src": src, "dst": dst_rel,
            "action": "overwrote" if existed else "installed",
            "size": size, "sha256": actual_sha, "existed_before": existed,
        })
    return out


def _summarize(manifest_result: list[dict]) -> dict:
    """Per-action counts so the LLM can render a one-line summary."""
    summary: dict[str, int] = {}
    for r in manifest_result:
        summary[r["action"]] = summary.get(r["action"], 0) + 1
    return summary


# ── Status (what's already installed) ────────────────────────────────────

def _status_local(home: str) -> dict:
    """Report what looks like rappter-distro state currently on disk."""
    checks = {
        "kernel_present": os.path.isfile(_brainstem_kernel_path(home)),
        "kernel_version": _read_kernel_version(home),
        "boot_py": os.path.isfile(os.path.join(home, "utils", "boot.py")),
        "organs_dir": os.path.isdir(os.path.join(home, "utils", "organs")),
        "senses_dir": os.path.isdir(os.path.join(home, "utils", "senses")),
        "rich_ui": False,
        "rappter_agents_dir": os.path.isdir(os.path.join(home, "agents", "@rappter")),
    }
    # The distro's rich index.html is ~223 KB; grail's is much smaller.
    idx = os.path.join(home, "index.html")
    if os.path.isfile(idx):
        try:
            checks["rich_ui"] = os.path.getsize(idx) > 100_000
        except OSError:
            checks["rich_ui"] = False

    def _count(p: str, suffix: str) -> int:
        if not os.path.isdir(p):
            return 0
        return sum(1 for n in os.listdir(p) if n.endswith(suffix))

    checks["organ_count"] = _count(os.path.join(home, "utils", "organs"), "_organ.py")
    checks["sense_count"] = _count(os.path.join(home, "utils", "senses"), "_sense.py")
    checks["rappter_agent_count"] = _count(
        os.path.join(home, "agents", "@rappter"), ".py"
    )

    checks["distro_installed"] = (
        checks["boot_py"]
        and checks["organs_dir"]
        and checks["senses_dir"]
        and checks["rich_ui"]
    )
    return checks


# ── Top-level orchestration ──────────────────────────────────────────────

def install_distro(
    *,
    brainstem_home: Optional[str] = None,
    branch: str = DEFAULT_BRANCH,
    repo: str = DISTRO_REPO,
    source_dir: Optional[str] = None,
    manifest: Optional[dict] = None,
    fetcher: Optional[Callable[[str], bytes]] = None,
    dry_run: bool = False,
) -> dict:
    """Pull the distro from raw.githubusercontent.com (or a test override)
    and lay it down on the brainstem at `brainstem_home`.

    Source resolution priority (highest first):
      1. source_dir   — read everything from a local checkout (no network,
                        no manifest needed). Used by the source-of-truth
                        test and as a no-network install path for dev.
      2. manifest +/- fetcher — caller supplies a pre-parsed manifest dict
                        and (optionally) a fetcher callable. The fetcher
                        gets `src` and returns bytes. Used by tests that
                        want to drive the full manifest pipeline without
                        hitting the network.
      3. fetcher only — caller supplies a fetcher; agent uses it to GET
                        "MANIFEST.json" first, then each file.
      4. network      — default: build a fetcher against
                        raw.githubusercontent.com/<repo>/<branch>.

    Never raises. All failures are reported in the returned dict.
    """
    home = brainstem_home or _brainstem_home()
    result: dict = {
        "ok": False,
        "action": "dry-run" if dry_run else "install",
        "brainstem_home": home,
        "repo": repo,
        "branch": branch,
        "source": None,
        "kernel_version": None,
        "files_installed": 0,
        "manifest": [],
        "summary": {},
        "note": "",
        "post_install": f"python {os.path.join(home, 'utils', 'boot.py')}",
        "error": None,
    }

    ok, msg = _verify_kernel_present(home)
    if not ok:
        result["error"] = msg
        return result
    result["kernel_version"] = _read_kernel_version(home)

    # Source 1: local checkout (walks LAYOUT, no manifest needed).
    if source_dir is not None:
        result["source"] = "dir"
        try:
            manifest_built = build_manifest(source_dir, branch=branch)
        except Exception as e:
            result["error"] = f"could not build manifest from source_dir: {e}"
            return result
        # Bytes come from disk via a checkout-local fetcher.
        def _dir_fetcher(src: str) -> bytes:
            with open(os.path.join(source_dir, src), "rb") as f:
                return f.read()
        manifest = manifest_built
        fetcher = _dir_fetcher

    else:
        # Build the fetcher if caller didn't supply one.
        if fetcher is None:
            result["source"] = "network"
            fetcher = _network_fetcher(repo, branch)
        else:
            result["source"] = "injected"

        # If no manifest passed, fetch MANIFEST.json via the fetcher.
        if manifest is None:
            try:
                manifest_bytes = fetcher("MANIFEST.json")
            except urllib.error.URLError as e:
                result["error"] = f"could not fetch MANIFEST.json: {e}"
                return result
            except Exception as e:
                result["error"] = f"could not fetch MANIFEST.json: {e}"
                return result
            try:
                manifest = json.loads(manifest_bytes.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as e:
                result["error"] = f"MANIFEST.json is not valid JSON: {e}"
                return result

    try:
        _validate_manifest(manifest)
    except PermissionError as e:
        result["error"] = str(e)
        return result
    except ValueError as e:
        result["error"] = str(e)
        return result

    install_result = _apply_manifest(manifest, home, fetcher, dry_run=dry_run)
    result["manifest"] = install_result
    result["summary"] = _summarize(install_result)

    installed = result["summary"].get("installed", 0) + result["summary"].get("overwrote", 0)
    would = result["summary"].get("would-install", 0)
    failed = (
        result["summary"].get("fetch-failed", 0)
        + result["summary"].get("sha-mismatch", 0)
        + result["summary"].get("write-failed", 0)
    )

    result["files_installed"] = (would if dry_run else installed)
    result["ok"] = failed == 0 and (installed + would) > 0

    if not result["ok"]:
        result["error"] = (
            f"{failed} file(s) failed; see manifest for details"
            if failed else "no files were processed"
        )
        return result

    if dry_run:
        result["note"] = (
            f"dry-run: {would} file(s) would be installed onto kernel "
            f"v{result['kernel_version']} at {home}"
        )
    else:
        result["note"] = (
            f"installed {installed} file(s) onto kernel "
            f"v{result['kernel_version']} at {home}. "
            f"start the organism with: {result['post_install']}"
        )
    return result


def check() -> dict:
    """Read-only: is a kernel present, and what's its version?"""
    home = _brainstem_home()
    ok, msg = _verify_kernel_present(home)
    return {
        "ok": ok,
        "brainstem_home": home,
        "kernel_version": _read_kernel_version(home) if ok else None,
        "note": msg,
        "manifest_url": _raw_url(DISTRO_REPO, DEFAULT_BRANCH, "MANIFEST.json"),
    }


def status() -> dict:
    """Report what's already installed locally."""
    home = _brainstem_home()
    return {"brainstem_home": home, "checks": _status_local(home)}


# ── Agent class ──────────────────────────────────────────────────────────

class InstallDistroAgent(BasicAgent):
    """Hot-loaded agent that installs the rappter-distro over a grail kernel
    by fetching files from raw.githubusercontent.com."""

    name = "install_rappter_distro"

    metadata = {
        "name": "install_rappter_distro",
        "description": (
            "Install the rappter-distro (organs, senses, lib/, rich UI, "
            "@rappter agents) on top of the grail brainstem this agent is "
            "loaded into. Fetches a MANIFEST.json and then each file from "
            "raw.githubusercontent.com/kody-w/rappter-distro/<branch>/, "
            "verifies sha256, and lays the files down per install.sh's "
            "layout. Always run action='check' or action='dry-run' first "
            "to preview, then action='install' with confirm=true."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["check", "status", "dry-run", "install"],
                    "description": (
                        "'check'   = verify a kernel is present (read-only). "
                        "'status'  = report what's already installed. "
                        "'dry-run' = fetch + verify hashes, write nothing. "
                        "'install' = apply the manifest. Requires confirm=true."
                    ),
                },
                "confirm": {
                    "type": "boolean",
                    "default": False,
                    "description": (
                        "Required true for action='install'. Without it, "
                        "install refuses and returns a dry-run preview instead."
                    ),
                },
                "branch": {
                    "type": "string",
                    "default": DEFAULT_BRANCH,
                    "description": (
                        "Git branch of kody-w/rappter-distro to install from. "
                        f"Defaults to '{DEFAULT_BRANCH}'."
                    ),
                },
            },
            "required": ["action"],
        },
    }

    def perform(
        self,
        action: str = "check",
        confirm: bool = False,
        branch: str = DEFAULT_BRANCH,
        **kwargs,
    ) -> str:
        if action == "check":
            return json.dumps(check())
        if action == "status":
            return json.dumps(status())
        if action == "dry-run":
            return json.dumps(install_distro(branch=branch, dry_run=True))
        if action == "install":
            if not confirm:
                preview = install_distro(branch=branch, dry_run=True)
                return json.dumps({
                    "ok": False,
                    "error": "confirmation required",
                    "hint": "set confirm=true to proceed with the install",
                    "preview": preview,
                })
            return json.dumps(install_distro(branch=branch, dry_run=False))
        return json.dumps({
            "ok": False,
            "error": f"unknown action: {action!r}",
            "valid_actions": ["check", "status", "dry-run", "install"],
        })


# ── Standalone CLI ───────────────────────────────────────────────────────
#
# `python install_distro_agent.py --build-manifest [--src .]` — write
# MANIFEST.json against a local checkout. Used in CI / dev to refresh the
# manifest the agent ships against.
#
# `python install_distro_agent.py [--check|--status|--dry-run|--confirm]` —
# run the same flows as the agent but without the brainstem in the loop.

def _main(argv: list[str]) -> int:
    branch = DEFAULT_BRANCH
    dry_run = False
    do_check = False
    do_status = False
    do_build = False
    confirm = False
    src = "."
    out_path: Optional[str] = None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--dry-run":
            dry_run = True
        elif a == "--check":
            do_check = True
        elif a == "--status":
            do_status = True
        elif a == "--build-manifest":
            do_build = True
        elif a == "--confirm":
            confirm = True
        elif a == "--branch" and i + 1 < len(argv):
            branch = argv[i + 1]
            i += 1
        elif a == "--src" and i + 1 < len(argv):
            src = argv[i + 1]
            i += 1
        elif a == "--out" and i + 1 < len(argv):
            out_path = argv[i + 1]
            i += 1
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            print(f"unknown arg: {a}", file=sys.stderr)
            return 2
        i += 1

    if do_build:
        manifest = build_manifest(src, branch=branch)
        text = json.dumps(manifest, indent=2) + "\n"
        if out_path:
            with open(out_path, "w", encoding="utf-8") as f:
                f.write(text)
            print(f"wrote {out_path} ({len(manifest['files'])} files)")
        else:
            print(text)
        return 0

    if do_check:
        print(json.dumps(check(), indent=2))
        return 0
    if do_status:
        print(json.dumps(status(), indent=2))
        return 0
    if not dry_run and not confirm:
        print(
            "refusing to install without --confirm. "
            "(re-run with --dry-run to preview, or add --confirm to apply.)",
            file=sys.stderr,
        )
        return 2
    out = install_distro(branch=branch, dry_run=dry_run)
    print(json.dumps(out, indent=2))
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
