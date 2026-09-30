/// Rutinitas deload terencana (FR-B10): ditandai "excluded from progression",
/// sesinya tetap riwayat — tampil di PREV, volume, statistik, PR — tapi tidak
/// pernah menggeser target sesi reguler berikutnya.
///
/// Aturannya hidup di satu tempat, [progressionHistory]; yang diuji di sini
/// adalah helper itu, jalur [planExercise] yang dilewati setiap pemanggil,
/// bentuk JSON-nya, dan saklar di editor rutinitas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/progression.dart';
import 'package:gymapps/domain/session_plan.dart';
import 'package:gymapps/features/workout/routine_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bench = ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, sets: 3, reps: 8);

const _push = Routine(id: 'push', name: 'Push', exercises: [_bench]);
const _deload = Routine(id: 'deload', name: 'Deload', exercises: [_bench], excludedFromProgression: true);
const _routines = [_push, _deload];

/// Satu sesi bench press, tiga set kerja tercentang penuh.
Workout _sesi(String date, String? routine, double w, {int reps = 8}) => Workout(
      date: date,
      routine: routine,
      entries: [
        WorkoutEntry(
          exerciseId: '0025',
          target: _bench,
          sets: [for (var i = 0; i < 3; i++) SetRow(weight: w, reps: reps, done: true)],
        ),
      ],
    );

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        child: MaterialApp(theme: buildGymTheme(), home: home),
      ),
    );

/// HP kecil yang umum: 360 × 780 dp.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Pump berjangka, bukan pumpAndSettle: animasi kedatangan tidak pernah
/// "tenang" di dalam zona waktu palsu.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Katalog dibaca dari aset lewat I/O sungguhan, yang tidak pernah selesai di
/// dalam zona waktu palsu widget test. Dimuat sekali lewat [WidgetTester.runAsync];
/// setelah itu `ExerciseCatalog.load()` di dalam layar langsung memakai cache.
Future<ExerciseCatalog> _catalog(WidgetTester tester) async =>
    (await tester.runAsync(ExerciseCatalog.load))!;

/// Tombol yang membuka [page] lewat push dan mencatat hasilnya — cara tab
/// Workout membuka editor.
Widget _launcher(Widget page, void Function(RoutineEditorResult?) onResult) => Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onResult(
            await Navigator.of(context).push<RoutineEditorResult>(MaterialPageRoute(builder: (_) => page)),
          ),
          child: const Text('GO'),
        ),
      ),
    );

