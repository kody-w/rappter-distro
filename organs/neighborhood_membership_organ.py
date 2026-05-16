"""
neighborhood_membership_organ.py — RAPP Neighborhood subscription + sync.

Endpoints (dispatched at /api/neighborhoods/*):

    GET    /api/neighborhoods                      — list my subscriptions + sync status
    POST   /api/neighborhoods/join                  — { gate_url } verify collaborator → subscribe
    POST   /api/neighborhoods/<slug>/sync           — pull latest gate + private companion
    GET    /api/neighborhoods/<slug>                — full neighborhood metadata (gate + private cache)
    GET    /api/neighborhoods/<slug>/members        — roster with live status
    POST   /api/neighborhoods/<slug>/leave          — local unsubscribe (does NOT remove from GitHub)

The organ is the brainstem-side runtime for the cross-device, cross-repo
neighborhood layer. Peers on the same machine are still served by the
sibling `neighborhood_organ.py` at /api/neighborhood/* — they don't
overlap.

Subscription state lives at:    ~/.brainstem/neighborhoods.json
Per-neighborhood content cache: ~/.brainstem/neighborhoods/<slug>/

Trust anchor: GitHub collaborator status on the private companion repo.
We never invent a separate identity layer — `gh auth` IS the auth.

Schema versioning:
    rapp-neighborhood/1.0           — neighborhood.json
    rapp-neighborhood-members/1.0   — members.json
    rapp-neighborhoods-cache/1.0    — ~/.brainstem/neighborhoods.json (this organ owns it)
"""

import json
import os
import re
import time
import urllib.error
import urllib.request

name = "neighborhoods"


GH_API = "https://api.github.com"
RAW = "https://raw.githubusercontent.com"
HOME_BRAINSTEM = os.path.expanduser("~/.brainstem")
SUBS_FILE = os.path.join(HOME_BRAINSTEM, "neighborhoods.json")
CACHE_DIR = os.path.join(HOME_BRAINSTEM, "neighborhoods")


def _gh_token():
    tok = os.environ.get("GITHUB_TOKEN")
    if tok:
        return tok
    # .copilot_token written by device-code OAuth (see brainstem.py auth chain)
    for path in (".copilot_token", os.path.join("rapp_brainstem", ".copilot_token")):
        try:
            with open(path, "r") as f:
                return (f.read() or "").strip()
        except FileNotFoundError:
            continue
    return ""


def _gh_request(path, method="GET", body=None, raw=False, timeout=6.0):
    url = path if path.startswith("http") else GH_API + path
    headers = {
        "User-Agent": "rapp-neighborhood-membership",
        "Accept": "application/vnd.github+json" if not raw else "*/*",
    }
    token = _gh_token()
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            payload_bytes = r.read()
            status = r.status
            if raw:
                return payload_bytes, status
            try:
                return json.loads(payload_bytes.decode("utf-8")), status
            except (ValueError, UnicodeDecodeError):
                return {"raw": payload_bytes.decode("utf-8", errors="replace")}, status
    except urllib.error.HTTPError as e:
        return {"error": str(e), "status": e.code}, e.code
    except (urllib.error.URLError, OSError, TimeoutError) as e:
        return {"error": str(e), "offline": True}, 0


def _slug_from_url(url):
    if not url:
        return None
    m = re.match(r"^https?://github\.com/([^/]+)/([^/]+?)(?:/.*)?$", url.strip())
    if not m:
        return None
    owner, repo = m.group(1), m.group(2).rstrip(".git")
    return f"{owner}/{repo}"


def _local_path_from_url(url):
    """Detect file:// URLs for local-only subscription (Scenario 1: on-device,
    no GitHub round trip). Returns the absolute path or None.

    Accepted shapes:
        file:///absolute/path/to/seed
        file://localhost/absolute/path/to/seed
    """
    if not url:
        return None
    s = url.strip()
    if s.startswith("file://localhost/"):
        return "/" + s[len("file://localhost/"):]
    if s.startswith("file:///"):
        return "/" + s[len("file:///"):]
    if s.startswith("file://"):
        # tolerate file://path (no leading /) by interpreting as absolute
        rest = s[len("file://"):]
        if rest and not rest.startswith("/"):
            return None
        return rest
    return None


