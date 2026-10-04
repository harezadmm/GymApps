/// Teks yang datang bersama UI v3 "Bevel glass": tab bar baru, pil status
/// Beranda, kartu cincin dan insight, lembar Mulai sesi, tab Program, dan
/// label grup di Profil.
///
/// Satu extension per rilis, seperti `strings_home.dart`: pemanggilnya tetap
/// `context.t.xxx`. Teks Indonesia mengikuti mockup Pen kata demi kata.
library;

import 'strings.dart';

extension V3Strings on Strings {
  String _v(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  // ── Tab bar ──
  String get homeTab => _v('Home', 'Beranda');
  String get historyTab => _v('History', 'Riwayat');
  String get programTab => _v('Program', 'Program');
  String get statsTab => _v('Stats', 'Statistik');
  String get startTab => _v('Start', 'Mulai');

  // ── Beranda ──
  String get nextSessionTitle => _v('Next session', 'Sesi berikutnya');
  String get pickOther => _v('Pick another', 'Pilih lain');
  String get strengthProgress => _v('Strength progress', 'Progres kekuatan');
  String get seeAllShort => _v('All', 'Semua');
  String get ringSessions => _v('Sessions this week', 'Sesi minggu ini');
  String get ringSets => _v('Working sets', 'Set kerja');
  String get ringVolume => _v('Volume vs last', 'Volume vs lalu');
  String get syncedPill => _v('Synced', 'Tersinkron');
  String get syncNotYet => _v('Not synced', 'Belum sinkron');
  String get syncNoServerPill => _v('No server', 'Tanpa server');
  String get justNow => _v('just now', 'baru saja');
  String minutesAgo(int n) => _v('$n min ago', '$n menit lalu');
  String hoursAgo(int n) => _v('$n h ago', '$n jam lalu');
  String daysAgoShort(int n) => _v('$n days ago', '$n hari lalu');
  String rotationCount(int n) => _v('Rotation · $n routines', 'Rotasi · $n rutinitas');
  String weekdayCount(String days) => _v('Fixed days · $days', 'Hari tetap · $days');
  String get pickProgramPill => _v('Pick a program', 'Pilih program');
  String moreExercises(int n) => _v('+$n more', '+$n lagi');
  String get strengthNoData => _v('No strength data yet', 'Belum ada data kekuatan');

  // ── Lembar Mulai sesi ──
  String get startSheetTitle => _v('Start a session', 'Mulai sesi');
  String startSheetNextRotation(String routine) =>
      _v('$routine is next in the rotation', '$routine adalah sesi berikutnya di rotasi');
  String startSheetNextToday(String routine) => _v('$routine is scheduled today', '$routine dijadwalkan hari ini');
  String get startSheetNoProgram => _v('No program yet — start freestyle', 'Belum ada program — mulai sesi bebas');
  String get freestyleRow => _v('Freestyle session', 'Sesi bebas');
  String get freestyleRowSub => _v('Add exercises as you go', 'Tambah gerakan sambil jalan');
  String get programRoutinesLabel => _v('PROGRAM ROUTINES', 'RUTINITAS PROGRAM');
  String get otherRoutinesLabel => _v('OTHER ROUTINES', 'RUTINITAS LAIN');
  String get logPastRow => _v('Log a past session', 'Catat sesi yang sudah lewat');

  // ── Sesi ──
  String get exerciseHistoryBtn => _v('Exercise history', 'Riwayat gerakan');
  String get supersetBtn => _v('Superset', 'Superset');
  String get endSupersetBtn => _v('End superset', 'Akhiri superset');
  String get restWord => _v('Rest', 'Istirahat');

  // ── Ringkasan ──
  String get totalReps => _v('Total reps', 'Total rep');
  String get targetsUp => _v('Targets up', 'Target naik');
  String get newRecordsTitle => _v('New records', 'Rekor baru');
  String get heaviestSet => _v('heaviest set', 'beban terberat');
  String get holdTag => _v('hold', 'tahan');
  String get newTag => _v('new', 'baru');
  String get deloadTag => _v('deload', 'deload');
  String get undoLink => _v('Undo', 'Batalkan');
  String get saveLink => _v('Save', 'Simpan');
  String get saveAgainLink => _v('Save again', 'Simpan lagi');

  // ── Riwayat ──
  String sessionsThisYearV3(int n) => _v('$n sessions this year', '$n sesi tahun ini');
  String minutesShort(int n) => _v('$n min', '$n mnt');

  // ── Program ──
  String get libraryButton => _v('Exercise library', 'Library gerakan');
  String get activeProgramKicker => _v('ACTIVE PROGRAM', 'PROGRAM AKTIF');
  String get skipSessionBtn => _v('Skip session', 'Lewati sesi');
  String get reorder => _v('Reorder', 'Urutkan');
  String get addRoutineCard => _v('Add routine', 'Tambah rutinitas');
  String get programRules => _v('Program rules', 'Aturan program');
  String get modeLabel => _v('Mode', 'Mode');
  String get minRestBetween => _v('Minimum rest between sessions', 'Istirahat minimum antar sesi');
  String daysValue(int n) => _v('$n days', '$n hari');
  String routineMetaComma(int exercises, int sets) =>
      _v('$exercises exercises, $sets sets', '$exercises gerakan, $sets set');

  // ── Profil ──
  String get profileNav => _v('Profile', 'Profil');
  String get groupTraining => _v('TRAINING', 'LATIHAN');
  String get groupAppearance => _v('APPEARANCE', 'TAMPILAN');
  String get groupDataAccount => _v('DATA & ACCOUNT', 'DATA & AKUN');
  String get weightUnitRow => _v('Weight unit', 'Satuan berat');
  String get logRirRow => _v('Log RIR', 'Catat RIR');
  String get restPushRow => _v('Rest notifications', 'Notifikasi istirahat');
  String get weekStartsRow => _v('Week starts', 'Minggu dimulai');
  String get forceSyncRow => _v('Force sync', 'Paksa sinkron');
  String get aboutRow => _v('About the app', 'Tentang aplikasi');
  String get logOutRow => _v('Log out', 'Keluar');

  // ── Statistik ──
  String oneRmShort(String value) => '1RM $value';
  String setsPerWeekSub(int weeks) => _v('Working sets per week, $weeks weeks', 'Set kerja per minggu, $weeks minggu');
  String avgSets(int n) => _v('avg $n sets', 'rata-rata $n set');
  String pctOverWeeks(String pct, int weeks) => _v('$pct · $weeks wk', '$pct · $weeks mgg');
  String bwDelta(String delta, int days) => _v('$delta / $days days', '$delta / $days hari');
  String get logShort => _v('Log', 'Catat');

  // ── Insight Beranda (spec §8) ──
  String get insightNoProgram => _v('No program yet', 'Belum ada program');
  String get insightNoProgramBody =>
      _v('Pick a program so the next session plans itself.', 'Pilih program supaya sesi berikutnya tersusun sendiri.');
  String get insightRecovery => _v('Recovery day', 'Hari pemulihan');
  String insightRecoveryBody(String routine, String day, String since) =>
      _v('$routine falls on $day. $since', '$routine jatuh pada $day. $since');
  String get insightRestDay => _v('Rest day', 'Hari istirahat');
  String insightRestDayBody(String day, String routine) =>
      _v('Next training day $day: $routine.', 'Latihan berikutnya $day: $routine.');
  String insightUp(String routine, int n) => _v(
        '$routine today, ${numberWord(n)} ${n == 1 ? 'exercise' : 'exercises'} ready to go up',
        '$routine hari ini, ${numberWord(n)} gerakan siap naik',
      );
  String insightUpBody(String since, String names) =>
      _v('$since $names go up this session.', '$since $names naik targetnya sesi ini.');
  String insightHold(String routine) => _v('$routine today, chase the reps', '$routine hari ini, kejar rep');
  String insightHoldBody(String since) => _v(
        '$since Weight held — fill the rep range and the load goes up next.',
        '$since Beban dipertahankan — penuhi rentang rep, beban naik sesudahnya.',
      );
  String insightDeload(String routine) =>
      _v('$routine today, one exercise deloaded', '$routine hari ini, satu gerakan diturunkan');
  String insightDeloadBody(String name) => _v(
        '$name is deloaded after a few missed sessions; the rest hold.',
        '$name di-deload setelah beberapa sesi gagal; selebihnya tetap.',
      );
  String get neverTrained => _v('Never trained yet.', 'Belum pernah dilatih.');
  String lastTrainedSentence(int days) => switch (days) {
        0 => _v('Last trained today.', 'Terakhir dilatih hari ini.'),
        1 => _v('Last trained yesterday.', 'Terakhir dilatih kemarin.'),
        _ => _v('Last trained $days days ago.', 'Terakhir dilatih $days hari lalu.'),
      };

  /// 1–9 ditulis dengan kata ("dua"/"two"), selebihnya angka.
  String numberWord(int n) {
    const idWords = ['nol', 'satu', 'dua', 'tiga', 'empat', 'lima', 'enam', 'tujuh', 'delapan', 'sembilan'];
    const enWords = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'];
    if (n < 0 || n > 9) return '$n';
    return lang == AppLanguage.indonesian ? idWords[n] : enWords[n];
  }

  /// "A dan B", "A, B, dan C" — mengikuti bahasa aktif.
  String andJoin(List<String> items) {
    final and = _v('and', 'dan');
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} $and ${items[1]}';
    return '${items.sublist(0, items.length - 1).join(', ')}, $and ${items.last}';
  }
}
