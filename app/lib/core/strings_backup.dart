/// Teks cadangan harian otomatis ke folder Download (FR-A5, FR-A6): grup
/// "Cadangan otomatis" di Profil dan snackbar "Simpan sekarang".
///
/// Dipisah dari `strings.dart` dengan alasan yang sama seperti
/// `strings_home.dart`: satu extension per area supaya pekerjaan rilis ini
/// tidak saling menimpa satu file. Pemanggilnya tetap `context.t.xxx` —
/// extension ini menempel pada [Strings].
library;

import 'strings.dart';

extension BackupStrings on Strings {
  String _b(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  // ── Grup di Profil (Android saja) ──
  String get autoBackupTitle => _b('Automatic backup', 'Cadangan otomatis');
  String get dailyBackup => _b('Daily backup', 'Cadangan harian');
  String get backUpNow => _b('Back up now', 'Simpan sekarang');
  String get neverBackedUp => _b('Never', 'Belum pernah');

  /// Nilai baris "Simpan sekarang": kapan terakhir kali.
  String lastBackup(String date) => _b('Last: $date', 'Terakhir: $date');

  /// `2026-09-30` → "30 Sep"; tahunnya ikut hanya kalau bukan tahun ini —
  /// cadangan yang setua itu berarti aplikasinya lama tidak dibuka, dan itu
  /// perlu terlihat. Tanggal yang tidak terbaca ditampilkan apa adanya.
  String backupDateLabel(String iso, DateTime today) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final day = '${d.day} ${monthShort(d.month)}';
    return d.year == today.year ? day : '$day ${d.year}';
  }

  /// Catatan di bawah grup: ke mana, berapa lama, dan bahwa Impor cadangan
  /// yang sudah ada bisa membukanya.
  String get autoBackupNote => _b(
        'Once a day, after your first change, to Download/GymApps — the last 7 days are kept, and the files stay '
            'there if the app is uninstalled. Import backup can open them.',
        'Sekali sehari setelah perubahan pertama, ke Download/GymApps — 7 hari terakhir disimpan, dan berkasnya '
            'tetap ada walau aplikasi dihapus. Impor cadangan bisa membukanya.',
      );

  // ── Snackbar "Simpan sekarang" ──
  String backupSavedTo(String name) => _b('Saved to Download/GymApps/$name', 'Disimpan ke Download/GymApps/$name');
  String get downloadBackupFailed => _b(
        "Couldn't write to Download/GymApps. Export backup still works.",
        'Gagal menulis ke Download/GymApps. Ekspor cadangan masih bisa.',
      );
  String get backupUnsupported => _b(
        'Automatic backup needs Android 10 or newer.',
        'Cadangan otomatis butuh Android 10 atau lebih baru.',
      );
}
