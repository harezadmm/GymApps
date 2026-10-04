/// v2.2 — layar sesi: konfirmasi selesai, penyelarasan rutinitas, kapsul
/// timer.
///
/// Dua keluhan yang melahirkan test ini:
/// * "Salah selesai-in split, padahal niatku cuma selesai-in timer" — FINISH
///   dulu langsung menutup sesi, dan kapsul timer di sebelahnya bukan tombol.
/// * "Gerakan yang kutambah hari ini hilang di sesi berikutnya" — pertanyaan
///   "perbarui rutinitas?" tidak punya jawaban bawaan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/gym_icons.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/routine_sync.dart';
import 'package:gymapps/features/session/finish_screen.dart';
import 'package:gymapps/features/session/rest_pill.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        child: MaterialApp(theme: buildGymTheme(), home: home),
      ),
    );

/// Bench press dua set kerja; [done] mencentang set pertama saja, supaya ada
/// satu set yang "belum dicentang" untuk banner peringatan.
SessionExercise _bench({bool done = false, bool expanded = true}) => SessionExercise(
      name: 'Barbell Bench Press',
      icon: Icons.fitness_center,
      config: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, sets: 2, reps: 8, weight: 60),
      sets: [SetRow(weight: 60, reps: 8, done: done), const SetRow(weight: 60, reps: 8)],
      previous: const ['60 × 8', '60 × 8'],
      expanded: expanded,
    );

SessionExercise _fly() => SessionExercise(
      name: 'Cable Fly',
      icon: Icons.fitness_center,
      config: const ExerciseConfig(exerciseId: 'fly', sets: 3, reps: 12, repsMin: 8, weight: 20, policy: ProgressionPolicy.double_),
      sets: const [
        SetRow(weight: 20, reps: 12, done: true),
        SetRow(weight: 20, reps: 12, done: true),
        SetRow(weight: 20, reps: 12, done: true),
      ],
      previous: const ['—', '—', '—'],
      expanded: false,
    );

