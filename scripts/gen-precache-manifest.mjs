#!/usr/bin/env node
// Tulis app/build/web/precache-manifest.json: daftar berkas yang disimpan
// sw.js supaya versi web bisa dibuka tanpa sinyal (NFR-4, jalur iPhone).
//
//   node scripts/gen-precache-manifest.mjs              # setelah flutter build web
//   node scripts/gen-precache-manifest.mjs <folder>     # folder build lain
//
// Dijalankan oleh .github/workflows/web.yml dan scripts/deploy-web.ps1 tepat
// setelah `flutter build web`. Tanpa manifest ini sw.js tidak menyimpan apa
// pun — halaman tetap jalan, hanya tidak offline.
//
// Bentuknya: { version, files }. `version` adalah sha256 atas daftar
// (path + hash isi) yang sudah diurutkan, jadi dua build yang isinya sama
// menghasilkan versi yang sama, dan satu byte yang berubah di berkas mana pun
// menghasilkan versi baru — sw.js memakainya sebagai nama cache, sehingga
// deploy baru otomatis mengganti cache lama.
//
// Yang tidak masuk daftar: manifest ini sendiri, sw.js (browser yang
// mengelolanya), api/ (fungsi server Vercel), vercel.json dan package.json
// (konfigurasi deploy, bukan bagian halaman).
//
// Juga tidak masuk, karena tidak pernah diminta browser tapi beratnya 28 MB
// dari 45 MB hasil build: peta debug *.js.symbols, dan varian CanvasKit yang
// hanya dipakai build --wasm atau flag eksperimen (skwasm*, wimp*,
// webparagraph/). Build ini dart2js + canvaskit, jadi yang dimuat hanya
// canvaskit/canvaskit.* (Safari, Firefox) dan canvaskit/chromium/* (Chrome).
// Menyimpan 45 MB per deploy di iPhone berarti kuota cache Safari cepat
// habis, dan tiap deploy menghabiskan kuota data orang tanpa guna.
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = resolve(process.argv[2] || join(root, 'app', 'build', 'web'));
const MANIFEST = 'precache-manifest.json';
const SKIP_FILES = new Set([MANIFEST, 'sw.js', 'vercel.json', 'package.json']);
const SKIP_DIRS = new Set(['api', 'canvaskit/webparagraph']);
const SKIP_PATTERNS = [/\.js\.symbols$/, /^canvaskit\/(skwasm|wimp)[^/]*$/];

function walk(dir, out = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const full = join(dir, entry.name);
    // Path selalu dengan garis miring, apa pun OS-nya: sw.js membacanya
    // sebagai URL relatif terhadap scope.
    const rel = relative(outDir, full).split('\\').join('/');
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(rel)) continue;
      walk(full, out);
    } else if (entry.isFile()) {
      if (rel.split('/').length === 1 && SKIP_FILES.has(rel)) continue;
      if (SKIP_PATTERNS.some((re) => re.test(rel))) continue;
      out.push(rel);
    }
  }
  return out;
}

if (!statSync(outDir, { throwIfNoEntry: false })?.isDirectory()) {
  console.error(`Folder build tidak ada: ${outDir}. Jalankan flutter build web dulu.`);
  process.exit(1);
}
if (!statSync(join(outDir, 'index.html'), { throwIfNoEntry: false })) {
  console.error(`${outDir} tidak berisi index.html — bukan hasil flutter build web.`);
  process.exit(1);
}

const files = walk(outDir).sort();
const digest = createHash('sha256');
let bytes = 0;
for (const file of files) {
  const content = readFileSync(join(outDir, file));
  bytes += content.length;
  digest.update(`${file}\t${createHash('sha256').update(content).digest('hex')}\n`);
}
const manifest = { version: digest.digest('hex'), files };
writeFileSync(join(outDir, MANIFEST), JSON.stringify(manifest, null, 2) + '\n');
console.log(`${MANIFEST}: ${files.length} berkas, ${(bytes / 1024 / 1024).toFixed(1)} MB, versi ${manifest.version.slice(0, 12)}`);