def _local_slug_from_path(path):
    """Synthesize a stable slug for a local seed: 'local/<basename-of-dir>'."""
    if not path:
        return None
    base = os.path.basename(os.path.normpath(path)) or "local"
    return f"local/{base}"


def _read_local_seed(path, files):
    """Read a small allow-list of files from a local seed directory.
    Returns (cache_dir, fetched_summary). Mirrors the shape of _cache_seed
    so the join/sync flow doesn't have to special-case."""
    seed_path = os.path.normpath(path)
    if not os.path.isdir(seed_path):
        return None, {"error": f"local seed dir does not exist: {seed_path}"}
    target = os.path.join(CACHE_DIR, "local__" + os.path.basename(seed_path))
    os.makedirs(target, exist_ok=True)
    fetched = {}
    for rel in files:
        src = os.path.join(seed_path, rel)
        if not os.path.exists(src):
            fetched[rel] = {"status": 404, "skipped": True}
            continue
        try:
            with open(src, "rb") as rf:
                body = rf.read()
            dest = os.path.join(target, rel.replace("/", "__"))
            with open(dest, "wb") as wf:
                wf.write(body)
            fetched[rel] = {"status": 200, "bytes": len(body), "from": "local"}
        except OSError as e:
            fetched[rel] = {"status": "read_error", "error": str(e)}
    return target, fetched


def _read_local_neighborhood_json(path):
    """Read neighborhood.json from a local seed directory."""
    seed_path = os.path.normpath(path)
    target = os.path.join(seed_path, "neighborhood.json")
    try:
        with open(target, "r") as f:
            return json.load(f), 200
    except FileNotFoundError:
        return None, 404
    except (ValueError, OSError) as e:
        return {"error": str(e)}, 0


def _load_subs():
    try:
        with open(SUBS_FILE, "r") as f:
            return json.load(f)
    except (FileNotFoundError, ValueError):
        return {
            "schema": "rapp-neighborhoods-cache/1.0",
            "version": 1,
            "subscriptions": [],
        }


def _save_subs(doc):
    os.makedirs(HOME_BRAINSTEM, exist_ok=True)
    tmp = SUBS_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(doc, f, indent=2)
    os.replace(tmp, SUBS_FILE)


def _find_sub(doc, slug):
    for s in doc.get("subscriptions") or []:
        if s.get("name") == slug or s.get("private_repo") == slug or s.get("gate_repo") == slug:
            return s
    return None


def _fetch_neighborhood_json(slug):
    payload, status = _gh_request(f"/repos/{slug}/contents/neighborhood.json")
    if status != 200 or not isinstance(payload, dict) or "content" not in payload:
        return None, status
    import base64
    try:
        decoded = base64.b64decode(payload["content"]).decode("utf-8")
        return json.loads(decoded), status
    except Exception:
        return None, status


def _verify_membership(private_slug):
    if not private_slug:
        return {"is_member": False, "reason": "no private companion declared"}
    payload, status = _gh_request(f"/repos/{private_slug}")
    if status == 200 and isinstance(payload, dict):
        perms = payload.get("permissions") or {}
        return {
            "is_member": bool(perms.get("pull")),
            "is_pusher": bool(perms.get("push")),
            "is_admin": bool(perms.get("admin")),
            "private": payload.get("private"),
            "reason": "verified via /repos/<slug> permissions",
        }
    if status == 404:
        return {"is_member": False, "reason": "not a collaborator (404)"}
    if status == 401:
        return {"is_member": False, "reason": "no GitHub token configured"}
    if status == 0:
        return {"is_member": False, "reason": "offline — cannot verify"}
    return {"is_member": False, "reason": f"unexpected status {status}"}


def _cache_seed(slug, paths_to_fetch):
    """Pull a small allow-list of files from a repo into ~/.brainstem/neighborhoods/<slug>/.
    Only the files we know about — no recursive clone."""
    target = os.path.join(CACHE_DIR, slug.replace("/", "__"))
    os.makedirs(target, exist_ok=True)
    fetched = {}
    for p in paths_to_fetch:
        body, status = _gh_request(f"{RAW}/{slug}/main/{p}", raw=True, timeout=8.0)
        if status == 200 and isinstance(body, (bytes, bytearray)):
            dest = os.path.join(target, p.replace("/", "__"))
            try:
                with open(dest, "wb") as f:
                    f.write(body)
                fetched[p] = {"status": 200, "bytes": len(body)}
            except OSError as e:
                fetched[p] = {"status": "write_error", "error": str(e)}
        else:
            fetched[p] = {"status": status, "skipped": True}
    return target, fetched


