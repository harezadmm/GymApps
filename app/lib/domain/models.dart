/// Bentuk data latihan, di-port dari `reference/opengym/src/lib/workout-model.js`.
///
/// Nama field sengaja dipertahankan sependek aslinya (`w`, `r`, `sec`) di lapisan
/// JSON: dokumen `S` yang disimpan di Supabase harus tetap kompatibel dengan
/// ekspor/impor openGym (NFR-10). Di Dart namanya dieja penuh.
library;

/// Fase satu baris set. Warm-up tidak pernah ikut dihitung untuk progresi,
/// 1RM, maupun fatigue (FR-D6).
enum SetPhase { work, warmup }

/// Bagaimana satu gerakan diukur. `reps` beban×rep, `time` detik (plank, hang),
/// `cardio` menit+kecepatan.
enum LogMode { reps, time, cardio }

/// Satu baris di tabel `SET | PREV | KG | REPS | ✓`.
class SetRow {
  const SetRow({
    this.weight = 0,
    this.reps = 0,
    this.seconds = 0,
    this.done = false,
    this.phase = SetPhase.work,
    this.rir,
  });

  final double weight;
  final int reps;
  final int seconds;

  /// Tercentang. Set yang tidak dicentang dibaca sebagai **nol rep**, bukan
  /// diabaikan — itu yang membuat FR-E3 ("sesi gagal tidak pernah menaikkan
  /// beban") jalan tanpa aturan tambahan.
  final bool done;

  final SetPhase phase;
  final int? rir;

  bool get isWarmup => phase == SetPhase.warmup;

  SetRow copyWith({double? weight, int? reps, int? seconds, bool? done, SetPhase? phase, int? rir}) {
    return SetRow(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      seconds: seconds ?? this.seconds,
      done: done ?? this.done,
      phase: phase ?? this.phase,
      rir: rir ?? this.rir,
    );
  }

  Map<String, dynamic> toJson() => {
        'w': weight,
        'r': reps,
        if (seconds > 0) 'sec': seconds,
        'done': done,
        if (phase == SetPhase.warmup) 'phase': 'warmup',
        if (rir != null) 'rir': rir,
      };

  factory SetRow.fromJson(Map<String, dynamic> j) => SetRow(
        weight: (j['w'] as num?)?.toDouble() ?? 0,
        reps: (j['r'] as num?)?.toInt() ?? 0,
        seconds: (j['sec'] as num?)?.toInt() ?? 0,
        done: j['done'] == true,
        // Riwayat lama memakai boolean `warmup`; `phase` menang kalau ada.
        phase: (j['phase'] == 'warmup' || j['warmup'] == true) ? SetPhase.warmup : SetPhase.work,
        rir: (j['rir'] as num?)?.toInt(),
      );
}

/// Konfigurasi satu gerakan di dalam rutinitas — sekaligus target yang dibekukan
/// ke dalam sesi saat sesi dibuat. Dibekukan supaya edit rutinitas belakangan
/// tidak menulis ulang penilaian sesi yang sudah lewat.
class ExerciseConfig {
  const ExerciseConfig({
    required this.exerciseId,
    this.policy,
    this.mode = LogMode.reps,
    this.sets = 3,
    this.reps = 10,
    this.repsMin,
    this.repsMax,
    this.weight = 0,
    this.seconds = 0,
    this.increment,
    this.restSeconds,
    this.deloadFactor,
    this.bodyweight = false,
    this.heavyBodyPart = false,
  });

  final String exerciseId;

  /// null = pakai default rutinitas, lalu default mode (lihat [policyFor]).
  final ProgressionPolicy? policy;

  final LogMode mode;
  final int sets;

  /// Batas atas rep range. Untuk double progression, pasangannya [repsMin].
  final int reps;
  final int? repsMin;

  /// Plafon rep untuk kerja bodyweight — di atas ini tambah set, bukan rep.
  final int? repsMax;

  final double weight;
  final int seconds;

  /// Kelipatan beban gerakan ini. null = pakai [defaultIncrementFor].
  final double? increment;

  final int? restSeconds;
  final double? deloadFactor;
  final bool bodyweight;

  /// Tubuh bawah/punggung: lompatan 5 kg normal, bukan brutal.
  final bool heavyBodyPart;

  ExerciseConfig copyWith({
    ProgressionPolicy? policy,
    int? sets,
    int? reps,
    int? repsMin,
    double? weight,
    int? seconds,
    double? increment,
    int? restSeconds,
    double? deloadFactor,
  }) {
    return ExerciseConfig(
      exerciseId: exerciseId,
      policy: policy ?? this.policy,
      mode: mode,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      repsMin: repsMin ?? this.repsMin,
      repsMax: repsMax,
      weight: weight ?? this.weight,
      seconds: seconds ?? this.seconds,
      increment: increment ?? this.increment,
      restSeconds: restSeconds ?? this.restSeconds,
      deloadFactor: deloadFactor ?? this.deloadFactor,
      bodyweight: bodyweight,
      heavyBodyPart: heavyBodyPart,
    );
  }
}

/// Satu gerakan di dalam satu sesi yang sudah selesai.
class WorkoutEntry {
  const WorkoutEntry({required this.exerciseId, required this.sets, this.target, this.excluded = false});

  final String exerciseId;
  final List<SetRow> sets;

  /// Target yang berlaku saat sesi itu berjalan. null untuk riwayat lama —
  /// penilainya jatuh ke konfigurasi gerakan saat ini (lihat [readSession]).
  final ExerciseConfig? target;

  /// Rutinitas deload ditandai "excluded from progression" (FR-B10): sesinya
  /// tidak boleh jadi dasar target berikutnya.
  final bool excluded;
}

class Workout {
  const Workout({required this.date, required this.entries});

  /// `YYYY-MM-DD`.
  final String date;
  final List<WorkoutEntry> entries;
}

enum ProgressionPolicy { off, linear, greyskull, double_, hit, time }

/// Policy mana yang masuk akal untuk mode pencatatan mana.
const policiesFor = <LogMode, List<ProgressionPolicy>>{
  LogMode.reps: [
    ProgressionPolicy.off,
    ProgressionPolicy.linear,
    ProgressionPolicy.greyskull,
    ProgressionPolicy.double_,
    ProgressionPolicy.hit,
  ],
  LogMode.time: [ProgressionPolicy.off, ProgressionPolicy.time],
  LogMode.cardio: [ProgressionPolicy.off],
};

const policyName = <ProgressionPolicy, String>{
  ProgressionPolicy.off: 'No automatic progression',
  ProgressionPolicy.linear: 'Linear progression',
  ProgressionPolicy.greyskull: 'Greyskull LP',
  ProgressionPolicy.double_: 'Double progression',
  ProgressionPolicy.hit: 'Heavy Duty (HIT)',
  ProgressionPolicy.time: 'Add time',
};
