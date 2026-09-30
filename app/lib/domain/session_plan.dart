/// Menyusun baris-baris sesi dari konfigurasi rutinitas dan riwayat (FR-D1,
/// FR-D2, FR-E2).
///
/// Ini jembatan antara mesin progresi dan layar sesi: prescription bilang
/// "72.5 kg × 8", fungsi ini mengubahnya jadi baris set yang sudah terisi, plus
/// kolom PREV dari sesi terakhir gerakan itu.
library;

import 'dart:math' as math;

import '../core/format.dart';
import 'models.dart';
import 'progression.dart';

/// Satu gerakan yang siap dibuka di layar sesi.
class PlannedExercise {
  const PlannedExercise({
    required this.target,
    required this.sets,
    required this.previous,
    required this.prescription,
  });

  /// Target yang dibekukan ke dalam sesi dan disimpan bersama entri-nya.
  /// Dibaca ulang oleh [readSession] untuk menilai sesi ini nanti.
  final ExerciseConfig target;

  final List<SetRow> sets;

  /// Teks kolom PREV per baris, sejajar dengan [sets].
  final List<String> previous;

  final Prescription prescription;
}

/// Entri terbaru untuk satu gerakan yang punya set kerja tercentang.
///
/// [history] harus urut **terlama dulu**, sama seperti yang diminta
/// [nextPrescription].
WorkoutEntry? lastEntryFor(List<Workout> history, String exerciseId) {
  for (var i = history.length - 1; i >= 0; i--) {
    for (final e in history[i].entries) {
      if (e.exerciseId == exerciseId && e.sets.any((s) => s.done && !s.isWarmup)) return e;
    }
  }
  return null;
}

String _prevText(SetRow s, LogMode mode) {
  if (!s.done) return '—';
  if (mode == LogMode.time) return '${s.seconds}s';
  return '${formatWeight(s.weight)} × ${s.reps}';
}

