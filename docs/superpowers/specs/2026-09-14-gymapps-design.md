# GymApps — Desain Aplikasi Gym Pribadi (fork openGym)

Tanggal: 2026-09-14
Status: desain disetujui secara lisan, belum ada kode. Dokumen ini adalah bahan eksekusi.
Referensi UI: `REFRENSI/Liftoff Apps/` (311 skrinsut aplikasi Liftoff, dipakai untuk tampilan saja, tanpa gamifikasi).
Base code: https://github.com/DuarteSantos8/openGym (commit a68a88d, 2026-09-13, v1.3.7, lisensi AGPL-3.0).

---

## 1. Tujuan

Aplikasi gym untuk pemakaian pribadi satu orang, dengan:

1. **APK Android** sebagai alat utama di gym (offline-first).
2. **Supabase** sebagai database dan auth, agar data tidak terkunci di HP.
3. **Dashboard web** untuk mengecek progres dari laptop.
4. **Pilihan split latihan** sebagai konsep utama: Push/Pull/Legs, Bro split, Upper/Lower, Heavy Duty, dan custom. Dengan mode rotasi (bukan hanya hari kalender tetap).
5. **Progressive overload otomatis**: setiap sesi dicatat (alat, set, rep, beban), sesi berikutnya sudah di-setup dengan target yang naik, dan alasan target itu ditampilkan.
6. **Tampilan** meniru gaya Liftoff: tema gelap, kartu besar membulat, bottom nav 5 tab, logger tabel SET / PREV / KG / REPS.

Yang **tidak** masuk scope (setidaknya fase ini): gamifikasi (XP, streak, quest, rank), fitur sosial, nutrisi, multi-user, admin dashboard, AI coach, MCP server, iOS.

---

## 2. Keputusan arsitektur dan alasannya

| Keputusan | Pilihan | Alasan |
|---|---|---|
| Base | **Flutter, dengan openGym sebagai rujukan algoritma** | Revisi 2026-09-15: pemilik produk memilih Flutter. Fork React tidak lagi jadi aplikasi. Yang tetap dipanen dari openGym: dataset 1.324 gerakan (dipakai apa adanya sebagai JSON) dan **aturan** engine progresi, 1RM, muscle map, recovery — dibaca dari `reference/opengym/src/lib/` lalu ditulis ulang dalam Dart beserta unit test-nya. Ongkosnya nyata: ~53.000 baris JS tidak ikut, tapi keputusan stack ada di pemilik produk. |
| Model data | **Tetap satu dokumen JSON** (`S`) seperti openGym | Seluruh lapisan penyimpanan openGym hanya ±200 baris (`lib/api.js` 83 baris, `lib/sync-merge.js` 105 baris, bagian push/pull di `store/useStore.js`). Semua analitik di `lib/` adalah fungsi murni atas dokumen ini. Normalisasi relasional berarti membongkar 36 ribu baris kode. |
| Backend | **Supabase**: tabel `user_state` dengan kolom jsonb + Supabase Auth | Mengganti server Node openGym. Passkey openGym memang tidak bisa dipakai di WebView Capacitor (didokumentasikan di `docs/MOBILE.md`), jadi Supabase Auth justru menyelesaikan masalah itu. |
| Auth | **Email + password**, satu akun | Personal, satu pengguna. Google OAuth di Capacitor perlu setup Google Console, SHA-1 fingerprint, dan deep link. Tidak sepadan untuk satu orang. Bisa ditambah nanti. |
| Sinkron | Offline-first: localStorage + file mirror di HP tetap sumber utama, Supabase cermin | Sama persis dengan pola openGym sekarang, hanya endpoint-nya diganti. `sync-merge.js` (merge berbasis revisi) dipakai apa adanya. |
| Dashboard web | **Vite + React SPA** terpisah di folder `dashboard/`, mengimpor `frontend/src/lib/` langsung | Stack sama dengan aplikasi, jadi fungsi progresi, 1RM, recovery, statistik dipakai ulang tanpa ditulis ulang. Bukan Next.js karena tidak perlu SSR dan lib openGym ditulis untuk browser. Deploy ke Vercel sebagai static site. |
| Gaya dashboard | Terang (light), kartu putih, mengikuti layar Analysis/Statistics Liftoff yang memang bertema terang | Layar analitik Liftoff sendiri terang. Konsisten dengan referensi, dan enak dibaca di laptop. |
| Query SQL atas set | **Fase lanjutan**: trigger Postgres yang men-flatten blob ke tabel `workout_sets` | Tidak mengubah aplikasi sama sekali. Ditambahkan hanya kalau dashboard butuh query yang tidak praktis dari blob. |
| Mengikuti upstream | Simpan remote `upstream` ke openGym, ambil perbaikan secara selektif dengan cherry-pick | openGym rilis dua mingguan. Perbaikan engine progresi layak diambil. Merge penuh tidak realistis setelah reskin. |

