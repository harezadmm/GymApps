/// Angka untuk tab Stats, dihitung dari riwayat (FR-F2, FR-F3).
///
/// Menggantikan angka contoh yang dulu dipaku di layar: set mingguan, hari
/// sejak tiap region dilatih, tren e1RM, dan kekuatan per gerakan. Semua fungsi
/// di sini murni — riwayat dan "hari ini" masuk, angka keluar.
library;

import '../data/exercise_catalog.dart';
import 'assisted.dart';
import 'models.dart';
import 'muscle_volume.dart';
import 'onerm.dart';
import 'program.dart';
import 'settings.dart';
import 'units.dart';

DateTime? _date(Workout w) => DateTime.tryParse(w.date);

/// Set kerja tercentang per minggu, [weeks] minggu terakhir, terlama dulu.
/// Minggu terakhir berakhir hari ini.
List<double> weeklyWorkingSets(List<Workout> history, DateTime today, {int weeks = 8}) {
  final end = dateOnly(today).add(const Duration(days: 1));
  final out = List<double>.filled(weeks, 0);
  for (final w in history) {
    final d = _date(w);
    if (d == null || !d.isBefore(end)) continue;
    final ago = end.difference(d).inDays ~/ 7;
    if (ago >= weeks) continue;
    final sets = w.entries.expand((e) => e.sets).where((s) => s.done && !s.isWarmup).length;
    out[weeks - 1 - ago] += sets;
  }
  return out;
}

/// Hari sejak tiap region terakhir dilatih. null = belum pernah.
Map<String, int?> daysSinceRegion(List<Workout> history, ExerciseCatalog catalog, DateTime today) {
  final day = dateOnly(today);
  final last = <String, DateTime>{};
  for (final w in history) {
    final d = _date(w);
    if (d == null) continue;
    for (final e in w.entries) {
      if (!e.sets.any((s) => s.done && !s.isWarmup)) continue;
      final ex = catalog.byId(e.exerciseId);
      final g = ex == null ? null : muscleGroupFor(ex.target);
      if (g == null) continue;
      for (final region in regionMuscles.entries) {
        if (!region.value.contains(g)) continue;
        final prev = last[region.key];
        if (prev == null || d.isAfter(prev)) last[region.key] = d;
      }
    }
  }
  return {
    for (final r in regionMuscles.keys) r: last[r] == null ? null : day.difference(dateOnly(last[r]!)).inDays,
  };
}

/// Gerakan yang paling sering dicatat, terbanyak dulu.
List<String> loggedExercises(List<Workout> history) {
  final count = <String, int>{};
  for (final w in history) {
    for (final e in w.entries) {
      if (e.sets.any((s) => s.done && !s.isWarmup)) count[e.exerciseId] = (count[e.exerciseId] ?? 0) + 1;
    }
  }
  final ids = count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
  return ids;
}

/// e1RM terbaik per minggu untuk satu gerakan, [weeks] minggu, terlama dulu.
/// Minggu tanpa sesi membawa nilai minggu sebelumnya, supaya grafiknya
/// menunjukkan kekuatan, bukan jadwal latihan. Sesi mesin assisted tidak
/// menyumbang angka (#232) — [isAssisted] menjawab untuk riwayat yang
/// targetnya belum menyimpan arah.
List<double> weeklyE1rm(List<Workout> history, String exerciseId, DateTime today,
    {int weeks = 12, AssistedLookup? isAssisted}) {
  final end = dateOnly(today).add(const Duration(days: 1));
  final best = List<double?>.filled(weeks, null);
  double? before;
  for (final w in history) {
    final d = _date(w);
    if (d == null || !d.isBefore(end)) continue;
    for (final e in w.entries) {
      if (e.exerciseId != exerciseId) continue;
      final b = bestSetOf(e, isAssisted: isAssisted)?.est;
      if (b == null) continue;
      final ago = end.difference(d).inDays ~/ 7;
      if (ago >= weeks) {
        if (before == null || b > before) before = b;
        continue;
      }
      final i = weeks - 1 - ago;
      if (best[i] == null || b > best[i]!) best[i] = b;
    }
  }
  final out = <double>[];
  var carry = before ?? 0;
  for (final v in best) {
    if (v != null) carry = v;
    out.add(carry);
  }
  return out;
}

