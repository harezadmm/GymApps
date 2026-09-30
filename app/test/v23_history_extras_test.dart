/// Riwayat v2.3: sesi yang sudah selesai dijadikan rutinitas (FR-B8 lewat
/// FR-F1), dan ekspor CSV riwayat (FR-G6).
///
/// Dua pembangun murninya diuji tanpa widget. Alur UI-nya diuji di sheet
/// detail Riwayat, ringkasan selesai, dan tombol ekspor di header — dengan
/// penyimpan palsu, karena dialog "simpan ke" milik sistem tidak ada di test.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/csv.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/program.dart';
import 'package:gymapps/domain/routine_from_workout.dart';
import 'package:gymapps/domain/units.dart';
import 'package:gymapps/features/history/history_screen.dart';
import 'package:gymapps/features/session/finish_screen.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, Widget home, {AppLanguage lang = AppLanguage.english}) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: Strings(lang),
        child: MaterialApp(theme: buildGymTheme(), home: home),
      ),
    );

/// HP kecil yang umum: 360 × 780 dp.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Huruf sistem 1,3× — batas yang dijepit aplikasi (NFR-11), jadi huruf
/// terbesar yang pernah dilihat layar mana pun.
void _bigText(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Pump berjangka, bukan pumpAndSettle: animasi kedatangan tidak pernah
/// "tenang".
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Habiskan waktu SnackBar beserta animasi keluarnya, supaya test tidak
/// berakhir dengan timer yang masih menggantung.
Future<void> _expireSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

/// Katalog dibaca dari aset lewat I/O sungguhan, yang tidak pernah selesai di
/// dalam zona waktu palsu widget test; dimuat sekali lewat `runAsync`.
Future<ExerciseCatalog> _catalog(WidgetTester tester) async => (await tester.runAsync(ExerciseCatalog.load))!;

SetRow _s(double w, int r, {bool done = true, SetPhase phase = SetPhase.work, int? rir, int sec = 0}) =>
    SetRow(weight: w, reps: r, seconds: sec, done: done, phase: phase, rir: rir);

const _bench = ExerciseConfig(
  exerciseId: '0025',
  policy: ProgressionPolicy.double_,
  reps: 10,
  repsMin: 6,
  restSeconds: 120,
  increment: 2.5,
);

/// Sesi bench press: satu pemanasan, tiga set kerja tercentang, satu tidak.
Workout _sesi(String date, {String? routine, double w = 60, String? gymId}) => Workout(
      date: date,
      routine: routine,
      durationSeconds: 1800,
      gymId: gymId,
      entries: [
        WorkoutEntry(
          exerciseId: '0025',
          target: _bench,
          sets: [
            _s(40, 8, phase: SetPhase.warmup),
            _s(w, 8),
            _s(w, 8, rir: 2),
            _s(w + 2.5, 6),
            _s(w + 5, 5, done: false),
          ],
        ),
      ],
    );

Workout _one(String id, List<SetRow> sets, {ExerciseConfig? target, String date = '2026-09-20'}) =>
    Workout(date: date, entries: [WorkoutEntry(exerciseId: id, sets: sets, target: target)]);

/// Gulir isi sheet detail sampai [finder] tampak: ListView-nya malas, jadi
/// tombol di bawah lipatan belum tentu sudah dibangun sebelum digulir.
Future<void> _revealInSheet(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    100,
    scrollable: find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(Scrollable)),
  );
  await _settle(tester);
}

/// Buka sheet detail sesi [title] lalu ketuk JADIKAN RUTINITAS di dalamnya.
Future<void> _openSaveAsRoutine(WidgetTester tester, String title) async {
  await tester.tap(find.descendant(of: find.byType(Dismissible), matching: find.text(title)));
  await _settle(tester);
  await _revealInSheet(tester, find.text('SAVE AS ROUTINE'));
  await tester.tap(find.text('SAVE AS ROUTINE'));
  await _settle(tester);
}

