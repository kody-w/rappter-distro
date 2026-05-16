/* =====================================================================
 * rapp-auth — Cloudflare Worker for the entire RAPP stack.
 *
 * The single auth + proxy surface used by any RAPP consumer that runs
 * outside a server (the virtual brainstem today; future PWAs, Copilot
 * Studio embeds, browser extensions tomorrow). Tier-1 (local brainstem)
 * and Tier-2 (Azure Functions) talk to GitHub directly from server-side
 * code and don't need this worker — but they can use it interchangeably
 * if they want one consistent auth surface across all tiers.
 *
 * What it does:
 *   - Holds the OAuth App client_secret so the browser doesn't have to.
 *   - Proxies the GitHub Models catalog (CORS-blocked upstream).
 *   - Proxies the GitHub Copilot device-code + token-exchange APIs
 *     (also CORS-blocked from kody-w.github.io). This unlocks the
 *     same Copilot flow the local brainstem.py uses.
 *
 * What it does NOT do:
 *   - Store tokens. Stateless. No KV, no D1, no logs.
 *   - Decide auth policy. The browser owns the token; we just proxy.
 *   - Cache per-user data. Catalog is edge-cached for 5 min, that's it.
 *
 * Endpoints:
 *   POST /api/auth/token         { code, redirect_uri? }
 *                                → OAuth web-flow code → access_token
 *   POST /api/auth/device        { client_id?, scope? }
 *                                → start device-code flow → user_code, verification_uri, …
 *   POST /api/auth/device/poll   { device_code, client_id? }
 *                                → poll for completion → access_token | { error: 'authorization_pending' }
 *   GET  /api/copilot/token      Authorization: Bearer ghu_…
 *                                → exchange ghu_ for short-lived Copilot bearer + endpoint
 *   GET  /api/copilot/models     Authorization: Bearer <copilot-token>
 *                                ?endpoint=https://api.individual.githubcopilot.com
 *                                → proxy {endpoint}/models with Editor headers + CORS
 *   POST /api/copilot/chat       Authorization: Bearer <copilot-token>
 *                                ?endpoint=https://api.individual.githubcopilot.com
 *                                → proxy {endpoint}/chat/completions
 *   GET  /api/models             → public catalog proxy (no auth required, 5-min edge cache)
 *   GET  /api/user               Authorization: Bearer …
 *                                → api.github.com/user proxy
 *   GET  /healthz                → "ok"
 *
 * Required secrets (one-time, via `wrangler secret put`):
 *   GH_CLIENT_ID                 — OAuth App (web-flow) client id
 *   GH_CLIENT_SECRET             — OAuth App (web-flow) client secret
 *   GH_DEVICE_CLIENT_ID          — device-flow client id (defaults to the
 *                                   Copilot one used by brainstem.py if unset)
 *
 * Deploy:  cd worker && npx wrangler deploy
 * ===================================================================== */

const ALLOWED_ORIGINS = [
  'https://kody-w.github.io',
  'http://localhost',
  'http://127.0.0.1',
];

// Same client id rapp_brainstem/brainstem.py uses for device-code flow.
// Returns ghu_ tokens that work with the Copilot exchange API.
const COPILOT_CLIENT_ID = 'Iv1.b507a08c87ecfe98';

function corsHeaders(req) {
  const origin = req.headers.get('Origin') || '';
  const allow = ALLOWED_ORIGINS.some(o => origin === o || origin.startsWith(o + ':') || origin.startsWith(o + '/'));
  return {
    'Access-Control-Allow-Origin': allow ? origin : ALLOWED_ORIGINS[0],
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  };
}

function json(body, init = {}, req) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(req),
      ...(init.headers || {}),
    },
  });
}

