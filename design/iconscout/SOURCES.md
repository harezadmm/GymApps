# Aset IconScout

Semua aset di bawah diunduh lewat MCP IconScout dengan langganan pemilik
proyek ("Downloaded under your subscription license", `attribution_required:
false`). Boleh dipakai di dalam aplikasi ini. Berkas mentahnya tidak boleh
dibagikan atau dijual lagi terpisah dari aplikasi.

## Ikon — font `GymIcons` (`app/assets/fonts/GymIcons.ttf`)

Paket **Gym** oleh Bharat Design (`gym-icon-pack_389484`), gaya line 24 px.
Satu paket supaya ketebalan garis dan sudutnya seragam; semuanya satu warna
sehingga ikut warna tema lewat `IconTheme`.

| Nama di font | Slug IconScout | Dipakai untuk |
| --- | --- | --- |
| barbell | equipment-gym-16676219 | alat: barbell |
| dumbbell | dumbbell-16676212 | alat: dumbbell |
| kettlebell | kettlebell-16676230 | alat: kettlebell |
| cable | equipment-gym-16676217 | alat: kabel (tumpukan beban) |
| machine | equipment-chest-press-16676216 | alat: mesin |
| band | expander-16676221 | alat: band |
| ball | yoga-ball-16676255 | alat: bola |
| cardio | treadmill-16676240 | alat: kardio |
| bodyweight | workout-squats-16676249 | gerakan tanpa alat |
| scale | weight-scale-16676242 | berat badan |

### Ikon antarmuka — paket **Basic UI** oleh Barudak Lier (`basic-ui-icon-pack_73462`), garis 32 px

Berkas `icons/ui_*.svg`; nama konstanta tanpa awalan `ui_`. Dipakai untuk nav
bawah, header, kolom cari, baris setelan, dan aksi cepat:

| Nama | Slug IconScout | Dipakai untuk |
| --- | --- | --- |
| home | home-3460720 | nav Beranda |
| chart | graph-3460716 | nav Statistik, e1RM, dashboard |
| clock | clock-3460680 | nav Riwayat, "sejak terakhir" |
| user | add-user-… (Basic UI) | nav Profil |
| search / filter / plus | search-3460769 / filter-3460704 / plus-sign-3460760 | Library, header |
| bell / calendar / alarm | bell-3460813 / calendar-3460670 / alarm-3460803 | setelan |
| edit / data-transfer / play | note-…/edit / data-transfer-3460691 / play-3460759 | Bebas, Pilih sesi lain, Mulai |
| download / sync / copy | download-… / loading-… / copy-… | cadangan & sinkron |
| moon / settings / globe / info / logout | moon / option / globe / info-sign / power | bagian Aplikasi |
| menu / more-vertical / trash / lock / mail / eye | — | daftar & aksi |
| eye-off | eye-off-3460701 | sembunyikan sandi (pasangan `eye`) |
| star / star-filled | star-3460781 / star-3461035 (Basic UI **Glyph**, pack id 73463) | favorit di Library; versi isi dari paket kembarannya supaya siluetnya sama persis |
| trophy | trophy-3460787 | rekor baru (layar selesai) |
| cloud | cloud-3460681 | sinkron menunggu |
| note | note-3460750 | catatan gerakan & catatan sesi |
| pause | pause-3460753 | tambah set rest-pause |
| skip | rewind-forward-3460767 | lewati / jadikan sesi berikutnya |
| link | link-3460735 | superset |
| flag | flag-3460705 | preskripsi tanpa arah |
| sliders | equalizer-3460700 | atur isi rutinitas |

#### Dari paket kembaran Barudak Lier

Basic UI tidak punya silang, centang, dan api. Kontributor yang sama punya
paket **UI Essentials** (pack id 73464, garis 32 px, lebar
garis 3 dan ujung bulat yang sama):

| Nama | Slug IconScout | Dipakai untuk |
| --- | --- | --- |
| close | cross-3461190 | tutup lembar / hapus baris |
| check | approve-3461191 | centang pilihan (`_Tick`), centang set selesai |
| check-circle | approve-3461442 | set selesai di Riwayat dan editor sesi |
| fire | fire-3461216 | tambah set pemanasan |

Silang dan centang paket ini memenuhi kotak glyph (seperti ikon lain di
paket), sedangkan versi Material punya ruang kosong di tepi. Pakai kira-kira
¾ ukuran Material yang digantikan (silang 24 → 18, centang 17 → 13).

#### Diturunkan dari glyph di atas (`scripts/derive-gym-icons.py`)

Glyph berikut tidak ada di paket mana pun milik Barudak Lier. Daripada
mengambil paket lain dengan ketebalan dan ujung garis berbeda, glyph ini
dirakit dari potongan SVG yang sudah diunduh, atau digambar ulang dengan
konstruksi garis paketnya sendiri (lebar 3 di kanvas 32, ujung dan sambungan
bulat — persis centang approve-3461442). Skripnya membaca SVG di `icons/` dan
menulis hasilnya kembali ke sana.

