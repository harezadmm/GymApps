/// Pemformatan angka yang dipakai lintas lapisan.
///
/// Tidak mengimpor Flutter: lapisan domain ikut memakainya untuk menyusun teks
/// alasan target, dan domain tidak boleh bergantung pada widget.
library;

/// Beban sebagai teks: `72.5`, `65`, `BW`.
///
/// Angka bulat tidak diberi `.0` — "65.0 kg" terbaca seperti presisi yang tidak
/// ada, dan di daftar panjang membuat kolom jadi ramai tanpa menambah informasi.
String formatWeight(double w) {
  if (w == 0) return 'BW';
  return w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString();
}

/// Seperti [formatWeight] tapi nol tetap ditulis `0` — untuk selisih dan
/// kelipatan, di mana "BW" tidak berarti apa-apa.
String formatDelta(double w) => w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString();

/// 1324 → "1,324". Daftar sepanjang katalog gerakan sulit dibaca tanpa ini.
String formatCount(int n) =>
    n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// Beban untuk teks target: `72.5`, `BW` untuk gerakan bodyweight, `—` untuk
/// gerakan berbeban yang bebannya belum diisi. Menulis "BW" untuk bench press
/// yang belum punya beban terbaca seolah bench-nya tanpa barbel.
String weightLabel(double w, {required bool bodyweight}) {
  if (w > 0) return formatWeight(w);
  return bodyweight ? 'BW' : '—';
}
