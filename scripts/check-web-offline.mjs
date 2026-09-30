#!/usr/bin/env node
// Uji mode offline versi web (NFR-4, jalur iPhone): sajikan app/build/web,
// buka di Chromium lewat Playwright, tunggu sw.js selesai menyimpan semua
// berkas di precache-manifest.json, lalu putus jaringan DAN matikan
// servernya, muat ulang — halaman harus tetap tampil dari cache.
//
//   cd app && flutter build web --release --no-web-resources-cdn --dart-define=... && cd ..
//   node scripts/gen-precache-manifest.mjs
//   NODE_PATH=$(npm root -g) node scripts/check-web-offline.mjs [folder-build]
//
// Playwright tidak ada di package.json — dipakai dari pemasangan global
// (npm i -g playwright; npx playwright install chromium). Kalau modul atau
// browsernya tidak ada, skrip keluar 0 dengan pesan "dilewati", supaya aman
// dipanggil dari mesin tanpa browser.
//
// Servernya ikut dimatikan, bukan hanya context.setOffline(true): emulasi
// offline Playwright berlaku untuk halaman, sedangkan fetch() dari dalam
// service worker bisa lolos ke jaringan sungguhan. Tanpa server yang mati,
// uji ini lulus walau cache-nya kosong.
import { execSync } from 'node:child_process';
import { readFile, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { dirname, extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = resolve(process.argv[2] || join(root, 'app', 'build', 'web'));
const CACHE_PREFIX = 'gymapps-';
const STEP_TIMEOUT = 45_000;

function loadPlaywright() {
  const require = createRequire(import.meta.url);
  try {
    return require('playwright');
  } catch (_) {
    // NODE_PATH tidak diset: cari sendiri di folder global npm.
  }
  try {
    const globalRoot = execSync('npm root -g', { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
    return require(join(globalRoot, 'playwright'));
  } catch (_) {
    return null;
  }
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
  '.css': 'text/css',
  '.txt': 'text/plain',
  '.ico': 'image/x-icon',
};

// Server statis seadanya: cukup untuk melayani hasil build dari 127.0.0.1.
// Cache-Control: no-cache supaya HTTP cache browser tidak diam-diam menjawab
// saat offline — yang diuji cache service worker, bukan cache browser.
async function serve(dir) {
  const sockets = new Set();
  const server = createServer(async (req, res) => {
    let rel = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    if (rel.endsWith('/')) rel += 'index.html';
    const file = resolve(dir, '.' + rel);
    if (file !== dir && !file.startsWith(dir + sep)) {
      res.writeHead(403).end();
      return;
    }
    try {
      if (!(await stat(file)).isFile()) throw new Error('bukan berkas');
      const body = await readFile(file);
      res.writeHead(200, {
        'Content-Type': MIME[extname(file)] || 'application/octet-stream',
        'Content-Length': body.length,
        'Cache-Control': 'no-cache',
      });
      res.end(body);
    } catch (_) {
      res.writeHead(404, { 'Content-Type': 'text/plain' }).end('404');
    }
  });
  server.on('connection', (s) => {
    sockets.add(s);
    s.on('close', () => sockets.delete(s));
  });
  await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
  return {
    url: `http://127.0.0.1:${server.address().port}/`,
    close: () =>
      new Promise((ok) => {
        for (const s of sockets) s.destroy();
        server.close(() => ok());
      }),
  };
}

const sleep = (ms) => new Promise((ok) => setTimeout(ok, ms));

async function until(label, probe, timeout = STEP_TIMEOUT) {
  const started = Date.now();
  for (;;) {
    if (await probe()) return Date.now() - started;
    if (Date.now() - started > timeout) throw new Error(`habis waktu ${timeout / 1000}s: ${label}`);
    await sleep(250);
  }
}

// Halaman dianggap tampil kalau layar boot ("Memuat GymApps…") sudah dilepas
// oleh flutter-first-frame, atau elemen Flutter sudah ada di DOM.
const pageRendered = () =>
  !document.getElementById('boot') ||
  document.getElementById('boot').classList.contains('done') ||
  !!document.querySelector('flutter-view, flt-glass-pane');

async function main() {
  const manifestFile = join(outDir, 'precache-manifest.json');
  const manifest = JSON.parse(await readFile(manifestFile, 'utf8').catch(() => {
    throw new Error(`${manifestFile} tidak ada. Jalankan flutter build web lalu scripts/gen-precache-manifest.mjs.`);
  }));
  const cacheName = CACHE_PREFIX + manifest.version;

  const pw = loadPlaywright();
  if (!pw) {
    console.log('check-web-offline: dilewati — modul playwright tidak ditemukan (npm i -g playwright).');
    return 0;
  }
  let browser;
  try {
    browser = await pw.chromium.launch();
  } catch (err) {
    if (/Executable doesn't exist|playwright install/i.test(String(err))) {
      console.log('check-web-offline: dilewati — browser Chromium Playwright belum terpasang.');
      return 0;
    }
    throw err;
  }

  const server = await serve(outDir);
  const t0 = Date.now();
  const failures = [];
  let code = 1;
  try {
    // Chromium headless tanpa locale membuat Flutter melempar "Incorrect
    // locale information provided" sebelum bingkai pertama; ponsel sungguhan
    // selalu punya locale.
    const context = await browser.newContext({ locale: 'id-ID' });
    const page = await context.newPage();
    const sameOriginFailed = [];
    page.on('requestfailed', (r) => {
      if (r.url().startsWith(server.url)) sameOriginFailed.push(`${r.url().slice(server.url.length)} (${r.failure()?.errorText})`);
    });
    page.on('console', (m) => {
      if (m.type() === 'error') console.log(`  [console] ${m.text()}`);
    });
    page.on('pageerror', (e) => console.log(`  [pageerror] ${e.message}`));

    console.log(`Membuka ${server.url} (${manifest.files.length} berkas di manifest)`);
    await page.goto(server.url, { waitUntil: 'load' });

    let ms = await until('service worker aktif', () =>
      page.evaluate(async () => {
        const reg = await navigator.serviceWorker?.getRegistration();
        return !!reg?.active && reg.active.state === 'activated';
      }));
    console.log(`  service worker aktif setelah ${ms} ms`);

    ms = await until('precache lengkap', () =>
      page.evaluate(async ([name, files]) => {
        if (!(await caches.has(name))) return false;
        const cache = await caches.open(name);
        for (const file of [...files, 'precache-manifest.json']) {
          if (!(await cache.match(new URL(file, document.baseURI).href))) return false;
        }
        return true;
      }, [cacheName, manifest.files]));
    console.log(`  ${manifest.files.length} berkas tersimpan di ${cacheName.slice(0, 20)}… setelah ${ms} ms`);

    ms = await until('bingkai pertama Flutter (online)', () => page.evaluate(pageRendered));
    console.log(`  halaman tampil online setelah ${ms} ms`);

    // Putus semuanya: jaringan halaman dan server.
    await context.setOffline(true);
    await server.close();
    sameOriginFailed.length = 0;

    let response;
    try {
      response = await page.reload({ waitUntil: 'load' });
    } catch (err) {
      throw new Error(`muat ulang offline gagal: ${err.message}`);
    }
    if (!response) throw new Error('muat ulang offline: tidak ada respons');
    if (!response.ok()) throw new Error(`muat ulang offline: HTTP ${response.status()}`);
    if (!response.fromServiceWorker()) failures.push('index.html tidak datang dari service worker');
    if (!page.url().startsWith(server.url)) failures.push(`halaman berpindah ke ${page.url()} (halaman error browser?)`);
    const title = await page.title();
    if (title !== 'GymApps') failures.push(`judul halaman "${title}", bukan "GymApps"`);

    try {
      ms = await until('halaman tampil offline', () => page.evaluate(pageRendered));
      console.log(`  halaman tampil offline setelah ${ms} ms`);
    } catch (err) {
      failures.push(err.message);
    }
    const missing = sameOriginFailed.filter((f) => manifest.files.some((m) => f.startsWith(m)));
    if (missing.length) failures.push(`berkas manifest gagal dimuat offline: ${missing.join(', ')}`);
    if (sameOriginFailed.length) console.log(`  permintaan gagal saat offline: ${sameOriginFailed.join(', ')}`);

    code = failures.length ? 1 : 0;
  } catch (err) {
    failures.push(err.message);
  } finally {
    await browser.close().catch(() => {});
    await server.close().catch(() => {});
  }
  for (const f of failures) console.log(`GAGAL: ${f}`);
  console.log(`${code === 0 ? 'OK' : 'GAGAL'}: aplikasi web ${code === 0 ? 'terbuka' : 'tidak terbuka'} tanpa jaringan (${((Date.now() - t0) / 1000).toFixed(1)} s)`);
  return code;
}

main().then(
  (code) => process.exit(code),
  (err) => {
    console.error(err);
    process.exit(1);
  },
);
