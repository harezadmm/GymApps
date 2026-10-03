# UI v3 — "Bevel glass": referensi Bevel, fitur tetap

Sumber desain: dokumen Pen `pencil-new.pen` (20 layar: 01–08 terang di y=140,
gelap di y=1560; aset di `gym/`). Referensi gaya: aplikasi **Bevel** (Mobbin).
Tidak ada fitur yang berubah — yang berubah hanya tampilannya dan susunan
navigasinya. Dokumen ini adalah kontrak antara mockup Pen dan kode; angka di
sini yang dipakai kode, bukan tebakan dari gambar.

Prinsip yang dipilih bersama pemilik produk (4 Okt 2026):

1. **Liquid glass** untuk tombol utama, chip terpilih, tab bar, dan pil
   istirahat — bukan tombol hitam/violet pekat.
2. **Ikon garis**, bukan ikon 3D. Ilustrasi tokoh 3D hanya tersisa di layar
   masuk/daftar, pilih program, dan keadaan kosong (bukan ikon).
3. Mode gelap lengkap, satu set token dua tema.
4. Grafik dirapikan: sparkline halus berisi gradien, batang membulat dengan
   garis rata-rata dan gelembung nilai.
5. Semua fitur Statistik tetap: peta panas otot, radar region, kelelahan,
   kekuatan, berat badan, dashboard.

---

## 1. Token warna (`GymColors`, `app/lib/core/theme.dart`)

Nama field lama dipertahankan supaya pemanggil tidak perlu diubah massal;
nilainya dari variabel Pen. `border` = `$hairline`, `bgNested` = `$nested`,
`doneInk` = `$done`, `warn` = `$warnInk`, `chartIdle` = `$barIdle`.

| Token | Terang | Gelap | Catatan |
| --- | --- | --- | --- |
| bg | `#F2F2F6` | `#0D0D10` | Beranda menambah dua *wash* radial: `washA` `#FFE3D1AA`/`#3A214A66` (kiri atas), `washB` `#E7E2FFAA`/`#1E2A4A66` (kanan atas); Ringkasan hanya `washB` |
| bgNested | `#F4F4F7` | `#141417` | area peta otot, tabel set |
| surface | `#FFFFFF` | `#1C1C20` | kartu |
| surface2 | `#F4F4F7` | `#26262B` | pil KG/REPS, lintasan tab segmented, tile ikon netral |
| border (hairline) | `#E7E7EC` | `#2F2F35` | pemisah baris, garis grid grafik, stroke chip tak terpilih |
| text | `#111114` | `#F4F4F6` | |
| text2 | `#6D6D76` | `#A1A1AA` | ≥ 4,5:1 di atas surface (terang 5,1:1) |
| text3 | `#A7A7B0` | `#6B6B74` | dekoratif saja (cincin "belum", chevron) |
| accent | `#5B4BD6` | `#8F7FFF` | teks/ikon aksen. Pen memakai `#6A5AE6` di terang; digelapkan ke `#5B4BD6` agar ≥ 4,5:1 di atas `bg` (5,4:1) |
| accentFill | `#5546D6` | `#6C5CEB` | = `glassTintB` tanpa alpha; satu-satunya latar pekat untuk teks putih (6,4:1 / 4,8:1) |
| accentInk | `#FFFFFF` | `#FFFFFF` | |
| accentSoft | `#EEEBFD` | `#2A2546` | tag HARI INI, avatar, banner preskripsi, hari ini di strip minggu |
| doneBg | `#E8F7EE` | `#15291C` | baris set selesai, pil "+1 rep" |
| doneInk (done) | `#15804A` | `#4ADE80` | Pen `#1F9D55` hanya 3,1:1 di atas doneBg; `#15804A` 4,8:1 |
| warnSoft | `#FFF1E3` | `#3A2A17` | banner "paling sedikit volume", catatan kelelahan |
| warn (warnInk) | `#A8560A` | `#FFAD5C` | 4,75:1 di atas warnSoft |
| warm | `#FF8A3D` | `#FF8A3D` | lencana warm-up (latar `warm` @ 0,13), ikon trofi rekor |
| danger | `#D93A40` | `#FF6B6B` | |
| ringTrack | `#EFEFF3` | `#2A2A30` | lintasan cincin Beranda |
| ringA / ringB / ringC | `#FFB020` / `#2FCB7E` / `#7C6CFF` | sama | busur cincin: sesi / set / volume |
| segThumb | `#FFFFFF` | `#3B3B44` | thumb tab segmented dan tombol stepper |
| sparkTop / sparkBottom | accent @ 0,28 / @ 0 | accent @ 0,33 / @ 0 | isian sparkline, isian radar |
| chartIdle (barIdle) | accent @ 0,16 | accent @ 0,20 | batang yang bukan sorotan |
| silhouette | `#E1E1E8` | `#2B2B32` | |
| heatRamp[0..4] | `#D6D1F5 #BBB1F2 #9A8DEE #7C6CE9 #5B4BD9` | `#2F2A4A #4A4386 #6A61BA #8A80E8 #A99BFF` | diturunkan: `heat0 = alphaBlend(accent@0,25 terang / @0,18 gelap, surface)`, lalu lerp ke accent |
| activityRamp | `[surface2, heat1, heat2, heat3, accent]` | sama | kalender aktivitas |
| cardShadow | `#14142B0F` offset (0,4) blur 18 | sama | semua `GymCard` |