| Nama | Sumber | Cara | Dipakai untuk |
| --- | --- | --- | --- |
| add | plus-sign-3460760 | tanda tambah tanpa cincin | stepper, "tambah hari/gerakan" |
| minus | plus-sign-3460760 | batang mendatar tanda tambah | stepper |
| circle | plus-sign-3460760 | cincinnya saja | set belum selesai, rutinitas bukan berikutnya |
| minus-circle | plus-sign-3460760 | cincin + batang mendatar | hapus set terakhir |
| alert | info-sign-3460725 | diputar 180° (titik ke bawah → tanda seru) | pesan galat field |
| arrow-down / arrow-up / arrow-left / arrow-right | download-3460695 | panahnya saja, dipusatkan, diputar | urutan gerakan, tombol kembali, preskripsi tahan |
| arrow-down-right / arrow-up-right | download-3460695 | diputar 45° | drop set, preskripsi turun / naik |
| chevron-right / chevron-down / chevron-up | left-3461075 (Elements UI, pack id 73470) | sudut 45° yang sama, garis 3 (aslinya 2), ukuran setara chevron Material | baris daftar, buka-tutup kartu |
| swap | data-transfer-3460691 | panah ⇅ tanpa cincin, diputar 90° | ganti gerakan |
| check-double | approve-3461442 | dua centang berkonstruksi sama | jumlah set selesai (layar selesai) |
| cloud-off | cloud-3460681 | awan dipotong + coretan, seperti eye-off | sinkron mati / gagal |
| cloud-check | cloud-3460681 + approve-3461442 | awan + centang kecil | sinkron selesai |

Unduhan yang tidak dipakai sebagai glyph: minus-3461082 (Elements UI, garis 2
— terlalu tipis) dan list-3460736.

Kategori bagian tubuh di Library **tidak** memakai ikon IconScout: ikon
anatomi yang tersedia terlalu rinci untuk 24 px. Gantinya `MuscleGlyph`
(`core/charts.dart`) menggambar siluet dari peta otot Stats dengan kelompok
otot yang disorot.

SVG sumbernya ada di `icons/`. Bangun ulang font setelah mengganti atau
menambah ikon (kode glyph mengikuti urutan nama berkas, lihat
`GymIcons.json`, jadi perbarui `lib/core/gym_icons.dart` juga). Font ikon
hanya menggambar **isian**: SVG yang cuma berisi `stroke` akan tampil kosong,
jadi garis harus sudah jadi kontur (test `assets_iconscout_test` memeriksanya).
Langkah pertama hanya perlu bila glyph turunan atau sumbernya berubah:

```bash
uv pip install --target 'D:\sdk\tmp\pyfonts' --python 3.13 fonttools pillow skia-pathops
PYTHONPATH=D:/sdk/tmp/pyfonts python "D:/Desktop/CODE PROJECT/GymApps/scripts/derive-gym-icons.py"
cd D:/sdk/tmp/iconfont && npm i svgicons2svgfont@12 svg2ttf@6
NODE_PATH=D:/sdk/tmp/iconfont/node_modules node "D:/Desktop/CODE PROJECT/GymApps/scripts/build-gym-icons.js" "D:/Desktop/CODE PROJECT/GymApps/design/iconscout/icons" "D:/Desktop/CODE PROJECT/GymApps/app/assets/fonts/GymIcons.ttf" "D:/Desktop/CODE PROJECT/GymApps/design/iconscout/GymIcons.json"
python "D:/Desktop/CODE PROJECT/GymApps/scripts/gen-gym-icons-dart.py"
```

## Font judul — Manrope (OFL, `app/assets/fonts/Manrope-*.ttf`)

Bukan dari IconScout; dari Google Fonts (lisensi di `OFL-Manrope.txt`).
Dipakai untuk judul layar, nama rutinitas, dan angka besar di blok statistik.

## Ilustrasi (`app/assets/illustrations/`)

Satu kontributor, **Nataliia Nesterenko**, figur potongan tanpa latar (flat).
Lingkaran aksen di belakangnya digambar aplikasi (`GymIllustration(blob: true)`),
jadi ikut warna aksen dan tema. Ilustrasi Roundsquid sebelumnya diganti
karena membawa latar gumpalan sendiri yang bertabrakan dengan kartu.

| Berkas | Slug IconScout | Dipakai di |
| --- | --- | --- |
| hero_lift.svg | female-powerlifter-lifting-barbell-3857849 | kartu sesi berikutnya (Home) |
| lift_overhead.svg | athlete-with-barbell-3937472 | layar masuk |
| lift_barbell.svg | sportswoman-lifting-barbell-3857850 | layar daftar |
| plan_workout.svg | woman-doing-squat-exercise-4243315 | pilih program |
| empty_history.svg | athlete-with-sport-equipment-3937483 | riwayat kosong |
| empty_stats.svg | athlete-exercising-on-bar-3937482 | statistik kosong |

## Ikon 3D (`app/assets/3d/`)

