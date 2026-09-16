/// Layar masuk, digerakkan seperti orang sungguhan.
///
/// Test-test ini menggantikan langkah terakhir smoke test yang tidak selesai
/// di simulator: keluar, lalu masuk lagi dengan kata sandi yang benar, dan
/// riwayat latihannya harus masih ada. Yang ditekan di sini adalah field dan
/// tombol yang sama dengan yang ditekan jari.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/account_store.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/features/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keychain sungguhan tidak ada di test host. Sengaja ditulis ulang di sini
/// dan tidak diimpor dari test lain — satu berkas test sebaiknya bisa dibaca
/// dan dijalankan tanpa mengejar definisi ke tempat lain.
class _MemorySecrets implements SecretStore {
  final _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

Widget _wrap(AccountStore accounts, WorkoutStore store, {required VoidCallback onSignedIn}) =>
    WorkoutScope(
      store: store,
      child: AppStrings(
        strings: Strings(AppLanguage.english),
        child: MaterialApp(
          theme: buildGymTheme(),
          home: LoginScreen(
            store: accounts,
            onSignedIn: onSignedIn,
            onCreateAccount: () {},
          ),
        ),
      ),
    );

Workout _sesi() => const Workout(
      date: '2026-09-17',
      routine: 'Pull',
      durationSeconds: 1800,
      entries: [
        WorkoutEntry(
          exerciseId: 'barbell-row',
          sets: [SetRow(weight: 72.5, reps: 8, done: true)],
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalAccountStore accounts;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    accounts = LocalAccountStore(secrets: _MemorySecrets());
  });

  Future<void> isiForm(WidgetTester tester, String email, String password) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), password);
    await tester.tap(find.text('SIGN IN'));
    // PBKDF2 50 ribu putaran; pump sekali tidak cukup menunggunya selesai.
    await tester.pumpAndSettle();
  }

  testWidgets('kata sandi benar membuka aplikasi, dan riwayatnya masih ada', (tester) async {
    // Ini inti test-nya — langkah smoke test yang tidak sempat dijalankan
    // karena panel simulatornya crash.
    await accounts.signUp(email: 'uji@contoh.com', password: 'barbel123');
    final store = WorkoutStore();
    await store.load();
    await store.addWorkout(_sesi());
    await accounts.signOut();

    var masuk = false;
    await tester.pumpWidget(_wrap(accounts, store, onSignedIn: () => masuk = true));
    await isiForm(tester, 'uji@contoh.com', 'barbel123');

    expect(masuk, isTrue, reason: 'kata sandi benar seharusnya diterima');
    expect(store.workouts.length, 1);
    expect(store.workouts.first.routine, 'Pull');
    expect(store.workouts.first.entries.first.sets.first.weight, 72.5);
  });

  testWidgets('riwayat bertahan lewat store baru setelah masuk lagi', (tester) async {
    // Store yang dibuat ulang meniru aplikasi yang benar-benar ditutup, bukan
    // sekadar berpindah layar.
    await accounts.signUp(email: 'uji@contoh.com', password: 'barbel123');
    final pertama = WorkoutStore();
    await pertama.load();
    await pertama.addWorkout(_sesi());
    await accounts.signOut();

    final kedua = WorkoutStore();
    await kedua.load();

    var masuk = false;
    await tester.pumpWidget(_wrap(accounts, kedua, onSignedIn: () => masuk = true));
    await isiForm(tester, 'uji@contoh.com', 'barbel123');

    expect(masuk, isTrue);
    expect(kedua.workouts.length, 1, reason: 'riwayat harus terbaca dari disk');
  });

  testWidgets('kata sandi salah ditolak dan tidak membuka apa pun', (tester) async {
    await accounts.signUp(email: 'uji@contoh.com', password: 'barbel123');
    await accounts.signOut();

    var masuk = false;
    await tester.pumpWidget(_wrap(accounts, WorkoutStore(), onSignedIn: () => masuk = true));
    await isiForm(tester, 'uji@contoh.com', 'salahbanget');

    expect(masuk, isFalse);
    expect(find.text('Wrong password.'), findsOneWidget);
  });

  testWidgets('tanpa akun sama sekali, pesannya menyuruh mendaftar', (tester) async {
    var masuk = false;
    await tester.pumpWidget(_wrap(accounts, WorkoutStore(), onSignedIn: () => masuk = true));
    await isiForm(tester, 'siapa@pun.com', 'barbel123');

    expect(masuk, isFalse);
    expect(find.text('No account on this device yet. Create one first.'), findsOneWidget);
  });

  testWidgets('banner tidak lagi menyiratkan datanya tidak ke mana-mana', (tester) async {
    // Build test tidak punya kredensial Supabase, jadi yang benar di sini
    // adalah kalimat "lokal saja" — dan kalimat lama yang membingungkan itu
    // memang harus sudah hilang.
    await tester.pumpWidget(_wrap(accounts, WorkoutStore(), onSignedIn: () {}));
    await tester.pump();

    expect(find.text('Everything works offline after the first sign-in.'), findsNothing);
    expect(find.text('Everything stays on this device. No server is configured.'), findsOneWidget);
  });
}
