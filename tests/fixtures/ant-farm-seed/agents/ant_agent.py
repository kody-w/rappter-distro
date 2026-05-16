"""ant_agent — one ant in the RAPP swarm.

Every brainstem that joins a `kind: "ant-farm"` neighborhood loads this
agent and runs it on a tick. One tick:

    1. Read existing pheromones (GitHub Issues labeled "ant-pheromone"
       on the seed repo). Local-first via cachedGhJson-style fallback.
    2. Pick an unexplored topic — either the operator's `topic` kwarg or
       the longest-unexplored row in the colony's task pool.
    3. Compose a contribution (`trail`) — operator-supplied OR a templated
       skeleton the operator's LLM can fill at /chat time.
    4. Emit a `rapp-pheromone/1.0` envelope. By default returns dry-run
       JSON; with `dry_run=False` AND a token, posts a labeled Issue.

Schema: `rapp-pheromone/1.0`. Channel: NEIGHBORHOOD_PROTOCOL §5b (Issues
with the "ant-pheromone" label is the canonical durable transport).

The neighborhood seed at `<owner>/<repo>` is configurable via the
`farm_owner` + `farm_repo` kwargs (defaults to kody-w/ant-farm).

Single-file agent per ANTIPATTERNS §1. Pure stdlib. Tier-portable.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request

try:
    from agents.basic_agent import BasicAgent
except ImportError:
    from basic_agent import BasicAgent


_GH_API = "https://api.github.com"
_USER_AGENT = "rapp-ant/1.0"
_HTTP_TIMEOUT = 8.0
_DEFAULT_FARM_OWNER = "kody-w"
_DEFAULT_FARM_REPO = "ant-farm"
_PHEROMONE_LABEL = "ant-pheromone"
_PHEROMONE_SCHEMA = "rapp-pheromone/1.0"


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _gh_get(url: str, token: str | None = None) -> object | None:
    headers = {"Accept": "application/vnd.github+json", "User-Agent": _USER_AGENT}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=_HTTP_TIMEOUT) as r:
            return json.loads(r.read().decode("utf-8", errors="replace"))
    except (urllib.error.URLError, urllib.error.HTTPError, OSError, ValueError):
        return None


def _gh_post(url: str, body: dict, token: str) -> tuple[int, dict | None]:
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url, data=data, method="POST",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": _USER_AGENT,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=_HTTP_TIMEOUT) as r:
            return r.status, json.loads(r.read().decode("utf-8", errors="replace"))
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode("utf-8", errors="replace"))
        except Exception:
            return e.code, None
    except (urllib.error.URLError, OSError) as e:
        return 0, {"error": str(e)}


def fetch_pheromones(owner: str, repo: str, token: str | None = None,
                     since: str | None = None) -> list[dict]:
    """Read all pheromone Issues; parse the JSON body of each."""
    qp = {"labels": _PHEROMONE_LABEL, "state": "all", "per_page": "100"}
    if since:
        qp["since"] = since
    url = f"{_GH_API}/repos/{owner}/{repo}/issues?" + urllib.parse.urlencode(qp)
    issues = _gh_get(url, token)
    if not isinstance(issues, list):
        return []
    out = []
    for issue in issues:
        body = issue.get("body") or ""
        # Body convention: a fenced ```json block holding the pheromone envelope.
        m = re.search(r"```json\s*(\{.*?\})\s*```", body, re.DOTALL)
        if not m:
            continue
        try:
            ph = json.loads(m.group(1))
        except (ValueError, json.JSONDecodeError):
            continue
        if not isinstance(ph, dict) or ph.get("schema") != _PHEROMONE_SCHEMA:
            continue
        ph["_issue_number"] = issue.get("number")
        ph["_issue_url"] = issue.get("html_url")
        ph["_created_at"] = issue.get("created_at")
        out.append(ph)
    return out


def fetch_colony(owner: str, repo: str, token: str | None = None) -> dict:
    """Fetch data/colony.json — the shared task pool."""
    url = f"{_GH_API}/repos/{owner}/{repo}/contents/data/colony.json"
    blob = _gh_get(url, token)
    if not isinstance(blob, dict) or not blob.get("content"):
        return {}
    try:
        import base64
        return json.loads(base64.b64decode(blob["content"]).decode("utf-8", errors="replace"))
    except Exception:
        return {}


def _detect_ant_id() -> str:
    """Best-effort identifier for this ant — falls back to brainstem rappid."""
    p = os.path.expanduser("~/.brainstem/rappid.json")
    if os.path.exists(p):
        try:
            with open(p) as f:
                rj = json.load(f) or {}
            if rj.get("rappid"):
                return f"ant:{rj['rappid'][:32]}"
        except (OSError, ValueError):
            pass
    return f"ant:anon:{hashlib.sha256(os.urandom(16)).hexdigest()[:8]}"


def _suggest_topic(colony: dict, pheromones: list[dict]) -> str:
    """Pick the colony task with the fewest existing pheromones (load-balance)."""
    tasks = colony.get("tasks") or []
    if not tasks:
        # No declared tasks — pick a generic exploration topic.
        return "open exploration"
    counts = {t: 0 for t in tasks}
    for p in pheromones:
        topic = p.get("topic")
        if topic in counts:
            counts[topic] += 1
    # least-explored first
    return min(counts, key=counts.get)


def _find_links(trail: str, pheromones: list[dict], max_links: int = 3) -> list[str]:
    """Naive link-back: surface the N most-recent pheromones for cross-pollination."""
    if not pheromones:
        return []
    sorted_ph = sorted(pheromones, key=lambda p: p.get("_created_at") or "", reverse=True)
    return [p["_issue_url"] for p in sorted_ph[:max_links] if p.get("_issue_url")]


def compose_pheromone(*, ant_id: str, topic: str, trail: str,
                      links: list[str] | None = None,
                      previous_hash: str = "") -> dict:
    """Build a `rapp-pheromone/1.0` envelope with content-addressed hash chain."""
    utc = _now_iso()
    payload = {
        "schema": _PHEROMONE_SCHEMA,
        "ant_id": ant_id,
        "topic": topic,
        "trail": trail,
        "links_to": list(links or []),
        "utc": utc,
        "prev_hash": previous_hash,
    }
    body = (previous_hash or "") + "|" + utc + "|" + topic + "|" + ant_id + "|" + trail
    payload["hash"] = hashlib.sha256(body.encode("utf-8")).hexdigest()
    return payload


def _post_pheromone_issue(owner: str, repo: str, ph: dict, token: str) -> dict:
    title = f"ant-pheromone: {ph.get('topic', '?')[:80]}"
    body = (
        f"<!-- {_PHEROMONE_SCHEMA} dropped by {ph.get('ant_id', '?')} -->\n\n"
        f"```json\n{json.dumps(ph, indent=2)}\n```\n\n"
        + (f"_Cross-links: {' '.join(ph.get('links_to') or [])}_\n" if ph.get("links_to") else "")
    )
    status, resp = _gh_post(
        f"{_GH_API}/repos/{owner}/{repo}/issues",
        {"title": title, "body": body, "labels": [_PHEROMONE_LABEL]},
        token,
    )
    return {"http_status": status, "response": resp}


class AntAgent(BasicAgent):
    metadata = {
        "name": "Ant",
        "description": (
            "Drop a pheromone in the RAPP ant farm. One tick: read existing "
            "pheromones (GitHub Issues labeled 'ant-pheromone'), pick the "
            "least-explored topic, compose a contribution, emit a "
            "rapp-pheromone/1.0 envelope. Defaults to dry_run. "
            "Set dry_run=False AND pass a github_token to actually post."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "topic": {"type": "string", "description": "Override the auto-picked topic."},
                "trail": {"type": "string",
                          "description": "Your contribution. If absent, returns a skeleton for the LLM to fill."},
                "ant_id": {"type": "string", "description": "Identity to attribute (default: derived from rappid)."},
                "farm_owner": {"type": "string", "default": _DEFAULT_FARM_OWNER},
                "farm_repo": {"type": "string", "default": _DEFAULT_FARM_REPO},
                "dry_run": {"type": "boolean", "default": True,
                            "description": "If true, return the pheromone without posting."},
                "github_token": {"type": "string",
                                 "description": "GitHub token (only required when dry_run=False)."},
            },
            "required": [],
        },
    }

    def __init__(self):
        self.name = "Ant"

    def perform(self, **kwargs) -> str:
        farm_owner = kwargs.get("farm_owner") or _DEFAULT_FARM_OWNER
        farm_repo = kwargs.get("farm_repo") or _DEFAULT_FARM_REPO
        token = kwargs.get("github_token")
        dry_run = kwargs.get("dry_run", True)
        ant_id = (kwargs.get("ant_id") or _detect_ant_id()).strip()

        # Allow tests to inject a pheromone pool without network.
        existing = kwargs.get("_existing_pheromones")
        if existing is None:
            existing = fetch_pheromones(farm_owner, farm_repo, token)
        # Allow tests to inject a colony state.
        colony = kwargs.get("_colony")
        if colony is None:
            colony = fetch_colony(farm_owner, farm_repo, token)

        topic = (kwargs.get("topic") or _suggest_topic(colony, existing)).strip()
        trail = (kwargs.get("trail") or "").strip()
        if not trail:
            # Skeleton for the calling LLM to fill on its own next turn.
            trail = (
                f"[skeleton — fill this with a real contribution about '{topic}'. "
                f"Reference what the {len(existing)} prior ants explored. Keep it ≤ 280 chars.]"
            )

        previous_hash = existing[-1].get("hash", "") if existing else ""
        pheromone = compose_pheromone(
            ant_id=ant_id, topic=topic, trail=trail,
            links=_find_links(trail, existing),
            previous_hash=previous_hash,
        )

        result = {
            "schema": "rapp-ant-tick/1.0",
            "ant_id": ant_id,
            "farm": f"{farm_owner}/{farm_repo}",
            "existing_pheromone_count": len(existing),
            "picked_topic": topic,
            "pheromone": pheromone,
            "dry_run": dry_run,
        }

        if dry_run:
            result["next_step"] = (
                "Set dry_run=False and pass github_token to post. "
                "Or post the pheromone JSON manually as a labeled Issue at "
                f"https://github.com/{farm_owner}/{farm_repo}/issues/new?labels={_PHEROMONE_LABEL}"
            )
            return json.dumps(result, indent=2)

        if not token:
            result["error"] = "github_token required when dry_run=False"
            return json.dumps(result, indent=2)
        post = _post_pheromone_issue(farm_owner, farm_repo, pheromone, token)
        result["post"] = post
        return json.dumps(result, indent=2)
