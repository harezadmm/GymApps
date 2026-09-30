/// Ekspor riwayat sebagai CSV (FR-G6): satu baris per set, RFC 4180.
///
/// Murni, tanpa Flutter: satu fungsi atas daftar [Workout] plus dua penyelesai
/// nama, supaya bentuk berkasnya bisa diuji byte demi byte. Yang menulis ke
/// disk — atau mengunduh di web — adalah layar Riwayat, lewat jalur yang sama
/// dengan cadangan JSON di Profil.
///
/// Bentuknya mengikuti RFC 4180 apa adanya: koma sebagai pemisah, CRLF di
/// akhir tiap baris, dan kolom yang memuat koma, kutip, atau baris baru
/// dibungkus kutip dengan kutip di dalamnya digandakan. Tanpa BOM dan tanpa
/// kolom berbahasa: berkas ini untuk spreadsheet dan skrip, bukan untuk
/// dibaca di layar — teks dua bahasa hidup di aplikasi, bukan di kolom.
library;

import '../domain/models.dart';
import '../domain/units.dart';
import 'format.dart';

/// Kolom-kolom berkas, dalam urutan ini. Dibuka supaya test dan pembaca lain
/// tidak perlu menyalin daftarnya.
const csvHeader = ['date', 'routine', 'gym', 'exercise', 'set', 'phase', 'weight', 'unit', 'reps', 'seconds', 'rir', 'done'];

/// Riwayat [workouts] sebagai CSV.
///
/// Baris urut tanggal naik; untuk tanggal yang sama urutan masukan
/// dipertahankan, lalu urutan gerakan di sesi, lalu urutan set. Beban ditulis
/// dalam [unit] dengan pembulatan aplikasi ([shown]: 0,01 kg atau 0,1 lb) —
/// angka yang sama dengan yang tampil di layar, bukan 63,502931800000006 kg
/// dari 140 lb yang disimpan sebagai kg.
///
/// [exerciseName] memberi nama tampilan gerakan (katalog atau custom);
/// [gymName] nama gym dari id sesi — kosong kalau tidak dikenal. Id-nya
/// diserahkan apa adanya (null untuk sesi tanpa gym); pemanggil yang tahu
/// gym bawaan. Tanpa [gymName] kolom gym kosong.
String historyCsv(
  List<Workout> workouts, {
  required WeightUnit unit,
  required String Function(String exerciseId) exerciseName,
  String Function(String? gymId)? gymName,
}) {
  // Indeks ikut jadi kunci kedua: sort Dart tidak stabil, dan dua sesi sehari
  // tidak boleh bertukar tempat tiap kali diekspor.
  final ordered = [...workouts.indexed]..sort((a, b) {
      final byDate = a.$2.date.compareTo(b.$2.date);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  final out = StringBuffer(csvLine(csvHeader));
  for (final (_, w) in ordered) {
    final gym = gymName?.call(w.gymId) ?? '';
    for (final e in w.entries) {
      final exercise = exerciseName(e.exerciseId);
      for (final (i, s) in e.sets.indexed) {
        out.write(csvLine([
          w.date,
          w.routine ?? '',
          gym,
          exercise,
          '${i + 1}',
          s.phase.name,
          formatDelta(shown(s.weight, unit)),
          unit.label,
          '${s.reps}',
          '${s.seconds}',
          s.rir?.toString() ?? '',
          s.done ? 'true' : 'false',
        ]));
      }
    }
  }
  return out.toString();
}

/// Satu baris CSV dari kolom-kolomnya, diakhiri CRLF.
String csvLine(List<String> fields) => '${fields.map(csvField).join(',')}\r\n';

/// Satu kolom: dibungkus kutip hanya kalau perlu (koma, kutip, CR, LF), dan
/// kutip di dalamnya digandakan. Kolom polos ditulis apa adanya supaya
/// berkasnya tetap terbaca manusia di editor teks.
String csvField(String v) {
  if (!v.contains(',') && !v.contains('"') && !v.contains('\n') && !v.contains('\r')) return v;
  return '"${v.replaceAll('"', '""')}"';
}
