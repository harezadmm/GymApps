/// Satuan beban: kg atau lb.
///
/// **Semua beban disimpan dalam kg**, apa pun satuan yang dipilih. Riwayat,
/// rutinitas, dan berat badan tidak pernah ditulis ulang saat satuan diganti:
/// menulis ulang riwayat berarti mengubah isi setiap sesi, dan penggabung
/// sinkron (yang mengenali sesi dari isinya) akan melihatnya sebagai sesi baru
/// di HP lain.
///
/// Yang berganti hanya cara angka ditampilkan dan dibaca — dan sesi yang
/// sedang berjalan. Sesi dihitung dalam satuan tampilan supaya engine progresi
/// memakai lompatan pelat yang benar (5/10 lb, bukan 2,5 kg yang jadi 5,51 lb),
/// lalu dikonversi balik ke kg saat disimpan. Konversi baliknya tidak
/// dibulatkan, jadi 135 lb tetap 135 lb saat dibaca lagi.
library;

import 'models.dart';

enum WeightUnit {
  kg,
  lb;

  String get label => name;

  static WeightUnit parse(Object? v) => v == 'lb' ? WeightUnit.lb : WeightUnit.kg;
}

/// Definisi internasional pound (1959).
const kgPerLb = 0.45359237;

/// kg → satuan [u], tanpa pembulatan.
double kgTo(double kg, WeightUnit u) => u == WeightUnit.kg ? kg : kg / kgPerLb;

/// Satuan [u] → kg, tanpa pembulatan.
double toKg(double v, WeightUnit u) => u == WeightUnit.kg ? v : v * kgPerLb;

double _round(double v, int per) => (v * per).roundToDouble() / per;

/// kg → angka yang ditampilkan: 0,01 kg atau 0,1 lb. Cukup untuk 1,25 kg
/// microplate dan untuk mengembalikan 135 lb yang disimpan sebagai 61,23 kg
/// jadi tepat 135.
double shown(double kg, WeightUnit u) => u == WeightUnit.kg ? _round(kg, 100) : _round(kg / kgPerLb, 10);

/// Pengubah beban satu arah untuk seluruh struktur data.
typedef _Scale = double Function(double);

SetRow _set(SetRow s, _Scale f) => s.weight == 0 ? s : s.copyWith(weight: f(s.weight));

ExerciseConfig _config(ExerciseConfig c, _Scale f) => c.copyWith(
      weight: c.weight == 0 ? 0 : f(c.weight),
      increment: c.increment == null ? null : f(c.increment!),
    );

WorkoutEntry _entry(WorkoutEntry e, _Scale f) => WorkoutEntry(
      exerciseId: e.exerciseId,
      sets: [for (final s in e.sets) _set(s, f)],
      target: e.target == null ? null : _config(e.target!, f),
      excluded: e.excluded,
      note: e.note,
    );

Workout _workout(Workout w, _Scale f) => w.copyWith(entries: [for (final e in w.entries) _entry(e, f)]);

/// Riwayat dalam satuan tampilan, untuk engine progresi dan layar sesi.
/// Dibulatkan ke 0,01 supaya 135 lb yang tersimpan sebagai kg kembali 135,
/// bukan 134,99999, dan tetap duduk di grid pelat 5 lb.
List<Workout> historyIn(List<Workout> kgHistory, WeightUnit u) {
  if (u == WeightUnit.kg) return kgHistory;
  double f(double kg) => _round(kgTo(kg, u), 100);
  return [for (final w in kgHistory) _workout(w, f)];
}

/// Konfigurasi rutinitas (kg) → satuan tampilan.
ExerciseConfig configIn(ExerciseConfig kgConfig, WeightUnit u) =>
    u == WeightUnit.kg ? kgConfig : _config(kgConfig, (kg) => _round(kgTo(kg, u), 100));

/// Konfigurasi dalam satuan tampilan → kg untuk disimpan.
ExerciseConfig configToKg(ExerciseConfig c, WeightUnit u) =>
    u == WeightUnit.kg ? c : _config(c, (v) => toKg(v, u));

/// Set dalam satuan [from] → satuan [to]. Untuk draft sesi yang dipulihkan
/// setelah satuannya diganti.
SetRow setBetween(SetRow s, WeightUnit from, WeightUnit to) =>
    from == to ? s : _set(s, (v) => _round(kgTo(toKg(v, from), to), 100));

ExerciseConfig configBetween(ExerciseConfig c, WeightUnit from, WeightUnit to) =>
    from == to ? c : _config(c, (v) => _round(kgTo(toKg(v, from), to), 100));

/// Sesi yang dicatat dalam satuan tampilan → kg untuk disimpan.
Workout workoutToKg(Workout w, WeightUnit u) => u == WeightUnit.kg ? w : _workout(w, (v) => toKg(v, u));

/// Volume (beban × rep) dalam satuan tampilan sebagai teks: "1.2 t" untuk kg,
/// "2.6k lb" untuk lb. Ton metrik tidak lazim di kalangan pemakai pound.
String volumeText(double volume, WeightUnit u) =>
    u == WeightUnit.kg ? '${(volume / 1000).toStringAsFixed(1)} t' : '${(volume / 1000).toStringAsFixed(1)}k lb';
