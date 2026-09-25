/// Bentuk data latihan, di-port dari `reference/opengym/src/lib/workout-model.js`.
///
/// Nama field sengaja dipertahankan sependek aslinya (`w`, `r`, `sec`) di lapisan
/// JSON: dokumen `S` yang disimpan di Supabase harus tetap kompatibel dengan
/// ekspor/impor openGym (NFR-10). Di Dart namanya dieja penuh.
library;

/// Fase satu baris set. Warm-up tidak pernah ikut dihitung untuk progresi,
/// 1RM, maupun fatigue (FR-D6).
///
/// Drop set dan rest-pause (FR-D7) adalah kerja sungguhan — ikut volume — tapi
/// bukan set kerja yang dinilai progresi: satu drop set dengan rep sedikit di
/// beban yang lebih ringan bukan tanda gagal.
enum SetPhase { work, warmup, drop, restPause }

const _phaseKey = <SetPhase, String>{
  SetPhase.warmup: 'warmup',
  SetPhase.drop: 'drop',
  SetPhase.restPause: 'rp',
};

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

  /// Set kerja yang dinilai progresi. Bukan warm-up, bukan drop/rest-pause.
  bool get isWork => phase == SetPhase.work;

  /// Drop set atau rest-pause: ikut volume, tidak ikut penilaian progresi.
  bool get isExtra => phase == SetPhase.drop || phase == SetPhase.restPause;

  SetRow copyWith({
    double? weight,
    int? reps,
    int? seconds,
    bool? done,
    SetPhase? phase,
    int? rir,
    bool clearRir = false,
  }) {
    return SetRow(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      seconds: seconds ?? this.seconds,
      done: done ?? this.done,
      phase: phase ?? this.phase,
      rir: clearRir ? null : (rir ?? this.rir),
    );
  }

  Map<String, dynamic> toJson() => {
        'w': weight,
        'r': reps,
        if (seconds > 0) 'sec': seconds,
        'done': done,
        if (_phaseKey[phase] != null) 'phase': _phaseKey[phase],
        if (rir != null) 'rir': rir,
      };

  factory SetRow.fromJson(Map<String, dynamic> j) => SetRow(
        weight: (j['w'] as num?)?.toDouble() ?? 0,
        reps: (j['r'] as num?)?.toInt() ?? 0,
        seconds: (j['sec'] as num?)?.toInt() ?? 0,
        done: j['done'] == true,
        // Riwayat lama memakai boolean `warmup`; `phase` menang kalau ada.
        phase: switch (j['phase']) {
          'warmup' => SetPhase.warmup,
          'drop' => SetPhase.drop,
          'rp' => SetPhase.restPause,
          _ => j['warmup'] == true ? SetPhase.warmup : SetPhase.work,
        },
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
    this.warmupSets = 0,
    this.superset = false,
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

  /// Berapa baris warm-up yang disiapkan di depan set kerja saat sesi dibuka.
  /// Heavy Duty memakai 1–2; kebanyakan rutinitas lain 0 dan menambahnya
  /// sendiri kalau perlu.
  final int warmupSets;

  /// Superset dengan gerakan sesudahnya (FR-D7): istirahat baru dimulai
  /// setelah set gerakan pasangannya.
  final bool superset;

  ExerciseConfig copyWith({
    ProgressionPolicy? policy,
    LogMode? mode,
    int? sets,
    int? reps,
    int? repsMin,
    int? repsMax,
    bool clearRepsMax = false,
    double? weight,
    int? seconds,
    double? increment,
    int? restSeconds,
    double? deloadFactor,
    int? warmupSets,
    bool? bodyweight,
    bool? superset,
    String? exerciseId,
  }) {
    return ExerciseConfig(
      exerciseId: exerciseId ?? this.exerciseId,
      policy: policy ?? this.policy,
      mode: mode ?? this.mode,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      repsMin: repsMin ?? this.repsMin,
      repsMax: clearRepsMax ? null : (repsMax ?? this.repsMax),
      superset: superset ?? this.superset,
      weight: weight ?? this.weight,
      seconds: seconds ?? this.seconds,
      increment: increment ?? this.increment,
      restSeconds: restSeconds ?? this.restSeconds,
      deloadFactor: deloadFactor ?? this.deloadFactor,
      bodyweight: bodyweight ?? this.bodyweight,
      heavyBodyPart: heavyBodyPart,
      warmupSets: warmupSets ?? this.warmupSets,
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
        if (warmupSets > 0) 'wu': warmupSets,
        if (superset) 'ss': true,
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
        warmupSets: (j['wu'] as num?)?.toInt() ?? 0,
        superset: j['ss'] == true,
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
  const WorkoutEntry({required this.exerciseId, required this.sets, this.target, this.excluded = false, this.note});

  final String exerciseId;
  final List<SetRow> sets;

  /// Target yang berlaku saat sesi itu berjalan. null untuk riwayat lama —
  /// penilainya jatuh ke konfigurasi gerakan saat ini (lihat [readSession]).
  final ExerciseConfig? target;

  /// Rutinitas deload ditandai "excluded from progression" (FR-B10): sesinya
  /// tidak boleh jadi dasar target berikutnya.
  final bool excluded;

  /// Catatan untuk gerakan ini di sesi ini ("kursi posisi 4"). Ditampilkan
  /// lagi di sesi berikutnya gerakan yang sama.
  final String? note;

  WorkoutEntry copyWith({List<SetRow>? sets, String? note, bool clearNote = false}) => WorkoutEntry(
        exerciseId: exerciseId,
        sets: sets ?? this.sets,
        target: target,
        excluded: excluded,
        note: clearNote ? null : (note ?? this.note),
      );

  Map<String, dynamic> toJson() => {
        'id': exerciseId,
        'sets': [for (final s in sets) s.toJson()],
        if (target != null) 'target': target!.toJson(),
        if (excluded) 'excl': true,
        if (note != null && note!.isNotEmpty) 'note': note,
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
        note: j['note'] as String?,
      );
}

class Workout {
  const Workout({
    required this.date,
    required this.entries,
    this.routine,
    this.durationSeconds,
    this.notes,
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

  /// Catatan sesi dari kotak "Session notes".
  final String? notes;

  Workout copyWith({String? date, List<WorkoutEntry>? entries, String? notes, bool clearNotes = false}) => Workout(
        date: date ?? this.date,
        entries: entries ?? this.entries,
        routine: routine,
        durationSeconds: durationSeconds,
        notes: clearNotes ? null : (notes ?? this.notes),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        if (routine != null) 'routine': routine,
        if (durationSeconds != null) 'dur': durationSeconds,
        if (notes != null && notes!.isNotEmpty) 'note': notes,
        'entries': [for (final e in entries) e.toJson()],
      };

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
        date: j['date'] as String? ?? '',
        routine: j['routine'] as String?,
        durationSeconds: (j['dur'] as num?)?.toInt(),
        notes: j['note'] as String?,
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


/// Satu rutinitas yang disimpan: nama dan daftar gerakan beserta targetnya.
///
/// `id` tetap selama rutinitas hidup, tidak ikut berubah saat dinamai ulang —
/// urutan rotasi program menunjuk ke id, bukan ke nama.
class Routine {
  const Routine({required this.id, required this.name, this.exercises = const [], this.policy});

  final String id;
  final String name;
  final List<ExerciseConfig> exercises;

  /// Policy bawaan untuk gerakan yang tidak menentukan sendiri.
  final ProgressionPolicy? policy;

  int get setCount => exercises.fold(0, (a, e) => a + e.sets);

  Routine copyWith({String? id, String? name, List<ExerciseConfig>? exercises, ProgressionPolicy? policy}) => Routine(
        id: id ?? this.id,
        name: name ?? this.name,
        exercises: exercises ?? this.exercises,
        policy: policy ?? this.policy,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (policy != null) 'pol': policy!.name,
        'ex': [for (final e in exercises) e.toJson()],
      };

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        policy: _byName(ProgressionPolicy.values, j['pol']),
        exercises: [
          for (final e in (j['ex'] as List? ?? const []))
            ExerciseConfig.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
}

/// Bagaimana program menentukan sesi berikutnya (FR-B2).
///
/// `rotation`: urutan sesi, tidak terikat hari — bolos Senin tidak menggeser
/// apa pun, sesi berikutnya tetap yang berikutnya. `weekday`: rutinitas terikat
/// ke hari latihan dalam seminggu.
enum ProgramMode { rotation, weekday }

/// Program aktif: rutinitas mana, dalam urutan apa, dan aturan istirahatnya.
class Program {
  const Program({
    required this.name,
    this.templateId,
    this.mode = ProgramMode.rotation,
    this.order = const [],
    this.cursor = 0,
    this.minRestDays = 0,
    this.days = const [],
    this.skippedOn,
  });

  final String name;

  /// Template asalnya (`ppl`, `heavy-duty`, …), atau null untuk split buatan
  /// sendiri.
  final String? templateId;

  final ProgramMode mode;

  /// Id rutinitas dalam urutan sesi.
  final List<String> order;

  /// Mode rotasi: indeks di [order] untuk sesi berikutnya (FR-B3).
  final int cursor;

  /// Hari istirahat minimum sejak latihan terakhir (FR-B5). Saran, bukan kunci.
  final int minRestDays;

  /// Mode weekday: hari latihan, 1 = Senin … 7 = Minggu. Rutinitas dibagikan ke
  /// hari-hari ini berurutan, berputar kalau harinya lebih banyak.
  final List<int> days;

  /// Tanggal `YYYY-MM-DD` yang dilewati lewat tombol Skip di mode weekday.
  final String? skippedOn;

  Program copyWith({
    String? name,
    ProgramMode? mode,
    List<String>? order,
    int? cursor,
    int? minRestDays,
    List<int>? days,
    String? skippedOn,
    bool clearSkip = false,
  }) =>
      Program(
        name: name ?? this.name,
        templateId: templateId,
        mode: mode ?? this.mode,
        order: order ?? this.order,
        cursor: cursor ?? this.cursor,
        minRestDays: minRestDays ?? this.minRestDays,
        days: days ?? this.days,
        skippedOn: clearSkip ? null : (skippedOn ?? this.skippedOn),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (templateId != null) 'tpl': templateId,
        'mode': mode.name,
        'order': order,
        'cursor': cursor,
        if (minRestDays != 0) 'rest': minRestDays,
        if (days.isNotEmpty) 'days': days,
        if (skippedOn != null) 'skip': skippedOn,
      };

  factory Program.fromJson(Map<String, dynamic> j) => Program(
        name: j['name'] as String? ?? '',
        templateId: j['tpl'] as String?,
        mode: _byName(ProgramMode.values, j['mode']) ?? ProgramMode.rotation,
        order: (j['order'] as List?)?.cast<String>() ?? const [],
        cursor: (j['cursor'] as num?)?.toInt() ?? 0,
        minRestDays: (j['rest'] as num?)?.toInt() ?? 0,
        days: (j['days'] as List?)?.map((d) => (d as num).toInt()).toList() ?? const [],
        skippedOn: j['skip'] as String?,
      );
}
