// Fungsi /api/recap-analyze: token Supabase, ukuran, validasi, batas harian,
// dan pemetaan galat. Semua ketergantungan luar disuntikkan.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import { createHandler } from '../api/recap-analyze.js';

const sample = () => JSON.parse(readFileSync(new URL('./fixtures/recap-week.json', import.meta.url), 'utf8'));
const analysis = {
  headline: 'Bagus',
  summary: 'Tiga sesi.',
  strengths: ['a'],
  critiques: ['b'],
  suggestions: [{ title: 'c', detail: 'd' }],
  nextFocus: 'e',
};

function memoryCache() {
  const m = new Map();
  return {
    store: m,
    get: async (k) => m.get(k),
    set: async (k, v) => void m.set(k, v),
  };
}

const ENV = {
  SUPABASE_URL: 'https://proj.supabase.co',
  SUPABASE_ANON_KEY: 'anon',
  GEMINI_API_KEY: 'RAHASIA-GEMINI',
  AI_DAILY_LIMIT: '2',
};

function setup({ env = ENV, gemini = 200, supabase = 200 } = {}) {
  const calls = { supabase: 0, gemini: 0 };
  const fetchImpl = async (url, init) => {
    if (url.startsWith(env.SUPABASE_URL || 'https://proj.supabase.co')) {
      calls.supabase++;
      assert.equal(init.headers.apikey, 'anon');
      if (supabase !== 200) return new Response('{}', { status: supabase });
      return new Response(JSON.stringify({ id: 'user-1' }), { status: 200 });
    }
    calls.gemini++;
    if (gemini !== 200) return new Response('{}', { status: gemini });
    return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify(analysis) }] } }] }), {
      status: 200,
    });
  };
  const cache = memoryCache();
  const handler = createHandler({
    fetchImpl,
    cache: () => cache,
    envGet: (k) => env[k] || '',
    now: () => new Date('2026-10-09T10:00:00Z'),
  });
  return { handler, calls, cache };
}

const req = (body, { token = 'tok' } = {}) =>
  new Request('https://gymapps.test/api/recap-analyze', {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });

const read = async (res) => ({ status: res.status, body: await res.json(), text: '' });

test('tanpa token → 401, Supabase dan Gemini tidak dipanggil', async () => {
  const { handler, calls } = setup();
  const res = await read(await handler(req({ payload: sample() }, { token: null })));
  assert.equal(res.status, 401);
  assert.equal(res.body.error, 'unauthorized');
  assert.deepEqual(calls, { supabase: 0, gemini: 0 });
});

test('token ditolak Supabase → 401', async () => {
  const { handler, calls } = setup({ supabase: 401 });
  const res = await read(await handler(req({ payload: sample() })));
  assert.equal(res.status, 401);
  assert.equal(calls.gemini, 0);
});

test('badan terlalu besar → 413; JSON rusak → 400', async () => {
  const { handler } = setup();
  const big = { payload: { ...sample(), pad: 'x'.repeat(40 * 1024) } };
  assert.equal((await handler(req(big))).status, 413);
  const bad = await read(await handler(req('{rusak')));
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error, 'bad_json');
});

test('payload tidak sesuai kontrak → 400 bad_payload; periode kosong → 400 empty', async () => {
  const { handler, calls } = setup();
  const bad = await read(await handler(req({ payload: { ...sample(), period: 'year' } })));
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error, 'bad_payload');
  const empty = sample();
  empty.totals.sessions = 0;
  const e = await read(await handler(req({ payload: empty })));
  assert.equal(e.body.error, 'empty');
  assert.equal(calls.gemini, 0);
});

test('kunci Gemini belum diisi → 503 not_configured', async () => {
  const { handler } = setup({ env: { ...ENV, GEMINI_API_KEY: '' } });
  const res = await read(await handler(req({ payload: sample() })));
  assert.equal(res.status, 503);
  assert.equal(res.body.error, 'not_configured');
});

test('berhasil → 200 {analysis, model, remaining}; batas harian → 429', async () => {
  const { handler, calls } = setup();
  const ok = await read(await handler(req({ payload: sample() })));
  assert.equal(ok.status, 200);
  assert.equal(ok.body.analysis.headline, 'Bagus');
  assert.equal(typeof ok.body.model, 'string');
  assert.equal(ok.body.remaining, 1);
  assert.equal((await handler(req({ payload: sample() }))).status, 200);
  const limited = await read(await handler(req({ payload: sample() })));
  assert.equal(limited.status, 429);
  assert.equal(limited.body.error, 'limit');
  assert.equal(calls.gemini, 2, 'panggilan ketiga tidak sampai ke Gemini');
});

test('Gemini sibuk → 503 busy, kuota dikembalikan, kunci tidak bocor', async () => {
  const { handler, cache } = setup({ gemini: 503 });
  const res = await handler(req({ payload: sample() }));
  const text = await res.text();
  assert.equal(res.status, 503);
  assert.equal(JSON.parse(text).error, 'busy');
  assert.ok(!text.includes('RAHASIA-GEMINI'));
  assert.deepEqual([...cache.store.values()], [0], 'percobaan gagal tidak memakan kuota');
});

test('Gemini menolak permintaan → 502 failed', async () => {
  const { handler } = setup({ gemini: 400 });
  const res = await read(await handler(req({ payload: sample() })));
  assert.equal(res.status, 502);
  assert.equal(res.body.error, 'failed');
});
