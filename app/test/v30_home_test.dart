/// Beranda v3: insight dari data, pil status, tiga cincin, kartu sesi
/// berikutnya dengan Mulai sesi/Lewati, minggu ini, dan progres kekuatan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/charts.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/program.dart';
import 'package:gymapps/domain/progression.dart';
import 'package:gymapps/features/home/home_insight.dart';
import 'package:gymapps/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.indonesian),
        child: MaterialApp(theme: buildGymTheme(brightness: Brightness.light), home: Scaffold(body: home)),
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Workout _sesi(String tanggal, {required String rutinitas, double berat = 60}) => Workout(
      date: tanggal,
      routine: rutinitas,
      entries: [
        WorkoutEntry(exerciseId: '0025', sets: [
          SetRow(weight: berat, reps: 8, done: true),
          SetRow(weight: berat, reps: 8, done: true),
        ]),
      ],
    );

Future<WorkoutStore> _storeWithWeek(WidgetTester tester) async {
  final store = WorkoutStore();
  await tester.runAsync(() async {
    await ExerciseCatalog.load();
    await store.load('a@x.com');
    await store.applyTemplate('ppl');
    final today = isoDate(DateTime.now());
    await store.addWorkout(_sesi(today, rutinitas: 'Push'), routineId: 'ppl-0');
    await store.addWorkout(_sesi(today, rutinitas: 'Pull', berat: 40), routineId: 'ppl-1');
  });
  return store;
}

Finder get _scrollable => find.byType(Scrollable).first;

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
  });

  group('homeInsight', () {
    const t = Strings(AppLanguage.indonesian);
    final today = DateTime(2026, 10, 4);
    const push = Routine(id: 'r', name: 'Push');

    test('dua gerakan naik', () {
      final r = homeInsight(
        t: t,
        next: NextSession(routine: push, due: today, today: today),
        weekdayMode: false,
        targets: const [
          ('Dumbbell Fly', PrescriptionKind.up),
          ('Chest Press', PrescriptionKind.up),
          ('Curl', PrescriptionKind.hold),
        ],
        daysSince: 5,
      );
      expect(r.title, 'Push hari ini, dua gerakan siap naik');
      expect(r.body, 'Terakhir dilatih 5 hari lalu. Dumbbell Fly dan Chest Press naik targetnya sesi ini.');
    });

    test('semua tahan, belum pernah dilatih', () {
      final r = homeInsight(
        t: t,
        next: NextSession(routine: push, due: today, today: today),
        weekdayMode: false,
        targets: const [('Curl', PrescriptionKind.hold), ('Row', PrescriptionKind.first)],
        daysSince: null,
      );
      expect(r.title, 'Push hari ini, kejar rep');
      expect(r.body, startsWith('Belum pernah dilatih.'));
    });

    test('masa pemulihan di rotasi', () {
      final r = homeInsight(
        t: t,
        next: NextSession(routine: push, due: today.add(const Duration(days: 2)), today: today),
        weekdayMode: false,
        targets: const [],
        daysSince: 1,
      );
      expect(r.title, 'Hari pemulihan');
      expect(r.body, contains('Push jatuh pada Selasa'));
    });

    test('tanpa program', () {
      final r = homeInsight(t: t, next: null, weekdayMode: false, targets: const [], daysSince: null);
      expect(r.title, 'Belum ada program');
    });
  });

  testWidgets('Beranda: pil status, tiga cincin, sesi berikutnya, minggu ini, progres kekuatan', (tester) async {
    _phone(tester);
    final store = await _storeWithWeek(tester);
    int? opened;
    await tester.pumpWidget(_wrap(store, HomeScreen(email: 'hariz@gym.app', onOpenTab: (i) => opened = i)));
    await _settle(tester);

    expect(find.text('Push / Pull / Legs'), findsOneWidget);
    expect(find.text('Tanpa server'), findsOneWidget);
    expect(find.text('Sesi minggu ini'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('Volume vs lalu'), findsOneWidget);
    expect(find.text('Sesi berikutnya'), findsOneWidget);
    expect(find.text('Pilih lain'), findsOneWidget);
    expect(find.text('Legs'), findsWidgets);
    expect(find.text('Mulai sesi'), findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Minggu ini'), 200, scrollable: _scrollable);
    expect(find.text('2 dari 3 sesi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Progres kekuatan'), 200, scrollable: _scrollable);
    await _settle(tester);
    expect(find.byType(Sparkline), findsWidgets);
    await tester.tap(find.text('Semua'));
    expect(opened, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pil program membuka tab Program; kotak hari → sheet → Lihat riwayat (tab 1)', (tester) async {
    _phone(tester);
    final store = await _storeWithWeek(tester);
    int? opened;
    await tester.pumpWidget(_wrap(store, HomeScreen(onOpenTab: (i) => opened = i)));
    await _settle(tester);
    await tester.tap(find.text('Push / Pull / Legs'));
    expect(opened, 2);

    final cell = find.byKey(ValueKey('home-day-${isoDate(DateTime.now())}'));
    await tester.scrollUntilVisible(cell, 200, scrollable: _scrollable);
    await _settle(tester);
    await tester.tap(cell);
    await _settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Lihat riwayat'));
    await _settle(tester);
    expect(opened, 1);
  });

  testWidgets('tanpa program: pil "Pilih program" dan kartu belum ada program', (tester) async {
    _phone(tester);
    final store = WorkoutStore();
    await tester.runAsync(() async {
      await ExerciseCatalog.load();
      await store.load('b@x.com');
    });
    await tester.pumpWidget(_wrap(store, const HomeScreen()));
    await _settle(tester);
    expect(find.text('Pilih program'), findsWidgets);
    expect(find.text('Belum ada program'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
