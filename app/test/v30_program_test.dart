/// Tab Program v3: kartu program aktif, kisi rutinitas dengan odometer volume
/// rencana dan tombol mulai, aturan program, dan keadaan tanpa program.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/session_plan.dart';
import 'package:gymapps/domain/units.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:gymapps/features/workout/program_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, Widget child) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.indonesian),
        child: MaterialApp(theme: buildGymTheme(brightness: Brightness.light), home: Scaffold(body: child)),
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<WorkoutStore> _ppl(WidgetTester tester) async {
  final store = WorkoutStore();
  await tester.runAsync(() async {
    await ExerciseCatalog.load();
    await store.load('a@x.com');
    await store.applyTemplate('ppl');
  });
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

Finder get _scrollable => find.byType(Scrollable).first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
  });

  test('plannedSessionVolume = Σ beban × rep set kerja dari rencana', () {
    const routine = Routine(id: 'r', name: 'Push', exercises: [
      ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, sets: 3, reps: 8, weight: 60),
    ]);
    final plan = planExercise(configIn(routine.exercises.first, WeightUnit.kg), const [],
        routineDefault: routine.policy, unit: 'kg');
    final expected = plan.sets.where((s) => !s.isWarmup).fold(0.0, (a, s) => a + s.weight * s.reps);
    expect(expected, greaterThan(0));
    expect(plannedSessionVolume(routine, const [], WeightUnit.kg), closeTo(expected, 0.01));
    expect(plannedSessionVolume(const Routine(id: 'x', name: 'Kosong'), const [], WeightUnit.kg), 0);
  });

  testWidgets('Program: kartu program, kisi rutinitas dengan odometer dan tombol mulai, aturan', (tester) async {
    _phone(tester);
    final store = await _ppl(tester);
    await tester.pumpWidget(_wrap(store, const ProgramScreen()));
    await _settle(tester);

    expect(find.text('PROGRAM AKTIF'), findsOneWidget);
    expect(find.text('Push / Pull / Legs'), findsOneWidget);
    expect(find.text('Ganti program'), findsOneWidget);
    expect(find.text('Lewati sesi'), findsOneWidget);
    expect(find.text('Library gerakan'), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Berikutnya'), findsOneWidget);
    expect(find.byType(Odometer), findsNWidgets(3));
    expect(find.text('Tambah rutinitas'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Aturan program'), 200, scrollable: _scrollable);
    await _settle(tester);
    expect(find.text('Mode'), findsOneWidget);
    expect(find.text('Rotasi'), findsOneWidget);
    expect(find.text('Istirahat minimum antar sesi'), findsOneWidget);
    expect(find.text('0 hari'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rest-plus')));
    await _settle(tester);
    expect(store.program!.minRestDays, 1);
    expect(find.text('1 hari'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mulai di kartu Push membuka sesi Push', (tester) async {
    _phone(tester);
    final store = await _ppl(tester);
    await tester.pumpWidget(_wrap(store, const ProgramScreen()));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('start-ppl-0')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _settle(tester);
    expect(find.byType(SessionScreen), findsOneWidget);
    expect(tester.widget<SessionScreen>(find.byType(SessionScreen)).routineName, 'Push');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tanpa program: Pilih program & Susun sendiri, kartu tambah rutinitas tetap ada', (tester) async {
    _phone(tester);
    final store = WorkoutStore();
    await tester.runAsync(() async {
      await ExerciseCatalog.load();
      await store.load('b@x.com');
    });
    // Rutinitas lepas tanpa program tidak bisa ada: saveRoutine selalu
    // membuat program "My split" — jadi keadaan tanpa program = tanpa rutinitas.
    await tester.pumpWidget(_wrap(store, const ProgramScreen()));
    await _settle(tester);
    expect(find.text('Belum ada program'), findsOneWidget);
    expect(find.text('Pilih program'), findsOneWidget);
    expect(find.text('Susun sendiri'), findsOneWidget);
    expect(find.text('Tambah rutinitas'), findsOneWidget);
    expect(find.byType(Odometer), findsNothing);
    expect(find.text('Aturan program'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Urutkan membuka sheet urutan dan memindah rutinitas', (tester) async {
    _phone(tester);
    final store = await _ppl(tester);
    await tester.pumpWidget(_wrap(store, const ProgramScreen()));
    await _settle(tester);
    await tester.tap(find.text('Urutkan'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Turunkan').first);
    await _settle(tester);
    expect(store.program!.order.first, 'ppl-1');
    expect(store.program!.order[1], 'ppl-0');
  });
}
