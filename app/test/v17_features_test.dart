/// Perbaikan dan fitur v1.7: dari audit "rusak, tidak jujur, bisa bikin data
/// hilang" sampai fitur baru untuk lifter serius.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/gym_icons.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/password_reset.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/progression.dart';
import 'package:gymapps/domain/settings.dart';
import 'package:gymapps/features/home/home_screen.dart' show weekStart;
import 'package:gymapps/features/session/exercise_history_sheet.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:gymapps/features/stats/dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Workout _w(String date, List<SetRow> sets, {String id = '0025', ExerciseConfig? target, String? note}) => Workout(
      date: date,
      entries: [WorkoutEntry(exerciseId: id, sets: sets, target: target, note: note)],
    );

SetRow _done(double w, int r, {SetPhase phase = SetPhase.work}) => SetRow(weight: w, reps: r, done: true, phase: phase);

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        child: MaterialApp(theme: buildGymTheme(), home: home),
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
  });

  group('model', () {
    test('drop set, rest-pause, RIR, catatan, dan superset bertahan lewat JSON', () {
      final w = Workout(
        date: '2026-09-25',
        notes: 'bahu kiri sedikit nyeri',
        entries: [
          WorkoutEntry(
            exerciseId: '0025',
            note: 'kursi posisi 4',
            target: const ExerciseConfig(exerciseId: '0025', superset: true, mode: LogMode.reps),
            sets: const [
              SetRow(weight: 60, reps: 8, done: true, rir: 2),
              SetRow(weight: 48, reps: 10, done: true, phase: SetPhase.drop),
              SetRow(weight: 60, reps: 3, done: true, phase: SetPhase.restPause),
            ],
          ),
        ],
      );
      final back = Workout.fromJson(jsonDecode(jsonEncode(w.toJson())) as Map<String, dynamic>);
      expect(back.notes, 'bahu kiri sedikit nyeri');
      expect(back.entries.first.note, 'kursi posisi 4');
      expect(back.entries.first.target!.superset, isTrue);
      expect(back.entries.first.sets.map((s) => s.phase), [SetPhase.work, SetPhase.drop, SetPhase.restPause]);
      expect(back.entries.first.sets.first.rir, 2);
      expect(workoutKey(back), workoutKey(w));
    });
  });

  group('progresi', () {
    test('drop set dengan rep sedikit tidak membuat sesi dianggap gagal', () {
      const cfg = ExerciseConfig(exerciseId: '0025', sets: 2, reps: 8, weight: 60, policy: ProgressionPolicy.linear);
      final history = [
        _w('2026-09-20', [_done(60, 8), _done(60, 8), _done(40, 4, phase: SetPhase.drop)], target: cfg),
      ];
      final p = nextPrescription(workouts: history, cfg: cfg);
      expect(p.kind, PrescriptionKind.up);
      expect(p.weight, 62.5);
    });

    test('Heavy Duty dips bodyweight: tidak pernah disuruh +2,5 kg', () {
      const cfg = ExerciseConfig(
          exerciseId: 'dips', sets: 1, reps: 10, repsMin: 6, bodyweight: true, policy: ProgressionPolicy.hit);
      final history = [_w('2026-09-20', [_done(0, 10)], id: 'dips', target: cfg)];
      final p = nextPrescription(workouts: history, cfg: cfg);
      expect(p.weight, 0);
      expect(p.why, isNot(contains('kg')));
    });

    test('bodyweight tanpa plafon: berhenti menambah rep di 20, lalu tambah set', () {
      const cfg = ExerciseConfig(exerciseId: 'pushup', sets: 3, reps: 20, bodyweight: true);
      final history = [
        _w('2026-09-20', [_done(0, 20), _done(0, 20), _done(0, 20)], id: 'pushup', target: cfg),
      ];
      final p = nextPrescription(workouts: history, cfg: cfg);
      expect(p.sets, 4);
      expect(p.reps, isNot(21));
    });
  });

  group('setelan', () {
    test('kelompok alat menyaring katalog, bodyweight selalu ada', () {
      const s = TrainingSettings(equipment: ['dumbbell']);
      expect(s.hasEquipment('dumbbell'), isTrue);
      expect(s.hasEquipment('barbell'), isFalse);
      expect(s.hasEquipment('body weight'), isTrue);
      expect(const TrainingSettings().hasEquipment('barbell'), isTrue);
    });

    test('istirahat: rutinitas, lalu yang disimpan dari sesi bebas, lalu bawaan', () {
      const s = TrainingSettings(defaultRestSeconds: 120, restByExercise: {'dl': 180});
      expect(s.restFor(const ExerciseConfig(exerciseId: 'x', restSeconds: 60)), 60);
      expect(s.restFor(const ExerciseConfig(exerciseId: 'dl')), 180);
      expect(s.restFor(const ExerciseConfig(exerciseId: 'x')), 120);
    });

    test('awal minggu Minggu: strip minggu mulai hari Minggu', () {
      final thursday = DateTime(2026, 9, 24);
      expect(weekStart(thursday, DateTime.monday), DateTime(2026, 9, 21));
      expect(weekStart(thursday, DateTime.sunday), DateTime(2026, 9, 20));
    });
  });

  group('store', () {
    test('edit sesi: versi lama dicatat terhapus, target ikut benar', () async {
      final store = WorkoutStore();
      await store.load('a@x.com');
      await store.addWorkout(_w('2026-09-20', [_done(600, 8)]));
      final typo = store.workouts.first;
      final fixed = typo.copyWith(entries: [typo.entries.first.copyWith(sets: [_done(60, 8)])]);
      await store.replaceWorkout(typo, fixed);
      expect(store.workouts.single.entries.first.sets.first.weight, 60);
      expect(store.toDocument()['removed'], contains(workoutKey(typo)));
    });

    test('setelan, favorit, dan berat badan tersimpan dan terbaca lagi', () async {
      final a = WorkoutStore();
      await a.load('a@x.com');
      await a.updateSettings(a.settings.copyWith(defaultRestSeconds: 150, logRir: true, equipment: ['barbell']));
      await a.toggleFavorite('0025');
      await a.logBodyweight('2026-09-20', 80.5);
      await a.logBodyweight('2026-09-25', 79.8);

      final b = WorkoutStore();
      await b.load('a@x.com');
      expect(b.settings.defaultRestSeconds, 150);
      expect(b.settings.logRir, isTrue);
      expect(b.settings.equipment, ['barbell']);
      expect(b.settings.favorites, ['0025']);
      expect(b.latestBodyweight, 79.8);
      expect(b.bodyweightLog.length, 2);
    });

    test('draft sesi disimpan per akun dan bisa dibuang', () async {
      final store = WorkoutStore();
      await store.load('a@x.com');
      await store.saveDraft({'name': 'Push', 'ex': []});
      final again = WorkoutStore();
      await again.load('a@x.com');
      expect(again.draft?['name'], 'Push');
      await again.load('b@x.com');
      expect(again.draft, isNull);
      await again.load('a@x.com');
      await again.clearDraft();
      expect(again.draft, isNull);
    });

    test('impor cadangan menggabung, tidak menghapus', () async {
      final store = WorkoutStore();
      await store.load('a@x.com');
      await store.addWorkout(_w('2026-09-20', [_done(60, 8)]));
      final backup = {
        'schema': stateSchema,
        'workouts': [
          _w('2026-09-20', [_done(60, 8)]).toJson(),
          _w('2026-09-10', [_done(55, 8)]).toJson(),
        ],
      };
      final added = await store.importDocument(backup);
      expect(added, 1);
      expect(store.workouts.length, 2);
      expect(() => store.importDocument({'hello': 1}), throwsFormatException);
    });
  });

  group('rekor dan dashboard', () {
    test('rekor gerakan: terberat, e1RM terbaik, volume sesi terbaik', () {
      final history = [
        _w('2026-09-10', [_done(60, 10), _done(60, 10)]),
        _w('2026-09-20', [_done(70, 3)]),
      ];
      final r = recordsFor(history, '0025');
      expect(r.heaviest, 70);
      expect(r.bestVolume, 1200);
      expect(r.bestVolumeDate, '2026-09-10');
      expect(r.best, isNotNull);
    });

    test('gerakan yang tidak naik 3 minggu disebut stagnan', () {
      final today = DateTime(2026, 9, 25);
      final history = [
        _w('2026-08-20', [_done(100, 5)]),
        _w('2026-09-18', [_done(95, 5)]),
        _w('2026-09-24', [_done(100, 5)]),
        _w('2026-08-20', [_done(40, 8)], id: 'row'),
        _w('2026-09-24', [_done(45, 8)], id: 'row'),
      ];
      final stalled = stalledLifts(history, today);
      expect(stalled.map((s) => s.exerciseId), ['0025']);
    });
  });

  test('reset kata sandi dikirim tanpa PKCE ke /recover', () async {
    late http.Request sent;
    final client = MockClient((r) async {
      sent = r;
      return http.Response('{}', 200);
    });
    final ok = await requestPasswordReset(
        supabaseUrl: 'https://x.supabase.co', anonKey: 'sb_publishable_x', email: ' A@B.co ', client: client);
    expect(ok, isTrue);
    expect(sent.url.path, '/auth/v1/recover');
    expect(sent.url.queryParameters['redirect_to'], passwordResetRedirect);
    expect(jsonDecode(sent.body), {'email': 'a@b.co'});
    expect(sent.headers['apikey'], 'sb_publishable_x');
  });

  group('layar sesi', () {
    SessionExercise ex(String name, {int sets = 2}) => SessionExercise(
          name: name,
          icon: Icons.fitness_center,
          config: ExerciseConfig(exerciseId: name),
          sets: [for (var i = 0; i < sets; i++) const SetRow(weight: 60, reps: 8)],
          previous: [for (var i = 0; i < sets; i++) '—'],
          expanded: true,
        );

    testWidgets('mencentang set menyimpan draft sesi', (tester) async {
      _phone(tester);
      final store = WorkoutStore();
      await tester.runAsync(() => store.load('a@x.com'));
      final bench = ex('Bench');
      await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [bench])));
      await tester.pump();
      await tester.tap(find.byIcon(GymIcons.circle).first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.draft?['name'], 'Push');
      final sets = ((store.draft!['ex'] as List).first as Map)['sets'] as List;
      expect((sets.first as Map)['done'], isTrue);
      // Tutup layar istirahat penuh.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('set terakhir satu gerakan tetap memulai istirahat sebelum gerakan berikutnya', (tester) async {
      _phone(tester);
      final store = WorkoutStore();
      await tester.runAsync(() => store.load('a@x.com'));
      final a = ex('Bench', sets: 1);
      final b = ex('Row', sets: 1)..expanded = false;
      await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [a, b])));
      await tester.pump();
      await tester.tap(find.byIcon(GymIcons.circle).first);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Next: Row'), findsWidgets);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('tombol + di kolom KG menambah satu increment', (tester) async {
      _phone(tester);
      final store = WorkoutStore();
      await tester.runAsync(() => store.load('a@x.com'));
      final bench = ex('Bench', sets: 1);
      await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [bench])));
      await tester.pump();
      await tester.tap(find.byIcon(GymIcons.add).first);
      await tester.pump();
      expect(bench.sets.first.weight, 62.5);
      expect(find.widgetWithText(TextField, '62.5'), findsOneWidget);
    });

    testWidgets('mengganti gerakan yang sudah punya set tercentang ditanyakan dulu', (tester) async {
      _phone(tester);
      final store = WorkoutStore();
      await tester.runAsync(() => store.load('a@x.com'));
      final bench = ex('Bench');
      bench.sets[0] = bench.sets[0].copyWith(done: true);
      await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [bench])));
      await tester.pump();
      await tester.tap(find.byTooltip('Exercise actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace exercise'));
      await tester.pumpAndSettle();
      expect(find.text('Replace exercise?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(bench.sets.first.done, isTrue);
    });

    testWidgets('RIR menyala: setelah centang muncul pilihan RIR dan tersimpan di set', (tester) async {
      _phone(tester);
      final store = WorkoutStore();
      await tester.runAsync(() async {
        await store.load('a@x.com');
        await store.updateSettings(store.settings.copyWith(logRir: true));
      });
      final bench = ex('Bench')..restEnabled = false;
      await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [bench])));
      await tester.pump();
      await tester.tap(find.byIcon(GymIcons.circle).first);
      await tester.pump();
      expect(find.text('Reps in reserve'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(Wrap), matching: find.text('2')));
      await tester.pump();
      expect(bench.sets.first.rir, 2);
      expect(find.text('Reps in reserve'), findsNothing);
    });
  });

  group('bahasa Indonesia di layar sesi', () {
    test('setiap kalimat alasan di progression.dart punya terjemahan', () {
      // Kalimat alasan dibentuk di lapisan domain dalam bahasa Inggris. Test ini
      // mengambil semua literalnya langsung dari sumber, mengisi variabelnya
      // dengan angka, lalu memastikan tidak ada yang lolos tanpa terjemahan —
      // supaya kalimat baru tidak diam-diam tampil berbahasa Inggris.
      final src = File('lib/domain/progression.dart').readAsStringSync();
      final literals = RegExp(r"'([^'\n]*)'")
          .allMatches(src)
          .map((m) => m.group(1)!)
          .where((l) => l.contains(' — ') || l.startsWith('Automatic progression'))
          .map((l) => l.replaceAll(RegExp(r'\$\{[^}]*\}'), '7').replaceAll(RegExp(r'\$\w+'), '7'))
          .toList();
      expect(literals.length, greaterThanOrEqualTo(20));
      const id = Strings(AppLanguage.indonesian);
      final missing = [for (final l in literals) if (id.why(l) == l) l];
      expect(missing, isEmpty);
    });

    test('angka ikut terbawa ke terjemahan, bahasa Inggris tidak diubah', () {
      const id = Strings(AppLanguage.indonesian);
      expect(id.why('Top of the rep range on every set — +2.5 kg, reps back to 6.'),
          'Batas atas rentang rep di semua set — +2.5 kg, rep kembali ke 6.');
      expect(id.why('Kalimat lain'), 'Kalimat lain');
      const en = Strings(AppLanguage.english);
      expect(en.why('+2.5 kg — all reps hit last session.'), '+2.5 kg — all reps hit last session.');
    });
  });

  testWidgets('sesi yang dilanjutkan dari draft menampilkan waktu yang sudah berjalan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = WorkoutStore();
    await store.load();
    await tester.pumpWidget(WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        child: MaterialApp(
          theme: buildGymTheme(),
          home: const SessionScreen(routineName: 'Pull', exercises: [], initialElapsed: Duration(minutes: 3)),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('3:0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
