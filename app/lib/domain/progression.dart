/// Progressive overload otomatis — port Dart dari
/// `reference/opengym/src/lib/progression.js` (v1.3.7, ditambah perbaikan
/// issue #233 dari v1.3.8), plus policy `hit` yang baru.
///
/// Prinsip yang ikut di-port, bukan cuma rumusnya (PRD §6):
///
/// * **Log adalah fakta, target adalah turunan.** Tidak ada counter tersimpan.
///   Setiap target dihitung ulang dari riwayat. Memperbaiki satu set yang salah
///   ketik otomatis memperbaiki target berikutnya (FR-E2).
/// * **Membaca sesi dengan jujur.** Set tercentang dengan rep cukup = hit; set
///   tercentang dengan rep kurang = miss; set yang tidak dicentang dibaca nol.
///   Karena itu sesi gagal tidak pernah menaikkan beban (FR-E3) tanpa perlu
///   aturan khusus.
/// * **Set tambahan tidak menggeser rencana** (openGym v1.3.8, issue #233).
///   Hanya `max(1, planned)` set kerja pertama yang dinilai: set bonus yang
///   lebih berat tidak menaikkan beban berikutnya, dan set bonus yang
///   dihentikan sebelum target tidak membuat sesi bersih terbaca gagal. Set
///   yang *kurang* dari rencana tetap belum cukup. Volume, PR, dan riwayat
///   membaca workout-nya langsung, jadi set tambahan tetap dihitung di sana.
/// * **Rutinitas deload tidak menggeser target** (FR-B10). Sesi dari rutinitas
///   yang ditandai "excluded from progression" disaring lewat
///   [progressionHistory] sebelum riwayat sampai ke policy mana pun.
/// * **Setiap angka punya alasan.** [Prescription.why] selalu terisi supaya UI
///   bisa menjawab "kenapa angka ini?" (FR-E5).
/// * **Mesin assisted berjalan terbalik** (openGym v1.3.8, issue #232). Beban
///   yang dicatat adalah bantuan mesin: sesi dibaca dari bantuan *terkecil*,
///   "naik" berarti bantuan berkurang, deload berarti bantuan bertambah, dan
///   di nol tidak ada lagi yang bisa dikurangi. Arahnya datang dari
///   [ExerciseConfig.assisted] yang diresolusi pemanggil — engine ini tidak
///   mengenal katalog (lihat `domain/assisted.dart`).
///
/// **Yang belum ikut di-port** dan sengaja disederhanakan: `selectDeloadCandidate`
/// milik openGym — pencarian grid Epley leksikografis untuk memilih pasangan
/// beban/rep saat deload. Di sini deload memakai [deloadTo] yang berbasis faktor,
/// yaitu jalur yang openGym sendiri pakai untuk greyskull dan time. Efeknya:
/// beban deload benar, tapi rep target tidak ikut dioptimalkan. Set unilateral
/// (per sisi), drop set, dan rest-pause juga belum ditangani.
library;

import 'dart:math' as math;

import '../core/format.dart';
import 'models.dart';

/// Dua desimal untuk beban yang benar-benar dipasang.
///
/// openGym membulatkan beban ke satu desimal (`round1`). Itu cukup untuk step
/// 0,5 / 2,5 / 5 tapi merusak grid **1,25 kg**: 61,25 keluar jadi 61,3 — angka
/// yang tidak bisa disusun dari pelat mana pun. Karena 1,25 adalah separuh dari
/// increment default tubuh atas, microplate bukan kasus pinggiran.
double _round2(double v) => (v * 100).round() / 100;

const deloadFactorDefault = 0.9;
const deloadFactorMin = 0.5;
const deloadFactorMax = 0.95;

/// Berapa sesi gagal berturut sebelum deload, per policy.
///
/// Greyskull 1 karena set terakhirnya memang AMRAP: gagal sekali di situ sudah
/// sinyal yang cukup. `hit` juga 1 siklus gagal ganda — lihat [_hit].
const deloadAfter = <ProgressionPolicy, int>{
  ProgressionPolicy.linear: 3,
  ProgressionPolicy.greyskull: 1,
  ProgressionPolicy.double_: 3,
  ProgressionPolicy.hit: 2,
  ProgressionPolicy.time: 3,
};

