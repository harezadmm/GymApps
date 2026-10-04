/// Teks layar sesi v2.2: lembar konfirmasi selesai dan kartu status
/// rutinitas di ringkasan. Dipisah dari `strings.dart` supaya beberapa area
/// bisa menambah teks bersamaan tanpa saling menimpa satu file raksasa.
library;

import '../domain/routine_sync.dart';
import 'strings.dart';

extension SessionStrings on Strings {
  bool get _id => lang == AppLanguage.indonesian;

  // ── Lembar konfirmasi selesai ───────────────────────────────────────────
  String get finishConfirmTitle => _id ? 'Selesaikan sesi?' : 'Finish this session?';
  String get workingSetsLabel => _id ? 'Set kerja' : 'Working sets';
  String unfinishedSets(int n) => _id ? '$n set belum dicentang' : (n == 1 ? '1 set not ticked' : '$n sets not ticked');
  String unfinishedSetsNote(int n) => _id
      ? '${unfinishedSets(n)} — akan tersimpan sebagai tidak dikerjakan'
      : '${unfinishedSets(n)} — they will be saved as not done';

  /// Inti keluhan pengguna: tombol selesai ditekan untuk "menyelesaikan
  /// timer", padahal yang tertutup sesinya. Kalimat ini menyebut keduanya
  /// dengan nama supaya tidak tertukar lagi.
  String get finishRestNote => _id
      ? 'Istirahat masih berjalan. Tombol ini menutup SESI, bukan timer. Untuk melewati istirahat, ketuk ✕ di kapsul timer.'
      : 'Rest is still running. This button ends the SESSION, not the timer. To skip the rest, tap ✕ on the timer capsule.';
  String saveLayoutTo(String routine) => _id ? 'Simpan susunan ini ke rutinitas $routine' : 'Save this layout to $routine';
  String get backToSessionUpper => _id ? 'Kembali ke sesi' : 'Back to session';

  // ── Sesi yang tertinggal (draft) ───────────────────────────────────────
  String get draftRestored => _id
      ? 'Sesi yang belum selesai dibuka lagi. Lanjutkan dari set terakhir.'
      : 'Unfinished session restored. Pick up from your last set.';
  String get draftExistsTitle => _id ? 'Ada sesi yang belum selesai' : 'Unfinished session';
  String draftExistsBody(String name, int sets, int minutes) => _id
      ? 'Sesi "$name" masih berjalan ($sets set tercatat, $minutes menit). Lanjutkan sesi itu, atau buang lalu mulai yang baru?'
      : '"$name" is still in progress ($sets sets logged, $minutes min). Continue it, or discard it and start a new one?';
  String get continueUpper => _id ? 'Lanjutkan' : 'Continue';
  String get discardAndStart => _id ? 'Buang & mulai baru' : 'Discard & start new';

  // ── Rutinitas mengikuti sesi terakhirnya (v2.5) ─────────────────────────
  /// Diumumkan sekali, saat rencana lama mengambil susunan sesi terakhir tiap
  /// rutinitas — susunan yang berubah sendiri tanpa disebut terasa seperti
  /// sulap.
  String routinesFollowLastSession(List<String> names) {
    final list = names.join(', ');
    if (names.length == 1) {
      return _id ? '$list sekarang memakai susunan sesi terakhirmu.' : '$list now uses the layout of your last session.';
    }
    return _id
        ? '$list sekarang memakai susunan sesi terakhir masing-masing.'
        : '$list now use the layouts of their last sessions.';
  }

  // ── Kartu status rutinitas di ringkasan ─────────────────────────────────
  String routineUpdatedTitle(String routine) => _id ? 'Rutinitas $routine diperbarui' : 'Routine $routine updated';
  String routineRevertedTitle(String routine) => _id ? 'Rutinitas $routine dikembalikan' : 'Routine $routine reverted';
  String get layoutNotSaved =>
      _id ? 'Susunan sesi ini tidak disimpan ke rutinitas' : "This session's layout was not saved to the routine";
  String get saveToRoutine => _id ? 'Simpan ke rutinitas' : 'Save to routine';
  String get revertUpper => _id ? 'Batalkan' : 'Undo';
  String get reverted => _id ? 'Dikembalikan' : 'Reverted';

  // ── Ringkasan selisih ───────────────────────────────────────────────────
  String setsChangedLine(String name, int from, int to) => _id ? '$name $from→$to set' : '$name $from→$to sets';
  String get orderChanged => _id ? 'urutan berubah' : 'order changed';
  String get noLayoutChanges => _id ? 'Tidak ada perubahan' : 'No changes';

  /// "+ Cable Fly · − Dips · Bench Press 3→4 set". [nameOf] memetakan id
  /// gerakan ke namanya; gerakan yang dibuang tidak ada lagi di sesi, jadi
  /// namanya harus datang dari katalog.
  String routineDiffSummary(RoutineDiff diff, String Function(String exerciseId) nameOf) {
    final parts = <String>[
      for (final id in diff.added) '+ ${nameOf(id)}',
      for (final id in diff.removed) '− ${nameOf(id)}',
      for (final (id, from, to) in diff.setChanges) setsChangedLine(nameOf(id), from, to),
      if (diff.reordered) orderChanged,
    ];
    return parts.isEmpty ? noLayoutChanges : parts.join(' · ');
  }
}
