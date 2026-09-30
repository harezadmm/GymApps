/// Aset IconScout: font ikon alat dan ilustrasi.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/gym_icons.dart';
import 'package:gymapps/core/illustration.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/domain/settings.dart';

Exercise _ex(String equipment, {String bodyPart = 'chest'}) =>
    Exercise(id: 'x', name: 'x', bodyPart: bodyPart, equipment: equipment, target: '', secondary: const []);

void main() {
  test('kode glyph di GymIcons sama dengan font yang dibangun', () {
    // Font dibangun ulang dari design/iconscout/icons; urutan nama berkas
    // menentukan kode glyph. Kalau berkas ditambah tanpa memperbarui
    // gym_icons.dart, ikon yang tampil akan tertukar diam-diam.
    final map = jsonDecode(File('../design/iconscout/GymIcons.json').readAsStringSync()) as Map<String, dynamic>;
    // gym_icons.dart dibangkitkan dari JSON yang sama; test ini memastikan
    // keduanya belum saling tertinggal.
    final dart = File('lib/core/gym_icons.dart').readAsStringSync();
    final declared = {
      for (final m in RegExp(r'static const (\w+) = IconData\(0x([0-9a-f]+)').allMatches(dart))
        m.group(1)!: int.parse(m.group(2)!, radix: 16),
    };
    String camel(String n) {
      final base = n.startsWith('ui_') ? n.substring(3) : n;
      final parts = base.split(RegExp('[-_]'));
      return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
    }
    expect(declared.keys.toSet(), map.keys.map(camel).toSet());
    for (final e in map.entries) {
      expect(declared[camel(e.key)], e.value, reason: e.key);
    }
    expect(GymIcons.barbell.fontFamily, 'GymIcons');
    expect(GymIcons.home.fontFamily, 'GymIcons');
    expect(File('assets/fonts/GymIcons.ttf').existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/fonts/GymIcons.ttf'));
  });

  test('SVG sumber font berupa isian dan tercatat di SOURCES.md', () {
    // Font ikon hanya menggambar isian. SVG yang garisnya masih berupa
    // stroke lolos build tanpa galat, tetapi glyph-nya kosong di aplikasi.
    final sources = File('../design/iconscout/SOURCES.md').readAsStringSync();
    final svgs = Directory('../design/iconscout/icons')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.svg'))
        .toList();
    expect(svgs, isNotEmpty);
    for (final f in svgs) {
      final name = f.uri.pathSegments.last.replaceAll('.svg', '');
      final svg = f.readAsStringSync();
      expect(svg, contains('<path'), reason: name);
      expect(RegExp(r'stroke\s*[=:]\s*"?(?!none)').hasMatch(svg), isFalse, reason: '$name masih memakai stroke');
      // Lisensinya per aset: glyph yang tidak tercatat tidak bisa dilacak
      // balik ke slug yang dibeli.
      final bare = name.startsWith('ui_') ? name.substring(3) : name;
      expect(RegExp('[|/] ${RegExp.escape(bare)} [|/]').hasMatch(sources), isTrue,
          reason: '$bare belum tercatat di SOURCES.md');
    }
  });

  test('lib/ tidak memakai ikon Material lagi', () {
    // Ikon Material bergaris lebih tipis dan bersudut lain; satu saja di
    // antara ikon Barudak Lier langsung terlihat asing.
    const pending = <String>[];
    final material = RegExp(r'(^|[^A-Za-z])Icons\.[a-z_0-9]+');
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || pending.any(path.endsWith)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (material.hasMatch(lines[i])) found.add('$path:${i + 1}');
      }
    }
    expect(found, isEmpty);
  });

  test('setiap kelompok alat punya ikonnya sendiri', () {
    final icons = {for (final g in equipmentGroups.keys) GymIcons.forGroup(g)};
    expect(icons.length, equipmentGroups.length);
    expect(icons.contains(GymIcons.bodyweight), isFalse);
  });

  test('ikon gerakan mengikuti alatnya', () {
    expect(_ex('barbell').icon, GymIcons.barbell);
    expect(_ex('ez barbell').icon, GymIcons.barbell);
    expect(_ex('dumbbell').icon, GymIcons.dumbbell);
    expect(_ex('cable').icon, GymIcons.cable);
    expect(_ex('smith machine').icon, GymIcons.machine);
    expect(_ex('stability ball').icon, GymIcons.ball);
    expect(_ex('body weight').icon, GymIcons.bodyweight);
    expect(_ex('body weight', bodyPart: 'cardio').icon, GymIcons.cardio);
  });

  test('semua berkas ilustrasi ada dan terdaftar', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/illustrations/'));
    for (final a in GymArt.values) {
      final f = File(a.asset);
      expect(f.existsSync(), isTrue, reason: a.asset);
      expect(f.readAsStringSync(), startsWith('<svg'), reason: a.asset);
    }
  });

  testWidgets('layar kosong tampil tanpa meluber di HP 360 dp, tema gelap dan terang', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    for (final b in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(MaterialApp(
        theme: buildGymTheme(brightness: b),
        home: const Scaffold(
          body: EmptyState(art: GymArt.emptyHistory, title: 'No sessions yet', body: 'Finish a session and it lands here.'),
        ),
      ));
      await tester.pump();
      expect(find.text('No sessions yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
