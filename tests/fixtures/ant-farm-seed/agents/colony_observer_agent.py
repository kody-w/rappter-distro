"""colony_observer_agent — read the swarm's collective state.

Every participant in the ant farm can summon this agent to get a
synthesized view of what the colony has been working on without spawning
new pheromones. Counterpart to ant_agent: ants drop trails; observer
reads them.

Schema: `rapp-colony-observation/1.0`.
"""

from __future__ import annotations

import json
from collections import Counter

try:
    from agents.basic_agent import BasicAgent
except ImportError:
    from basic_agent import BasicAgent

# Reuse ant_agent's pheromone fetcher to avoid duplicating GH API code.
try:
    from agents.ant_agent import fetch_pheromones, fetch_colony
except ImportError:
    from ant_agent import fetch_pheromones, fetch_colony


_DEFAULT_FARM_OWNER = "kody-w"
_DEFAULT_FARM_REPO = "ant-farm"


class ColonyObserverAgent(BasicAgent):
    metadata = {
        "name": "ColonyObserver",
        "description": (
            "Synthesize the ant farm's collective state. Returns: total "
            "pheromone count, top contributing ants, topic distribution, "
            "longest hash chain, recent trails. Doesn't spawn new pheromones — "
            "purely an observer."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "farm_owner": {"type": "string", "default": _DEFAULT_FARM_OWNER},
                "farm_repo": {"type": "string", "default": _DEFAULT_FARM_REPO},
                "github_token": {"type": "string"},
                "recent_n": {"type": "integer", "default": 5,
                             "description": "How many recent trails to include verbatim."},
            },
            "required": [],
        },
    }

    def __init__(self):
        self.name = "ColonyObserver"

    def perform(self, **kwargs) -> str:
        farm_owner = kwargs.get("farm_owner") or _DEFAULT_FARM_OWNER
        farm_repo = kwargs.get("farm_repo") or _DEFAULT_FARM_REPO
        token = kwargs.get("github_token")
        recent_n = int(kwargs.get("recent_n") or 5)

        # Test-injection paths
        pheromones = kwargs.get("_existing_pheromones")
        if pheromones is None:
            pheromones = fetch_pheromones(farm_owner, farm_repo, token)
        colony = kwargs.get("_colony")
        if colony is None:
            colony = fetch_colony(farm_owner, farm_repo, token)

        ants = Counter(p.get("ant_id", "anon") for p in pheromones)
        topics = Counter(p.get("topic", "?") for p in pheromones)

        # Detect the longest unbroken hash chain — find a chain start (prev_hash="")
        # then walk forward by hash matches.
        by_prev = {p.get("prev_hash"): p for p in pheromones if p.get("prev_hash") is not None}
        longest_chain_len = 0
        for start in [p for p in pheromones if not p.get("prev_hash")]:
            length = 1
            cur = start
            while cur.get("hash") in by_prev:
                cur = by_prev[cur["hash"]]
                length += 1
                if length > 10000:  # safety
                    break
            longest_chain_len = max(longest_chain_len, length)

        sorted_ph = sorted(pheromones,
                           key=lambda p: p.get("_created_at") or p.get("utc") or "",
                           reverse=True)
        recent = [{
            "ant_id": p.get("ant_id"),
            "topic": p.get("topic"),
            "trail": (p.get("trail") or "")[:200],
            "utc": p.get("utc"),
            "issue_url": p.get("_issue_url"),
        } for p in sorted_ph[:recent_n]]

        return json.dumps({
            "schema": "rapp-colony-observation/1.0",
            "farm": f"{farm_owner}/{farm_repo}",
            "pheromone_count": len(pheromones),
            "ant_count": len(ants),
            "top_ants": ants.most_common(5),
            "topic_distribution": topics.most_common(),
            "longest_chain_length": longest_chain_len,
            "colony_tasks": colony.get("tasks", []) if isinstance(colony, dict) else [],
            "recent_trails": recent,
        }, indent=2)
