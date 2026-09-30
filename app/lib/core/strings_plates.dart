/// Teks hitung pelat (FR-D16): grup "Barbel & pelat" di Profil, baris dan
/// lembar pelat di kartu sesi, dan bar per gerakan di editor rutinitas.
///
/// Dipisah dari `strings.dart` dengan alasan yang sama seperti
/// `strings_home.dart`: satu extension per area supaya pekerjaan rilis ini
/// tidak saling menimpa satu file. Pemanggilnya tetap `context.t.xxx` —
/// extension ini menempel pada [Strings].
library;

import 'format.dart';
import 'strings.dart';

extension PlateStrings on Strings {
  String _p(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  /// Angka pelat dan bar: "2.5" di Inggris, "2,5" di Indonesia. Tabel set
  /// dan alasan target tetap memakai titik karena angkanya dibaca balik oleh
  /// kotak input dan pola terjemahan; teks di sini hanya dibaca orang.
  String plateNum(double v) =>
      lang == AppLanguage.indonesian ? formatDelta(v).replaceAll('.', ',') : formatDelta(v);

  /// "20 + 5 + 2.5" — pelat satu sisi, terberat dulu.
  String plateList(List<double> perSide) => [for (final p in perSide) plateNum(p)].join(' + ');

  /// "per side: 20 + 5 + 2.5" / "per sisi: 20 + 5 + 2,5".
  String perSide(String list) => _p('per side: $list', 'per sisi: $list');

  /// "30 kg per side" — kriteria penerimaan FR-D16 secara harfiah.
  String perSideTotal(String w) => _p('$w per side', '$w per sisi');

  /// "20 kg" / "2,5 kg".
  String weightUnit(double v, String unit) => '${plateNum(v)} $unit';

  // ── Profil ──
  String get plateSettingsTitle => _p('Barbell & plates', 'Barbel & pelat');
  String get barWeight => _p('Bar weight', 'Berat bar');
  String get noBar => _p('No bar', 'Tanpa bar');
  String get barWeightHint => _p(
        'Weight of the empty bar. Smith machines and plate-loaded machines count from zero.',
        'Berat bar kosong. Smith machine dan mesin berpelat dihitung dari nol.',
      );
  String get useDefault => _p('Default', 'Bawaan');
  String get platesAvailable => _p('Plates available', 'Pelat yang ada');
  String plateSizes(int n) => _p(n == 1 ? '1 size' : '$n sizes', '$n ukuran');
  String get platesNote => _p(
        'Tap the sizes your gym has. Plate math assumes a pair of each.',
        'Ketuk ukuran yang ada di gym-mu. Hitung pelat menganggap tiap ukuran ada sepasang.',
      );
  String get useDefaultPlates => _p('Use default plates', 'Pakai pelat bawaan');
  String get plateSettingsNote => _p(
        'Used by "Plates" on barbell exercises in a session. A bar per exercise can be set in the routine editor.',
        'Dipakai baris "Pelat" pada gerakan barbel di sesi. Bar per gerakan bisa diatur di editor rutinitas.',
      );

  // ── Sesi ──
  String get plates => _p('Plates', 'Pelat');

  /// Tooltip dan label pembaca layar baris pelat di kartu gerakan (NFR-11).
  String get showPlates => _p('Show plates per side', 'Lihat pelat per sisi');
  String barLine(String bar) => _p('Bar $bar', 'Bar $bar');
  String get noBarLine => _p('No bar — counted from zero', 'Tanpa bar — dihitung dari nol');
  String platesLine(String list) => _p('Plates: $list', 'Pelat: $list');
  String get emptyBar => _p('Empty bar', 'Bar kosong');
  String lighterThanBar(String bar) => _p('Lighter than the bar ($bar)', 'Lebih ringan dari bar ($bar)');

  /// Beban tidak bisa dibangun persis dari pelat yang ada — disebut mana
  /// yang terdekat dan berapa kurangnya, supaya orangnya bisa memutuskan
  /// sendiri: pakai yang terdekat, atau cari microplate.
  String notExact(String closest, String short) => _p(
        'Not exact with these plates — closest $closest ($short short)',
        'Tidak pas dengan pelat ini — terdekat $closest (kurang $short)',
      );
  String get noWeightYet => _p('No weight entered yet', 'Beban belum diisi');
  String get noWorkSetsForPlates => _p('No working sets to load.', 'Tidak ada set kerja untuk dimuat.');
  String get platesSheetHint => _p(
        'Bar and plates: Profile → Barbell & plates. Bar for this exercise only: routine editor.',
        'Bar dan pelat: Profil → Barbel & pelat. Bar khusus gerakan ini: editor rutinitas.',
      );

  // ── Editor rutinitas ──
  String get barWeightLabel => _p('Bar for plate math', 'Bar untuk hitung pelat');
  String barGlobal(String bar) => _p('Global · $bar', 'Global · $bar');
  String get barOverrideHint => _p(
        'Global follows Profile; Smith machine and sled count from zero unless set here.',
        'Global mengikuti Profil; Smith machine dan sled dihitung dari nol kecuali diatur di sini.',
      );
}