def _list_subs_response():
    doc = _load_subs()
    out = []
    for s in doc.get("subscriptions") or []:
        out.append({
            "name": s.get("name"),
            "neighborhood_rappid": s.get("neighborhood_rappid"),
            "display_name": s.get("display_name"),
            "gate_repo": s.get("gate_repo"),
            "private_repo": s.get("private_repo"),
            "role_inferred": s.get("role_inferred"),
            "joined_at": s.get("joined_at"),
            "last_sync": s.get("last_sync"),
            "cache_dir": s.get("cache_dir"),
        })
    return {
        "schema": "rapp-neighborhoods-cache/1.0",
        "subscriptions": out,
    }


def _estate_view():
    """Synthesize the user's full estate from all subscriptions.

    An estate is the union of neighborhoods one operator participates in —
    local + cross-device, public + private, founder + member + guest. This
    view is what makes the metropolis pattern legible: zones (by purpose),
    bridges (shared members across neighborhoods), and the operator's
    aggregate footprint."""
    doc = _load_subs()
    subs = doc.get("subscriptions") or []

    # Zoning: bucket neighborhoods by purpose and kind so the operator can
    # see at a glance what their estate covers.
    zones = {}
    for s in subs:
        kind = (s.get("kind") or "neighborhood")
        zones.setdefault(kind, []).append(s.get("name") or s.get("gate_repo"))

    # Bridges: pairs of neighborhoods that share a known member login. Phase 1
    # surfaces this from cached members.json; live bridge detection (across
    # other operators' estates) lands in Phase 2 once the federation
    # transport is wired.
    bridges = []
    member_index = {}
    for s in subs:
        cache = s.get("cache_dir")
        if not cache:
            continue
        members_path = os.path.join(cache, "members.json")
        try:
            with open(members_path, "r") as f:
                doc_m = json.load(f)
        except (FileNotFoundError, ValueError):
            continue
        for m in doc_m.get("members") or []:
            login = (m.get("github_login") or "").lower()
            if not login:
                continue
            member_index.setdefault(login, []).append(s.get("name") or s.get("gate_repo"))
    for login, neighborhoods in member_index.items():
        if len(neighborhoods) >= 2:
            bridges.append({"login": login, "spans": sorted(set(neighborhoods))})

    return {
        "schema": "rapp-estate/1.0",
        "synthesized_at": _now(),
        "subscription_count": len(subs),
        "zones": zones,
        "bridges": bridges,
        "neighborhoods": [
            {
                "name": s.get("name"),
                "display_name": s.get("display_name"),
                "kind": s.get("kind") or "neighborhood",
                "role_inferred": s.get("role_inferred"),
                "gate_repo": s.get("gate_repo"),
                "private_repo": s.get("private_repo"),
                "last_sync": s.get("last_sync"),
            }
            for s in subs
        ],
        "note": (
            "This is the operator's full estate — every neighborhood the local "
            "brainstem subscribes to, local + cross-device, public + private. "
            "Operator identity is preserved across neighborhoods; work products "
            "in any zone attribute back to the operator's rappid."
        ),
    }


