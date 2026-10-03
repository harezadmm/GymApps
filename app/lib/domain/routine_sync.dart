/// Menyelaraskan rutinitas dengan susunan sesi yang baru selesai (FR-B9).
///
/// Latar belakangnya keluhan nyata: gerakan yang ditambah di tengah sesi Push
/// hilang lagi di sesi Push berikutnya, karena pertanyaan "perbarui
/// rutinitas?" di ringkasan tidak punya jawaban bawaan dan biasanya dilewati.
/// Sekarang penyelarasan dihitung di sini — murni, tanpa Flutter — supaya
/// layar konfirmasi bisa menunjukkan *apa* yang akan berubah sebelum orang
/// menekan selesai, dan ringkasan bisa membatalkannya tanpa menebak.
library;

import 'models.dart';

/// Selisih antara rutinitas dan susunan sesi, dalam bentuk yang bisa
/// ditampilkan: "+ Cable Fly · − Dips · Bench Press 3→4 set".
class RoutineDiff {
  const RoutineDiff({
    this.added = const [],
    this.removed = const [],
    this.setChanges = const [],
    this.reordered = false,
  });

  /// Id gerakan yang ada di sesi tapi tidak di rutinitas, urut seperti di sesi.
  final List<String> added;

  /// Id gerakan yang ada di rutinitas tapi dibuang di sesi, urut seperti di
  /// rutinitas.
  final List<String> removed;

  /// Gerakan yang jumlah set kerjanya berbeda: (id, dari, ke).
  final List<(String id, int from, int to)> setChanges;

  /// Urutan gerakan yang sama-sama ada berubah.
  final bool reordered;

  bool get isEmpty => added.isEmpty && removed.isEmpty && setChanges.isEmpty && !reordered;
}

/// Bandingkan [original] dengan susunan [session] — (id gerakan, jumlah set
/// kerja) urut seperti di layar sesi.
///
/// Set kerja 0 (gerakan yang semua barisnya warm-up, atau yang baru ditambah
/// lalu tidak diisi) tidak dihitung sebagai perubahan set: menulis "3→0 set"
/// bukan niat siapa pun.
RoutineDiff diffRoutine(Routine original, List<(String exerciseId, int workCount)> session) {
  // Dihitung sebagai multiset lewat antrean per id: satu rutinitas boleh
  // memuat gerakan yang sama dua kali (mis. dua variasi curl), dan set kedua
  // harus dipasangkan dengan kemunculan kedua, bukan dianggap "ditambah".
  final pool = <String, List<ExerciseConfig>>{};
  for (final cfg in original.exercises) {
    pool.putIfAbsent(cfg.exerciseId, () => []).add(cfg);
  }

  final added = <String>[];
  final setChanges = <(String, int, int)>[];
  final matchedInSession = <String>[];
  for (final (id, work) in session) {
    final queue = pool[id];
    if (queue == null || queue.isEmpty) {
      added.add(id);
      continue;
    }
    final cfg = queue.removeAt(0);
    matchedInSession.add(id);
    if (work > 0 && work != cfg.sets) setChanges.add((id, cfg.sets, work));
  }

  // Yang tersisa di antrean tidak pernah dipasangkan → dibuang di sesi.
  final removed = <String>[];
  final matchedInOriginal = <String>[];
  final leftover = {for (final e in pool.entries) e.key: e.value.length};
  for (final cfg in original.exercises.reversed) {
    final n = leftover[cfg.exerciseId] ?? 0;
    if (n > 0) {
      removed.insert(0, cfg.exerciseId);
      leftover[cfg.exerciseId] = n - 1;
    } else {
      matchedInOriginal.insert(0, cfg.exerciseId);
    }
  }

  var reordered = matchedInOriginal.length == matchedInSession.length;
  if (reordered) {
    reordered = false;
    for (var i = 0; i < matchedInOriginal.length; i++) {
      if (matchedInOriginal[i] != matchedInSession[i]) {
        reordered = true;
        break;
      }
    }
  }

  return RoutineDiff(added: added, removed: removed, setChanges: setChanges, reordered: reordered);
}

/// Rutinitas baru yang susunannya mengikuti [session].
///
/// * Urutan ikut sesi.
/// * Gerakan yang sudah ada di rutinitas **mempertahankan konfigurasinya**
///   (policy, istirahat, kelipatan, rep range) — sesi tidak tahu apa-apa soal
///   itu; hanya jumlah set dan superset yang diambil dari sesi.
/// * Gerakan baru memakai [session]'s config apa adanya; pemanggil sudah
///   mengonversinya ke kg, karena rutinitas selalu disimpan dalam kg.
/// * Gerakan yang dibuang di sesi keluar dari rutinitas.
/// * Set kerja 0 mempertahankan jumlah set lama — rutinitas dengan 0 set
///   tidak bisa dimulai.
Routine syncRoutineWithSession(Routine original, List<(ExerciseConfig configKg, int workCount)> session) {
  final pool = <String, List<ExerciseConfig>>{};
  for (final cfg in original.exercises) {
    pool.putIfAbsent(cfg.exerciseId, () => []).add(cfg);
  }

  final next = <ExerciseConfig>[];
  for (final (cfg, work) in session) {
    final queue = pool[cfg.exerciseId];
    if (queue != null && queue.isNotEmpty) {
      final kept = queue.removeAt(0);
      next.add(kept.copyWith(sets: work > 0 ? work : kept.sets, superset: cfg.superset));
    } else {
      next.add(work > 0 ? cfg.copyWith(sets: work) : cfg);
    }
  }
  // Superset menunjuk ke gerakan sesudahnya. Gerakan terakhir yang masih
  // bertanda superset (pasangannya dibuang di sesi) akan diam-diam
  // berpasangan dengan gerakan apa pun yang ditambah berikutnya.
  if (next.isNotEmpty && next.last.superset) {
    next[next.length - 1] = next.last.copyWith(superset: false);
  }
  return original.copyWith(exercises: next);
}

