/// Mesin assisted — port dari perbaikan openGym v1.3.8, issue #232.
///
/// Di assisted pull-up / chin-up / dip, angka yang dicatat adalah **bantuan**
/// mesin, bukan beban yang diangkat: 20 kg bantuan lebih berat daripada 30.
/// Sebelum ini engine membacanya seperti barbel — "semua rep tercapai, +2,5
/// kg" berarti latihannya justru makin ringan tiap minggu, dan e1RM-nya
/// "naik" saat orangnya makin lemah.
///
/// Modul ini murni: tidak mengimpor Flutter maupun katalog. Aturan katalognya
/// hidup di sini sebagai fungsi atas (alat, nama) supaya bisa diuji tanpa
/// memuat aset 870 KB, dan `data/exercise_catalog.dart` tinggal memanggilnya.
/// Arah untuk satu entri riwayat dijawab lewat [entryIsAssisted]: target
/// yang dibekukan ke sesi menang, lalu pencarian katalog dari pemanggil,
/// lalu "bukan".
library;

import 'models.dart';

/// Aturannya sengaja sempit: alat persis `leverage machine` **dan** nama
/// memuat kata `assist`/`assisted` utuh. Itu keluarga assisted pull-up,
/// chin-up, chest dip, dan triceps dip — delapan entri katalog. Peregangan
/// dengan bantuan pasangan, band-assisted pull-up, dan self-assisted leg curl
/// memakai alat lain dan tetap dibaca normal.
final RegExp assistedNamePattern = RegExp(r'\bassist(ed)?\b', caseSensitive: false);

const assistedEquipment = 'leverage machine';

/// Apakah gerakan ini assisted. [override] eksplisit (gerakan custom, slot
/// rutinitas) menang atas aturan katalog ke dua arah.
bool isAssistedExercise({required String equipment, required String name, bool? override}) =>
    override ?? (equipment == assistedEquipment && assistedNamePattern.hasMatch(name));

/// Jawaban "apakah id ini assisted" dari lapisan yang memegang katalog. Domain
/// menerimanya sebagai fungsi supaya tidak perlu mengimpor katalog.
typedef AssistedLookup = bool Function(String exerciseId);

/// Arah satu entri riwayat: target yang dibekukan saat sesi berjalan menang —
/// itulah cara sesi itu dinilai waktu itu — lalu [lookup], lalu normal.
bool entryIsAssisted(WorkoutEntry entry, [AssistedLookup? lookup]) =>
    entry.target?.assisted ?? lookup?.call(entry.exerciseId) ?? false;

/// Arah satu gerakan di seluruh riwayat, diambil dari entri bertanggal
/// terbaru — urutan [workouts] bebas, karena lembar riwayat memegang daftar
/// terbaru-dulu sedangkan engine progresi terlama-dulu.
///
/// Bantuan mesin adalah sifat gerakan, bukan sifat sesi; rekor dibandingkan
/// dalam satu arah untuk semua sesinya. Riwayat yang bertukar arah di tengah
/// (override diubah) memang tidak bisa dibandingkan dengan jujur, dan arah
/// terbaru adalah yang sedang dipakai orangnya.
bool exerciseIsAssisted(List<Workout> workouts, String exerciseId, [AssistedLookup? lookup]) {
  WorkoutEntry? latest;
  String latestDate = '';
  for (final w in workouts) {
    if (latest != null && w.date.compareTo(latestDate) < 0) continue;
    for (final e in w.entries) {
      if (e.exerciseId != exerciseId) continue;
      latest = e;
      latestDate = w.date;
      break;
    }
  }
  return latest == null ? (lookup?.call(exerciseId) ?? false) : entryIsAssisted(latest, lookup);
}

/// Apakah [candidate] mengalahkan [record]: lebih berat untuk gerakan biasa,
/// lebih *sedikit* bantuan untuk assisted.
bool beatsLoad(double candidate, double record, {required bool assisted}) =>
    assisted ? candidate < record : candidate > record;

/// Beban rekor satu entri: tertinggi untuk gerakan biasa, terendah di atas
/// nol untuk assisted. Nol berarti beban tidak diisi, bukan "tanpa bantuan"
/// — dan tidak pernah jadi rekor. null kalau tidak ada set kerja tercentang
/// yang berbeban.
double? recordLoadOf(WorkoutEntry entry, {required bool assisted}) {
  double? best;
  for (final s in entry.sets) {
    if (!s.done || s.isWarmup || s.weight <= 0) continue;
    if (best == null || beatsLoad(s.weight, best, assisted: assisted)) best = s.weight;
  }
  return best;
}

/// Rekor beban sepanjang riwayat beserta tanggalnya. Urutan [workouts] bebas;
/// rekor yang sama persis dipegang tanggal yang pertama ditemui.
({double load, String date})? bestLoad(List<Workout> workouts, String exerciseId, {required bool assisted}) {
  ({double load, String date})? best;
  for (final w in workouts) {
    for (final e in w.entries) {
      if (e.exerciseId != exerciseId) continue;
      final load = recordLoadOf(e, assisted: assisted);
      if (load == null) continue;
      if (best == null || beatsLoad(load, best.load, assisted: assisted)) best = (load: load, date: w.date);
    }
  }
  return best;
}

/// Rekor beban yang baru dipecahkan: bantuan paling sedikit untuk assisted.
class LoadRecord {
  const LoadRecord({required this.now, required this.previous});
  final double now;

  /// Rekor sebelumnya, null kalau ini yang pertama.
  final double? previous;
}

/// Apakah [entry] memecahkan rekor beban gerakan ini? Seperti `is1RMRecord`,
/// [workouts] harus riwayat yang **belum** memuat sesi berjalan.
LoadRecord? isLoadRecord(List<Workout> workouts, String exerciseId, WorkoutEntry entry, {AssistedLookup? isAssisted}) {
  final assisted = entryIsAssisted(entry, isAssisted);
  final now = recordLoadOf(entry, assisted: assisted);
  if (now == null) return null;
  final prev = bestLoad(workouts, exerciseId, assisted: assisted)?.load;
  if (prev != null && !beatsLoad(now, prev, assisted: assisted)) return null;
  return LoadRecord(now: now, previous: prev);
}
