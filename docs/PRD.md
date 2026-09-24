# PRD — GymApps

Product Requirements Document untuk aplikasi gym pribadi.
Versi 1.0, 2026-09-14. Pemilik produk: Hariz.
Dokumen pendamping: `docs/superpowers/specs/2026-09-14-gymapps-design.md` (desain teknis). PRD ini menentukan **apa** yang harus jadi dan **bagaimana membuktikannya**; spec menentukan **bagaimana** membangunnya. Jika keduanya bertentangan, PRD menang untuk perilaku produk, spec menang untuk pilihan teknis.

Cara membaca: setiap kebutuhan punya ID (`FR-xx` fungsional, `NFR-xx` non-fungsional), prioritas (P0 wajib untuk rilis pertama, P1 penting, P2 nanti), dan kriteria penerimaan (KP) yang harus lolos sebelum kebutuhan dianggap selesai.

---

## 1. Ringkasan

GymApps adalah aplikasi Android untuk mencatat latihan beban di gym dan mengatur progressive overload secara otomatis, dengan dashboard web untuk memantau progres dari laptop. Dibangun dengan Flutter, data disimpan di Supabase, algoritma latihan di-port dari openGym, tampilan mengikuti desain di `REFRENSI/export/`.

Satu kalimat: **buka aplikasi, dia sudah tahu sesi apa hari ini dan berapa beban yang harus diangkat, kamu tinggal centang set yang selesai.**

### Base code

| | |
|---|---|
| Repo | https://github.com/DuarteSantos8/openGym |
| Mirror kanonik (CI, rilis) | https://gitlab.com/DuarteSantos8/opengym |
| Versi acuan | v1.3.7, commit `a68a88d` (2026-09-13) |
| Lisensi | AGPL-3.0-or-later |
| Stack GymApps | **Flutter 3.47 / Dart 3.13, Supabase** (keputusan 2026-09-15, menggantikan React+Capacitor) |
| Stack openGym (rujukan) | React 19, Vite, Zustand, Capacitor 7 |
| Demo | https://opengym.duarte-santos.ch/demo/ |
| Dokumen wajib dibaca sebelum eksekusi | `CLAUDE.md` (arsitektur), `CONTRIBUTING.md` (aturan: logika beban wajib fungsi murni + unit test), `docs/MOBILE.md` (build APK), `frontend/src/lib/progression.js` (engine progresi) |

Cara memakai: repo ini **tidak di-fork sebagai aplikasi**. Sejak stack pindah ke Flutter (2026-09-15) ia jadi **rujukan algoritma** di `reference/opengym/`: kode `lib/`-nya dibaca sebagai spesifikasi yang sudah teruji, lalu di-port ke Dart beserta test-nya. Yang dipakai langsung tanpa penulisan ulang hanya datanya — 1.324 gerakan di `app/assets/data/exercises.json`. Detail struktur di spec §3.

---

## 2. Masalah yang diselesaikan

1. **Lupa beban dan rep sesi lalu.** Catatan di notes HP atau ingatan tidak konsisten, akibatnya progressive overload tidak terjadi.
2. **Tidak tahu kapan harus naik beban.** Keputusan naik atau tetap dibuat berdasarkan perasaan, bukan aturan.
3. **Split latihan kaku.** Aplikasi yang ada mengikat rutinitas ke hari kalender. Jika Senin bolos, seluruh minggu bergeser. Program seperti Heavy Duty yang butuh jeda 3 sampai 4 hari tidak bisa dimodelkan.
4. **Data terkunci di HP.** Tidak bisa melihat tren jangka panjang dengan nyaman di layar besar.
5. **Aplikasi komersial penuh gangguan.** Langganan, iklan, gamifikasi berlebihan, fitur sosial yang tidak dibutuhkan.

---

## 3. Tujuan dan metrik keberhasilan

| Tujuan | Metrik | Target |
|---|---|---|
| Setiap sesi tercatat lengkap | Persentase sesi yang diselesaikan dengan semua working set tercentang | ≥ 90% sesi |
| Progressive overload terjadi | Persentase gerakan utama yang e1RM-nya naik dalam 8 minggu | ≥ 70% gerakan compound |
| Aplikasi tidak menghambat latihan | Jumlah tap dari buka aplikasi sampai set pertama tercentang | ≤ 4 tap |
| Data aman | Sesi yang hilang karena ganti HP atau instal ulang | 0 |
| Dashboard dipakai | Dashboard dibuka minimal sekali per minggu | ya |

---

## 4. Pengguna dan konteks

Satu pengguna: pemilik produk sendiri. Latihan 3 sampai 6 kali per minggu di gym komersial, kadang lebih dari satu gym. HP dipakai di antara set dengan tangan berkeringat dan perhatian terbatas. Laptop dipakai di rumah untuk melihat tren.

Konsekuensi desain:
- Elemen tap harus besar, kontras tinggi, satu tangan.
- Angka yang dibutuhkan saat set (beban target, rep target, beban sesi lalu) harus terlihat tanpa scroll atau tap tambahan.
- Aplikasi harus berfungsi penuh tanpa sinyal.
- Tidak ada notifikasi motivasi, streak, atau pengingat kecuali rest timer.

---

## 5. Lingkup

### Masuk lingkup rilis pertama (P0 dan P1)

