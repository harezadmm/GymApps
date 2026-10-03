/// v2.5: susunan rutinitas mengikuti sesi terakhirnya — juga untuk sesi yang
/// dicatat sebelum v2.2, waktu penyelarasan rutinitas belum ada.
///
/// Laporan pemakai (3 Okt 2026): sesi Push 28 Sep sudah disusun ulang dengan
/// mesin-mesin pilihannya sendiri, tapi sesi Push berikutnya kembali ke
/// Barbell Bench Press dkk. dari template. Penyelarasan v2.2 hanya berjalan
/// saat sesi *selesai*, dan sesi 28 Sep selesai sehari sebelum v2.2 ada.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/backend.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/progression.dart';
import 'package:gymapps/domain/routine_sync.dart';
import 'package:gymapps/domain/session_plan.dart';
import 'package:gymapps/domain/templates.dart';
import 'package:gymapps/features/history/history_screen.dart';
import 'package:gymapps/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mesin-mesin dari tangkapan layar pemakai. Id-nya katalog sungguhan supaya
// layar Riwayat bisa menamainya; yang diuji susunannya, bukan namanya.
const _pecFly = '0308', _chestPress = '0577', _lateral = '0334', _curl = '0031';

/// Target yang dibekukan v2.1 ke gerakan yang ditambah di tengah sesi: belum
/// pernah dicatat → 3 × 8–12, double progression, plus faktor deload Profil.
ExerciseConfig _added(String id) => ExerciseConfig(
      exerciseId: id,
      sets: 3,
      reps: 12,
      repsMin: 8,
      policy: ProgressionPolicy.double_,
      deloadFactor: 0.9,
    );

WorkoutEntry _entry(String id, List<(double, int)> sets) => WorkoutEntry(
      exerciseId: id,
      target: _added(id),
      sets: [for (final (w, r) in sets) SetRow(weight: w, reps: r, done: true)],
    );

/// Sesi Push 28 Sep, seperti di Riwayat pemakai (dipersingkat jadi empat
/// gerakan; bentuk tangga bebannya dipertahankan).
Workout _push28Sep({String? routine = 'Push'}) => Workout(
      date: '2026-09-28',
      routine: routine,
      durationSeconds: 42 * 60,
      entries: [
        _entry(_pecFly, [(32, 8), (45, 8), (65, 6)]),
        _entry(_chestPress, [(72, 8), (86, 8), (83.5, 8)]),
        _entry(_lateral, [(27, 8), (45, 8), (52, 8)]),
        _entry(_curl, [(36, 8), (45.5, 8), (54, 8)]),
      ],
    );

Routine _push() => buildTemplate('ppl')!.routines.first;

List<String> _ids(Routine r) => [for (final c in r.exercises) c.exerciseId];

/// Dokumen yang ditulis versi lama: program PPL tanpa penanda selaras, Push
/// masih isi template, dan satu sesi Push yang susunannya berbeda.
Map<String, dynamic> _legacyDoc({List<Workout>? workouts}) {
  final ppl = buildTemplate('ppl')!;
  final program = ppl.program.toJson()..remove('aligned');
  return {
    'schema': stateSchema,
    'workouts': [for (final w in workouts ?? [_push28Sep()]) w.toJson()],
    'routines': [for (final r in ppl.routines) r.toJson()],
    'program': program,
  };
}

class _Server implements Backend {
  _Server({this.rev, Map<String, dynamic>? state}) : state = state ?? {};

  int? rev;
  Map<String, dynamic> state;

  @override
  String? get signedInEmail => null;

  @override
  Future<int?> getRev() async => rev;

  @override
  Future<PulledState?> pull() async => rev == null ? null : PulledState(rev: rev!, state: state);

  @override
  Future<PushResult> push({required int? baseRev, required Map<String, dynamic> state}) async {
    this.state = state;
    rev = (rev ?? 0) + 1;
    return PushAccepted(rev!);
  }
}

class _Offline implements Backend {
  @override
  String? get signedInEmail => null;

  @override
  Future<int?> getRev() async => throw Exception('tidak ada jaringan');

  @override
  Future<PulledState?> pull() async => throw Exception('tidak ada jaringan');

  @override
  Future<PushResult> push({required int? baseRev, required Map<String, dynamic> state}) async =>
      throw Exception('tidak ada jaringan');
}

