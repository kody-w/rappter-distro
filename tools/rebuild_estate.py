"""rebuild_estate — reconstruct an operator's estate from pure GitHub raw data.

Per the operator: "and can this be completely rebuilt by basically reading the
estate from the global githubrawuser data across this full network to basically
rebuild this data structure from scratch if we lose it... that's the point..."

This is the disaster-recovery floor for the Estate Spec (Article XLVI.6).
Given just a GitHub handle, walks public data and reconstructs:

  created[]  — every door this operator planted (filtered by parent_rappid)
  member[]   — every gate this operator joined (filtered by their rappid in members.json)

The estate file becomes provably a CACHE of facts the network already publishes,
not the source of truth. Local + published-mirror are conveniences; this tool
proves the relationships are recomputable from raw URLs.

USAGE:
    python3 tools/rebuild_estate.py --handle <gh>                # dry-run, prints
    python3 tools/rebuild_estate.py --handle <gh> --apply        # write to ~/.brainstem/estate.json
    python3 tools/rebuild_estate.py --handle <gh> --out /tmp/x   # write elsewhere
    python3 tools/rebuild_estate.py --handle <gh> --operator-rappid <rappid>
                                                                  # skip discovery, use this one

DISCOVERY:
  1. Operator rappid:
     a. Try ~/.brainstem/rappid.json locally (fast path)
     b. Try conventional repos: <handle>/<handle>-twin, <handle>/<handle>-brainstem,
        <handle>/.brainstem, <handle>/kody-twin (operator-specific patterns)
     c. Walk all <handle>/* repos via gh repo list, fetch each rappid.json,
        derive operator rappid by taking ANY twin-kind rappid + swapping the
        kind token to "operator"
     d. Fail with operator-action message ("pass --operator-rappid <rappid>")

  2. created[] discovery:
     gh repo list <handle> --limit 200 → for each repo with a fetchable
     rappid.json → if parent_rappid matches operator → include it.

  3. member[] discovery:
     gh search code "<operator-rappid>" filename:members.json → for each hit,
     fetch the gate's rappid.json to get the gate's own rappid → include it.

Operator-mediated by default: default mode is dry-run; --apply writes the
file. Idempotent: safe to re-run.

Stdlib + gh CLI only.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# Add repo's tools/ to sys.path so we can import door_address
_REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_REPO_ROOT / "tools"))

from door_address import door_from_rappid, InvalidRappidError, estate_url  # noqa: E402


_ESTATE_SCHEMA = "rapp-estate/1.1"
_FETCH_TIMEOUT = 8


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _gh(args: list[str]) -> tuple[int, str, str]:
    p = subprocess.run(["gh", *args], capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def _gh_get_json(path: str) -> dict | list | None:
    rc, out, _ = _gh(["api", path])
    if rc != 0:
        return None
    try:
        return json.loads(out)
    except Exception:
        return None


def _raw_fetch_json(owner: str, repo: str, path: str) -> dict | None:
    """Fetch a JSON file via the GitHub API (no CDN cache)."""
    d = _gh_get_json(f"/repos/{owner}/{repo}/contents/{path}")
    if not d or not isinstance(d, dict):
        return None
    try:
        b64 = d.get("content", "").replace("\n", "")
        if not b64:
            return None
        body = base64.b64decode(b64).decode("utf-8", errors="replace")
        return json.loads(body)
    except Exception:
        return None


# ─── Operator-rappid discovery ────────────────────────────────────────────

def _try_local_brainstem() -> str:
    """If running on the operator's machine, ~/.brainstem/rappid.json is the
    fastest path. Returns "" if not present or malformed."""
    p = Path(os.path.expanduser("~/.brainstem/rappid.json"))
    if not p.exists():
        return ""
    try:
        d = json.loads(p.read_text())
        rappid = d.get("rappid", "")
        if isinstance(rappid, str) and ":@" in rappid:  # self-locating (canonical §6.1)
            return rappid
    except Exception:
        pass
    return ""


def _try_conventional_repos(handle: str) -> str:
    """Probe conventional anchor repos for an operator rappid. Returns the
    derived operator rappid (kind-swapped if we found a twin) or ""."""
    candidates = [
        f"{handle}-twin",
        f"{handle}-brainstem",
        ".brainstem",
        "kody-twin",   # legacy convention used by this codebase's operator
    ]
    for repo in candidates:
        d = _raw_fetch_json(handle, repo, "rappid.json")
        if not d:
            continue
        rappid = d.get("rappid", "")
        if not isinstance(rappid, str) or ":@" not in rappid:  # self-locating (canonical §6.1)
            continue
        # Validate the string; kind lives in the RECORD now (canonical §6.1),
        # not the rappid string — so read d["kind"], never munge the string.
        try:
            door_from_rappid(rappid)
        except InvalidRappidError:
            continue
        record_kind = d.get("kind")
        if record_kind in ("operator", "twin"):
            # A twin record's rappid IS a valid identity and doubles as the
            # operator's front door — return it as-is (no fabricated operator id).
            return rappid
    return ""


def _scan_handle_for_operator(handle: str) -> str:
    """Last-ditch: walk every <handle>/* repo, look for a twin/operator rappid."""
    repos = _gh_get_json(f"/users/{handle}/repos?per_page=100&type=owner")
    if not isinstance(repos, list):
        return ""
    for r in repos:
        if not isinstance(r, dict) or r.get("fork"):
            continue
        name = r.get("name", "")
        if not name:
            continue
        d = _raw_fetch_json(handle, name, "rappid.json")
        if not d:
            continue
        rappid = d.get("rappid", "")
        if not isinstance(rappid, str):
            continue
        try:
            door_from_rappid(rappid)
        except InvalidRappidError:
            continue
        record_kind = d.get("kind")  # kind lives in the record, not the string
        if record_kind == "operator":
            return rappid
        if record_kind == "twin" and (handle in name or name in ("twin", "brainstem")):
            return rappid
    return ""


def discover_operator_rappid(handle: str) -> str:
    """Try every discovery path in order. Returns "" if none succeed."""
    for fn in (_try_local_brainstem, lambda: _try_conventional_repos(handle),
               lambda: _scan_handle_for_operator(handle)):
        rappid = fn()
        if rappid:
            try:
                door_from_rappid(rappid)
                return rappid
            except InvalidRappidError:
                continue
    return ""


# ─── created[] discovery ──────────────────────────────────────────────────

def _list_handle_repos(handle: str) -> list:
    """List all repos owned by handle. If handle matches the gh-authenticated
    user, uses /user/repos to include private repos too (operator-self path).
    Otherwise falls back to public-only /users/<handle>/repos."""
    auth_user = _gh_get_json("/user") or {}
    self_path = isinstance(auth_user, dict) and auth_user.get("login") == handle
    api_path = ("/user/repos?per_page=100&affiliation=owner"
                if self_path else
                f"/users/{handle}/repos?per_page=100&type=owner")
    rc, out, _ = _gh(["api", "--paginate", api_path])
    if rc != 0:
        return []
    # --paginate concatenates JSON arrays; parse them as a stream
    repos: list = []
    decoder = json.JSONDecoder()
    s = out.strip()
    pos = 0
    while pos < len(s):
        s_remaining = s[pos:].lstrip()
        if not s_remaining:
            break
        leading_ws = len(s) - pos - len(s_remaining)
        try:
            obj, end = decoder.raw_decode(s_remaining)
        except json.JSONDecodeError:
            break
        if isinstance(obj, list):
            # When using /user/repos, we may see repos owned by other accounts
            # the operator collaborates on — filter to only handle's repos.
            for r in obj:
                if isinstance(r, dict):
                    rowner = (r.get("owner") or {}).get("login", "")
                    if rowner == handle:
                        repos.append(r)
        pos += leading_ws + end
    return repos


def discover_created(handle: str, operator_rappid: str, on_progress=None) -> tuple[list, list]:
    """Walk handle's repos (public + private when self-auth). Return (created_entries, skipped_repos)."""
    repos = _list_handle_repos(handle)
    if not repos:
        return [], [{"reason": "no repos returned by gh"}]
    created = []
    skipped = []
    for r in repos:
        if not isinstance(r, dict) or r.get("fork"):
            continue
        name = r.get("name", "")
        if not name:
            continue
        if on_progress:
            on_progress(f"checking {handle}/{name}")
        d = _raw_fetch_json(handle, name, "rappid.json")
        if not d:
            skipped.append({"repo": name, "reason": "no rappid.json"})
            continue
        rappid = d.get("rappid", "")
        if not isinstance(rappid, str):
            skipped.append({"repo": name, "reason": "rappid not a string"})
            continue
        try:
            door_from_rappid(rappid)
        except InvalidRappidError as e:
            skipped.append({"repo": name, "reason": f"invalid rappid: {str(e)[:80]}"})
            continue
        if d.get("parent_rappid") != operator_rappid:
            skipped.append({"repo": name, "reason": "parent_rappid does not match operator"})
            continue
        created.append({
            "rappid":   rappid,
            "added_at": _now_iso(),
            "via":      "rebuild",
        })
    return created, skipped


# ─── member[] discovery ───────────────────────────────────────────────────

def discover_memberships(operator_rappid: str, on_progress=None) -> tuple[list, list]:
    """Use gh search code to find every members.json containing the operator
    rappid. Each hit is a gate the operator is a member of."""
    rc, out, err = _gh(["search", "code", operator_rappid, "filename:members.json",
                        "--limit", "100", "--json", "repository,path"])
    if rc != 0:
        return [], [{"reason": f"gh search code failed: {err.strip()[:200]}"}]
    try:
        hits = json.loads(out) if out.strip() else []
    except Exception:
        hits = []
    if not isinstance(hits, list):
        return [], [{"reason": f"unexpected gh search response shape: {type(hits).__name__}"}]
    member = []
    skipped = []
    seen = set()
    for hit in hits:
        if not isinstance(hit, dict):
            continue
        repo_obj = hit.get("repository", {}) or {}
        full = repo_obj.get("nameWithOwner") or repo_obj.get("name", "")
        if not full or "/" not in full:
            continue
        if full in seen:
            continue
        seen.add(full)
        owner, repo = full.split("/", 1)
        if on_progress:
            on_progress(f"checking gate {owner}/{repo}")
        # Verify the operator is actually listed in members.json (not just
        # mentioned somewhere in the file body — code search matches anywhere)
        members = _raw_fetch_json(owner, repo, "members.json")
        if not isinstance(members, dict):
            skipped.append({"repo": full, "reason": "couldn't fetch members.json"})
            continue
        listed = any(
            isinstance(m, dict) and m.get("rappid") == operator_rappid
            for m in members.get("members", [])
        )
        if not listed:
            skipped.append({"repo": full, "reason": "operator not in members[] (substring match only)"})
            continue
        # Get the gate's own rappid
        gate_meta = _raw_fetch_json(owner, repo, "rappid.json")
        if not isinstance(gate_meta, dict):
            skipped.append({"repo": full, "reason": "gate has no rappid.json"})
            continue
        gate_rappid = gate_meta.get("rappid", "")
        if not isinstance(gate_rappid, str):
            continue
        try:
            door_from_rappid(gate_rappid)
        except InvalidRappidError as e:
            skipped.append({"repo": full, "reason": f"gate rappid invalid: {str(e)[:60]}"})
            continue
        member.append({
            "rappid":   gate_rappid,
            "added_at": _now_iso(),
            "via":      "rebuild",
        })
    return member, skipped


# ─── Estate assembly ──────────────────────────────────────────────────────

def rebuild(handle: str, operator_rappid: str = "", on_progress=None) -> dict:
    """Top-level: discover operator, walk created/member, return spec-compliant estate."""
    if not operator_rappid:
        if on_progress:
            on_progress("discovering operator rappid…")
        operator_rappid = discover_operator_rappid(handle)
        if not operator_rappid:
            return {
                "schema": _ESTATE_SCHEMA, "ok": False,
                "error": (
                    f"could not discover operator rappid for {handle}. "
                    f"Pass --operator-rappid explicitly. The conventional anchors "
                    f"(<handle>-twin, <handle>-brainstem, .brainstem, kody-twin) "
                    f"and a full repo scan all came up empty."
                ),
            }
    # Validate one more time
    try:
        door_from_rappid(operator_rappid)
    except InvalidRappidError as e:
        return {"schema": _ESTATE_SCHEMA, "ok": False,
                "error": f"operator rappid invalid: {e}"}

    if on_progress:
        on_progress("walking handle's repos for created[]…")
    created, created_skipped = discover_created(handle, operator_rappid, on_progress)

    if on_progress:
        on_progress("searching for memberships in members.json files…")
    member, member_skipped = discover_memberships(operator_rappid, on_progress)

    return {
        "schema": _ESTATE_SCHEMA,
        "ok": True,
        "owner": {"rappid": operator_rappid, "github": handle},
        "created": created,
        "member":  member,
        "updated_at": _now_iso(),
        "_rebuild": {
            "tool":              "tools/rebuild_estate.py",
            "operator_rappid":   operator_rappid,
            "created_count":     len(created),
            "member_count":      len(member),
            "created_skipped":   created_skipped,
            "member_skipped":    member_skipped,
            "rebuilt_at":        _now_iso(),
            "public_url":        estate_url(handle),
        },
    }


# ─── CLI ──────────────────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--handle", required=True, help="GitHub handle to rebuild estate for")
    ap.add_argument("--operator-rappid", default="",
                    help="skip operator discovery; use this rappid as the operator's identity")
    ap.add_argument("--out", default="",
                    help="write estate.json here (default: print only — i.e. dry-run)")
    ap.add_argument("--apply", action="store_true",
                    help="write to ~/.brainstem/estate.json (overrides --out)")
    args = ap.parse_args()

    def _progress(msg: str) -> None:
        print(f"  · {msg}", file=sys.stderr)

    estate = rebuild(args.handle, args.operator_rappid, on_progress=_progress)

    # Strip the rebuild metadata if we're writing to a real estate file
    write_path = ""
    if args.apply:
        write_path = os.path.expanduser("~/.brainstem/estate.json")
    elif args.out:
        write_path = os.path.expanduser(args.out)

    if write_path and estate.get("ok"):
        clean = {k: v for k, v in estate.items() if k not in ("ok", "_rebuild")}
        os.makedirs(os.path.dirname(write_path), exist_ok=True)
        Path(write_path).write_text(json.dumps(clean, indent=2))
        estate["_rebuild"]["wrote_to"] = write_path

    print(json.dumps(estate, indent=2))
    return 0 if estate.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
