/// Profil v3 (spec UI-V3 §7.8): halaman dorong dengan nav kaca, kartu akun
/// dengan baris sinkron bertitik, tiga grup LATIHAN / TAMPILAN / DATA & AKUN,
/// lima titik warna aksen yang bisa diketuk, dan Keluar sebagai baris danger
/// di grup terakhir — bukan tombol besar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/gym_icons.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/backend.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/features/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend yang selalu menerima dorongan — cukup untuk status "tersinkron".
class _StubBackend implements Backend {
  @override
  String? get signedInEmail => null;
  @override
  Future<int?> getRev() async => null;
  @override
  Future<PulledState?> pull() async => null;
  @override
  Future<PushResult> push({required int? baseRev, required Map<String, dynamic> state}) async =>
      const PushAccepted(1);
}

/// Profil dibuka seperti di aplikasi: didorong dari layar lain (avatar
/// Beranda), supaya Keluar punya halaman untuk ditutup.
Widget _wrap(
  WorkoutStore store, {
  ValueChanged<Color>? onAccentChanged,
  VoidCallback? onSignOut,
  Brightness brightness = Brightness.light,
}) =>
    WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.indonesian),
        child: MaterialApp(
          theme: buildGymTheme(brightness: brightness),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      asPage: true,
                      language: AppLanguage.indonesian,
                      onLanguageChanged: (_) {},
                      onSignOut: onSignOut ?? () {},
                      onAccentChanged: onAccentChanged,
                      onThemeModeChanged: (_) {},
                      email: 'budi@contoh.com',
                    ),
                  )),
                  child: const Text('Go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _open(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.tap(find.text('Go'));
  await _settle(tester);
}

Finder _scroll() => find.byType(Scrollable).first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brightness in Brightness.values) {
    testWidgets('susunan v3 (${brightness.name}): nav kaca, akun, tiga grup, baris Keluar danger', (tester) async {
      _phone(tester);
      final store = WorkoutStore();
      await store.load();
      await _open(tester, _wrap(store, brightness: brightness));
      expect(tester.takeException(), isNull);

      expect(find.text('Profil'), findsOneWidget);
      expect(find.widgetWithIcon(GlassIconButton, GymIcons.arrowLeft), findsOneWidget);
      expect(find.text('budi@contoh.com'), findsOneWidget);
      expect(find.text('BU'), findsOneWidget);
      expect(find.text('Tanpa server'), findsOneWidget, reason: 'tanpa backend: baris sinkron bilang tanpa server');

      expect(find.text('LATIHAN'), findsOneWidget);
      for (final label in ['Satuan berat', 'Istirahat bawaan', 'Faktor deload', 'Catat RIR', 'Layar tetap menyala']) {
        expect(find.widgetWithText(SettingsTile, label), findsOneWidget, reason: label);
      }
      await tester.scrollUntilVisible(find.text('TAMPILAN'), 200, scrollable: _scroll());
      for (final label in ['Minggu dimulai', 'Alat saya', 'Tema', 'Warna aksen', 'Bahasa']) {
        expect(find.widgetWithText(SettingsTile, label), findsOneWidget, reason: label);
      }
      await tester.scrollUntilVisible(find.text('DATA & AKUN'), 200, scrollable: _scroll());
      await tester.scrollUntilVisible(find.text('Keluar'), 200, scrollable: _scroll());
      for (final label in ['Paksa sinkron', 'Impor cadangan', 'Tentang aplikasi', 'Keluar']) {
        expect(find.widgetWithText(SettingsTile, label), findsOneWidget, reason: label);
      }
      expect(find.widgetWithText(SettingsTile, 'Ekspor cadangan (JSON)'), findsOneWidget);
      // Keluar diwarnai danger: ikon dan labelnya memakai tone yang sama.
      final logout = tester.widget<SettingsTile>(find.widgetWithText(SettingsTile, 'Keluar'));
      expect(logout.tone, isNotNull);
      expect(logout.icon, GymIcons.logout);
      expect(find.byType(GymButton), findsNothing, reason: 'tidak ada tombol keluar besar lagi');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('lima titik aksen: ketuk titik ketiga memilih accentChoices[2]', (tester) async {
    _phone(tester);
    final store = WorkoutStore();
    await store.load();
    Color? picked;
    await _open(tester, _wrap(store, onAccentChanged: (c) => picked = c));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('accent-dot-0')), 200, scrollable: _scroll());
    await tester.ensureVisible(find.byKey(const ValueKey('accent-dot-2')));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('accent-dot-$i')), findsOneWidget, reason: 'titik $i');
    }
    await tester.tap(find.byKey(const ValueKey('accent-dot-2')));
    await tester.pump();
    expect(picked, accentChoices[2]);
  });

  testWidgets('baris sinkron: setelah dorongan berhasil bertuliskan "Tersinkron · baru saja"', (tester) async {
    _phone(tester);
    final store = WorkoutStore(_StubBackend());
    await store.load();
    await store.syncNow();
    await _open(tester, _wrap(store));
    expect(find.text('Tersinkron · baru saja'), findsOneWidget);
  });

  testWidgets('Keluar sebagai halaman: menutup halaman lalu memanggil onSignOut', (tester) async {
    _phone(tester);
    final store = WorkoutStore();
    await store.load();
    var signedOut = 0;
    await _open(tester, _wrap(store, onSignOut: () => signedOut++));
    await tester.scrollUntilVisible(find.text('Keluar'), 200, scrollable: _scroll());
    await tester.ensureVisible(find.text('Keluar'));
    await tester.pump();
    await tester.tap(find.text('Keluar'));
    await _settle(tester);
    expect(signedOut, 1);
    expect(find.byType(ProfileScreen), findsNothing);
  });
}
