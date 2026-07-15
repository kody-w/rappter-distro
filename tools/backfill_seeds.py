"""backfill_seeds — bring already-planted doors into Article XLVI compliance.

Per the operator: "we can retroactively backfill what we created to make
them compliant... don't do all of these exception things... let's get it
right from the beginning."

This script walks the 15 known kody-w/* doors planted before the
ESTATE_SPEC + Article XLVI lock-in (2026-05-09) and brings each one into
spec compliance:

  1. Validate the existing rappid.json via door_from_rappid(). If invalid
     (the sim-art-collective @local/* case is the canonical example),
     REISSUE the rappid using BLAKE2b(owner/repo) + push the new
     rappid.json + regenerate the holocard / avatar / summon QR.
  2. Ensure facets.json exists (Door URL Set §9). Empty-but-valid.
  3. Ensure .nojekyll exists at root.
  4. For neighborhood gates: ensure members.json exists.
  5. For twins: ensure members.json exists (empty by spec).
  6. Ensure README.md exists.

Idempotent: each PUT looks up the existing file's sha first, so re-runs
are no-ops once compliance is reached.

USAGE:
    python3 tools/backfill_seeds.py --dry-run     # see what would change
    python3 tools/backfill_seeds.py --apply       # make the changes
    python3 tools/backfill_seeds.py --apply --only echo-brainstem  # one seed

Per memory: "User-facing fixes ship via the install one-liner only" —
this is operator-tooling for spec migration, not a user-facing path.
The operator runs it once after Article XLVI ships.

Out of scope (intentional):
- Private repos (twin-private) — Pages-not-supported; backfill skips with reason.
- Repos that 404 over raw (e.g. microsoft-se-team-neighborhood currently) —
  reported as unreachable; manual investigation needed.
- Twin's bonds.json — not part of the Door URL Set; backfill leaves it alone.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# Add repo's tools/ to sys.path so we can import door_address + holo_card_generator
_REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_REPO_ROOT / "tools"))

from door_address import door_from_rappid, InvalidRappidError  # noqa: E402
import holo_card_generator as hcg  # noqa: E402


# The 15 seeds we know about (planted before Article XLVI). Owner is always kody-w.
# kind is the SPEC kind (twin/neighborhood). The presence/correctness of each
# canonical file is verified per-seed at runtime — this list is just the inventory.
SEEDS = [
    ("kody-w", "echo-brainstem",                  "twin",         "Echo"),
    ("kody-w", "lumen-brainstem",                 "twin",         "Lumen"),
    ("kody-w", "tide-brainstem",                  "twin",         "Tide"),
    ("kody-w", "sim-demo-twin",                   "twin",         "Sim Demo Twin"),
    ("kody-w", "twin",                            "twin",         "Twin"),
    ("kody-w", "twin-private",                    "twin",         "Twin (private)"),
    ("kody-w", "kody-twin",                       "twin",         "Kody Twin"),
    ("kody-w", "wildhaven-ai-homes-twin",         "twin",         "Wildhaven AI Homes Twin"),
    ("kody-w", "pkstop-the-bean",                 "neighborhood", "Pkstop — The Bean"),
    ("kody-w", "pkstop-national-mall",            "neighborhood", "Pkstop — National Mall"),
    ("kody-w", "pkstop-central-park-bandshell",   "neighborhood", "Pkstop — Central Park Bandshell"),
    ("kody-w", "pkstop-santa-monica-pier",        "neighborhood", "Pkstop — Santa Monica Pier"),
    ("kody-w", "pkstop-pike-place-market",        "neighborhood", "Pkstop — Pike Place Market"),
    ("kody-w", "rapp-test-neighbor",              "neighborhood", "RAPP Test Neighbor"),
    ("kody-w", "sim-art-collective",              "neighborhood", "Sim Art Collective"),
    ("kody-w", "microsoft-se-team-neighborhood",  "neighborhood", "Microsoft SE Team"),
]


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _gh(args: list[str]) -> tuple[int, str, str]:
    p = subprocess.run(["gh", *args], capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def _raw_fetch(owner: str, repo: str, path: str, timeout: int = 8) -> tuple[int, str]:
    """Fetch <owner>/<repo>/main/<path> via GitHub API (no CDN cache).

    Returns (http_code, body). raw.githubusercontent.com caches aggressively
    (~5min TTL), so consecutive dry-runs would show stale state. The API
    serves fresh content every call. Operator-tooling assumption: gh auth
    is configured (the operator running backfills always has it).
    """
    rc, out, _ = _gh(["api", f"/repos/{owner}/{repo}/contents/{path}"])
    if rc != 0:
        return 404, ""
    try:
        d = json.loads(out)
        b64 = d.get("content", "").replace("\n", "")
        if not b64:
            return 200, ""
        return 200, base64.b64decode(b64).decode("utf-8", errors="replace")
    except Exception:
        return 200, ""


def _file_exists_in_repo(owner: str, repo: str, path: str) -> bool:
    code, _ = _raw_fetch(owner, repo, path)
    return code == 200


def _put_file(owner: str, repo: str, path: str, content_bytes: bytes,
              message: str, dry_run: bool) -> tuple[bool, str]:
    """Idempotent PUT — looks up existing sha so updates work, creates work."""
    if dry_run:
        return True, f"DRY-RUN would PUT {path} ({len(content_bytes)}B)"

    full = f"/repos/{owner}/{repo}/contents/{path}"
    rc_get, out_get, _ = _gh(["api", full])
    sha_args: list[str] = []
    if rc_get == 0:
        try:
            sha = json.loads(out_get).get("sha", "")
            if sha:
                sha_args = ["-f", f"sha={sha}"]
        except Exception:
            pass
    b64 = base64.b64encode(content_bytes).decode("ascii")
    rc_put, _, err = _gh([
        "api", "-X", "PUT", full,
        "-f", f"message={message}",
        "-f", f"content={b64}",
        *sha_args,
    ])
    if rc_put == 0:
        return True, f"wrote {path} ({len(content_bytes)}B)"
    return False, f"PUT failed: {err.strip()[:160]}"


def _canonical_rappid(owner: str, repo: str, kind: str = None) -> str:
    """Mint a canonical rappid for an (owner, repo) — RAPP spec §6.2, keyless.

    `rappid:@<owner>/<slug>:<64hex>` where owner/repo locate the door and the
    64-hex tail is ``Hb("rapp/1:rappid", uuid4_bytes)`` — domain separated,
    minted once. It is NEVER ``blake2b/sha256("owner/repo")``: hashing a name
    into an address is the cardinal sin the spec exists to end (owner/slug in
    the string already locate the door; the hash is identity, not a name digest).
    `kind` lives in the rappid.json record, not the string, and is ignored here.
    Callers are idempotent via the stored rappid.json (mint-once), so a fresh
    random tail per un-minted repo is correct.
    """
    import uuid
    tail = hashlib.sha256(b"rapp/1:rappid\n" + uuid.uuid4().bytes).hexdigest()
    return f"rappid:@{owner}/{repo}:{tail}"


def _build_rappid_json(rappid: str, owner: str, repo: str, kind: str,
                       display_name: str, parent_rappid: str | None = None) -> bytes:
    return (json.dumps({
        "schema": "rapp/1",
        "rappid": rappid,
        "kind": kind,
        "name": repo,
        "display_name": display_name,
        "github": f"https://github.com/{owner}/{repo}",
        "url": f"https://{owner}.github.io/{repo}/",
        "parent_rappid": parent_rappid,
        "parent_repo": "https://github.com/kody-w/RAPP",
        "planted_by": owner,
        "planted_at": _now_iso(),
        "kernel_version": "0.6.0",
        "_planted_by_agent": "backfill_seeds",
        "_backfilled_at": _now_iso(),
        "_backfill_reason": "Article XLVI compliance pass",
    }, indent=2) + "\n").encode()


def _build_facets_json(rappid: str) -> bytes:
    return (json.dumps({
        "schema": "rapp-facets/1.0",
        "rappid": rappid,
        "facets": {},
        "_note": "Declare published capabilities here over time. See specs/SPEC.md §3.",
    }, indent=2) + "\n").encode()


def _build_members_gate(owner: str, repo: str, rappid: str) -> bytes:
    return (json.dumps({
        "schema": "rapp-neighborhood-members/1.0",
        "neighborhood": f"{owner}/{repo}",
        "updated_at": _now_iso(),
        "open_to_anyone": True,
        "members": [{
            "rappid": rappid, "github": owner, "role": "founder",
            "joined_at": _now_iso(),
            "_note": f"The operator who planted this {repo}.",
        }],
    }, indent=2) + "\n").encode()


def _build_members_twin(owner: str, repo: str) -> bytes:
    return (json.dumps({
        "schema": "rapp-neighborhood-members/1.0",
        "neighborhood": f"{owner}/{repo}",
        "updated_at": _now_iso(),
        "open_to_anyone": False,
        "members": [],
        "_note": f"Twins have no members; this twin's operator is {owner}.",
    }, indent=2) + "\n").encode()


def _build_minimal_readme(owner: str, repo: str, rappid: str, kind: str,
                          display_name: str) -> bytes:
    return (
        f"# {display_name}\n\n"
        f"A planted RAPP {kind} ({'front door' if kind == 'twin' else 'gate'}).\n\n"
        f"## Identity\n\n"
        f"- **Rappid:** `{rappid}`\n"
        f"- **Kind:** `{kind}`\n"
        f"- **Spec:** [`specs/SPEC.md`](./specs/SPEC.md)\n\n"
        f"## Front door\n\n"
        f"Visit https://{owner}.github.io/{repo}/ to chat with this {'twin' if kind == 'twin' else 'gate'}.\n\n"
        f"---\n*Backfilled to spec on {_now_iso()} per Article XLVI.*\n"
    ).encode()


# ─── Backfill plan computation ────────────────────────────────────────────

def plan_for_seed(owner: str, repo: str, kind: str, display_name: str) -> dict:
    """Return a per-seed plan: {repo, status, actions[]} where actions describe
    the PUTs that compliance requires. Read-only — does not mutate anything."""
    plan: dict = {
        "repo":         f"{owner}/{repo}",
        "kind":         kind,
        "actions":      [],
        "skipped":      None,
    }

    # 1. rappid.json — fetch + validate
    code, body = _raw_fetch(owner, repo, "rappid.json")
    if code == 0 or code == 404:
        # Repo unreachable via raw — could be private (twin-private), 404 (microsoft-se), etc.
        plan["skipped"] = f"rappid.json unreachable (HTTP {code or 'no-response'}); investigate manually"
        return plan

    rappid_existing = ""
    rappid_valid    = False
    try:
        rappid_existing = json.loads(body).get("rappid", "")
        if rappid_existing:
            door_from_rappid(rappid_existing)
            rappid_valid = True
    except Exception:
        pass

    canonical_rappid = _canonical_rappid(owner, repo, kind)

    if not rappid_valid:
        # Reissue: rappid.json + card.json + holo.svg + holo-qr.svg all need refresh
        plan["actions"].append({
            "path": "rappid.json",
            "reason": f"existing rappid invalid or missing ({rappid_existing[:60] or 'none'!s}) — reissue with canonical",
            "new_rappid": canonical_rappid,
        })
        seed = hcg.derive_seed(canonical_rappid)
        plan["actions"].append({
            "path": "card.json",
            "reason": "regenerate holocard for reissued rappid",
            "_seed": seed,
        })
        plan["actions"].append({
            "path": "holo.svg",
            "reason": "regenerate avatar for reissued rappid",
            "_seed": seed,
        })
        plan["actions"].append({
            "path": "holo-qr.svg",
            "reason": "regenerate summon QR for reissued rappid",
            "_seed": seed,
        })
        rappid_for_compliance = canonical_rappid
    else:
        rappid_for_compliance = rappid_existing

    # 2. facets.json — required for ALL doors per Door URL Set §9
    if not _file_exists_in_repo(owner, repo, "facets.json"):
        plan["actions"].append({"path": "facets.json", "reason": "Door URL Set §9 — required"})

    # 3. .nojekyll — required so GitHub Pages serves index.html literally
    if not _file_exists_in_repo(owner, repo, ".nojekyll"):
        plan["actions"].append({"path": ".nojekyll", "reason": "Pages publishing requirement"})

    # 4. members.json — required for ALL doors (empty for twins) per Door URL Set §8
    if not _file_exists_in_repo(owner, repo, "members.json"):
        plan["actions"].append({
            "path": "members.json",
            "reason": "Door URL Set §8 — required (empty for twins)",
        })

    # 5. README.md — required (canonical browseable doc)
    if not _file_exists_in_repo(owner, repo, "README.md"):
        plan["actions"].append({"path": "README.md", "reason": "human-readable description"})

    plan["rappid_for_compliance"] = rappid_for_compliance
    return plan


def apply_plan(plan: dict, kind: str, display_name: str, dry_run: bool) -> dict:
    """Execute the actions in a plan. Returns {repo, results: [{path, ok, msg}]}."""
    results: list[dict] = []
    if plan.get("skipped"):
        return {"repo": plan["repo"], "skipped": plan["skipped"], "results": []}

    owner, repo = plan["repo"].split("/", 1)
    rappid = plan["rappid_for_compliance"]

    for action in plan["actions"]:
        path = action["path"]
        reason = action["reason"]
        try:
            if path == "rappid.json":
                content = _build_rappid_json(action["new_rappid"], owner, repo, kind, display_name)
                rappid = action["new_rappid"]
            elif path == "card.json":
                seed = action["_seed"]
                content = (json.dumps(
                    hcg.generate_holo_card(rappid=rappid, kind=kind, owner=owner, name=repo,
                                            display_name=display_name,
                                            gate_url=f"https://{owner}.github.io/{repo}/"),
                    indent=2) + "\n").encode()
            elif path == "holo.svg":
                content = hcg.generate_avatar_svg(action["_seed"], kind=kind).encode()
            elif path == "holo-qr.svg":
                content = hcg.generate_summon_qr_svg(action["_seed"],
                                                      f"https://{owner}.github.io/{repo}/").encode()
            elif path == "facets.json":
                content = _build_facets_json(rappid)
            elif path == ".nojekyll":
                content = b""
            elif path == "members.json":
                content = (_build_members_gate(owner, repo, rappid) if kind != "twin"
                           else _build_members_twin(owner, repo))
            elif path == "README.md":
                content = _build_minimal_readme(owner, repo, rappid, kind, display_name)
            else:
                results.append({"path": path, "ok": False, "msg": f"unknown action: {reason}"})
                continue

            ok, msg = _put_file(owner, repo, path, content,
                                f"backfill: {reason} (Article XLVI)", dry_run)
            results.append({"path": path, "ok": ok, "msg": msg, "reason": reason})
        except Exception as e:
            results.append({"path": path, "ok": False, "msg": f"build failed: {e}"})

    return {"repo": plan["repo"], "results": results,
            "compliant_rappid": rappid}


# ─── CLI ──────────────────────────────────────────────────────────────────

def patch_parents(seeds: list, operator_rappid: str, dry_run: bool) -> dict:
    """Standalone --patch-parents pass: ensure every seed's rappid.json carries
    parent_rappid = operator_rappid (Article XLVI.6). Idempotent: skip seeds
    that already have it set correctly. Used to retroactively fill the
    network's edges so tools/rebuild_estate.py can walk back to operators."""
    # Validate the operator rappid before touching anything
    door_from_rappid(operator_rappid)
    report = {
        "schema":    "rapp-backfill-report/1.0",
        "mode":      "DRY-RUN" if dry_run else "APPLY",
        "operation": "patch-parents",
        "operator_rappid": operator_rappid,
        "started_at": _now_iso(),
        "results": [],
        "totals": {"already_correct": 0, "patched": 0, "unreachable": 0, "failed": 0},
    }
    for owner, repo, _kind, _display in seeds:
        print(f"  · patching parent_rappid on {owner}/{repo}…", file=sys.stderr)
        code, body = _raw_fetch(owner, repo, "rappid.json")
        if code != 200 or not body:
            report["results"].append({"repo": f"{owner}/{repo}", "status": "unreachable",
                                       "code": code})
            report["totals"]["unreachable"] += 1
            continue
        try:
            d = json.loads(body)
        except Exception as e:
            report["results"].append({"repo": f"{owner}/{repo}", "status": "parse_error",
                                       "error": str(e)[:100]})
            report["totals"]["failed"] += 1
            continue
        if d.get("parent_rappid") == operator_rappid:
            report["results"].append({"repo": f"{owner}/{repo}", "status": "already_correct"})
            report["totals"]["already_correct"] += 1
            continue
        d["parent_rappid"] = operator_rappid
        d.setdefault("_backfill_reason_parent", "Article XLVI.6 — parent_rappid for rebuild")
        new_body = (json.dumps(d, indent=2) + "\n").encode()
        ok, msg = _put_file(owner, repo, "rappid.json", new_body,
                             "backfill: set parent_rappid (Article XLVI.6)", dry_run)
        if ok:
            report["results"].append({"repo": f"{owner}/{repo}", "status": "patched", "msg": msg})
            report["totals"]["patched"] += 1
        else:
            report["results"].append({"repo": f"{owner}/{repo}", "status": "put_failed", "msg": msg})
            report["totals"]["failed"] += 1
    report["finished_at"] = _now_iso()
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--dry-run", action="store_true", help="report planned actions; do not write")
    ap.add_argument("--apply",   action="store_true", help="execute the plan via gh api PUTs")
    ap.add_argument("--only",    default="", help="restrict to a single seed by repo name")
    ap.add_argument("--owner",   default="", help="restrict to seeds with this owner")
    ap.add_argument("--patch-parents", default="",
                    help="set parent_rappid=<this rappid> on every seed's rappid.json. "
                         "Used to retroactively backfill the planter→door pointer needed "
                         "by tools/rebuild_estate.py (Article XLVI.6).")
    args = ap.parse_args()

    if not args.dry_run and not args.apply:
        print("error: must pass --dry-run or --apply", file=sys.stderr)
        return 2

    seeds = SEEDS
    if args.only:
        seeds = [s for s in seeds if s[1] == args.only]
    if args.owner:
        seeds = [s for s in seeds if s[0] == args.owner]

    if not seeds:
        print("error: no seeds matched filter", file=sys.stderr)
        return 2

    # --patch-parents pass: just fix parent_rappid; skip the full compliance flow
    if args.patch_parents:
        report = patch_parents(seeds, args.patch_parents, dry_run=args.dry_run)
        print(json.dumps(report, indent=2))
        return 0 if report["totals"]["failed"] == 0 else 1

    overall = {
        "schema": "rapp-backfill-report/1.0",
        "started_at": _now_iso(),
        "mode": "DRY-RUN" if args.dry_run else "APPLY",
        "seeds": [],
        "totals": {"compliant_already": 0, "actions_planned": 0, "actions_applied": 0,
                   "skipped": 0, "failed_actions": 0},
    }

    for owner, repo, kind, display_name in seeds:
        print(f"  · scanning {owner}/{repo} ({kind})…", file=sys.stderr)
        plan = plan_for_seed(owner, repo, kind, display_name)
        if plan.get("skipped"):
            overall["seeds"].append({"repo": plan["repo"], "skipped": plan["skipped"], "results": []})
            overall["totals"]["skipped"] += 1
            continue
        if not plan["actions"]:
            overall["seeds"].append({"repo": plan["repo"], "results": [], "compliant": True})
            overall["totals"]["compliant_already"] += 1
            continue
        overall["totals"]["actions_planned"] += len(plan["actions"])
        result = apply_plan(plan, kind, display_name, dry_run=args.dry_run)
        overall["seeds"].append(result)
        for r in result.get("results", []):
            if r["ok"]:
                overall["totals"]["actions_applied"] += 1
            else:
                overall["totals"]["failed_actions"] += 1

    overall["finished_at"] = _now_iso()
    print(json.dumps(overall, indent=2))
    return 0 if overall["totals"]["failed_actions"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