bool isValidDeloadFactor(num? value) =>
    value != null && value.isFinite && value >= deloadFactorMin && value <= deloadFactorMax;

double deloadFactorOf(ExerciseConfig cfg) =>
    isValidDeloadFactor(cfg.deloadFactor) ? cfg.deloadFactor! : deloadFactorDefault;

/// Kelipatan beban default: 2,5 kg tubuh atas, 5 kg tubuh bawah (FR-E7).
double defaultIncrementFor({required bool heavyBodyPart, String unit = 'kg'}) {
  if (unit == 'lb') return heavyBodyPart ? 10 : 5;
  return heavyBodyPart ? 5 : 2.5;
}

double weightIncrement(ExerciseConfig cfg, String unit) {
  final inc = cfg.increment;
  if (inc != null && inc > 0) return inc;
  return defaultIncrementFor(heavyBodyPart: cfg.heavyBodyPart, unit: unit);
}

const defaultSecondIncrement = 5;

/// Batas di mana menambah satu set push-up berhenti jadi kemajuan.
const maxBodyweightSets = 6;

/// Plafon rep bodyweight kalau rutinitas tidak menentukannya sendiri. Tanpa
/// plafon, target push-up naik satu rep per sesi selamanya — 40 push-up per
/// set bukan lagi latihan kekuatan.
const bodyweightRepCeiling = 20;

/// Bulatkan ke kelipatan yang benar-benar bisa dipasang di gym.
double snapWeight(double v, double step) {
  if (step <= 0) return _round2(v);
  return _round2((v / step).round() * step);
}

/// Tambah satu langkah beban.
///
/// Kalau beban sekarang sudah duduk di grid increment, hasilnya di-snap ke grid
/// itu. Kalau tidak — misal sled yang dicatat 397 kg karena beratnya sendiri ikut
/// — langkahnya sekadar ditambahkan, tidak dipaksa ke 400. Beban yang ditulis
/// pengguna tidak boleh berubah diam-diam.
double addStep(double w, double step, double inc) {
  final v = w.isFinite ? w : 0;
  final onGrid = inc > 0 && ((v - (v / inc).round() * inc).abs() <= 0.1);
  final next = v + step;
  return math.max(0, onGrid ? snapWeight(next, inc) : _round2(next));
}

double stepWeight(double value, double step, int direction) => addStep(value, direction * step, step);

/// Mundur sesuai faktor, mendarat di beban yang bisa dipasang.
double deloadTo(double current, double step, [double factor = deloadFactorDefault]) {
  var next = snapWeight(current * factor, step);
  if (next >= current) next = snapWeight(current - step, step);
  return math.max(step, next);
}

/// Deload untuk mesin assisted (#232): lebih banyak bantuan. Cermin dari
/// [deloadTo] — bantuan *dibagi* faktornya, bukan dikali, lalu di-snap ke
/// grid pelat; kalau snap-nya tidak beranjak, naik satu langkah.
double moreHelp(double current, double step, [double factor = deloadFactorDefault]) {
  var next = snapWeight(current / factor, step);
  if (next <= current) next = snapWeight(current + step, step);
  return next;
}

/// Satu langkah lebih berat: tambah beban, atau untuk assisted kurangi
/// bantuan. Tidak pernah negatif — [addStep] berhenti di nol, dan di nol
/// [nextPrescription] tidak lagi meminta langkah ini.
double harderBy(double w, double step, double inc, {required bool assisted}) =>
    addStep(w, assisted ? -step : step, inc);

/// Deload ke arah yang benar: beban turun, atau untuk assisted bantuan naik.
double easierTo(double w, double inc, double factor, {required bool assisted}) =>
    assisted ? moreHelp(w, inc, factor) : deloadTo(w, inc, factor);

/// Normalkan dua batas rep range milik double progression.
({int reps, int repsMin}) normalizeRepRange(int? reps, int? repsMin, [int stride = 1]) {
  final step = stride > 0 ? stride : 1;
  int align(int value) => math.max(step, (value / step).ceil() * step);
  final upper = align((reps != null && reps > 0) ? reps : 10);
  final lower = align((repsMin != null && repsMin > 0) ? repsMin : math.max(1, upper - 2));
  return lower >= upper ? (reps: lower + step, repsMin: lower) : (reps: upper, repsMin: lower);
}

