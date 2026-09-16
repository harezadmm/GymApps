/// Akun lokal: dibuat, disimpan, dan diperiksa di perangkat ini saja.
///
/// **Ini bukan pengganti Supabase Auth.** Supabase yang akan memegang akun
/// sungguhan begitu proyeknya dibuat; lapisan ini yang membuat "Buat akun"
/// benar-benar berfungsi sekarang, dan ia tetap berguna sesudahnya sebagai
/// jalur offline — FR-A3 menjanjikan aplikasi jalan tanpa sinyal, dan itu
/// mustahil kalau setiap kali masuk harus bertanya ke server.
///
/// **Yang disimpan di mana, dan kenapa:**
///
/// * Email, salt, dan tanggal dibuat → `shared_preferences`. Bukan rahasia.
/// * Hash kata sandi → `flutter_secure_storage`, yang berarti Keychain di iOS
///   dan Keystore di Android. Di sanalah tempatnya, bukan di file preferensi
///   biasa yang ikut terbawa saat backup perangkat.
///
/// **Kata sandinya tidak pernah disimpan**, hanya turunannya lewat PBKDF2.
/// Alasannya bukan data latihan — itu toh ada di perangkat yang sama dalam
/// bentuk biasa. Alasannya orang memakai ulang kata sandi: hash yang bocor
/// dari sini tidak boleh membuka akun mereka di tempat lain.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tempat menyimpan satu rahasia.
///
/// Sengaja antarmuka sendiri dan bukan `FlutterSecureStorage` langsung:
/// tanda tangan paket itu berubah antar versi mayor, dan store ini tidak
/// perlu tahu apakah rahasianya berakhir di Keychain, Keystore, atau peta
/// di memori saat test.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Keychain di iOS, Keystore di Android.
class KeychainSecrets implements SecretStore {
  const KeychainSecrets([this._inner = const FlutterSecureStorage()]);

  final FlutterSecureStorage _inner;

  @override
  Future<String?> read(String key) => _inner.read(key: key);

  @override
  Future<void> write(String key, String value) => _inner.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _inner.delete(key: key);
}

/// Jumlah putaran PBKDF2.
///
/// Dijalankan di Dart murni, jadi ini pertukaran langsung antara keamanan dan
/// lama menunggu. 50 ribu kira-kira seperempat detik di ponsel kelas menengah —
/// cukup terasa mahal bagi penebak, dan tidak terasa bagi pemakai yang hanya
/// menjalaninya dua kali: saat mendaftar dan saat masuk.
const _iterations = 50000;

class Account {
  const Account({required this.email, required this.createdAt});

  final String email;
  final DateTime createdAt;
}

/// Kenapa pendaftaran gagal. Sengaja enum, bukan string: pemanggilnya harus
/// memilih pesan dalam bahasa yang sedang dipakai, dan string di sini akan
/// memaksa satu bahasa masuk ke lapisan data.
enum SignUpFailure { emailTaken }

enum SignInFailure { noAccount, wrongEmail, wrongPassword }

sealed class SignUpResult {
  const SignUpResult();
}

class SignUpOk extends SignUpResult {
  const SignUpOk(this.account);
  final Account account;
}

class SignUpError extends SignUpResult {
  const SignUpError(this.reason);
  final SignUpFailure reason;
}

sealed class SignInResult {
  const SignInResult();
}

class SignInOk extends SignInResult {
  const SignInOk(this.account);
  final Account account;
}

class SignInError extends SignInResult {
  const SignInError(this.reason);
  final SignInFailure reason;
}

abstract interface class AccountStore {
  /// Akun yang sedang masuk, atau null kalau belum ada yang masuk.
  Future<Account?> signedIn();

  Future<SignUpResult> signUp({required String email, required String password});

  Future<SignInResult> signIn({required String email, required String password});

  Future<void> signOut();

  /// Hapus akun beserta hash-nya. Dipakai test dan tombol "hapus akun" nanti.
  Future<void> erase();
}

class LocalAccountStore implements AccountStore {
  LocalAccountStore({SecretStore? secrets, Random? random})
      : _secrets = secrets ?? const KeychainSecrets(),
        _random = random ?? Random.secure();

