/// Akun di web: langsung Supabase, tanpa salinan lokal.
///
/// Di browser tidak ada Keystore. Penyimpanan "aman" yang tersedia hanyalah
/// localStorage yang dienkripsi dengan kunci yang juga disimpan di
/// localStorage, dan PBKDF2 50 ribu putaran yang dikompilasi ke JavaScript
/// terasa lambat di ponsel. Jadi di web server yang memeriksa kata sandi.
///
/// Sesinya disimpan supabase_flutter, sehingga membuka aplikasi lagi — juga
/// tanpa sinyal — tidak perlu masuk ulang. Yang butuh jaringan hanya masuk
/// pertama kali. Data latihan tetap ditulis lokal dulu oleh WorkoutStore;
/// yang berubah cuma siapa yang memegang kata sandi.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_store.dart';

class WebAccountStore implements AccountStore {
  WebAccountStore(this.auth, {this.onSignedIn});

  final GoTrueClient auth;

  /// Dipanggil setelah sesi ada — memicu tarikan pertama.
  final VoidCallback? onSignedIn;

  static const _timeout = Duration(seconds: 15);

  /// Naik setiap kali keluar. Jawaban masuk/daftar yang datang sesudahnya —
  /// atau sesudah batas waktu — tetap disimpan gotrue sebagai sesi; di sini
  /// sesi semacam itu dibuang lagi supaya HP bersama tidak tiba-tiba
  /// berpindah ke akun orang yang tadi gagal masuk.
  int _epoch = 0;

  Future<T> _call<T>(Future<T> request) {
    final epoch = _epoch;
    var timedOut = false;
    unawaited(request.then((_) {
      if (epoch != _epoch || timedOut) unawaited(signOut());
    }, onError: (_) {}));
    return request.timeout(_timeout, onTimeout: () {
      timedOut = true;
      throw TimeoutException('auth');
    });
  }

  Account? _accountOf(User? user) {
    final email = user?.email;
    if (email == null) return null;
    return Account(
      email: LocalAccountStore.normalise(email),
      createdAt: DateTime.tryParse(user!.createdAt) ?? clock.now(),
    );
  }

  @override
  Future<Account?> signedIn() async => _accountOf(auth.currentSession?.user);

  @override
  Future<SignUpResult> signUp({required String email, required String password}) async {
    final address = LocalAccountStore.normalise(email);
    try {
      final r = await _call(auth.signUp(email: address, password: password));
      if (r.session == null) {
        // Proyek meminta konfirmasi email: belum ada sesi. Tidak bisa masuk
        // sampai tautannya diklik — dan itu yang dikatakan.
        return const SignUpError(SignUpFailure.confirmEmail);
      }
    } catch (e) {
      if (_offline(e)) return const SignUpError(SignUpFailure.offline);
      debugPrint('mendaftar ditolak server: $e');
      final code = e is AuthException ? e.code : null;
      return SignUpError(code == 'user_already_exists' || code == 'email_exists'
          ? SignUpFailure.emailTaken
          : SignUpFailure.rejected);
    }
    final account = _accountOf(auth.currentSession?.user);
    if (account == null || account.email != address) return const SignUpError(SignUpFailure.offline);
    onSignedIn?.call();
    return SignUpOk(account);
  }

  @override
  Future<SignInResult> signIn({required String email, required String password}) async {
    final address = LocalAccountStore.normalise(email);
    try {
      await _call(auth.signInWithPassword(email: address, password: password));
    } catch (e) {
      if (_offline(e)) return const SignInError(SignInFailure.offline);
      // GoTrue sengaja tidak membedakan "email tidak ada" dari "kata sandi
      // salah" — keduanya invalid_credentials — supaya email tidak bisa
      // ditebak. Pesannya mengikuti.
      debugPrint('masuk ditolak server: $e');
      return const SignInError(SignInFailure.invalidCredentials);
    }
    final account = _accountOf(auth.currentSession?.user);
    if (account == null || account.email != address) return const SignInError(SignInFailure.offline);
    onSignedIn?.call();
    return SignInOk(account);
  }

  @override
  Future<void> signOut() async {
    _epoch++;
    try {
      await auth.signOut().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('gagal keluar dari Supabase: $e');
    }
  }

  /// Menghapus akun server butuh hak admin yang tidak dipegang klien. Di web
  /// yang bisa dilakukan hanya keluar.
  @override
  Future<void> erase() => signOut();

  /// Tidak ada kata sandi lokal yang perlu diganti di web.
  @override
  Future<void> replacePassword({required String email, required String password}) async {}

  static bool _offline(Object e) {
    if (e is TimeoutException || e is AuthRetryableFetchException || e is AuthUnknownException || e is! AuthException) {
      return true;
    }
    final status = int.tryParse(e.statusCode ?? '') ?? 0;
    return status == 429 || status >= 500;
  }
}