/// Konfigurasi gerakan baru (belum ada di [original]) untuk ditulis ke
/// rutinitas, dalam kg.
///
/// Target sesi membawa hal yang tidak pernah dipilih orangnya: policy
/// rutinitas dan faktor deload Profil yang sudah "dibekukan" ke dalamnya.
/// Kalau ikut tertulis, keduanya jadi pengaturan khusus gerakan itu —
/// mengganti policy rutinitas atau deload di Profil nanti tidak lagi berlaku
/// untuknya. [restSeconds]: istirahat yang dipilih di tengah sesi, yang
/// memang pilihan orangnya.
ExerciseConfig routineConfigForNew(
  ExerciseConfig configKg,
  Routine original, {
  double? profileDeload,
  int? restSeconds,
}) {
  final json = configKg.toJson();
  if (json['pol'] == original.policy?.name) json.remove('pol');
  if (configKg.deloadFactor != null && configKg.deloadFactor == profileDeload) json.remove('dl');
  if (restSeconds != null) json['rest'] = restSeconds;
  return ExerciseConfig.fromJson(json);
}

/// Susunan (id gerakan, set kerja) sesi yang sudah tersimpan — dihitung sama
/// dengan layar sesi: warm-up, drop set, dan rest-pause bukan set kerja.
List<(String, int)> workoutLayout(Workout w) => [
      for (final e in w.entries) (e.exerciseId, e.sets.where((s) => s.isWork).length),
    ];

/// [routine] dengan susunan sesi tersimpan [w], atau null kalau susunannya
/// sudah sama (atau sesinya kosong — rutinitas tanpa gerakan tidak bisa
/// dimulai).
///
/// Sama dengan penyelarasan saat sesi selesai ([syncRoutineWithSession]):
/// gerakan yang sudah ada mempertahankan konfigurasinya, gerakan baru membawa
/// target sesinya tanpa policy dan deload yang hanya dibekukan.
Routine? routineFollowingWorkout(Routine routine, Workout w, {double? profileDeload}) {
  if (w.entries.isEmpty) return null;
  final layout = workoutLayout(w);
  if (diffRoutine(routine, layout).isEmpty) return null;
  final known = {for (final c in routine.exercises) c.exerciseId};
  return syncRoutineWithSession(routine, [
    for (final (i, e) in w.entries.indexed)
      (
        known.contains(e.exerciseId)
            ? (e.target ?? ExerciseConfig(exerciseId: e.exerciseId))
            : routineConfigForNew(
                // Riwayat yang sangat lama tidak menyimpan target: rentang
                // yang sama dengan gerakan yang ditambah di sesi bebas.
                e.target ?? ExerciseConfig(exerciseId: e.exerciseId, reps: 12, repsMin: 8),
                routine,
                profileDeload: profileDeload,
              ),
        layout[i].$2,
      ),
  ]);
}

/// Setiap rutinitas mengikuti sesi terbarunya (menurut tanggal) yang dicatat
/// dengan nama rutinitas itu. Sesi bebas dan nama lain tidak dihitung.
///
/// Untuk rencana yang dibuat sebelum v2.2: waktu itu menyelesaikan sesi tidak
/// pernah menulis susunannya ke rutinitas, jadi rutinitas masih isi template
/// sementara orangnya sudah lama berlatih dengan susunan sendiri. Dijalankan
/// sekali per rencana ([Program.aligned]); sesudahnya rutinitas hanya berubah
/// karena keputusan orangnya — editor, atau saat sesi selesai.
({List<Routine> routines, List<String> changed}) alignRoutinesWithLatestSessions(
  List<Routine> routines,
  List<Workout> workouts, {
  double? profileDeload,
}) {
  final latest = <String, Workout>{};
  for (final w in workouts) {
    final name = w.routine;
    if (name == null || w.entries.isEmpty) continue;
    final seen = latest[name];
    // Tanggal sama: yang lebih dulu di daftar dipertahankan — daftar store
    // terbaru dulu.
    if (seen == null || w.date.compareTo(seen.date) > 0) latest[name] = w;
  }
  final out = <Routine>[];
  final changed = <String>[];
  for (final r in routines) {
    final w = latest[r.name];
    final next = w == null ? null : routineFollowingWorkout(r, w, profileDeload: profileDeload);
    out.add(next ?? r);
    if (next != null) changed.add(r.name);
  }
  return (routines: out, changed: changed);
}