/// Policy yang berlaku: override gerakan, lalu default rutinitas, lalu default mode.
ProgressionPolicy policyFor(ExerciseConfig cfg, {ProgressionPolicy? routineDefault}) {
  final allowed = policiesFor[cfg.mode] ?? const [ProgressionPolicy.off];
  final pick = cfg.policy ??
      routineDefault ??
      (cfg.mode == LogMode.reps ? ProgressionPolicy.linear : ProgressionPolicy.off);
  return allowed.contains(pick) ? pick : ProgressionPolicy.off;
}

/// Satu sesi yang sudah selesai, diringkas ke hal-hal yang dibutuhkan policy.
class SessionRead {
  const SessionRead({
    required this.date,
    required this.mode,
    required this.goal,
    required this.weight,
    required this.reps,
    required this.ok,
    required this.target,
    this.assisted = false,
  });

  final String date;
  final LogMode mode;

  /// Rep (atau detik) yang diminta target sesi itu.
  final int goal;

  /// Beban tertinggi yang benar-benar tercentang di antara set yang dinilai.
  /// Untuk mesin assisted (#232): bantuan *terkecil* di atas nol — itulah set
  /// terberatnya; nol berarti beban tidak diisi, bukan "tanpa bantuan".
  final double weight;

  /// Sesi ini dibaca sebagai mesin assisted (lihat [readSession]).
  final bool assisted;

  /// Rep per set kerja yang dinilai — sebanyak rencana, set bonus di luar itu
  /// tidak ikut (#233). Set yang tidak dicentang jadi 0.
  final List<int> reps;

  /// Semua set yang dinilai tercapai penuh, dan jumlah set yang *dicatat*
  /// tidak kurang dari rencana.
  final bool ok;

  final ExerciseConfig? target;

  int get count => reps.length;
  int get low => reps.isEmpty ? 0 : reps.reduce(math.min);

  /// Set terakhir yang *direncanakan* — yang dibawa ke failure oleh Greyskull.
  /// Set bonus sesudahnya bukan AMRAP-nya (#233).
  int get amrap => reps.isEmpty ? 0 : reps.last;

  /// Working set pertama — satu-satunya yang dibaca policy `hit`.
  int get firstWorking => reps.isEmpty ? 0 : reps.first;
}

/// Reduksi satu entry jadi penilaian.
///
/// `fallback` dipakai kalau entry tidak menyimpan targetnya sendiri. Riwayat
/// openGym sebelum v1.2.2 memang begitu, dan menilainya terhadap "tidak ada"
/// akan menskor setiap sesi lama sebagai gagal — lalu menyambut pengguna lama
/// dengan "gagal 11 sesi berturut, deload".
///
/// [assisted] adalah arah beban menurut konfigurasi yang berlaku sekarang
/// (#232). null = ikuti target yang dibekukan di entri; kalau itu pun tidak
/// tahu (riwayat sebelum v2.3), dibaca normal.
SessionRead readSession(WorkoutEntry entry, {required String date, ExerciseConfig? fallback, bool? assisted}) {
  final target = entry.target ?? fallback;
  final mode = target?.mode ?? LogMode.reps;
  final help = assisted ?? target?.assisted ?? false;

  // Warm-up disaring sekali di sini. Kalau tidak, satu warm-up yang tidak
  // dicentang akan meracuni `ok` selamanya dan menyeret `low` ke bawah. Drop
  // set dan rest-pause juga: rep sedikit di sana adalah rancangannya, bukan
  // kegagalan.
  final logged = entry.sets.where((s) => s.isWork).toList();
  final planned = target?.sets ?? logged.length;

  // `enough` membandingkan yang DICATAT dengan rencana: dua dari tiga set
  // tetap kurang. Tapi yang DINILAI hanya set sebanyak rencana (openGym
  // v1.3.8, #233): set bonus keempat yang lebih berat, atau yang dihentikan
  // lebih awal, adalah kerja ekstra — bukan bukti target naik atau gagal.
  // Minimal satu, supaya rencana yang rusak (0 set) tidak menilai kehampaan.
  final enough = logged.length >= planned;
  final sets = logged.take(math.max(1, planned)).toList();

  final weight = sessionLoad(sets.where((s) => s.done), assisted: help);

  if (mode == LogMode.time) {
    final goal = target?.seconds ?? 0;
    final held = sets.map((s) => s.done ? s.seconds : 0).toList();
    return SessionRead(
      date: date,
      mode: mode,
      goal: goal,
      weight: weight,
      reps: held,
      ok: goal > 0 && enough && held.isNotEmpty && held.every((h) => h >= goal),
      target: target,
      assisted: help,
    );
  }

  final goal = target?.reps ?? 0;
  final reps = sets.map((s) => s.done ? s.reps : 0).toList();
  return SessionRead(
    date: date,
    mode: mode,
    goal: goal,
    weight: weight,
    reps: reps,
    ok: goal > 0 && enough && reps.isNotEmpty && reps.every((r) => r >= goal),
    target: target,
    assisted: help,
  );
}