- Tanpa layar login. Mode lokal adalah default; sinkronisasi ke Supabase opsional, dinyalakan dengan satu tombol.
- Library gerakan bawaan openGym (1.324 gerakan dengan animasi) dan gerakan custom.
- Program split: Push/Pull/Legs, Upper/Lower, Bro split, Heavy Duty, Full Body, custom. Mode hari kalender dan mode rotasi.
- Logger sesi lengkap: set, rep, beban, RIR/RPE opsional, warm-up, drop set, rest-pause, superset, rest timer, catatan.
- Progressive overload otomatis: linear, Greyskull, double progression, Heavy Duty (`hit`), deload otomatis, alasan target selalu ditampilkan.
- Statistik di aplikasi: riwayat, tren e1RM per gerakan, heatmap otot.
- Dashboard web baca-saja: overview, progres per gerakan, program, otot, riwayat, ekspor.
- Backup JSON manual.
- Tampilan gaya Liftoff: tema gelap, bottom nav 5 tab, logger tabel.

### Tidak masuk lingkup

- Gamifikasi: XP, level, streak, quest, rank, maskot, egg, reward.
- Fitur sosial: teman, feed, komentar, leaderboard, berbagi ke media sosial.
- Nutrisi dan makro.
- Multi-user, admin, undangan.
- AI coach, chat, MCP server.
- iOS.
- Publikasi ke Play Store (sideload saja).
- Integrasi wearable atau Health Connect.
- Bahasa selain Inggris di UI (Indonesia bisa ditambah nanti; teks gerakan bawaan berbahasa Inggris).

---

## 6. Prinsip produk

1. **Angka yang bisa diaudit.** Setiap beban target menampilkan alasan singkat ("naik 2,5 kg karena semua rep tercapai dua sesi berturut"). Tidak ada angka yang muncul tanpa asal.
2. **Log adalah fakta, target adalah turunan.** Yang tersimpan hanya apa yang benar-benar terjadi. Target dihitung ulang dari riwayat setiap kali dibutuhkan. Memperbaiki satu set yang salah ketik otomatis memperbaiki target berikutnya.
3. **Saran, bukan kunci.** Aplikasi menyarankan sesi dan beban, pengguna selalu bisa menimpa tanpa dialog konfirmasi.
4. **Offline dulu.** Semua fitur logging berjalan tanpa jaringan. Sinkron terjadi di latar belakang.
5. **Sedikit tapi benar.** Fitur yang tidak dipakai dihapus, bukan disembunyikan.

---

## 7. Alur utama

### 7.1 Pertama kali pakai
Buka APK → langsung ke onboarding tanpa layar akun → pilih program split dari template atau buat sendiri → pilih profil alat gym → tiba di Home yang menampilkan sesi berikutnya.

### 7.2 Hari latihan
Buka aplikasi → Home menampilkan "Sesi berikutnya: Pull, jatuh tempo hari ini" → tap Start → aplikasi minta berat badan (opsional, bisa dilewati) → layar Workout terbuka dengan semua gerakan, target beban dan rep sudah terisi, kolom PREV menunjukkan sesi lalu → selesai satu set, tap centang → rest timer berjalan otomatis → ulangi → tap Finish → ringkasan: durasi, volume, PR baru, otot yang dilatih, dan preview target sesi berikutnya → cursor rotasi bergeser.

### 7.3 Hari tidak sesuai rencana
Buka aplikasi → Home menampilkan "Berikutnya: Legs, bisa kapan saja" (mode rotasi) atau "Hari istirahat, sesi berikutnya Kamis: Legs" (mode kalender) → pengguna bisa Start sekarang, Skip sesi, atau mulai Freestyle.

### 7.4 Cek progres di laptop
Buka dashboard web → sekali saja masukkan kode pairing 6 digit dari HP (kunjungan berikutnya langsung masuk) → Overview menampilkan heatmap aktivitas, sesi minggu ini vs rencana, berat badan → buka Progres, pilih Bench Press → grafik e1RM 12 minggu, tabel sesi, target berikutnya dan alasannya.

### 7.5 Ganti HP
Instal APK di HP baru → impor berkas backup JSON, atau pulihkan lewat email pemulihan jika sudah dipasang → semua data kembali.

---

## 8. Kebutuhan fungsional

### A. Akun dan data

