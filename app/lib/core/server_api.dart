/// Alamat fungsi server Vercel dan token akun untuk memanggilnya.
///
/// Fungsi server (`web-api/api/*`) memegang rahasia yang tidak boleh ada di
/// APK atau bundel web — kunci Gemini, kunci privat VAPID — dan hanya
/// melayani akun yang masuk ke Supabase.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

class ServerApi {
  ServerApi._();

  /// Token akses Supabase akun yang sedang masuk, diperbarui kalau kedaluwarsa.
  /// Diisi `main.dart` saat Supabase terkonfigurasi; null = build tanpa server.
  static Future<String?> Function()? accessToken;

  /// Domain produksi untuk HP. Bisa diganti `--dart-define=API_BASE=...`.
  static const _base = String.fromEnvironment('API_BASE', defaultValue: 'https://gymapps-hariz.vercel.app');

  /// Web memanggil asal halamannya sendiri (deploy preview ikut benar); HP
  /// memanggil domain produksi.
  static Uri endpoint(String path) => kIsWeb ? Uri.base.resolve('/$path') : Uri.parse('$_base/$path');
}
