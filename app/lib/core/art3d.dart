/// Ikon 3D IconScout untuk jalan pintas Home dan kartu template program.
/// Sumber dan lisensinya di `design/iconscout/SOURCES.md`.
///
/// Semuanya dari **satu** paket ("Gym And Fitness", Didik Prasetio): cahaya,
/// bahan, dan sudut kameranya sama, jadi deretan ikon terbaca sebagai satu
/// keluarga. Aset 3D tidak bisa diwarnai ulang seperti font `GymIcons`, maka
/// paketnya dipilih yang memang ungu satu warna — sewarna aksen aplikasi —
/// dan tetap terbaca di kartu gelap maupun putih.
///
/// Berkasnya WebP transparan 384 × 384 dengan padding seragam (dibuat dari
/// PNG 3000 px; objek bulat sedikit dikecilkan supaya bobot visualnya sama
/// dengan objek lebar), jadi ukuran widget yang sama menghasilkan ikon yang
/// tampak sama besar.
library;

import 'package:flutter/material.dart';

import 'motion.dart';

enum Gym3d {
  dumbbell('dumbbell'),
  kettlebell('kettlebell'),
  weightPlates('weight_plates'),
  stopwatch('stopwatch'),
  calendar('calendar'),
  fitnessWatch('fitness_watch'),
  grippers('grippers'),
  exerciseBall('exercise_ball');

  const Gym3d(this.file);
  final String file;

  String get asset => 'assets/3d/$file.webp';
}

/// Satu ikon 3D seukuran [size] dp.
///
/// Hiasan murni: labelnya selalu ada di sebelahnya, jadi pembaca layar tidak
/// perlu mendengar "gambar" di setiap ubin.
class Gym3dIcon extends StatelessWidget {
  const Gym3dIcon(this.art, {super.key, this.size = 48});

  final Gym3d art;
  final double size;

  /// Sisi berkas sumber. Mendekode lebih besar dari ini hanya memperbesar
  /// piksel yang sama sambil memakan memori.
  static const _sourcePx = 384;

  @override
  Widget build(BuildContext context) {
    // Dekode seukuran tampilan: 46 dp di HP 3× cukup 138 px, bukan 384 px
    // penuh untuk setiap ubin — enam ikon di satu layar tetap ringan.
    final px = (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(1, _sourcePx);
    final Widget image = ExcludeSemantics(
      child: Image.asset(
        art.asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        cacheWidth: px,
        cacheHeight: px,
        excludeFromSemantics: true,
        // Berkas hilang tidak boleh membuat baris melompat atau kotak merah
        // di rilis: tempatnya tetap terisi, hanya kosong.
        errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
      ),
    );
    // Kartu yang sudah datang lewat Reveal membawa ikonnya ikut masuk;
    // gerak kedua di dalamnya hanya membuat ikon tertinggal dari kartunya.
    if (context.findAncestorWidgetOfExactType<Reveal>() != null) return image;
    return Reveal(scale: true, child: image);
  }
}