| ID | P | Kebutuhan | Kriteria penerimaan |
|---|---|---|---|
| FR-A1 | P0 | **Tidak ada layar login.** Aplikasi dibuka langsung ke Home dan langsung bisa dipakai mencatat latihan. Tidak ada email, password, atau akun yang diminta kapan pun, kecuali pengguna sendiri yang memilihnya (FR-A1b, FR-A1d). | Instal APK baru, buka, catat satu sesi lengkap. Tidak ada satu pun layar akun yang muncul sepanjang alur itu. |
| FR-A1b | P0 | Sinkronisasi ke Supabase bersifat **opsional dan opt-in**, satu tombol di Pengaturan bernama "Hubungkan dashboard web". Menekannya membuat identitas lewat Supabase **anonymous sign-in** di latar belakang, tanpa meminta apa pun dari pengguna. | Tap tombol itu, dalam ≤ 5 detik status berubah menjadi "Tersambung" tanpa ada isian yang harus diketik. |
| FR-A1c | P0 | Setelah tersambung, aplikasi menampilkan **kode pairing 6 digit** berlaku 10 menit. Dashboard web meminta kode itu sekali, lalu terikat ke identitas yang sama secara permanen. | Masukkan kode di dashboard, dashboard menampilkan data dari HP. Buka dashboard esok hari, tidak diminta kode lagi. |
| FR-A1d | P1 | Pengguna bisa memasang **email pemulihan** kapan saja di Pengaturan, yang menautkan identitas anonim tadi ke email itu. Tanpa ini, data hanya ada di HP dan di baris Supabase yang kuncinya ada di HP. Aplikasi menjelaskan risiko itu satu kali saat pertama menyalakan sinkronisasi. | Pasang email, hapus aplikasi, instal ulang, pulihkan lewat tautan email, data kembali. |
| FR-A2 | P0 | Seluruh data pengguna disimpan lokal dan dicerminkan ke Supabase (tabel `user_state`). | Selesaikan satu sesi, dalam ≤ 10 detik dengan jaringan aktif baris `user_state.state.workouts` berisi sesi itu. |
| FR-A3 | P0 | Aplikasi berfungsi penuh saat offline. Perubahan dikirim saat jaringan kembali. | Matikan data, catat sesi lengkap, nyalakan data, sesi muncul di Supabase tanpa tindakan pengguna. Indikator "belum tersinkron" tampil selama offline. |
| FR-A4 | P0 | Konflik dua perangkat diselesaikan dengan merge berbasis revisi (mekanisme openGym). Tidak ada data yang hilang diam-diam. | Dua perangkat offline masing-masing mencatat satu sesi berbeda, online bergantian, kedua sesi ada di hasil akhir. |
| FR-A5 | P0 | Pemulihan data setelah instal ulang atau ganti HP tersedia lewat dua jalur: impor berkas backup JSON (FR-A6), atau email pemulihan jika sudah dipasang (FR-A1d). | Kedua jalur diuji: jumlah workout sama dengan sebelum dihapus. |
| FR-A6 | P1 | Ekspor backup JSON lengkap lewat share sheet Android, dan impor dari file yang sama. | Ekspor, reset aplikasi, impor, data identik. |
| FR-A7 | P1 | "Putuskan sambungan" di Pengaturan menghentikan sinkronisasi dan kembali ke mode lokal saja. Data lokal **tidak** dihapus. Jika masih ada perubahan yang belum terkirim, aplikasi menyinkronkan dulu atau meminta konfirmasi eksplisit. | Putuskan sambungan, semua data latihan tetap utuh di HP, indikator sinkron hilang. |
| FR-A8 | P0 | Mode lokal saja adalah **default dan sepenuhnya didukung**. Tidak ada fitur latihan yang dikunci di balik sinkronisasi. Yang hilang tanpa sinkronisasi hanya dashboard web. | Jalankan seluruh alur FR-B sampai FR-F tanpa pernah menyalakan sinkronisasi; semuanya berfungsi. |
| FR-A9 | P0 | Satu HP, satu data. Tidak ada pemilih akun atau profil ganda di aplikasi. | Tidak ada layar atau menu untuk menambah atau berganti akun. |

### B. Program dan split

| ID | P | Kebutuhan | Kriteria penerimaan |
|---|---|---|---|
| FR-B1 | P0 | Pengguna memilih satu program aktif dari template: Push/Pull/Legs, Upper/Lower, Bro split, Heavy Duty, Full Body, 5×5, atau membuat custom dari rutinitas sendiri. | Semua template tersedia di layar pilih program dan menghasilkan rutinitas yang bisa diedit. |
| FR-B2 | P0 | Program punya mode **kalender** (rutinitas terikat hari dalam minggu) atau **rotasi** (urutan sesi, tidak terikat hari). Mode bisa diganti tanpa kehilangan rutinitas. | PPL dalam mode rotasi: setelah Push selesai, Home menampilkan Pull terlepas dari hari apa. |
| FR-B3 | P0 | Mode rotasi menyimpan posisi (cursor). Menyelesaikan sesi dari program menggeser cursor. Sesi freestyle tidak menggeser cursor. | Selesaikan Push, lalu freestyle, Home tetap menampilkan Pull. |
| FR-B4 | P0 | Pengguna bisa Skip sesi berikutnya (geser cursor tanpa mencatat) dan bisa memilih sesi lain dari program secara manual. | Skip Pull, Home menampilkan Legs. Pilih manual Push saat cursor di Legs, sesi tercatat sebagai Push dan cursor bergeser ke setelah Push. |
| FR-B5 | P0 | Program punya `minRestDays`. Jika belum terpenuhi, Home menampilkan tanggal jatuh tempo dan tetap mengizinkan Start. | Heavy Duty `minRestDays: 3`, sesi terakhir Senin, Selasa Home menampilkan "Pulih dulu, jatuh tempo Kamis" dan tombol Start tetap aktif. |
| FR-B6 | P0 | Template **Bro split**: 5 rutinitas Chest, Back, Shoulders, Legs, Arms; 4 sampai 5 gerakan per rutinitas; 3 sampai 4 set; rep range 8 sampai 12; policy double progression; mode kalender Senin sampai Jumat. | Memilih template menghasilkan 5 rutinitas dengan isi tersebut dan jadwal Senin sampai Jumat. |
| FR-B7 | P0 | Template **Heavy Duty**: 4 rutinitas dalam rotasi Chest+Back, Legs, Delts+Arms, Legs; setiap gerakan 1 sampai 2 warm-up plus 1 working set; rep range 6 sampai 10; policy `hit`; `minRestDays: 3`. | Memilih template menghasilkan konfigurasi tersebut; sesi pertama terbuka dengan 1 working set per gerakan. |
| FR-B8 | P0 | Rutinitas bisa diedit: tambah, hapus, urutkan gerakan; atur set, rep range, increment, rest per gerakan, policy per gerakan, intensifier (drop set, rest-pause), superset. Ini fitur openGym yang dipertahankan. | Semua aksi tersedia dari editor rutinitas dan perubahan tercermin di sesi berikutnya. |
| FR-B9 | P1 | Setelah sesi yang isinya menyimpang dari rutinitas (set ditambah, gerakan diganti), aplikasi menawarkan memperbarui rutinitas: "Update sets only", "Update all", "Keep routine", dengan opsi jadikan default. Referensi: `Update_Legs.jpg`. | Tambah 1 set di sesi, Finish, dialog muncul, pilih Update sets only, rutinitas kini punya set tambahan. |
| FR-B10 | P2 | Deload terencana: rutinitas bisa ditandai "excluded from progression" (fitur openGym). | Sesi dari rutinitas deload tidak mengubah target sesi reguler berikutnya. |

