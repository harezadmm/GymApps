/// Teks tab Home yang datang bersama v2.2 (bilah progres minggu, sheet per
/// hari, tarik-untuk-sinkron).
///
/// Dipisah dari `strings.dart` karena file itu disunting beberapa pekerjaan
/// sekaligus di rilis ini; satu extension per area membuat tiap perubahan
/// hidup di filenya sendiri dan tidak saling menimpa. Pemanggilnya tetap
/// `context.t.xxx` — extension ini menempel pada [Strings].
library;

import 'strings.dart';

extension HomeStrings on Strings {
  String _h(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  /// "2 of 3 sessions" — sesi minggu ini dibanding rencana program.
  ///
  /// Lewat dari rencana ditulis apa adanya, bukan "4 dari 3".
  String weekProgress(int done, int total) => done > total
      ? _h('$done sessions · goal $total', '$done sesi · target $total')
      : _h('$done of $total sessions', '$done dari $total sesi');

  /// Keterangan kecil di blok statistik yang bisa diketuk. Hanya tampil kalau
  /// kolomnya cukup lebar; di HP sempit ikonnya saja yang jadi petunjuk.
  String get tapForStats => _h('Tap for stats', 'Ketuk untuk statistik');
  String get tapForHistory => _h('Tap for history', 'Ketuk untuk riwayat');

  // ── Sheet satu hari dari strip minggu ──
  String get noSessionsThatDay => _h('No sessions', 'Tidak ada sesi');
  String plannedRoutine(String name) => _h('Planned: $name', 'Rencana: $name');
  String get viewHistory => _h('View history', 'Lihat riwayat');

  // ── Tarik untuk sinkron ──
  String get syncedShort => _h('Synced', 'Tersinkron');
  String get noServer => _h('No server', 'Tidak ada server');
}