---

## 3. Struktur repo (monorepo)

```
GymApps/
├── REFRENSI/
│   ├── Liftoff Apps/         referensi gaya (311 skrinsut)
│   └── export/               12 layar + 7 dashboard dari Pen — acuan UI
├── docs/                     PRD, spec, dokumen upstream
├── app/                      APLIKASI FLUTTER
│   ├── lib/core/             theme.dart (token dari REFRENSI/export)
│   ├── lib/data/             backend.dart (getRev/pull/push), Supabase
│   ├── lib/domain/           progression, onerm, muscles — port Dart + test
│   ├── lib/ui/               layar, satu per artboard
│   ├── assets/data/          exercises.json (1.324 gerakan, dari openGym)
│   └── test/
├── reference/opengym/        fork React — RUJUKAN algoritma, tidak dibuild
├── supabase/migrations/      SQL: user_state, RLS, RPC push_state
└── package.json
```

Yang **dihapus** dari fork: `api/` (server Node), `mcp/`, `website/`, `web/` (Dockerfile nginx), `docker-compose.yml`, workflow CI Gitea/GitLab/GitHub, `views/Admin*.jsx`, `views/Coach*.jsx` dan `api/coach`. Kode i18n dibiarkan (EN saja yang dipakai; bahasa lain bisa dihapus dari bundle belakangan).

---

## 4. Supabase

### 4.1 Skema

```sql
create table public.user_state (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  rev        bigint not null default 0,
  state      jsonb  not null,
  updated_at timestamptz not null default now()
);
alter table public.user_state enable row level security;
create policy "own row" on public.user_state
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

### 4.2 RPC push dengan cek revisi (meniru `baseRev` openGym)

```sql
create or replace function public.push_state(p_base_rev bigint, p_state jsonb)
returns table (ok boolean, rev bigint, state jsonb)
language plpgsql security invoker as $$
declare cur_rev bigint;
begin
  select s.rev into cur_rev from public.user_state s where s.user_id = auth.uid();
  if cur_rev is null then
    insert into public.user_state(user_id, rev, state) values (auth.uid(), 1, p_state);
    return query select true, 1::bigint, p_state;
  elsif p_base_rev is null or p_base_rev = cur_rev then
    update public.user_state set rev = cur_rev + 1, state = p_state, updated_at = now()
      where user_id = auth.uid();
    return query select true, cur_rev + 1, p_state;
  else
    -- konflik: kembalikan versi server, klien melakukan merge (sync-merge.js) lalu push ulang
    return query select false, s.rev, s.state from public.user_state s where s.user_id = auth.uid();
  end if;
