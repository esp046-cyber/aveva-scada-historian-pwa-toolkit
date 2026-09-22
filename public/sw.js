// public/sw.js
// Offline-first service worker for field sites with unreliable UAE cellular
// backhaul. Strategy:
//   - App shell (HTML/CSS/JS)   -> cache-first, so the console still opens
//     with zero signal at a remote pump station.
//   - /api/historian/*          -> stale-while-revalidate, so the last known
//     good trend/alarm data renders instantly while a fresh fetch runs.
//   - /api/telemetry/log (POST) -> network-first with an IndexedDB outbox;
//     failed manual entries queue and flush on reconnect via Background Sync.
//   - /api/stream (SSE)         -> never cached, always network.

const SHELL_CACHE = 'agc-shell-v1';
const API_CACHE = 'agc-api-v1';
const OUTBOX_DB = 'agc-outbox';
const OUTBOX_STORE = 'pending-writes';

const SHELL_ASSETS = ['/', '/manifest.json'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE).then((cache) => cache.addAll(SHELL_ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((k) => ![SHELL_CACHE, API_CACHE].includes(k)).map((k) => caches.delete(k)))
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Never intercept the SSE stream -- must stay live network-only.
  if (url.pathname === '/api/stream') return;

  // Queue manual telemetry POSTs when offline.
  if (url.pathname === '/api/telemetry/log' && request.method === 'POST') {
    event.respondWith(handleTelemetryPost(request));
    return;
  }

  // Stale-while-revalidate for Historian read APIs.
  if (url.pathname.startsWith('/api/historian/')) {
    event.respondWith(staleWhileRevalidate(request));
    return;
  }

  // Cache-first app shell for navigations and static assets.
  if (request.method === 'GET') {
    event.respondWith(cacheFirst(request));
  }
});

async function cacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) return cached;
  try {
    const response = await fetch(request);
    const cache = await caches.open(SHELL_CACHE);
    cache.put(request, response.clone());
    return response;
  } catch {
    return caches.match('/');
  }
}

async function staleWhileRevalidate(request) {
  const cache = await caches.open(API_CACHE);
  const cached = await cache.match(request);

  const networkFetch = fetch(request)
    .then((response) => {
      cache.put(request, response.clone());
      return response;
    })
    .catch(() => null);

  return cached || (await networkFetch) || new Response(JSON.stringify({ error: 'offline' }), { status: 503 });
}

async function handleTelemetryPost(request) {
  const clone = request.clone();
  try {
    return await fetch(request);
  } catch {
    const body = await clone.json();
    await queueOutboxWrite(body);
    if ('sync' in self.registration) {
      await self.registration.sync.register('flush-telemetry-outbox');
    }
    return new Response(JSON.stringify({ queued: true }), {
      status: 202,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}

self.addEventListener('sync', (event) => {
  if (event.tag === 'flush-telemetry-outbox') {
    event.waitUntil(flushOutbox());
  }
});

function openOutboxDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(OUTBOX_DB, 1);
    req.onupgradeneeded = () => {
      req.result.createObjectStore(OUTBOX_STORE, { keyPath: 'id', autoIncrement: true });
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function queueOutboxWrite(body) {
  const db = await openOutboxDb();
  await new Promise((resolve, reject) => {
    const tx = db.transaction(OUTBOX_STORE, 'readwrite');
    tx.objectStore(OUTBOX_STORE).add({ body, queuedAt: Date.now() });
    tx.oncomplete = resolve;
    tx.onerror = reject;
  });
}

async function flushOutbox() {
  const db = await openOutboxDb();
  const tx = db.transaction(OUTBOX_STORE, 'readonly');
  const entries = await new Promise((resolve, reject) => {
    const req = tx.objectStore(OUTBOX_STORE).getAll();
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });

  for (const entry of entries) {
    try {
      await fetch('/api/telemetry/log', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(entry.body),
      });
      const delTx = db.transaction(OUTBOX_STORE, 'readwrite');
      delTx.objectStore(OUTBOX_STORE).delete(entry.id);
    } catch {
      // leave it queued, retry on next sync event
    }
  }
}
