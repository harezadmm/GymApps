/// Penjadwal program (FR-B2 sampai FR-B5): sesi mana berikutnya, kapan jatuh
/// temponya, dan bagaimana cursor bergeser.
///
/// Semuanya fungsi murni atas [Program], daftar [Routine], dan riwayat. Tidak
/// ada yang disimpan di sini — sama seperti mesin progresi, "berikutnya apa"
/// selalu dihitung ulang dari fakta yang tercatat.
library;

import 'models.dart';

/// Tanggal kalender tanpa jam, supaya selisih hari tidak terganggu jam dan
/// pergantian waktu musim panas.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `YYYY-MM-DD`, bentuk yang dipakai [Workout.date].
String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _parseIso(String s) {
  final p = s.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Sesi yang disarankan berikutnya.
class NextSession {
  const NextSession({required this.routine, required this.due, required this.today});

  final Routine routine;

  /// Hari sesi ini jatuh tempo. Tidak pernah sebelum [today].
  final DateTime due;

  final DateTime today;

  /// Belum waktunya — masih dalam masa istirahat (rotasi) atau bukan hari
  /// latihan (weekday). Tetap boleh dimulai: ini saran, bukan kunci (FR-B5).
  bool get early => due.isAfter(today);

  /// Selisih hari dari hari ini.
  int get daysAway => due.difference(today).inDays;
}

/// Rutinitas program dalam urutan sesinya. Id yang tidak lagi ada dilewati.
List<Routine> programRoutines(Program program, List<Routine> routines) {
  final byId = {for (final r in routines) r.id: r};
  return [
    for (final id in program.order)
      if (byId[id] != null) byId[id]!,
  ];
}

/// Tanggal latihan terakhir di riwayat, atau null kalau belum pernah.
DateTime? lastTrainingDay(List<Workout> history) {
  DateTime? last;
  for (final w in history) {
    final d = _parseIso(w.date);
    if (d != null && (last == null || d.isAfter(last))) last = d;
  }
  return last;
}

/// Hitung sesi berikutnya. null kalau program belum punya rutinitas.
NextSession? nextSession({
  required Program program,
  required List<Routine> routines,
  required List<Workout> history,
  required DateTime today,
}) {
  final list = programRoutines(program, routines);
  if (list.isEmpty) return null;
  final day = dateOnly(today);

  if (program.mode == ProgramMode.weekday && program.days.isNotEmpty) {
    return _weekday(program, list, history, day);
  }

  final routine = list[program.cursor % list.length];
  final last = lastTrainingDay(history);
  var due = day;
  if (last != null && program.minRestDays > 0) {
    final earliest = last.add(Duration(days: program.minRestDays));
    if (earliest.isAfter(due)) due = earliest;
  }
  return NextSession(routine: routine, due: due, today: day);
}

NextSession? _weekday(Program program, List<Routine> list, List<Workout> history, DateTime day) {
  final days = [...program.days]..sort();
  final trainedToday = history.any((w) => w.date == isoDate(day));

  // Dua minggu cukup: satu minggu penuh selalu memuat setiap hari latihan,
  // minggu kedua menampung kasus hari ini dilewati dan besoknya juga dilewati.
  for (var offset = 0; offset < 14; offset++) {
    final d = day.add(Duration(days: offset));
    final slot = days.indexOf(d.weekday);
    if (slot < 0) continue;
    if (offset == 0 && trainedToday) continue;
    if (program.skippedOn == isoDate(d)) continue;
    return NextSession(routine: list[slot % list.length], due: d, today: day);
  }
  return null;
}

/// Program setelah sebuah sesi dari rutinitas [routineId] selesai.
///
/// Mode rotasi: cursor pindah ke setelah rutinitas yang **benar-benar**
/// dijalankan, bukan sekadar maju satu — memilih Push secara manual saat cursor
/// di Legs membuat berikutnya Pull (FR-B4). Sesi di luar program (freestyle)
/// tidak menggeser apa pun.
Program advanceAfter(Program program, String? routineId) {
  if (routineId == null) return program;
  final idx = program.order.indexOf(routineId);
  if (idx < 0) return program;
  if (program.mode == ProgramMode.weekday) return program.copyWith(clearSkip: true);
  return program.copyWith(cursor: (idx + 1) % program.order.length, clearSkip: true);
}

/// Lewati sesi berikutnya tanpa mencatat apa pun (FR-B4).
Program skipNextIn(Program program, NextSession next) {
  if (program.mode == ProgramMode.weekday && program.days.isNotEmpty) {
    return program.copyWith(skippedOn: isoDate(next.due));
  }
  if (program.order.isEmpty) return program;
  return program.copyWith(cursor: (program.cursor + 1) % program.order.length);
}

/// Hari-hari (1 = Senin … 7 = Minggu) yang dipegang satu rutinitas di mode
/// weekday. Kosong di mode rotasi.
List<int> weekdaysOf(Program program, List<Routine> routines, String routineId) {
  if (program.mode != ProgramMode.weekday || program.days.isEmpty) return const [];
  final list = programRoutines(program, routines);
  if (list.isEmpty) return const [];
  final days = [...program.days]..sort();
  return [
    for (final (i, d) in days.indexed)
      if (list[i % list.length].id == routineId) d,
  ];
}
