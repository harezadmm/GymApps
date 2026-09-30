import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/decode_size.dart';

void main() {
  test('di HP: seukuran tampilan, dibatasi ukuran berkas dan minimal 1 px', () {
    expect(decodePx(170, 3, 600, web: false), 510);
    expect(decodePx(46, 2.75, 384, web: false), 127);
    expect(decodePx(250, 3, 600, web: false), 600);
    expect(decodePx(0.1, 1, 600, web: false), 1);
  });

  test('di web: tidak pernah mengubah ukuran dekode', () {
    // WebKit tidak pernah menyelesaikan gambar yang diubah ukurannya oleh
    // Flutter web — di iPhone ilustrasinya kosong.
    expect(decodePx(170, 3, 600, web: true), isNull);
    expect(decodePx(46, 3, 384, web: true), isNull);
  });

  test('setiap cacheWidth/cacheHeight di lib/ lewat decodePx', () {
    final raw = RegExp(r'cache(Width|Height):\s*([^,)\n]+)');
    final offenders = <String>[];
    var seen = 0;
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in raw.allMatches(src)) {
        seen++;
        // Nilainya harus variabel yang diisi decodePx di berkas yang sama.
        final name = m.group(2)!.trim();
        final assigned = RegExp('\\b${RegExp.escape(name)}\\s*=\\s*decodePx\\(').hasMatch(src);
        if (!assigned) offenders.add('${f.path}: ${m.group(0)}');
      }
    }
    // Ilustrasi (1) dan ikon 3D (2): kalau 0, pemindainya yang rusak.
    expect(seen, greaterThanOrEqualTo(3));
    expect(offenders, isEmpty);
  });
}
