/// Katalog gerakan dari `assets/data/exercises.json` — 1.324 gerakan yang
/// dibawa dari openGym (FR-C1) — ditambah gerakan custom buatan pengguna (FR-C2).
///
/// Dimuat sekali lalu disimpan di memori. File-nya ±870 KB; mem-parse ulang
/// setiap kali layar library dibuka akan terasa sebagai jeda saat mengetik di
/// kolom cari.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import '../core/gym_icons.dart';
import '../domain/settings.dart';
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
    this.custom = false,
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

  /// Dibuat pengguna, bukan dari katalog bawaan (FR-C2).
  final bool custom;

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'] as String? ?? '',
        // Katalog openGym menyimpan nama huruf kecil semua ("barbell row").
        // Ditulis ulang jadi Title Case di sini, sekali, bukan di setiap widget
        // yang kebetulan menampilkannya. Nama custom disimpan persis seperti
        // yang diketik pemiliknya.
        name: j['custom'] == true ? (j['n'] as String? ?? '') : _title(j['n'] as String? ?? ''),
        bodyPart: j['bp'] as String? ?? '',
        equipment: j['eq'] as String? ?? '',
        target: j['tg'] as String? ?? '',
        secondary: (j['sm'] as List?)?.cast<String>() ?? const [],
        custom: j['custom'] == true,
      );

  /// Bentuk yang sama dengan aset, supaya gerakan custom bisa disimpan di
  /// dokumen store dan dibaca ulang dengan [Exercise.fromJson].
  Map<String, dynamic> toJson() => {
        'id': id,
        'n': name,
        'bp': bodyPart,
        'eq': equipment,
        'tg': target,
        if (secondary.isNotEmpty) 'sm': secondary,
        if (custom) 'custom': true,
      };

  /// "Back · Barbell" — baris kedua di daftar.
  String get subtitle => [
        if (bodyPart.isNotEmpty) _title(bodyPart),
        if (equipment.isNotEmpty) _title(equipment),
      ].join(' · ');

  /// Ikon dari alat yang dipakai (IconScout, lihat [GymIcons]). Bagian
  /// tubuh sudah tertulis di baris yang sama ("Chest · Barbell"); ikon alat
  /// membedakan Barbell Bench Press dari Dumbbell Bench Press sekilas, yang
  /// dulu sama-sama tampil sebagai ikon dada.
  IconData get icon {
    if (bodyPart == 'cardio') return GymIcons.cardio;
    for (final e in equipmentGroups.entries) {
      if (e.value.contains(equipment)) return GymIcons.forGroup(e.key);
    }
    return GymIcons.bodyweight;
  }
}

/// Kata yang orang ketik berbeda dari yang tertulis di katalog. Setiap kata di
/// kiri juga dicari sebagai kata-kata di kanannya.
const _synonyms = <String, List<String>>{
  'single': ['one'],
  'one': ['single'],
  '1': ['one', 'single'],
  'unilateral': ['one', 'single'],
  'db': ['dumbbell'],
  'dumbell': ['dumbbell'],
  'bb': ['barbell'],
  'kb': ['kettlebell'],
  'machine': ['lever', 'smith', 'sled'],
  'lat': ['lats', 'latissimus'],
  'pec': ['pectorals', 'chest'],
  'chest': ['pectorals'],
  'shoulder': ['delts', 'deltoid'],
  'delt': ['delts', 'deltoid'],
  'quad': ['quads', 'quadriceps'],
  'ham': ['hamstrings'],
  'calf': ['calves'],
  'ab': ['abs'],
  'trap': ['traps'],
  'flye': ['fly'],
  'rdl': ['romanian'],
  'ohp': ['overhead'],
};