def _now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _join_local(body, gate_url):
    """Local-mode subscription (file:// URL). Reads the seed straight from disk;
    no GitHub round-trip; no membership verification (filesystem access IS the
    auth). Used by Scenario 1 (local on-device) and any test rig."""
    local_path = _local_path_from_url(gate_url)
    if not local_path:
        return {"error": f"could not parse local path from {gate_url}"}, 400

    gate_n, gate_status = _read_local_neighborhood_json(local_path)
    if not gate_n:
        return {
            "error": f"could not read neighborhood.json at {local_path}",
            "status": gate_status,
            "hint": "Is this a planted RAPP neighborhood seed directory?",
        }, 404

    slug = _local_slug_from_path(local_path)
    paths = ["neighborhood.json", "card.json", "facets.json", "README.md", "members.json"]
    agent_paths = [
        "agents/neighborhood_introduce_agent.py",
        "agents/neighborhood_ask_agent.py",
        "agents/neighborhood_federate_agent.py",
        "agents/neighborhood_subscribe_agent.py",
    ]
    cache_dir, fetched = _read_local_seed(local_path, paths + agent_paths)

    doc = _load_subs()
    existing = _find_sub(doc, slug)
    sub = {
        "schema": "rapp-neighborhood-subscription/1.0",
        "neighborhood_rappid": gate_n.get("neighborhood_rappid"),
        "name": gate_n.get("name"),
        "display_name": gate_n.get("display_name"),
        "kind": gate_n.get("kind"),
        "visibility": gate_n.get("visibility"),
        "gate_repo": slug,
        "private_repo": None,
        "local_path": local_path,
        "role_inferred": "founder",
        "joined_at": (existing or {}).get("joined_at") or _now(),
        "last_sync": _now(),
        "cache_dir": cache_dir,
        "membership_check": {
            "is_member": True,
            "reason": "local-mode (filesystem access)",
        },
    }
    subs = [s for s in (doc.get("subscriptions") or []) if s.get("gate_repo") != slug]
    subs.append(sub)
    doc["subscriptions"] = subs
    _save_subs(doc)

    return {
        "joined": True,
        "mode": "local",
        "subscription": sub,
        "fetched": {"local": fetched},
    }, 200


def _join(body):
    gate_url = (body or {}).get("gate_url") or (body or {}).get("repo_url")
    if not gate_url:
        return {"error": "missing gate_url"}, 400

    if (gate_url or "").strip().startswith("file://"):
        return _join_local(body, gate_url)

    gate_slug = _slug_from_url(gate_url)
    if not gate_slug:
        return {"error": f"could not parse repo slug from {gate_url}"}, 400

    gate_n, gate_status = _fetch_neighborhood_json(gate_slug)
    if not gate_n:
        return {
            "error": f"could not read neighborhood.json from {gate_slug}",
            "status": gate_status,
            "hint": "Is this a planted RAPP neighborhood gate? Check the URL.",
        }, 404

    pc = (gate_n.get("private_companion") or {}).get("repo")
    private_slug = _slug_from_url(pc) if pc else None

    membership = _verify_membership(private_slug) if private_slug else {
        "is_member": True,
        "reason": "no private companion — public-only neighborhood",
    }

    if private_slug and not membership.get("is_member"):
        return {
            "joined": False,
            "reason": membership.get("reason"),
            "next_step": {
                "action": "open_join_issue",
                "url": (
                    f"https://github.com/{gate_slug}/issues/new"
                    f"?title={_url_encode('Request access — ' + (gate_n.get('display_name') or gate_n.get('name') or gate_slug))}"
                    f"&labels=join-request"
                ),
            },
            "membership_check": membership,
            "gate": gate_n,
        }, 403

    role = "founder" if membership.get("is_admin") else (
        "member" if membership.get("is_pusher") else "guest"
    )

    paths = ["neighborhood.json", "card.json", "facets.json", "README.md"]
    private_paths = paths + ["members.json"]
    private_agents = [
        "agents/neighborhood_introduce_agent.py",
        "agents/neighborhood_ask_agent.py",
        "agents/neighborhood_federate_agent.py",
        "agents/neighborhood_subscribe_agent.py",
    ]

    gate_cache_dir, gate_fetched = _cache_seed(gate_slug, paths)
    private_cache_dir, private_fetched = (None, {})
    if private_slug and membership.get("is_member"):
        private_cache_dir, private_fetched = _cache_seed(
            private_slug, private_paths + private_agents
        )

    doc = _load_subs()
    existing = _find_sub(doc, gate_slug)
    sub = {
        "schema": "rapp-neighborhood-subscription/1.0",
        "neighborhood_rappid": gate_n.get("neighborhood_rappid"),
        "name": gate_n.get("name"),
        "display_name": gate_n.get("display_name"),
        "gate_repo": gate_slug,
        "private_repo": private_slug,
        "role_inferred": role,
        "joined_at": (existing or {}).get("joined_at") or _now(),
        "last_sync": _now(),
        "cache_dir": private_cache_dir or gate_cache_dir,
        "membership_check": membership,
    }
    subs = [s for s in (doc.get("subscriptions") or []) if s.get("gate_repo") != gate_slug]
    subs.append(sub)
    doc["subscriptions"] = subs
    _save_subs(doc)

    # Surface the per-neighborhood RAR participation kit (rapp-rar-index/1.0)
    # if the gate declares one. Joining brainstems can hot-load it via the
    # RarLoader agent — sha256-verified, dry_run by default. This is the
    # universal pattern: every planted seed's `rar/index.json` declares the
    # agents/cards/rapps/organs required to participate; the loader installs
    # them. See ECOSYSTEM_MAP §5 (rapp-rar-index/1.0) + tests/features/F7.
    rar_url = (
        gate_n.get("rar_index_url")
        or f"https://raw.githubusercontent.com/{gate_slug}/main/rar/index.json"
    )
    rar_kit = {
        "rar_index_url": rar_url,
        "load_via": (
            "Invoke the RarLoader agent on /chat: "
            f"\"use the RarLoader agent on gate_repo={gate_slug}\" "
            "(defaults to dry_run; pass dry_run=False to install). "
            "Or POST to /api/neighborhoods/" + gate_slug + "/rar-loadout for a server-side loadout report."
        ),
        "default_mode": "dry_run",
        "_note": (
            "Per the universal RAR pattern: every joining brainstem MAY hot-load "
            "the gate's required participation kit. Default off — the operator "
            "opts in. Local-first: cached at ~/.brainstem/rar_cache/ once fetched."
        ),
    }

    return {
        "joined": True,
        "subscription": sub,
        "fetched": {
            "gate": gate_fetched,
            "private": private_fetched,
        },
        "agents_pending_mount": [
            os.path.basename(p) for p in private_agents
        ] if private_slug and membership.get("is_member") else [],
        "rar_kit": rar_kit,
        "phase": (
            "Phase 1: subscription recorded, content cached, rar kit pointer "
            "surfaced. Hot-mounting the gate's required RAR entries is operator-opt-in "
            "via the RarLoader agent (defaults to dry_run for safety)."
        ),
    }, 200


