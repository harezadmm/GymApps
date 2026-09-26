// Tanda istirahat selesai untuk versi web (iPhone).
//
// Safari menghentikan JavaScript begitu layar terkunci, jadi timer di halaman
// tidak bisa berbunyi. Yang bisa berbunyi di layar terkunci hanya notifikasi
// push — dan push harus dikirim dari server. Fungsi ini menerima "bunyikan
// dalam N detik", menunggu, lalu mengirim Web Push ke langganan HP itu.
//
// * Hanya akun GymApps yang masuk: token Supabase dicek ke /auth/v1/user.
// * Satu alarm aktif per akun. Alarm baru (durasi diubah, set berikutnya)
//   menggantikan yang lama; pembatalan menghapusnya. Keduanya lewat Runtime
//   Cache: saat bangun, alarm yang bukan lagi alarm terbaru tidak dikirim.
// * Fungsi dibatasi ±5 menit, istirahat boleh sampai 30 menit. Penantian
//   dipotong per 270 detik; sisanya diteruskan ke panggilan berikutnya yang
//   ditandatangani HMAC, supaya tidak ada orang lain yang bisa memakainya.
// * Endpoint push dibatasi ke layanan push yang dikenal. Tanpa ini, fungsi ini
//   bisa disuruh mengirim POST ke alamat mana pun.

import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { getCache, waitUntil } from '@vercel/functions';
import webpush from 'web-push';

const HOP_SECONDS = 270;
const MAX_DELAY = 30 * 60 + 60;
const PUSH_HOSTS = [
  /(^|\.)push\.apple\.com$/,
  /^fcm\.googleapis\.com$/,
  /^android\.googleapis\.com$/,
  /(^|\.)push\.services\.mozilla\.com$/,
  /(^|\.)notify\.windows\.com$/,
];

const env = (name) => {
  // Nilai yang diisi lewat pipa PowerShell bisa membawa BOM di depannya, dan
  // header HTTP menolak karakter itu.
  const v = (process.env[name] || '').replace(/^\uFEFF/, '').trim();
  if (!v) throw new Error(`env ${name} belum diisi`);
  return v;
};

const json = (status, body) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function validSubscription(sub) {
  if (!sub || typeof sub.endpoint !== 'string' || !sub.keys) return false;
  if (typeof sub.keys.p256dh !== 'string' || typeof sub.keys.auth !== 'string') return false;
  let url;
  try {
    url = new URL(sub.endpoint);
  } catch {
    return false;
  }
  return url.protocol === 'https:' && PUSH_HOSTS.some((re) => re.test(url.hostname));
}

const clip = (s, n) => (typeof s === 'string' ? s.slice(0, n) : '');

async function userIdFrom(request) {
  const auth = request.headers.get('authorization') || '';
  if (!auth.startsWith('Bearer ')) return null;
  const r = await fetch(`${env('SUPABASE_URL')}/auth/v1/user`, {
    headers: { apikey: env('SUPABASE_ANON_KEY'), authorization: auth },
  });
  if (!r.ok) return null;
  const user = await r.json();
  return typeof user?.id === 'string' ? user.id : null;
}

const sign = (payload) => createHmac('sha256', env('REST_ALARM_SECRET')).update(payload).digest('hex');

function verified(payload, sig) {
  if (typeof sig !== 'string') return false;
  const a = Buffer.from(sign(payload));
  const b = Buffer.from(sig);
  return a.length === b.length && timingSafeEqual(a, b);
}

const keyFor = (uid) => `rest:${uid}`;

/// Tunggu sampai `remaining` detik atau satu langkah, lalu kirim atau teruskan.
async function run(origin, alarm) {
  const cache = getCache();
  const hop = Math.min(alarm.remaining, HOP_SECONDS);
  await sleep(hop * 1000);
  if ((await cache.get(keyFor(alarm.uid))) !== alarm.id) {
    console.log('alarm dilewati: diganti atau dibatalkan');
    return;
  }
  const rest = alarm.remaining - hop;
  if (rest > 0) {
    const cont = JSON.stringify({ ...alarm, remaining: rest });
    await fetch(`${origin}/api/rest-alarm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ action: 'continue', cont, sig: sign(cont) }),
    });
    return;
  }
  webpush.setVapidDetails(env('VAPID_SUBJECT'), env('VAPID_PUBLIC_KEY'), env('VAPID_PRIVATE_KEY'));
  try {
    const res = await webpush.sendNotification(
      alarm.sub,
      JSON.stringify({ title: alarm.title, body: alarm.body, tag: 'rest' }),
      { TTL: 120, urgency: 'high' },
    );
    console.log('push terkirim', res.statusCode, new URL(alarm.sub.endpoint).host);
  } catch (e) {
    console.warn('push gagal', e?.statusCode, e?.body);
  }
  await cache.delete(keyFor(alarm.uid));
}

export async function POST(request) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json(400, { error: 'bad json' });
  }
  const origin = new URL(request.url).origin;
  const cache = getCache();

  if (body.action === 'continue') {
    if (!verified(body.cont, body.sig)) return json(403, { error: 'bad signature' });
    const alarm = JSON.parse(body.cont);
    waitUntil(run(origin, alarm));
    return json(202, { ok: true });
  }

  const uid = await userIdFrom(request);
  if (!uid) return json(401, { error: 'not signed in' });

  if (body.action === 'cancel') {
    await cache.delete(keyFor(uid));
    return json(200, { ok: true });
  }

  if (body.action !== 'schedule') return json(400, { error: 'unknown action' });
  const delay = Math.round(Number(body.delaySeconds));
  if (!Number.isFinite(delay) || delay < 1 || delay > MAX_DELAY) return json(400, { error: 'bad delay' });
  if (!validSubscription(body.subscription)) return json(400, { error: 'bad subscription' });

  const alarm = {
    id: randomUUID(),
    uid,
    remaining: delay,
    sub: { endpoint: body.subscription.endpoint, keys: body.subscription.keys },
    title: clip(body.title, 80) || 'GymApps',
    body: clip(body.body, 160),
  };
  await cache.set(keyFor(uid), alarm.id, { ttl: delay + 300, name: 'rest-alarm' });
  waitUntil(run(origin, alarm));
  return json(202, { ok: true, id: alarm.id });
}
