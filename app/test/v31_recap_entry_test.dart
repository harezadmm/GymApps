/// Pintu masuk Recap: kartu di Beranda (minggu ini → minggu lalu →
/// tersembunyi) dan tombol Recap di header Statistik.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/program.dart';
import 'package:gymapps/domain/recap.dart';
import 'package:gymapps/features/home/home_screen.dart';
import 'package:gymapps/features/recap/recap_screen.dart';
import 'package:gymapps/features/stats/stats_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Workout _w(DateTime day, {int dur = 2700}) => Workout(
      date: isoDate(day),
      durationSeconds: dur,
      entries: [
        WorkoutEntry(exerciseId: '0025', sets: const [
          SetRow(weight: 60, reps: 8, done: true),
          SetRow(weight: 60, reps: 8, done: true),
        ]),
      ],
    );

Widget _wrap(WorkoutStore store, Widget body) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.indonesian),
        child: MaterialApp(theme: buildGymTheme(), home: Scaffold(body: body)),
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
}

Future<WorkoutStore> _store(WidgetTester tester, List<Workout> workouts) async {
  final store = WorkoutStore();
  await tester.runAsync(() async {
    await ExerciseCatalog.load();
    await store.load('a@x.com');
    for (final w in workouts) {
      await store.addWorkout(w);
    }
  });
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
  });

  final today = dateOnly(DateTime.now());
  final thisWeek = recapRangeFor(RecapPeriod.week, today);
  final lastWeekDay = thisWeek.start.subtract(const Duration(days: 3));

  testWidgets('Beranda: ada sesi minggu ini → kartu "Recap minggu ini" membuka Recap minggu ini', (tester) async {
    _phone(tester);
    final store = await _store(tester, [_w(lastWeekDay), _w(today)]);
    await tester.pumpWidget(_wrap(store, HomeScreen(email: 'a@x.com', onOpenProfile: () {})));
    await _settle(tester);
    final card = find.byKey(const ValueKey('home-recap'));
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Recap minggu ini'), findsOneWidget);
    expect(find.descendant(of: card, matching: find.textContaining('1 sesi')), findsOneWidget);
    await tester.tap(card);
    await _settle(tester);
    expect(find.byType(RecapScreen), findsOneWidget);
    expect(find.text('Minggu ini'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Beranda: minggu ini kosong, minggu lalu ada → "Recap minggu lalu"', (tester) async {
    _phone(tester);
    final store = await _store(tester, [_w(lastWeekDay)]);
    await tester.pumpWidget(_wrap(store, HomeScreen(email: 'a@x.com', onOpenProfile: () {})));
    await _settle(tester);
    final card = find.byKey(const ValueKey('home-recap'));
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Recap minggu lalu'), findsOneWidget);
    await tester.tap(card);
    await _settle(tester);
    expect(find.byType(RecapScreen), findsOneWidget);
    expect(find.text('Minggu lalu'), findsOneWidget);
  });

  testWidgets('Beranda: dua minggu terakhir kosong → kartu recap tidak tampil', (tester) async {
    _phone(tester);
    final store = await _store(tester, [_w(thisWeek.start.subtract(const Duration(days: 30)))]);
    await tester.pumpWidget(_wrap(store, HomeScreen(email: 'a@x.com', onOpenProfile: () {})));
    await _settle(tester);
    expect(find.byKey(const ValueKey('home-recap')), findsNothing);
  });

  testWidgets('Statistik: tombol Recap di header membuka Recap', (tester) async {
    _phone(tester);
    final store = await _store(tester, [_w(today)]);
    await tester.pumpWidget(_wrap(store, const StatsScreen()));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(GymButton, 'Recap');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    await tester.tap(button);
    await _settle(tester);
    expect(find.byType(RecapScreen), findsOneWidget);
  });
}