/// Beban yang mewakili satu sesi: puncak dari set tercentang. Untuk mesin
/// assisted (#232): bantuan terkecil di atas nol. Baris bernilai nol berarti
/// bebannya tidak diisi — kalau dibaca sebagai "tanpa bantuan", satu baris
/// kosong akan membuat sesi 20 kg terbaca sebagai pull-up tanpa mesin dan
/// target berikutnya "naik" dari nol.
double sessionLoad(Iterable<SetRow> done, {required bool assisted}) {
  if (!assisted) return done.fold(0.0, (a, s) => math.max(a, s.weight));
  final loads = [for (final s in done) if (s.weight > 0) s.weight];
  return loads.isEmpty ? 0 : loads.reduce(math.min);
}

/// Riwayat yang boleh menjadi dasar target berikutnya (FR-B10).
///
/// Rutinitas yang ditandai [Routine.excludedFromProgression] adalah minggu
/// deload yang direncanakan: sesinya fakta — tetap tampil di riwayat, volume,
/// statistik, PR, dan kolom PREV — tapi bukan target. Tanpa saringan ini,
/// sesi deload 50 kg yang "berhasil" akan meresepkan 52,5 kg untuk sesi
/// reguler yang sebelumnya sudah di 60.
///
/// Dicocokkan lewat nama ([Workout.routine]), karena itulah satu-satunya
/// jejak rutinitas yang dibawa setiap sesi — cara yang sama dipakai Home dan
/// sesi yang dibuka ulang. Sesi bebas (tanpa nama rutinitas) selalu ikut.
///
/// Ini satu-satunya tempat aturan itu hidup: setiap pemanggil prescription
/// (`planExercise`, pratinjau target di ringkasan dan Home, daftar stagnan)
/// lewat sini, bukan menyaring sendiri-sendiri. Tanpa rutinitas yang
/// dikecualikan, daftar yang sama dikembalikan apa adanya.
List<Workout> progressionHistory(List<Workout> workouts, List<Routine> routines) {
  final excluded = {for (final r in routines) if (r.excludedFromProgression) r.name};
  if (excluded.isEmpty) return workouts;
  return [for (final w in workouts) if (!excluded.contains(w.routine)) w];
}

/// Semua sesi lampau untuk satu gerakan, terlama dulu. [assisted] diteruskan
/// ke [readSession].
List<SessionRead> sessionsFor(List<Workout> workouts, String exerciseId,
    {ExerciseConfig? fallback, bool? assisted}) {
  final out = <SessionRead>[];
  for (final w in workouts) {
    for (final entry in w.entries) {
      if (entry.exerciseId != exerciseId) continue;
      // Sesi dari rutinitas deload tidak boleh jadi dasar target berikutnya (FR-B10).
      if (entry.excluded) continue;
      if (entry.sets.any((s) => s.done && !s.isWarmup)) {
        out.add(readSession(entry, date: w.date, fallback: fallback, assisted: assisted));
      }
    }
  }
  return out;
}