/// HP kecil yang umum: 360 × 780 dp.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Buka lembar konfirmasi lewat tombol FINISH.
Future<void> _openFinishSheet(WidgetTester tester) async {
  await tester.tap(find.text('Finish'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('routine_sync', () {
    const bench = ExerciseConfig(exerciseId: '0025', sets: 3, reps: 8, weight: 60, restSeconds: 120, increment: 2.5);
    const dips = ExerciseConfig(exerciseId: 'dips', sets: 3, reps: 10, bodyweight: true);
    const fly = ExerciseConfig(exerciseId: 'fly', sets: 3, reps: 12, repsMin: 8, weight: 20, policy: ProgressionPolicy.double_);
    const push = Routine(id: 'r1', name: 'Push', policy: ProgressionPolicy.linear, exercises: [bench, dips]);

    test('gerakan lama mempertahankan konfigurasinya, hanya set yang ikut sesi', () {
      final next = syncRoutineWithSession(push, [(bench.copyWith(weight: 65, restSeconds: 30), 4), (dips, 3)]);
      final b = next.exercises.first;
      expect(b.sets, 4);
      // Beban, istirahat, dan kelipatan rutinitas tidak ditulis ulang oleh
      // sesi — sesi hanya tahu susunannya.
      expect(b.weight, 60);
      expect(b.restSeconds, 120);
      expect(b.increment, 2.5);
      expect(next.policy, ProgressionPolicy.linear);
      expect(next.name, 'Push');
    });

    test('gerakan baru masuk dengan config kg dari sesi, yang dibuang keluar, urutan ikut sesi', () {
      final next = syncRoutineWithSession(push, [(fly, 3), (bench, 3)]);
      expect(next.exercises.map((e) => e.exerciseId), ['fly', '0025']);
      final f = next.exercises.first;
      expect(f.sets, 3);
      expect(f.weight, 20);
      expect(f.policy, ProgressionPolicy.double_);
      expect(f.repsMin, 8);
    });

    test('set kerja 0 tidak menulis 0 ke rutinitas', () {
      final next = syncRoutineWithSession(push, [(bench, 0), (fly, 0)]);
      expect(next.exercises.first.sets, 3);
      expect(next.exercises.last.sets, 3);
    });

    test('superset mengikuti sesi', () {
      final next = syncRoutineWithSession(push, [(bench.copyWith(superset: true), 3), (dips, 3)]);
      expect(next.exercises.first.superset, isTrue);
      expect(next.exercises.last.superset, isFalse);
    });

    test('diffRoutine: ditambah, dibuang, set berubah', () {
      final d = diffRoutine(push, [('0025', 4), ('fly', 3)]);
      expect(d.added, ['fly']);
      expect(d.removed, ['dips']);
      expect(d.setChanges, [('0025', 3, 4)]);
      expect(d.reordered, isFalse);
      expect(d.isEmpty, isFalse);
    });

    test('diffRoutine: urutan berubah saja', () {
      final d = diffRoutine(push, [('dips', 3), ('0025', 3)]);
      expect(d.added, isEmpty);
      expect(d.removed, isEmpty);
      expect(d.setChanges, isEmpty);
      expect(d.reordered, isTrue);
      expect(d.isEmpty, isFalse);
    });

    test('diffRoutine: sama persis → kosong; set 0 bukan perubahan', () {
      expect(diffRoutine(push, [('0025', 3), ('dips', 3)]).isEmpty, isTrue);
      expect(diffRoutine(push, [('0025', 0), ('dips', 3)]).isEmpty, isTrue);
    });

    test('gerakan kembar di rutinitas dipasangkan berurutan, bukan dianggap ditambah', () {
      const twice = Routine(id: 'r2', name: 'Arms', exercises: [bench, bench]);
      final d = diffRoutine(twice, [('0025', 3), ('0025', 4)]);
      expect(d.added, isEmpty);
      expect(d.removed, isEmpty);
      expect(d.setChanges, [('0025', 3, 4)]);
      final next = syncRoutineWithSession(twice, [(bench, 3), (bench, 4)]);
      expect(next.exercises.map((e) => e.sets), [3, 4]);
    });
  });

  group('layar sesi', () {
    late WorkoutStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = WorkoutStore();
      await store.load();
    });

    testWidgets('FINISH membuka lembar konfirmasi; sesi tersimpan hanya setelah FINISH & SAVE', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [_bench(done: true)])));
      await tester.pump();

      await _openFinishSheet(tester);
      expect(find.text('Finish this session?'), findsOneWidget);
      expect(find.textContaining('1 set not ticked'), findsOneWidget);
      expect(store.workouts, isEmpty);

      // Kembali ke sesi: tidak ada yang tersimpan, layar sesi masih di depan.
      await tester.tap(find.text('Back to session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Finish this session?'), findsNothing);
      expect(store.workouts, isEmpty);
      expect(find.byType(SessionScreen), findsOneWidget);

      await _openFinishSheet(tester);
      await tester.tap(find.text('Finish & save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(store.workouts.length, 1);
      expect(find.byType(FinishScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sesi tanpa set kerja ditolak sebelum lembar dibuka', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [_bench()])));
      await tester.pump();
      await _openFinishSheet(tester);
      expect(find.text('Finish this session?'), findsNothing);
      expect(find.text('No working sets logged.'), findsOneWidget);
    });

    testWidgets('susunan sesi yang menyimpang tersimpan ke rutinitas secara bawaan, dan bisa dibatalkan',
        (tester) async {
      _phone(tester);
      const routine = Routine(
        id: 'r1',
        name: 'Push',
        policy: ProgressionPolicy.linear,
        exercises: [ExerciseConfig(exerciseId: '0025', sets: 2, reps: 8, weight: 60, restSeconds: 120)],
      );
      await store.saveRoutine(routine);
      await tester.pumpWidget(_wrap(
        store,
        SessionScreen(
          routineName: 'Push',
          routineId: 'r1',
          exercises: [_bench(done: true), _fly()],
          planned: const [('0025', 2)],
        ),
      ));
      await tester.pump();

      await _openFinishSheet(tester);
      expect(find.text('Finish this session?'), findsOneWidget);
      expect(find.text('Save this layout to Push'), findsOneWidget);
      expect(find.textContaining('+ Cable Fly'), findsOneWidget);
      // Switch di lembar, bukan switch istirahat di kartu gerakan di belakangnya.
      final sw = tester.widget<Switch>(find.descendant(of: find.byType(BottomSheet), matching: find.byType(Switch)));
      expect(sw.value, isTrue);

      await tester.tap(find.text('Finish & save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final saved = store.routineById('r1')!;
      expect(saved.exercises.map((e) => e.exerciseId), ['0025', 'fly']);
      expect(saved.exercises.first.restSeconds, 120);
      expect(saved.exercises.last.sets, 3);
      expect(saved.exercises.last.weight, 20);

      // Ringkasan memberi tahu, dan menawarkan kebalikannya.
      expect(find.byType(FinishScreen), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Routine Push updated'), 200);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('UNDO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.routineById('r1')!.exercises.map((e) => e.exerciseId), ['0025']);
      expect(find.text('Routine Push reverted'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('switch dimatikan → rutinitas tidak disentuh, ringkasan menawarkan simpan', (tester) async {
      _phone(tester);
      const routine = Routine(
        id: 'r1',
        name: 'Push',
        exercises: [ExerciseConfig(exerciseId: '0025', sets: 2, reps: 8, weight: 60)],
      );
      await store.saveRoutine(routine);
      await tester.pumpWidget(_wrap(
        store,
        SessionScreen(
          routineName: 'Push',
          routineId: 'r1',
          exercises: [_bench(done: true), _fly()],
          planned: const [('0025', 2)],
        ),
      ));
      await tester.pump();

      await _openFinishSheet(tester);
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.byType(Switch)));
      await tester.pump();
      await tester.tap(find.text('Finish & save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(store.routineById('r1')!.exercises.length, 1);
      expect(store.workouts.length, 1);
      await tester.scrollUntilVisible(find.text('Save to routine'), 200);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Save to routine'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.routineById('r1')!.exercises.map((e) => e.exerciseId), ['0025', 'fly']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('kapsul timer di atas melewati istirahat — sesinya tetap terbuka', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [_bench()])));
      await tester.pump();

      // Mencentang set pertama memulai istirahat dan membuka layar penuhnya;
      // tutup layar itu, istirahat tetap berjalan di belakang.
      await tester.tap(find.byIcon(GymIcons.circle).first);
      await tester.pump(const Duration(milliseconds: 500));
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byTooltip('Skip rest'), findsOneWidget);
      expect(find.byType(RestPill), findsOneWidget);

      // Lembar konfirmasi menyebut istirahat yang masih berjalan — dan
      // "kembali ke sesi" tidak menghentikannya.
      await _openFinishSheet(tester);
      expect(find.textContaining('ends the SESSION, not the timer'), findsOneWidget);
      await tester.tap(find.text('Back to session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Skip rest'), findsOneWidget);

      await tester.tap(find.byTooltip('Skip rest'));
      await tester.pump();
      expect(find.byTooltip('Skip rest'), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(RestPill), findsNothing);
      expect(store.workouts, isEmpty);
      expect(find.byType(SessionScreen), findsOneWidget);
    });

    testWidgets('kartu gerakan membuka dan menutup tanpa meluber di HP 360 dp', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [_bench(expanded: false)])));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget); // hanya catatan sesi

      await tester.tap(find.byTooltip('Expand'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TextField), findsNWidgets(5)); // catatan + 2 baris × (kg, rep)

      await tester.tap(find.byTooltip('Collapse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('"kurangi gerak": kartu membuka dan istirahat dilewati tanpa animasi, tanpa error', (tester) async {
      _phone(tester);
      // AnimatedSize melempar assertion kalau diberi durasi nol — ini
      // memastikan jalur reduce-motion tidak pernah sampai ke sana.
      await tester.pumpWidget(_wrap(
        store,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SessionScreen(routineName: 'Push', exercises: [_bench(expanded: false)]),
        ),
      ));
      await tester.pump();
      await tester.tap(find.byTooltip('Expand'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(5));

      await tester.tap(find.byIcon(GymIcons.circle).first);
      await tester.pump(const Duration(milliseconds: 500));
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RestPill), findsOneWidget);
      await tester.tap(find.byTooltip('Skip rest'));
      await tester.pump();
      expect(find.byType(RestPill), findsNothing);
    });
  });

  testWidgets('bilah atas dengan kapsul istirahat muat di 360 dp, bahasa Indonesia, huruf 1,3x', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = WorkoutStore();
    await s.load();
    final ex = SessionExercise(
      name: 'Barbell Bench Press',
      icon: Icons.fitness_center,
      config: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.double_, reps: 10, repsMin: 6),
      sets: const [SetRow(weight: 60, reps: 8), SetRow(weight: 60, reps: 8)],
      previous: const ['-', '-'],
      expanded: true,
    );
    await tester.pumpWidget(WorkoutScope(
      store: s,
      child: AppStrings(
        strings: const Strings(AppLanguage.indonesian),
        child: MaterialApp(
          theme: buildGymTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: SessionScreen(routineName: 'Push Day Berat', exercises: [ex]),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.byIcon(GymIcons.circle).first);
    await tester.pump(const Duration(milliseconds: 500));
    // Tutup layar istirahat penuh supaya bilah atas sesi tergambar lagi;
    // luapan RenderFlex di bilah itu membuat test ini gagal dengan sendirinya.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byTooltip('Lewati istirahat'), findsWidgets);
    final bar = tester.getRect(find.byTooltip('Lewati istirahat').first);
    expect(bar.height, greaterThanOrEqualTo(44), reason: 'target sentuh kapsul di sebelah SELESAI');
    await tester.pumpWidget(const SizedBox());
  });
}
