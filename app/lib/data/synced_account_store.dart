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
/// Dua pengecualian, dua-duanya karena server yang tahu jawabannya:
///
/// * Email yang belum pernah masuk di HP ini. Itu HP baru atau aplikasi yang
///   dipasang ulang, dan akunnya hanya ada di server — maka server yang
///   memeriksa kata sandinya, lalu akun lokal dibuat dengannya. Tanpa jalur
///   ini, orang yang ganti HP disuruh "membuat akun" untuk email yang sudah
///   mereka punya.
/// * [connect] dari Profil, yang memang perintah "sambungkan ke server". Kalau
///   akun yang sama pernah dibuat di HP lain dengan kata sandi berbeda, kata
///   sandi server yang menang dan kata sandi lokal ikut diganti — kalau tidak,
///   HP ini tidak akan pernah bisa tersambung.
///
/// Sesi Supabase-nya adalah *tambahan*, bukan syarat. Gagal menyambung berarti
/// kehilangan sinkron, bukan kehilangan aplikasi.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_store.dart';

/// Hasil menyambungkan akun yang sudah masuk ke server.
enum ConnectResult {
  connected,
  wrongPassword,

  /// Server menjawab, tapi menolak kata sandi ini untuk email ini — biasanya
  /// akun yang sama pernah dibuat di HP lain dengan kata sandi berbeda.
  rejected,

  /// Tidak ada jawaban dari server: jaringan mati atau terlalu lambat.
  unreachable,
}

/// Apa yang terjadi saat meminta sesi server.
enum _Reach { session, rejected, offline }

class SyncedAccountStore implements AccountStore {
  SyncedAccountStore({required this.local, required this.auth, this.onSignedIn});

  /// Sumber kebenaran untuk masuk. Selalu diperiksa lebih dulu.
  final AccountStore local;

  final GoTrueClient auth;

  /// Dipanggil setelah sesi Supabase benar-benar ada. Dipakai untuk memicu
  /// dorongan pertama — riwayat yang sudah tercatat offline harus segera naik,
  /// bukan menunggu sesi latihan berikutnya.
  final VoidCallback? onSignedIn;

  /// Batas waktu tiap panggilan ke server auth. Tanpa ini, sinyal gym yang
  /// putus-putus membuat layar menunggu sampai batas TCP sistem.
  static const _timeout = Duration(seconds: 15);

  /// Naik setiap kali keluar. Jawaban server yang datang sesudahnya — sesi
  /// yang disimpan gotrue untuk orang yang sudah keluar — dibuang lagi.
  int _epoch = 0;

  @override
  Future<Account?> signedIn() => local.signedIn();

  @override
  Future<SignUpResult> signUp({required String email, required String password}) async {
    final result = await local.signUp(email: email, password: password);
    // Akun lokal gagal dibuat (email sudah terpakai) — jangan sentuh server.
    if (result is! SignUpOk) return result;
    if (await _reachServer(email: email, password: password) == _Reach.session) onSignedIn?.call();
    return result;
  }

  @override
  Future<SignInResult> signIn({required String email, required String password}) async {
    final result = await local.signIn(email: email, password: password);
    if (result is SignInOk) {
      if (await _reachServer(email: email, password: password) == _Reach.session) onSignedIn?.call();
      return result;
    }
    // Email yang belum dikenal HP ini: server hanya ditanya "akun ini ada?",
    // tidak pernah disuruh membuat akun. Salah ketik email di layar masuk
    // tidak boleh diam-diam melahirkan akun kosong baru.
    if (result case SignInError(reason: SignInFailure.noAccount || SignInFailure.wrongEmail)) {
      if (await _reachServer(email: email, password: password, mayRegister: false) == _Reach.session) {
        final made = await local.signUp(email: email, password: password);
        if (made case SignUpOk(:final account)) {
          onSignedIn?.call();
          return SignInOk(account);
        }
        await _dropSession();
      }
    }
    return result;
  }