### Hue pembeda (`GymHues`)

Tiap hue punya **ink** (ikon/teks) dan **soft** (latar tile). Violet mengikuti
aksen pilihan pengguna.

| Hue | ink terang | soft terang | ink gelap | soft gelap |
| --- | --- | --- | --- | --- |
| violet | accent | accentSoft | accent | accentSoft |
| pink | `#C42F7D` | `#FFE6F2` | `#FF7FC0` | `#3A1F2E` |
| cyan | `#0F7F9A` | `#E1F6FB` | `#5ED3EE` | `#14303A` |
| orange | `#B85C08` | `#FFF0E1` | `#FFAD5C` | `#3A2A17` |
| lime | `#4D7C0F` | tint | `#D9FF5C` | tint |
| green | `#15803D` | tint | `#34D399` | tint |

`c.tint(hue)` tetap ada untuk hue tanpa soft eksplisit: `alphaBlend(hue @ 0,12
terang / 0,22 gelap, surface)`. `c.block()` dihapus — tidak ada lagi blok
berwarna penuh.

### Glass (`GlassTokens`, diturunkan dari aksen)

| Token | Terang (aksen bawaan) | Gelap | Turunan untuk aksen lain |
| --- | --- | --- | --- |
| tintA | `#7A6AF2F2` | `#A396FFE6` | `lighten(accentFill, +0,08)` @ 0,95 / `accent` @ 0,90 |
| tintB | `#5546D6EB` | `#6C5CEBD9` | `accentFill` @ 0,92 / @ 0,85 |
| glow | `#5546D64D` | `#6C5CEB59` | `accentFill` @ 0,30 / 0,35 |
| clear | `#ECECF3CC` | `#FFFFFF1A` | tetap |
| bar | `#FFFFFFBF` | `#1E1E24BF` | tetap |
| edgeTop / edgeLow | `#FFFFFFE6` / `#FFFFFF33` | `#FFFFFF59` / `#FFFFFF0D` | tetap |
| sheen | `#FFFFFF5C → #FFFFFF00` (atas → 50 %) | sama | tetap |

Resep satu permukaan glass (urutan gambar):

1. **Blur latar** (`BackdropFilter`, sigma 12) — **hanya** untuk tab bar, pil
   istirahat, dan header sesi: ketiganya mengapung di atas isi yang bergulir.
   Tombol, chip, dan titik hari duduk di atas latar polos: blur di sana mahal
   (satu `saveLayer` per widget) dan tidak terlihat. `GlassSurface.blur`
   bawaannya `false`.
2. Isian: `tinted` = gradien linear atas→bawah `tintA → tintB`; `clear` =
   `clear`; `bar` = `bar`.
3. Sheen: gradien `sheen` di separuh atas.
4. Tepi 1 px di dalam: gradien vertikal `edgeTop → edgeLow (55 %) → edgeTop`.
5. Sorot dalam: garis 1 px putih @ 0,55 (tinted) / 0,70 (clear) di tepi atas.
6. Bayangan luar: tinted `glow` offset (0,6) blur 16; clear `#14142B14` (0,6)
   blur 16; bar `#14142B24` (0,10) blur 30.

Teks di atas tinted selalu putih (`#FFFFFF`); di atas clear/bar `text`.

---

## 2. Tipografi

Satu keluarga: **Inter** (sudah di-bundle). Manrope dihapus dari pubspec —
mockup tidak memakainya dan satu keluarga lebih tenang.

| Gaya | Ukuran/berat | Pakai |
| --- | --- | --- |
| headlineMedium | 28 / 800, spasi −0,6 | judul layar tab (Statistik, Riwayat, Program) |
| displaySmall | 30 / 800 | waktu sesi berjalan, Durasi/Volume di Ringkasan |
| headlineSmall | 22 / 800 | nama rutinitas di kartu sesi berikutnya, nama program |
| titleLarge | 17 / 700 | judul seksi ("Sesi berikutnya", "Minggu ini") |
| titleMedium | 15 / 700 | judul kartu ("Perkiraan 1RM"), nama baris utama |
| bodyLarge | 14 / 500 | nama gerakan di baris |
| bodyMedium | 13 / 400, text2 | meta |
| labelSmall | 11 / 700, text2, spasi 0,6, KAPITAL | label grup ("RUTINITAS PROGRAM", "LATIHAN") |
| tautan seksi | 13 / 600, accent | "Pilih lain", "Semua", "Urutkan" |
| angka tabular | `FontFeature.tabularFigures()` | semua angka yang berubah |

