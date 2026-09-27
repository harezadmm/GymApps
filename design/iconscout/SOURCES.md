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

Kategori bagian tubuh di Library **tidak** memakai ikon IconScout: ikon
anatomi yang tersedia terlalu rinci untuk 24 px. Gantinya `MuscleGlyph`
(`core/charts.dart`) menggambar siluet dari peta otot Stats dengan kelompok
otot yang disorot.

SVG sumbernya ada di `icons/`. Bangun ulang font setelah mengganti atau
menambah ikon (kode glyph mengikuti urutan nama berkas, lihat
`GymIcons.json`, jadi perbarui `lib/core/gym_icons.dart` juga):

```bash
cd D:/sdk/tmp/iconfont && npm i svgicons2svgfont@12 svg2ttf@6
NODE_PATH=D:/sdk/tmp/iconfont/node_modules node "D:/Desktop/CODE PROJECT/GymApps/scripts/build-gym-icons.js" "D:/Desktop/CODE PROJECT/GymApps/design/iconscout/icons" "D:/Desktop/CODE PROJECT/GymApps/app/assets/fonts/GymIcons.ttf" "D:/Desktop/CODE PROJECT/GymApps/design/iconscout/GymIcons.json"
python "D:/Desktop/CODE PROJECT/GymApps/scripts/gen-gym-icons-dart.py"
```

## Font judul — Barlow Condensed (OFL, `app/assets/fonts/BarlowCondensed-*.ttf`)

Bukan dari IconScout; dari Google Fonts (lisensi di `OFL-BarlowCondensed.txt`).
Dipakai untuk judul layar, nama rutinitas, dan angka besar di blok statistik.

## Ilustrasi (`app/assets/illustrations/`)

Satu kontributor, **Roundsquid**, gaya flat dengan latar gumpalan lavender
muda yang terbaca di tema gelap maupun terang.

| Berkas | Slug IconScout | Dipakai di |
| --- | --- | --- |
| lift_overhead.svg | man-lifting-barbell-at-gym-7807673 | layar masuk |
| lift_barbell.svg | girl-doing-weightlifting-7807658 | layar daftar |
| plan_workout.svg | woman-workout-according-to-gym-plan-7807642 | pilih program |
| empty_history.svg | boy-with-workout-plan-8689251 | riwayat kosong |
| empty_stats.svg | girl-lifting-barbell-6137974 | statistik kosong |