def _url_encode(s):
    import urllib.parse
    return urllib.parse.quote(s, safe="")


def _sync(slug, body):
    doc = _load_subs()
    sub = _find_sub(doc, slug)
    if not sub:
        return {"error": f"not subscribed to {slug}"}, 404

    gate_n, _ = _fetch_neighborhood_json(sub["gate_repo"])
    if gate_n:
        sub["display_name"] = gate_n.get("display_name") or sub.get("display_name")
        sub["neighborhood_rappid"] = gate_n.get("neighborhood_rappid") or sub.get("neighborhood_rappid")

    membership = _verify_membership(sub.get("private_repo"))
    paths = ["neighborhood.json", "card.json", "facets.json", "README.md"]
    private_paths = paths + ["members.json"]
    private_agents = [
        "agents/neighborhood_introduce_agent.py",
        "agents/neighborhood_ask_agent.py",
        "agents/neighborhood_federate_agent.py",
        "agents/neighborhood_subscribe_agent.py",
    ]

    gate_cache_dir, gate_fetched = _cache_seed(sub["gate_repo"], paths)
    private_fetched = {}
    if sub.get("private_repo") and membership.get("is_member"):
        _, private_fetched = _cache_seed(sub["private_repo"], private_paths + private_agents)

    sub["last_sync"] = _now()
    sub["membership_check"] = membership
    _save_subs(doc)
    return {
        "synced": True,
        "subscription": sub,
        "fetched": {"gate": gate_fetched, "private": private_fetched},
    }, 200


def _members(slug):
    doc = _load_subs()
    sub = _find_sub(doc, slug)
    if not sub:
        return {"error": f"not subscribed to {slug}"}, 404
    cache_dir = sub.get("cache_dir")
    if not cache_dir:
        return {"error": "no cache yet — sync first"}, 409
    members_path = os.path.join(cache_dir, "members.json")
    try:
        with open(members_path, "r") as f:
            members_doc = json.load(f)
    except (FileNotFoundError, ValueError):
        return {
            "error": "members.json not in cache",
            "hint": "You may not be a member of the private companion. Check membership_check on the subscription.",
        }, 403
    return {
        "schema": members_doc.get("schema"),
        "neighborhood_rappid": members_doc.get("neighborhood_rappid"),
        "members": members_doc.get("members") or [],
        "synced_at": sub.get("last_sync"),
    }, 200


def _detail(slug):
    doc = _load_subs()
    sub = _find_sub(doc, slug)
    if not sub:
        return {"error": f"not subscribed to {slug}"}, 404
    return {"subscription": sub}, 200


