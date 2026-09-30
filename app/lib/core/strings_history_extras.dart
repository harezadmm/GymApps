/// Teks dua fitur riwayat v2.3: sesi yang sudah selesai dijadikan rutinitas
/// (FR-B8 lewat FR-F1), dan ekspor CSV riwayat (FR-G6).
///
/// Dipisah dari `strings.dart` dan `strings_history.dart` dengan alasan yang
/// sama seperti `strings_home.dart`: satu extension per pekerjaan, supaya
/// rilis ini tidak saling menimpa di berkas bersama. Pemanggilnya tetap
/// `context.t.xxx` — extension ini menempel ke [Strings].
library;

import 'strings.dart';

extension HistoryExtraStrings on Strings {
  String _x(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  // ── Jadikan rutinitas ──────────────────────────────────────────────────

  /// Judul dialog. Tombolnya memakai [saveAsRoutineUpper], seperti tombol
  /// aksi lain di sheet detail dan ringkasan selesai.
  String get saveAsRoutine => _x('Save as routine', 'Jadikan rutinitas');
  String get saveAsRoutineUpper => _x('SAVE AS ROUTINE', 'JADIKAN RUTINITAS');
  String get saveAsRoutineHint => _x(
        'Sets, reps and weights come from the ticked sets.',
        'Set, rep, dan beban diambil dari set yang tercentang.',
      );

  /// Kotak centang di mode rotasi (FR-B2).
  String get addToRotation => _x('Add to rotation', 'Tambahkan ke rotasi');
  String get addToRotationHint => _x(
        'Goes in after the current routines. Unticked, it only shows under "another session" on Home.',
        'Masuk setelah rutinitas yang ada. Tanpa centang, hanya muncul di "sesi lain" di Home.',
      );
  String routineSaved(String name) => _x('Routine $name saved.', 'Rutinitas $name disimpan.');
  String get nothingToSaveAsRoutine => _x(
        'No ticked sets to turn into a routine.',
        'Tidak ada set tercentang untuk dijadikan rutinitas.',
      );

  // ── Ekspor CSV (FR-G6) ─────────────────────────────────────────────────
  String get exportCsv => _x('Export CSV', 'Ekspor CSV');
  String csvSaved(String name) => _x('CSV saved: $name', 'CSV disimpan: $name');
  String get csvExportFailed => _x("Couldn't save the CSV.", 'CSV gagal disimpan.');
  String get nothingToExport => _x('Nothing to export yet.', 'Belum ada sesi untuk diekspor.');
}
