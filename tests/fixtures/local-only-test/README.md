# Local-Only Test Neighborhood

A diagnostic seed used by `tests/scenarios/01-local-on-device.sh` to verify the membership organ's local-mode (`file://`) flow without any GitHub round-trip.

## How to use

```bash
# From a brainstem at http://localhost:7071
curl -s -X POST http://localhost:7071/api/neighborhoods/join \
     -H 'content-type: application/json' \
     -d '{"gate_url":"file:///<absolute-path-to-this-dir>"}' \
     | jq

# Verify
curl -s http://localhost:7071/api/neighborhoods | jq
curl -s http://localhost:7071/api/neighborhoods/estate | jq
```

Expected outcome: `joined: true`, `mode: "local"`, `role_inferred: "founder"`, the neighborhood appears in `/api/neighborhoods`, and the estate view counts 1+ subscriptions.

## Why this seed exists

The membership organ supports two URL schemes:

- `https://github.com/<owner>/<repo>` → GitHub mode (collaborator-gated)
- `file:///<absolute-path>` → local mode (filesystem-access-gated)

Local mode lets multiple brainstems on the same machine share a neighborhood without anyone going to GitHub. Useful for development, demos, fully air-gapped environments, and the on-device hero scenario.

This seed is the smallest possible fixture that exercises that path.
