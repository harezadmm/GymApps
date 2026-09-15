/// Katalog gerakan dari `assets/data/exercises.json` — 1.324 gerakan yang
/// dibawa dari openGym (FR-C1).
///
/// Dimuat sekali lalu disimpan di memori. File-nya ±870 KB; mem-parse ulang
/// setiap kali layar library dibuka akan terasa sebagai jeda saat mengetik di
/// kolom cari.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

String _title(String s) =>
    s.isEmpty ? '' : s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    required this.secondary,
  });

  final String id;
  final String name;

  /// Kunci pendek di JSON dipertahankan apa adanya saat parsing (`n`, `bp`,
  /// `eq`, `tg`) supaya file aset tidak perlu ditulis ulang.
  final String bodyPart;
  final String equipment;
  final String target;

  /// Otot pendukung (`sm` di aset). Ikut dihitung dengan bobot lebih kecil —
  /// bench press bukan cuma dada, dan peta yang bilang begitu akan menyesatkan.
  final List<String> secondary;

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'] as String? ?? '',
        // Katalog openGym menyimpan nama huruf kecil semua ("barbell row").
        // Ditulis ulang jadi Title Case di sini, sekali, bukan di setiap widget
        // yang kebetulan menampilkannya.
        name: _title(j['n'] as String? ?? ''),
        bodyPart: j['bp'] as String? ?? '',
        equipment: j['eq'] as String? ?? '',
        target: j['tg'] as String? ?? '',
        secondary: (j['sm'] as List?)?.cast<String>() ?? const [],
      );

  /// "Back · Barbell" — baris kedua di daftar.
  String get subtitle => '${_title(bodyPart)} · ${_title(equipment)}';

  /// Ikon per bagian tubuh. Katalognya tidak membawa gambar yang di-bundle —
  /// hanya nama berkas gif di server openGym — jadi baris pakai ikon, bukan
  /// kotak kosong yang menunggu gambar yang tidak akan datang.
  IconData get icon => switch (bodyPart) {
        'back' => Icons.rowing,
        'chest' => Icons.fitness_center,
        'upper legs' || 'lower legs' => Icons.directions_run,
        'shoulders' => Icons.sports_martial_arts,
        'upper arms' || 'lower arms' => Icons.sports_gymnastics,
        'waist' => Icons.self_improvement,
        'cardio' => Icons.monitor_heart_outlined,
        _ => Icons.fitness_center,
      };
}

class ExerciseCatalog {
  ExerciseCatalog._(this.all);

  /// Katalog buatan untuk test, supaya pengujian volume tidak perlu memuat
  /// aset 870 KB dan tidak ikut gagal saat isi katalog berubah.
  factory ExerciseCatalog.forTest(List<Exercise> items) = ExerciseCatalog._;

  final List<Exercise> all;

  static ExerciseCatalog? _cached;

  static Future<ExerciseCatalog> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/data/exercises.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(Exercise.fromJson).toList();
    return _cached = ExerciseCatalog._(list);
  }

  /// Cari berdasarkan nama, bagian tubuh, atau alat — satu kolom untuk
  /// ketiganya, karena orang mengetik "cable" sama seringnya dengan "fly".
  List<Exercise> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((e) =>
            e.name.toLowerCase().contains(q) ||
            e.bodyPart.toLowerCase().contains(q) ||
            e.equipment.toLowerCase().contains(q) ||
            e.target.toLowerCase().contains(q))
        .toList();
  }
}
