# Recap mingguan/bulanan + Analisis AI (v3.1)

Permintaan pengguna (9 Okt 2026): recap mingguan/bulanan supaya progres terlihat,
plus analisis AI (Gemini) atas progres beban, rep, dan waktu latihan yang
memberi kritik dan saran. Mengikuti token dan komponen `design/UI-V3.md`.

## 1. Arsitektur

```
HP / web ──(ringkasan angka + token Supabase)──▶ Vercel /api/recap-analyze ──▶ Gemini
   ▲                                                   │ cek token (/auth/v1/user)
   └──────────── {analysis, model} ◀───────────────────┘ batas harian per akun
```

- **Kunci Gemini hanya di server** (env Vercel `GEMINI_API_KEY`, salinan lokal
  `.secrets/gemini.json` yang di-gitignore). Tidak pernah masuk APK, bundel web,
  atau repo — kunci di klien bisa diekstrak siapa pun yang memegang APK.
- Fungsi hanya melayani akun yang masuk (token Supabase dicek seperti
  `rest-alarm.js`). Akun lokal tanpa server: analisis AI tidak tersedia, recap
  angka tetap jalan penuh (offline-first).
- Yang dikirim: ringkasan angka periode itu (nama gerakan, beban × rep, set,
  menit, set per otot, berat badan awal/akhir). Tidak ada email, catatan bebas,
  atau riwayat mentah. Layar menyebutkannya di bawah tombol analisis.
- Model: `gemini-3.5-flash` (thinking bawaan; ±9 dtk; paling spesifik), cadangan
  otomatis `gemini-2.5-flash` saat 429/5xx/timeout. Bisa diganti lewat env
  `GEMINI_MODELS` (daftar dipisah koma). Keluaran JSON terstruktur
  (`responseSchema`), divalidasi dan dipotong di server.
- **Payload disusun ulang di server** (`sanitizePayload`): hanya field yang
  dikenal, nama dipotong 80 karakter, set harus berbentuk `62.5x8` / `BWx12` /
  `45s`. Field bebas dibuang — endpoint tidak bisa dipakai sebagai proksi LLM.
- **Kuota atomik** lewat RPC Supabase `consume_ai_quota()`
  (`supabase/migrations/0004_ai_quota.sql`, dijalankan manual di SQL Editor):
  20 analisis/akun/hari dan 200/hari global, batasnya tertanam di fungsi SQL,
  tanpa fungsi "kembalikan kuota". Selama migrasi belum dijalankan, cadangannya
  Runtime Cache (best effort): satu analisis berjalan per akun, batas per akun
  (`AI_DAILY_LIMIT`) + global (`AI_GLOBAL_DAILY_LIMIT`), dan kuota hanya
  dikembalikan untuk galat sementara dari Google (429/5xx/batas waktu).
- Payload ≤ 24 KB, timeout per model 25 dtk dalam anggaran total 50 dtk,
  fungsi `maxDuration` 60. Supabase yang tak bisa dihubungi → 503, bukan 401.
- Hasil disimpan lokal per akun + periode bersama sidik jari payload. Membuka
  recap yang sama tidak memanggil AI lagi; kalau datanya berubah, hasil lama
  tetap tampil dengan tanda "data berubah" dan tombol analisis ulang.

## 2. Domain (`lib/domain/recap.dart`)

- `RecapPeriod { week, month }`; `RecapRange [start, end)`; minggu mengikuti
  `settings.weekStartsOn`, bulan = bulan kalender.
- `buildRecap(history, period, range, catalog?, bodyweight, today?)` menghitung
  untuk periode dan periode sebelumnya. **Periode yang masih berjalan**
  (`today` di dalamnya, bukan hari terakhir) dibandingkan dengan bagian yang
  sama dari periode lalu (`elapsedDays` hari pertamanya) untuk total dan volume
  gerakan; top set dan perkiraan 1RM tetap dibandingkan dengan seluruh periode
  lalu. Payload membawa `elapsedDays`, dan prompt menilai laju "sejauh ini".
  Yang dihitung: sesi, set kerja, volume (kg·rep), total rep,
  menit latihan (dari `durationSeconds`), rata-rata menit per sesi, hari latihan,
  jeda terpanjang antar hari latihan, volume per hari (minggu) / per minggu
  (bulan), per gerakan (sesi, set, volume, top set = set kerja biasa dengan perkiraan 1RM terbaik,
  atau beban lalu rep bila salah satu tanpa perkiraan,
  e1RM terbaik, pembanding periode sebelumnya, rentang rep target, set sesi
  terakhir), rekor (e1RM periode > semua sebelum periode), set kerja per otot
  utama, berat badan awal → akhir.
- Set kerja = tercentang dan bukan pemanasan (sama dengan seluruh aplikasi).
- `recapPayload(...)` → JSON ringkas dalam satuan tampilan; maksimal 15 gerakan,
  10 rekor, nama ≤ 80 karakter; untuk bulan ada `muscleSetsPerWeek` (dibagi
  minggu yang sudah lewat, minimal satu). Berat badan awal hanya dari catatan
  ≤ 14 hari sebelum periode. `payloadFingerprint` = sha1.

## 3. Layar

**Recap** (halaman dorong): nav kaca · `SegmentedTabs` Mingguan/Bulanan ·
pemilih periode (‹ "28 Sep – 4 Okt" ›, sub "Minggu ini") · kisi 2×2 KPI (Sesi,
Volume, Waktu latihan, Set kerja) dengan `ChangePill` vs periode sebelumnya ·
**kartu Analisis AI** · Konsistensi (titik hari / kalender bulan + rata-rata
menit, jeda terpanjang, rencana program) · Volume per hari/minggu (`BarSeries`)
· Progres beban & rep (top set sebelumnya → sekarang + pil e1RM) · Rekor baru ·
Set per otot. Periode kosong → `EmptyState`.

**Kartu Analisis AI**: siap (penjelasan + catatan data dikirim + tombol) ·
memuat · hasil (judul, ringkasan, Sudah bagus, Kritik, Saran, Fokus berikutnya,
"Dianalisis … · model", analisis ulang) · galat (tidak tersambung, batas harian,
sibuk, offline, gagal) · tidak tersedia (akun lokal).

**Pintu masuk**: kartu "Recap minggu ini" di Beranda (atau "minggu lalu" kalau
minggu ini masih kosong; tersembunyi kalau keduanya kosong) dan tombol "Recap"
di header Statistik.
