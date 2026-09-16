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

  /// Kunci pendek dan field bawaan dihilangkan. Satu sesi bisa punya belasan
  /// entri, dan seluruh riwayat dikirim sebagai satu dokumen ke Supabase —
  /// yang tidak ditulis tidak perlu diangkut.
  Map<String, dynamic> toJson() => {
        'id': exerciseId,
        if (policy != null) 'pol': policy!.name,
        if (mode != LogMode.reps) 'mode': mode.name,
        if (sets != 3) 'n': sets,
        if (reps != 10) 'r': reps,
        if (repsMin != null) 'rMin': repsMin,
        if (repsMax != null) 'rMax': repsMax,
        if (weight != 0) 'w': weight,
        if (seconds != 0) 'sec': seconds,
        if (increment != null) 'inc': increment,
        if (restSeconds != null) 'rest': restSeconds,
        if (deloadFactor != null) 'dl': deloadFactor,
        if (bodyweight) 'bw': true,
        if (heavyBodyPart) 'heavy': true,
      };

  factory ExerciseConfig.fromJson(Map<String, dynamic> j) => ExerciseConfig(
        exerciseId: j['id'] as String? ?? '',
        // Nama policy yang tidak dikenal jatuh ke null, bukan melempar: satu
        // policy baru di versi berikutnya tidak boleh membuat riwayat lama
        // tidak bisa dibaca sama sekali.
        policy: _byName(ProgressionPolicy.values, j['pol']),
        mode: _byName(LogMode.values, j['mode']) ?? LogMode.reps,
        sets: (j['n'] as num?)?.toInt() ?? 3,
        reps: (j['r'] as num?)?.toInt() ?? 10,
        repsMin: (j['rMin'] as num?)?.toInt(),
        repsMax: (j['rMax'] as num?)?.toInt(),
        weight: (j['w'] as num?)?.toDouble() ?? 0,
        seconds: (j['sec'] as num?)?.toInt() ?? 0,
        increment: (j['inc'] as num?)?.toDouble(),
        restSeconds: (j['rest'] as num?)?.toInt(),
        deloadFactor: (j['dl'] as num?)?.toDouble(),
        bodyweight: j['bw'] == true,
        heavyBodyPart: j['heavy'] == true,
      );
}

/// Cari anggota enum berdasarkan namanya; null kalau tidak ada yang cocok.
T? _byName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
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

  Map<String, dynamic> toJson() => {
        'id': exerciseId,
        'sets': [for (final s in sets) s.toJson()],
        if (target != null) 'target': target!.toJson(),
        if (excluded) 'excl': true,
      };

  factory WorkoutEntry.fromJson(Map<String, dynamic> j) => WorkoutEntry(
        exerciseId: j['id'] as String? ?? '',
        sets: [
          for (final s in (j['sets'] as List? ?? const []))
            SetRow.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
        target: j['target'] == null
            ? null
            : ExerciseConfig.fromJson(Map<String, dynamic>.from(j['target'] as Map)),
        excluded: j['excl'] == true,
      );
}

class Workout {
  const Workout({
    required this.date,
    required this.entries,
    this.routine,
    this.durationSeconds,
  });

  /// `YYYY-MM-DD`.
  final String date;
  final List<WorkoutEntry> entries;

  /// Nama rutinitas yang dijalankan, kalau sesinya berasal dari rutinitas.
  /// Nullable karena sesi bebas tidak punya nama, dan karena riwayat yang
  /// ditulis sebelum kolom ini ada tetap harus bisa dibaca.
  final String? routine;

  /// Lama sesi. Tidak bisa dihitung ulang dari set — istirahat, ganti alat, dan
  /// antre di rak tidak meninggalkan jejak apa pun di data.
  final int? durationSeconds;

  Map<String, dynamic> toJson() => {
        'date': date,
        if (routine != null) 'routine': routine,
        if (durationSeconds != null) 'dur': durationSeconds,
        'entries': [for (final e in entries) e.toJson()],
      };

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
        date: j['date'] as String? ?? '',
        routine: j['routine'] as String?,
        durationSeconds: (j['dur'] as num?)?.toInt(),
        entries: [
          for (final e in (j['entries'] as List? ?? const []))
            WorkoutEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
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
