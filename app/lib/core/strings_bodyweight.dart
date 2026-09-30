/// Teks target berat badan (FR-F4): tombol dan dialog di kartu berat badan,
/// label garis target di grafik, dan keterangan "x kg lagi" di bawah angka.
///
/// Dipisah dari `strings.dart` dengan alasan yang sama seperti
/// `strings_home.dart`: satu extension per pekerjaan supaya rilis ini tidak
/// saling menimpa satu file. Pemanggilnya tetap `context.t.xxx` — extension
/// ini menempel pada [Strings].
///
/// Angka di sini memakai titik desimal seperti teks lain di kartu yang sama
/// ("78.4 kg" lewat `context.wUnit`), bukan koma seperti teks pelat: satu
/// kartu tidak boleh menulis 78.4 di atas dan 3,4 di bawahnya.
library;

import 'strings.dart';

extension BodyweightStrings on Strings {
  String _b(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  /// Judul dialog target.
  String get bodyweightTargetTitle => _b('Bodyweight target', 'Target berat badan');

  /// Tombol di kartu saat belum ada target.
  String get setBodyweightTarget => _b('Set target', 'Atur target');

  /// Tombol di kartu saat target sudah ada: angkanya yang ditulis, supaya
  /// targetnya terbaca tanpa membuka dialog. [w] sudah bersatuan ("75 kg").
  String targetButton(String w) => _b('Target $w', 'Target $w');

  String get bodyweightTargetHint => _b(
        'A dashed line marks the target on the chart, and the latest entry is '
            'coloured by whether you are moving toward it.',
        'Garis putus-putus menandai target di grafik, dan catatan terakhir '
            'diwarnai menurut arahnya: mendekat atau menjauh.',
      );

  /// Menghapus target, bukan mengosongkan angkanya ke nol — nol bukan target.
  String get clearBodyweightTarget => _b('Clear target', 'Hapus target');

  /// Label kecil di ujung garis target pada grafik: "target 75 kg".
  String targetLineLabel(String w) => _b('target $w', 'target $w');

  /// "3.4 kg to go" / "3.4 kg lagi" — [w] sudah bersatuan.
  String toGo(String w) => _b('$w to go', '$w lagi');

  /// Dalam setengah satuan tampilan dari target — angka sisanya tidak
  /// ditulis lagi, "0.3 kg to go" hanya mengundang orang mengejar timbangan.
  String get onTarget => _b('On target', 'Sudah di target');
}
