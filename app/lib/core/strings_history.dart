/// Teks untuk riwayat: catat sesi lampau, lanjutkan sesi yang terlanjur
/// diselesaikan, hapus dengan urungkan.
///
/// Dipisah dari `strings.dart` supaya area riwayat bisa menambah teksnya
/// sendiri tanpa menyentuh berkas bersama yang disunting banyak fitur
/// sekaligus. Pemanggilnya tetap `context.t.xxx` — extension ini menempel ke
/// [Strings], bukan kelas baru.
library;

import 'strings.dart';

extension HistoryStrings on Strings {
  String _h(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  // ── Tombol + di header ─────────────────────────────────────────────────
  String get newSessionTitle => _h('New session', 'Sesi baru');
  String get startFreestyleNow => _h('Start a freestyle session now', 'Mulai sesi bebas sekarang');
  String get logPastSession => _h('Log a past session', 'Catat sesi yang sudah lewat');
  String get logSession => _h('Log a session', 'Catat sesi');
  String get sessionLogged => _h('Session logged.', 'Sesi dicatat.');

  // ── Lanjutkan sesi ─────────────────────────────────────────────────────
  String get resumeSession => _h('RESUME SESSION', 'LANJUTKAN SESI');
  String get resumeSessionTitle => _h('Resume this session?', 'Lanjutkan sesi ini?');
  String get resumeSessionHint => _h(
        'Reopens as a live session with its logged sets. The history entry is replaced only when you finish it again; leaving without finishing keeps the original.',
        'Dibuka lagi sebagai sesi berjalan beserta set yang tercatat. Catatan di riwayat baru diganti saat kamu menyelesaikannya lagi; keluar tanpa selesai membiarkan yang asli.',
      );

  // ── Hapus + urungkan ───────────────────────────────────────────────────
  String get deleteSessionTitle => _h('Delete this session?', 'Hapus sesi ini?');
  String get sessionDeleted => _h('Session deleted.', 'Sesi dihapus.');
  String get undo => _h('UNDO', 'URUNGKAN');

  // ── Pakai susunan sesi untuk rutinitas (v2.5) ──────────────────────────
  String get useLayoutForRoutine => _h('USE THIS LAYOUT FOR A ROUTINE', 'PAKAI SUSUNAN INI UNTUK RUTINITAS');
  String get useLayoutHint => _h(
        'The routine takes these exercises and set counts. Weights keep progressing from your history.',
        'Rutinitasnya memakai gerakan dan jumlah set ini. Beban tetap naik dari riwayatmu.',
      );
  String get pickRoutineTitle => _h('Use for which routine?', 'Pakai untuk rutinitas yang mana?');
  /// Nilai di kanan baris pilihan: isi rutinitas sekarang, atau "sudah sama".
  String routineExerciseCount(int n) => _h(n == 1 ? '1 exercise' : '$n exercises', '$n gerakan');
  String get sameAsThisSession => _h('Matches', 'Sudah sama');
  String routineFollowsSession(String routine) =>
      _h('$routine now follows this session.', '$routine sekarang mengikuti sesi ini.');
  String routineAlreadyMatches(String routine) =>
      _h('$routine already matches this session.', '$routine sudah sama dengan sesi ini.');

  // ── Editor sesi ────────────────────────────────────────────────────────
  String get routineLabel => _h('Routine', 'Rutinitas');
  String get dateLabel => _h('Date', 'Tanggal');
  String get removeExerciseTitle => _h('Remove this exercise?', 'Hapus gerakan ini?');
  String removeExerciseBody(int n) => _h(
        n == 1 ? '1 ticked set will be lost.' : '$n ticked sets will be lost.',
        '$n set tercentang akan hilang.',
      );

  // ── Keluar dari editor tanpa menyimpan ─────────────────────────────────
  String get discardLogTitle => _h('Discard this session?', 'Buang sesi ini?');
  String get discardEditsTitle => _h('Discard your changes?', 'Buang perubahanmu?');
  String get discardEditsBody => _h(
        "What you typed here hasn't been saved yet.",
        'Yang kamu ketik di sini belum disimpan.',
      );
  String get keepEditing => _h('Keep editing', 'Lanjut menyunting');

  /// Nama bulan penuh untuk label pemisah di daftar riwayat.
  String monthLong(int m) => _h(
        const [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December',
        ][m - 1],
        const [
          'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
          'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
        ][m - 1],
      );
}
