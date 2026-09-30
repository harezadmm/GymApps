/// Label pembaca layar dan tooltip untuk tombol ikon-saja (NFR-11), dari
/// audit anti-slop 001 temuan 9: beberapa layar dulu punya nol tooltip pada
/// tombol yang hanya berupa ikon, jadi TalkBack/VoiceOver membacanya sebagai
/// "tombol" tanpa nama.
///
/// Dipisah dari `strings.dart` dengan alasan yang sama seperti
/// `strings_home.dart`: satu extension per pekerjaan supaya rilis ini tidak
/// saling menimpa di satu file. Pemanggilnya tetap `context.t.xxx`.
library;

import 'strings.dart';

extension A11yStrings on Strings {
  String _y(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  /// Objek untuk [Strings.decrease]/[Strings.increase] pada tombol −/+ di
  /// kolom beban tabel set: "decrease weight" / "kurangi beban". Ikonnya
  /// hanya − dan +, jadi tanpa ini pembaca layar tidak tahu apa yang dikurangi.
  String get weightWord => _y('weight', 'beban');

  /// Tombol ✕ di baris set editor riwayat.
  String get removeSet => _y('Remove set', 'Hapus set');

  /// Tombol centang di baris set editor riwayat. Menyebut aksinya, bukan
  /// keadaannya, supaya pembaca layar tahu apa yang terjadi kalau ditekan.
  String setDoneToggle(bool done) =>
      done ? _y('Mark set not done', 'Batalkan centang set') : _y('Mark set done', 'Tandai set selesai');
}
