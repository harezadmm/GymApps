/// Teks hitung mundur istirahat di notifikasi (FR-H3): baris senyap yang
/// menempel di layar terkunci selama istirahat berjalan.
///
/// Dipisah dari `strings.dart` dengan alasan yang sama seperti
/// `strings_home.dart`: satu extension per area supaya pekerjaan rilis ini
/// tidak saling menimpa satu file. Pemanggilnya tetap `context.t.xxx` —
/// extension ini menempel pada [Strings].
library;

import 'strings.dart';

extension RestStrings on Strings {
  String _r(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  /// Judul baris hitung mundur. Angkanya digambar sistem di sebelah nama
  /// aplikasi (chronometer), jadi judulnya cukup menyebut apa yang sedang
  /// dihitung, bukan mengulang angkanya.
  String get restCountdownTitle => _r('Resting', 'Sedang istirahat');

  /// "Bench Press — Next: set 3 · 72.5 kg × 8": gerakan yang sedang
  /// diistirahatkan dan set berikutnya, supaya dari layar terkunci orang tahu
  /// mau angkat apa tanpa membuka aplikasi. [next] sudah dalam bahasa yang
  /// dipilih. Yang kosong dilewati: set terakhir hanya menyebut gerakannya.
  String restCountdownBody(String exercise, String next) => [exercise, next].where((s) => s.isNotEmpty).join(' — ');
}
