/// Sesi yang sedang berjalan tidak boleh hilang saat aplikasi dimatikan.
///
/// Lahir dari laporan pemakai: "saat aplikasi mulai ulang karena lama nggak
/// dibuka, semua progress-nya hilang, nggak ke-save". Draft sebenarnya
/// tersimpan, tapi hanya menunggu di kartu kecil di Home — dan menekan
/// "Mulai sesi" di atasnya menimpanya tanpa bertanya. Test di sini menjaga:
/// draft ditulis cepat, membawa istirahat dan tanggalnya, dibuka otomatis
/// saat aplikasi dimulai, dan tidak pernah tertimpa diam-diam.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/gym_icons.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/program.dart';
import 'package:gymapps/features/session/session_launcher.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:gymapps/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        child: MaterialApp(theme: buildGymTheme(), home: home),
      ),
    );

SessionExercise _bench() => SessionExercise(
      name: 'Barbell Bench Press',
      icon: Icons.fitness_center,
      config: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.double_, reps: 10, repsMin: 6),
      sets: const [SetRow(weight: 60, reps: 8), SetRow(weight: 60, reps: 8)],
      previous: const ['—', '—'],
      expanded: true,
    );

/// Draft seperti yang ditulis layar sesi: satu gerakan, satu set tercentang.
Map<String, dynamic> _draft({required DateTime saved, int elapsed = 600, Map<String, dynamic>? rest, String? date}) => {
      'v': 1,
      'name': 'Push',
      'unit': 'kg',
      'elapsed': elapsed,
      'saved': saved.millisecondsSinceEpoch,
      'date': ?date,
      'planned': [
        ['0025', 2],
      ],
      'ex': [
        {
          'name': 'Barbell Bench Press',
          'cfg': {'id': '0025', 'pol': 'double_', 'rMin': 6},
          'sets': [
            {'w': 60, 'r': 8, 'done': true},
            {'w': 60, 'r': 8, 'done': false},
          ],
          'prev': ['—', '—'],
          'rest': 90,
          'open': true,
        },
      ],
      'rest': ?rest,
    };

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<ExerciseCatalog> _catalog(WidgetTester tester) async => (await tester.runAsync(ExerciseCatalog.load))!;

