/// Akun lokal + sesi Supabase: masuk di HP baru, dan "sambungkan ke server"
/// dari Profil untuk HP yang masuk sebelum build punya server.
///
/// Server auth-nya palsu tapi aturannya sama dengan GoTrue di proyek ini:
/// email langsung terkonfirmasi, pendaftaran terbuka, email yang sudah ada
/// ditolak dengan user_already_exists.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/data/account_store.dart';
import 'package:gymapps/data/synced_account_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemorySecrets implements SecretStore {
  final _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

class _FakeAuth implements GoTrueClient {
  /// Akun di server: email → kata sandi.
  final users = <String, String>{};
  bool offline = false;
  bool rateLimited = false;

  /// Kalau diisi, masuk menunggu ini — jaringan gym yang lambat.
  Completer<void>? gate;
  int signIns = 0;
  int signUps = 0;
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
    signIns++;
    await gate?.future;
    if (offline) throw AuthRetryableFetchException();
    if (rateLimited) {
      throw const AuthApiException('Request rate limit reached', statusCode: '429', code: 'over_request_rate_limit');
    }
    if (users[email] != password) {
      throw const AuthApiException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials');
    }
    // Seperti gotrue: sesi disimpan begitu jawaban datang, siapa pun yang
    // sedang masuk di aplikasi saat itu.
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
    signUps++;
    if (offline) throw AuthRetryableFetchException();
    if (users.containsKey(email)) {
      throw const AuthApiException('User already registered', statusCode: '422', code: 'user_already_exists');
    }
    users[email!] = password;
    _session = _sessionFor(email);
    return AuthResponse(session: _session);
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async => _session = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalAccountStore local;
  late _FakeAuth auth;
  late SyncedAccountStore store;
  var signedInCalls = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    local = LocalAccountStore(secrets: _MemorySecrets(), random: Random(7));
    auth = _FakeAuth();
    signedInCalls = 0;
    store = SyncedAccountStore(local: local, auth: auth, onSignedIn: () => signedInCalls++);
  });

  /// Akun yang dibuat di HP ini sebelum build punya server: lokal saja.
  Future<void> legacyAccount(String email, String password) async {
    await local.signUp(email: email, password: password);
  }

  group('sambungkan dari Profil', () {
    test('kata sandi lokal benar, belum ada akun server: didaftarkan dan tersambung', () async {
      await legacyAccount('a@gym.test', 'rahasia123');
      expect(await store.connect('rahasia123'), ConnectResult.connected);
      expect(auth.currentSession?.user.email, 'a@gym.test');
      expect(auth.users['a@gym.test'], 'rahasia123');
    });

    test('server punya kata sandi lain: disebut ditolak server, bukan jaringan', () async {
      await legacyAccount('a@gym.test', 'rahasia123');
      auth.users['a@gym.test'] = 'dariHPlain';
      expect(await store.connect('rahasia123'), ConnectResult.rejected);
      expect(auth.currentSession, isNull);
    });

    test('kata sandi server menang, dan kata sandi lokal ikut diganti', () async {
      await legacyAccount('a@gym.test', 'rahasia123');
      auth.users['a@gym.test'] = 'dariHPlain';
      expect(await store.connect('dariHPlain'), ConnectResult.connected);
      expect(await local.signIn(email: 'a@gym.test', password: 'dariHPlain'), isA<SignInOk>());
      expect(await local.signIn(email: 'a@gym.test', password: 'rahasia123'), isA<SignInError>());
    });

    test('kata sandi salah di lokal dan di server: salah kata sandi', () async {
      await legacyAccount('a@gym.test', 'rahasia123');
      auth.users['a@gym.test'] = 'rahasia123';
      expect(await store.connect('ngawur'), ConnectResult.wrongPassword);
      expect(auth.currentSession, isNull);
    });

    test('salah ketik, akun server belum ada: tidak mendaftarkan kata sandi yang salah', () async {
      // Temuan review: dulu salah ketik di sini mendaftarkan typo ke server
      // dan sekaligus mengganti kata sandi lokal dengannya.
      await legacyAccount('a@gym.test', 'rahasia123');
      expect(await store.connect('rahasia12'), ConnectResult.wrongPassword);
      expect(auth.signUps, 0);
      expect(auth.users, isEmpty);
      expect(await local.signIn(email: 'a@gym.test', password: 'rahasia123'), isA<SignInOk>());
    });

    test('tanpa jaringan dan kata sandi tidak lolos lokal: tidak dituduh salah', () async {
      await legacyAccount('a@gym.test', 'rahasia123');
      auth.offline = true;
      expect(await store.connect('dariHPlain'), ConnectResult.unreachable);
    });

    test('server membatasi permintaan (429): tidak terjangkau, bukan ditolak', () async {
      await legacyAccount('a@gym.test', 'rahasia123');
      auth.rateLimited = true;
      expect(await store.connect('rahasia123'), ConnectResult.unreachable);
    });

    test('tanpa jaringan: tidak terjangkau, dan tidak mencoba mendaftar', () async {
      await legacyAccount('a@gym.test', 'rahasia123');
      auth.offline = true;
      expect(await store.connect('rahasia123'), ConnectResult.unreachable);
      expect(auth.signUps, 0);
    });

    test('sesi akun lain yang tertinggal tidak dihitung tersambung', () async {
      await legacyAccount('a@gym.test', 'rahasia123');
      auth.users['a@gym.test'] = 'dariHPlain';
      auth.users['b@gym.test'] = 'punyaB';
      await auth.signInWithPassword(email: 'b@gym.test', password: 'punyaB');
      expect(await store.connect('rahasia123'), isNot(ConnectResult.connected));
    });

    test('keluar selagi menyambung: sesi yang datang belakangan dibuang', () async {
      await legacyAccount('a@gym.test', 'rahasia123');
      auth.users['a@gym.test'] = 'rahasia123';
      auth.gate = Completer<void>();
      final pending = store.connect('rahasia123');
      await Future<void>.delayed(Duration.zero);
      await store.signOut();
      auth.gate!.complete();
      expect(await pending, ConnectResult.unreachable);
      await Future<void>.delayed(Duration.zero);
      expect(auth.currentSession, isNull);
      expect(await local.signedIn(), isNull);
    });
  });

  group('masuk', () {
    test('HP baru: email yang hanya ada di server langsung bisa masuk', () async {
      auth.users['baru@gym.test'] = 'rahasia456';
      final r = await store.signIn(email: 'Baru@gym.test ', password: 'rahasia456');
      expect(r, isA<SignInOk>());
      expect((await local.signedIn())?.email, 'baru@gym.test');
      expect(signedInCalls, 1);
    });

    test('email yang tidak ada di mana pun: ditolak, tidak membuat akun baru', () async {
      final r = await store.signIn(email: 'hariz@gmial.com', password: 'rahasia123');
      expect(r, isA<SignInError>());
      expect(auth.signUps, 0);
      expect(auth.users, isEmpty);
      expect(await local.signedIn(), isNull);
    });

    test('HP baru, kata sandi salah: tetap ditolak dan tidak ada akun lokal', () async {
      auth.users['baru@gym.test'] = 'rahasia456';
      final r = await store.signIn(email: 'baru@gym.test', password: 'salah');
      expect(r, isA<SignInError>());
      expect(await local.signedIn(), isNull);
      expect(auth.currentSession, isNull);
    });

    test('kata sandi lokal salah dan ditolak server: tetap salah, tidak mendaftar', () async {
      await legacyAccount('a@gym.test', 'rahasia123');
      auth.users['a@gym.test'] = 'rahasia123';
      await local.signOut();
      final r = await store.signIn(email: 'a@gym.test', password: 'salah');
      expect((r as SignInError).reason, SignInFailure.wrongPassword);
      expect(auth.signUps, 0);
      expect(auth.currentSession, isNull);
    });

    test('setelah reset kata sandi di server, kata sandi baru diterima dan lokal ikut diganti', () async {
      // Lupa kata sandi → link reset → kata sandi baru disetel di web. HP ini
      // masih memegang hash kata sandi lama.
      await legacyAccount('a@gym.test', 'lamaSekali');
      auth.users['a@gym.test'] = 'baruHasilReset';
      await local.signOut();
      final r = await store.signIn(email: 'a@gym.test', password: 'baruHasilReset');
      expect(r, isA<SignInOk>());
      expect(auth.currentSession?.user.email, 'a@gym.test');
      await local.signOut();
      expect(await local.signIn(email: 'a@gym.test', password: 'baruHasilReset'), isA<SignInOk>());
    });

    test('keluar melepas sesi server juga', () async {
      auth.users['a@gym.test'] = 'rahasia123';
      await store.signIn(email: 'a@gym.test', password: 'rahasia123');
      expect(auth.currentSession, isNotNull);
      await store.signOut();
      expect(auth.currentSession, isNull);
    });
  });
}
