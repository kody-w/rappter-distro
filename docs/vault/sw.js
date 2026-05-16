// pages/vault/sw.js — service worker for the RAPP Vault PWA.
//
// Strategy:
//   - Precache the viewer shell + manifest on install.
//   - For markdown notes: stale-while-revalidate so notes are instant offline
//     but quietly refresh in the background when online.
//   - For raw.githubusercontent.com: pass through to network (the viewer
//     already has same-origin first, raw.gh as fallback — we don't add
//     another cache layer there).

const CACHE_VERSION = 'rapp-vault-v1';
const SHELL = [
  './',
  './index.html',
  './vault.css',
  './vault.js',
  './manifest.webmanifest',
  './icon-192.svg',
  './icon-512.svg',
  './_manifest.json',
  'https://cdn.jsdelivr.net/npm/marked@12.0.2/marked.min.js',
  'https://cdn.jsdelivr.net/npm/jszip@3.10.1/dist/jszip.min.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) =>
      // Best-effort precache; don't fail install if a CDN asset is briefly slow.
      Promise.all(SHELL.map((url) =>
        cache.add(url).catch((err) => console.warn('precache miss', url, err))
      ))
    )
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Pass-through for raw GitHub fallback fetches.
  if (url.hostname === 'raw.githubusercontent.com') return;

  // Same-origin .md fetches: stale-while-revalidate.
  const sameOrigin = url.origin === self.location.origin;
  const isMarkdown = url.pathname.endsWith('.md') || url.pathname.endsWith('_manifest.json');
  if (sameOrigin && isMarkdown) {
    event.respondWith(staleWhileRevalidate(event.request));
    return;
  }

  // App shell: cache-first, fall back to network, fall back to index.html.
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;
      return fetch(event.request).catch(() => {
        if (event.request.mode === 'navigate') return caches.match('./index.html');
        return new Response('offline', { status: 503 });
      });
    })
  );
});

async function staleWhileRevalidate(request) {
  const cache = await caches.open(CACHE_VERSION);
  const cached = await cache.match(request);
  const network = fetch(request).then((res) => {
    if (res && res.status === 200) cache.put(request, res.clone());
    return res;
  }).catch(() => cached);
  return cached || network;
}
