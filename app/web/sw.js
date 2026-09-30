// Service worker GymApps web: precache supaya aplikasi terbuka tanpa sinyal,
// plus notifikasi "istirahat selesai".
//
// Kenapa precache di sini, bukan service worker bawaan Flutter: versi Flutter
// ini memasang pekerja pembersih yang langsung mencabut pendaftarannya
// sendiri (lihat flutter_bootstrap.js), dan pencabutan itu ikut menghapus
// langganan push. Jadi satu pekerja ini yang memegang keduanya.
//
// Versi web adalah jalur iPhone. Di gym sering tidak ada sinyal (NFR-4), dan
// web_account_store.dart sudah mengandalkan sesi yang tersimpan supaya
// membuka aplikasi lagi tidak butuh jaringan — tapi itu percuma kalau
// halamannya sendiri tidak bisa dimuat. Daftar berkas yang harus tersimpan
// datang dari precache-manifest.json (dibuat scripts/gen-precache-manifest.mjs
// setelah flutter build web); versinya menjadi nama cache, sehingga deploy
// baru = cache baru, dan cache lama dibuang saat pekerja baru aktif.
//
// Yang tidak disentuh: permintaan lintas origin (Supabase, media dari CDN),
// dan /api/ (alarm istirahat) — keduanya memang butuh jaringan.

const MANIFEST = 'precache-manifest.json';
const CACHE_PREFIX = 'gymapps-';

// Nama cache versi yang dipasang pekerja ini. Diisi saat install; kalau
// pekerja sempat dimatikan browser dan dibangunkan lagi, dicari ulang lewat
// manifest yang tersimpan (lihat currentCache()).
let currentCacheName = null;

const scopeUrl = (path) => new URL(path, self.registration.scope).href;

async function currentCache() {
  if (currentCacheName && (await caches.has(currentCacheName))) return currentCacheName;
  currentCacheName = null;
  for (const name of await caches.keys()) {
    if (!name.startsWith(CACHE_PREFIX)) continue;
    const cache = await caches.open(name);
    const stored = await cache.match(scopeUrl(MANIFEST));
    if (!stored) continue;
    try {
      const manifest = await stored.json();
      if (CACHE_PREFIX + manifest.version === name) {
        currentCacheName = name;
        break;
      }
    } catch (_) {
      // Manifest rusak: cache ini tidak dipercaya, lanjut ke yang lain.
    }
  }
  return currentCacheName;
}

async function precache() {
  // cache: 'reload' — manifest harus datang dari server, bukan dari HTTP
  // cache browser, supaya deploy baru benar-benar terlihat.
  const response = await fetch(scopeUrl(MANIFEST), { cache: 'reload' });
  if (!response.ok) throw new Error(`precache-manifest.json: HTTP ${response.status}`);
  const manifest = await response.clone().json();
  if (!manifest || typeof manifest.version !== 'string' || !Array.isArray(manifest.files)) {
    throw new Error('precache-manifest.json tidak valid');
  }
  const name = CACHE_PREFIX + manifest.version;
  if (await caches.has(name)) {
    // Versi yang sama sudah tersimpan (pekerja dipasang ulang tanpa deploy
    // baru): tidak perlu mengunduh 2,4 MB lagi.
    currentCacheName = name;
    return;
  }
  const cache = await caches.open(name);
  try {
    // Semua atau tidak sama sekali: setengah cache berarti aplikasi yang
    // gagal separuh jalan saat offline. Kalau satu berkas gagal, install
    // gagal, cache versi lama tetap dipakai, dan dicoba lagi lain kali.
    await Promise.all(
      manifest.files.map(async (file) => {
        const url = scopeUrl(file);
        const res = await fetch(url, { cache: 'reload' });
        if (!res.ok) throw new Error(`${file}: HTTP ${res.status}`);
        await cache.put(url, res);
      }),
    );
    await cache.put(scopeUrl(MANIFEST), response);
  } catch (err) {
    await caches.delete(name);
    throw err;
  }
  currentCacheName = name;
}

self.addEventListener('install', (event) => {
  event.waitUntil(precache().then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keep = await currentCache();
      for (const name of await caches.keys()) {
        if (name.startsWith(CACHE_PREFIX) && name !== keep) await caches.delete(name);
      }
      await self.clients.claim();
    })(),
  );
});

async function fromCache(request) {
  // Flutter kadang menambahkan query (?v=…) pada berkasnya; isi berkasnya
  // tetap yang tersimpan di manifest.
  return (await caches.match(request)) || (await caches.match(request, { ignoreSearch: true }));
}

// Halaman dan manifest: jaringan dulu supaya deploy baru langsung terlihat,
// cache hanya kalau jaringan tidak ada.
async function networkFirst(request, fallbackUrl) {
  try {
    return await fetch(request);
  } catch (err) {
    const cached = (await fromCache(request)) || (fallbackUrl && (await caches.match(fallbackUrl)));
    if (cached) return cached;
    throw err;
  }
}

// Aset (main.dart.js, CanvasKit, font, ikon): cache dulu — isinya tidak
// berubah tanpa deploy, dan deploy berarti versi cache baru.
async function cacheFirst(request) {
  const cached = await fromCache(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok) {
    const name = await currentCache();
    if (name) {
      const cache = await caches.open(name);
      await cache.put(request, response.clone());
    }
  }
  return response;
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  // Alarm istirahat di server: harus sampai ke jaringan, tidak pernah dari cache.
  if (url.href.startsWith(scopeUrl('api/'))) return;
  // Permintaan DevTools/only-if-cached lintas mode membuat Chrome melempar
  // error kalau dijawab pekerja.
  if (request.cache === 'only-if-cached' && request.mode !== 'same-origin') return;

  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request, scopeUrl('index.html')));
  } else if (url.href === scopeUrl(MANIFEST)) {
    event.respondWith(networkFirst(request));
  } else {
    event.respondWith(cacheFirst(request));
  }
});

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }
  // Safari mencabut langganan kalau push datang tanpa notifikasi yang tampil,
  // jadi notifikasi selalu ditampilkan — juga saat aplikasi sedang terbuka.
  event.waitUntil(
    self.registration.showNotification(data.title || 'GymApps', {
      body: data.body || '',
      tag: data.tag || 'rest',
      renotify: true,
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      vibrate: [200, 100, 200, 100, 200],
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ('focus' in client) return client.focus();
      }
      return self.clients.openWindow('./');
    }),
  );
});
