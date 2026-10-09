// Analisis AI untuk recap mingguan/bulanan (spec design/RECAP-AI.md §1).
//
// Aplikasi mengirim ringkasan angka periode itu; fungsi ini meneruskannya ke
// Gemini dan mengembalikan kritik + saran. Kunci Gemini hanya ada di env
// server (GEMINI_API_KEY) — tidak pernah di APK atau bundel web.
//
// * Hanya akun GymApps yang masuk: token Supabase dicek ke /auth/v1/user,
//   sama dengan rest-alarm.js. Supabase yang tidak bisa dihubungi menghasilkan
//   503, bukan 401 — itu bukan salah akun pemakai.
// * Payload disusun ulang dari field yang dikenal saja (sanitizePayload):
//   tidak ada teks bebas yang sampai ke model.
// * Kuota harian per akun dan global, ATOMIK lewat RPC Supabase
//   `consume_ai_quota` (supabase/migrations/0004_ai_quota.sql). Selama migrasi
//   itu belum dijalankan, cadangannya Runtime Cache: satu permintaan berjalan
//   per akun, batas per akun + global, dan kuota hanya dikembalikan untuk
//   galat sementara dari Google (429/5xx/batas waktu) — best effort, karena
//   Runtime Cache tidak punya operasi atomik.

import { createHash } from 'node:crypto';

import { AiError, DEFAULT_MODELS, MAX_PAYLOAD_BYTES, analyzeRecap, sanitizePayload } from './_lib/recap-ai.js';

const readEnv = (name) => (process.env[name] || '').replace(/^﻿/, '').trim();

const json = (status, body) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  });

// Diimpor saat dipakai, bukan di atas: tes menyuntikkan cache sendiri dan
// tidak perlu memasang @vercel/functions.
const vercelCache = async () => (await import('@vercel/functions')).getCache();

/** @returns {Promise<{uid: string} | {error: 'unauthorized' | 'unavailable'}>} */
async function userFrom(request, fetchImpl, envGet) {
  const auth = request.headers.get('authorization') || '';
  if (!auth.startsWith('Bearer ')) return { error: 'unauthorized' };
  const url = envGet('SUPABASE_URL'), anon = envGet('SUPABASE_ANON_KEY');
  if (!url || !anon) return { error: 'unavailable' };
  try {
    const r = await fetchImpl(`${url}/auth/v1/user`, { headers: { apikey: anon, authorization: auth } });
    if (r.status === 401 || r.status === 403) return { error: 'unauthorized' };
    if (!r.ok) return { error: 'unavailable' };
    const user = await r.json();
    return typeof user?.id === 'string' ? { uid: user.id } : { error: 'unauthorized' };
  } catch {
    return { error: 'unavailable' };
  }
}

/**
 * Kuota atomik lewat RPC Supabase dengan token pemakai sendiri. Batasnya
 * tertanam di fungsi SQL, jadi memanggil RPC langsung tidak bisa
 * melonggarkannya.
 * @returns {Promise<{mode: 'rpc', remaining: number} | {mode: 'rpc', limited: true} | {mode: 'missing'} | {mode: 'error'}>}
 */
async function consumeAtomic(request, fetchImpl, envGet) {
  try {
    const r = await fetchImpl(`${envGet('SUPABASE_URL')}/rest/v1/rpc/consume_ai_quota`, {
      method: 'POST',
      headers: {
        apikey: envGet('SUPABASE_ANON_KEY'),
        authorization: request.headers.get('authorization'),
        'content-type': 'application/json',
      },
      body: '{}',
    });
    // Fungsi belum dipasang (PGRST202 / 404): pakai cadangan.
    if (r.status === 404) return { mode: 'missing' };
    if (!r.ok) return { mode: 'error' };
    const n = Number(await r.json());
    if (!Number.isFinite(n)) return { mode: 'error' };
    return n < 0 ? { mode: 'rpc', limited: true } : { mode: 'rpc', remaining: n };
  } catch {
    return { mode: 'error' };
  }
}

