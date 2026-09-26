// Service worker GymApps web: hanya untuk notifikasi "istirahat selesai".
//
// Service worker bawaan Flutter sengaja tidak dipakai (lihat
// flutter_bootstrap.js): versi Flutter ini memasang pekerja pembersih yang
// langsung mencabut pendaftarannya sendiri, dan pencabutan itu ikut
// menghapus langganan push.
//
// Tidak ada handler fetch: halaman tetap diambil dari jaringan seperti biasa.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

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
