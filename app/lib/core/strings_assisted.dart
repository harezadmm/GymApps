/// Teks mesin assisted yang datang bersama v2.3 (openGym v1.3.8, issue #232):
/// catatan di detail gerakan dan kartu sesi, tri-state di editor rutinitas,
/// saklar di lembar gerakan custom, dan label rekor "bantuan tersedikit".
///
/// Dipisah dari `strings.dart` dengan alasan yang sama seperti
/// `strings_home.dart`: satu extension per area supaya pekerjaan yang berjalan
/// bersamaan tidak saling menimpa file yang sama. Pemanggilnya tetap
/// `context.t.xxx` — extension ini menempel pada [Strings]. Terjemahan alasan
/// target ("2,5 kg bantuan lebih sedikit") tidak di sini: itu tabel pola milik
/// [Strings.why], yang memang harus tinggal di sebelah tabelnya.
library;

import 'strings.dart';

extension AssistedStrings on Strings {
  String _a(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  /// Catatan kecil di detail gerakan dan kartu sesi. Satu kalimat, karena
  /// itu satu-satunya hal yang perlu diingat saat mengetik angkanya.
  String get assistedNote => _a('Load = machine help; lower is harder', 'Beban = bantuan mesin; makin kecil makin berat');

  // ── Editor rutinitas: tri-state per gerakan ──
  String get assistedLabel => _a('Assisted machine', 'Mesin assisted');
  String get assistedAuto => _a('Auto', 'Otomatis');
  String get assistedYes => _a('Assisted', 'Assisted');
  String get assistedNo => _a('Normal', 'Biasa');

  /// Apa arti "otomatis", supaya orang tahu kapan perlu memaksanya.
  String get assistedHint => _a(
        'Auto follows the catalogue: assisted pull-ups, chin-ups and dips on the lever machine. $assistedNote.',
        'Otomatis mengikuti katalog: assisted pull-up, chin-up, dan dip di mesin lever. $assistedNote.',
      );

  // ── Rekor ──
  /// Pengganti "Heaviest" untuk mesin assisted: rekornya bantuan paling sedikit.
  String get prLeastHelp => _a('Least help', 'Bantuan tersedikit');

  /// Baris rekor di ringkasan selesai. Rekor pertama tidak punya pembanding —
  /// "(was 0)" akan terbaca seolah pernah tanpa bantuan.
  String helpRecordLine(String now, String unit, String? previous) => previous == null
      ? _a('Help $now $unit', 'Bantuan $now $unit')
      : _a('Help $now $unit (was $previous)', 'Bantuan $now $unit (sebelumnya $previous)');
}
