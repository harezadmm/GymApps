/// Ilustrasi IconScout untuk kartu hero, layar masuk, onboarding, dan layar
/// kosong. Sumber dan lisensinya di `design/iconscout/SOURCES.md`.
///
/// Satu tokoh 3D dari satu paket ("Fitness Character", Mintemid) dalam
/// beberapa pose, supaya semua layar terasa satu keluarga — dan terasa satu
/// keluarga juga dengan ikon 3D di ubin Beranda. Figur datar sebelumnya
/// (dua set berturut-turut) ditolak pemakai karena terasa kaku dan asing.
///
/// Pakaiannya abu-abu dan navy, jadi tenang di tema gelap maupun terang;
/// latarnya lingkaran aksen yang digambar aplikasi ([GymIllustration.blob])
/// supaya ikut warna aksen dan tema. Berkasnya WebP transparan 600 px tinggi,
/// sudah dipotong rapat ke isinya.
library;

import 'package:flutter/material.dart';

import 'decode_size.dart';
import 'theme.dart';

enum GymArt {
  /// Squat dengan barbel — kartu sesi berikutnya di Beranda.
  heroLift('hero_lift', 442 / 600),

  /// Barbel di atas kepala — layar masuk.
  liftOverhead('lift_overhead', 339 / 600),

  /// Dua dumbbell diangkat — layar daftar.
  liftBarbell('lift_barbell', 306 / 600),

  /// Berdiri siap dengan dua dumbbell — pilih program.
  planWorkout('plan_workout', 242 / 600),

  /// Santai dengan botol minum — riwayat masih kosong.
  emptyHistory('empty_history', 178 / 600),

  /// Lunge dengan dumbbell — statistik belum ada; terus latihan.
  emptyStats('empty_stats', 603 / 600);

  const GymArt(this.file, this.aspect);
  final String file;

  /// Lebar ÷ tinggi berkasnya (dicek di test). Figur berdiri ramping sekali,
  /// dan kotak yang hanya selebar figurnya memotong lingkaran aksen di
  /// belakangnya jadi kapsul sempit.
  final double aspect;

  String get asset => 'assets/illustrations/$file.webp';

  /// Tinggi berkas sumber dalam piksel. Mendekode lebih besar hanya
  /// memperbesar piksel yang sama sambil memakan memori.
  static const sourceHeight = 600;
}

class GymIllustration extends StatelessWidget {
  const GymIllustration(this.art, {super.key, this.height = 160, this.blob = false});

  final GymArt art;
  final double height;

  /// Lingkaran aksen tipis di belakang figur, sedikit ke bawah.
  final bool blob;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    // Dekode seukuran tampilan: 150 dp di HP 3× cukup 450 px, bukan seluruh
    // berkas untuk setiap layar. Di web null — lihat [decodePx].
    final px = decodePx(height, MediaQuery.devicePixelRatioOf(context), GymArt.sourceHeight);
    final picture = Image.asset(
      art.asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      cacheHeight: px,
      excludeFromSemantics: true,
      // Berkas hilang tidak boleh membuat kotak merah atau tata letak
      // melompat: tempatnya tetap terisi, hanya kosong.
      errorBuilder: (_, _, _) => SizedBox(height: height, width: height * art.aspect),
    );
    // Lingkaran 0,78 × tinggi harus muat utuh, termasuk di belakang figur
    // yang lebih ramping dari lingkarannya.
    final width = blob ? (height * art.aspect).clamp(height * 0.86, double.infinity) : height * art.aspect;
    // Ilustrasi hiasan: pembaca layar cukup membaca judul di sebelahnya.
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: width,
        child: blob
            ? Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    bottom: height * 0.02,
                    child: Container(
                      width: height * 0.78,
                      height: height * 0.78,
                      decoration: BoxDecoration(color: c.tint(c.accent), shape: BoxShape.circle),
                    ),
                  ),
                  picture,
                ],
              )
            : picture,
      ),
    );
  }
}

/// Layar kosong: ilustrasi, judul, dan satu kalimat yang bilang harus apa.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.art, required this.title, required this.body, this.height = 150});

  final GymArt art;
  final String title;
  final String body;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(
        children: [
          GymIllustration(art, height: height, blob: true),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.4, color: c.text2)),
        ],
      ),
    );
  }
}