/// Huruf kecil, tanda baca jadi spasi, dan beberapa ejaan yang sering berbeda
/// disatukan ("pull-down", "pull down" → "pulldown").
String normalizeQuery(String s) {
  var t = s.toLowerCase().replaceAll(RegExp(r'[-_/(),.]'), ' ');
  t = t
      .replaceAll(RegExp(r'\bpull\s+down\b'), 'pulldown')
      .replaceAll(RegExp(r'\bpush\s+down\b'), 'pushdown')
      .replaceAll(RegExp(r'\bpushup\b'), 'push up')
      .replaceAll(RegExp(r'\bpullup\b'), 'pull up')
      .replaceAll(RegExp(r'\bchinup\b'), 'chin up');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class ExerciseCatalog {
  ExerciseCatalog._(this._builtin);

  /// Katalog buatan untuk test, supaya pengujian volume tidak perlu memuat
  /// aset 870 KB dan tidak ikut gagal saat isi katalog berubah.
  factory ExerciseCatalog.forTest(List<Exercise> items) = ExerciseCatalog._;

  final List<Exercise> _builtin;

  /// Gerakan custom milik pengguna. Statis karena katalog di-cache sekali untuk
  /// seluruh aplikasi, sedangkan daftarnya dipegang store dan bisa berubah
  /// kapan saja; store memberi tahu lewat [registerCustom].
  static List<Exercise> _custom = const [];
  static Map<String, Exercise> _customById = const {};

  /// Dipanggil store setiap kali daftar gerakan custom dibaca atau berubah.
  static void registerCustom(List<Exercise> items) {
    _custom = List.unmodifiable(items);
    _customById = {for (final e in items) e.id: e};
  }

  /// Gerakan custom dulu — itu yang dibuat orang ini sendiri, dan mencarinya di
  /// bawah 1.324 gerakan lain hanya menyusahkan.
  List<Exercise> get all => [..._custom, ..._builtin];

  late final Map<String, Exercise> _byId = {for (final e in _builtin) e.id: e};

  /// Gerakan berdasarkan id, custom atau bawaan. null kalau tidak ada.
  Exercise? byId(String id) => _customById[id] ?? _byId[id];

  /// Nama untuk ditampilkan. Id yang tidak dikenal tetap diberi nama yang
  /// jujur, bukan string kosong yang membuat baris terlihat rusak.
  String nameOf(String id) => byId(id)?.name ?? 'Exercise $id';

  static ExerciseCatalog? _cached;
  static Future<ExerciseCatalog>? _loading;

  /// Satu pemuatan untuk semua pemanggil. Layar Home memanggil ini dari
  /// beberapa FutureBuilder sekaligus sebelum yang pertama selesai; tanpa
  /// ini tiap panggilan mengunduh dan mem-parse 870 KB sendiri — di web itu
  /// nama gerakan yang tetap "…" beberapa detik.
  static Future<ExerciseCatalog> load() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _loading ??= () async {
      final raw = await rootBundle.loadString('assets/data/exercises.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(Exercise.fromJson).toList();
      return _cached = ExerciseCatalog._(list);
    }();
  }

  /// Cari berdasarkan nama, bagian tubuh, alat, atau otot — per kata, dalam
  /// urutan apa pun, dengan sinonim. "single arm lat pulldown" menemukan
  /// "Cable One Arm Pulldown": single → one, dan lat cocok dengan otot target
  /// "lats".
  ///
  /// Kata dicocokkan di awal kata, bukan di tengah: "arm" tidak boleh ikut
  /// menemukan "forearm". Gerakan yang memuat semua kata tampil lebih dulu.
  /// Kalau kuerinya tiga kata atau lebih, gerakan yang hanya meleset satu kata
  /// ikut tampil di bawahnya — orang jarang mengetik nama persis seperti yang
  /// tertulis di katalog.
  List<Exercise> search(String query) {
    final q = normalizeQuery(query);
    if (q.isEmpty) return all;
    final tokens = q.split(' ');

    final full = <Exercise>[];
    final near = <(Exercise, int)>[];
    for (final e in all) {
      final hay =
          ' ${normalizeQuery('${e.name} ${e.bodyPart} ${e.equipment} ${e.target} ${e.secondary.join(' ')}')}';
      var hit = 0;
      for (final t in tokens) {
        if ([t, ...?_synonyms[t]].any((a) => hay.contains(' $a'))) hit++;
      }
      if (hit == tokens.length) {
        full.add(e);
      } else if (tokens.length >= 3 && hit >= tokens.length - 1) {
        near.add((e, hit));
      }
    }
    near.sort((a, b) => b.$2.compareTo(a.$2));
    return [...full, for (final (e, _) in near) e];
  }
}
