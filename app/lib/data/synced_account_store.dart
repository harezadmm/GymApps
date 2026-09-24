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
/// * Kata sandi yang salah untuk akun yang ada di HP ini tidak pernah sampai
///   ke jaringan.
///
/// Satu pengecualian: email yang belum pernah masuk di HP ini. Itu HP baru
/// atau aplikasi yang dipasang ulang, dan akunnya hanya ada di server — maka
/// server yang memeriksa kata sandinya, lalu akun lokal dibuat dengannya.
/// Tanpa jalur ini, orang yang ganti HP disuruh "membuat akun" untuk email
/// yang sudah mereka punya.
///
/// Sesi Supabase-nya adalah *tambahan*, bukan syarat. Gagal menyambung berarti
/// kehilangan sinkron, bukan kehilangan aplikasi.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_store.dart';

/// Hasil menyambungkan akun yang sudah masuk ke server.
enum ConnectResult { connected, wrongPassword, unreachable }

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
    if (result is SignInOk) {
      await _reachServer(email: email, password: password);
      return result;
    }
    if (result case SignInError(reason: SignInFailure.noAccount || SignInFailure.wrongEmail)) {
      if (await _serverAccepts(email: email, password: password)) {
        final made = await local.signUp(email: email, password: password);
        if (made case SignUpOk(:final account)) {
          onSignedIn?.call();
          return SignInOk(account);
        }
      }
    }
    return result;
  }

  /// Sambungkan akun yang sudah masuk di HP ini ke server.
  ///
  /// Untuk orang yang masuknya terjadi tanpa sinyal, atau sebelum build ini
  /// punya server — mereka tetap masuk, tapi tanpa sesi Supabase, dan kata
  /// sandinya tidak disimpan di mana pun untuk dipakai ulang. Kata sandi
  /// diperiksa lokal dulu, sama seperti saat masuk.
  Future<ConnectResult> connect(String password) async {
    final account = await local.signedIn();
    if (account == null) return ConnectResult.unreachable;
    final check = await local.signIn(email: account.email, password: password);
    if (check is! SignInOk) return ConnectResult.wrongPassword;
    await _reachServer(email: account.email, password: password);
    return auth.currentSession != null ? ConnectResult.connected : ConnectResult.unreachable;
  }

  /// true kalau server menerima kredensial ini dan sesinya sekarang ada.
  /// Jaringan mati atau kata sandi salah sama-sama false — pemanggil lalu
  /// menampilkan kesalahan lokal seperti biasa.
  Future<bool> _serverAccepts({required String email, required String password}) async {
    try {
      await auth.signInWithPassword(email: LocalAccountStore.normalise(email), password: password);
    } catch (e) {
      debugPrint('server menolak atau tidak terjangkau: $e');
      return false;
    }
    return auth.currentSession != null;
  }

  @override
  Future<void> signOut() async {
    await local.signOut();
    // Sesi server dibuang juga. Kalau tidak, perangkat yang dipinjamkan ke
    // orang lain akan tetap mendorong riwayat ke akun pemilik sebelumnya.
    // Sesi lokal Supabase dibuang sebelum permintaan logout dikirim, jadi
    // batas waktu di sini aman: yang terpotong hanya pemberitahuan ke server.
    try {
      await auth.signOut().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('gagal keluar dari Supabase: $e');
    }
  }

  @override
  Future<void> erase() async {
    // Lokal dulu: erase() menghapus akun yang *sedang masuk*, dan signOut()
    // melepas penunjuk itu. Dibalik, tidak ada yang terhapus.
    await local.erase();
    await signOut();
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
    final address = LocalAccountStore.normalise(email);
    try {
      await auth.signInWithPassword(email: address, password: password);
    } on AuthException catch (e) {
      debugPrint('masuk ke Supabase gagal (${e.message}); mencoba mendaftar');
      try {
        await auth.signUp(email: address, password: password);
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