Finder _dialogSave() => find.descendant(of: find.byType(AlertDialog), matching: find.text('SAVE'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('routineFromWorkout', () {
    test('set = set kerja tercentang, rep = yang paling sering, beban = terberat yang tercentang', () {
      final r = routineFromWorkout(_sesi('2026-09-20', routine: 'Push'), id: 'r1', name: 'Push B');
      expect(r.id, 'r1');
      expect(r.name, 'Push B');
      expect(r.policy, ProgressionPolicy.double_, reason: 'policy yang dibekukan ke target jadi policy rutinitas');
      final cfg = r.exercises.single;
      expect(cfg.exerciseId, '0025');
      expect(cfg.sets, 3, reason: 'pemanasan dan set yang tidak dicentang tidak dihitung');
      expect(cfg.reps, 8);
      expect(cfg.weight, 62.5, reason: '65 tidak dicentang');
      expect(cfg.warmupSets, 1);
      expect(cfg.restSeconds, 120);
      expect(cfg.increment, 2.5);
      expect(cfg.repsMin, 6, reason: 'rentang di bawah rep baru ikut');
      expect(cfg.mode, LogMode.reps);
      expect(cfg.policy, isNull, reason: 'sama dengan policy rutinitas, tidak perlu override');
    });

    test('rep seri dimenangkan yang lebih tinggi; baris 0 rep yang tercentang bukan set', () {
      final cfg = routineFromWorkout(_one('x', [_s(60, 8), _s(60, 10), _s(60, 0)]), id: 'r', name: 'n').exercises.single;
      expect(cfg.reps, 10);
      expect(cfg.sets, 2);
    });

    test('assisted (#232): bantuan paling sedikit di atas nol, arah dari target yang dibekukan', () {
      final w = _one(
        'a',
        [_s(30, 8), _s(25, 6), _s(20, 4, done: false)],
        target: const ExerciseConfig(exerciseId: 'a', assisted: true),
      );
      final cfg = routineFromWorkout(w, id: 'r', name: 'n').exercises.single;
      expect(cfg.weight, 25, reason: '20 tidak dicentang; 25 bantuan lebih sedikit dari 30');
      expect(cfg.assisted, isTrue, reason: 'override arah ikut ke rutinitas');
    });

    test('assisted tanpa override di target: arah dari pencarian katalog', () {
      final w = Workout(date: '2026-09-20', entries: [
        WorkoutEntry(exerciseId: 'a', sets: [_s(30, 8), _s(25, 6)]),
        WorkoutEntry(exerciseId: 'b', sets: [_s(30, 8), _s(25, 6)]),
      ]);
      final r = routineFromWorkout(w, id: 'r', name: 'n', isAssisted: (id) => id == 'a');
      expect(r.exercises[0].weight, 25);
      expect(r.exercises[1].weight, 30);
      expect(r.exercises[0].assisted, isNull, reason: 'tanpa override tetap otomatis dari katalog');
    });

    test('gerakan tanpa set tercentang dilewati; pemanasan tercentang saja tidak cukup', () {
      final w = Workout(date: '2026-09-20', entries: [
        WorkoutEntry(exerciseId: 'skip', sets: [_s(60, 8, done: false), _s(60, 8, done: false)]),
        WorkoutEntry(exerciseId: 'warm', sets: [_s(40, 8, phase: SetPhase.warmup), _s(60, 8, done: false)]),
        WorkoutEntry(exerciseId: 'keep', sets: [_s(60, 8)]),
      ]);
      final r = routineFromWorkout(w, id: 'r', name: 'n');
      expect([for (final c in r.exercises) c.exerciseId], ['keep']);
      expect(routineFromWorkout(const Workout(date: '2026-09-20', entries: []), id: 'r', name: 'n').exercises, isEmpty);
    });

    test('drop set dan rest-pause (FR-D7) tidak menggeser set, rep, dan beban', () {
      final w = _one('x', [_s(80, 8), _s(80, 8), _s(60, 12, phase: SetPhase.drop), _s(80, 3, phase: SetPhase.restPause)]);
      final cfg = routineFromWorkout(w, id: 'r', name: 'n').exercises.single;
      expect(cfg.sets, 2);
      expect(cfg.reps, 8);
      expect(cfg.weight, 80);
    });

    test('mode waktu dipertahankan: detiknya yang dipilih', () {
      final w = _one(
        'plank',
        [_s(0, 0, sec: 45), _s(0, 0, sec: 45), _s(0, 0, sec: 40)],
        target: const ExerciseConfig(exerciseId: 'plank', mode: LogMode.time, seconds: 30, policy: ProgressionPolicy.time),
      );
      final r = routineFromWorkout(w, id: 'r', name: 'n');
      final cfg = r.exercises.single;
      expect(cfg.mode, LogMode.time);
      expect(cfg.seconds, 45);
      expect(cfg.sets, 3);
      expect(cfg.weight, 0);
      expect(r.policy, ProgressionPolicy.time);
    });

    test('bar, bodyweight, superset, dan heavy ikut dari target; faktor deload tidak', () {
      final w = _one(
        'x',
        [_s(0, 12), _s(0, 12)],
        target: const ExerciseConfig(
          exerciseId: 'x',
          barWeight: 10,
          bodyweight: true,
          superset: true,
          heavyBodyPart: true,
          deloadFactor: 0.8,
          repsMax: 20,
        ),
      );
      final cfg = routineFromWorkout(w, id: 'r', name: 'n').exercises.single;
      expect(cfg.barWeight, 10);
      expect(cfg.bodyweight, isTrue);
      expect(cfg.superset, isTrue);
      expect(cfg.heavyBodyPart, isTrue);
      expect(cfg.repsMax, 20);
      expect(cfg.deloadFactor, isNull, reason: 'dibekukan dari setelan Profil, bukan pilihan untuk gerakan ini');
    });

    test('policy: yang paling umum jadi policy rutinitas, yang berbeda jadi override', () {
      final w = Workout(date: '2026-09-20', entries: [
        WorkoutEntry(exerciseId: 'a', target: const ExerciseConfig(exerciseId: 'a', policy: ProgressionPolicy.double_), sets: [_s(60, 8)]),
        WorkoutEntry(exerciseId: 'b', target: const ExerciseConfig(exerciseId: 'b', policy: ProgressionPolicy.double_), sets: [_s(60, 8)]),
        WorkoutEntry(exerciseId: 'c', target: const ExerciseConfig(exerciseId: 'c', policy: ProgressionPolicy.linear), sets: [_s(60, 5)]),
      ]);
      final r = routineFromWorkout(w, id: 'r', name: 'n');
      expect(r.policy, ProgressionPolicy.double_);
      expect(r.exercises[0].policy, isNull);
      expect(r.exercises[2].policy, ProgressionPolicy.linear);
      // Riwayat lama tanpa target: tidak ada policy yang bisa diklaim.
      expect(routineFromWorkout(_one('x', [_s(60, 8)]), id: 'r', name: 'n').policy, isNull);
    });
  });

  group('historyCsv', () {
    String name(String id) => id == '0025' ? 'Barbell Bench Press' : 'Exercise $id';

    test('header, CRLF, dan urutan: tanggal naik → gerakan → set', () {
      final newerFirst = [
        Workout(date: '2026-09-21', routine: 'Pull', entries: [WorkoutEntry(exerciseId: 'b', sets: [_s(40, 10)])]),
        Workout(date: '2026-09-20', routine: 'Push', entries: [
          WorkoutEntry(exerciseId: '0025', sets: [_s(40, 8, phase: SetPhase.warmup), _s(60, 8, rir: 2), _s(62.5, 6, done: false)]),
          WorkoutEntry(exerciseId: 'c', sets: [_s(20, 12)]),
        ]),
      ];
      final csv = historyCsv(newerFirst, unit: WeightUnit.kg, exerciseName: name);
      expect(csv.split('\r\n'), [
        'date,routine,gym,exercise,set,phase,weight,unit,reps,seconds,rir,done',
        '2026-09-20,Push,,Barbell Bench Press,1,warmup,40,kg,8,0,,true',
        '2026-09-20,Push,,Barbell Bench Press,2,work,60,kg,8,0,2,true',
        '2026-09-20,Push,,Barbell Bench Press,3,work,62.5,kg,6,0,,false',
        '2026-09-20,Push,,Exercise c,1,work,20,kg,12,0,,true',
        '2026-09-21,Pull,,Exercise b,1,work,40,kg,10,0,,true',
        '',
      ], reason: 'CRLF di akhir tiap baris, termasuk yang terakhir');
      expect(csv.split('\r\n').first, csvHeader.join(','));
      expect(csv.replaceAll('\r\n', '').contains('\n'), isFalse, reason: 'tidak ada LF telanjang');
    });

    test('dua sesi sehari mempertahankan urutan masukan', () {
      final w = [
        Workout(date: '2026-09-20', routine: 'A', entries: [WorkoutEntry(exerciseId: 'x', sets: [_s(1, 1)])]),
        Workout(date: '2026-09-20', routine: 'B', entries: [WorkoutEntry(exerciseId: 'x', sets: [_s(1, 1)])]),
        Workout(date: '2026-09-19', routine: 'C', entries: [WorkoutEntry(exerciseId: 'x', sets: [_s(1, 1)])]),
      ];
      final lines = historyCsv(w, unit: WeightUnit.kg, exerciseName: name).split('\r\n');
      expect([for (final l in lines.skip(1)) if (l.isNotEmpty) l.split(',')[1]], ['C', 'A', 'B']);
    });

    test('koma, kutip, dan baris baru dibungkus kutip (RFC 4180)', () {
      final w = [
        Workout(date: '2026-09-20', routine: 'Push, heavy "A"', gymId: 'g1', entries: [
          WorkoutEntry(exerciseId: 'x', sets: [_s(60, 8)]),
        ]),
      ];
      final csv = historyCsv(
        w,
        unit: WeightUnit.kg,
        exerciseName: (_) => 'Line1\nLine2',
        gymName: (id) => id == 'g1' ? 'Gym "dekat" kantor' : '',
      );
      expect(csv.split('\r\n')[1], '2026-09-20,"Push, heavy ""A""","Gym ""dekat"" kantor","Line1\nLine2",1,work,60,kg,8,0,,true');
      expect(csvField('plain'), 'plain');
      expect(csvField('a,b'), '"a,b"');
      expect(csvField('say "hi"'), '"say ""hi"""');
      expect(csvField('cr\rlf'), '"cr\rlf"');
    });

    test('beban dalam satuan tampilan dengan pembulatan aplikasi', () {
      final w = [_one('x', [_s(60, 8), _s(63.5029318, 5)])];
      final kg = historyCsv(w, unit: WeightUnit.kg, exerciseName: name).split('\r\n');
      expect(kg[1].split(',')[6], '60');
      expect(kg[2].split(',')[6], '63.5', reason: '140 lb yang tersimpan sebagai kg tidak ditulis 63.502931800000006');
      expect(kg[1].split(',')[7], 'kg');
      final lb = historyCsv(w, unit: WeightUnit.lb, exerciseName: name).split('\r\n');
      expect(lb[1].split(',')[6], '132.3');
      expect(lb[2].split(',')[6], '140');
      expect(lb[1].split(',')[7], 'lb');
    });

    test('gym: nama dari penyelesai, kosong kalau tidak dikenal atau tanpa penyelesai', () {
      final w = [
        _one('x', [_s(60, 8)], date: '2026-09-20').copyWith(gymId: 'g1'),
        _one('x', [_s(60, 8)], date: '2026-09-21').copyWith(gymId: 'gone'),
        _one('x', [_s(60, 8)], date: '2026-09-22'),
      ];
      final seen = <String?>[];
      final lines = historyCsv(w, unit: WeightUnit.kg, exerciseName: name, gymName: (id) {
        seen.add(id);
        return id == 'g1' ? 'Home' : '';
      }).split('\r\n');
      expect([for (final l in lines.skip(1)) if (l.isNotEmpty) l.split(',')[2]], ['Home', '', '']);
      expect(seen, ['g1', 'gone', null], reason: 'sesi tanpa gym diserahkan apa adanya; pemanggil yang tahu gym bawaan');
      expect(historyCsv(w, unit: WeightUnit.kg, exerciseName: name).split('\r\n')[1].split(',')[2], '');
    });

    test('sesi yang dihapus (tombstone) tidak ikut', () async {
      SharedPreferences.setMockInitialValues({});
      final store = WorkoutStore();
      await store.load();
      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      await store.addWorkout(_sesi('2026-09-21', routine: 'Pull'));
      await store.removeWorkout(store.workouts.first);
      final csv = historyCsv(store.chronological, unit: WeightUnit.kg, exerciseName: name);
      expect(csv, contains('Push'));
      expect(csv, isNot(contains('Pull')));
    });
  });

  group('jadikan rutinitas (UI)', () {
    late WorkoutStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ExerciseCatalog.registerCustom(const []);
      store = WorkoutStore();
      await store.load();
    });

    testWidgets('sheet detail: nama terisi, kotak rotasi tercentang, rutinitas masuk store dan akhir rotasi', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.applyTemplate('ppl');
      final push = store.routines.first;
      await store.addWorkout(_sesi('2026-09-20', routine: push.name), routineId: push.id);
      final before = store.routines.length;
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);

      await _openSaveAsRoutine(tester, 'Push');
      expect(find.text('Save as routine'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Push'), findsOneWidget, reason: 'terisi nama rutinitas sesi');
      expect(find.text('Add to rotation'), findsOneWidget, reason: 'PPL berjalan dalam mode rotasi');
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

      await tester.enterText(find.byType(TextField), 'Push B');
      await tester.tap(_dialogSave());
      await _settle(tester);

      expect(store.routines.length, before + 1);
      final saved = store.routines.last;
      expect(saved.name, 'Push B');
      expect(store.program!.order.last, saved.id, reason: 'ditambahkan di akhir rotasi');
      final cfg = saved.exercises.single;
      expect(cfg.exerciseId, '0025');
      expect(cfg.sets, 3);
      expect(cfg.reps, 8);
      expect(cfg.weight, 62.5);
      expect(cfg.warmupSets, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('RESUME SESSION'), findsNothing, reason: 'sheet ditutup supaya SnackBar terlihat');
      expect(find.text('Routine Push B saved.'), findsOneWidget);
      await _expireSnackBar(tester);
    });

    testWidgets('kotak rotasi dimatikan: rutinitas tersimpan di luar urutan program', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.applyTemplate('ppl');
      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      final order = [...store.program!.order];
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);

      await _openSaveAsRoutine(tester, 'Push');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      await tester.enterText(find.byType(TextField), 'Push solo');
      await tester.tap(_dialogSave());
      await _settle(tester);

      final saved = store.routines.last;
      expect(saved.name, 'Push solo');
      expect(store.program!.order, order, reason: 'urutan rotasi tidak berubah');
      expect(store.routineById(saved.id), isNotNull);
      await _expireSnackBar(tester);
    });

    testWidgets('batal tidak menyimpan apa pun', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.applyTemplate('ppl');
      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      final before = store.routines.length;
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);

      await _openSaveAsRoutine(tester, 'Push');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
      await _settle(tester);
      expect(store.routines.length, before);
      expect(find.text('RESUME SESSION'), findsOneWidget, reason: 'sheet masih terbuka');
    });

    testWidgets('program mode weekday: tanpa kotak rotasi, rutinitas tetap masuk program', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.applyTemplate('bro-split');
      expect(store.program!.mode, ProgramMode.weekday);
      await store.addWorkout(_sesi('2026-09-20', routine: 'Chest'));
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);

      await _openSaveAsRoutine(tester, 'Chest');
      expect(find.text('Add to rotation'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      await tester.enterText(find.byType(TextField), 'Chest B');
      await tester.tap(_dialogSave());
      await _settle(tester);

      final saved = store.routines.last;
      expect(saved.name, 'Chest B');
      expect(store.program!.order.last, saved.id);
      await _expireSnackBar(tester);
    });

    testWidgets('sesi tanpa nama: dialog terisi tanggalnya', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.addManualWorkout(_sesi('2026-09-20'));
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);

      await _openSaveAsRoutine(tester, 'Freestyle');
      expect(find.widgetWithText(TextField, '2026-09-20'), findsOneWidget);
      expect(find.text('Add to rotation'), findsNothing, reason: 'tanpa program tidak ada rotasi');
      await tester.tap(_dialogSave());
      await _settle(tester);
      expect(store.routines.single.name, '2026-09-20');
      expect(store.program!.order, [store.routines.single.id], reason: 'program lahir bersama rutinitas pertama');
      await _expireSnackBar(tester);
    });

    testWidgets('ringkasan selesai: menyimpan dalam kg dari sesi dalam lb, lalu tombolnya jadi keterangan', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.applyTemplate('ppl');
      await store.updateSettings(store.settings.copyWith(unit: WeightUnit.lb));
      final ex = SessionExercise(
        name: 'Barbell Bench Press',
        icon: Icons.fitness_center,
        config: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, sets: 3, reps: 8, weight: 135, restSeconds: 90),
        sets: [_s(95, 8, phase: SetPhase.warmup), _s(135, 8), _s(135, 8), _s(135, 7, done: false)],
        previous: const ['—', '—', '—', '—'],
      );
      await tester.pumpWidget(_wrap(
        store,
        FinishScreen(
          routineName: 'Freestyle',
          exercises: [ex],
          history: const [],
          elapsed: const Duration(minutes: 30),
          dateLabel: 'Sat 20 Sep · 10:00',
        ),
      ));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));

      await tester.ensureVisible(find.text('SAVE AS ROUTINE'));
      await _settle(tester);
      await tester.tap(find.text('SAVE AS ROUTINE'));
      await _settle(tester);
      expect(find.widgetWithText(TextField, 'Freestyle'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Bench day');
      await tester.tap(_dialogSave());
      await _settle(tester);

      final saved = store.routines.last;
      expect(saved.name, 'Bench day');
      final cfg = saved.exercises.single;
      expect(cfg.sets, 2);
      expect(cfg.reps, 8);
      expect(cfg.weight, closeTo(toKg(135, WeightUnit.lb), 0.001), reason: 'sesi dicatat dalam lb, rutinitas menyimpan kg');
      expect(cfg.restSeconds, 90);
      expect(cfg.warmupSets, 1);
      expect(store.program!.order.last, saved.id);
      expect(find.text('SAVE AS ROUTINE'), findsNothing, reason: 'tombolnya berganti keterangan, bukan membuat rutinitas kedua');
      expect(find.text('Routine Bench day saved.'), findsWidgets);
      expect(tester.takeException(), isNull);
      await _expireSnackBar(tester);
    });

    testWidgets('[id] sheet detail dan dialognya utuh di 360 dp dengan huruf 1,3×', (tester) async {
      _phone(tester);
      _bigText(tester);
      await _catalog(tester);
      await store.applyTemplate('ppl');
      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen()), lang: AppLanguage.indonesian));
      await _settle(tester);
      expect(find.byTooltip('Ekspor CSV'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(Dismissible), matching: find.text('Push')));
      await _settle(tester);
      await _revealInSheet(tester, find.text('JADIKAN RUTINITAS'));
      await tester.tap(find.text('JADIKAN RUTINITAS'));
      await _settle(tester);
      expect(find.text('Jadikan rutinitas'), findsOneWidget);
      expect(find.text('Tambahkan ke rotasi'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'dialog dengan kotak centang dan keterangannya tidak meluber');

      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('SIMPAN')));
      await _settle(tester);
      expect(find.text('Rutinitas Push disimpan.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _expireSnackBar(tester);
    });

    testWidgets('[id] ringkasan selesai dengan tombol jadikan rutinitas utuh dengan huruf 1,3×', (tester) async {
      _phone(tester);
      _bigText(tester);
      await _catalog(tester);
      await store.applyTemplate('ppl');
      final ex = SessionExercise(
        name: 'Barbell Bench Press',
        icon: Icons.fitness_center,
        config: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, sets: 2, reps: 8, weight: 60),
        sets: [_s(60, 8), _s(60, 8)],
        previous: const ['—', '—'],
      );
      await tester.pumpWidget(_wrap(
        store,
        FinishScreen(
          routineName: 'Push',
          exercises: [ex],
          history: const [],
          elapsed: const Duration(minutes: 30),
          dateLabel: 'Sab 20 Sep · 10:00',
        ),
        lang: AppLanguage.indonesian,
      ));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1200), warnIfMissed: false);
      await _settle(tester);
      expect(find.text('JADIKAN RUTINITAS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ekspor CSV (UI)', () {
    late WorkoutStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ExerciseCatalog.registerCustom(const []);
      store = WorkoutStore();
      await store.load();
    });

    testWidgets('tombol Export CSV: mengikuti chip rutinitas dan mengirim byte ke penyimpan', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      await store.addWorkout(_sesi('2026-09-21', routine: 'Pull', w: 40));
      final calls = <(String, Uint8List, String)>[];
      await tester.pumpWidget(_wrap(
        store,
        Scaffold(
          body: HistoryScreen(saveFile: (name, bytes, mime) async {
            calls.add((name, bytes, mime));
            return Uri.file('/tmp/$name');
          }),
        ),
      ));
      await _settle(tester);

      await tester.tap(find.byTooltip('Export CSV'));
      await _settle(tester);
      expect(calls, hasLength(1));
      final (name, bytes, mime) = calls.single;
      expect(name, 'gymapps-history-${isoDate(DateTime.now())}.csv');
      expect(mime, 'text/csv');
      final lines = utf8.decode(bytes).split('\r\n');
      expect(lines.first, csvHeader.join(','));
      expect(lines[1], '2026-09-20,Push,My gym,Barbell Bench Press,1,warmup,40,kg,8,0,,true');
      expect(lines[2], '2026-09-20,Push,My gym,Barbell Bench Press,2,work,60,kg,8,0,,true');
      expect(lines[3], '2026-09-20,Push,My gym,Barbell Bench Press,3,work,60,kg,8,0,2,true');
      expect(lines, contains('2026-09-21,Pull,My gym,Barbell Bench Press,2,work,40,kg,8,0,,true'));
      expect(find.text('CSV saved: $name'), findsOneWidget);
      await _expireSnackBar(tester);

      // Chip Pull: hanya sesi Pull yang diekspor.
      await tester.tap(find.descendant(of: find.byType(FilterChips), matching: find.text('Pull')));
      await _settle(tester);
      await tester.tap(find.byTooltip('Export CSV'));
      await _settle(tester);
      expect(calls, hasLength(2));
      final filtered = utf8.decode(calls.last.$2);
      expect(filtered, contains(',Pull,'));
      expect(filtered, isNot(contains(',Push,')));
      await _expireSnackBar(tester);
    });

    testWidgets('sesi yang menunggu URUNGKAN tidak ikut diekspor', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      await store.addWorkout(_sesi('2026-09-21', routine: 'Pull'));
      final calls = <Uint8List>[];
      await tester.pumpWidget(_wrap(
        store,
        Scaffold(
          body: HistoryScreen(saveFile: (_, bytes, _) async {
            calls.add(bytes);
            return Uri.file('/tmp/ok.csv');
          }),
        ),
      ));
      await _settle(tester);

      await tester.tap(find.descendant(of: find.byType(Dismissible), matching: find.text('Pull')));
      await _settle(tester);
      await _revealInSheet(tester, find.text('DELETE'));
      await tester.tap(find.text('DELETE'));
      await _settle(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('DELETE')));
      await _settle(tester);
      expect(find.text('UNDO'), findsOneWidget);
      expect(store.workouts.length, 2, reason: 'store belum disentuh selama URUNGKAN tampil');

      await tester.tap(find.byTooltip('Export CSV'));
      await _settle(tester);
      final csv = utf8.decode(calls.single);
      expect(csv, contains(',Push,'));
      expect(csv, isNot(contains(',Pull,')));
      await _expireSnackBar(tester);
      await _expireSnackBar(tester);
    });

    testWidgets('kosong: pesan ramah tanpa memanggil penyimpan; penyimpan gagal: pesan gagal', (tester) async {
      _phone(tester);
      await _catalog(tester);
      var calls = 0;
      await tester.pumpWidget(_wrap(
        store,
        Scaffold(
          body: HistoryScreen(saveFile: (_, _, _) async {
            calls++;
            throw Exception('disk penuh');
          }),
        ),
      ));
      await _settle(tester);

      await tester.tap(find.byTooltip('Export CSV'));
      await _settle(tester);
      expect(calls, 0);
      expect(find.text('Nothing to export yet.'), findsOneWidget);
      await _expireSnackBar(tester);

      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Export CSV'));
      await _settle(tester);
      expect(calls, 1);
      expect(find.text("Couldn't save the CSV."), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _expireSnackBar(tester);
    });
  });
}