Satu paket, **Gym And Fitness** oleh **Didik Prasetio**
(`gym-and-fitness-3d-icon-pack_331506`, premium, lisensi langganan tanpa
atribusi). Aset 3D tidak bisa diwarnai ulang, jadi yang dipilih paket yang
sudah ungu satu warna (warna dominan `#4a2a95`) dengan bahan matte lembut dan
sudut kamera yang sama — sewarna aksen `#8F7FFF`/`#6A5AE6`, terbaca di kartu
gelap `#1B1B1F` maupun putih, tanpa karakter/wajah.

PNG 3000 px diunduh lalu dipotong ke objeknya, diberi padding seragam (objek
maks. 340 px; objek bulat/padat dikecilkan sedikit supaya bobot visualnya
setara), dan disimpan sebagai WebP transparan 384 × 384 (`quality 82`,
9–17 KB). Enum dan widgetnya: `Gym3d` / `Gym3dIcon` di `lib/core/art3d.dart`.

| Berkas | Slug IconScout | Dipakai di |
| --- | --- | --- |
| calendar.webp | gym-calendar-14535162 | Home: ubin "Pilih sesi lain"; template Bro split |
| stopwatch.webp | stopwatch-14535283 | Home: ubin "Bebas" |
| dumbbell.webp | barbell-14535138 | Home: ubin "Library Gerakan"; template Push / Pull / Legs |
| fitness_watch.webp | fitness-watch-14535141 | Home: ubin "Dashboard" |
| grippers.webp | grippers-14535164 | template Upper / Lower |
| kettlebell.webp | kettle-bell-14535165 | template Heavy Duty |
| exercise_ball.webp | exercise-ball-14535139 | template Full Body |
| weight_plates.webp | weight-plates-14543158 | template 5 × 5 |

Paket ini tidak punya piala atau medali, jadi layar selesai sengaja tidak
diberi ikon 3D: mencampur piala dari paket lain akan memecah keseragaman
cahaya dan warnanya.

## Lottie (`app/assets/lottie/`)

Satu kontributor, **Prosymbols**, gaya garis satu tinta di kanvas 256 × 256
(premium, lisensi langganan tanpa atribusi). Garis, bukan maskot: figur di
ilustrasi tanpa wajah, dan ikon aplikasi juga garis. Aset berwajah di paket
yang sama (medali, orang membawa piala) sengaja dilewati.

Diunduh sebagai JSON dengan palet IconScout **"GymApps" (id 824060**:
`#8F7FFF #6A5AE6 #4ADE80 #FFA94D #FF5FB0 #26262C`). Karena sumbernya satu
tinta hitam, palet memetakannya ke `#26262C` — sama dengan `surface2`, tidak
terlihat di kartu gelap. Maka setelah diunduh:

- tinta `#26262C` diganti warna palet lain (tabel di bawah); popper diberi
  pita dan serpihan bergantian violet/hijau/oranye/pink dari palet yang sama;
- ekspresi After Effects (`x`) dan efek pseudo Duik Kleaner (`ef` ty 5)
  dibuang — lottie-flutter tidak menjalankan keduanya, dan di piala keduanya
  menyumbang 350 dari 423 KB;
- piala: matte bersama (`tp`, bodymovin 5.12) diganti matte duplikat per
  layer, karena lottie-flutter selalu memasangkan matte ke layer tepat di
  atasnya (tanpa ini satu bintang hilang dan satu lagi terpotong);
- angka dibulatkan 3 desimal dan JSON dipadatkan. Tidak ada gambar raster.

Di aplikasi (`GymLottie` / `GymLottieView`, `lib/core/lottie_art.dart`)
warna palet itu dipetakan lagi ke token tema aktif (`accent`, `doneInk`,
`warn`, `hues.pink`, …), jadi tema terang dan aksen pilihan pengguna ikut
berlaku. Garis yang lebih tipis dari 1,3 dp ditebalkan saat digambar kecil.

| Berkas | Slug IconScout | Warna tinta | Ukuran | Dipakai di |
| --- | --- | --- | --- | --- |
| session_done.json | confetti-15718296 (paket "Success") | corong `#8F7FFF`, pita/serpihan 4 warna palet | 24 KB | ringkasan sesi: kanan judul "SESSION COMPLETE", 96 dp, sekali |
| new_record.json | trophy-18210984 | `#FFA94D` | 75 KB | kartu rekor baru di ringkasan, 40 dp, sekali |
| resting.json | hourglass-15718303 (paket "Success") | `#8F7FFF` | 24 KB | layar istirahat, pojok kanan kepala, 44 dp, berulang (0,6×) selama timer jalan |

Aturan gerak mengikuti `lib/core/motion.dart`: perayaan diputar sekali lalu
diam di bingkai terakhir; jam pasir satu-satunya yang berulang karena ia
penanda "sedang berjalan"; dengan "kurangi gerak" semuanya satu bingkai diam
(perayaan: bingkai terakhir; jam pasir: posisi tegak).
