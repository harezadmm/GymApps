/// Akun di web: server yang memeriksa, tanpa salinan lokal.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/data/account_store.dart';
import 'package:gymapps/data/web_account_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuth implements GoTrueClient {
  final users = <String, String>{};
  bool offline = false;
  bool confirmationRequired = false;
  Session? _session;

  @override
  Session? get currentSession => _session;

  Session _sessionFor(String email) => Session(
        accessToken: 'token-$email',
        tokenType: 'bearer',
        user: User(
          id: 'id-$email',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-09-24T00:00:00Z',
          email: email,
        ),
      );

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    if (offline) throw AuthRetryableFetchException();
    if (users[email] != password) {
      throw const AuthApiException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials');
    }
    _session = _sessionFor(email!);
    return AuthResponse(session: _session);
  }

  @override
  Future<AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    if (offline) throw AuthRetryableFetchException();
    if (users.containsKey(email)) {
      throw const AuthApiException('User already registered', statusCode: '422', code: 'user_already_exists');
    }
    if (password.length < 6) {
      throw const AuthApiException('Password should be at least 6 characters', statusCode: '422', code: 'weak_password');
    }
    users[email!] = password;
    if (confirmationRequired) return AuthResponse(user: _sessionFor(email).user);
    _session = _sessionFor(email);
    return AuthResponse(session: _session);
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async => _session = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAuth auth;
  late WebAccountStore store;
  var signedIn = 0;

  setUp(() {
    auth = _FakeAuth();
    signedIn = 0;
    store = WebAccountStore(auth, onSignedIn: () => signedIn++);
  });

  test('belum ada sesi: belum ada yang masuk', () async {
    expect(await store.signedIn(), isNull);
  });

  test('daftar langsung masuk, email dinormalkan', () async {
    final r = await store.signUp(email: ' Baru@Gym.test ', password: 'rahasia123');
    expect(r, isA<SignUpOk>());
    expect((await store.signedIn())?.email, 'baru@gym.test');
    expect(signedIn, 1);
  });

  test('email yang sudah ada: emailTaken', () async {
    auth.users['a@gym.test'] = 'x';
    final r = await store.signUp(email: 'a@gym.test', password: 'rahasia123');
    expect(r, isA<SignUpError>());
    expect((r as SignUpError).reason, SignUpFailure.emailTaken);
  });

  test('kata sandi ditolak server: rejected, bukan offline', () async {
    final r = await store.signUp(email: 'a@gym.test', password: 'abc');
    expect((r as SignUpError).reason, SignUpFailure.rejected);
  });

  test('proyek minta konfirmasi email: tidak diklaim berhasil', () async {
    auth.confirmationRequired = true;
    final r = await store.signUp(email: 'a@gym.test', password: 'rahasia123');
    expect((r as SignUpError).reason, SignUpFailure.rejected);
    expect(await store.signedIn(), isNull);
  });

  test('masuk benar', () async {
    auth.users['a@gym.test'] = 'rahasia123';
    final r = await store.signIn(email: 'A@gym.test', password: 'rahasia123');
    expect(r, isA<SignInOk>());
    expect(signedIn, 1);
  });

  test('masuk salah: satu pesan untuk email atau kata sandi', () async {
    auth.users['a@gym.test'] = 'rahasia123';
    final r = await store.signIn(email: 'a@gym.test', password: 'salah');
    expect((r as SignInError).reason, SignInFailure.invalidCredentials);
    final r2 = await store.signIn(email: 'tidakada@gym.test', password: 'rahasia123');
    expect((r2 as SignInError).reason, SignInFailure.invalidCredentials);
  });

  test('tanpa jaringan: offline, bukan salah kata sandi', () async {
    auth.offline = true;
    final r = await store.signIn(email: 'a@gym.test', password: 'rahasia123');
    expect((r as SignInError).reason, SignInFailure.offline);
    final s = await store.signUp(email: 'a@gym.test', password: 'rahasia123');
    expect((s as SignUpError).reason, SignUpFailure.offline);
  });

  test('keluar melepas sesi', () async {
    auth.users['a@gym.test'] = 'rahasia123';
    await store.signIn(email: 'a@gym.test', password: 'rahasia123');
    await store.signOut();
    expect(await store.signedIn(), isNull);
  });
}