/// Satu baris "kekuatan per gerakan": e1RM terbaik dan perubahannya dalam
/// [window] hari terakhir.
class MovementStrength {
  const MovementStrength({required this.exerciseId, required this.best, required this.delta});
  final String exerciseId;
  final double best;

  /// Selisih terhadap e1RM terbaik sebelum jendela. 0 kalau belum ada
  /// pembanding.
  final double delta;
}

/// Gerakan assisted tidak masuk daftar (#232): tanpa e1RM tidak ada
/// "kekuatan" yang bisa diurutkan.
List<MovementStrength> strengthByMovement(List<Workout> history, DateTime today,
    {int count = 4, int window = 28, AssistedLookup? isAssisted}) {
  final cutoff = dateOnly(today).subtract(Duration(days: window));
  final older = [for (final w in history) if ((_date(w) ?? today).isBefore(cutoff)) w];
  final out = <MovementStrength>[];
  for (final id in loggedExercises(history)) {
    final now = best1RM(history, id, isAssisted: isAssisted)?.est;
    if (now == null) continue;
    final then = best1RM(older, id, isAssisted: isAssisted)?.est;
    out.add(MovementStrength(exerciseId: id, best: now, delta: then == null ? 0 : now - then));
  }
  out.sort((a, b) => b.best.compareTo(a.best));
  return out.take(count).toList();
}

// ── Berat badan dan target (FR-F4) ─────────────────────────────────────────

/// Arah dua catatan berat badan terakhir terhadap target.
enum TargetHeading { toward, away }

/// Jarak berat badan terakhir ke targetnya, dalam satuan tampilan — bahan
/// untuk "3.4 kg to go" dan warna batang terakhir di kartu berat badan.
class TargetGap {
  const TargetGap({required this.toGo, required this.onTarget, required this.heading, required this.delta});

  /// Sisa ke target, selalu ≥ 0, dibulatkan seperti angka tampilan lain
  /// (0,01 kg / 0,1 lb) supaya "3.4 kg" di layar dan angka di sini sama.
  final double toGo;

  /// Dalam setengah satuan tampilan dari target — 0,5 kg atau 0,5 lb. Lebih
  /// rapat dari itu bukan tren lagi, itu selisih timbangan pagi dan sore.
  final bool onTarget;

  /// Mendekat atau menjauh menurut dua catatan terakhir. null kalau baru
  /// satu catatan, atau keduanya sama jauhnya dari target (tidak bergerak).
  final TargetHeading? heading;

  /// Catatan terakhir dikurangi sebelumnya, satuan tampilan, bertanda; null
  /// kalau baru satu catatan. Untuk panah naik/turun di samping angkanya.
  final double? delta;
}

/// Pembulatan ke presisi tampilan [u]: selisih dua angka yang sudah dibulatkan
/// masih bisa membawa debu float (78,4 − 75 = 3,3999…).
double _tidy(double v, WeightUnit u) {
  final per = u == WeightUnit.kg ? 100 : 10;
  return (v * per).roundToDouble() / per;
}

/// [TargetGap] untuk [log] (kg, terlama dulu) terhadap [targetKg], dibaca
/// dalam [unit]. null kalau belum ada catatan: tanpa berat, tidak ada jarak.
///
/// Semua dihitung dari angka yang *ditampilkan* ([shown]), bukan kg mentah:
/// dua catatan yang tampil sama tidak boleh diwarnai "mendekat" karena
/// selisih 0,003 kg sisa konversi dari lb.
TargetGap? bodyweightGap(List<BodyweightEntry> log, double targetKg, WeightUnit unit) {
  if (log.isEmpty) return null;
  final target = shown(targetKg, unit);
  final last = shown(log.last.kg, unit);
  final toGo = _tidy((last - target).abs(), unit);
  TargetHeading? heading;
  double? delta;
  if (log.length >= 2) {
    final prev = shown(log[log.length - 2].kg, unit);
    delta = _tidy(last - prev, unit);
    final before = _tidy((prev - target).abs(), unit);
    // Keduanya sudah dibulatkan ke presisi yang sama, jadi perbandingannya
    // persis: sama jauh = tidak bergerak, bukan "mendekat 0,000001".
    if (toGo < before) {
      heading = TargetHeading.toward;
    } else if (toGo > before) {
      heading = TargetHeading.away;
    }
  }
  return TargetGap(toGo: toGo, onTarget: toGo <= 0.5, heading: heading, delta: delta);
}
