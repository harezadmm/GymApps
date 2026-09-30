/// Hitung pelat per sisi (FR-D16): "Bench 80 kg, bar 20 kg → 30 kg per sisi,
/// yaitu 25 + 5".
///
/// Orang yang berdiri di rak dengan tangan berkapur tidak mau menghitung
/// (80 − 20) ÷ 2 lalu memecahnya ke pelat yang ada di gym itu — apalagi dalam
/// lb, di mana 185 lb dengan bar 45 lb adalah 70 per sisi, yaitu 45 + 25.
///
/// Modul ini murni: tidak tahu satuan, tidak mengimpor Flutter maupun
/// setelan. Angkanya sudah dalam satuan tampilan (lihat `units.dart`), dan
/// bar serta daftar pelat datang dari setelan lewat pemanggil. Bawaan per
/// satuan ada di `units.dart`; pemetaan alat katalog → "dimuat pelat" ada di
/// bawah supaya bisa diuji tanpa memuat katalog 870 KB.
library;

/// Hasil satu hitungan pelat untuk satu beban total.
class PlateLoad {
  const PlateLoad({
    required this.perSide,
    required this.loaded,
    required this.remainder,
    this.barTooHeavy = false,
  });

  /// Pelat di satu sisi, terberat dulu. Satu ukuran boleh berulang
  /// (100 kg dengan bar 20 = 25 + 15, tapi 120 kg = 25 + 25).
  final List<double> perSide;

  /// Beban yang benar-benar terpasang: bar + 2 × jumlah [perSide]. Sama
  /// dengan total yang diminta kalau pelatnya cukup halus.
  final double loaded;

  /// Selisih total yang diminta dengan [loaded] — sisa yang tidak bisa
  /// dibangun dari pelat yang ada, dihitung untuk **dua sisi** (0,75 kg
  /// kalau 60,75 kg diminta dan pelat terkecil 1,25). Nol = pas.
  final double remainder;

  /// Total yang diminta lebih ringan dari bar kosong: tidak ada pelat yang
  /// bisa dipasang, dan [loaded] adalah bar itu sendiri.
  final bool barTooHeavy;

  /// Beban bisa dibangun persis dari pelat yang ada.
  bool get exact => remainder == 0 && !barTooHeavy;
}

/// Bulatkan ke 0,01 supaya 0,45 − 0,25 tidak jadi 0,19999999999999998 —
/// debu float seperti itu membuat pelat 0,2 berikutnya "tidak muat".
double _r(double v) {
  final out = (v * 100).roundToDouble() / 100;
  // −0,0 tertulis "-0" oleh toStringAsFixed; nol selalu nol positif di sini.
  return out == 0 ? 0.0 : out;
}

/// Pecah [total] menjadi pelat per sisi di atas [bar].
///
/// Serakah dari pelat terberat: itu cara orang memuat bar sungguhan (pelat
/// besar di dalam), dan untuk set pelat gym yang saling berkelipatan hasilnya
/// juga jumlah pelat paling sedikit. [available] boleh dalam urutan apa pun
/// dan boleh memuat duplikat; ukuran nol atau negatif diabaikan.
///
/// [bar] 0 berarti "tanpa bar" — Smith machine atau mesin berpelat (leg
/// press, hack squat): seluruh [total] dibagi dua ke kedua sisi. Total di
/// bawah bar mengembalikan daftar kosong dengan [PlateLoad.barTooHeavy].
PlateLoad plateLoad({required double total, required double bar, required List<double> available}) {
  final wantTotal = _r(total < 0 ? 0 : total);
  final barWeight = _r(bar < 0 ? 0 : bar);
  if (wantTotal < barWeight) {
    return PlateLoad(perSide: const [], loaded: barWeight, remainder: 0, barTooHeavy: true);
  }
  final plates = [
    for (final p in {for (final p in available) _r(p)})
      if (p > 0) p,
  ]..sort((a, b) => b.compareTo(a));

  var remaining = _r((wantTotal - barWeight) / 2);
  final perSide = <double>[];
  for (final p in plates) {
    // Toleransi sepersepuluh sen: sisa 1,25 harus menerima pelat 1,25 walau
    // pembulatan meninggalkan 1,2499999.
    while (remaining + 0.001 >= p) {
      perSide.add(p);
      remaining = _r(remaining - p);
    }
    if (remaining <= 0) break;
  }
  final loaded = _r(barWeight + 2 * perSide.fold(0.0, (a, p) => a + p));
  return PlateLoad(perSide: perSide, loaded: loaded, remainder: _r(wantTotal - loaded));
}

/// Nilai `eq` katalog yang bebannya dimuat dari pelat: keluarga barbel dan
/// mesin yang dimuat pelat. Dumbel, kabel, dan mesin selectorized tidak
/// punya arti "per sisi", jadi tidak masuk. Kunci-kuncinya persis seperti
/// di `assets/data/exercises.json`.
const plateLoadedEquipment = {
  'barbell',
  'olympic barbell',
  'ez barbell',
  'trap bar',
  'smith machine',
  'sled machine',
};

/// Alat berpelat yang tidak punya bar untuk dihitung: Smith machine (bar-nya
/// dikontra-bobot dan orang mencatat pelatnya saja) dan sled leg press /
/// hack squat. Bawaannya "tanpa bar"; yang Smith machine-nya berbobot bisa
/// menimpanya per gerakan lewat `ExerciseConfig.barWeight`.
const noBarEquipment = {'smith machine', 'sled machine'};

bool isPlateLoaded(String equipment) => plateLoadedEquipment.contains(equipment);

bool defaultsToNoBar(String equipment) => noBarEquipment.contains(equipment);

/// Bar yang berlaku untuk satu gerakan di sesi: override rutinitas menang,
/// lalu "tanpa bar" untuk alat yang memang tidak punya bar, lalu bar global
/// dari Profil — semuanya sudah dalam satuan tampilan.
double effectiveBar({required String equipment, double? override, required double globalBar}) =>
    override ?? (defaultsToNoBar(equipment) ? 0 : globalBar);