### C. Library gerakan dan alat

| ID | P | Kebutuhan | Kriteria penerimaan |
|---|---|---|---|
| FR-C1 | P0 | Library 1.324 gerakan openGym dengan pencarian, filter otot, filter alat, animasi demo dari CDN, dan favorit. | Cari "row", hasil muncul < 300 ms; buka satu gerakan, animasi tampil. |
| FR-C2 | P0 | Gerakan custom: nama dan bagian tubuh wajib, deskripsi opsional. Berperilaku sama dengan gerakan bawaan di semua layar. | Buat "Mesin Pec Deck Gym X", masukkan ke rutinitas, catat sesi, muncul di statistik. |
| FR-C3 | P0 | Profil alat (equipment profile) per gym: pengguna memilih alat yang tersedia; library dan picker bisa difilter berdasarkan profil aktif. Referensi: `Is_This_Your_Equipment.jpg`. | Buat profil "Gym A" tanpa kettlebell; picker dengan filter aktif tidak menampilkan gerakan kettlebell. |
| FR-C4 | P2 | Beban terakhir per gerakan disimpan per profil gym, sehingga mesin yang sama di gym berbeda punya memori beban terpisah. | Chest press 60 kg di Gym A, 50 kg di Gym B; ganti profil aktif, kolom PREV dan target mengikuti profil. |

### D. Logger sesi

| ID | P | Kebutuhan | Kriteria penerimaan |
|---|---|---|---|
| FR-D1 | P0 | Layar Workout menampilkan setiap gerakan sebagai kartu dengan tabel `SET | PREV | KG | REPS | ✓`. Kolom PREV berisi beban×rep set yang sama di sesi lalu. Referensi: `Tracker.jpg`, `Rest.jpg`. | Sesi kedua sebuah rutinitas, setiap baris PREV terisi; sesi pertama menampilkan "-". |
| FR-D2 | P0 | Baris set terbuka dengan beban dan rep **target** sudah terisi (hasil engine progresi). Pengguna cukup tap centang jika sesuai, atau ubah angka lalu centang. | Buka sesi, tanpa mengetik apa pun, tap centang set 1, set tersimpan dengan beban dan rep target. |
| FR-D3 | P0 | Baris yang tercentang berubah warna (hijau gelap) dan rest timer mulai otomatis dengan durasi rest gerakan itu (atau default global). Timer terlihat di header sticky. | Centang set, header menampilkan hitung mundur; selesai, ada bunyi atau getar dan opsi flash layar. |
| FR-D4 | P0 | Tap centang, ubah beban, ubah rep masing-masing satu aksi. Stepper +/− memakai increment gerakan. Angka bisa diketik langsung. | Dari 60 kg tap + sekali menjadi 62,5 kg (increment 2,5); ketik 61 diterima. |
| FR-D5 | P0 | Kolom RIR atau RPE opsional per set, dimatikan secara default, bisa diaktifkan di Pengaturan. Nilai berwarna sesuai kedekatan ke failure. | Aktifkan RPE, kolom muncul; nilai 9 dan 10 berwarna paling merah. |
| FR-D6 | P0 | Set warm-up ditandai dan tidak ikut dihitung untuk 1RM, progresi, dan fatigue. | Warm-up 40 kg × 10 tidak mengubah e1RM gerakan itu. |
| FR-D7 | P0 | Drop set, rest-pause, superset tersedia dari menu set atau menu gerakan (fitur openGym). | Tambah drop pada set 3, sub-baris muncul dengan beban 20% lebih ringan. |
| FR-D8 | P0 | Menu ⋯ per gerakan: Reorder, Notes, Add to superset, Replace exercise, Remove. Referensi: `Rest_3.jpg`. | Semua item ada dan berfungsi di tengah sesi tanpa mengakhiri sesi. |
| FR-D9 | P0 | Tambah gerakan di tengah sesi dari picker; hapus gerakan yang belum dilakukan. | Tambah "Face Pull" ke sesi Push berjalan, kartu baru muncul di bawah. |
| FR-D10 | P0 | Layar tetap menyala selama sesi berjalan (wake lock), bisa dimatikan di Pengaturan. | Sesi berjalan 5 menit tanpa sentuhan, layar tidak padam. |
| FR-D11 | P0 | Finish sesi menampilkan ringkasan: durasi, total volume, PR baru, otot yang dilatih (body map), dan target sesi berikutnya per gerakan. Tanpa XP, egg, streak. | Ringkasan tampil dengan semua elemen; tombol Selesai kembali ke Home. |
| FR-D12 | P0 | Sesi yang belum selesai tetap ada jika aplikasi ditutup paksa atau HP restart. | Tutup paksa di tengah set 5, buka lagi, sesi berlanjut dengan set 1 sampai 4 tercentang. |
| FR-D13 | P1 | Freestyle: mulai sesi kosong, tambah gerakan sambil jalan, setiap gerakan terisi dari sesi terakhirnya. | Mulai freestyle, tambah Bench Press, set terisi dari Bench Press terakhir apa pun rutinitasnya. |
| FR-D14 | P1 | Catat sesi lampau: pilih tanggal, jam mulai, durasi, rutinitas atau freestyle, lalu logger normal. Sesi lampau tidak mengklaim PR terhadap sesi yang lebih baru. | Catat sesi tertanggal minggu lalu dengan beban lebih berat dari PR hari ini; PR hari ini tidak berubah. |
| FR-D15 | P1 | Gerakan berbasis waktu (plank, hang) dicatat detik, dengan work timer. Kardio dicatat waktu dan kecepatan. | Plank 60 detik tercatat sebagai 60 s, bukan rep. |
| FR-D16 | P1 | Plate math untuk barbell: menampilkan beban per sisi berdasarkan bar weight gerakan. | Bench 80 kg bar 20 kg menampilkan "30 kg per sisi". |
| FR-D17 | P1 | Catatan per gerakan (persisten antar sesi) dan catatan per sesi. | Tulis "setel kursi posisi 4" di Chest Press; sesi berikutnya catatan itu tampil. |