def _leave(slug):
    doc = _load_subs()
    before = len(doc.get("subscriptions") or [])
    doc["subscriptions"] = [
        s for s in (doc.get("subscriptions") or [])
        if s.get("gate_repo") != slug and s.get("private_repo") != slug and s.get("name") != slug
    ]
    after = len(doc["subscriptions"])
    _save_subs(doc)
    return {
        "left": before > after,
        "removed_count": before - after,
        "note": "Local unsubscribe only. To revoke GitHub collaborator status, use `gh api -X DELETE /repos/<owner>/<repo>/collaborators/<login>`.",
    }, 200


_TERMINAL_VERBS = {"sync", "members", "leave", "contribute", "contributions"}


def _contribute(slug, body):
    """Accept a contribution from a peer brainstem (or local agent).

    This is the receiver side of brainstem-to-brainstem federation. A peer
    brainstem POSTs `{request_id, topic, contribution}` to this endpoint;
    we record it under the subscription's cache so the operator's
    synthesizer can later fold it into a report.

    No GitHub round-trip. No auth ceremony beyond the local subscription —
    if the receiver has subscribed to this neighborhood (file:// or remote),
    contributions from peers are accepted into their cache. The trust
    boundary at the network edge is whatever fronts the brainstem (firewall,
    same-machine peer registry, manually-shared peer URL)."""
    doc = _load_subs()
    sub = _find_sub(doc, slug)
    if not sub:
        return {"error": f"not subscribed to {slug}"}, 404
    if not isinstance(body, dict):
        return {"error": "body must be a JSON object"}, 400

    contribution = body.get("contribution") or body
    request_id = body.get("request_id") or contribution.get("request_id")
    if not request_id:
        return {"error": "missing request_id"}, 400
    contributor_login = (
        (contribution.get("contributor") or {}).get("github_login")
        or body.get("contributor_login")
        or "unknown"
    )

    cache_dir = sub.get("cache_dir")
    if not cache_dir:
        return {"error": "subscription has no cache directory"}, 409
    contrib_dir = os.path.join(cache_dir, "contributions", request_id)
    os.makedirs(contrib_dir, exist_ok=True)
    fname = f"{_now().replace(':', '').replace('-', '')}-{contributor_login}.json"
    path = os.path.join(contrib_dir, fname)
    receipt = {
        "schema": "rapp-braintrust-contribution-receipt/1.0",
        "request_id": request_id,
        "received_at": _now(),
        "received_by_neighborhood": slug,
        "contribution": contribution,
        "from_peer": body.get("from_peer"),
    }
    try:
        with open(path, "w") as f:
            json.dump(receipt, f, indent=2)
    except OSError as e:
        return {"error": f"could not write receipt: {e}"}, 500

    return {
        "received": True,
        "request_id": request_id,
        "contributor_login": contributor_login,
        "stored_at": path,
        "schema": "rapp-braintrust-contribution-receipt/1.0",
    }, 200


def _list_contributions(slug, body=None):
    """List contributions stored for this subscription, optionally
    filtered by request_id."""
    doc = _load_subs()
    sub = _find_sub(doc, slug)
    if not sub:
        return {"error": f"not subscribed to {slug}"}, 404
    cache_dir = sub.get("cache_dir")
    if not cache_dir:
        return {"contributions": [], "note": "no cache yet"}, 200
    contrib_root = os.path.join(cache_dir, "contributions")
    if not os.path.isdir(contrib_root):
        return {"contributions": [], "request_count": 0}, 200

    request_filter = (body or {}).get("request_id")
    out = []
    for req_id in sorted(os.listdir(contrib_root)):
        if request_filter and req_id != request_filter:
            continue
        req_dir = os.path.join(contrib_root, req_id)
        if not os.path.isdir(req_dir):
            continue
        for fn in sorted(os.listdir(req_dir)):
            if not fn.endswith(".json"):
                continue
            try:
                with open(os.path.join(req_dir, fn), "r") as f:
                    out.append(json.load(f))
            except (ValueError, OSError):
                continue
    return {
        "contributions": out,
        "count": len(out),
        "request_filter": request_filter,
    }, 200


