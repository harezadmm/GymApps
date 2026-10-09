// Pustaka analisis recap: validasi payload, prompt, cadangan model, dan
// validasi jawaban. Jalankan: node --test web-api/test
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import {
  AiError,
  DEFAULT_MODELS,
  analyzeRecap,
  buildRequest,
  parseAnalysis,
  validatePayload,
} from '../api/_lib/recap-ai.js';

const sample = () => JSON.parse(readFileSync(new URL('./fixtures/recap-week.json', import.meta.url), 'utf8'));

const goodAnalysis = {
  headline: 'Bench naik, kaki tertinggal',
  summary: 'Tiga sesi minggu ini, lebih banyak dari minggu lalu.',
  strengths: ['Barbell Bench Press 60x8 → 62.5x8.'],
  critiques: ['Hamstring tidak dilatih sama sekali.'],
  suggestions: [{ title: 'Tambah hamstring', detail: 'Tambahkan 3 set Romanian Deadlift.' }],
  nextFocus: 'Seimbangkan volume kaki.',
};

const geminiOk = (analysis = goodAnalysis) =>
  new Response(
    JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify(analysis) }] }, finishReason: 'STOP' }] }),
    { status: 200, headers: { 'content-type': 'application/json' } },
  );
const status = (code) => new Response(JSON.stringify({ error: { code, message: 'x' } }), { status: code });

test('validatePayload menerima payload contoh dan menolak yang menyimpang', () => {
  assert.deepEqual(validatePayload(sample()), { ok: true });
  const bad = (mutate) => {
    const p = sample();
    mutate(p);
    return validatePayload(p);
  };
  assert.equal(bad((p) => (p.v = 2)).ok, false);
  assert.equal(bad((p) => (p.period = 'year')).ok, false);
  assert.equal(bad((p) => (p.lang = 'fr')).ok, false);
  assert.equal(bad((p) => (p.unit = 'stone')).ok, false);
  assert.equal(bad((p) => delete p.totals).ok, false);
  assert.equal(bad((p) => (p.exercises = Array.from({ length: 16 }, () => p.exercises[0]))).ok, false);
  assert.equal(bad((p) => (p.exercises[0].name = 'x'.repeat(200))).ok, false);
  assert.equal(bad((p) => (p.records = Array.from({ length: 11 }, () => p.records[0]))).ok, false);
  assert.deepEqual(bad((p) => (p.totals.sessions = 0)), { ok: false, error: 'empty' });
  assert.equal(validatePayload(null).ok, false);
  assert.equal(validatePayload([]).ok, false);
});

test('buildRequest: bahasa, periode, skema JSON, dan data sebagai pesan pengguna', () => {
  const id = buildRequest(sample());
  const sys = id.systemInstruction.parts[0].text;
  assert.match(sys, /Indonesian/);
  assert.match(sys, /kamu/);
  assert.match(sys, /week/);
  assert.match(sys, /kg/);
  assert.equal(id.generationConfig.responseMimeType, 'application/json');
  assert.ok(id.generationConfig.responseSchema.required.includes('suggestions'));
  const user = id.contents[0].parts[0].text;
  assert.ok(user.includes('"Barbell Bench Press"'));

  const en = buildRequest({ ...sample(), lang: 'en', period: 'month', unit: 'lb' });
  const sysEn = en.systemInstruction.parts[0].text;
  assert.match(sysEn, /English/);
  assert.match(sysEn, /month/);
  assert.match(sysEn, /lb/);
});

test('parseAnalysis memotong teks dan daftar yang terlalu panjang', () => {
  const long = {
    ...goodAnalysis,
    headline: 'h'.repeat(500),
    strengths: Array.from({ length: 9 }, (_, i) => `kuat ${i}\u0007`),
    suggestions: Array.from({ length: 9 }, () => ({ title: 't'.repeat(300), detail: 'd'.repeat(900) })),
  };
  const out = parseAnalysis(JSON.stringify(long));
  assert.equal(out.headline.length, 160);
  assert.equal(out.strengths.length, 5);
  assert.equal(out.strengths[0], 'kuat 0', 'karakter kendali dibuang');
  assert.equal(out.suggestions.length, 5);
  assert.equal(out.suggestions[0].title.length, 80);
  assert.equal(out.suggestions[0].detail.length, 320);
});