### E. Progressive overload

| ID | P | Kebutuhan | Kriteria penerimaan |
|---|---|---|---|
| FR-E1 | P0 | Setiap gerakan dalam rutinitas punya policy progresi: `off`, `linear`, `greyskull`, `double`, `hit`, `time`. Default rutinitas bisa ditimpa per gerakan. | Ubah policy Bench Press ke double, gerakan lain di rutinitas tetap linear. |
| FR-E2 | P0 | Target sesi berikutnya dihitung dari riwayat, bukan dari counter tersimpan. Mengedit sesi lama mengubah target. | Edit rep set terakhir sesi lalu dari 8 ke 5, target hari ini turun atau tidak naik sesuai policy. |
| FR-E3 | P0 | Sesi yang gagal (rep kurang, set tidak dicentang, set kurang dari rencana) **tidak pernah** menaikkan beban. | Centang 2 dari 3 set dengan rep penuh, target berikutnya tidak naik. |
| FR-E4 | P0 | Stall berulang (jumlah tergantung policy) memicu deload dengan faktor yang bisa diatur (default 90%). Perubahan beban manual memulai hitungan stall baru. | Linear gagal 3 sesi berturut, target sesi ke-4 = 90% dibulatkan ke grid increment. |
| FR-E5 | P0 | Setiap target menampilkan alasan satu kalimat, dapat dibuka dari baris set atau menu gerakan. | Tap ikon info di target, muncul "Naik 2,5 kg: semua rep tercapai sesi lalu". |
| FR-E6 | P0 | Policy `hit` (Heavy Duty): membaca satu working set; rep ≥ batas atas → beban naik satu increment dan target rep ke batas bawah; rep di dalam range → beban tetap, target rep + 1; rep < batas bawah dua sesi berturut → deload dan saran tambah 1 hari istirahat (teks, bukan otomatis). | Unit test mencakup ketiga cabang plus kasus warm-up diabaikan dan kasus set tambahan diabaikan. |
| FR-E7 | P0 | Increment default 2,5 kg (tubuh atas) dan 5 kg (tubuh bawah), bisa ditimpa per gerakan. Beban selalu dibulatkan ke kelipatan increment. | Set increment Dumbbell Curl ke 1 kg, progresi menaikkan 1 kg. |
| FR-E8 | P0 | Gerakan bodyweight berprogresi di rep, lalu set (sampai batas), lalu menyarankan variasi lebih sulit atau beban tambahan. | Push-up capai rep target, target berikutnya +1 rep, bukan +2,5 kg. |
| FR-E9 | P0 | Estimasi 1RM (Epley) per gerakan dari set terbaik yang memenuhi syarat (≤ 12 rep, bukan warm-up), dengan riwayat kurva. | Bench 80 × 5 menghasilkan e1RM 93,3 kg dan set itu ditandai sebagai sumbernya. |
| FR-E10 | P1 | Deteksi PR saat sesi: beban tertinggi, e1RM tertinggi, volume tertinggi per gerakan, ditampilkan saat centang dan di ringkasan. | Set melebihi e1RM sebelumnya memunculkan penanda PR di baris itu. |

### F. Statistik di aplikasi

