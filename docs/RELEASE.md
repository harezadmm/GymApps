# Rilis Android: kunci tanda tangan

Setiap APK Android ditandatangani, dan Android hanya mau memperbarui aplikasi
yang terpasang kalau pembaruannya ditandatangani kunci yang sama. Kunci itu
tidak bisa diganti belakangan tanpa semua orang uninstall dulu. Dokumen ini
tentang kunci rilis GymApps: cara membuatnya, di mana ia dibaca, dan kenapa
build tanpa kunci masih bisa jalan.

## Membuat keystore (sekali seumur aplikasi)

`keytool` ikut dengan JDK. Di Windows dengan Android Studio ia ada di
`C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`; di macOS dan
Linux biasanya sudah di PATH.

```sh
keytool -genkey -v -keystore ~/gymapps-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias gymapps
```

- `-validity 10000` hari (27 tahun): Play menolak kunci yang kedaluwarsa
  sebelum 2033, dan tidak ada gunanya kunci yang habis lebih dulu daripada
  aplikasinya.
- Kata sandi keystore dan kata sandi kunci boleh sama; keduanya ditanya
  `keytool`, dan keduanya harus masuk ke `key.properties` di bawah.
- Simpan berkas `.jks` **di luar** repo (folder rumah, pengelola kata sandi,
  atau drive terenkripsi) dan **cadangkan**. Kalau hilang, tidak ada cara
  menerbitkan pembaruan untuk aplikasi yang sudah terpasang.

## Mengisi `app/android/key.properties`

```properties
storePassword=<kata sandi keystore>
keyPassword=<kata sandi kunci>
keyAlias=gymapps
storeFile=C:/Users/<nama>/gymapps-release.jks
```

- `storeFile` boleh path absolut (pakai `/`, juga di Windows) atau relatif
  terhadap folder `app/android/` — folder tempat `key.properties` berada.
- Berkas ini, `*.jks`, dan `*.keystore` ada di `.gitignore` (root dan
  `app/android/`). Jangan pernah di-commit: siapa pun yang memegang keystore
  dan kata sandinya bisa menerbitkan pembaruan atas nama aplikasi ini.

Lalu build seperti biasa:

```sh
pwsh scripts/build-android.ps1
```

Skrip menolak build rilis kalau `key.properties` tidak ada. Untuk sengaja
membuat APK rilis dengan debug key (hanya untuk uji di HP sendiri):

```sh
pwsh scripts/build-android.ps1 -DebugSign
```

## Kenapa build tanpa kunci masih jalan

`app/android/app/build.gradle.kts` membaca `key.properties` kalau ada. Kalau
tidak ada, build rilis memakai debug key milik Android SDK dan Gradle
mencetak:

```
PERINGATAN: APK rilis ditandatangani debug key, lihat docs/RELEASE.md
```

Cadangan ini disengaja: `flutter run --release`, CI tanpa rahasia, dan
kontributor tanpa akses ke keystore tetap bisa memastikan build rilis tidak
rusak. Yang dijaga adalah supaya APK semacam itu tidak *terbagikan* tanpa
sadar — itu tugas `scripts/build-android.ps1` yang menolak build rilis tanpa
`key.properties`, dan peringatan Gradle untuk siapa pun yang memanggil
`flutter build apk` langsung.

## Pindah dari debug key ke kunci asli

Semua APK rilis sebelum kunci ini ada ditandatangani debug key. APK yang
ditandatangani kunci asli **tidak bisa dipasang menimpa** APK debug-key
(`INSTALL_FAILED_UPDATE_INCOMPATIBLE`), dan sebaliknya. Satu kali uninstall
diperlukan di setiap HP yang memasang APK lama — data lokal ikut hilang,
jadi pastikan sinkron Supabase sudah jalan (Profil menampilkan alamat
server, bukan "Sync off") atau ekspor JSON dulu sebelum uninstall.

Build debug (`GymApps Debug`, id `dev.hariz.gymapps.debug`) tidak terpengaruh:
ia terpasang berdampingan dengan build rilis dan selalu memakai debug key.
