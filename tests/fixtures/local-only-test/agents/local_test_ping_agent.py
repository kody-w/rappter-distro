"""local_test_ping_agent.py — diagnostic ping for the local-only neighborhood.

Returns a constant payload that includes the seed directory it was loaded from.
Used by Scenario 1 to verify two brainstems on the same machine see the same
seed contents after subscribing via file://."""
import os
import time

from agents.basic_agent import BasicAgent


class LocalTestPingAgent(BasicAgent):
    name = "local_test_ping"
    metadata = {
        "name": "local_test_ping",
        "description": "Diagnostic ping for the local-only test neighborhood. Returns the seed dir it was loaded from + a UTC timestamp.",
        "parameters": {"type": "object", "properties": {}, "required": []}
    }

    def perform(self, **kwargs):
        return {
            "schema": "rapp-local-ping/1.0",
            "seed_dir": os.environ.get("NEIGHBORHOOD_SEED_DIR", os.getcwd()),
            "utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "ok": True,
        }