| ID | P | Kebutuhan | Kriteria penerimaan |
|---|---|---|---|
| FR-F1 | P0 | Riwayat semua sesi dengan detail per set, bisa diedit dan dihapus. | Buka sesi minggu lalu, ubah beban satu set, tersimpan dan tersinkron. |
| FR-F2 | P0 | Per gerakan: riwayat sesi dan grafik e1RM, dapat dibuka dari menu gerakan di tengah sesi tanpa keluar dari sesi. | Dari sesi berjalan, buka riwayat Squat, kembali, sesi tetap utuh. |
| FR-F3 | P0 | Heatmap otot depan-belakang dengan mode Balance (volume per otot dalam rentang waktu), Fatigue (pemulihan), Strength (e1RM per otot). Referensi: `Analysis.jpg`. | Ganti rentang 7 hari ke 30 hari, warna berubah; otot yang belum dilatih disebut. |
| FR-F4 | P1 | Grafik berat badan dengan garis target. | Masukkan target 75 kg, garis tampil, titik diwarnai sesuai arah ke target. |
| FR-F5 | P1 | Heatmap aktivitas tahunan gaya GitHub berdasarkan durasi latihan. | Hari dengan sesi berwarna, intensitas sesuai durasi. |
| FR-F6 | P1 | Radar 6 region: Back, Chest, Core, Arms, Shoulders, Legs untuk rentang saat ini vs rentang sebelumnya. Referensi: `Analysis.jpg`. | Dua poligon tampil dengan legenda. |

### G. Dashboard web

| ID | P | Kebutuhan | Kriteria penerimaan |
|---|---|---|---|
| FR-G1 | P0 | Terikat ke identitas HP lewat kode pairing (FR-A1c), bukan login; membaca `user_state` dan berlangganan Realtime sehingga sesi baru dari HP tampil tanpa refresh. | Selesaikan sesi di HP, dalam ≤ 10 detik dashboard yang terbuka menampilkan sesi itu. |
| FR-G2 | P0 | Halaman **Overview**: heatmap aktivitas, sesi minggu ini vs rencana program, berat badan 90 hari, 3 PR terbaru. | Semua elemen tampil dengan data nyata dari akun. |
| FR-G3 | P0 | Halaman **Progres**: pilih gerakan, grafik e1RM dan volume mingguan dengan rentang 4, 12, 26, 52 minggu, tabel sesi, kartu "Target berikutnya" berisi beban, rep, dan alasan yang **identik** dengan yang akan ditampilkan HP. | Angka target di dashboard sama persis dengan yang muncul saat sesi dibuka di HP. |
| FR-G4 | P0 | Halaman **Program**: split aktif, mode, urutan sesi dan posisi cursor, kepatuhan mingguan (sesi terencana vs terlaksana) 12 minggu, daftar gerakan stall (e1RM tidak naik ≥ 3 minggu). | Gerakan dengan e1RM datar 3 minggu muncul di daftar stall. |
| FR-G5 | P1 | Halaman **Otot**: body map Balance, Fatigue, Strength, komponen yang sama dengan aplikasi. | Warna identik dengan aplikasi untuk rentang yang sama. |
| FR-G6 | P1 | Halaman **Riwayat**: tabel semua set, filter tanggal, rutinitas, gerakan; ekspor CSV hasil filter. | Filter "Bench Press, 2026" lalu ekspor menghasilkan CSV dengan kolom tanggal, set, beban, rep, rir. |
| FR-G7 | P1 | Halaman **Pengaturan**: unduh backup JSON mentah, ganti password. | File JSON yang diunduh bisa diimpor ke aplikasi (FR-A6). |
| FR-G8 | P0 | Dashboard **baca-saja** pada rilis pertama. Tidak ada tombol yang mengubah data latihan. | Tidak ada request tulis ke `user_state` dari dashboard selain ganti password. |
| FR-G9 | P0 | Responsif: layak dipakai di laptop 1280 px dan tablet 768 px. Layout HP tidak diprioritaskan (ada aplikasinya). | Tidak ada scroll horizontal pada 1280 dan 768 px. |

### H. Pengaturan dan onboarding

| ID | P | Kebutuhan | Kriteria penerimaan |
|---|---|---|---|
| FR-H1 | P0 | Onboarding pertama: pilih program → pilih alat → Home. Maksimal 2 layar, dan keduanya bisa dilewati. Tanpa layar akun, tanpa pertanyaan usia, diet, tujuan, avatar. | Pengguna baru tiba di Home dalam ≤ 2 layar sejak aplikasi dibuka pertama kali. |
| FR-H2 | P0 | Pengaturan: satuan kg/lb (dengan konversi data), rest default, rest-pause default, RIR/RPE on/off, wake lock, ukuran animasi, awal minggu, tema gelap/terang, warna aksen. | Semua opsi tersimpan dan tersinkron. |
| FR-H3 | P1 | Pengingat rest timer sebagai notifikasi lokal saat aplikasi di latar belakang. | Kunci HP saat rest 90 detik, notifikasi muncul saat habis. |
| FR-H4 | P2 | Bahasa Indonesia untuk UI. | Semua string UI tersedia dalam ID. |


### I. Identitas dan ikon

Aplikasi ini adalah produk sendiri. Kode yang di-port dari openGym boleh tetap menyebut asalnya di komentar dan di `NOTICE.md` (kewajiban atribusi AGPL), tapi tidak boleh ada jejak openGym yang tampil ke pengguna.