Label tombol **kalimat biasa** (Mulai sesi, Selesai, Simpan), 15/700 untuk
tinggi ≥ 48, 13,5/600 untuk tombol kecil. Tidak ada lagi label KAPITAL dengan
spasi huruf — itu bagian dari rasa "AI slop" yang dibuang. Snackbar action
(`UNDO`/`URUNGKAN`) tetap kapital mengikuti konvensi Material.

---

## 3. Radius dan ukuran

| Unsur | Nilai |
| --- | --- |
| kartu | 22 (`GymRadius.card`), padding 16, bayangan cardShadow |
| kartu kecil / baris sesi / KPI | 18 (`GymRadius.tile`) |
| tile ikon 44 | 14; tile 36 → 12; tile 30 → 10 |
| pil KG/REPS, lencana warm-up | 12 |
| tombol tinggi 52 | pil (26); tinggi 42 → 21; tinggi 34–40 → lingkaran/pil |
| chip tinggi 32 | 16 |
| tab segmented | lintasan 16, thumb 12, tinggi 44, padding 4 |
| tab bar | tinggi 66, radius 33, tombol tengah 50 |
| sheet | 28 atas |
| sel kalender | 2,5 |
| batang grafik | 6 atas / 3 bawah |
| tepi layar | 20 (layar tab) · 16 (sesi) |
| target sentuh | ≥ 44 dp (tombol 34–40 dp dibungkus padding) |

---

## 4. Ikon

Mockup memakai Lucide (satu-satunya yang ada di Pen). Aplikasi tetap memakai
font `GymIcons` (IconScout Basic UI + alat gym — garis membulat 2 px, sama
rupa dengan Lucide) supaya tidak ada font kedua dan tetap offline. Pemetaan:

| Lucide di Pen | GymIcons |
| --- | --- |
| house | home |
| history | clock |
| dumbbell | dumbbell |
| chart-column | chart |
| plus / minus / check / info / flag / link / bell / moon / calendar / scale / download / trophy / search / play | sama |
| chevron-down / chevron-right | chevronDown / chevronRight |
| chevron-left | arrowLeft |
| ellipsis | moreVertical |
| repeat | swap |
| cloud-check | cloudCheck |
| trending-up / trending-down | arrowUpRight / arrowDownRight |
| alarm-clock / timer | alarm |
| notebook-pen | note |
| flame | fire |
| skip-forward | skip |
| list | menu |
| cog | machine |
| layers | menu |
| calendar-check / calendar-plus | calendar |
| weight | scale |
| book-open | dumbbell (tombol library gerakan) |
| gauge | menu (Catat RIR) |
| sun | eye (layar tetap menyala) |
| palette | settings |
| languages | globe |
| refresh-cw | sync |
| upload | dataTransfer |
| log-out | logout |
| party-popper | Lottie `sessionDone` di dalam lingkaran accentSoft |
| biceps-flexed / footprints (ikon rutinitas) | dumbbell; pembedanya hue tile per rutinitas (violet, pink, cyan, orange bergilir menurut urutan program) |

Ikon 3D (`Gym3dIcon`, `assets/3d/`) **dihapus** beserta testnya. Ilustrasi
`GymArt` tetap untuk layar masuk, daftar, pilih program, riwayat kosong, dan
statistik kosong; **tidak** lagi di kartu hero Beranda.

---

## 5. Navigasi

Lima tab lama (Workout · Home · Stats · History · Profile) menjadi:

```
Beranda(0) · Riwayat(1) · [ + ] · Program(2) · Statistik(3)
```

- Tab bar: `GlassSurface(bar, blur)` 358×66, mengapung 16 dp dari tepi dan 14
  dp dari bawah (di dalam SafeArea). Tiap tab: ikon 22 + label 10,5 (aktif
  accent 600, lainnya text2 500). Label **tampil**, bukan hanya semantics.
- Tombol tengah **+** (50 dp, tinted glass, glow): membuka **lembar Mulai
  sesi** (§7.2).
- **Profil** bukan tab lagi: dibuka dari avatar di Beranda sebagai halaman
  dorong dengan tombol kembali. Konstruktor `HomeShell` tidak berubah.
- `onOpenTab` dari Beranda: Riwayat = 1, Statistik = 3.
- Tab **Program** menggantikan tab Workout (Tracker/My Plan): isinya program
  aktif, rutinitas, dan aturan program (§7.7). Mulai sesi bebas/rutinitas
  pindah ke tombol +.

---

## 6. Komponen bersama (`widgets.dart`, `glass.dart`)

