/// Rutinitas dari sesi yang sudah selesai — "tadi enak, simpan jadi
/// rutinitas" (FR-B8, lewat pintu riwayat FR-F1).
///
/// Sesi bebas yang ternyata bagus, atau sesi rutinitas yang menyimpang jauh,
/// selama ini hanya bisa dijadikan rutinitas dengan mengetik ulang gerakan
/// dan angkanya satu per satu di editor. Modul ini murni — tidak mengimpor
/// Flutter maupun katalog — supaya aturannya bisa diuji tanpa aset, dan
/// pemanggilnya (ringkasan selesai, sheet detail riwayat) tinggal memberi
/// nama.
///
/// Yang dibaca adalah **apa yang benar-benar dikerjakan**, bukan rencana:
/// baris yang tidak dicentang dibaca sebagai tidak dilakukan — aturan yang
/// sama dengan FR-E3 — jadi jumlah set, rep, dan beban semuanya turun dari
/// set yang tercentang. Beban dalam kg, seperti [Workout] di store; sesi yang
/// masih dalam satuan tampilan dikonversi dulu oleh pemanggil.
library;

import 'assisted.dart';
import 'models.dart';

/// Susun rutinitas [name] ber-[id] dari [w]. Gerakan tanpa set tercentang
/// dilewati; sesi tanpa set tercentang sama sekali menghasilkan rutinitas
/// tanpa gerakan, dan pemanggil yang memutuskan mau diapakan.
///
/// [isAssisted] menjawab arah beban untuk entri yang targetnya tidak menyebut
/// `assisted` (lihat [entryIsAssisted]).
Routine routineFromWorkout(Workout w, {required String id, required String name, AssistedLookup? isAssisted}) {
  final entries = [for (final e in w.entries) if (hasDoneSet(e)) e];
  // Policy yang paling sering berlaku di sesi ini jadi policy rutinitas;
  // gerakan yang berbeda membawa override-nya sendiri. Tiap gerakan lalu
  // dinilai persis seperti di sesi asalnya, dan rutinitasnya tetap punya satu
  // policy yang bisa diganti dari editor — bukan enam override yang diam-diam
  // mengabaikan policy rutinitas.
  final policy = _commonPolicy(entries);
  return Routine(
    id: id,
    name: name,
    policy: policy,
    exercises: [
      for (final e in entries) configFromEntry(e, isAssisted: isAssisted, routinePolicy: policy)!,
    ],
  );
}

/// Ada set tercentang yang benar-benar berisi. Pemanasan yang dicentang saja
/// bukan latihan, dan baris 0 × 0 yang tercentang karena salah ketuk bukan
/// set — aturan yang sama dengan penjaga "belum ada set kerja" di editor.
bool hasDoneSet(WorkoutEntry e) => e.sets.any(_counted);

bool _counted(SetRow s) => s.done && !s.isWarmup && (s.reps > 0 || s.seconds > 0);

