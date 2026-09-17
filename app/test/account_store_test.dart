import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/data/account_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keychain sungguhan tidak ada di test host, jadi diganti peta di memori.
/// Yang diuji perilaku store-nya, bukan Keychain-nya Apple.
class _MemorySecrets implements SecretStore {
  final _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  Iterable<String> get values => _data.values;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalAccountStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Random tetap: salt jadi bisa diramal, sehingga test yang gagal bisa
    // diulang persis. Yang diuji alurnya, bukan kualitas acaknya.
    store = LocalAccountStore(secrets: _MemorySecrets(), random: Random(7));
  });

  group('daftar', () {
    test('akun baru langsung masuk', () async {
      final r = await store.signUp(email: 'hariz@example.com', password: 'barbel123');
      expect(r, isA<SignUpOk>());
      expect((await store.signedIn())?.email, 'hariz@example.com');
    });

    test('email dinormalkan, bukan disimpan apa adanya', () async {
      await store.signUp(email: '  Hariz@Example.COM ', password: 'barbel123');
      expect((await store.signedIn())?.email, 'hariz@example.com');
    });

    test('email yang sama ditolak', () async {
      await store.signUp(email: 'hariz@example.com', password: 'barbel123');
      final r = await store.signUp(email: 'hariz@example.com', password: 'lainnya9');
      expect(r, isA<SignUpError>());
      expect((r as SignUpError).reason, SignUpFailure.emailTaken);
    });

    test('tanggal dibuat diambil dari clock, bukan dari DateTime.now langsung',
        () async {
      // Kalau ini gagal, ada yang memanggil DateTime.now() di dalam store —
      // dan itu membuat test apa pun yang bergantung waktu jadi rapuh.
      final fixed = DateTime.utc(2026, 3, 14, 9, 26);
      await withClock(Clock.fixed(fixed), () async {
        await store.signUp(email: 'a@b.co', password: 'barbel123');
      });
      expect((await store.signedIn())?.createdAt, fixed);
    });
  });

  group('lebih dari satu akun di perangkat yang sama', () {
    // Bug yang terlihat di simulator: HP yang sudah punya akun A menolak
    // pendaftaran akun B dengan pesan "akun sudah ada", padahal email B
    // belum pernah dipakai.
    test('email kedua boleh mendaftar saat email pertama sudah ada', () async {
      await store.signUp(email: 'a@contoh.com', password: 'barbel123');
      final r = await store.signUp(email: 'b@contoh.com', password: 'lainnya9');
      expect(r, isA<SignUpOk>());
      expect((await store.signedIn())?.email, 'b@contoh.com');
    });

    test('kedua akun tetap bisa masuk dengan kata sandinya sendiri', () async {
      await store.signUp(email: 'a@contoh.com', password: 'barbel123');
      await store.signUp(email: 'b@contoh.com', password: 'lainnya9');
      await store.signOut();

      expect(await store.signIn(email: 'a@contoh.com', password: 'barbel123'), isA<SignInOk>());
      expect(await store.signIn(email: 'b@contoh.com', password: 'lainnya9'), isA<SignInOk>());
      final silang = await store.signIn(email: 'a@contoh.com', password: 'lainnya9');
      expect((silang as SignInError).reason, SignInFailure.wrongPassword);
    });

    test('menghapus satu akun tidak ikut menghapus yang lain', () async {
      await store.signUp(email: 'a@contoh.com', password: 'barbel123');
      await store.signUp(email: 'b@contoh.com', password: 'lainnya9');
      await store.erase(); // yang sedang masuk: b
      expect(await store.signIn(email: 'a@contoh.com', password: 'barbel123'), isA<SignInOk>());
      final b = await store.signIn(email: 'b@contoh.com', password: 'lainnya9');
      expect((b as SignInError).reason, SignInFailure.wrongEmail);
    });
  });

  group('migrasi dari tata letak satu-akun', () {
    test('akun v1.3 tetap masuk tanpa mendaftar ulang', () async {
      // Tulis persis seperti store lama menulisnya, lalu buka dengan store
      // baru. Hash-nya diambil dari store baru supaya PBKDF2-nya sama.
      final secrets = _MemorySecrets();
      final probe = LocalAccountStore(secrets: secrets, random: Random(7));
      await probe.signUp(email: 'lama@contoh.com', password: 'barbel123');
      final hash = await secrets.read('accounts.lama@contoh.com.passwordHash');
      final prefs = await SharedPreferences.getInstance();
      final salt = prefs.getString('accounts.lama@contoh.com.salt');

      SharedPreferences.setMockInitialValues({
        'account.email': 'lama@contoh.com',
        'account.salt': salt!,
        'account.createdAt': '2026-09-16T10:00:00.000Z',
        'account.signedIn': true,
      });
      final legacySecrets = _MemorySecrets();
      await legacySecrets.write('account.passwordHash', hash!);
      final s = LocalAccountStore(secrets: legacySecrets, random: Random(7));

      expect((await s.signedIn())?.email, 'lama@contoh.com');
      await s.signOut();
      expect(await s.signIn(email: 'lama@contoh.com', password: 'barbel123'), isA<SignInOk>());
      expect(await legacySecrets.read('account.passwordHash'), isNull,
          reason: 'kunci lama harus dibersihkan setelah dipindahkan');
    });
  });

  group('masuk', () {
    test('kata sandi benar diterima', () async {
      await store.signUp(email: 'hariz@example.com', password: 'barbel123');
      await store.signOut();
      final r = await store.signIn(email: 'hariz@example.com', password: 'barbel123');
      expect(r, isA<SignInOk>());
    });

    test('kata sandi salah ditolak', () async {
      await store.signUp(email: 'hariz@example.com', password: 'barbel123');
      await store.signOut();
      final r = await store.signIn(email: 'hariz@example.com', password: 'barbel124');
      expect((r as SignInError).reason, SignInFailure.wrongPassword);
    });

    test('email lain ditolak sebelum kata sandi diperiksa', () async {
      await store.signUp(email: 'hariz@example.com', password: 'barbel123');
      final r = await store.signIn(email: 'orang@lain.co', password: 'barbel123');
      expect((r as SignInError).reason, SignInFailure.wrongEmail);
    });

    test('tanpa akun sama sekali dibedakan dari kata sandi salah', () async {
      // Dua kegagalan ini butuh pesan berbeda: satu menyuruh mendaftar,
      // satunya menyuruh mencoba lagi.
      final r = await store.signIn(email: 'sia@pa.co', password: 'barbel123');
      expect((r as SignInError).reason, SignInFailure.noAccount);
    });

    test('kapitalisasi email tidak menghalangi masuk', () async {
      await store.signUp(email: 'hariz@example.com', password: 'barbel123');
      await store.signOut();
      final r = await store.signIn(email: 'HARIZ@Example.com', password: 'barbel123');
      expect(r, isA<SignInOk>());
    });
  });

  group('keluar dan hapus', () {
    test('keluar tidak menghapus akunnya', () async {
      await store.signUp(email: 'hariz@example.com', password: 'barbel123');
      await store.signOut();
      expect(await store.signedIn(), isNull);
      expect(await store.signIn(email: 'hariz@example.com', password: 'barbel123'),
          isA<SignInOk>());
    });

    test('hapus benar-benar menghilangkan akunnya', () async {
      await store.signUp(email: 'hariz@example.com', password: 'barbel123');
      await store.erase();
      final r = await store.signIn(email: 'hariz@example.com', password: 'barbel123');
      expect((r as SignInError).reason, SignInFailure.noAccount);
    });
  });

  test('kata sandi tidak pernah tersimpan dalam bentuk aslinya', () async {
    // Ini inti seluruh berkas itu. Kalau suatu hari seseorang menyederhanakan
    // penyimpanannya, test ini yang menangkapnya.
    const secret = 'kataSandiRahasia99';
    final secrets = _MemorySecrets();
    final s = LocalAccountStore(secrets: secrets, random: Random(7));
    await s.signUp(email: 'hariz@example.com', password: secret);

    final prefs = await SharedPreferences.getInstance();
    final semua = [
      ...prefs.getKeys().map((k) => prefs.get(k).toString()),
      ...secrets.values,
    ].join('|');

    expect(semua.contains(secret), isFalse);
  });
}