end $$;
```

Ukuran blob: satu pengguna, bertahun-tahun data, tetap di kisaran beberapa MB. Aman untuk jsonb.

### 4.3 Antarmuka backend di aplikasi

`frontend/src/lib/backend.js` mengekspor satu objek dengan tiga fungsi. `useStore.js` hanya memanggil ini, tidak lagi memanggil `api()`:

```js
getRev()                 // → number|null   (untuk checkRev)
pull()                   // → { rev, state }|null
push(baseRev, state)     // → { ok:true, rev } | { ok:false, rev, state }  (konflik → merge → push ulang)
```

Implementasi `backend-supabase.js` memakai `@supabase/supabase-js`. Session auth disimpan lewat `@aparajita/capacitor-secure-storage` yang sudah jadi dependensi openGym.

Yang dihapus di store: alur passkey, pairing code, guest mode, endpoint push notification server (rest timer di APK sudah pakai notifikasi lokal Capacitor, tidak butuh server).

### 4.4 Fase lanjutan (opsional): flatten ke tabel `workout_sets`

Trigger `after insert or update on user_state` yang mengurai `state->'workouts'` menjadi baris `(user_id, workout_id, date, routine, exercise_id, set_idx, weight, reps, rir, phase, type)`. Hanya dibuat kalau dashboard butuh SQL. Tidak menyentuh aplikasi.

---

## 5. Model split dan rotasi (`lib/program.js`)

openGym punya `S.week` (rutinitas per hari kalender) dan `S.dayPlan` (reschedule per tanggal). Itu dipertahankan sebagai **mode weekday**. Ditambah **mode rotasi**:

```js
S.program = {
  id: 'ppl' | 'bro' | 'ul' | 'hit' | 'custom',
  mode: 'weekday' | 'rotation',
  order: [routineId, ...],   // urutan sesi, misal [push, pull, legs]
  cursor: 0,                 // indeks sesi berikutnya
  minRestDays: 0,            // Heavy Duty: 3–4; lain: 0
  startedAt: 'YYYY-MM-DD'
}
```

Aturan (fungsi murni, ada test):

- `nextSession(S, today)` → `{ routineId, dueDate, reason }`. Mode weekday memakai logika openGym yang ada. Mode rotasi memakai `order[cursor]`; `dueDate = lastWorkoutDate + minRestDays`.
- `advanceCursor(S)` dipanggil oleh `finish-workout.js` saat sesi selesai dari program. Sesi freestyle tidak menggeser cursor.
- `skipSession(S)` menggeser cursor tanpa mencatat workout (untuk melewati sesi).
- Home menampilkan: "Berikutnya: Pull" dan, jika `minRestDays` belum terpenuhi, "Pulih dulu, jatuh tempo Kamis". Pengguna tetap boleh mulai lebih awal; ini saran, bukan kunci.

Template starter yang ditambahkan ke `lib/starter.js`:

| Split | Sesi | Mode default | Catatan |
|---|---|---|---|
| Push/Pull/Legs (ada) | 3 rutinitas | rotation | Dipakai 3 sampai 6 hari per minggu tergantung ritme |
| Upper/Lower (ada) | 2 rutinitas | rotation | |
| Full Body, 5×5 (ada) | dibiarkan | weekday | |
| **Bro split (baru)** | Chest, Back, Shoulders, Legs, Arms | weekday (Senin sampai Jumat) | 4 sampai 5 gerakan per sesi, 3 sampai 4 set, 8 sampai 12 rep, progresi double |
| **Heavy Duty (baru)** | Chest+Back, Legs, Delts+Arms, Legs | rotation, `minRestDays: 3` | 1 working set ke failure per gerakan setelah 1 sampai 2 warm-up, rep range 6 sampai 10, policy `hit` |

Isi gerakan per template dipilih dari library openGym (pakai id yang ada di `exercises-data.js`).

---

## 6. Progressive overload

### 6.1 Yang sudah ada dan dipakai apa adanya

`lib/progression.js`: policy `linear`, `greyskull`, `double`, `time`. Target sesi berikutnya diturunkan dari riwayat setiap kali dibutuhkan (tidak ada counter tersimpan), miss tidak pernah menaikkan beban, stall memicu deload, setiap target punya alasan teks (`progression-copy.js`). Ini persis kebutuhan "next latihan sudah di-setup beban tambahan".

### 6.2 Policy baru: `hit` (Heavy Duty)

Ditambahkan ke `POLICIES` dan `POLICIES_FOR.reps`. Aturan:

- Hanya membaca **satu working set** (baris non-warm-up pertama). Set tambahan diabaikan.
- Rep range `[lo, hi]`, default `[6, 10]`, memakai `rep-range.js` yang ada.
- `reps >= hi` → beban naik satu `inc` (default 2.5 kg atas, 5 kg bawah), reps target kembali ke `lo`.
- `lo <= reps < hi` → beban tetap, target reps = reps + 1.
- `reps < lo` dua sesi berturut → deload memakai `deloadFactorOf(cfg)`, dan saran menaikkan `minRestDays` satu hari (ditampilkan sebagai alasan, tidak otomatis mengubah program).
- 1RM tetap dihitung dari set itu (masuk cap 12 rep).

Ditulis dengan unit test di `progression.test.js`, mengikuti aturan CONTRIBUTING openGym: apa pun yang memutuskan beban berikutnya adalah fungsi murni yang diuji.

### 6.3 Ringkasan overload di dashboard

- Tabel "Target sesi berikutnya" per gerakan: beban, rep, dan alasan, hasil `nextPrescription(S, cfg, routine)`.
- Tren e1RM dan volume mingguan per gerakan (fungsi `onerm.js` yang ada).
- Penanda stall: gerakan yang tidak naik e1RM selama 3 minggu.

---

## 7. Alat per gym (fase 2)

openGym sudah punya `equipProfiles` (filter alat yang dimiliki) dan `gymCards`. Ditambah: `exWeights` diberi kunci per profil gym, sehingga mesin chest press di gym A dan gym B menyimpan beban terakhir masing-masing. Profil aktif dipilih saat mulai sesi. Masuk fase 2 karena tidak menghalangi fitur inti.

---

## 8. Reskin gaya Liftoff (aplikasi)

Prinsip: ubah token CSS dan tata letak beberapa layar, jangan bongkar struktur komponen.

- **Tema**: gelap default. Latar `#0f0f14`, kartu `#1a1a22`, aksen biru langit `#5ac8fa`, hijau selesai `#2ecc71`, radius kartu 20 px, tinggi kartu aksi besar (72 px). Token di `index.css` (`--bg`, `--bg-el`, `--acc`) diganti; tema terang tetap tersedia.
- **Bottom nav 5 tab**: Workout, Home, Stats, History, Profile (ganti `TabBar.jsx`). Plan dan Library dipindah ke dalam tab Workout seperti Liftoff (segmen "Tracker | My Plan", kartu "Exercise Library").
- **Home**: header ringkas (berat badan terakhir, sesi minggu ini), kartu besar "Sesi berikutnya: Pull, jatuh tempo hari ini" dengan tombol Start, strip hari.
- **Workout (logger)**: header sticky dengan rest timer di tengah, kartu per gerakan dengan ikon gerakan kiri, toggle rest timer per gerakan, tabel `SET | PREV | KG | REPS | ✓`, baris selesai berlatar hijau gelap, tombol "+ ADD SET" lebar penuh, menu ⋯ per gerakan (Reorder, Notes, Superset, Replace, Remove) memakai menu openGym yang ada.
- **Stats**: tema terang seperti layar Analysis Liftoff: heatmap otot depan-belakang (`BodyMap.jsx` yang ada), radar 6 region (Back, Chest, Core, Arms, Shoulders, Legs), pemilih rentang waktu.
- Tanpa maskot, XP, streak, quest, ranks, eggs.

