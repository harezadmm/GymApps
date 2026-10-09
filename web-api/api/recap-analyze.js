// Analisis AI untuk recap mingguan/bulanan (spec design/RECAP-AI.md §1).
//
// Aplikasi mengirim ringkasan angka periode itu; fungsi ini meneruskannya ke
// Gemini dan mengembalikan kritik + saran. Kunci Gemini hanya ada di env
// server (GEMINI_API_KEY) — tidak pernah di APK atau bundel web.
//
// * Hanya akun GymApps yang masuk: token Supabase dicek ke /auth/v1/user,
//   sama dengan rest-alarm.js.
// * Batas harian per akun lewat Runtime Cache (AI_DAILY_LIMIT, bawaan 20).
//   Percobaan yang gagal di sisi model tidak memakan kuota.
// * Payload dibatasi ukurannya dan divalidasi sebelum dikirim ke model.

import { createHash } from 'node:crypto';

import { AiError, DEFAULT_MODELS, MAX_PAYLOAD_BYTES, analyzeRecap, validatePayload } from './_lib/recap-ai.js';

const readEnv = (name) => (process.env[name] || '').replace(/^﻿/, '').trim();

const json = (status, body) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  });

// Diimpor saat dipakai, bukan di atas: tes menyuntikkan cache sendiri dan
// tidak perlu memasang @vercel/functions.
const vercelCache = async () => (await import('@vercel/functions')).getCache();

async function userIdFrom(request, fetchImpl, envGet) {
  const auth = request.headers.get('authorization') || '';
  if (!auth.startsWith('Bearer ')) return null;
  const url = envGet('SUPABASE_URL'), anon = envGet('SUPABASE_ANON_KEY');
  if (!url || !anon) return null;
  try {
    const r = await fetchImpl(`${url}/auth/v1/user`, { headers: { apikey: anon, authorization: auth } });
    if (!r.ok) return null;
    const user = await r.json();
    return typeof user?.id === 'string' ? user.id : null;
  } catch {
    return null;
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

    const uid = await userIdFrom(request, fetchImpl, envGet);
    if (!uid) return json(401, { error: 'unauthorized' });

    const check = validatePayload(body?.payload);
    if (!check.ok) return json(400, { error: check.error });

    const apiKey = envGet('GEMINI_API_KEY');
    if (!apiKey) return json(503, { error: 'not_configured' });

    const limit = Number(envGet('AI_DAILY_LIMIT')) || 20;
    const day = now().toISOString().slice(0, 10);
    const who = createHash('sha256').update(uid).digest('hex').slice(0, 24);
    const key = `recap-ai:${who}:${day}`;
    const store = await cache();
    const used = Number(await store.get(key)) || 0;
    if (used >= limit) return json(429, { error: 'limit', limit });
    const keep = { ttl: 26 * 3600, name: 'recap-ai' };
    await store.set(key, used + 1, keep);

    const models = envGet('GEMINI_MODELS')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    try {
      const { analysis, model } = await analyzeRecap(body.payload, {
        apiKey,
        models: models.length ? models : DEFAULT_MODELS,
        fetchImpl,
        log: (l) => console.log('recap-ai', JSON.stringify(l)),
      });
      return json(200, { analysis, model, remaining: Math.max(0, limit - used - 1) });
    } catch (e) {
      // Model sibuk atau jawabannya rusak bukan salah pemakai: kuotanya
      // dikembalikan supaya "coba lagi" tetap bisa.
      await store.set(key, used, keep);
      const code = e instanceof AiError ? e.code : 'failed';
      if (!(e instanceof AiError)) console.warn('recap-ai gagal tak terduga', e?.name);
      const status = code === 'busy' || code === 'not_configured' ? 503 : 502;
      return json(status, { error: code });
    }
  };
}

export const POST = createHandler();
