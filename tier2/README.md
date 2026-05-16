# RAPP Swarm — Twin Stack on Azure Functions

`rapp_swarm/` is the Tier 2 deploy target — the same brainstem agent loop
running in Azure Functions, backed by Azure OpenAI and an Azure Storage
account. Same wire surface as the local brainstem (deploy/agent/seal/
snapshot) plus an LLM-driven `/api/chat` that mirrors the OG
community brainstem's `businessinsightbot_function` shape.

## Layout

```
rapp_swarm/
  function_app.py             ← Azure Functions Python v2 entrypoint
  host.json                   ← runtime config (extension bundle 4.x)
  requirements.txt            ← azure-functions
  local.settings.json.example ← copy → local.settings.json for `func start`
  build.sh                    ← vendors ../rapp_brainstem/* into ./_vendored/
  provision-twin.sh           ← one-shot Azure deploy per twin
  provision-twin-lite.sh      ← minimal deploy variant
  twin-egg.sh                 ← pack/unpack the full local Twin Stack
  twin-sim.sh                 ← spin up isolated local twin workspaces
  index.html                  ← static landing page
```

## One-time per twin: provision an isolated cloud

Each twin gets its **own resource group**, **own Function App**, **own
Azure OpenAI**, **own storage** — all in the same subscription/tenant.

```bash
# Kody's twin
bash rapp_swarm/provision-twin.sh kody

# Molly's twin
bash rapp_swarm/provision-twin.sh molly
```

Defaults (override with env vars):

| Var                 | Default                                                 |
|---------------------|---------------------------------------------------------|
| `SUBSCRIPTION_ID`   | `3d0e6986-1b31-4189-a394-b3289d54efb0` (VS Enterprise)  |
| `LOCATION`          | `eastus2`                                               |
| `OPENAI_LOCATION`   | `eastus2`                                               |
| `OPENAI_MODEL`      | `gpt-4o`                                                |
| `OPENAI_DEPLOYMENT` | same as model                                           |

What it does:

1. `az login` (if needed) → set subscription
2. Creates `rg-twin-<name>` resource group
3. ARM-deploys `azuredeploy.json` (Function App + Storage + OpenAI + RBAC)
4. Layers root `.env` keys onto Function App app settings
5. Vendors the brainstem core into `_vendored/`
6. `func azure functionapp publish` — pushes `function_app.py` live
7. Prints health-check + chat URLs

Tear-down (when you're done):

```bash
az group delete --name rg-twin-kody --yes --no-wait
```

## After provisioning

The Function App is empty. Hatch the twin's cloud into it:

1. Open `https://kody-w.github.io/RAPP/rapp_brainstem/web/onboard/`
2. Set the endpoint to the Function App URL printed at the end of provisioning
3. Click `Kody's Founder-Engineer Twin` (or `Molly's CEO Twin`) → **🚀 Push to endpoint**

The twin is now live. Try it:

```bash
curl -X POST "https://<APP_NAME>.azurewebsites.net/api/chat" \
    -H 'Content-Type: application/json' \
    -d '{"user_input":"What should I focus on this week?"}'
```

## Local dev

```bash
# Vendor brainstem core, install deps, start the function host
bash rapp_swarm/build.sh
cp rapp_swarm/local.settings.json.example rapp_swarm/local.settings.json
# (paste your AZURE_OPENAI_API_KEY into local.settings.json)
cd rapp_swarm && func start
```

## Wire surface

All routes prefixed with `/api/`:

| Method   | Path                                        | What it does                                      |
|----------|---------------------------------------------|---------------------------------------------------|
| POST     | `chat`                                      | LLM-driven chat (defaults to single hosted swarm) |
| POST     | `businessinsightbot_function`               | OG wire compat (lineage endpoint)                 |
| GET      | `swarm/healthz`                             | List swarms + LLM provider status                 |
| GET      | `swarm/{guid}/healthz`                      | Per-swarm info                                    |
| POST     | `swarm/deploy`                              | Hatch a `rapp-swarm/1.0` bundle                   |
| POST     | `swarm/{guid}/agent`                        | Single-agent call                                 |
| POST     | `swarm/{guid}/chat`                         | LLM-driven chat against this swarm                |
| GET/POST | `swarm/{guid}/seal`                         | Seal status / seal it                             |
| POST     | `swarm/{guid}/snapshot`                     | Create snapshot                                   |
| GET      | `swarm/{guid}/snapshots`                    | List snapshots                                    |
| POST     | `swarm/{guid}/snapshots/{snap}/agent`       | Read-only agent call against snapshot             |
| GET      | `llm/status`                                | Which LLM provider is wired                       |

## Why a separate Tier 2?

`rapp_brainstem/` is the local runtime — lives on the user's device,
always-present, speaks `rapp-tether/1.0` on `:7071`, runs as the user's
autonomic core.
`rapp_swarm/` is the **always-on multi-tenant runtime** — runs in Azure,
hosts long-running swarms, persists conversations to an Azure Storage
account, answers from anywhere without the user's laptop being open.

Local-first by default; this is the optional cloud surface for twins
that need to be reachable from anywhere.
