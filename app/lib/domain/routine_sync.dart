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