test('parseAnalysis menolak jawaban rusak atau kosong', () => {
  assert.throws(() => parseAnalysis('bukan json'), AiError);
  assert.throws(() => parseAnalysis(JSON.stringify({ ...goodAnalysis, headline: '' })), AiError);
  assert.throws(() => parseAnalysis(JSON.stringify({ ...goodAnalysis, suggestions: [] })), AiError);
  const { summary, ...noSummary } = goodAnalysis;
  assert.throws(() => parseAnalysis(JSON.stringify(noSummary)), AiError);
  assert.ok(summary);
});

test('analyzeRecap: kunci lewat header, bukan URL; model pertama dipakai bila berhasil', async () => {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    return geminiOk();
  };
  const res = await analyzeRecap(sample(), { apiKey: 'RAHASIA-123', fetchImpl });
  assert.equal(res.model, DEFAULT_MODELS[0]);
  assert.equal(res.analysis.headline, goodAnalysis.headline);
  assert.equal(calls.length, 1);
  assert.ok(!calls[0].url.includes('RAHASIA-123'), 'kunci tidak boleh ada di URL');
  assert.equal(calls[0].init.headers['x-goog-api-key'], 'RAHASIA-123');
  assert.ok(calls[0].url.includes(`/models/${DEFAULT_MODELS[0]}:generateContent`));
});

test('analyzeRecap pindah ke model cadangan pada 503, 429, 404, dan jawaban rusak', async () => {
  for (const first of [status(503), status(429), status(404), new Response('{"candidates":[]}', { status: 200 })]) {
    const seen = [];
    const fetchImpl = async (url) => {
      seen.push(url);
      return seen.length === 1 ? first : geminiOk();
    };
    const res = await analyzeRecap(sample(), { apiKey: 'k', fetchImpl, models: ['m-a', 'm-b'] });
    assert.equal(res.model, 'm-b');
    assert.equal(seen.length, 2);
  }
});

test('analyzeRecap pindah model saat batas waktu habis', async () => {
  let n = 0;
  const fetchImpl = (url, init) => {
    n++;
    if (n === 1) {
      return new Promise((_, reject) => {
        init.signal.addEventListener('abort', () => reject(Object.assign(new Error('aborted'), { name: 'AbortError' })));
      });
    }
    return Promise.resolve(geminiOk());
  };
  const res = await analyzeRecap(sample(), { apiKey: 'k', fetchImpl, models: ['m-a', 'm-b'], timeoutMs: 30 });
  assert.equal(res.model, 'm-b');
});

test('analyzeRecap: semua model sibuk → busy; 400/403 → failed tanpa mencoba lagi; kunci tidak bocor', async () => {
  await assert.rejects(
    analyzeRecap(sample(), { apiKey: 'RAHASIA-123', fetchImpl: async () => status(503), models: ['a', 'b'] }),
    (e) => e instanceof AiError && e.code === 'busy' && !e.message.includes('RAHASIA-123'),
  );
  for (const code of [400, 401, 403]) {
    let n = 0;
    await assert.rejects(
      analyzeRecap(sample(), {
        apiKey: 'RAHASIA-123',
        fetchImpl: async () => {
          n++;
          return status(code);
        },
        models: ['a', 'b'],
      }),
      (e) => e instanceof AiError && e.code === 'failed' && !String(e.stack).includes('RAHASIA-123'),
    );
    assert.equal(n, 1, `status ${code} tidak dicoba ke model lain`);
  }
  await assert.rejects(
    analyzeRecap(sample(), {
      apiKey: 'RAHASIA-123',
      fetchImpl: async () => {
        throw new Error('getaddrinfo ENOTFOUND RAHASIA-123');
      },
      models: ['a'],
    }),
    (e) => e instanceof AiError && !e.message.includes('RAHASIA-123'),
  );
});

test('analyzeRecap tanpa kunci → not_configured', async () => {
  await assert.rejects(analyzeRecap(sample(), { apiKey: '' }), (e) => e instanceof AiError && e.code === 'not_configured');
});

test('analyzeRecap berhenti saat anggaran waktu habis, tidak mencoba semua model', async () => {
  let n = 0;
  const hang = (url, init) => {
    n++;
    return new Promise((_, reject) => {
      init.signal.addEventListener('abort', () => reject(Object.assign(new Error('aborted'), { name: 'AbortError' })));
    });
  };
  await assert.rejects(
    analyzeRecap(sample(), { apiKey: 'k', fetchImpl: hang, models: ['a', 'b', 'c'], timeoutMs: 40, budgetMs: 60, minAttemptMs: 30 }),
    (e) => e instanceof AiError && e.code === 'busy',
  );
  assert.equal(n, 1, 'model kedua tidak dicoba karena sisa anggaran < minAttemptMs');
});
