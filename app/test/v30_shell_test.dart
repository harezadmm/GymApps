/// Navigasi UI v3: empat tab berlabel + tombol tengah kaca yang membuka
/// lembar Mulai sesi, dan Profil sebagai halaman dorong dari avatar Beranda.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/glass.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/features/history/history_screen.dart';
import 'package:gymapps/features/profile/profile_screen.dart';
import 'package:gymapps/features/session/start_session_sheet.dart';
import 'package:gymapps/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<WorkoutStore> _store(WidgetTester tester) async {
  final store = WorkoutStore();
  await tester.runAsync(() async {
    await ExerciseCatalog.load();
    await store.load('a@x.com');
    await store.applyTemplate('ppl');
  });
  return store;
}

Widget _wrap(WorkoutStore store, {VoidCallback? onSignOut}) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.indonesian),
        child: MaterialApp(
          theme: buildGymTheme(),
          home: HomeShell(
            language: AppLanguage.indonesian,
            onLanguageChanged: (_) {},
            onSignOut: onSignOut ?? () {},
            email: 'hariz@gym.app',
          ),
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
  });

  testWidgets('empat tab berlabel + tombol tengah kaca; Profil bukan tab', (tester) async {
    _phone(tester);
    final store = await _store(tester);
    await tester.pumpWidget(_wrap(store));
    await _settle(tester);
    for (final label in ['Beranda', 'Riwayat', 'Program', 'Statistik']) {
      expect(find.text(label), findsWidgets, reason: 'tab $label');
    }
    expect(find.text('Profil'), findsNothing);
    final center = find.byKey(const ValueKey('tab-start'));
    expect(center, findsOneWidget);
    expect(tester.getSize(center), const Size(50, 50));
    final glass = tester.widget<GlassSurface>(find.descendant(of: center, matching: find.byType(GlassSurface)));
    expect(glass.tone, GlassTone.tinted);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tombol + membuka lembar Mulai sesi dengan rutinitas program', (tester) async {
    _phone(tester);
    final store = await _store(tester);
    await tester.pumpWidget(_wrap(store));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('tab-start')));
    await _settle(tester);
    expect(find.byType(StartSessionSheet), findsOneWidget);
    expect(find.text('Sesi bebas'), findsOneWidget);
    expect(find.text('Catat sesi yang sudah lewat'), findsOneWidget);
    final sheet = find.byType(StartSessionSheet);
    expect(find.descendant(of: sheet, matching: find.text('Push')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Pull')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Berikutnya')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('avatar membuka Profil sebagai halaman; Keluar menutupnya dulu', (tester) async {
    _phone(tester);
    final store = await _store(tester);
    var signedOut = 0;
    await tester.pumpWidget(_wrap(store, onSignOut: () => signedOut++));
    await _settle(tester);
    await tester.tap(find.byTooltip('Buka profil'));
    await _settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Keluar'), 300, scrollable: find.byType(Scrollable).last);
    await tester.pump();
    await tester.tap(find.text('Keluar'));
    await _settle(tester);
    expect(signedOut, 1);
    expect(find.byType(ProfileScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tab Statistik dan Riwayat dibuka dari tab bar', (tester) async {
    _phone(tester);
    final store = await _store(tester);
    await tester.pumpWidget(_wrap(store));
    await _settle(tester);
    await tester.tap(find.text('Statistik'));
    await _settle(tester);
    expect(find.text('Keseimbangan'), findsOneWidget);
    await tester.tap(find.text('Riwayat').first);
    await _settle(tester);
    expect(find.byType(HistoryScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