/// Konfigurasi rutinitas untuk satu entri sesi, atau null kalau entri itu
/// tidak punya set tercentang (lihat [hasDoneSet]).
///
/// - set = jumlah set kerja tercentang; drop set dan rest-pause (FR-D7) bukan
///   set kerja yang dinilai, jadi hanya dipakai kalau tidak ada set kerja
///   tercentang sama sekali;
/// - rep = jumlah rep yang paling sering muncul, seri dimenangkan yang lebih
///   tinggi (mode waktu: detiknya, dengan aturan yang sama);
/// - beban = yang terberat; di mesin assisted (#232) bantuan paling sedikit
///   di atas nol, karena di sana angka kecil justru lebih berat;
/// - pemanasan = jumlah baris warm-up, tercentang atau tidak — baris warm-up
///   adalah bagian susunan, bukan hasil;
/// - istirahat, mode, increment, bodyweight, superset, dan override assisted
///   serta bar (FR-D16) ikut dari target yang dibekukan ke sesi. Faktor
///   deload tidak: ia dibekukan dari setelan Profil, bukan pilihan orangnya
///   untuk gerakan ini. Rentang rep hanya ikut kalau masih berupa rentang di
///   sekitar rep yang baru — batas bawah 8 untuk target 6 bukan rentang.
///
/// [routinePolicy] adalah policy rutinitas yang akan menampungnya: policy
/// gerakan yang sama dengannya tidak ditulis sebagai override.
ExerciseConfig? configFromEntry(WorkoutEntry e, {AssistedLookup? isAssisted, ProgressionPolicy? routinePolicy}) {
  final done = [for (final s in e.sets) if (_counted(s)) s];
  if (done.isEmpty) return null;
  final work = [for (final s in done) if (s.isWork) s];
  final basis = work.isNotEmpty ? work : done;
  final t = e.target;
  final mode = t?.mode ?? LogMode.reps;
  final timed = mode == LogMode.time;
  final reps = timed ? (t?.reps ?? 10) : (_mostCommon([for (final s in basis) if (s.reps > 0) s.reps]) ?? t?.reps ?? 10);
  final seconds = timed
      ? (_mostCommon([for (final s in basis) if (s.seconds > 0) s.seconds]) ?? t?.seconds ?? 0)
      : (t?.seconds ?? 0);
  final policy = t?.policy;
  final repsMin = t?.repsMin;
  final repsMax = t?.repsMax;
  return ExerciseConfig(
    exerciseId: e.exerciseId,
    policy: policy == routinePolicy ? null : policy,
    mode: mode,
    sets: basis.length,
    reps: reps,
    repsMin: repsMin != null && repsMin < reps ? repsMin : null,
    repsMax: repsMax != null && repsMax > reps ? repsMax : null,
    weight: _load(basis, assisted: entryIsAssisted(e, isAssisted)),
    seconds: seconds,
    increment: t?.increment,
    restSeconds: t?.restSeconds,
    bodyweight: t?.bodyweight ?? false,
    heavyBodyPart: t?.heavyBodyPart ?? false,
    warmupSets: e.sets.where((s) => s.isWarmup).length,
    superset: t?.superset ?? false,
    assisted: t?.assisted,
    barWeight: t?.barWeight,
  );
}

/// Beban target: terberat, atau bantuan paling sedikit di atas nol untuk
/// assisted. Nol kalau tidak ada yang berbeban (bodyweight).
double _load(List<SetRow> basis, {required bool assisted}) {
  double? best;
  for (final s in basis) {
    if (assisted && s.weight <= 0) continue;
    if (best == null || beatsLoad(s.weight, best, assisted: assisted)) best = s.weight;
  }
  return best ?? 0;
}

/// Nilai yang paling sering muncul; seri dimenangkan yang lebih besar. null
/// untuk daftar kosong.
int? _mostCommon(List<int> values) {
  final count = <int, int>{};
  for (final v in values) {
    count[v] = (count[v] ?? 0) + 1;
  }
  int? best;
  var bestCount = 0;
  for (final MapEntry(key: v, value: n) in count.entries) {
    if (best == null || n > bestCount || (n == bestCount && v > best)) {
      best = v;
      bestCount = n;
    }
  }
  return best;
}

/// Policy yang paling sering dibekukan di target sesi ini. Seri dimenangkan
/// yang lebih dulu muncul (urutan gerakan). null kalau tidak ada target yang
/// menyebut policy — riwayat lama — dan rutinitasnya ikut default mode.
ProgressionPolicy? _commonPolicy(List<WorkoutEntry> entries) {
  final count = <ProgressionPolicy, int>{};
  for (final e in entries) {
    final p = e.target?.policy;
    if (p != null) count[p] = (count[p] ?? 0) + 1;
  }
  ProgressionPolicy? best;
  for (final MapEntry(key: p, value: n) in count.entries) {
    if (best == null || n > count[best]!) best = p;
  }
  return best;
}