void main() {
  group('routineFollowingWorkout', () {
    test('sesi Push dengan mesin pilihan sendiri jadi susunan Push', () {
      final push = _push();
      final next = routineFollowingWorkout(push, _push28Sep(), profileDeload: 0.9)!;

      expect(_ids(next), [_pecFly, _chestPress, _lateral, _curl]);
      expect([for (final c in next.exercises) c.sets], [3, 3, 3, 3]);
      expect((next.id, next.name, next.policy), (push.id, 'Push', push.policy));

      final fly = next.exercises.first;
      // Policy rutinitas dan deload Profil yang dibekukan ke target sesi tidak
      // boleh jadi pengaturan khusus gerakan itu.
      expect(fly.policy, isNull);
      expect(fly.deloadFactor, isNull);
      expect((fly.repsMin, fly.reps), (8, 12));
    });

    test('susunan yang sudah sama: tidak ada yang diubah', () {
      final push = _push();
      final same = Workout(date: '2026-09-28', routine: 'Push', entries: [
        for (final c in push.exercises)
          WorkoutEntry(
            exerciseId: c.exerciseId,
            target: c,
            sets: [for (var i = 0; i < c.sets; i++) const SetRow(weight: 50, reps: 8, done: true)],
          ),
      ]);
      expect(routineFollowingWorkout(push, same), isNull);
    });

    test('gerakan yang sudah ada mempertahankan konfigurasinya; jumlah set kerja ikut sesi', () {
      final push = _push();
      final bench = push.exercises.first;
      final w = Workout(date: '2026-09-28', routine: 'Push', entries: [
        WorkoutEntry(
          exerciseId: bench.exerciseId,
          target: bench.copyWith(restSeconds: 30, reps: 5),
          sets: const [
            SetRow(phase: SetPhase.warmup, weight: 20, reps: 10, done: true),
            SetRow(weight: 60, reps: 8, done: true),
            SetRow(weight: 60, reps: 8, done: true),
            SetRow(weight: 60, reps: 8, done: true),
            SetRow(weight: 60, reps: 7, done: true),
          ],
        ),
        _entry(_pecFly, [(32, 8), (45, 8), (65, 6)]),
      ]);
      final next = routineFollowingWorkout(push, w, profileDeload: 0.9)!;
      expect(_ids(next), [bench.exerciseId, _pecFly]);
      final kept = next.exercises.first;
      expect(kept.sets, 4, reason: 'warm-up tidak dihitung sebagai set kerja');
      expect((kept.restSeconds, kept.reps, kept.repsMin), (bench.restSeconds, bench.reps, bench.repsMin));
    });

    test('sesi kosong tidak pernah mengosongkan rutinitas', () {
      expect(routineFollowingWorkout(_push(), const Workout(date: '2026-09-28', routine: 'Push', entries: [])),
          isNull);
    });
  });

  group('alignRoutinesWithLatestSessions', () {
    test('sesi terbaru per nama rutinitas menurut tanggal; sesi bebas dan nama lain diabaikan', () {
      final ppl = buildTemplate('ppl')!.routines;
      final older = Workout(date: '2026-09-20', routine: 'Push', entries: [
        _entry(_curl, [(30, 8), (30, 8), (30, 8)]),
      ]);
      final freestyle = Workout(date: '2026-10-01', routine: 'Freestyle', entries: [
        _entry(_lateral, [(20, 12)]),
      ]);
      // Urutan daftar sengaja tidak urut tanggal: yang menentukan tanggalnya.
      final result = alignRoutinesWithLatestSessions(ppl, [freestyle, older, _push28Sep()], profileDeload: 0.9);

      expect(result.changed, ['Push']);
      expect(_ids(result.routines[0]), [_pecFly, _chestPress, _lateral, _curl]);
      expect(_ids(result.routines[1]), _ids(ppl[1]), reason: 'Pull tanpa sesi tetap seperti template');
      expect(_ids(result.routines[2]), _ids(ppl[2]));
    });
  });

  group('WorkoutStore: penyelarasan sekali untuk rencana lama', () {
    test('rencana lama: Push mengikuti sesi terakhirnya sekali, lalu diumumkan sekali', () async {
      SharedPreferences.setMockInitialValues({'state.doc': jsonEncode(_legacyDoc())});
      final store = WorkoutStore();
      await store.load();
      await store.initialSync;

      expect(_ids(store.routines.first), [_pecFly, _chestPress, _lateral, _curl]);
      expect(store.program!.aligned, isTrue);
      expect(store.takeAlignedRoutines(), ['Push']);
      expect(store.takeAlignedRoutines(), isEmpty, reason: 'diumumkan sekali saja');

      // Tersimpan ke disk: dibuka lagi tidak mengulang dan tidak mengumumkan.
      final again = WorkoutStore();
      await again.load();
      await again.initialSync;
      expect(_ids(again.routines.first), [_pecFly, _chestPress, _lateral, _curl]);
      expect(again.takeAlignedRoutines(), isEmpty);
    });

    test('sesudah selaras, rutinitas yang diubah sengaja tidak ditimpa sesi lama', () async {
      SharedPreferences.setMockInitialValues({'state.doc': jsonEncode(_legacyDoc())});
      final store = WorkoutStore();
      await store.load();
      await store.initialSync;
      final push = store.routines.first;
      await store.saveRoutine(push.copyWith(exercises: [push.exercises.first]));

      final again = WorkoutStore();
      await again.load();
      await again.initialSync;
      expect(_ids(again.routines.first), [_pecFly]);
    });

    test('template yang dipasang di versi ini tidak diselaraskan dari riwayat lama', () async {
      SharedPreferences.setMockInitialValues({
        'state.doc': jsonEncode({'schema': stateSchema, 'workouts': [_push28Sep().toJson()]}),
      });
      final store = WorkoutStore();
      await store.load();
      await store.initialSync;
      await store.applyTemplate('ppl');

      final again = WorkoutStore();
      await again.load();
      await again.initialSync;
      expect(_ids(again.routines.first), _ids(_push()));
      expect(again.takeAlignedRoutines(), isEmpty);
    });

    test('sinkron gagal: belum diselaraskan saat dibuka, tapi diselaraskan saat sesi dimulai', () async {
      SharedPreferences.setMockInitialValues({'state.a@x.com.doc': jsonEncode(_legacyDoc())});
      final store = WorkoutStore(_Offline());
      await store.load('a@x.com');
      await store.initialSync;
      expect(_ids(store.routines.first), _ids(_push()), reason: 'data lokal mungkin tertinggal dari server');
      expect(store.program!.aligned, isFalse);

      // Orangnya menekan Mulai sesi di gym tanpa sinyal: susunan tetap harus
      // mengikuti sesi terakhir di HP ini.
      final push = await store.alignBeforeSession(store.routines.first.id);
      expect(_ids(push!), [_pecFly, _chestPress, _lateral, _curl]);
      expect(store.program!.aligned, isTrue);
      expect(store.takeAlignedRoutines(), ['Push']);
    });

    test('sinkron berhasil: diselaraskan sesudah dokumen server digabung, lalu naik ke server', () async {
      SharedPreferences.setMockInitialValues({});
      final server = _Server(rev: 3, state: _legacyDoc());
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.initialSync;
      await store.syncNow();

      expect(_ids(store.routines.first), [_pecFly, _chestPress, _lateral, _curl]);
      final pushed = (server.state['routines'] as List).first as Map;
      expect([for (final e in pushed['ex'] as List) (e as Map)['id']], [_pecFly, _chestPress, _lateral, _curl]);
      expect((server.state['program'] as Map)['aligned'], isTrue);
    });
  });

  group('beban sesi berikutnya dari sesi 28 Sep', () {
    test('reps belum di puncak rentang 8–12: beban tangga ditahan, rep naik dulu', () {
      final cfg = routineFollowingWorkout(_push(), _push28Sep(), profileDeload: 0.9)!.exercises.first;
      final plan = planExercise(cfg, [_push28Sep()], routineDefault: ProgressionPolicy.double_);
      expect([for (final s in plan.sets) s.weight], [32, 45, 65], reason: 'bentuk tangga dipertahankan');
      expect(plan.prescription.kind, PrescriptionKind.hold);
      expect(plan.previous, ['32 × 8', '45 × 8', '65 × 6']);
    });

    test('semua set mencapai 12 rep: seluruh tangga naik', () {
      final top = Workout(date: '2026-10-03', routine: 'Push', entries: [
        _entry(_pecFly, [(32, 12), (45, 12), (65, 12)]),
      ]);
      final cfg = routineFollowingWorkout(_push(), _push28Sep(), profileDeload: 0.9)!.exercises.first;
      final plan = planExercise(cfg, [_push28Sep(), top], routineDefault: ProgressionPolicy.double_);
      expect(plan.prescription.kind, PrescriptionKind.up);
      final w = [for (final s in plan.sets) s.weight];
      expect(w[0] > 32 && w[1] > 45 && w[2] > 65, isTrue, reason: 'naik: $w');
    });
  });

  group('Riwayat: pakai susunan sesi ini untuk rutinitas', () {
    Widget wrap(WorkoutStore store) => WorkoutScope(
          store: store,
          child: AppStrings(
            strings: const Strings(AppLanguage.english),
            child: MaterialApp(theme: buildGymTheme(), home: const Scaffold(body: HistoryScreen())),
          ),
        );

    testWidgets('sesi bebas bisa dijadikan susunan Push, dan bisa diurungkan', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.runAsync(ExerciseCatalog.load);
      SharedPreferences.setMockInitialValues({});
      final store = WorkoutStore();
      await tester.runAsync(() async {
        await store.load();
        await store.applyTemplate('ppl');
        await store.addManualWorkout(_push28Sep(routine: 'Freestyle'));
      });

      // Sheet bawah baru mulai beranimasi di frame sesudah ketukan; pump
      // berjangka, bukan pumpAndSettle, karena animasi kedatangan kartu.
      Future<void> settle() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Simpan ke disk berjalan di luar zona waktu palsu.
      Future<void> flush() async {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await settle();
      }

      await tester.pumpWidget(wrap(store));
      await settle();
      // Baris sesinya (di dalam Dismissible), bukan chip filter bernama sama.
      await tester.tap(find.descendant(of: find.byType(Dismissible), matching: find.text('Freestyle')));
      await settle();

      // Daftar sheet dibangun malas: tombolnya baru ada setelah digulir.
      final use = find.text('USE THIS LAYOUT FOR A ROUTINE');
      await tester.scrollUntilVisible(use, 300, scrollable: find.byType(Scrollable).last);
      await settle();
      await tester.tap(use);
      await settle();

      expect(find.text('Use for which routine?'), findsOneWidget);
      expect(find.text('5 exercises'), findsNWidgets(2), reason: 'Push dan Legs masih isi template');
      await tester.tap(find.text('Push').last);
      await flush();

      expect(_ids(store.routines.first), [_pecFly, _chestPress, _lateral, _curl]);
      expect(find.text('Push now follows this session.'), findsOneWidget);

      await tester.tap(find.text('UNDO'));
      await flush();
      expect(_ids(store.routines.first), _ids(_push()));
    });
  });

  group('aplikasi dibuka dengan rencana lama', () {
    testWidgets('Beranda langsung memakai mesin dari sesi terakhir, dan perubahannya disebut sekali', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.runAsync(ExerciseCatalog.load);
      SharedPreferences.setMockInitialValues({'state.doc': jsonEncode(_legacyDoc())});
      final store = WorkoutStore();
      await tester.runAsync(() async {
        await store.load();
        await store.initialSync;
      });

      await tester.pumpWidget(WorkoutScope(
        store: store,
        child: AppStrings(
          strings: const Strings(AppLanguage.english),
          child: MaterialApp(
            theme: buildGymTheme(),
            home: HomeShell(
              language: AppLanguage.english,
              onLanguageChanged: (_) {},
              onSignOut: () {},
              email: 'a@b.test',
            ),
          ),
        ),
      ));
      await tester.pump();
      // initialSync lahir di zona sungguhan (runAsync di atas): lanjutan yang
      // menunggunya dijadwalkan di sana, dan pump berjangka tidak
      // menjalankannya. Di aplikasi hanya ada satu zona.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Push now uses the layout of your last session.'), findsOneWidget);
      // Kartu sesi berikutnya: mesin pilihan sendiri, bukan isi template.
      expect(find.text('Dumbbell Fly'), findsWidgets);
      expect(find.text('Barbell Bench Press'), findsNothing);
      expect(store.takeAlignedRoutines(), isEmpty, reason: 'sudah diumumkan');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
