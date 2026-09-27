/// Ilustrasi IconScout (Nataliia Nesterenko) untuk kartu hero, layar masuk,
/// onboarding, dan layar kosong. Sumber dan lisensinya di
/// `design/iconscout/SOURCES.md`.
///
/// Semuanya figur potongan tanpa latar, seperti figur di kartu "Body yoga"
/// referensi; latarnya lingkaran aksen yang digambar aplikasi ([blob]) supaya
/// ikut warna aksen dan tema.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

enum GymArt {
  heroLift('hero_lift'),
  liftOverhead('lift_overhead'),
  liftBarbell('lift_barbell'),
  planWorkout('plan_workout'),
  emptyHistory('empty_history'),
  emptyStats('empty_stats');

  const GymArt(this.file);
  final String file;

  String get asset => 'assets/illustrations/$file.svg';
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
    final picture = SvgPicture.asset(art.asset, fit: BoxFit.contain);
    // Ilustrasi hiasan: pembaca layar cukup membaca judul di sebelahnya.
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: blob
            ? Stack(
                alignment: Alignment.center,
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