| ID | P | Kebutuhan | Kriteria penerimaan |
|---|---|---|---|
| FR-I1 | P0 | Nama tampilan aplikasi `GymApps` (bukan `gymapps`), ikon launcher, dan splash screen memakai identitas sendiri. `applicationId` tetap `dev.hariz.gymapps`. | `android:label` di `AndroidManifest.xml` bernilai `GymApps`. `grep -rni "opengym" app/lib` hanya menemukan komentar, tidak ada string yang tampil di UI. |
| FR-I2 | P0 | Ikon launcher Android lengkap: semua kerapatan mipmap, ikon adaptif (foreground dan background terpisah), dan monochrome untuk tema dinamis Android 13+. Dihasilkan dari satu berkas sumber lewat `flutter_launcher_icons`, bukan ditambal per ukuran. | Pasang APK, ikon tajam di launcher, di menu Recents, dan di Pengaturan aplikasi. Tidak ada ikon buram atau kotak putih. |
| FR-I3 | P0 | Ikon **di dalam** aplikasi memakai satu set: Material Icons, dengan satu varian yang sama di seluruh aplikasi (misalnya semuanya `_rounded`). Dilarang mencampur emoji, gambar bitmap, atau pustaka ikon lain sebagai ikon fungsional. | `grep -rhoE "Icons\.[a-z_]+" app/lib` hanya menghasilkan satu varian. Tidak ada emoji sebagai ikon di layar mana pun. |
| FR-I4 | P0 | Warna ikon mengikuti tema (`IconTheme` atau `colorScheme`), tidak dipaku dengan `Color(0x...)`. Ukuran ikon mengikuti skala tetap: 16, 20, 24, 32. | Ganti tema terang/gelap, semua ikon ikut berubah dan tidak ada yang hilang kontras. |
| FR-I5 | P1 | Splash screen memakai warna latar yang sama dengan latar tema gelap, sehingga tidak ada kedipan putih saat aplikasi dibuka. | Buka aplikasi 5 kali, tidak ada kilatan putih di antara splash dan Home. |
| FR-I6 | P1 | Dashboard web memakai favicon dan nama yang sama dengan aplikasi. | Tab browser menampilkan ikon dan judul GymApps. |

---

## 9. Kebutuhan non-fungsional

| ID | Kebutuhan | Kriteria |
|---|---|---|
| NFR-1 | Waktu buka aplikasi sampai Home interaktif | ≤ 2 detik di HP kelas menengah dengan data 2 tahun |
| NFR-2 | Respons tap centang set | ≤ 100 ms sampai baris berubah hijau |
| NFR-3 | Ukuran APK | ≤ 25 MB (animasi dari CDN, bukan bundel) |
| NFR-4 | Offline | Semua FR-B, FR-C, FR-D, FR-E, FR-F berfungsi tanpa jaringan |
| NFR-5 | Sinkron | Perubahan terkirim ≤ 10 detik setelah jaringan tersedia |
| NFR-6 | Keamanan | RLS aktif: setiap pengguna hanya bisa baca-tulis barisnya sendiri. Anon key boleh ada di klien, service key tidak pernah. Token disimpan di secure storage Android. |
| NFR-7 | Integritas | Tidak ada jalur kode yang menghapus workout tanpa konfirmasi eksplisit dua langkah |
| NFR-8 | Pengujian | Setiap fungsi yang menentukan beban berikutnya atau membaca sesi (progression, program, onerm, finish-workout) punya unit test. Test suite openGym yang ada tetap hijau kecuali untuk fitur yang sengaja dihapus. |
| NFR-9 | Kompatibilitas | Android 10 ke atas |
| NFR-10 | Backup | Ekspor JSON manual tersedia setiap saat; format kompatibel dengan impor openGym |
| NFR-11 | Aksesibilitas dasar | Area tap ≥ 44 px, kontras teks ≥ 4,5:1 pada tema gelap |

---

## 10. Layar dan navigasi

Bottom navigation 5 tab (gaya Liftoff): **Workout · Home · Stats · History · Profile**. Home adalah tab default.

| Layar | Isi | Referensi skrinsut |
|---|---|---|
| Onboarding: pilih program | Kartu template, deskripsi singkat, jumlah hari | `02_.../Getting_Started.jpg`, `Beginner.jpg` |
| Onboarding: pilih alat | Daftar alat berkelompok dengan gambar dan centang | `03_.../Is_This_Your_Equipment.jpg` |
| Home | Header berat badan dan sesi minggu ini; kartu besar "Sesi berikutnya" dengan Start, Skip, Freestyle; strip 7 hari | `01_.../Home_Screen.jpg` (grid kartu) |
| Workout (tab) | Segmen Tracker / My Plan. Tracker: kartu Exercise Library, Start Empty Workout, daftar rutinitas program. My Plan: editor program dan jadwal | `03_.../Tracker.jpg` |
| Workout (sesi) | Header sticky timer, kartu gerakan, tabel set, ADD SET, menu ⋯ | `03_.../Rest.jpg`, `Rest_3.jpg` |
| Finish | Ringkasan sesi, body map, PR, target berikutnya, dialog update rutinitas | `02_.../Update_Legs.jpg` |
| Stats | Heatmap otot, radar region, rentang waktu, e1RM per gerakan, berat badan | `04_.../Analysis.jpg` (tema terang) |
| History | Kalender atau daftar sesi, detail sesi, edit, catat sesi lampau | `03_.../2026-03-16.jpg` (tanpa foto dan komentar) |
| Library | Pencarian, filter, favorit, detail gerakan dengan animasi | `03_.../Weighted_Support.jpg` |
| Routine editor | Daftar gerakan, konfigurasi set, rep, policy, intensifier | `02_.../Create_Now_Routine.jpg` |
| Profile | Pengaturan, profil alat, backup, logout | `07_.../Settings.jpg` |

