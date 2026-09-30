/// Teks gambar dan animasi gerakan (FR-C1): saklar di Profil, placeholder
/// animasi di detail library, dan tombol coba lagi saat katalog gagal dibaca.
///
/// Dipisah dari `strings.dart` dengan alasan yang sama seperti
/// `strings_home.dart`: satu extension per area, supaya pekerjaan rilis ini
/// tidak saling menimpa di satu file. Pemanggilnya tetap `context.t.xxx` —
/// extension ini menempel pada [Strings].
library;

import 'strings.dart';

extension MediaStrings on Strings {
  String _m(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  // ── Profil ──
  String get showExerciseMedia => _m('Exercise images & animations', 'Gambar & animasi gerakan');

  /// Satu kalimat di bawah saklarnya: dari mana datangnya dan kapan tidak
  /// ada — supaya "tidak ada gambar" saat offline tidak dibaca sebagai bug.
  String get exerciseMediaNote => _m(
        'Downloaded from the internet when shown; skipped while offline.',
        'Diunduh dari internet saat ditampilkan; dilewati saat offline.',
      );

  // ── Detail gerakan ──
  /// Label pembaca layar untuk animasi (NFR-11). Gambar diam — saat sistem
  /// meminta gerak dikurangi — memakai label yang sama: isinya sama, gerakan
  /// yang diperagakan.
  String demonstrationOf(String name) => _m('Demonstration of $name', 'Peragaan $name');

  /// Placeholder saat animasinya gagal dimuat. Tanpa nada galat: offline
  /// bukan kesalahan siapa-siapa, dan detail lainnya tetap ada.
  String get animationUnavailable => _m('Animation unavailable offline', 'Animasi tidak tersedia saat offline');

  // ── Katalog gagal dibaca ──
  String get tryAgain => _m('Try again', 'Coba lagi');
}
