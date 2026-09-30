/// Teks editor rutinitas yang datang bersama v2.3 (rutinitas deload, FR-B10).
///
/// Dipisah dari `strings.dart` dengan alasan yang sama seperti
/// `strings_home.dart`: satu extension per area supaya pekerjaan yang berjalan
/// bersamaan tidak saling menimpa file yang sama. Pemanggilnya tetap
/// `context.t.xxx` — extension ini menempel pada [Strings].
library;

import 'strings.dart';

extension RoutineStrings on Strings {
  String _r(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  /// Saklar di editor rutinitas: rutinitas ini minggu deload terencana.
  String get excludeFromProgression => _r('Exclude from progression', 'Kecualikan dari progresi');

  /// Satu kalimat di bawah saklar — apa yang tetap dan apa yang berhenti.
  /// "Riwayat dan statistik" disebut supaya orang tidak mengira sesinya hilang.
  String get excludeFromProgressionHint => _r(
        'Planned deload: sessions stay in history and stats, but never move the next target.',
        'Deload terencana: sesi tetap masuk riwayat dan statistik, tapi tidak menggeser target berikutnya.',
      );
}