/// Tombol yang menjalankan [run] dengan context di bawah Navigator.
Widget _launcher(void Function(BuildContext) run) => Scaffold(
      body: Builder(builder: (context) => TextButton(onPressed: () => run(context), child: const Text('Go'))),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
    store = WorkoutStore();
    await store.load();
  });

  group('umur dan lama draft', () {
    final now = DateTime(2026, 9, 29, 18);

    test('draft baru dibuka otomatis, draft kemarin lusa tidak', () {
      expect(draftIsRecent(_draft(saved: now.subtract(const Duration(minutes: 40))), now: now), isTrue);
      expect(draftIsRecent(_draft(saved: now.subtract(const Duration(hours: 11))), now: now), isTrue);
      expect(draftIsRecent(_draft(saved: now.subtract(const Duration(hours: 30))), now: now), isFalse);
      expect(draftIsRecent({'name': 'Push'}, now: now), isFalse, reason: 'draft tanpa waktu simpan tidak dipaksa');
    });

    test('jeda singkat ikut dihitung, semalam tidak', () {
      expect(draftElapsed(_draft(saved: now.subtract(const Duration(minutes: 10))), now: now),
          const Duration(minutes: 20));
      expect(draftElapsed(_draft(saved: now.subtract(const Duration(hours: 9))), now: now),
          const Duration(minutes: 10));
    });
  });

  testWidgets('beban yang diketik tersimpan ke draft tanpa menunggu set dicentang', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [_bench()])));
    await tester.pump();
    // TextField pertama adalah catatan sesi; sesudahnya kg lalu rep set 1.
    await tester.enterText(find.byType(TextField).at(1), '72.5');
    await tester.pump(const Duration(seconds: 1));
    final sets = ((store.draft!['ex'] as List).first as Map)['sets'] as List;
    expect((sets.first as Map)['w'], 72.5);
    expect(store.draft!['date'], isoDate(DateTime.now()));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('istirahat yang berjalan ikut tersimpan di draft', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [_bench()])));
    await tester.pump();
    await tester.tap(find.byIcon(GymIcons.circle).first);
    await _settle(tester);
    final rest = store.draft!['rest'] as Map;
    expect(rest['total'], 90);
    expect(rest['on'], 0);
    expect(DateTime.fromMillisecondsSinceEpoch(rest['end'] as int).isAfter(DateTime.now()), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('draft dilanjutkan dengan istirahat, tanggal, dan waktu yang benar', (tester) async {
    _phone(tester);
    await _catalog(tester);
    final now = DateTime.now();
    await store.saveDraft(_draft(
      saved: now.subtract(const Duration(minutes: 5)),
      date: '2026-09-28',
      rest: {'end': now.add(const Duration(seconds: 50)).millisecondsSinceEpoch, 'total': 90, 'on': 0, 'next': 'Next: set 2'},
    ));
    await tester.pumpWidget(_wrap(store, _launcher((c) => resumeDraftSession(c))));
    await tester.tap(find.text('Go'));
    await _settle(tester);

    final screen = tester.widget<SessionScreen>(find.byType(SessionScreen));
    expect(screen.initialDate, '2026-09-28', reason: 'sesi yang dimulai kemarin tetap bertanggal kemarin');
    expect(screen.initialElapsed.inSeconds, closeTo(900, 5), reason: '10 menit tercatat + 5 menit jeda');
    expect(find.text('Next: set 2'), findsWidgets, reason: 'kartu istirahat kembali');
    expect(find.textContaining('00:4'), findsWidgets, reason: 'sisa istirahat dari tenggat lama, bukan 1:30 baru');
    await tester.pumpWidget(const SizedBox());
  });

  group('draft tidak tertimpa diam-diam', () {
    testWidgets('mulai sesi baru saat ada draft bertanya dulu; buang lalu mulai', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.saveDraft(_draft(saved: DateTime.now()));
      await tester.pumpWidget(_wrap(store, _launcher((c) => openFreestyleSession(c, 'Freestyle'))));
      await tester.tap(find.text('Go'));
      await _settle(tester);

      expect(find.text('Unfinished session'), findsOneWidget);
      expect(find.byType(SessionScreen), findsNothing, reason: 'belum ada yang ditimpa');
      await tester.tap(find.text('Discard & start new'));
      await _settle(tester);
      expect(store.draft, isNull);
      expect(tester.widget<SessionScreen>(find.byType(SessionScreen)).routineName, 'Freestyle');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('LANJUTKAN membuka sesi yang tertinggal, bukan yang baru', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.saveDraft(_draft(saved: DateTime.now()));
      await tester.pumpWidget(_wrap(store, _launcher((c) => openFreestyleSession(c, 'Freestyle'))));
      await tester.tap(find.text('Go'));
      await _settle(tester);
      await tester.tap(find.text('Continue'));
      await _settle(tester);
      expect(tester.widget<SessionScreen>(find.byType(SessionScreen)).routineName, 'Push');
      expect(store.draft, isNotNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('aplikasi dibuka lagi', () {
    Widget shell() => HomeShell(
          language: AppLanguage.english,
          onLanguageChanged: (_) {},
          onSignOut: () {},
          email: 'a@b.test',
        );

    testWidgets('draft baru langsung dibuka lagi sebagai sesi', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.saveDraft(_draft(saved: DateTime.now().subtract(const Duration(minutes: 20))));
      await tester.pumpWidget(_wrap(store, shell()));
      await _settle(tester);
      final screen = tester.widget<SessionScreen>(find.byType(SessionScreen));
      expect(screen.routineName, 'Push');
      expect(screen.restored, isTrue);
      expect(find.text('Unfinished session restored. Pick up from your last set.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('draft lama menunggu di Home, tidak dibuka paksa', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.saveDraft(_draft(saved: DateTime.now().subtract(const Duration(days: 2))));
      await tester.pumpWidget(_wrap(store, shell()));
      await _settle(tester);
      expect(find.byType(SessionScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('sesi yang dibuka ulang dari Riwayat menggantikan catatannya saat selesai', (tester) async {
    _phone(tester);
    await _catalog(tester);
    final old = Workout(date: '2026-09-20', routine: 'Push', durationSeconds: 1800, entries: [
      WorkoutEntry(exerciseId: '0025', sets: const [SetRow(weight: 60, reps: 8, done: true)]),
    ]);
    await store.addWorkout(old);
    final ex = _bench()..sets[0] = const SetRow(weight: 60, reps: 8, done: true);
    await tester.pumpWidget(_wrap(
      store,
      SessionScreen(routineName: 'Push', exercises: [ex], initialDate: '2026-09-20', replacesKey: workoutKey(old)),
    ));
    await tester.pump();
    await tester.tap(find.text('Finish'));
    await _settle(tester);
    await tester.tap(find.text('Finish & save'));
    await _settle(tester);
    expect(store.workouts.length, 1, reason: 'diganti, bukan ditambah');
    expect(store.workouts.single.date, '2026-09-20');
    expect(store.draft, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
