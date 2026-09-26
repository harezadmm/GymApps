/// Menampilkan beban tersimpan (kg) dalam satuan pilihan.
///
/// Dipakai di layar yang membaca data dari store: riwayat, statistik, Home,
/// editor rutinitas. Layar sesi tidak memakainya, karena angkanya sudah dalam
/// satuan tampilan (lihat `domain/units.dart`).
library;

import 'package:flutter/widgets.dart';

import '../data/workout_store.dart';
import '../domain/units.dart';
import 'format.dart';

extension WeightTextX on BuildContext {
  /// Satuan pilihan. kg kalau layar ini tidak berada di bawah store (test).
  WeightUnit get unit =>
      dependOnInheritedWidgetOfExactType<WorkoutScope>()?.notifier?.settings.unit ?? WeightUnit.kg;

  /// "kg" atau "lb".
  String get unitLabel => unit.label;

  /// kg tersimpan → angka tampilan: `72.5`, `160`, `BW` untuk nol.
  String w(double kg) => formatWeight(shown(kg, unit));

  /// Seperti [w] tapi nol tetap `0` — untuk selisih dan rekor.
  String wDelta(double kg) => formatDelta(shown(kg, unit));

  /// kg tersimpan → `72.5 kg` / `160 lb`.
  String wUnit(double kg) => '${w(kg)} $unitLabel';

  /// `—` untuk gerakan berbeban yang belum diisi, `BW` untuk bodyweight.
  String wLabel(double kg, {required bool bodyweight}) => weightLabel(shown(kg, unit), bodyweight: bodyweight);

  /// Volume tersimpan (kg × rep) → "1.2 t" / "2.6k lb".
  String volume(double kgVolume) => volumeText(kgTo(kgVolume, unit), unit);

  /// Angka yang diketik dalam satuan tampilan → kg untuk disimpan.
  double typedToKg(double v) => toKg(v, unit);
}
