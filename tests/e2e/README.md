# RAPP End-to-End Test Plan

Validates the full three-tier model from Article II of
`rapp_brainstem/CONSTITUTION.md`:

1. **Tier 1 (local brainstem)** — `brainstem.py` on port 7071, GitHub
   Copilot LLM, flat single-user `agents/`.
2. **Tier 2 local** — `rapp_swarm/function_app.py` under `func start`,
   Azure OpenAI or Copilot fallback, guid-scoped memory per request.
3. **Tier 2 cloud** — same `function_app.py` deployed to Azure
   Functions, hit over HTTPS with the Power Automate shape.
4. **One-liner install** — `curl | bash` from the published repo in a
   clean sandbox dir. Post-publish validation.

## Stage order

| # | Stage | Script | Gate |
|---|-------|--------|------|
| 1 | Tier 1 smoke (health + basic /chat) | `01-tier1-smoke.sh` | `gh auth` + Copilot access |
| 2 | Tier 1 memory + factory | `02-tier1-memory-factory.sh` | same as 1 |
| 3 | Tier 2 local (func start + MCS-shape curl) | `04-tier2-local.sh` | `func` CLI + Azure OpenAI OR Copilot |
| 4 | VERSION bump + tag (Article VIII) | (inline) | tests 1–3 green |
| 5 | Publish to public repo | (inline) | explicit user authorization |
| 6 | Tier 2 cloud (deployed URL) | `05-tier2-cloud.sh` | `az login` + subscription |
| 7 | One-liner install verification | `06-oneliner-install.sh` | stage 5 done |
| 8 | HTML pages content | `08-html-pages.sh` | none |
| 9 | Wire envelope (Article XXV) | `09-wire-envelope.sh` | borrowed Copilot auth |
| 10 | Cross-version wire (current ↔ legacy v0.6.0) | `10-cross-version-wire.sh` | borrowed Copilot auth + network |
| 11 | Binder bootstrap from RAPPstore | `11-binder-bootstrap.sh` | network |
| 12 | Legacy wire conformance (all ancestors) | `12-legacy-wire-conformance.sh` | network + gh CLI for private CA365 |

Stages 1–3 are re-runnable locally without external state. Stage 5 is
a one-way action (public repo push). Stage 6 affects paid Azure
resources.

## How to run

```bash
# Tier 1 + Tier 2 local:
bash tests/e2e/01-tier1-smoke.sh
bash tests/e2e/02-tier1-memory-factory.sh
bash tests/e2e/04-tier2-local.sh

# Post-publish:
FUNCTION_URL=https://<twin-app>.azurewebsites.net \
FUNCTION_KEY=<key> \
  bash tests/e2e/05-tier2-cloud.sh

# In a /tmp sandbox, after publish:
bash tests/e2e/06-oneliner-install.sh
```

Each script prints `PASS: …` / `FAIL: …` per assertion and exits
non-zero on the first failure. Logs land under `/tmp/rapp-e2e-*.log`.

## What each test validates

### 01-tier1-smoke.sh
- Brainstem starts and binds port 7071.
- `/health` returns `status: ok` and the expected starter agent set
  (basic, hacker_news, learn_new, recall_memory, save_memory,
  workiq, swarm_factory).
- `/chat` round-trips a non-empty response.

### 02-tier1-memory-factory.sh
- `save_memory` + `recall_memory` round-trip through the LLM tool-call
  loop (save a fact, recall it in a subsequent turn).
- `swarm_factory` (action=build) produces a singleton agent file and
  writes it to a deterministic path.

### 04-tier2-local.sh
- `func start` comes up and binds port 7071 (brainstem must be
  stopped first).
- `/api/health` returns 200.
- `/api/businessinsightbot_function` accepts the Power-Automate-shape
  body `{user_input, conversation_history, user_guid}` and returns
  `{assistant_response, voice_response, agent_logs, user_guid}`.
- Guid-scoped memory: save a fact under `user_guid=A`, attempt recall
  under `user_guid=B`, assert the fact is NOT in the response.

### 05-tier2-cloud.sh
- Same assertions as `04` but against the deployed `$FUNCTION_URL`
  with `?code=$FUNCTION_KEY`.

### 06-oneliner-install.sh
- In `/tmp/rapp-install-sandbox-<timestamp>/`, run
  `curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash`.
- Verify brainstem starts, `/health` returns ok, `/chat` round-trips.
- Tears down after.

### 09-wire-envelope.sh — Constitution Article XXV
The sacred `/chat` envelope on a current brainstem:
- `/health` includes the `bootstrap` block (start.sh canary)
- `user_guid` omitted → defaults to `DEFAULT_USER_GUID = "c0p110t0-..."`
- `user_guid` provided → echoed in response
- Response contains BOTH `response` AND `assistant_response` keys
  with identical content (Tier 1 + CA365 lineage parity)
- Unknown future field is accepted (additive-only honored)

Borrows Copilot session from `~/.brainstem/src/rapp_brainstem/`
or `~/.brainstem/`, restored on exit. Test brainstem on port 7081.

### 10-cross-version-wire.sh — Time-travel safety acid test
Pulls legacy v0.6.0 brainstem from `kody-w/rapp-installer` to
`/tmp/rapp-e2e-legacy-src` and runs it alongside the current brainstem:
- Current → legacy WITH `user_guid` (legacy must accept and ignore)
- Legacy → current WITHOUT `user_guid` (current must default silently)
- Multi-turn `conversation_history` honored by both versions

This is THE proof that a brainstem from a year ago still chats with
today's brainstem with no code changes on either side. If this breaks,
the wire broke. Ports 7082 + 7083.

### 11-binder-bootstrap.sh — Distros + RAPPSTORE_URL
Clean sandbox at `/tmp/rapp-e2e-bootstrap` (no `services/`, no
`.brainstem_data/`), then runs `start.sh`:
- Bootstrap fetches binder from RAPPstore and lands it in `services/`
- `bootstrap.json` records `rapp_store_reachable=true, binder_installed=true`
- `/api/binder` responds with the installed list
- `/health` bootstrap block reflects the install

Proves a fresh brainstem on a fresh machine self-installs its package
manager from RAPPstore on first launch. Port 7084.

### 12-legacy-wire-conformance.sh — Static check across all ancestors
Static conformance check that pulls the `/chat` handler source from
each ancestor implementation and asserts the sacred wire fields are
still present:
- `kody-w/rapp-installer` (Tier 1, v0.6.0)
- `kody-w/CommunityRAPP` (Tier 2 cloud)
- `kody-w/Copilot-Agent-365` (CA365 original — private; needs `gh` CLI auth)
- This repo's `rapp_brainstem/brainstem.py`
- This repo's `rapp_swarm/function_app.py`

Will fail loudly if any of those repos ship a handler that drops
`user_input`, `conversation_history`, `user_guid`, or breaks the
exact `DEFAULT_USER_GUID` string. **Tests 09–12 together are the
regression net for Article XXV; do NOT edit them to make them pass —
fix the code that broke the wire.**