  final SecretStore _secrets;
  final Random _random;

  static const _kEmail = 'account.email';
  static const _kSalt = 'account.salt';
  static const _kCreated = 'account.createdAt';
  static const _kSignedIn = 'account.signedIn';
  static const _kHash = 'account.passwordHash';

  /// Email dinormalkan sebelum dibandingkan. Orang mengetik alamat yang sama
  /// dengan kapitalisasi berbeda tiap hari, dan menolak mereka karena itu
  /// adalah kegagalan yang terasa seperti bug.
  static String normalise(String email) => email.trim().toLowerCase();

  @override
  Future<Account?> signedIn() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kSignedIn) != true) return null;
    return _stored(prefs);
  }

  Account? _stored(SharedPreferences prefs) {
    final email = prefs.getString(_kEmail);
    final created = prefs.getString(_kCreated);
    if (email == null || created == null) return null;
    return Account(
      email: email,
      createdAt: DateTime.tryParse(created) ?? clock.now(),
    );
  }

  @override
  Future<SignUpResult> signUp({required String email, required String password}) async {
    final prefs = await SharedPreferences.getInstance();
    final wanted = normalise(email);

    // Satu akun per perangkat untuk sekarang. Beberapa akun baru masuk akal
    // setelah ada server yang bisa memisahkan datanya.
    final existing = prefs.getString(_kEmail);
    if (existing != null && existing != wanted) {
      return const SignUpError(SignUpFailure.emailTaken);
    }
    if (existing == wanted) {
      return const SignUpError(SignUpFailure.emailTaken);
    }

    final salt = _newSalt();
    final hash = _derive(password, salt);
    final now = clock.now();

    await prefs.setString(_kEmail, wanted);
    await prefs.setString(_kSalt, salt);
    await prefs.setString(_kCreated, now.toIso8601String());
    await prefs.setBool(_kSignedIn, true);
    await _secrets.write(_kHash, hash);

    return SignUpOk(Account(email: wanted, createdAt: now));
  }

  @override
  Future<SignInResult> signIn({required String email, required String password}) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kEmail);
    final salt = prefs.getString(_kSalt);
    final hash = await _secrets.read(_kHash);

    if (stored == null || salt == null || hash == null) {
      return const SignInError(SignInFailure.noAccount);
    }
    if (normalise(email) != stored) {
      return const SignInError(SignInFailure.wrongEmail);
    }
    // Perbandingan waktu-tetap. Berlebihan untuk hash di perangkat sendiri,
    // tapi ini kebiasaan yang tidak ada alasannya untuk tidak dipakai.
    if (!_constantTimeEquals(_derive(password, salt), hash)) {
      return const SignInError(SignInFailure.wrongPassword);
    }

    await prefs.setBool(_kSignedIn, true);
    return SignInOk(_stored(prefs)!);
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    // Hanya menurunkan bendera. Akunnya tetap ada supaya orang bisa masuk
    // lagi — keluar bukan berarti menghapus diri sendiri.
    await prefs.setBool(_kSignedIn, false);
  }

  @override
  Future<void> erase() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [_kEmail, _kSalt, _kCreated, _kSignedIn]) {
      await prefs.remove(k);
    }
    await _secrets.delete(_kHash);
  }

  String _newSalt() {
    final bytes = Uint8List(16);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return base64Encode(bytes);
  }

  /// PBKDF2-HMAC-SHA256. Ditulis tangan karena `crypto` menyediakan HMAC tapi
  /// tidak PBKDF2, dan menambah satu paket lagi untuk dua puluh baris ini
  /// tidak sepadan.
  String _derive(String password, String saltB64) {
    final salt = base64Decode(saltB64);
    final hmac = Hmac(sha256, utf8.encode(password));

    // Blok pertama saja: SHA-256 menghasilkan 32 byte, dan 32 byte sudah
    // panjang kunci yang diinginkan. Blok kedua tidak menambah apa pun.
    final first = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    var previous = first;
    final result = List<int>.from(first);

    for (var i = 1; i < _iterations; i++) {
      previous = hmac.convert(previous).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= previous[j];
      }
    }
    return base64Encode(result);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