Elemen Liftoff yang **tidak** ditiru: maskot gajah, bar XP, api streak, egg, rank badge, quest, tab Nutrition, tab Friends, feed, reaksi, komentar, foto sesi.

---

## 11. Model data (ringkas)

Satu dokumen JSON per pengguna (skema openGym `S`), kunci utama:

- `routines[]`, `week{}`, `dayPlan{}`: rutinitas dan jadwal kalender (ada).
- `program{}`: **baru**, lihat spec §5. `id`, `mode`, `order[]`, `cursor`, `minRestDays`, `startedAt`.
- `workouts[]`: riwayat sesi, setiap sesi berisi `entries[]` → `sets[]` dengan `w`, `r`, `done`, `phase`, `type`, `rir`.
- `active`: sesi yang sedang berjalan.
- `exWeights{}`: beban terakhir per gerakan (fase 2: per profil gym).
- `bodyweight[]`, `customEx[]`, `equipProfiles[]`, `favEx[]`, `exNotes{}`, setelan.

Disimpan di `user_state.state` (jsonb) dengan `rev` untuk deteksi konflik. Detail SQL di spec §4.

---

## 12. Prioritas rilis

**Rilis 1 (P0):** semua FR-A1 sampai A5, B1 sampai B8, C1 sampai C3, D1 sampai D12, E1 sampai E9, F1 sampai F3, G1 sampai G4 dan G8 sampai G9, H1 sampai H2, semua NFR.

**Rilis 2 (P1):** A6, A7, B9, D13 sampai D17, E10, F4 sampai F6, G5 sampai G7, H3.

**Rilis 3 (P2):** B10, C4, H4, Google sign-in, edit dari dashboard, tabel `workout_sets` untuk SQL.

Milestone teknis M0 sampai M5 dan urutannya ada di spec §10.

---

## 13. Asumsi

- Satu pengguna. Tidak ada kebutuhan privasi antar pengguna selain RLS standar.
- Koneksi internet tersedia di rumah; di gym bisa tidak ada.
- Animasi gerakan diambil dari CDN jsDelivr (dataset yang sudah dipakai openGym). Jika CDN tidak tersedia, aplikasi tetap berfungsi tanpa animasi.
- Supabase free tier cukup: satu baris jsonb beberapa MB, Realtime satu channel.
- Lisensi AGPL openGym (https://github.com/DuarteSantos8/openGym) tidak menimbulkan kewajiban untuk pemakaian pribadi. Jika suatu hari dipublikasikan sebagai layanan, kode sumber harus dibuka dengan lisensi yang sama.
- Dataset animasi gerakan: https://github.com/hasaneyldrm/exercises-dataset lewat jsDelivr, commit yang sudah dipin di skrip `build:mobile` openGym.

---

## 14. Pertanyaan terbuka

Tidak ada yang menghambat mulai. Yang bisa diputuskan saat eksekusi dengan default yang sudah ditetapkan:

1. Isi gerakan persis untuk template Bro split dan Heavy Duty (default: pilihan compound dan isolasi standar dari library openGym, bisa diedit pengguna).
2. Warna aksen final (default biru langit `#5ac8fa` seperti Liftoff).
3. Apakah bahasa selain EN dibuang dari bundle di M0 atau dibiarkan (default: dibiarkan, tidak memengaruhi fungsi).

---

## 15. Glosarium

- **Split**: pembagian sesi latihan berdasarkan kelompok otot atau pola gerak. PPL = Push/Pull/Legs. Bro split = satu kelompok otot per hari. Upper/Lower = tubuh atas dan bawah bergantian.
- **Heavy Duty (HIT)**: metode Mike Mentzer, satu working set ke failure per gerakan, volume rendah, istirahat panjang antar sesi.
- **Progressive overload**: menaikkan beban, rep, atau set secara bertahap agar otot terus beradaptasi.
- **Policy progresi**: aturan yang menentukan target sesi berikutnya dari hasil sesi lalu.
- **Linear**: semua rep tercapai → beban naik satu increment.
- **Double progression**: naikkan rep dalam range dulu, capai batas atas di semua set → beban naik, rep kembali ke batas bawah.
- **Greyskull LP**: set terakhir AMRAP; lewati target → naik; dua kali lipat → naik ganda; gagal → reset 10%.
- **Deload**: penurunan beban terencana setelah stall.
- **Stall**: gagal mencapai target beberapa sesi berturut.
- **e1RM**: estimasi beban maksimum satu repetisi, rumus Epley: `w × (1 + r/30)`.
- **RIR / RPE**: Reps In Reserve (sisa rep yang masih bisa dilakukan) / Rate of Perceived Exertion (skala 1 sampai 10).
- **Warm-up set**: set pemanasan, tidak dihitung untuk progresi dan 1RM.
- **Drop set**: set utama diikuti set beban lebih ringan tanpa istirahat.
- **Rest-pause**: satu set dipecah menjadi beberapa burst dengan istirahat 10 sampai 20 detik.
- **Superset**: dua gerakan dilakukan berturut dengan satu istirahat di akhir.
- **PR**: personal record.
- **Cursor**: posisi sesi berikutnya dalam urutan rotasi program.