/// Berapa sesi berturut-turut berakhir gagal, dihitung mundur dari yang terbaru.
///
/// Dua hal mengakhiri rentetan selain keberhasilan:
///
/// * **Beban berubah.** Deload harus mencerminkan kegagalan pada beban yang
///   memicunya, bukan pada beban ringan yang menyusul. Perubahan ke arah mana
///   pun memutus rentetan, jadi mesin assisted (#232) ikut benar tanpa cabang
///   khusus: bantuan yang berkurang lalu gagal adalah kegagalan pertama pada
///   bantuan baru — kemajuan yang belum jadi, bukan stall yang berlanjut.
/// * **Di double progression, mengalahkan rekor rep pada beban yang sama.**
///   Double sengaja meminta lebih sedikit daripada yang dinilainya: targetnya
///   memanjat dari bawah range, sementara `ok` menuntut puncaknya. Tanpa
///   pengecualian ini, rep range yang lebih lebar dari dua akan selalu berakhir
///   deload meski jelas ada kemajuan.
int stallCount(List<SessionRead> sessions, ProgressionPolicy policy) {
  var n = 0;
  for (var i = sessions.length - 1; i >= 0; i--) {
    if (sessions[i].ok) break;
    if (i < sessions.length - 1 && sessions[i].weight != sessions[i + 1].weight) break;

    if (policy == ProgressionPolicy.double_) {
      // Hanya dalam lingkup beban sesi ini — bukan setiap sesi yang pernah
      // dilakukan pada beban itu. Membangun lagi setelah deload tidak boleh
      // diukur terhadap rep sebelum deload.
      final run = <int>[];
      for (var j = i - 1; j >= 0 && sessions[j].weight == sessions[i].weight; j--) {
        run.add(sessions[j].low);
      }
      if (run.isNotEmpty && sessions[i].low > run.reduce(math.max)) break;
    }
    n++;
  }
  return n;
}

enum PrescriptionKind { first, up, hold, deload, off }

/// Target sesi berikutnya untuk satu gerakan.
class Prescription {
  const Prescription({
    required this.policy,
    required this.kind,
    this.weight,
    this.reps,
    this.seconds,
    this.sets,
    required this.why,
  });

  final ProgressionPolicy policy;
  final PrescriptionKind kind;

  /// Field yang tidak dipunyai opini oleh policy tetap null, dan pemanggil
  /// mempertahankan apa pun yang tertulis di rencana.
  final double? weight;
  final int? reps;
  final int? seconds;
  final int? sets;

  /// Alasan satu kalimat, siap ditampilkan (FR-E5).
  final String why;
}

/// Hitung target sesi berikutnya dari riwayat.
Prescription nextPrescription({
  required List<Workout> workouts,
  required ExerciseConfig cfg,
  ProgressionPolicy? routineDefault,
  String unit = 'kg',
}) {
  final policy = policyFor(cfg, routineDefault: routineDefault);
  if (policy == ProgressionPolicy.off) {
    return Prescription(policy: policy, kind: PrescriptionKind.off, why: 'Automatic progression is off for this exercise.');
  }

  final inc = cfg.mode == LogMode.time
      ? ((cfg.increment != null && cfg.increment! > 0) ? cfg.increment! : defaultSecondIncrement.toDouble())
      : weightIncrement(cfg, unit);

  final sessions = sessionsFor(workouts, cfg.exerciseId, fallback: cfg, assisted: cfg.assisted)
      .where((s) => s.mode == cfg.mode)
      .toList();
  if (sessions.isEmpty) {
    return Prescription(
      policy: policy,
      kind: PrescriptionKind.first,
      why: 'Nothing logged yet — this session is the starting point.',
    );
  }

  final last = sessions.last;
  final stalls = stallCount(sessions, policy);
  final limit = deloadAfter[policy] ?? 3;

  if (cfg.mode == LogMode.time) return _time(policy, cfg, last, stalls, limit, inc.toInt());

  // Arah beban (#232): konfigurasi yang sudah diresolusi pemanggil menang;
  // kalau masih "otomatis", sesi terakhir dibaca dengan arah yang dibekukan
  // ke targetnya — [readSession] memakai urutan yang sama.
  final assisted = last.assisted;
  if (assisted && last.weight <= 0) return _assistedFloor(policy, cfg, last);
  if (policy == ProgressionPolicy.hit) return _hit(policy, cfg, sessions, inc, unit, assisted);

  final w = last.weight;
  if (w <= 0) return _bodyweight(policy, cfg, last);
  if (policy == ProgressionPolicy.double_) return _double(policy, cfg, last, stalls, limit, inc, unit, assisted);
  return _linearOrGreyskull(policy, cfg, last, stalls, limit, inc, unit, assisted);
}

