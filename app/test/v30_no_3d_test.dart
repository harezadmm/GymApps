/// UI v3 memakai ikon garis saja: tidak ada lagi ikon 3D maupun font Manrope
/// di bundel (spec UI-V3 §4 dan §2).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tidak ada lagi ikon 3D dan Manrope di aplikasi', () {
    expect(File('lib/core/art3d.dart').existsSync(), isFalse, reason: 'art3d.dart masih ada');
    expect(Directory('assets/3d').existsSync(), isFalse, reason: 'assets/3d masih ada');
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('assets/3d'), isFalse);
    expect(pubspec.contains('Manrope'), isFalse);
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('Gym3d') || src.contains("'Manrope'")) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });
}
