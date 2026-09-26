/// Inset aman (poni iPhone, garis home) untuk Flutter web.
///
/// Mesin Flutter web tidak membaca `env(safe-area-inset-*)`: `MediaQuery.padding`
/// selalu nol. Dengan `viewport-fit=cover` di index.html, itu berarti konten
/// tergambar di balik bilah status dan garis home pada iPhone yang memasang
/// aplikasi ini ke Home Screen. Di sini nilainya dibaca dari variabel CSS
/// yang diisi index.html, lalu disuntikkan ke MediaQuery oleh `main.dart`.
///
/// Dibaca setiap build, bukan sekali: iOS mengabaikan `orientation` di
/// manifest, dan saat diputar insetnya berpindah dari atas ke kiri-kanan.
library;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

EdgeInsets readCssSafeArea() {
  final style = web.window.getComputedStyle(web.document.documentElement!);
  double side(String name) {
    final raw = style.getPropertyValue(name).trim();
    if (raw.isEmpty) return 0;
    return double.tryParse(raw.replaceFirst('px', '')) ?? 0;
  }

  return EdgeInsets.fromLTRB(side('--sal'), side('--sat'), side('--sar'), side('--sab'));
}

String? _lastChrome;

/// Warnai bilah browser (Chrome Android, tab Safari) sesuai tema, dan beri tahu
/// browser skema warnanya supaya kontrol bawaannya tidak berbenturan.
void setBrowserChrome({required Color background, required bool light}) {
  final hex = '#${(background.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  final key = '$hex$light';
  if (key == _lastChrome) return;
  _lastChrome = key;
  void meta(String name, String content) {
    final el = web.document.querySelector('meta[name="$name"]');
    el?.setAttribute('content', content);
  }

  meta('theme-color', hex);
  meta('color-scheme', light ? 'light' : 'dark');
  web.document.body?.style.backgroundColor = hex;
}