def _by_rappid(rappid):
    """Look up a rappid across all subscribed neighborhoods.

    The rappid is the AI's identity passport. Given a rappid, this returns
    every neighborhood (in the local brainstem's subscription set) where
    that rappid appears as a member. This is the global-estate-view by
    operator-identity — exactly what makes 'who is this AI? where do they
    show up?' answerable from any node in the network."""
    if not rappid:
        return {"error": "missing rappid"}
    rappid = rappid.strip().lower()
    doc = _load_subs()
    appearances = []
    for sub in (doc.get("subscriptions") or []):
        cache = sub.get("cache_dir")
        if not cache:
            continue
        members_path = os.path.join(cache, "members.json")
        try:
            with open(members_path, "r") as f:
                members_doc = json.load(f)
        except (FileNotFoundError, ValueError):
            continue
        for m in (members_doc.get("members") or []):
            mr = (m.get("rappid") or "").lower()
            if mr == rappid:
                appearances.append({
                    "neighborhood_name": sub.get("name"),
                    "neighborhood_display_name": sub.get("display_name"),
                    "neighborhood_rappid": sub.get("neighborhood_rappid"),
                    "kind": sub.get("kind"),
                    "visibility": sub.get("visibility"),
                    "github_login_in_this_neighborhood": m.get("github_login"),
                    "role": m.get("role"),
                    "joined_at": m.get("joined_at"),
                    "capabilities": m.get("capabilities") or [],
                })
                break
    return {
        "schema": "rapp-rappid-estate-view/1.0",
        "rappid": rappid,
        "appears_in_count": len(appearances),
        "appearances": appearances,
        "note": (
            "This is the global view of where this rappid (operator identity) "
            "shows up across the local brainstem's known subscriptions. The "
            "rappid is the AI's passport — it travels with the operator across "
            "every neighborhood they enter, and this lookup walks the full "
            "estate to find them. (Cross-brainstem global lookup is Phase 2: "
            "uses the same primitive against any peer's public estate-view.)"
        ),
    }


def handle(method, path, body):
    """Organ entry point — dispatched by utils/organs at /api/neighborhoods/*.

    A GitHub slug is `<owner>/<repo>` (two path segments), so per-neighborhood
    routes have shape `<owner>/<repo>` (detail) or `<owner>/<repo>/<verb>`
    (sync/members/leave). The dispatcher peels off a trailing terminal verb
    if present and treats the remainder as the slug — that way the slug can
    legitimately contain slashes without ambiguity."""
    method = (method or "GET").upper()
    path = (path or "").strip("/")

    if method == "GET" and path == "":
        return _list_subs_response(), 200

    if method == "GET" and path == "estate":
        return _estate_view(), 200

    if method == "GET" and path.startswith("by-rappid/"):
        return _by_rappid(path[len("by-rappid/"):]), 200

    if method == "POST" and path == "join":
        return _join(body)

    parts = path.split("/")

    if len(parts) >= 1 and parts[-1] in _TERMINAL_VERBS:
        verb = parts[-1]
        slug = "/".join(parts[:-1])
        if not slug:
            return {"error": f"missing <owner>/<repo> before /{verb}"}, 400
        if method == "POST" and verb == "sync":
            return _sync(slug, body)
        if method == "GET" and verb == "members":
            return _members(slug)
        if method == "POST" and verb == "leave":
            return _leave(slug)
        if method == "POST" and verb == "contribute":
            return _contribute(slug, body)
        if method == "GET" and verb == "contributions":
            return _list_contributions(slug, body)
        return {"error": f"verb /{verb} does not accept {method}"}, 405

    if method == "GET" and len(parts) >= 1:
        return _detail("/".join(parts))

    return {
        "error": f"unknown route: {method} /api/neighborhoods/{path}",
        "valid_routes": [
            "GET    /api/neighborhoods",
            "GET    /api/neighborhoods/estate",
            "GET    /api/neighborhoods/by-rappid/<rappid>",
            "POST   /api/neighborhoods/join",
            "POST   /api/neighborhoods/<owner>/<repo>/sync",
            "GET    /api/neighborhoods/<owner>/<repo>/members",
            "GET    /api/neighborhoods/<owner>/<repo>",
            "POST   /api/neighborhoods/<owner>/<repo>/leave",
            "POST   /api/neighborhoods/<owner>/<repo>/contribute",
            "GET    /api/neighborhoods/<owner>/<repo>/contributions",
        ],
    }, 404
