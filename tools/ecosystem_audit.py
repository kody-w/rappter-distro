#!/usr/bin/env python3
"""ecosystem_audit — Bond Pulse drift detector.

Walks every offspring listed in `pages/metropolis/index.json`, fetches
its canonical files (via fixture in --offline or via `gh api` →
`raw.githubusercontent.com` in --online), diffs against the per-kind
contract in `tools/ecosystem_contract.py`, and emits both a human report
(`pages/_audit/ecosystem-audit.md`) and a machine envelope
(`pages/_audit/ecosystem-audit.json`, schema `rapp-ecosystem-audit/1.0`).

Stdlib-only — runs from a fresh `git clone` with no pip install. Mirrors
`bond.py`'s discipline: the substrate health check can't depend on its
own installation succeeding.

Modes:
    --offline   (default; CI-safe) Use checked-in tests/fixtures/<name>{-seed,}/
    --online    Live network. Honors gh auth; falls back to raw.githubusercontent.com.
                Set ECOSYSTEM_AUDIT_ONLINE=1 to enable from env.
    --repo NAME Audit one offspring by name; default audits all entries
    --no-write  Print audit JSON to stdout; skip pages/_audit/ writes
    --strict    Exit 1 on drift_count > 0 (default: True)

Exit code: 0 if drift_count == 0, 1 otherwise.

The Bond Pulse heartbeat (`bond_rhythm_agent`) calls this script as a
subprocess and parses the JSON envelope. Any direct caller can also
`from ecosystem_audit import audit_ecosystem`.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

# Allow running as a script OR being imported
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from ecosystem_contract import (  # noqa: E402
    CONTRACTS, KERNEL_BASE_FILES, SEED_REQUIRED_AGENTS,
    kind_for_entry, contract_for_kind, all_kinds,
)


# ── constants ──────────────────────────────────────────────────────────────

REPO_ROOT = os.path.dirname(_HERE)  # tools/ → repo root
DEFAULT_METROPOLIS = os.path.join(REPO_ROOT, "pages", "metropolis", "index.json")
DEFAULT_AUDIT_OUT_DIR = os.path.join(REPO_ROOT, "pages", "_audit")
DEFAULT_FIXTURES_DIR = os.path.join(REPO_ROOT, "tests", "fixtures")
CACHE_DIR = os.path.expanduser("~/.brainstem/audit_cache")
USER_AGENT = "rapp-ecosystem-audit/1.0"
HTTP_TIMEOUT = 12.0

AUDIT_SCHEMA = "rapp-ecosystem-audit/1.0"

# Identity block sentinel — soul.md must contain this string per ANTIPATTERNS §4
IDENTITY_BLOCK_SENTINEL = "Identity"  # tolerant — matches "## Identity" or "## Identity — read this every turn"


# ── small helpers ──────────────────────────────────────────────────────────

def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_str(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def _ensure_cache():
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
    except OSError:
        pass


def _cache_key(url: str) -> str:
    return os.path.join(CACHE_DIR, _sha256_str(url)[:16] + ".bin")


def _cache_get(url: str) -> bytes | None:
    p = _cache_key(url)
    if not os.path.exists(p):
        return None
    try:
        with open(p, "rb") as f:
            return f.read()
    except OSError:
        return None


def _cache_put(url: str, body: bytes) -> None:
    _ensure_cache()
    try:
        with open(_cache_key(url), "wb") as f:
            f.write(body)
    except OSError:
        pass


# ── network fetch (online mode) ────────────────────────────────────────────

def _gh_api(path: str) -> dict | list | None:
    """Try gh CLI first (uses operator's auth + rate limit). Returns parsed JSON."""
    try:
        p = subprocess.run(["gh", "api", path], capture_output=True, text=True, timeout=20)
        if p.returncode == 0 and p.stdout.strip():
            try:
                return json.loads(p.stdout)
            except (ValueError, json.JSONDecodeError):
                return None
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return None


def _raw_fetch(url: str) -> bytes | None:
    """GET raw.githubusercontent.com (or any URL). Local-first cache."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as r:
            body = r.read()
            _cache_put(url, body)
            return body
    except (urllib.error.URLError, urllib.error.HTTPError, OSError):
        return _cache_get(url)


def _fetch_offspring_file(owner_repo: str, path: str) -> tuple[bytes | None, str]:
    """Fetch one file from an offspring repo. Returns (bytes, source).
    source ∈ {"gh-api", "raw.githubusercontent.com", "cache", "missing"}.
    """
    # Prefer gh api (auth + rate limit)
    api_path = f"repos/{owner_repo}/contents/{path}"
    blob = _gh_api(api_path)
    if isinstance(blob, dict) and blob.get("content"):
        try:
            return base64.b64decode(blob["content"]), "gh-api"
        except (ValueError, TypeError):
            pass
    # Fallback to raw.githubusercontent.com
    raw_url = f"https://raw.githubusercontent.com/{owner_repo}/main/{path}"
    body = _raw_fetch(raw_url)
    if body is not None:
        return body, "raw.githubusercontent.com"
    cached = _cache_get(raw_url)
    if cached is not None:
        return cached, "cache"
    return None, "missing"


# ── offline fixture discovery ─────────────────────────────────────────────

def _find_fixture_dir(name: str, fixtures_dir: str) -> str | None:
    """Pick the fixture dir for an offspring name. Tries <name>-seed/ then <name>/."""
    for candidate in (f"{name}-seed", name):
        p = os.path.join(fixtures_dir, candidate)
        if os.path.isdir(p):
            return p
    return None


def _read_fixture_file(fixture_dir: str, path: str) -> bytes | None:
    full = os.path.join(fixture_dir, path)
    if not os.path.isfile(full):
        return None
    try:
        with open(full, "rb") as f:
            return f.read()
    except OSError:
        return None


# ── owner_repo extraction from gate_repo URL ──────────────────────────────

def _owner_repo_from_entry(entry: dict) -> str | None:
    gr = entry.get("gate_repo") or ""
    if not gr:
        return None
    if gr.startswith("https://github.com/"):
        tail = gr[len("https://github.com/"):].rstrip("/").split("/")
        if len(tail) >= 2:
            return f"{tail[0]}/{tail[1]}"
    if "/" in gr and not gr.startswith("http"):
        return gr  # already in owner/repo form
    return None


# ── per-offspring diff against contract ───────────────────────────────────

def _diff_offspring(name: str, kind: str, contract: dict,
                    file_getter, owner_repo: str | None) -> dict:
    """Run the contract checks against an offspring. file_getter is a
    callable(path) -> (bytes | None, source_label).

    Returns a dict {ok: bool, drift: list, fingerprint_sha256: str | None,
                    rappid: str | None, fetched_from: str}.
    """
    drift = []
    sources_seen = set()
    fingerprint_sha256 = None
    rappid = None

    # 1. required_files presence
    for path in contract.get("required_files", []):
        body, source = file_getter(path)
        if source != "missing":
            sources_seen.add(source)
        if body is None:
            drift.append({"category": "missing_files", "path": path,
                          "detail": f"required file '{path}' not found"})

    # 2. expected_schemas — for each expected file, check the file's "schema" field
    for path, expected_schema in (contract.get("expected_schemas") or {}).items():
        body, source = file_getter(path)
        if source != "missing":
            sources_seen.add(source)
        if body is None:
            # Already covered by missing_files above (if required); skip silent for optional
            continue
        try:
            d = json.loads(body)
        except (ValueError, json.JSONDecodeError):
            drift.append({"category": "schema_drift", "path": path,
                          "detail": "file is not valid JSON"})
            continue
        actual_schema = d.get("schema") if isinstance(d, dict) else None
        if actual_schema != expected_schema:
            drift.append({"category": "schema_drift", "path": path,
                          "detail": f"expected schema={expected_schema!r}, got {actual_schema!r}"})
        if path == "rappid.json" and isinstance(d, dict):
            rappid = d.get("rappid")
            try:
                fingerprint_sha256 = _sha256_bytes(body)
            except Exception:
                pass

    # 3. rappid_kind_prefix check
    prefix = contract.get("rappid_kind_prefix")
    if prefix and rappid is not None:
        if not isinstance(rappid, str) or not rappid.startswith(prefix):
            drift.append({"category": "rappid_drift",
                          "path": "rappid.json",
                          "detail": f"expected rappid prefix {prefix!r}, got {str(rappid)[:64]!r}"})

    # 4. identity_block_required (soul.md must mention "Identity")
    if contract.get("identity_block_required"):
        body, source = file_getter("soul.md")
        if source != "missing":
            sources_seen.add(source)
        if body is None:
            # Already in missing_files if required; otherwise flag explicitly
            pass
        else:
            try:
                txt = body.decode("utf-8", errors="replace")
            except Exception:
                txt = ""
            if IDENTITY_BLOCK_SENTINEL not in txt:
                drift.append({"category": "identity_block_missing",
                              "path": "soul.md",
                              "detail": "soul.md must contain the Identity block sentinel (per ANTIPATTERNS §4)"})

    # 5. rar_required + sha256-validate against agents/
    if contract.get("rar_required"):
        body, source = file_getter("rar/index.json")
        if source != "missing":
            sources_seen.add(source)
        if body is None:
            # already reported as missing_file if required
            pass
        else:
            try:
                rar_index = json.loads(body)
            except (ValueError, json.JSONDecodeError):
                rar_index = None
            if not isinstance(rar_index, dict) or rar_index.get("schema") != "rapp-rar-index/1.0":
                drift.append({"category": "schema_drift", "path": "rar/index.json",
                              "detail": "rar/index.json schema invalid or missing"})
            else:
                # Recompute sha256 of every required_for_participation + kernel_base_included entry
                items = (rar_index.get("required_for_participation") or []) + \
                        (rar_index.get("kernel_base_included") or [])
                for item in items:
                    rel = item.get("file")
                    expected_sha = (item.get("sha256") or "").lower()
                    if not rel or not expected_sha:
                        continue
                    file_body, _ = file_getter(rel)
                    if file_body is None:
                        drift.append({"category": "missing_files", "path": rel,
                                      "detail": f"rar/index.json declares {rel} but file is absent"})
                        continue
                    actual_sha = _sha256_bytes(file_body)
                    if actual_sha != expected_sha:
                        drift.append({"category": "kernel_drift" if rel.endswith("basic_agent.py")
                                      else "schema_drift",
                                      "path": rel,
                                      "detail": f"sha256 mismatch — manifest={expected_sha[:12]}…, actual={actual_sha[:12]}…"})

    # 6. kernel_base_check: agents/{SEED_REQUIRED_AGENTS} must be present.
    #    This is the seed-portable minimum — basic_agent.py only. The other
    #    kernel-tier agents (manage_memory, context_memory per Art. XXXIII)
    #    are brainstem-internal and loaded by the joining brainstem.
    if contract.get("kernel_base_check"):
        for fname in SEED_REQUIRED_AGENTS:
            rel = f"agents/{fname}"
            body, source = file_getter(rel)
            if source != "missing":
                sources_seen.add(source)
            if body is None:
                drift.append({"category": "missing_files", "path": rel,
                              "detail": f"seed-portable kernel base {rel} required by kind"})

    fetched_from = ",".join(sorted(sources_seen)) if sources_seen else "none"
    return {
        "ok": not drift,
        "drift": drift,
        "fingerprint_sha256": fingerprint_sha256,
        "rappid": rappid,
        "fetched_from": fetched_from,
    }


# ── classification (push vs pull vs informational) ────────────────────────

def _classify_drift(offspring_result: dict, kind: str) -> str:
    """Map an offspring's drift entries to a direction the Bond Pulse should
    suggest. Heuristic — the rhythm agent receives this as a STARTING POINT.
    """
    drift = offspring_result.get("drift") or []
    if not drift:
        return "ALIGNED"
    # Anything missing on the offspring side that we have locally → push direction
    has_missing = any(d.get("category") == "missing_files" for d in drift)
    has_schema = any(d.get("category") in ("schema_drift", "rappid_drift") for d in drift)
    has_kernel = any(d.get("category") == "kernel_drift" for d in drift)
    if has_kernel:
        return "GLOBAL_TO_LOCAL"  # offspring has a kernel snapshot we should refresh from
    if has_missing or has_schema:
        return "LOCAL_TO_GLOBAL"
    return "INFORMATIONAL"


def _suggest_action(offspring_name: str, owner_repo: str | None,
                    direction: str, kind: str) -> dict | None:
    if direction == "ALIGNED":
        return None
    if direction == "LOCAL_TO_GLOBAL":
        agent = "Graft" if kind in ("neighborhood", "ant-farm", "braintrust", "workspace") else "Launch"
        gate = owner_repo or f"<owner>/{offspring_name}"
        return {
            "direction": direction,
            "agent_to_invoke": agent,
            "offspring": offspring_name,
            "one_liner": (f"{agent}.perform(upstream_repo={gate!r}, dry_run=False)"
                          if agent == "Graft"
                          else f"{agent}.perform(target_repo={gate!r}, instructions='…', dry_run=False)"),
            "reason": f"Offspring missing/diverged on required files; push the local version up via {agent}.",
        }
    if direction == "GLOBAL_TO_LOCAL":
        gate = owner_repo or f"<owner>/{offspring_name}"
        return {
            "direction": direction,
            "agent_to_invoke": "RarLoader",
            "offspring": offspring_name,
            "one_liner": f"RarLoader.perform(gate_repo={gate!r}, dry_run=False)",
            "reason": "Offspring's rar kit / kernel files differ from local cache — refresh local from offspring.",
        }
    return {
        "direction": "INFORMATIONAL",
        "agent_to_invoke": None,
        "offspring": offspring_name,
        "one_liner": None,
        "reason": "Cosmetic drift only; no action required.",
    }


# ── main audit ─────────────────────────────────────────────────────────────

def _build_file_getter_offline(fixture_dir: str | None):
    def get(path: str):
        if fixture_dir is None:
            return None, "missing"
        body = _read_fixture_file(fixture_dir, path)
        return (body, "fixture") if body is not None else (None, "missing")
    return get


def _build_file_getter_online(owner_repo: str | None):
    def get(path: str):
        if not owner_repo:
            return None, "missing"
        return _fetch_offspring_file(owner_repo, path)
    return get


def audit_ecosystem(*, mode: str = "offline",
                    repo_filter: str | None = None,
                    metropolis_index_path: str | None = None,
                    fixtures_dir: str | None = None,
                    out_dir: str | None = None,
                    write_outputs: bool = True) -> dict:
    """Run the audit. Returns the rapp-ecosystem-audit/1.0 envelope."""
    metropolis_path = metropolis_index_path or DEFAULT_METROPOLIS
    fixtures = fixtures_dir or DEFAULT_FIXTURES_DIR
    out = out_dir or DEFAULT_AUDIT_OUT_DIR

    if not os.path.exists(metropolis_path):
        return {
            "schema": AUDIT_SCHEMA,
            "audited_at": _now_iso(),
            "ok": False,
            "error": f"metropolis index not found at {metropolis_path}",
        }

    with open(metropolis_path) as f:
        metropolis = json.load(f)
    entries = metropolis.get("entries") or []
    metropolis_url = metropolis.get("tracker_url") or "(no tracker_url)"

    if repo_filter:
        # match by name OR by owner/repo gate_repo
        filtered = []
        for e in entries:
            if e.get("name") == repo_filter:
                filtered.append(e); continue
            owner_repo = _owner_repo_from_entry(e)
            if owner_repo == repo_filter:
                filtered.append(e); continue
        entries = filtered

    by_kind = {}
    offspring_results = []
    next_actions = []

    for entry in entries:
        name = entry.get("name") or "(unnamed)"
        kind = kind_for_entry(entry)
        contract = contract_for_kind(kind)
        owner_repo = _owner_repo_from_entry(entry)

        if mode == "online":
            getter = _build_file_getter_online(owner_repo)
        else:
            fixture_dir = _find_fixture_dir(name, fixtures)
            getter = _build_file_getter_offline(fixture_dir)
            if fixture_dir is None:
                # Skip — no fixture available, can't audit offline
                offspring_results.append({
                    "name": name, "kind": kind, "rappid": entry.get("neighborhood_rappid"),
                    "ok": True, "skipped": True, "skip_reason": "no_fixture",
                    "drift": [], "fetched_from": "none",
                    "fingerprint_sha256": None,
                    "_note": f"--offline mode; no tests/fixtures/{name}/ or {name}-seed/ found.",
                })
                by_kind.setdefault(kind, {"ok": 0, "drift": 0, "skipped": 0})["skipped"] += 1
                continue

        result = _diff_offspring(name, kind, contract, getter, owner_repo)
        result["name"] = name
        result["kind"] = kind
        result["kind_contract_version"] = "1.0"
        result["entry_metropolis_rappid"] = entry.get("neighborhood_rappid")
        offspring_results.append(result)

        bucket = by_kind.setdefault(kind, {"ok": 0, "drift": 0, "skipped": 0})
        if result["ok"]:
            bucket["ok"] += 1
        else:
            bucket["drift"] += 1
            direction = _classify_drift(result, kind)
            action = _suggest_action(name, owner_repo, direction, kind)
            if action:
                next_actions.append(action)

    drift_count = sum(1 for r in offspring_results if not r.get("ok") and not r.get("skipped"))

    summary = {
        "_purpose": "Quick scan: which offspring need GLOBAL→LOCAL pull, LOCAL→GLOBAL push, or just informational.",
        "needs_local_to_global_push": [a["offspring"] for a in next_actions if a["direction"] == "LOCAL_TO_GLOBAL"],
        "needs_global_to_local_pull": [a["offspring"] for a in next_actions if a["direction"] == "GLOBAL_TO_LOCAL"],
        "informational_only": [a["offspring"] for a in next_actions if a["direction"] == "INFORMATIONAL"],
    }

    audit = {
        "schema": AUDIT_SCHEMA,
        "audited_at": _now_iso(),
        "mode": mode,
        "metropolis_url": metropolis_url,
        "metropolis_path": metropolis_path,
        "offspring_count": len(offspring_results),
        "drift_count": drift_count,
        "by_kind": by_kind,
        "offspring": offspring_results,
        "summary": summary,
        "next_actions": next_actions,
        "ok": drift_count == 0,
    }

    if write_outputs:
        _write_outputs(audit, out)

    return audit


# ── output writers ────────────────────────────────────────────────────────

def render_human_report(audit: dict) -> str:
    """Markdown rendering of the audit dict."""
    lines = []
    lines.append("# Bond Pulse — Ecosystem Alignment Audit\n")
    lines.append(f"> Schema: `{audit.get('schema')}`. Generated by `tools/ecosystem_audit.py`.\n")
    lines.append(f"- **Audited at:** {audit.get('audited_at')}")
    lines.append(f"- **Mode:** `{audit.get('mode')}`")
    lines.append(f"- **Metropolis:** {audit.get('metropolis_url')}")
    lines.append(f"- **Offspring audited:** {audit.get('offspring_count')}")
    lines.append(f"- **Drift count:** {audit.get('drift_count')}")
    lines.append("")

    by_kind = audit.get("by_kind") or {}
    if by_kind:
        lines.append("## By kind\n")
        lines.append("| Kind | Aligned | Drifted | Skipped |")
        lines.append("|---|---|---|---|")
        for kind in sorted(by_kind.keys()):
            b = by_kind[kind]
            lines.append(f"| `{kind}` | {b.get('ok', 0)} | {b.get('drift', 0)} | {b.get('skipped', 0)} |")
        lines.append("")

    summary = audit.get("summary") or {}
    push = summary.get("needs_local_to_global_push") or []
    pull = summary.get("needs_global_to_local_pull") or []
    info = summary.get("informational_only") or []
    if push or pull or info:
        lines.append("## Suggested directions\n")
        if push:
            lines.append(f"**LOCAL → GLOBAL push** ({len(push)}): {', '.join(push)}")
        if pull:
            lines.append(f"**GLOBAL → LOCAL pull** ({len(pull)}): {', '.join(pull)}")
        if info:
            lines.append(f"**Informational only** ({len(info)}): {', '.join(info)}")
        lines.append("")

    actions = audit.get("next_actions") or []
    if actions:
        lines.append("## Next actions\n")
        for a in actions:
            lines.append(f"- **{a['offspring']}** ({a['direction']}) — `{a.get('one_liner') or '(no action)'}`")
            lines.append(f"  - {a.get('reason', '')}")
        lines.append("")

    lines.append("## Per-offspring detail\n")
    for o in (audit.get("offspring") or []):
        status = "🟡 skipped" if o.get("skipped") else ("✅ aligned" if o.get("ok") else "⚠️ drifted")
        lines.append(f"### {o.get('name')} — {status}\n")
        lines.append(f"- kind: `{o.get('kind')}`")
        lines.append(f"- rappid: `{(o.get('rappid') or o.get('entry_metropolis_rappid') or '(none)')[:96]}`")
        lines.append(f"- fetched_from: `{o.get('fetched_from')}`")
        if o.get("skipped"):
            lines.append(f"- skip_reason: `{o.get('skip_reason')}`")
        for d in (o.get("drift") or []):
            lines.append(f"- ⚠️ **{d.get('category')}** at `{d.get('path')}` — {d.get('detail')}")
        lines.append("")

    return "\n".join(lines) + "\n"


def _write_outputs(audit: dict, out_dir: str) -> None:
    try:
        os.makedirs(out_dir, exist_ok=True)
    except OSError:
        return
    json_path = os.path.join(out_dir, "ecosystem-audit.json")
    md_path = os.path.join(out_dir, "ecosystem-audit.md")
    try:
        with open(json_path, "w") as f:
            json.dump(audit, f, indent=2)
            f.write("\n")
        with open(md_path, "w") as f:
            f.write(render_human_report(audit))
    except OSError:
        pass


# ── CLI ────────────────────────────────────────────────────────────────────

def _resolve_mode(args) -> str:
    if args.online:
        return "online"
    if args.offline:
        return "offline"
    if os.environ.get("ECOSYSTEM_AUDIT_ONLINE") == "1":
        return "online"
    return "offline"


def main(argv=None):
    p = argparse.ArgumentParser(
        prog="ecosystem_audit",
        description="Bond Pulse drift detector — audit offspring repos against the per-kind contract.",
    )
    p.add_argument("--offline", action="store_true",
                   help="Use checked-in fixtures only (default; CI-safe).")
    p.add_argument("--online", action="store_true",
                   help="Fetch live offspring data via gh api + raw.githubusercontent.com.")
    p.add_argument("--repo", default=None,
                   help="Audit one offspring by name or owner/repo.")
    p.add_argument("--metropolis", default=None,
                   help="Override path to pages/metropolis/index.json.")
    p.add_argument("--fixtures-dir", default=None,
                   help="Override tests/fixtures/ directory (used by --offline).")
    p.add_argument("--out-dir", default=None,
                   help="Override pages/_audit output directory.")
    p.add_argument("--no-write", action="store_true",
                   help="Print audit JSON to stdout; skip file writes.")
    p.add_argument("--strict", action="store_true", default=True,
                   help="Exit 1 if drift_count > 0 (default).")
    p.add_argument("--lenient", dest="strict", action="store_false",
                   help="Exit 0 even if drift detected (just report).")
    args = p.parse_args(argv)

    mode = _resolve_mode(args)
    audit = audit_ecosystem(
        mode=mode,
        repo_filter=args.repo,
        metropolis_index_path=args.metropolis,
        fixtures_dir=args.fixtures_dir,
        out_dir=args.out_dir,
        write_outputs=not args.no_write,
    )

    if args.no_write:
        print(json.dumps(audit, indent=2))
    else:
        print(json.dumps({
            "schema": AUDIT_SCHEMA,
            "audited_at": audit.get("audited_at"),
            "mode": audit.get("mode"),
            "offspring_count": audit.get("offspring_count"),
            "drift_count": audit.get("drift_count"),
            "by_kind": audit.get("by_kind"),
            "outputs": {
                "markdown": os.path.join(args.out_dir or DEFAULT_AUDIT_OUT_DIR, "ecosystem-audit.md"),
                "json":     os.path.join(args.out_dir or DEFAULT_AUDIT_OUT_DIR, "ecosystem-audit.json"),
            },
        }, indent=2))

    if args.strict and audit.get("drift_count", 0) > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
