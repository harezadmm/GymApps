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
  return formatDelta(w);
}

/// Seperti [formatWeight] tapi nol tetap ditulis `0` — untuk selisih dan
/// kelipatan, di mana "BW" tidak berarti apa-apa.
///
/// Dibulatkan ke 0,01: beban yang dicatat dalam lb tersimpan sebagai kg
/// dengan pecahan panjang (140 lb = 63,5029318 kg), dan itu tidak boleh
/// muncul di layar sebagai "63.502931800000006".
String formatDelta(double w) {
  final r = (w * 100).roundToDouble() / 100;
  if (r == r.roundToDouble()) return r.toStringAsFixed(0);
  final s = r.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

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
