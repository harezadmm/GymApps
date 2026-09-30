/// Estimasi 1RM — port Dart dari `reference/opengym/src/lib/onerm.js` (FR-E9).
///
/// Modul ini sengaja tidak tahu apa-apa soal database gerakan. Sebuah estimasi
/// butuh beban **dan** rep, dan hanya set mode `reps` yang punya keduanya. Set
/// cardio dan set berbasis waktu karena itu gugur sendiri di setiap pemindaian
/// di sini — tidak ada pengecekan tipe gerakan yang harus dijaga tetap sinkron.
///
/// Satu pengecualian yang tidak bisa dibaca dari set-nya: mesin assisted
/// (#232). Angkanya bantuan mesin, bukan beban yang diangkat, jadi "e1RM 40 kg
/// dari 30 × 8" adalah angka yang tidak berarti apa-apa — dan akan *naik* saat
/// orangnya makin lemah. Entri assisted tidak menghasilkan estimasi sama
/// sekali; arahnya dijawab target yang dibekukan atau [AssistedLookup] dari
/// pemanggil (lihat `assisted.dart`).
library;

import 'dart:math' as math;

import 'assisted.dart';
import 'models.dart';

/// Di atas sebanyak ini rep, estimasi lebih banyak bicara soal daya tahan
/// daripada kekuatan maksimal, dan ketiga rumus mulai berselisih dua digit.
/// Menolak menebak lebih baik daripada mencetak fantasi.
const repCap = 12;

enum OneRmFormula { epley, brzycki, lombardi }

const defaultFormula = OneRmFormula.epley;

double _apply(OneRmFormula f, double w, int r) => switch (f) {
      // Epley 1985 — w · (1 + r/30)
      OneRmFormula.epley => w * (1 + r / 30),
      // Brzycki 1993 — w · 36/(37 − r); tak terdefinisi di r ≥ 37, jauh di atas [repCap]
      OneRmFormula.brzycki => w * 36 / (37 - r),
      // Lombardi 1989 — w · r^0.10
      OneRmFormula.lombardi => w * math.pow(r, 0.1),
    };

/// Estimasi 1RM dari satu set.
///
/// Mengembalikan null untuk apa pun yang tidak bisa dijawab dengan jujur: beban
/// kosong/negatif, tanpa rep, atau rep di atas [repCap]. Satu rep bukan estimasi
/// — itu pengukuran — dan dikembalikan apa adanya.
double? estimate1RM(double w, num r, [OneRmFormula formula = defaultFormula]) {
  if (!w.isFinite || !r.isFinite) return null;
  if (w <= 0 || r < 1) return null;
  if (r > repCap) return null;
  final est = r == 1 ? w : _apply(formula, w, r.round());
  if (!est.isFinite || est <= 0) return null;
  return (est * 10).round() / 10;
}

/// Satu set terbaik, dengan beban dan rep asalnya.
class BestSet {
  const BestSet({required this.est, required this.weight, required this.reps, this.date});

  /// Estimasi 1RM-nya.
  final double est;

  /// Beban dan rep yang menghasilkannya. Ikut dibawa karena sumbernya penting:
  /// "142,5 kg dari 100×10" klaim yang sangat berbeda dari "dari 140×1".
  final double weight;
  final int reps;

  final String? date;
}

/// Estimasi terbaik dari set-set tercentang di satu entry. null untuk mesin
/// assisted (#232): tidak ada estimasi yang jujur dari angka bantuan.
BestSet? bestSetOf(WorkoutEntry entry, {OneRmFormula formula = defaultFormula, AssistedLookup? isAssisted}) {
  if (entryIsAssisted(entry, isAssisted)) return null;
  BestSet? best;
  for (final s in entry.sets) {
    if (!s.done || s.isWarmup) continue;
    final est = estimate1RM(s.weight, s.reps, formula);
    if (est == null) continue;
    if (best == null || est > best.est) {
      best = BestSet(est: est, weight: s.weight, reps: s.reps);
    }
  }
  return best;
}

/// Satu titik per sesi yang menghasilkan estimasi — bahan grafik tren.
/// Kronologis, mengikuti urutan sesi ditambahkan. Sesi assisted tidak
/// menyumbang titik (#232).
List<BestSet> e1rmSeries(List<Workout> workouts, String exerciseId,
    {OneRmFormula formula = defaultFormula, AssistedLookup? isAssisted}) {
  final pts = <BestSet>[];
  for (final w in workouts) {
    for (final entry in w.entries) {
      if (entry.exerciseId != exerciseId) continue;
      final best = bestSetOf(entry, formula: formula, isAssisted: isAssisted);
      if (best != null) {
        pts.add(BestSet(est: best.est, weight: best.weight, reps: best.reps, date: w.date));
      }
      break;
    }
  }
  return pts;
}

/// Estimasi terbaik sepanjang masa untuk satu gerakan.
BestSet? best1RM(List<Workout> workouts, String exerciseId,
    {OneRmFormula formula = defaultFormula, AssistedLookup? isAssisted}) {
  BestSet? best;
  for (final p in e1rmSeries(workouts, exerciseId, formula: formula, isAssisted: isAssisted)) {
    if (best == null || p.est > best.est) best = p;
  }
  return best;
}

/// Rekor 1RM yang baru dipecahkan, kalau ada.
class OneRmRecord {
  const OneRmRecord({required this.now, required this.previous});
  final BestSet now;

  /// Rekor sebelumnya, null kalau ini yang pertama.
  final double? previous;
}

/// Apakah sesi ini mengalahkan semua estimasi sebelumnya?
///
/// Dipakai ringkasan setelah selesai, jadi [workouts] harus riwayat yang
/// **belum** memuat sesi berjalan — kalau tidak, ia akan selalu kalah oleh
/// dirinya sendiri.
OneRmRecord? is1RMRecord(
  List<Workout> workouts,
  String exerciseId,
  WorkoutEntry entry, {
  OneRmFormula formula = defaultFormula,
  AssistedLookup? isAssisted,
}) {
  final now = bestSetOf(entry, formula: formula, isAssisted: isAssisted);
  if (now == null) return null;
  final prev = best1RM(workouts, exerciseId, formula: formula, isAssisted: isAssisted);
  if (prev != null && now.est <= prev.est) return null;
  return OneRmRecord(now: now, previous: prev?.est);
}
