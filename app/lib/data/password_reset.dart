/// Minta email reset kata sandi.
///
/// Sengaja lewat `/auth/v1/recover` langsung, bukan
/// `auth.resetPasswordForEmail`: klien aplikasi memakai alur PKCE, dan link
/// PKCE hanya bisa ditukar di perangkat yang memintanya. Orang menekan "lupa
/// kata sandi" di aplikasi Android lalu membuka email di browser — di sana
/// link PKCE gagal. Tanpa `code_challenge`, link membawa token langsung dan
/// versi web bisa menanganinya di browser mana pun.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Halaman yang menangani link reset: versi web aplikasi ini.
const passwordResetRedirect = 'https://gymapps-hariz.vercel.app/';

/// true kalau server menerima permintaannya. Server sengaja menjawab sama
/// untuk email yang terdaftar dan yang tidak — pesan di layar mengikuti.
Future<bool> requestPasswordReset({
  required String supabaseUrl,
  required String anonKey,
  required String email,
  http.Client? client,
}) async {
  final uri = Uri.parse('$supabaseUrl/auth/v1/recover').replace(queryParameters: {'redirect_to': passwordResetRedirect});
  final c = client ?? http.Client();
  try {
    final r = await c
        .post(
          uri,
          headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim().toLowerCase()}),
        )
        .timeout(const Duration(seconds: 15));
    return r.statusCode >= 200 && r.statusCode < 300;
  } catch (_) {
    return false;
  } finally {
    if (client == null) c.close();
  }
}