Skrinsut acuan per layar: `01_Onboarding_Auth/Home_Screen.jpg` (grid kartu), `03_Workout_Logger_Tracker/Tracker.jpg`, `Rest.jpg`, `Rest_3.jpg` (logger dan menu), `04_Ranked_Stats_Analytics/Analysis.jpg` (stats), `03_Workout_Logger_Tracker/Is_This_Your_Equipment.jpg` (pemilih alat), `02_Workout_Planning_Routines/Update_Legs.jpg` (dialog update rutinitas setelah sesi: "Update sets only", dan opsi "jadikan default").

---

## 9. Dashboard web (`dashboard/`)

Vite + React + react-router. Login Supabase (akun yang sama). Membaca `user_state.state` sekali saat buka, lalu berlangganan Realtime pada baris itu agar sesi yang baru selesai di HP langsung tampil.

Halaman:

1. **Overview**: heatmap aktivitas tahunan (`Heatmap.jsx`), sesi minggu ini vs program, grafik berat badan dengan garis target (`LineChart.jsx`).
2. **Progres per gerakan**: pilih gerakan, grafik e1RM dan volume, tabel sesi, target berikutnya dan alasannya.
3. **Program**: split aktif, posisi cursor rotasi, kepatuhan (sesi terencana vs terlaksana per minggu), penanda stall.
4. **Otot**: BodyMap mode Balance, Fatigue, Strength (komponen openGym yang ada).
5. **Riwayat**: tabel semua sesi dengan filter tanggal, rutinitas, gerakan; ekspor CSV.
6. **Pengaturan**: unduh backup JSON (blob mentah), ganti password.

Gaya: terang, kartu putih membulat, sidebar kiri dengan item aktif berbentuk pill biru, mini-chart di kartu ringkasan. Komponen chart openGym dipakai ulang; kalau butuh grafik lebih kaya, tambah Recharts.

Dashboard **hanya membaca** pada fase pertama. Edit dari web (misal ubah rutinitas) masuk fase lanjutan karena butuh alur merge dua arah yang sudah disediakan `sync-merge.js` tapi perlu diuji.

---

## 10. Urutan pengerjaan (milestone)