/// Bantuan sudah nol: tidak ada lagi yang bisa dikurangi (#232). Target
/// ditahan di nol dan alasannya menyuruh pindah ke versi tanpa mesin — bukan
/// "-2,5 kg" yang jadi negatif, dan bukan jalur bodyweight yang akan
/// menyarankan "tambah beban".
Prescription _assistedFloor(ProgressionPolicy policy, ExerciseConfig cfg, SessionRead last) {
  final goal = last.goal > 0 ? last.goal : cfg.reps;
  return Prescription(
    policy: policy, kind: PrescriptionKind.hold, weight: 0, reps: goal > 0 ? goal : null,
    why: 'No help left to take away — move on to the unassisted exercise.',
  );
}

Prescription _time(ProgressionPolicy policy, ExerciseConfig cfg, SessionRead last, int stalls, int limit, int inc) {
  if (last.ok) {
    final sec = (last.goal > 0 ? last.goal : cfg.seconds) + inc;
    return Prescription(
      policy: policy, kind: PrescriptionKind.up, seconds: sec,
      why: 'Full hold on every set — target up ${inc}s.',
    );
  }
  if (stalls >= limit) {
    final base = (last.goal > 0 ? last.goal : cfg.seconds).toDouble();
    final sec = deloadTo(base, 5).round();
    return Prescription(
      policy: policy, kind: PrescriptionKind.deload, seconds: sec,
      why: 'Short $stalls sessions running — back to ${sec}s, then build again.',
    );
  }
  return Prescription(
    policy: policy, kind: PrescriptionKind.hold,
    seconds: last.goal > 0 ? last.goal : cfg.seconds,
    why: 'Came up short last time — same target again.',
  );
}

/// Kerja bodyweight tidak punya beban eksternal, jadi tidak ada yang bisa
/// ditambah atau dikurangi — "deload push-up-mu ke 2,5 kg" bukan saran.
/// Kemajuannya di rep, lalu set, lalu variasi yang lebih sulit (FR-E8).
Prescription _bodyweight(ProgressionPolicy policy, ExerciseConfig cfg, SessionRead last) {
  final goal = last.goal > 0 ? last.goal : cfg.reps;
  if (!last.ok || goal <= 0) {
    return Prescription(
      policy: policy, kind: PrescriptionKind.hold, weight: 0, reps: goal > 0 ? goal : null,
      why: 'Bodyweight — same target until every set is clean.',
    );
  }
  final top = cfg.repsMax ?? bodyweightRepCeiling;
  if (goal >= top) {
    final sets = math.max(1, cfg.sets > 0 ? cfg.sets : last.count) + 1;
    final bottom = math.max(1, math.min(cfg.reps > 0 ? cfg.reps : top, top));
    if (sets <= maxBodyweightSets) {
      return Prescription(
        policy: policy, kind: PrescriptionKind.up, weight: 0, reps: bottom, sets: sets,
        why: '$goal reps on every set — add a set, reps back to $bottom.',
      );
    }
    return Prescription(
      policy: policy, kind: PrescriptionKind.hold, weight: 0, reps: goal,
      why: '${sets - 1} × $goal — time for added load or a harder variation.',
    );
  }
  final next = goal + 1;
  return Prescription(
    policy: policy, kind: PrescriptionKind.up, weight: 0, reps: next,
    why: 'Bodyweight — all reps hit, go for $next this time.',
  );
}

