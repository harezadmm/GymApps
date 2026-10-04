/// Ringkasan sesi v3: hero dengan popper, dua angka besar, kisi 2×2, kartu
/// otot yang dilatih, rekor, target berikutnya, dan banner rutinitas yang
/// diperbarui dengan tautan Batalkan / Simpan lagi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/charts.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/routine_sync.dart';
import 'package:gymapps/features/session/finish_screen.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

SessionExercise _ex(String id, String name, double w) => SessionExercise(
      name: name,
      icon: Icons.fitness_center,
      config: ExerciseConfig(exerciseId: id, policy: ProgressionPolicy.linear, sets: 2, reps: 8, weight: w),
      sets: [SetRow(weight: w, reps: 8, done: true), SetRow(weight: w, reps: 8, done: true)],
      previous: const ['—', '—'],
    );

const _routine = Routine(id: 'r1', name: 'Push', exercises: [
  ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, sets: 3, reps: 8, weight: 60),
]);

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.indonesian),
        child: MaterialApp(theme: buildGymTheme(brightness: Brightness.light), home: home),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
    store = WorkoutStore();
    await store.load('a@x.com');
    await store.saveRoutine(_routine);
  });

  Widget screen({bool updated = true}) {
    final layout = [('0025', 2), ('0030', 2)];
    return FinishScreen(
      routineName: 'Push',
      exercises: [_ex('0025', 'Barbell Bench Press', 60), _ex('0030', 'Dumbbell Fly', 20)],
      history: const [],
      elapsed: const Duration(minutes: 42, seconds: 10),
      dateLabel: 'Min 4 Okt · 18.40',
      originalRoutine: _routine,
      diff: diffRoutine(_routine, layout),
      routineUpdated: updated,
    );
  }

  testWidgets('ringkasan: hero, angka besar, kisi, otot, rekor, target, tombol Selesai kaca', (tester) async {
    _phone(tester);
    await tester.runAsync(() => ExerciseCatalog.load());
    await tester.pumpWidget(_wrap(store, screen()));
    await _settle(tester);

    expect(find.text('Sesi selesai'), findsOneWidget);
    expect(find.text('42:10'), findsOneWidget);
    expect(find.text('Durasi'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
    expect(find.text('Set kerja'), findsOneWidget);
    expect(find.text('Total rep'), findsOneWidget);
    expect(find.text('32'), findsOneWidget);
    expect(find.text('Rekor baru'), findsWidgets);
    expect(find.text('Target naik'), findsOneWidget);
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byType(MuscleMap), 200, scrollable: scroll);
    expect(find.byType(MuscleMap), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Target sesi berikutnya'), 200, scrollable: scroll);
    expect(find.text('Target sesi berikutnya'), findsOneWidget);
    final done = find.widgetWithText(GymButton, 'Selesai');
    expect(done, findsOneWidget);
    expect(tester.widget<GymButton>(done).tone, GymButtonTone.primary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner rutinitas diperbarui: Batalkan mengembalikan rutinitas dan menawarkan Simpan lagi',
      (tester) async {
    _phone(tester);
    await tester.runAsync(() => ExerciseCatalog.load());
    await tester.pumpWidget(_wrap(store, screen()));
    await _settle(tester);
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Batalkan'), 200, scrollable: scroll);
    expect(find.text('Rutinitas Push diperbarui'), findsOneWidget);
    await tester.tap(find.text('Batalkan'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _settle(tester);
    expect(store.routineById('r1')!.exercises.length, 1, reason: 'kembali ke susunan asli');
    expect(find.text('Simpan lagi'), findsOneWidget);
  });
}