/// Susun satu gerakan untuk sesi baru.
///
/// [history] urut terlama dulu. [routines] dipakai untuk mengenali rutinitas
/// deload (FR-B10): target dihitung hanya dari sesi yang lolos
/// [progressionHistory], sedangkan kolom PREV dan catatan tetap membaca
/// [history] utuh — "sesi lalu" adalah fakta, bukan target.
PlannedExercise planExercise(
  ExerciseConfig cfg,
  List<Workout> history, {
  ProgressionPolicy? routineDefault,
  String unit = 'kg',
  List<Routine> routines = const [],
}) {
  final eligible = progressionHistory(history, routines);
  final p = nextPrescription(workouts: eligible, cfg: cfg, routineDefault: routineDefault, unit: unit);
  final policy = p.policy;

  final weight = p.weight ?? cfg.weight;
  final setCount = math.max(1, p.sets ?? cfg.sets);

  // Double progression dan HIT menilai terhadap rep range di konfigurasi —
  // targetnya harus tetap membawa batas atas range, bukan rep yang sedang
  // dipanjat. Policy lain memang menilai terhadap rep yang diminta sesi itu.
  final rangeBased = policy == ProgressionPolicy.double_ || policy == ProgressionPolicy.hit;
  final firstClimb =
      p.kind == PrescriptionKind.first && rangeBased && cfg.repsMin != null ? cfg.repsMin! : cfg.reps;
  final rowReps = p.reps ?? firstClimb;
  final storedReps = rangeBased ? cfg.reps : (p.reps ?? cfg.reps);
  final seconds = p.seconds ?? cfg.seconds;

  final inc = cfg.mode == LogMode.time ? 0.0 : weightIncrement(cfg, unit);
  final warmups = <SetRow>[
    for (var i = 0; i < cfg.warmupSets; i++)
      SetRow(
        phase: SetPhase.warmup,
        // 50 % lalu 75 %: ramp yang cukup untuk satu set ke failure tanpa
        // menghabiskan tenaganya duluan.
        weight: weight <= 0 ? 0 : snapWeight(weight * (0.5 + 0.25 * i), inc > 0 ? inc : 2.5),
        reps: i == 0 ? 8 : 5,
      ),
  ];
  final last = lastEntryFor(history, cfg.exerciseId);
  final lastWarm = last?.sets.where((s) => s.isWarmup).toList() ?? const <SetRow>[];
  final lastWork = last?.sets.where((s) => s.isWork).toList() ?? const <SetRow>[];
  // Tangga beban mengikuti keputusan progresi, jadi bentuknya diambil dari
  // sesi terakhir yang *dinilai* — bukan dari sesi deload yang lebih ringan,
  // yang akan menggeser seluruh tangga dari titik yang salah.
  final judged = identical(eligible, history) ? last : lastEntryFor(eligible, cfg.exerciseId);
  final judgedWork = judged?.sets.where((s) => s.isWork).toList() ?? const <SetRow>[];
  final ramp = cfg.mode == LogMode.reps ? rampWeights(judgedWork, p, setCount, inc) : null;

  final work = <SetRow>[
    for (var i = 0; i < setCount; i++)
      SetRow(
        weight: ramp?[i] ?? weight,
        reps: cfg.mode == LogMode.time ? 0 : rowReps,
        seconds: cfg.mode == LogMode.time ? seconds : 0,
      ),
  ];

  // PREV: warm-up dipasangkan dengan warm-up sesi lalu, set kerja dengan set
  // kerja — kalau tidak, warm-up sesi lalu tampil di baris set kerja pertama.
  final previous = <String>[
    for (var i = 0; i < warmups.length; i++) i < lastWarm.length ? _prevText(lastWarm[i], cfg.mode) : '—',
    for (var i = 0; i < work.length; i++) i < lastWork.length ? _prevText(lastWork[i], cfg.mode) : '—',
  ];

  return PlannedExercise(
    // Policy yang berlaku ikut dibekukan: tanpa itu, kartu sesi dan ringkasan
    // yang membaca target ini jatuh ke default mode (linear) meski rutinitasnya
    // memakai double progression.
    target: cfg.copyWith(weight: weight, reps: storedReps, seconds: seconds, sets: setCount, policy: policy),
    sets: [...warmups, ...work],
    previous: previous,
    prescription: p,
  );
}

/// Beban per set untuk sesi berikutnya kalau sesi lalu berbentuk tangga
/// (30 → 50 → 55), atau null kalau semua setnya sama berat.
///
/// Mesin progresi berpikir dalam satu angka — beban puncak sesi lalu — dan
/// dulu angka itu dipasang ke semua set. Tangga 30/50/55 lalu terbuka sebagai
/// 55/55/55: set pertama melompat 25 kg tanpa alasan apa pun. Di sini bentuk
/// tangganya dipertahankan dan seluruh tangga digeser mengikuti keputusan
/// progresi: naik = tiap set naik selangkah yang sama, tahan = sama persis,
/// deload = tiap set turun dengan faktor yang sama.
///
/// Set yang tidak dicentang, atau set tambahan di luar jumlah sesi lalu,
/// memakai beban puncak yang diresepkan.
List<double>? rampWeights(List<SetRow> lastWork, Prescription p, int setCount, double inc) {
  final next = p.weight;
  if (next == null || next <= 0) return null;
  if (p.kind != PrescriptionKind.up && p.kind != PrescriptionKind.hold && p.kind != PrescriptionKind.deload) {
    return null;
  }
  final done = [for (final s in lastWork) if (s.done && s.weight > 0) s.weight];
  if (done.length < 2 || done.toSet().length < 2) return null;
  final top = done.reduce(math.max);
  double shift(double base) => switch (p.kind) {
        PrescriptionKind.up => addStep(base, next - top, inc > 0 ? inc : 2.5),
        PrescriptionKind.deload => math.max(inc > 0 ? inc : 0, snapWeight(base * next / top, inc)),
        _ => base,
      };
  return [
    for (var i = 0; i < setCount; i++)
      i < lastWork.length && lastWork[i].done && lastWork[i].weight > 0 ? shift(lastWork[i].weight) : next,
  ];
}