/// Alasan untuk mesin assisted bicara soal *bantuan*, bukan beban (#232):
/// "+2,5 kg" di pull-up assisted terbaca sebagai lebih berat, padahal yang
/// terjadi kebalikannya. Teks untuk gerakan biasa tidak disentuh.
Prescription _double(ProgressionPolicy policy, ExerciseConfig cfg, SessionRead last, int stalls, int limit,
    double inc, String unit, bool assisted) {
  final range = normalizeRepRange(cfg.reps > 0 ? cfg.reps : last.goal, cfg.repsMin);
  final w = last.weight;
  if (last.ok) {
    final next = harderBy(w, inc, inc, assisted: assisted);
    return Prescription(
      policy: policy, kind: PrescriptionKind.up, weight: next, reps: range.repsMin,
      why: assisted
          ? 'Top of the rep range on every set — ${formatDelta(inc)} $unit less help, reps back to ${range.repsMin}.'
          : 'Top of the rep range on every set — +${formatDelta(inc)} $unit, reps back to ${range.repsMin}.',
    );
  }
  if (stalls >= limit) {
    final dw = easierTo(w, inc, deloadFactorOf(cfg), assisted: assisted);
    return Prescription(
      policy: policy, kind: PrescriptionKind.deload, weight: dw, reps: range.repsMin,
      why: assisted
          ? 'Stalled $stalls sessions — more help, back to ${formatDelta(dw)} $unit.'
          : 'Stalled $stalls sessions — deload to ${formatDelta(dw)} $unit.',
    );
  }
  final aim = math.min(range.reps, math.max(range.repsMin, last.low + 1));
  return Prescription(
    policy: policy, kind: PrescriptionKind.hold, weight: w, reps: aim,
    why: assisted ? 'Same help — go for $aim reps this time.' : 'Same weight — go for $aim reps this time.',
  );
}

Prescription _linearOrGreyskull(ProgressionPolicy policy, ExerciseConfig cfg, SessionRead last, int stalls,
    int limit, double inc, String unit, bool assisted) {
  final w = last.weight;
  if (last.ok) {
    // Set terakhir Greyskull dibawa ke failure: lewati dua kali target di situ
    // dan lompatan gandanya sudah kamu bayar sendiri.
    final dbl = policy == ProgressionPolicy.greyskull && last.goal > 0 && last.amrap >= last.goal * 2;
    final step = dbl ? inc * 2 : inc;
    return Prescription(
      policy: policy, kind: PrescriptionKind.up, weight: harderBy(w, step, inc, assisted: assisted),
      why: switch ((assisted, dbl)) {
        (true, true) =>
          'Last set ${last.amrap} reps — double the target, so a double step of ${formatDelta(step)} $unit less help.',
        (true, false) => '${formatDelta(step)} $unit less help — all reps hit last session.',
        (false, true) =>
          'Last set ${last.amrap} reps — double the target, so a double jump of +${formatDelta(step)} $unit.',
        (false, false) => '+${formatDelta(step)} $unit — all reps hit last session.',
      },
    );
  }
  if (stalls >= limit) {
    final dw = easierTo(w, inc, deloadFactorOf(cfg), assisted: assisted);
    return Prescription(
      policy: policy, kind: PrescriptionKind.deload, weight: dw,
      why: switch ((assisted, stalls > 1)) {
        (true, true) =>
          'Reps short $stalls sessions running — more help, back to ${formatDelta(dw)} $unit, then work it down again.',
        (true, false) => 'Reps short — more help, back to ${formatDelta(dw)} $unit, then work it down again.',
        (false, true) => 'Reps short $stalls sessions running — reset to ${formatDelta(dw)} $unit and climb again.',
        (false, false) => 'Reps short — reset to ${formatDelta(dw)} $unit and climb again.',
      },
    );
  }
  return Prescription(
    policy: policy, kind: PrescriptionKind.hold, weight: w,
    why: assisted
        ? 'Reps short last session — same help again (${limit - stalls} of $limit to go).'
        : 'Reps short last session — same weight again (${limit - stalls} of $limit to go).',
  );
}