export function createHandler({
  fetchImpl = globalThis.fetch,
  cache = vercelCache,
  envGet = readEnv,
  now = () => new Date(),
} = {}) {
  return async function handle(request) {
    const text = await request.text();
    if (Buffer.byteLength(text, 'utf8') > MAX_PAYLOAD_BYTES + 1024) return json(413, { error: 'too_large' });
    let body;
    try {
      body = JSON.parse(text);
    } catch {
      return json(400, { error: 'bad_json' });
    }

    const who = await userFrom(request, fetchImpl, envGet);
    if (who.error === 'unauthorized') return json(401, { error: 'unauthorized' });
    if (who.error) return json(503, { error: 'auth_unavailable' });

    const check = sanitizePayload(body?.payload);
    if (!check.ok) return json(400, { error: check.error });

    const apiKey = envGet('GEMINI_API_KEY');
    if (!apiKey) return json(503, { error: 'not_configured' });

    const limit = Number(envGet('AI_DAILY_LIMIT')) || 20;
    const globalLimit = Number(envGet('AI_GLOBAL_DAILY_LIMIT')) || 200;
    const day = now().toISOString().slice(0, 10);
    const id = createHash('sha256').update(who.uid).digest('hex').slice(0, 24);
    const store = await cache();
    const keep = { ttl: 26 * 3600, name: 'recap-ai' };

    // Satu analisis berjalan per akun — mengetuk dua kali, atau skrip yang
    // menembak paralel, tidak menggandakan panggilan ke Gemini.
    const lockKey = `recap-ai:lock:${id}`;
    if (await store.get(lockKey)) return json(429, { error: 'in_progress' });
    await store.set(lockKey, 1, { ttl: 75, name: 'recap-ai' });

    try {
      let remaining;
      let refund = async () => {};
      const atomic = await consumeAtomic(request, fetchImpl, envGet);
      if (atomic.mode === 'rpc') {
        if (atomic.limited) return json(429, { error: 'limit' });
        remaining = atomic.remaining;
      } else if (atomic.mode === 'missing') {
        const userKey = `recap-ai:${id}:${day}`;
        const globalKey = `recap-ai:global:${day}`;
        const used = Number(await store.get(userKey)) || 0;
        const usedGlobal = Number(await store.get(globalKey)) || 0;
        if (used >= limit || usedGlobal >= globalLimit) return json(429, { error: 'limit', limit });
        await store.set(userKey, used + 1, keep);
        await store.set(globalKey, usedGlobal + 1, keep);
        remaining = Math.max(0, limit - used - 1);
        // Dikurangi dari nilai terbaru, bukan ditimpa dengan angka lama —
        // supaya permintaan lain yang berhasil di sela-selanya tetap terhitung.
        refund = async () => {
          for (const k of [userKey, globalKey]) {
            const n = Number(await store.get(k)) || 0;
            await store.set(k, Math.max(0, n - 1), keep);
          }
        };
      } else {
        return json(503, { error: 'auth_unavailable' });
      }

      const models = envGet('GEMINI_MODELS')
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);
      try {
        const { analysis, model } = await analyzeRecap(check.payload, {
          apiKey,
          models: models.length ? models : DEFAULT_MODELS,
          fetchImpl,
          log: (l) => console.log('recap-ai', JSON.stringify(l)),
        });
        return json(200, { analysis, model, remaining });
      } catch (e) {
        const code = e instanceof AiError ? e.code : 'failed';
        // Hanya galat sementara dari Google yang dikembalikan kuotanya.
        // Jawaban yang gagal divalidasi atau diblokir tetap terhitung —
        // payload yang sengaja memicunya tidak boleh jadi panggilan gratis.
        if (code === 'busy') await refund();
        if (!(e instanceof AiError)) console.warn('recap-ai gagal tak terduga', e?.name);
        const status = code === 'busy' || code === 'not_configured' ? 503 : 502;
        return json(status, { error: code });
      }
    } finally {
      await store.delete(lockKey);
    }
  };
}

export const POST = createHandler();
