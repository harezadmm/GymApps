/// Penjaga layar Profil.
///
/// Semua test di sini lahir dari satu bug yang lolos sampai ke simulator:
/// kartu akun menampilkan `hariz@example.com` yang di-hardcode, sehingga
/// setiap orang melihat email orang lain di layar akunnya sendiri. Bug seperti
/// itu tidak menimbulkan error, tidak membuat test lain gagal, dan hanya
/// ketahuan kalau ada yang benar-benar membukanya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/backend.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/features/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend yang tidak pernah dipanggil — cuma supaya `hasBackend` bernilai true
/// dan status sinkronnya bukan "sync mati".
class _StubBackend implements Backend {
  @override
  Future<int?> getRev() async => null;
  @override
  Future<PulledState?> pull() async => null;
  @override
  Future<PushResult> push({
    required int? baseRev,
    required Map<String, dynamic> state,
  }) async =>
      const PushAccepted(1);
}

Widget _wrap(WorkoutStore store, {required String? email}) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: Strings(AppLanguage.english),
        child: MaterialApp(
          theme: buildGymTheme(),
          // Scaffold-nya ditambahkan di sini karena di aplikasi asli
          // ProfileScreen memang duduk di dalam Scaffold milik HomeShell —
          // ia bukan layar berdiri sendiri.
          home: Scaffold(
            body: ProfileScreen(
              language: AppLanguage.english,
              onLanguageChanged: (_) {},
              onSignOut: () {},
              email: email,
            ),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('menampilkan email akun yang sedang masuk', (tester) async {
    await tester.pumpWidget(_wrap(WorkoutStore(), email: 'nyata@contoh.com'));
    await tester.pump();

    expect(find.text('nyata@contoh.com'), findsOneWidget);
  });

  testWidgets('tidak ada alamat contoh yang tertinggal di layar', (tester) async {
    // Penjaga langsung terhadap bug aslinya.
    await tester.pumpWidget(_wrap(WorkoutStore(), email: 'nyata@contoh.com'));
    await tester.pump();

    expect(find.text('hariz@example.com'), findsNothing);
  });

  testWidgets('inisial avatar diambil dari email, bukan dipatok', (tester) async {
    await tester.pumpWidget(_wrap(WorkoutStore(), email: 'budi@contoh.com'));
    await tester.pump();

    expect(find.text('BU'), findsOneWidget);
    expect(find.text('HZ'), findsNothing);
  });

  group('status sinkron', () {
    testWidgets('tanpa backend disebut mati, bukan tersinkron', (tester) async {
      final store = WorkoutStore();
      await store.load();
      await tester.pumpWidget(_wrap(store, email: 'a@b.co'));
      await tester.pump();

      expect(find.text('Sync off — local only'), findsOneWidget);
      expect(find.text('Synced just now'), findsNothing);
    });

    testWidgets('dengan backend tapi belum pernah dorong, disebut belum tersinkron',
        (tester) async {
      // Ini kasus yang dulu berbohong: kredensial ada, jadi layar menulis
      // "Synced just now" padahal belum satu byte pun naik.
      final store = WorkoutStore(_StubBackend());
      await tester.pumpWidget(_wrap(store, email: 'a@b.co'));
      await tester.pump();

      expect(find.text('Not synced yet'), findsOneWidget);
      expect(find.text('Synced just now'), findsNothing);
    });

    testWidgets('baru menyebut tersinkron setelah dorongan berhasil', (tester) async {
      final store = WorkoutStore(_StubBackend());
      await store.load();
      await store.syncNow();
      await tester.pumpWidget(_wrap(store, email: 'a@b.co'));
      await tester.pump();

      expect(find.text('Synced just now'), findsOneWidget);
    });
  });

  testWidgets('nomor versi tidak ditulis tangan di layar', (tester) async {
    // package_info_plus tidak menjawab di test host, jadi yang bisa dibuktikan
    // di sini adalah tidak adanya angka mati — persis bug keduanya.
    await tester.pumpWidget(_wrap(WorkoutStore(), email: 'a@b.co'));
    await tester.pump();

    expect(find.text('v1.0.0'), findsNothing);
  });
}