void main() {
  group('progressionHistory (FR-B10)', () {
    test('sesi rutinitas deload yang lebih berat tidak mengubah target reguler', () {
      final history = [_sesi('2026-09-01', 'Push', 60), _sesi('2026-09-03', 'Deload', 80)];
      final plan = planExercise(_bench, history, routines: _routines);
      expect(plan.prescription.kind, PrescriptionKind.up);
      expect(plan.prescription.weight, 62.5, reason: 'naik dari 60 (sesi Push), bukan dari 80 (sesi deload)');
      expect({for (final s in plan.sets) if (s.isWork) s.weight}, {62.5});
    });

    test('sesi reguler tetap menggeser target', () {
      final history = [_sesi('2026-09-01', 'Push', 60), _sesi('2026-09-03', 'Push', 62.5)];
      final plan = planExercise(_bench, history, routines: _routines);
      expect(plan.prescription.kind, PrescriptionKind.up);
      expect(plan.prescription.weight, 65);
    });

    test('sesi deload yang gagal juga tidak dihitung sebagai stall', () {
      // Tanpa saringan, deload 40 kg × 3 rep terbaca "gagal di beban lain" dan
      // memutus rentetan — atau, lebih buruk, jadi sesi terakhir yang ditahan.
      final history = [_sesi('2026-09-01', 'Push', 60), _sesi('2026-09-03', 'Deload', 40, reps: 3)];
      final plan = planExercise(_bench, history, routines: _routines);
      expect(plan.prescription.kind, PrescriptionKind.up);
      expect(plan.prescription.weight, 62.5);
    });

    test('kolom PREV tetap menampilkan sesi terakhir, termasuk sesi deload', () {
      // PREV adalah riwayat, bukan target: yang terakhir diangkat memang 40.
      final history = [_sesi('2026-09-01', 'Push', 60), _sesi('2026-09-03', 'Deload', 40)];
      final plan = planExercise(_bench, history, routines: _routines);
      expect(plan.previous.first, startsWith('40'));
      expect(plan.prescription.weight, 62.5);
    });

    test('hanya sesi deload di riwayat → sesi reguler jadi titik awal', () {
      final plan = planExercise(_bench, [_sesi('2026-09-03', 'Deload', 40)], routines: _routines);
      expect(plan.prescription.kind, PrescriptionKind.first);
      expect({for (final s in plan.sets) if (s.isWork) s.weight}, {_bench.weight});
    });

    test('sesi bebas tanpa nama rutinitas selalu ikut', () {
      final history = [_sesi('2026-09-01', null, 60), _sesi('2026-09-03', 'Deload', 80)];
      expect(progressionHistory(history, _routines), [history.first]);
    });

    test('tanpa rutinitas yang dikecualikan, riwayat dikembalikan apa adanya', () {
      final history = [_sesi('2026-09-01', 'Push', 60), _sesi('2026-09-03', 'Deload', 80)];
      expect(identical(progressionHistory(history, [_push]), history), isTrue);
      expect(identical(progressionHistory(history, const []), history), isTrue);
    });

    test('tanpa daftar rutinitas, planExercise berperilaku seperti dulu', () {
      final history = [_sesi('2026-09-01', 'Push', 60), _sesi('2026-09-03', 'Deload', 80)];
      expect(planExercise(_bench, history).prescription.weight, 82.5);
    });
  });

  group('Routine JSON', () {
    test('tanda deload ikut bolak-balik lewat kunci `excluded`', () {
      final j = _deload.toJson();
      expect(j['excluded'], isTrue);
      expect(Routine.fromJson(j).excludedFromProgression, isTrue);
    });

    test('rutinitas biasa tidak menulis kuncinya, dan dokumen lama tanpa kunci dibaca false', () {
      expect(_push.toJson().containsKey('excluded'), isFalse);
      expect(Routine.fromJson(_push.toJson()).excludedFromProgression, isFalse);
      // Dokumen dari HP lain yang belum mengenal v2.3.
      expect(Routine.fromJson({'id': 'a', 'name': 'A', 'ex': []}).excludedFromProgression, isFalse);
      expect(Routine.fromJson({'id': 'a', 'name': 'A', 'excluded': 'yes'}).excludedFromProgression, isFalse);
    });

    test('copyWith mempertahankan tanda kecuali diminta ganti', () {
      expect(_deload.copyWith(name: 'Deload B').excludedFromProgression, isTrue);
      expect(_deload.copyWith(excludedFromProgression: false).excludedFromProgression, isFalse);
      expect(_push.copyWith(excludedFromProgression: true).excludedFromProgression, isTrue);
    });
  });

  group('store', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ExerciseCatalog.registerCustom(const []);
    });

    test('tanda deload tersimpan ke dokumen dan terbaca lagi setelah muat ulang', () async {
      final store = WorkoutStore();
      await store.load();
      await store.saveRoutine(_deload);
      final routines = store.toDocument()['routines'] as List;
      expect((routines.single as Map)['excluded'], isTrue);

      final again = WorkoutStore();
      await again.load();
      expect(again.routineById('deload')!.excludedFromProgression, isTrue);
    });

    test('dokumen lama dari perangkat lain: rutinitas tanpa kunci = false', () async {
      final store = WorkoutStore();
      await store.load();
      await store.importDocument({
        'workouts': <Map<String, dynamic>>[],
        'program': {'name': 'PPL', 'mode': 'rotation', 'order': ['a'], 'cursor': 0},
        'routines': [
          {'id': 'a', 'name': 'A', 'ex': []},
        ],
      });
      expect(store.routineById('a')!.excludedFromProgression, isFalse);
    });
  });

  group('editor rutinitas', () {
    late WorkoutStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ExerciseCatalog.registerCustom(const []);
      store = WorkoutStore();
      await store.load();
    });

    testWidgets('saklar deload bisa dinyalakan, dikembalikan lewat pop, dan tersimpan', (tester) async {
      _phone(tester);
      // Teks 130 % (NFR-11): baris saklar dan penjelasannya tidak boleh meluap.
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _catalog(tester);

      RoutineEditorResult? result;
      const routine = Routine(id: 'push', name: 'Push');
      await tester.pumpWidget(_wrap(store, _launcher(const RoutineEditorScreen(routine: routine), (r) => result = r)));
      await tester.tap(find.text('GO'));
      await _settle(tester);

      expect(find.text('Exclude from progression'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse, reason: 'bawaan: bukan rutinitas deload');

      await tester.tap(find.byType(Switch));
      await _settle(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.text('SAVE'));
      await _settle(tester);
      final saved = result;
      expect(saved, isA<RoutineSaved>());
      expect((saved as RoutineSaved).routine.excludedFromProgression, isTrue);
      expect(saved.routine.id, 'push', reason: 'id tidak berubah saat ditandai');

      // Yang menyimpan adalah pemanggil editor (tab Workout) — lewat store.
      await store.saveRoutine(saved.routine);
      final again = WorkoutStore();
      await again.load();
      expect(again.routineById('push')!.excludedFromProgression, isTrue);
    });

    testWidgets('saklar yang sudah nyala bisa dimatikan lagi', (tester) async {
      _phone(tester);
      await _catalog(tester);
      RoutineEditorResult? result;
      await tester.pumpWidget(_wrap(store, _launcher(const RoutineEditorScreen(routine: _deload), (r) => result = r)));
      await tester.tap(find.text('GO'));
      await _settle(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.tap(find.byType(Switch));
      await _settle(tester);
      await tester.tap(find.text('SAVE'));
      await _settle(tester);
      expect((result as RoutineSaved).routine.excludedFromProgression, isFalse);
    });
  });
}