  /// Sambungkan akun yang sudah masuk di HP ini ke server.
  ///
  /// Untuk orang yang masuknya terjadi tanpa sinyal, atau sebelum build ini
  /// punya server — mereka tetap masuk, tapi tanpa sesi Supabase, dan kata
  /// sandinya tidak disimpan di mana pun untuk dipakai ulang.
  ///
  /// Kata sandi diperiksa lokal dulu. Kalau lokal menolak tapi server
  /// menerima, kata sandi server yang menang dan yang lokal diganti.
  Future<ConnectResult> connect(String password) async {
    final account = await local.signedIn();
    if (account == null) return ConnectResult.unreachable;
    final email = account.email;
    final epoch = _epoch;
    final localOk = await local.signIn(email: email, password: password) is SignInOk;
    // Mendaftar hanya dengan kata sandi yang sudah lolos di lokal. Kalau lokal
    // menolak, server harus membuktikan kata sandi itu lewat akun yang sudah
    // ada — pendaftaran baru tidak membuktikan apa-apa, dan salah ketik akan
    // jadi kata sandi di server sekaligus di HP ini.
    final reach = await _reachServer(email: email, password: password, mayRegister: localOk);

    // Orangnya keluar (atau berganti akun) selagi menunggu server. Sesi yang
    // mungkin baru tersimpan bukan lagi milik siapa pun yang sedang masuk.
    if (epoch != _epoch || (await local.signedIn())?.email != email) {
      if (reach == _Reach.session) await _dropSession();
      return ConnectResult.unreachable;
    }
    switch (reach) {
      case _Reach.session:
        if (!localOk) await local.replacePassword(email: email, password: password);
        return ConnectResult.connected;
      case _Reach.rejected:
        return localOk ? ConnectResult.rejected : ConnectResult.wrongPassword;
      // Server tidak menjawab: kata sandi yang tidak lolos lokal mungkin memang
      // kata sandi server. Belum bisa dipastikan salah.
      case _Reach.offline:
        return ConnectResult.unreachable;
    }
  }

  @override
  Future<void> replacePassword({required String email, required String password}) =>
      local.replacePassword(email: email, password: password);

  @override
  Future<void> signOut() async {
    _epoch++;
    await local.signOut();
    // Sesi server dibuang juga. Kalau tidak, perangkat yang dipinjamkan ke
    // orang lain akan tetap mendorong riwayat ke akun pemilik sebelumnya.
    await _dropSession();
  }

  @override
  Future<void> erase() async {
    // Lokal dulu: erase() menghapus akun yang *sedang masuk*, dan signOut()
    // melepas penunjuk itu. Dibalik, tidak ada yang terhapus.
    await local.erase();
    await signOut();
  }

  /// Sesi lokal Supabase dibuang sebelum permintaan logout dikirim, jadi batas
  /// waktu di sini aman: yang terpotong hanya pemberitahuan ke server.
  Future<void> _dropSession() async {
    try {
      await auth.signOut().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('gagal keluar dari Supabase: $e');
    }
  }

  /// Panggilan auth dengan batas waktu. Kalau jawabannya baru datang setelah
  /// orangnya keluar, sesi yang terlanjur disimpan gotrue dibuang.
  Future<T> _call<T>(Future<T> request) {
    final epoch = _epoch;
    unawaited(request.then((_) {
      if (epoch != _epoch) unawaited(_dropSession());
    }, onError: (_) {}));
    return request.timeout(_timeout);
  }

  /// Jaringan, bukan penolakan: tidak ada jawaban yang bisa dipercaya.
  static bool _offline(Object e) {
    if (e is TimeoutException || e is AuthRetryableFetchException || e is AuthUnknownException || e is! AuthException) {
      return true;
    }
    // Dibatasi atau server sedang bermasalah: coba lagi nanti, bukan "ditolak".
    final status = int.tryParse(e.statusCode ?? '') ?? 0;
    return status == 429 || status >= 500;
  }

  /// Minta sesi Supabase untuk kredensial ini.
  ///
  /// Mencoba masuk dulu, lalu mendaftar kalau akunnya belum ada di server.
  /// Urutan itu penting: akun yang dibuat saat offline tidak punya padanan di
  /// server, dan orang tidak boleh diminta mendaftar ulang hanya karena
  /// kebetulan tidak ada sinyal waktu pertama kali membuka aplikasi.
  ///
  /// Sesi dianggap ada hanya kalau memang milik email ini — sesi orang lain
  /// yang tertinggal di perangkat bukan "tersambung".
  Future<_Reach> _reachServer({required String email, required String password, bool mayRegister = true}) async {
    final address = LocalAccountStore.normalise(email);
    final epoch = _epoch;
    try {
      await _call(auth.signInWithPassword(email: address, password: password));
    } catch (e) {
      if (_offline(e)) {
        debugPrint('tidak bisa menghubungi Supabase: $e');
        return _Reach.offline;
      }
      if (!mayRegister) {
        debugPrint('masuk ke Supabase ditolak: $e');
        return _Reach.rejected;
      }
      debugPrint('masuk ke Supabase ditolak ($e); mencoba mendaftar');
      try {
        await _call(auth.signUp(email: address, password: password));
      } catch (e) {
        if (_offline(e)) return _Reach.offline;
        // Email sudah punya akun server dengan kata sandi lain, atau ditolak.
        // Aplikasi tetap jalan; yang hilang cuma sinkronnya.
        debugPrint('mendaftar ke Supabase ditolak: $e');
        return _Reach.rejected;
      }
    }
    if (epoch != _epoch) {
      await _dropSession();
      return _Reach.offline;
    }
    final who = auth.currentSession?.user.email?.trim().toLowerCase();
    return who == address ? _Reach.session : _Reach.rejected;
  }
}
