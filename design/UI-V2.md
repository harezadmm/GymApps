# UI v2 — mengikuti referensi "Diet Adviser"

Referensi: `REFRENSI/NEW REFRENSI/*.png` (17 layar UI kit). Isi dan fitur
aplikasi tidak berubah; yang diambil dari referensi hanya gayanya. Semua
token ada di `app/lib/core/theme.dart`, komponennya di `app/lib/core/widgets.dart`.

## Kontrak desain

| Unsur | Referensi | Penerapan |
| --- | --- | --- |
| Latar | hampir hitam `#0D0D0F` | `GymColors.bg` `#0C0C0F` |
| Kartu | abu gelap, **tanpa garis tepi**, sudut ±20 | `surface` `#1B1B1F`, `GymRadius.card` 20; `GymCard`/`SettingsGroup` tidak lagi memakai `border` |
| Aksen | violet `#8B7CF6` | `accent` `#8F7FFF` (ikon/teks di atas gelap), `accentFill` `#6A5AE6` (latar tombol/chip terpilih, teks putih ≥ 4,5:1) |
| Warna pembeda | pink, cyan, oranye, lime, hijau pada kartu "Water/Weight/Calories/BPM" | `GymHues`; latar tipis lewat `c.tint(hue)`, blok pekat lewat `c.block(hue)` |
| Ikon | cakram bulat berwarna | `IconDisc` — baris setelan, kisi aksi cepat, kategori Library, baris gerakan |
| Header | judul kiri, lonceng + avatar bulat kanan | `ScreenHeader` + `SquareIconButton` (kini lingkaran) + `AvatarCircle` (Home → Profil) |
| Nav bawah | pil melayang, ikon saja, aktif = aksen | `_FloatingNav` di `main.dart`; label tetap ada sebagai semantics/tooltip |
| Tombol utama | pil violet, teks putih | `GymButton` primary → `accentFill`, radius pil |
| Blok statistik | kartu berwarna penuh, angka besar | `StatBlock` (Home) dan kartu berat badan (`c.block(pink)`) |
| Kisi 2×2 | "My Fitness Profile / My Nutrition Goals" | `_QuickTile` di Home: Pilih sesi lain, Bebas, Library, Dashboard |
| Kategori | "Featured categories": cakram + label | `_CategoryDisc` di Library untuk bagian tubuh |
| Kolom cari | kotak gelap membulat, ikon saring di kanan | `_SearchField` Library; ikon saring = "Alat saya" |
| Grafik | batang berwarna aksen | ramp peta panas & kalender diturunkan dari aksen (`_ramp`) |

## Aturan yang dipertahankan

- Kontras teks ≥ 4,5:1 (NFR-11). Test di `test/v18_units_theme_test.dart`
  memeriksa `accentFill` vs putih dan `accent` vs latar untuk semua pilihan
  aksen, di tema gelap dan terang.
- Aksen pilihan pengguna tetap berlaku: `accentFill` dihitung dari aksen
  (`_fillFor`), ramp grafik dan `hues.violet` ikut aksen.
- Tema terang memakai palet sendiri (`GymColors.light`); aksen digelapkan
  lewat `lightAccent` seperti sebelumnya.
- Font tetap Inter yang di-bundle (offline-first).

## Yang tidak diambil dari referensi

Foto pelatih, rating bintang, "Upgrade to premium", dan konten nutrisi —
tidak ada padanannya di GymApps, jadi tidak dibuatkan tempatnya.