/// Heavy Duty / HIT — policy baru, tidak ada di openGym (FR-E6, spec §6.2).
///
/// Bedanya dari policy lain: **hanya membaca satu working set**, yaitu baris
/// non-warm-up pertama. Itu memang metodenya — satu set ke failure per gerakan.
/// Set tambahan yang terlanjur tercatat diabaikan, bukan dijadikan alasan gagal.
Prescription _hit(ProgressionPolicy policy, ExerciseConfig cfg, List<SessionRead> sessions, double inc, String unit,
    bool assisted) {
  final range = normalizeRepRange(cfg.reps > 0 ? cfg.reps : 10, cfg.repsMin ?? 6);
  final hi = range.reps;
  final lo = range.repsMin;

  final last = sessions.last;
  final w = last.weight;
  final reps = last.firstWorking;

  // Dips, pull-up, push-up tanpa beban tambahan: tidak ada beban untuk
  // dinaikkan atau diturunkan. Dulu di sini keluar "+2,5 kg" untuk dips.
  // Mesin assisted di nol tidak sampai sini — [_assistedFloor] menahannya.
  if (w <= 0) {
    if (reps >= hi) {
      return Prescription(
        policy: policy, kind: PrescriptionKind.hold, weight: 0, reps: hi,
        why: '$reps reps on bodyweight — past the top of the range. Add load (belt, vest) or a harder variation.',
      );
    }
    if (reps >= lo) {
      return Prescription(
        policy: policy, kind: PrescriptionKind.up, weight: 0, reps: reps + 1,
        why: '$reps reps on bodyweight — go for ${reps + 1}.',
      );
    }
    return Prescription(
      policy: policy, kind: PrescriptionKind.hold, weight: 0, reps: lo,
      why: '$reps reps, under $lo — same target. Consider an extra rest day.',
    );
  }

  if (reps >= hi) {
    final next = harderBy(w, inc, inc, assisted: assisted);
    return Prescription(
      policy: policy, kind: PrescriptionKind.up, weight: next, reps: lo,
      why: assisted
          ? '$reps reps — past the top of the range, ${formatDelta(inc)} $unit less help and reps back to $lo.'
          : '$reps reps — past the top of the range, +${formatDelta(inc)} $unit and reps back to $lo.',
    );
  }

  if (reps >= lo) {
    return Prescription(
      policy: policy, kind: PrescriptionKind.hold, weight: w, reps: reps + 1,
      why: assisted
          ? '$reps reps — still inside the range, same help, go for ${reps + 1}.'
          : '$reps reps — still inside the range, same weight, go for ${reps + 1}.',
    );
  }

  // Di bawah batas bawah. Sekali masih ditoleransi; dua kali berturut baru
  // deload — dan sarannya menambah satu hari istirahat, karena pada volume
  // serendah ini penyebab tersering bukan bebannya, tapi pemulihannya.
  final prev = sessions.length >= 2 ? sessions[sessions.length - 2] : null;
  final twiceShort = prev != null && prev.weight == w && prev.firstWorking < lo;
  if (twiceShort) {
    final dw = easierTo(w, inc, deloadFactorOf(cfg), assisted: assisted);
    return Prescription(
      policy: policy, kind: PrescriptionKind.deload, weight: dw, reps: lo,
      why: assisted
          ? 'Two sessions running under $lo reps — more help, back to ${formatDelta(dw)} $unit. Consider adding a rest day.'
          : 'Two sessions running under $lo reps — deload to ${formatDelta(dw)} $unit. Consider adding a rest day.',
    );
  }
  return Prescription(
    policy: policy, kind: PrescriptionKind.hold, weight: w, reps: lo,
    why: assisted
        ? '$reps reps, under $lo — same help again before deciding to deload.'
        : '$reps reps, under $lo — same weight again before deciding to deload.',
  );
}

/// Terapkan prescription ke set yang belum dicatat.
///
/// Tidak pernah menimpa set yang sudah dicentang, dan tidak pernah menyentuh
/// warm-up: prescription bicara ke baris kerja saja.
List<SetRow> applyPrescription(List<SetRow> sets, Prescription p) {
  if (p.kind == PrescriptionKind.off || p.kind == PrescriptionKind.first) return sets;
  return sets.map((s) {
    if (s.done || s.isWarmup) return s;
    return s.copyWith(
      weight: p.weight,
      reps: p.reps,
      seconds: p.seconds,
    );
  }).toList();
}