| Komponen | Spesifikasi |
| --- | --- |
| `GlassSurface` | lihat §1 resep; param `tone` (tinted/clear/bar), `radius`, `blur`, `padding`, `shadow` |
| `GymButton` | API lama (label, icon, tone, height, expand, shape). primary → tinted; neutral → clear; danger → isian `danger @ 0,12`, teks danger, tepi `danger @ 0,35`. Mati: opacity 0,45. Label kalimat biasa, 15/700 (≥ 48) atau 13,5/600 |
| `GlassIconButton` | lingkaran 38 (header) atau 40 (sesi), clear atau tinted; area sentuh 44 |
| `GymCard` | surface, radius 22, padding 16, bayangan cardShadow; `color`/`radius`/`padding` tetap bisa diubah |
| `HueTile(icon, hue, size, radius)` | soft bg + ikon ink; 44/14, 36/12, 30/10 |
| `TagPill(text)` | accentSoft r10 pad 5/9, 10/700 accent, KAPITAL — "HARI INI", "BESOK" |
| `Pill` | r8 pad 3/7, 10,5/700; warna lewat param (doneBg/done untuk "+1 rep", surface2/text2 untuk "tahan", warnSoft/warn untuk deload) |
| `SectionTitle(title, action)` | 17/700 + tautan 13/600 accent |
| `SectionLabel` | 11/700 text2 KAPITAL |
| `SegmentedTabs` | §3; thumb bergeser beranimasi (tetap) |
| `FilterChips` | terpilih tinted glass; lainnya surface + stroke hairline; tinggi 32; 13/600 |
| `SettingsTile` | ikon 18 text2 (tanpa cakram), label 14,5/500, nilai 13,5 text2, chevron 16 text3; padding 13/16; `tone` danger untuk Keluar |
| `SettingsGroup` | surface r20, pemisah hairline indent 46 |
| `NoteBanner(text, icon, tone)` | tone warn → warnSoft/warn; accent → accentSoft/accent; text2 → surface2/text2; r14 pad 10/12, 12,5/600 |
| `ScreenHeader` | judul 28/800; aksi di kanan |
| `AvatarCircle` | accentSoft, inisial accent 700 |
| `Odometer(value, unit)` | digit 18×26 surface2 r6, 14/700 tabular; satuan 12/600 text2 |
| `RingGauge(fraction, color, label, value)` | cincin 86, lintasan ringTrack 8 px, busur 8 px ujung bulat; nilai 19/700 (17 kalau > 4 karakter); label 12/500 text2; busur tumbuh saat tampil (`AnimatedValue`) |
| `RestPill` | §7.3 |
| Dialog/sheet | sheet `bg` r28 dengan handle 40×5 hairline; dialog surface r22; tombol di dalamnya `GymButton` |

Grafik (`charts.dart`):

- **Sparkline**: kurva Catmull-Rom (tegangan 1/6), stroke accent 2,2 ujung
  bulat, isian gradien `sparkTop → sparkBottom`, titik akhir 8 dp accent
  dengan stroke surface 2, halo 14 dp `sparkTop`; animasi "pena menggambar"
  tetap. Ukuran bawaan 94×36.
- **BarSeries**: batang r 6/6/3/3, celah 7 (≤ 12 batang) atau proporsional;
  idle `chartIdle`, sorotan gradien `tintA → tintB`; tiga garis grid hairline
  (0, 50, 100 %); gelembung nilai di batang sorotan (accent r8, 10,5/800
  putih) **selalu tampil** untuk batang terakhir, pindah ke batang yang
  diketuk; opsional `average` → garis `text3` 1 px + pil "rata-rata N set"
  (surface2 r8, 10,5/600 text2) di kiri; label sumbu 10,5: kiri/tengah text2
  500, kanan accent 700. Tinggi bawaan 104 + 22 ruang gelembung.
- **RadarChart**: cincin & jari-jari hairline; periode sebelumnya stroke
  text3 1,5 + isian text3 @ 0,10; sekarang isian sparkTop + stroke accent 2 +
  titik sudut 8 dp accent stroke surface 2; label sumbu 12,5/600 text2;
  animasi melayang tetap.
- **ActivityHeatmap**: sel 10 r 2,5 celah 3; ramp `activityRamp`.
- **MuscleMap**: painter tetap; warna dari `heatRamp` dan `silhouette`;
  **data**: bentuk otot bokong kanan tampak belakang ditambahkan sebagai
  cermin bentuk ke-98 (sumbu x = 222,2 dari 320) dengan grup `glutes` —
  sebelumnya hanya sisi kiri yang ada.

---

## 7. Layar

Semua ukuran dalam dp dari artboard 390 lebar. Tepi 20 kecuali disebut.

### 7.1 Beranda (`01`)

Latar `bg` + washA/washB. Isi `ListView` (tarik = sinkron, tetap), gap 20.

1. **Header**: tanggal "Minggu, 4 Oktober" 21/700; kanan avatar 36 → dorong
   Profil.