| # | Milestone | Isi | Kriteria selesai |
|---|---|---|---|
| M0 | Fork dan toolchain | Clone openGym ke `frontend/`, hapus bagian server/admin/coach/MCP, `npm run build:mobile`, `npx cap open android`, build debug APK, pasang di HP | APK openGym polos jalan di HP, tes vitest hijau |
| M1 | Supabase | Proyek Supabase, migrasi §4, `backend.js` + `backend-supabase.js`, layar login email/password menggantikan `Login.jsx` dan `MobileOnboarding.jsx`, push/pull/konflik diuji | Sesi yang dicatat di HP muncul di tabel `user_state`; instal ulang APK lalu login memulihkan data |
| M2 | Split dan Heavy Duty | `program.js`, mode rotasi di Home, template Bro dan Heavy Duty, policy `hit` + test | Program Heavy Duty berjalan 2 siklus dengan target naik dan pesan alasan yang benar |
| M3 | Reskin Liftoff | Token CSS, TabBar 5 tab, Home, Workout, Stats sesuai §8 | Skrinsut side-by-side dengan referensi untuk 4 layar utama |
| M4 | Dashboard web | `dashboard/` §9, deploy Vercel | Buka dashboard di laptop, lihat sesi yang baru selesai di HP dalam hitungan detik |
| M5 | Fase lanjutan | Alat per gym (§7), trigger flatten (§4.4), edit dari web, Google sign-in | Sesuai kebutuhan |

Alasan urutan: risiko terbesar ada di toolchain Android (M0), lalu keamanan data (M1). Fitur baru (M2) dikerjakan sebelum kosmetik (M3) supaya reskin dilakukan sekali atas layar yang sudah final. Dashboard (M4) terakhir karena hanya membaca data yang sudah stabil.

---

## 11. Yang harus disiapkan pengguna sebelum eksekusi

Akun dan kredensial:
- Proyek Supabase (free tier cukup). Dibutuhkan: Project URL, anon key, dan akses ke SQL editor atau Supabase CLI. Aktifkan provider Email di Authentication, matikan "Confirm email" agar satu akun bisa dibuat langsung.
- Akun Vercel (atau Netlify) untuk dashboard. Boleh ditunda sampai M4.

Toolchain di mesin Windows:
- Node.js 22 (versi yang dipakai openGym).
- JDK 17 dan Android Studio (Android SDK 34+, platform tools). Dibutuhkan untuk `cap sync` dan build APK.
- Keystore untuk menandatangani APK release (`keytool -genkey`). Untuk debug APK tidak perlu.
- HP Android dengan USB debugging, atau sideload file APK.

Data pribadi untuk seed awal (bisa diisi di aplikasi):
- Split yang sedang dipakai dan hari latihannya.
- Daftar alat yang tersedia di gym-mu (untuk `equipProfiles`).
- Berat badan awal, satuan kg, increment default (2.5 kg atas, 5 kg bawah, bisa diubah).
- Untuk Heavy Duty: rep range dan jumlah hari istirahat yang kamu pakai, kalau berbeda dari default 6 sampai 10 rep dan 3 hari.

---

## 12. Risiko dan mitigasi

- **Build Android gagal** (Gradle, SDK versi). Mitigasi: M0 dikerjakan pertama, pakai versi persis dari `docs/MOBILE.md` openGym.
- **Blob jsonb membesar**. Satu pengguna tidak akan melewati puluhan MB dalam beberapa tahun. Jika perlu, workouts lama bisa dipindah ke tabel arsip tanpa mengubah aplikasi.
- **Konflik sinkron** kalau HP dan web menulis bersamaan. Fase pertama web hanya membaca, jadi konflik hanya antar perangkat HP, dan itu sudah ditangani `sync-merge.js`.
- **Drift dari upstream**. Cherry-pick selektif hanya untuk `lib/`, yang paling jarang berubah bentuknya dan paling berharga.
- **Lisensi AGPL**. Untuk pemakaian pribadi tidak ada kewajiban. Jika suatu hari dipublikasikan sebagai layanan, kode harus dibuka.

---

## 13. Keputusan yang masih bisa kamu ubah tanpa membongkar desain

- Auth email+password → Google sign-in (M5).
- Gaya dashboard terang → gelap (hanya token CSS).
- Default Heavy Duty (rep range, hari istirahat).
- Menyimpan atau membuang bahasa selain EN dari bundle.
