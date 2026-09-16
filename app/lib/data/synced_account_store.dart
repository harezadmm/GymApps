/// Akun lokal yang juga punya sesi Supabase.
///
/// **Kenapa ini ada sama sekali.** [SupabaseBackend] menolak setiap panggilan
/// tanpa `auth.currentSession` — RLS memerlukan `auth.uid()` untuk mencocokkan
/// baris. Tanpa lapisan ini, seluruh jalur sinkronisasi diam selamanya
/// sementara aplikasi tampak terkonfigurasi; itu kegagalan yang paling sulit
/// dilihat, karena tidak ada yang error.
///
/// **Lokal tetap gerbangnya, bukan server.** Setiap kata sandi diperiksa dulu
/// oleh [LocalAccountStore] lewat PBKDF2; server hanya pernah menerima
/// kredensial yang sudah lolos di sini. Dua akibatnya disengaja:
///
/// * Masuk tetap bisa tanpa sinyal — FR-A3 menjanjikan itu, dan orang di ruang
///   bawah tanah gym memang tidak punya sinyal.
/// * Kata sandi yang salah tidak pernah sampai ke jaringan.
///
/// Sesi Supabase-nya adalah *tambahan*, bukan syarat. Gagal menyambung berarti
/// kehilangan sinkron, bukan kehilangan aplikasi.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_store.dart';

class SyncedAccountStore implements AccountStore {
  SyncedAccountStore({required this.local, required this.auth, this.onSignedIn});

  /// Sumber kebenaran untuk masuk. Selalu diperiksa lebih dulu.
  final AccountStore local;

  final GoTrueClient auth;

  /// Dipanggil setelah sesi Supabase benar-benar ada. Dipakai untuk memicu
  /// dorongan pertama — riwayat yang sudah tercatat offline harus segera naik,
  /// bukan menunggu sesi latihan berikutnya.
  final VoidCallback? onSignedIn;

  @override
  Future<Account?> signedIn() => local.signedIn();

  @override
  Future<SignUpResult> signUp({required String email, required String password}) async {
    final result = await local.signUp(email: email, password: password);
    // Akun lokal gagal dibuat (email sudah terpakai) — jangan sentuh server.
    if (result is! SignUpOk) return result;
    await _reachServer(email: email, password: password);
    return result;
  }

  @override
  Future<SignInResult> signIn({required String email, required String password}) async {
    final result = await local.signIn(email: email, password: password);
    if (result is! SignInOk) return result;
    await _reachServer(email: email, password: password);
    return result;
  }

  @override
  Future<void> signOut() async {
    await local.signOut();
    // Sesi server dibuang juga. Kalau tidak, perangkat yang dipinjamkan ke
    // orang lain akan tetap mendorong riwayat ke akun pemilik sebelumnya.
    try {
      await auth.signOut();
    } catch (e) {
      debugPrint('gagal keluar dari Supabase: $e');
    }
  }

  @override
  Future<void> erase() async {
    await signOut();
    await local.erase();
  }

  /// Dapatkan sesi Supabase untuk kredensial yang **sudah** lolos di lokal.
  ///
  /// Mencoba masuk dulu, lalu mendaftar kalau akunnya belum ada di server.
  /// Urutan itu penting: akun yang dibuat saat offline tidak punya padanan di
  /// server, dan orang tidak boleh diminta mendaftar ulang hanya karena
  /// kebetulan tidak ada sinyal waktu pertama kali membuka aplikasi.
  ///
  /// Mendaftar di sini aman karena lokal sudah membuktikan kata sandinya —
  /// jalur ini tidak pernah dilewati kredensial yang salah.
  Future<void> _reachServer({required String email, required String password}) async {
    try {
      await auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      debugPrint('masuk ke Supabase gagal (${e.message}); mencoba mendaftar');
      try {
        await auth.signUp(email: email, password: password);
      } on AuthException catch (e) {
        // Kata sandi lokal berbeda dari yang ada di server, atau email ditolak.
        // Aplikasi tetap jalan; yang hilang cuma sinkronnya.
        debugPrint('mendaftar ke Supabase gagal: ${e.message}');
        return;
      } catch (e) {
        debugPrint('mendaftar ke Supabase gagal: $e');
        return;
      }
    } catch (e) {
      // Biasanya jaringan. Bukan alasan untuk menghalangi orang masuk.
      debugPrint('tidak bisa menghubungi Supabase: $e');
      return;
    }

    if (auth.currentSession != null) onSignedIn?.call();
  }
}