async function passthroughText(upstream, req, extraHeaders = {}) {
  const text = await upstream.text();
  return new Response(text, {
    status: upstream.status,
    headers: {
      'Content-Type': upstream.headers.get('Content-Type') || 'application/json',
      ...corsHeaders(req),
      ...extraHeaders,
    },
  });
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const p = url.pathname;

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    if (p === '/healthz') {
      return new Response('ok', { status: 200, headers: corsHeaders(request) });
    }

    // ── OAuth web flow: code → access_token ──────────────────────
    if (p === '/api/auth/token' && request.method === 'POST') {
      try {
        const body = await request.json();
        if (!body.code) return json({ error: 'missing code' }, { status: 400 }, request);
        const params = new URLSearchParams({
          client_id: env.GH_CLIENT_ID,
          client_secret: env.GH_CLIENT_SECRET,
          code: body.code,
        });
        if (body.redirect_uri) params.set('redirect_uri', body.redirect_uri);
        const ghResp = await fetch('https://github.com/login/oauth/access_token', {
          method: 'POST',
          headers: { 'Accept': 'application/json', 'Content-Type': 'application/x-www-form-urlencoded' },
          body: params.toString(),
        });
        return passthroughText(ghResp, request);
      } catch (e) {
        return json({ error: 'exchange_failed', detail: String(e) }, { status: 500 }, request);
      }
    }

    // ── Device-code flow: start ───────────────────────────────────
    if (p === '/api/auth/device' && request.method === 'POST') {
      try {
        const body = await request.json().catch(() => ({}));
        const clientId = body.client_id || env.GH_DEVICE_CLIENT_ID || COPILOT_CLIENT_ID;
        const scope = body.scope || 'read:user';
        const ghResp = await fetch('https://github.com/login/device/code', {
          method: 'POST',
          headers: { 'Accept': 'application/json', 'Content-Type': 'application/x-www-form-urlencoded' },
          body: `client_id=${encodeURIComponent(clientId)}&scope=${encodeURIComponent(scope)}`,
        });
        return passthroughText(ghResp, request);
      } catch (e) {
        return json({ error: 'device_start_failed', detail: String(e) }, { status: 500 }, request);
      }
    }

    // ── Device-code flow: poll ────────────────────────────────────
    if (p === '/api/auth/device/poll' && request.method === 'POST') {
      try {
        const body = await request.json();
        if (!body.device_code) return json({ error: 'missing device_code' }, { status: 400 }, request);
        const clientId = body.client_id || env.GH_DEVICE_CLIENT_ID || COPILOT_CLIENT_ID;
        const ghResp = await fetch('https://github.com/login/oauth/access_token', {
          method: 'POST',
          headers: { 'Accept': 'application/json', 'Content-Type': 'application/x-www-form-urlencoded' },
          body: `client_id=${encodeURIComponent(clientId)}&device_code=${encodeURIComponent(body.device_code)}&grant_type=urn:ietf:params:oauth:grant-type:device_code`,
        });
        return passthroughText(ghResp, request);
      } catch (e) {
        return json({ error: 'device_poll_failed', detail: String(e) }, { status: 500 }, request);
      }
    }

    // ── Copilot session-token exchange (mirrors brainstem.py) ─────
    if (p === '/api/copilot/token' && request.method === 'GET') {
      const auth = request.headers.get('Authorization');
      if (!auth) return json({ error: 'missing Authorization' }, { status: 401 }, request);
      // Normalize "Bearer ghu_…" / "token ghu_…" — Copilot expects "token" for ghu_.
      const raw = auth.replace(/^(Bearer|token)\s+/i, '');
      const upstreamAuth = raw.startsWith('ghu_') ? `token ${raw}` : `Bearer ${raw}`;
      const ghResp = await fetch('https://api.github.com/copilot_internal/v2/token', {
        method: 'GET',
        headers: {
          'Authorization': upstreamAuth,
          'Accept': 'application/json',
          'Editor-Version': 'vscode/1.95.0',
          'Editor-Plugin-Version': 'copilot/1.0.0',
          'User-Agent': 'GitHubCopilotChat/0.22.2024',
        },
      });
      return passthroughText(ghResp, request);
    }

    // ── Copilot models list (full Copilot model catalog incl. Claude/Opus) ──
    if (p === '/api/copilot/models' && request.method === 'GET') {
      const auth = request.headers.get('Authorization');
      if (!auth) return json({ error: 'missing Authorization' }, { status: 401 }, request);
      const endpoint = url.searchParams.get('endpoint') || 'https://api.individual.githubcopilot.com';
      if (!/^https:\/\/[a-z0-9.-]*githubcopilot\.com\/?$/i.test(endpoint)) {
        return json({ error: 'invalid endpoint' }, { status: 400 }, request);
      }
      const upstream = await fetch(endpoint.replace(/\/$/, '') + '/models', {
        method: 'GET',
        headers: {
          'Authorization': auth,
          'Accept': 'application/json',
          'Editor-Version': 'vscode/1.95.0',
          'Editor-Plugin-Version': 'copilot/1.0.0',
          'Copilot-Integration-Id': 'vscode-chat',
          'User-Agent': 'GitHubCopilotChat/0.22.2024',
        },
      });
      return passthroughText(upstream, request);
    }

    // ── Copilot chat completions proxy ─────────────────────────────
    if (p === '/api/copilot/chat' && request.method === 'POST') {
      const auth = request.headers.get('Authorization');
      if (!auth) return json({ error: 'missing Authorization' }, { status: 401 }, request);
      const endpoint = url.searchParams.get('endpoint') || 'https://api.individual.githubcopilot.com';
      if (!/^https:\/\/[a-z0-9.-]*githubcopilot\.com\/?$/i.test(endpoint)) {
        return json({ error: 'invalid endpoint' }, { status: 400 }, request);
      }
      const body = await request.text();
      const upstream = await fetch(endpoint.replace(/\/$/, '') + '/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': auth,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Editor-Version': 'vscode/1.95.0',
          'Editor-Plugin-Version': 'copilot/1.0.0',
          'Copilot-Integration-Id': 'vscode-chat',
          'User-Agent': 'GitHubCopilotChat/0.22.2024',
        },
        body,
      });
      return passthroughText(upstream, request);
    }

    // ── Public catalog proxy with CORS + aggressive edge cache ────
    // models.github.ai rate-limits anon requests; we cache 1 hour at the edge
    // and serve stale-while-revalidate so a 429 from upstream still returns
    // something useful to the browser.
    if (p === '/api/models' && request.method === 'GET') {
      const cacheKey = new Request('https://rapp-auth-cache/api/models/v1', { method: 'GET' });
      const cache = caches.default;
      let cached = await cache.match(cacheKey);
      // Fresh hit — serve from edge.
      if (cached) {
        const h = new Headers(cached.headers);
        Object.entries(corsHeaders(request)).forEach(([k, v]) => h.set(k, v));
        h.set('X-RAPP-Cache', 'HIT');
        return new Response(cached.body, { status: cached.status, headers: h });
      }
      try {
        const upstream = await fetch('https://models.github.ai/catalog/models', {
          headers: { 'Accept': 'application/json', 'User-Agent': 'rapp-auth-worker/1' },
        });
        const body = await upstream.text();
        // Only cache 2xx responses; 429s shouldn't poison the cache.
        if (upstream.ok) {
          const cacheResp = new Response(body, {
            status: upstream.status,
            headers: { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=3600' },
          });
          // Fire-and-forget — don't block the response.
          ctx?.waitUntil?.(cache.put(cacheKey, cacheResp.clone()));
        }
        return new Response(body, {
          status: upstream.status,
          headers: {
            'Content-Type': 'application/json',
            'Cache-Control': 'public, max-age=3600',
            'X-RAPP-Cache': upstream.ok ? 'MISS' : 'BYPASS',
            ...corsHeaders(request),
          },
        });
      } catch (e) {
        return json({ error: 'upstream_failed', detail: String(e) }, { status: 502 }, request);
      }
    }

    // ── api.github.com/user proxy ─────────────────────────────────
    if (p === '/api/user' && request.method === 'GET') {
      const auth = request.headers.get('Authorization');
      if (!auth) return json({ error: 'unauthorized' }, { status: 401 }, request);
      const upstream = await fetch('https://api.github.com/user', {
        headers: { 'Authorization': auth, 'Accept': 'application/json', 'User-Agent': 'rapp-auth-worker' },
      });
      return passthroughText(upstream, request);
    }

    return json({ error: 'not_found', path: p }, { status: 404 }, request);
  },
};