2. **Pil status** (baris, gap 10): *Program pill* (surface, stroke hairline,
   r24, tinggi 48; ikon 34 lingkaran `accentFill` + `swap` putih; judul nama
   program 13/600, sub "Rotasi · 3 rutinitas" / "Hari tetap · Sen, Rab, Jum"
   11 text2; chevron) → tab Program. *Sync pill* (ikon lingkaran `done` +
   cloudCheck putih; "Tersinkron" / "Belum sinkron" (warn, cloudOff) / "Tanpa
   server" (text3, cloudOff); sub "2 menit lalu" dari `lastSyncedAt`) → ketuk
   = `syncNow`. Tanpa program: Program pill berbunyi "Pilih program" dan
   membuka onboarding program.
3. **Kartu cincin** (surface r22, padding 18/14/16/14): tiga `RingGauge`
   melebar sama — *Sesi minggu ini* `done/planned` (ringA), *Set kerja*
   `set minggu ini / set rencana rutinitas minggu ini` (ringB), *Volume vs
   lalu* `+12 %` = volume 7 hari dibanding 7 hari sebelumnya (ringC; busur =
   min(1, sekarang/lalu); "—" kalau periode lalu nol). Pemisah hairline.
   **Insight**: ikon arrowUpRight accent + judul 14/700 + badan 13 text2,
   dari `homeInsight()` (§8): nama sesi berikutnya, berapa gerakan yang
   targetnya naik, kapan terakhir dilatih.
4. **Sesi berikutnya**: `SectionTitle("Sesi berikutnya", "Pilih lain")` →
   sheet pilih rutinitas (ada). Kartu: HueTile 52/16 violet dumbbell; nama
   22/800; meta "4 gerakan · 12 set · 5 hari lalu" 12,5 text2; `TagPill`
   HARI INI / BESOK / hari. Bila `next.early`: `NoteBanner` warn (teks
   pemulihan/hari latihan, ada). Daftar gerakan (maks 4, sisanya "+n lagi"):
   nama 14/500 · pil perubahan (`+1 rep` / `+2,5 kg` doneBg; `deload` warn)
   bila preskripsi naik/turun · target 14/700 "32 kg × 8"; pemisah hairline.
   Tombol: **Mulai sesi** (tinted, play, lebar 220 flex 5) + **Lewati**
   (clear, flex 2), tinggi 52. Tanpa program → kartu "Belum ada program" +
   tombol Pilih program (tinted) & Sesi bebas (clear). Draft tertunda →
   kartu lanjutkan di atas kartu ini (surface, ikon play warn, dua tombol
   clear/tinted) — ada.
5. **Minggu ini**: `SectionTitle("Minggu ini", "2 dari 3 sesi")`. Kartu
   (padding 14/12): 7 kolom — huruf hari 11/600 text2; titik 36: selesai =
   tinted glass + check putih; hari ini = accentSoft + stroke accent 1,5 +
   angka accent; lainnya surface2 + angka 13/600; titik 4 dp accent di bawah
   untuk hari latihan terjadwal (mode hari tetap). Ketuk → sheet hari (ada).
6. **Progres kekuatan**: `SectionTitle("Progres kekuatan", "Semua")` →
   Statistik. Kartu (padding 6/16): tiga gerakan teratas
   `strengthByMovement` — nama 14/600, meta "Mesin · e1RM 71 kg" (peralatan
   katalog diterjemahkan + e1RM), `Sparkline` 94×36 dari `carried(weeklyBest)`,
   pil delta doneBg ("+9 kg"; turun → warnSoft "−2 kg"; 0 → surface2 "tetap").
   Ketuk baris → sheet riwayat gerakan (ada). Kosong → satu baris text2
   "Belum ada data kekuatan".

### 7.2 Lembar Mulai sesi (`02`)

`showModalBottomSheet`, latar `bg`, r28, handle. Judul "Mulai sesi" 17/700
tengah; sub "Push adalah sesi berikutnya di rotasi" / "Push dijadwalkan hari
ini" / "Belum ada program" 12,5 text2.

- **Sesi bebas**: baris 72 surface, stroke text3 1,2 r18; tile surface2 44
  plus; "Sesi bebas" 15/600 + "Tambah gerakan sambil jalan". →
  `openFreestyleSession`.
- Label `RUTINITAS PROGRAM`; baris rutinitas 72 (surface r18, bayangan;
  berikutnya + stroke accent 1,5): HueTile 44/14 hue ke-i; nama 15/700 +
  `Pill` "Berikutnya"; meta "4 gerakan · 12 set"; tombol ⋯ 32 surface2 →
  lembar aksi (Edit gerakan · Ganti nama · Duplikat · Jadikan berikutnya ·
  Hapus). Ketuk baris → `openRoutineSession`. Rutinitas di luar program di
  bawah label `RUTINITAS LAIN`.
- **Catat sesi yang sudah lewat**: baris 60 surface r18; tile 36 accentSoft
  calendar; chevron → `openManualEntry`.

### 7.3 Sesi (`03`)

- **Header** (padding 2/20/10/20, tinggi 64): `GlassIconButton` 40 clear
  chevronDown (= minimise/keluar, konfirmasi tetap); kolom judul: nama
  rutinitas 13/600 text2, waktu berjalan 30/800 tabular; **Selesai** tinted
  40 tinggi pad 0/18 14/700. Bilah progres 3 dp di bawah header tetap.
- Catatan sesi: pil surface r16 tinggi 42, ikon note 18 text2, hint
  "Catatan sesi…".
- **Kartu gerakan aktif** (surface r22, padding 14/14/12/14): kepala —
  tile peralatan 44/14 surface2 + ikon alat 20; nama 16/700 + ikon info 14
  text3 (→ riwayat gerakan); target "Target 32 kg × 8 · double progression"
  12 text2; ⋯ 32 surface2 (menu aksi ada). **Preskripsi** `NoteBanner`
  accent (flag). **Baris istirahat**: alarm 16 text2 · "Istirahat" 13 text2
  · nilai 13/700 accent (ketuk → sheet durasi) · tombol play kecil (mulai
  istirahat) · Switch. **Tabel set**: header 10,5/700 text2 SET · PREV · KG ·
  REPS · ✓ (kolom 34 · 74 · 84 · 64 · 34); baris 52 r12 (selesai = doneBg):
  nomor 14/700 (warm-up = lencana 26 `warm @ 0,13` + fire warm; drop "D",
  rest-pause "RP" accent); prev 12,5 text2; **KG pill** 84×40 surface2 r12:
  minus 14 · TextField 15/700 · plus 14 (baris selesai: tanpa latar, teks
  saja); **Reps pill** 64×40; baris aktif (set belum selesai pertama) pil
  bergaris `text` 1,5; centang: cincin 26 stroke text3 1,8 → lingkaran
  `done` 28 + check putih. Chip RIR di bawah baris (ada). "Tambah set": cincin
  22 plus + 13,5/600 text2. **Aksi gerakan**: dua `GymButton` clear tinggi 42
  — "Riwayat gerakan" (menu) & "Superset"/"Akhiri superset" (link).
- **Kartu gerakan tertutup** (72): tile 44 + nama 15/700 + meta "3 set ·
  target 72 kg × 9" + tombol expand 32 (chevronDown berputar) + ⋯ 32.
- **Tambah gerakan**: 52 r18 stroke text3 1,2, plus + 14/600.
- **Pil istirahat** (menggantikan kartu istirahat di daftar dan kapsul di
  header): `GlassSurface(bar, blur)` 358×64 r32 di bawah layar (padding
  4/16/18/16, SafeArea), tampil hanya saat timer jalan, masuk/keluar
  meluncur dari bawah 220 ms: titik hidup 7 accent + "Istirahat" 13,5/700;
  "Set 3 · 65 kg × 8" 11,5 text2; waktu 22/800 tabular; **−15 / +15** clear
  44×36 r18 12,5/700; **lewati** tinted lingkaran 44 ikon skip (tooltip &
  semantics "Lewati istirahat"). Ketuk area teks → layar istirahat penuh.
  Daftar diberi padding bawah 90 saat pil tampil.
- **Layar istirahat penuh**: sama seperti sekarang; tombol −15s/+15s clear,
  Lewati istirahat tinted; cincin: lintasan ringTrack, busur accent 12 px.

### 7.4 Ringkasan (`04`)

Latar bg + washB. Isi tengah.

1. Hero: lingkaran 64 accentSoft berisi Lottie `sessionDone` 40 (diam setelah
   sekali); "Sesi selesai" 24/800; "Push · Minggu, 4 Okt · 18.40" 13 text2.
2. Angka besar: **Durasi** | **Volume** 30/800 dengan label 12,5 text2,
   pemisah hairline 1×48.
3. Kisi 2×2 (kartu 65 r18, tile 36/12 surface2 ikon 17 text): Set kerja
   (dumbbell), Total rep (swap), Rekor baru (trophy), Target naik
   (arrowUpRight) — nilai 19/800 + label 11,5 text2. "Target naik" = jumlah
   gerakan yang preskripsi berikutnya `up`.
4. **Otot yang dilatih** (tetap ada; tidak di mockup): kartu dengan area
   nested berisi `MuscleMap` 200 + empat pil porsi (surface2 r12).
5. **Rekor baru** (hanya kalau ada): kartu; kepala trophy 16 `warm` + "Rekor
   baru" 15/700; baris nama 14/600 + sub "e1RM 109 kg" 12 text2 + nilai
   "86 kg × 8" 14/800 (set terbaik).
6. **Target sesi berikutnya**: baris nama 14/500 · pil delta ("+1 rep" /
   "+2,5 kg" doneBg; "tahan" surface2; "−5 kg" warnSoft; "baru" surface2) ·
   target 14/700; pemisah hairline.
7. **Rutinitas diperbarui** (hanya saat sesi menyimpang): banner accentSoft
   r18: lingkaran 36 `accentFill` check putih; "Rutinitas Push diperbarui"
   14/700 + diff 12 text2; tautan **Batalkan** 13/700 accent. Keadaan lain:
   "Susunan belum disimpan" + tautan **Simpan**; "Rutinitas Push dikembalikan"
   + **Simpan lagi**.
8. **Selesai**: tinted 54, 16/700.

### 7.5 Riwayat (`05`)

- Header: "Riwayat" 28/800 + `GlassIconButton` 38 plus (→ sheet tambah: sesi
  bebas / catat lewat — ada).
- **Aktivitas**: kartu; "Aktivitas" 15/700 + "23 sesi tahun ini" 12,5 text2;
  `ActivityHeatmap` 24 minggu; label bulan 10,5 text2.
- **Chip filter**: Semua (terpilih tinted) + nama rutinitas.
- **Grup bulan**: label `OKTOBER 2026` 11/700 text2; baris sesi 72 (surface
  r18, bayangan, padding 12/14/12/12): tile 44/14 hue rutinitas (hash nama →
  hue bergilir) + dumbbell ink; sesi bebas = orange + alarm; **lencana** set
  kerja di pojok kanan bawah tile (surface, stroke accent 1, r7, 10/800
  accent); nama 15/700; meta "Sab, 3 Okt · 48 mnt · 6,1 t" 12,5 text2;
  chevron 18 text2. Geser kiri = hapus (ada). Ketuk → sheet detail (ada;
  tombolnya GymButton baru: Lanjutkan sesi tinted, Pakai susunan clear,
  Edit clear, Hapus danger).
- Kosong: `EmptyState` (ilustrasi tetap).

### 7.6 Statistik (`06a/b/c`)

- "Statistik" 28/800; chip rentang 7/30/90 hari; **KPI** tiga kartu 108
  (surface r18, padding 12): tile 30/10 hue (violet calendar, cyan menu,
  orange scale); nilai 20/800 (`CountUp`); label 11,5 text2.
- `SegmentedTabs` Keseimbangan / Kelelahan / Kekuatan.
- **Keseimbangan**: kartu *Peta panas otot* ("porsi volume" 12 text2 di
  kanan): area nested r18 padding 12/0 berisi `MuscleMap` 244; legenda
  Rendah + 5 batang 8 dp r4 + Tinggi (11 text2); `NoteBanner` warn "X paling
  sedikit…" / accent detail otot yang diketuk; "Ketuk otot untuk melihat
  porsinya" 11,5 text2. Kartu *Region tubuh yang dilatih*: radar 236 + legenda
  (titik 9: accent "30 hari terakhir", text3 "Periode sebelumnya").
- **Kelelahan**: kartu *Volume set mingguan* (sub "Set kerja per minggu, 8
  minggu"): `BarSeries` 8 batang, `average`, gelembung "51 set", label −7
  mgg / −4 mgg / sekarang. Kartu *Hari sejak terakhir dilatih*: baris region
  14/500 · bilah 110×8 (accent; ≥ 7 hari warn) · "2h" 13/700 (warn bila ≥ 7).
  `NoteBanner` warn catatan kelelahan.
- **Kekuatan**: kartu *Perkiraan 1RM*: pemilih gerakan = `GymButton` clear
  kecil (nama + chevronDown) → PopupMenu (ada); angka 36/800 + "kg" 14/600
  text2 + pil "+18,5 % · 12 mgg" doneBg (turun → warnSoft); `BarSeries` 12
  batang, gelembung "109 kg", label −11 mgg / −6 mgg / sekarang. Kartu
  *Kekuatan per gerakan* ("12 mgg terakhir"): baris nama 14/600 + "1RM 109
  kg" 12 text2 · `Sparkline` 94×36 · pil delta 58 lebar. Kartu *Berat badan*:
  "Berat badan" 12,5 text2 · "72,4 kg" 24/800 · "−0,6 kg / 30 hari" 12 text2
  · tombol **Catat** tinted 34 (plus) · sparkline lebar penuh 36 dari 12 entri
  terakhir bila ≥ 2 (menggantikan grafik batang). Tombol **Buka dashboard**
  clear 46 (chart).
- Kosong: `EmptyState` (ilustrasi) di kartu kekuatan.

### 7.7 Program (`07`)

- Header: "Program" 28/800 + `GymButton` clear 34 "Library gerakan" (dumbbell).
- **Kartu program** (surface + washB r22): `PROGRAM AKTIF` 10,5/700 accent;
  nama 22/800; meta "Rotasi · 3 rutinitas · double progression" (mode ·
  jumlah · policy mayoritas) 12,5 text2; dua `GymButton` clear 42: **Ganti
  program** (swap) & **Lewati sesi** (skip; rotasi saja).
- **Rutinitas**: `SectionTitle("Rutinitas", "Urutkan")` → sheet urutan (baris
  nama + panah naik/turun + jadikan berikutnya; ada). Kisi 2 kolom, kartu
  128 r20 (berikutnya + stroke accent 1,5): nama 16/700 + `Pill` Berikutnya;
  meta "4 gerakan, 12 set" 12 text2; bawah: `Odometer` volume rencana sesi
  berikutnya (kg, dari `planExercise`) + **Mulai** 34 (tinted bila
  berikutnya, clear lainnya). Ketuk kartu → editor; tahan → lembar aksi
  (Ganti nama · Duplikat · Jadikan berikutnya · Hapus). Kartu **Tambah
  rutinitas** (stroke text3 1,2 putus; lingkaran 36 surface2 plus).
- **Aturan program**: `SectionTitle`; grup surface r20: *Mode* (nilai Rotasi
  / Hari tetap, chevron → sheet pilih; hari tetap menampilkan baris *Hari
  latihan* dengan chip Sen–Min), *Istirahat minimum antar sesi* (rotasi;
  stepper surface2 r16: tombol segThumb 26 minus/plus, nilai "0 hari"
  13/700).
- Tanpa program: kartu "Belum ada program" + Pilih program (tinted) + Susun
  sendiri (clear); rutinitas lepas tetap tampil di kisi.

### 7.8 Profil (`08`) — halaman dorong

- Nav: `GlassIconButton` 38 arrowLeft; "Profil" 16/700 tengah.
- **Akun** (surface r22 padding 16): avatar 52 accentSoft inisial 18/800;
  email 15/700; baris sinkron: titik 7 (done tersinkron · warn gagal/tanpa
  sesi · text3 tanpa server/sedang) + "Tersinkron · 2 menit lalu" 12,5 text2.
- Grup `LATIHAN`: Satuan berat (scale) · Istirahat bawaan (alarm) · Faktor
  deload (arrowDownRight) · Catat RIR (menu, switch) · Layar tetap menyala
  (eye, switch) · Notifikasi istirahat (bell; web saja) · Minggu dimulai
  (calendar) · Alat saya (dumbbell).
- Grup `TAMPILAN`: Tema (moon) · Warna aksen (settings; lima titik 18 di
  kanan, terpilih stroke `text` 2; ketuk titik = pilih) · Bahasa (globe).
- Grup `DATA & AKUN`: Paksa sinkron (sync) · Ekspor cadangan (download) ·
  Impor cadangan (dataTransfer) · Tentang aplikasi (info; nilai versi) ·
  **Keluar** (logout, danger) — menggantikan tombol besar.

### 7.9 Layar lain (tidak di mockup)

Mengikuti token dan komponen baru tanpa susunan baru: masuk/daftar (field
surface r14, tombol tinted), pilih program (kartu template memakai `HueTile`
+ ikon alat, bukan 3D), susun sendiri, pemilih alat, library gerakan (kolom
cari surface r16, kategori `HueTile`/`MuscleGlyph`), editor rutinitas, editor
sesi lampau, dashboard (`_Metric` → kartu surface + `HueTile`), sheet riwayat
gerakan.

---

## 8. Insight Beranda (`homeInsight`)

Fungsi murni, diuji unit: masukan `next` (NextSession?), daftar
`(nama, PrescriptionKind)` gerakan sesi berikutnya, `daysSince` (int?),
`Strings`. Keluaran `(title, body)`:

| Keadaan | Judul | Badan |
| --- | --- | --- |
| tidak ada program | "Belum ada program" | "Pilih program supaya sesi berikutnya tersusun sendiri." |
| `early`, rotasi | "Hari pemulihan" | "{Push} jatuh pada {Rabu}. Terakhir dilatih {5} hari lalu." |
| `early`, hari tetap | "Hari istirahat" | "Latihan berikutnya {Rabu}: {Push}." |
| n gerakan `up` ≥ 1 | "{Push} hari ini, {dua} gerakan siap naik" | "Terakhir dilatih {5} hari lalu. {Dumbbell Fly} dan {Chest Press} naik targetnya sesi ini." |
| semua `hold`/`first` | "{Push} hari ini, kejar rep" | "Terakhir dilatih {5} hari lalu. Beban dipertahankan — penuhi rentang rep, beban naik sesudahnya." |
| ada `deload` | "{Push} hari ini, satu gerakan diturunkan" | "{Chest Press} di-deload setelah beberapa sesi gagal; selebihnya tetap." |
| belum pernah dilatih | … | "Belum pernah dilatih." menggantikan "Terakhir dilatih…" |

Angka 1–9 ditulis dengan kata dalam bahasa aktif ("dua"/"two"), ≥ 10 angka.

---

## 9. Gerak

Aturan `motion.dart` tetap. Tambahan: pil istirahat masuk/keluar meluncur
dari bawah (`normal`), busur cincin tumbuh saat kartu tampil (`slow`),
thumb tab segmented bergeser (ada), titik hari minggu berganti warna lembut
(ada). Tidak ada animasi berulang selain Lottie jam pasir di layar istirahat.

## 10. Aksesibilitas & web

- Kontras teks ≥ 4,5:1 (test `v30_theme_glass_test.dart`: text/text2 di atas
  surface & bg, accent di atas bg, putih di atas accentFill, done di atas
  doneBg, warn di atas warnSoft — dua tema, lima aksen).
- Semua tombol ikon punya `Tooltip`/`Semantics` label; tab bar punya label
  terlihat.
- Web: lebar ponsel 480 tetap; blur hanya di tiga permukaan (§1) sehingga
  WebKit tidak kewalahan; tidak ada `cacheWidth/Height` baru.
- "Kurangi gerak" mematikan semua animasi lewat `GymMotion.of`.

## 11. Yang dihapus

`StatBlock`, `_QuickTile`, `_HeroFigure`, `Gym3dIcon` + `assets/3d/`,
Manrope, `c.block()`, `GymButtonShape` tetap ada tapi primary selalu pil,
kapsul istirahat di header sesi, kartu istirahat di daftar sesi (diganti pil
bawah), tombol Keluar besar (jadi baris), tab Workout (Tracker/My Plan).
