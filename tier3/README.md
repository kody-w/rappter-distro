# rapp-auth — the RAPP stack auth/proxy worker

A tiny stateless Cloudflare Worker that holds the GitHub OAuth client secret and proxies the few GitHub APIs that aren't browser-friendly. It's the canonical auth + proxy surface for **any** RAPP consumer that runs outside a server: the virtual brainstem today, future PWAs, browser extensions, Copilot Studio embeds tomorrow.

Tier 1 (local Python brainstem) and Tier 2 (Azure Functions swarm) talk to GitHub directly server-side and don't *need* this worker — but they can use it if you want one consistent auth surface across every tier.

## Endpoints

| Method · Path | Purpose | Notes |
|---|---|---|
| `POST /api/auth/token` | OAuth web-flow `code` → `access_token` | The only step that needs `client_secret`. |
| `POST /api/auth/device` | Start device-code flow | Body: `{ client_id?, scope? }`. Defaults to the Copilot client id used by `brainstem.py`. |
| `POST /api/auth/device/poll` | Poll device-code completion | Body: `{ device_code, client_id? }`. Returns `access_token` or `{ error: 'authorization_pending' }`. |
| `GET /api/copilot/token` | Exchange `ghu_` for Copilot session bearer + endpoint | Sends the same `Editor-Version` + `Copilot-Integration-Id` headers `brainstem.py` does. |
| `GET /api/models` | GitHub Models catalog proxy with CORS | Public, no auth needed. 5-min edge cache. |
| `GET /api/user` | `api.github.com/user` proxy | Convenience — browser can also call upstream directly. |
| `GET /healthz` | Liveness | Returns `ok`. |

The worker is **stateless**: no KV, no D1, no logs, no per-user storage. It's just a CORS-friendly courier in front of `github.com` and `models.github.ai`. The browser holds the token; the worker never sees the same request twice.

`ALLOWED_ORIGINS` whitelists `https://kody-w.github.io` plus localhost. Add your fork's origin if you host elsewhere.

## Setup (one time, ~3 minutes)

1. **Register a GitHub OAuth App** dedicated to RAPP.
   - GitHub → Settings → Developer settings → **OAuth Apps** → **New OAuth App**
   - **Application name:** `RAPP`
   - **Homepage URL:** `https://kody-w.github.io/RAPP/`
   - **Authorization callback URL:** `https://kody-w.github.io/RAPP/`
   - Click **Register application**, then **Generate a new client secret**.
   - Copy both the **Client ID** and the **Client Secret**.

2. **Deploy the worker.**

   ```bash
   cd worker
   npx wrangler login                            # one-time browser login
   npx wrangler secret put GH_CLIENT_ID          # paste the client id
   npx wrangler secret put GH_CLIENT_SECRET      # paste the client secret
   npx wrangler deploy
   ```

   Wrangler prints the deployed URL, e.g. `https://rapp-auth.<your>.workers.dev`.

3. **Wire it into the brainstem.** Open `brainstem/index.html` and update the two
   constants near the top of the inline script:

   ```js
   const AUTH_CLIENT_ID  = '<your OAuth App Client ID>';
   const AUTH_WORKER_URL = 'https://rapp-auth.<your>.workers.dev';
   ```

   Commit + push. GitHub Pages picks it up in ~30 s.

## Why a dedicated worker?

A previous iteration shared an existing worker (`rappterbook-auth`). Splitting RAPP onto its own worker means:

- Independent secret rotation per app.
- Independent OAuth callback URLs and scopes.
- Smaller blast radius — one app's bug or rate limit doesn't take the others down.
- The worker source stays small enough (~180 lines) to audit in one sitting.

## Local dev

```bash
cd worker
npx wrangler dev               # runs on http://localhost:8787
# point the brainstem at it by editing AUTH_WORKER_URL temporarily
```

`wrangler dev` reloads on save. Use `wrangler tail` to stream logs from the production worker.
