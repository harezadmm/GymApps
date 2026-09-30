/// Mesin assisted berjalan terbalik — port dari openGym v1.3.8, issue #232.
///
/// Di assisted pull-up angka yang dicatat adalah bantuan mesin: makin kecil
/// makin berat. Yang diuji di sini adalah aturan katalog yang sengaja sempit,
/// pembacaan sesi dari bantuan terkecil, arah naik/tahan/deload di tiap
/// policy, lantai nol, hitungan stall, e1RM yang tidak dihitung, arah rekor,
/// terjemahan alasannya, dan tri-state di editor rutinitas.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/assisted.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/onerm.dart';
import 'package:gymapps/domain/progression.dart';
import 'package:gymapps/domain/session_plan.dart';
import 'package:gymapps/domain/stats.dart';
import 'package:gymapps/features/session/exercise_history_sheet.dart';
import 'package:gymapps/features/workout/routine_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Delapan entri katalog yang assisted: alat `leverage machine` dan nama
/// memuat kata `assist(ed)`. Diambil dari `assets/data/exercises.json`.
const _assistedIds = {
  '0009', // assisted chest dip (kneeling)
  '0015', // assisted parallel close grip pull-up
  '0017', // assisted pull-up
  '0019', // assisted triceps dip (kneeling)
  '0572', // lever assisted chin-up
  '1431', // assisted standing chin-up
  '1432', // assisted standing pull-up
  '2364', // assisted wide-grip chest dip (kneeling)
};

/// Assisted pull-up (0017) dengan arah yang sudah diresolusi, seperti yang
/// dibekukan `buildSessionExercise` ke target sesi.
ExerciseConfig _cfg({
  ProgressionPolicy policy = ProgressionPolicy.linear,
  int reps = 8,
  int? repsMin,
  bool? assisted = true,
  double? increment,
  double? deloadFactor,
}) =>
    ExerciseConfig(
      exerciseId: '0017',
      policy: policy,
      sets: 3,
      reps: reps,
      repsMin: repsMin,
      weight: 25,
      increment: increment,
      deloadFactor: deloadFactor,
      assisted: assisted,
    );

/// Satu sesi assisted pull-up: (bantuan, rep) per set kerja, semua tercentang
/// kecuali disebut lain. Targetnya ikut dibekukan seperti sesi sungguhan.
Workout _sesi(String date, List<(double, int)> rows, {ExerciseConfig? target, List<bool>? done}) => Workout(
      date: date,
      entries: [
        WorkoutEntry(
          exerciseId: '0017',
          target: target ?? _cfg(),
          sets: [
            for (var i = 0; i < rows.length; i++) SetRow(weight: rows[i].$1, reps: rows[i].$2, done: done?[i] ?? true),
          ],
        ),
      ],
    );

/// Tiga set penuh pada bantuan [help] — sesi yang "berhasil".
Workout _hit(String date, double help, {ExerciseConfig? target, int reps = 8}) =>
    _sesi(date, [(help, reps), (help, reps), (help, reps)], target: target);

/// Tiga set kurang pada bantuan [help] — sesi yang "gagal".
Workout _miss(String date, double help, {ExerciseConfig? target}) =>
    _sesi(date, [(help, 8), (help, 6), (help, 5)], target: target);

Exercise _ex(String id, String name, String eq, {bool? assisted}) =>
    Exercise(id: id, name: name, bodyPart: 'back', equipment: eq, target: 'lats', secondary: const [], assisted: assisted);

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        child: MaterialApp(theme: buildGymTheme(), home: home),
      ),
    );

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

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Gulir daftar editor sampai [f] terbangun dan terlihat. ListView membangun
/// anaknya malas, jadi blok di bawah picker policy belum ada sebelum digulir
/// — apalagi dengan teks 130 %. Digulir lewat posisinya, bukan gesture:
/// Scrollable pertama di pohon adalah daftar luar editor.
Future<void> _reveal(WidgetTester tester, Finder f) async {
  final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  var offset = 0.0;
  while (f.evaluate().isEmpty && offset < position.maxScrollExtent) {
    offset = math.min(offset + 300, position.maxScrollExtent);
    position.jumpTo(offset);
    await tester.pump();
  }
  await tester.ensureVisible(f);
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('aturan katalog (#232)', () {
    test('alat leverage machine + kata assist(ed) utuh, dan hanya itu', () {
      expect(isAssistedExercise(equipment: 'leverage machine', name: 'Assisted Pull-up'), isTrue);
      expect(isAssistedExercise(equipment: 'leverage machine', name: 'Lever Assisted Chin-up'), isTrue);
      expect(isAssistedExercise(equipment: 'leverage machine', name: 'ASSIST DIP'), isTrue, reason: 'tak peduli huruf');
      // Peregangan dengan bantuan pasangan: alatnya `assisted`, bukan mesin.
      expect(isAssistedExercise(equipment: 'assisted', name: 'Assisted Lying Calves Stretch'), isFalse);
      expect(isAssistedExercise(equipment: 'band', name: 'Band Assisted Pull-up'), isFalse);
      expect(isAssistedExercise(equipment: 'cable', name: 'Cable Assisted Inverse Leg Curl'), isFalse);
      // Kata harus utuh: "assistance" bukan "assist".
      expect(isAssistedExercise(equipment: 'leverage machine', name: 'Assistance Row'), isFalse);
      expect(isAssistedExercise(equipment: 'leverage machine', name: 'Lever Row'), isFalse);
    });

    test('delapan entri katalog sungguhan assisted; tetangganya tidak', () async {
      final catalog = await ExerciseCatalog.load();
      for (final id in _assistedIds) {
        final e = catalog.byId(id)!;
        expect(e.isAssisted, isTrue, reason: '$id ${e.name}');
        expect(e.equipment, 'leverage machine');
      }
      final assisted = {for (final e in catalog.all) if (e.isAssisted) e.id};
      expect(assisted, _assistedIds, reason: 'tidak ada entri lain yang ikut terbaca assisted');
      // "assisted lying calves stretch" (1708) memakai alat `assisted`.
      expect(catalog.byId('1708')!.name.toLowerCase(), 'assisted lying calves stretch');
      expect(catalog.isAssisted('1708'), isFalse);
      expect(catalog.isAssisted('0970'), isFalse, reason: 'band assisted pull-up');
      expect(catalog.isAssisted('0697'), isFalse, reason: 'self assisted inverse leg curl');
      expect(catalog.isAssisted('0025'), isFalse, reason: 'barbell bench press');
      expect(catalog.isAssisted('tidak-ada'), isFalse);
    });

    test('override gerakan custom menang ke dua arah', () {
      expect(_ex('c1', 'Assisted Pull-up', 'leverage machine', assisted: false).isAssisted, isFalse);
      expect(_ex('c2', 'Gravitron Gym X', 'leverage machine', assisted: true).isAssisted, isTrue);
      expect(_ex('c3', 'Gravitron Gym X', 'leverage machine').isAssisted, isFalse, reason: 'tanpa override: aturan');
      final catalog = ExerciseCatalog.forTest([
        _ex('c1', 'Assisted Pull-up', 'leverage machine', assisted: false),
        _ex('c2', 'Gravitron Gym X', 'leverage machine', assisted: true),
      ]);
      expect(catalog.isAssisted('c1'), isFalse);
      expect(catalog.isAssisted('c2'), isTrue);
    });

    test('override gerakan custom ikut disimpan dan dibaca ulang', () {
      final j = _ex('c2', 'Gravitron', 'leverage machine', assisted: true).toJson();
      expect(j['assisted'], isTrue);
      expect(Exercise.fromJson(j).assisted, isTrue);
      expect(Exercise.fromJson(_ex('c3', 'Gravitron', 'leverage machine').toJson()).assisted, isNull);
      expect(_ex('c3', 'Gravitron', 'leverage machine').toJson().containsKey('assisted'), isFalse);
      // Nilai rusak dari perangkat lain = otomatis, bukan salah satu arah.
      expect(Exercise.fromJson({'id': 'x', 'n': 'x', 'assisted': 'ya'}).assisted, isNull);
    });

    test('withAssisted: slot otomatis diisi dari katalog, override tidak disentuh', () {
      final catalog = ExerciseCatalog.forTest([
        _ex('0017', 'Assisted Pull-up', 'leverage machine'),
        _ex('0025', 'Barbell Bench Press', 'barbell'),
      ]);
      expect(catalog.withAssisted(const ExerciseConfig(exerciseId: '0017')).assisted, isTrue);
      expect(catalog.withAssisted(const ExerciseConfig(exerciseId: '0025')).assisted, isNull,
          reason: 'gerakan biasa tetap null supaya dokumen tidak mengangkut false di mana-mana');
      expect(catalog.withAssisted(const ExerciseConfig(exerciseId: '0017', assisted: false)).assisted, isFalse);
      expect(catalog.withAssisted(const ExerciseConfig(exerciseId: '0025', assisted: true)).assisted, isTrue);
    });

    test('override slot rutinitas: JSON bolak-balik, tri-state utuh', () {
      const on = ExerciseConfig(exerciseId: '0017', assisted: true);
      const off = ExerciseConfig(exerciseId: '0017', assisted: false);
      const auto = ExerciseConfig(exerciseId: '0017');
      expect(on.toJson()['assisted'], isTrue);
      expect(off.toJson()['assisted'], isFalse);
      expect(auto.toJson().containsKey('assisted'), isFalse);
      expect(ExerciseConfig.fromJson(on.toJson()).assisted, isTrue);
      expect(ExerciseConfig.fromJson(off.toJson()).assisted, isFalse);
      expect(ExerciseConfig.fromJson(auto.toJson()).assisted, isNull);
      expect(ExerciseConfig.fromJson({'id': '0017', 'assisted': 1}).assisted, isNull);
      // copyWith: null berarti "jangan ubah"; kembali ke otomatis lewat clearAssisted.
      expect(on.copyWith(sets: 4).assisted, isTrue);
      expect(on.copyWith(assisted: false).assisted, isFalse);
      expect(on.copyWith(clearAssisted: true).assisted, isNull);
      expect(assistedIndex(null), 0);
      expect(assistedIndex(true), 1);
      expect(assistedIndex(false), 2);
    });
  });

  group('readSession (#232)', () {
    test('beban sesi = bantuan terkecil di atas nol; baris nol = tidak diisi', () {
      final w = _sesi('2026-09-01', [(25, 8), (0, 8), (20, 8)]);
      final r = readSession(w.entries.first, date: w.date, assisted: true);
      expect(r.weight, 20);
      expect(r.assisted, isTrue);
      // Gerakan biasa tetap membaca puncaknya.
      expect(readSession(w.entries.first, date: w.date, assisted: false).weight, 25);
    });

    test('semua baris nol → nol, bukan error', () {
      final w = _sesi('2026-09-01', [(0, 8), (0, 8)]);
      expect(readSession(w.entries.first, date: w.date, assisted: true).weight, 0);
    });

    test('set yang tidak dicentang tidak ikut; arah diambil dari target beku kalau tidak disebut', () {
      final w = _sesi('2026-09-01', [(25, 8), (15, 8), (20, 8)], done: [true, false, true]);
      final r = readSession(w.entries.first, date: w.date);
      expect(r.assisted, isTrue, reason: 'target sesi menyimpan assisted: true');
      expect(r.weight, 20, reason: '15 tidak dicentang');
      // Konfigurasi sekarang menang atas target beku.
      expect(readSession(w.entries.first, date: w.date, assisted: false).weight, 25);
    });
  });

  group('langkah dan deload', () {
    test('harderBy mengurangi bantuan dan berhenti di nol', () {
      expect(harderBy(20, 2.5, 2.5, assisted: true), 17.5);
      expect(harderBy(2.5, 2.5, 2.5, assisted: true), 0);
      expect(harderBy(1, 2.5, 2.5, assisted: true), 0, reason: 'tidak pernah negatif');
      expect(harderBy(20, 2.5, 2.5, assisted: false), 22.5);
    });

    test('moreHelp membagi dengan faktor lalu snap ke grid', () {
      expect(moreHelp(20, 2.5, 0.9), 22.5, reason: '20 / 0,9 = 22,2 → 22,5');
      expect(moreHelp(20, 5, 0.9), 25, reason: '22,2 di grid 5 kg = 20, tidak beranjak → +5');
      expect(moreHelp(40, 2.5, 0.5), 80);
      expect(easierTo(20, 2.5, 0.9, assisted: true), 22.5);
      expect(easierTo(20, 2.5, 0.9, assisted: false), 17.5);
    });
  });

  group('linear (#232)', () {
    test('naik = bantuan berkurang satu increment, alasannya bicara bantuan', () {
      final p = nextPrescription(workouts: [_hit('2026-09-01', 20)], cfg: _cfg());
      expect(p.kind, PrescriptionKind.up);
      expect(p.weight, 17.5);
      expect(p.why, '2.5 kg less help — all reps hit last session.');
    });

    test('tahan = bantuan sama', () {
      final p = nextPrescription(workouts: [_miss('2026-09-01', 20)], cfg: _cfg());
      expect(p.kind, PrescriptionKind.hold);
      expect(p.weight, 20);
      expect(p.why, contains('same help'));
    });

    test('deload setelah 3 gagal = bantuan bertambah (dibagi faktor)', () {
      final h = [_miss('2026-09-01', 20), _miss('2026-09-03', 20), _miss('2026-09-05', 20)];
      final p = nextPrescription(workouts: h, cfg: _cfg());
      expect(p.kind, PrescriptionKind.deload);
      expect(p.weight, 22.5);
      expect(p.why, contains('more help'));
      expect(p.why, contains('22.5 kg'));
    });

    test('faktor deload sendiri tetap dihormati, ke arah yang benar', () {
      final h = [_miss('2026-09-01', 40), _miss('2026-09-03', 40), _miss('2026-09-05', 40)];
      final p = nextPrescription(workouts: h, cfg: _cfg(deloadFactor: 0.8));
      expect(p.weight, 50);
    });

    test('di nol bantuan: tahan, jangan negatif, suruh pindah ke versi tanpa bantuan', () {
      final p = nextPrescription(workouts: [_hit('2026-09-01', 0)], cfg: _cfg());
      expect(p.kind, PrescriptionKind.hold);
      expect(p.weight, 0);
      expect(p.reps, 8);
      expect(p.why, contains('unassisted'));
      expect(p.why, isNot(contains('+')));
    });

    test('naik dari 2,5 kg mendarat di nol, bukan −2,5', () {
      final p = nextPrescription(workouts: [_hit('2026-09-01', 2.5)], cfg: _cfg());
      expect(p.kind, PrescriptionKind.up);
      expect(p.weight, 0);
    });

    test('greyskull: lompatan ganda berarti dua langkah bantuan lebih sedikit', () {
      final cfg = _cfg(policy: ProgressionPolicy.greyskull, reps: 5);
      final p = nextPrescription(workouts: [_sesi('2026-09-01', [(20, 5), (20, 5), (20, 12)], target: cfg)], cfg: cfg);
      expect(p.kind, PrescriptionKind.up);
      expect(p.weight, 15);
      expect(p.why, contains('5 kg less help'));
    });

    test('gerakan biasa tidak berubah: teks dan arah lama', () {
      final cfg = _cfg(assisted: null);
      final p = nextPrescription(workouts: [_hit('2026-09-01', 20, target: cfg)], cfg: cfg);
      expect(p.weight, 22.5);
      expect(p.why, '+2.5 kg — all reps hit last session.');
    });

    test('konfigurasi otomatis mengikuti arah yang dibekukan di sesi terakhir', () {
      // Sesi dibuka saat katalog bilang assisted; pratinjau dari konfigurasi
      // rutinitas yang belum diresolusi tetap harus membaca arah yang sama.
      final p = nextPrescription(workouts: [_hit('2026-09-01', 20)], cfg: _cfg(assisted: null));
      expect(p.weight, 17.5);
    });
  });

  group('double progression (#232)', () {
    final cfg = _cfg(policy: ProgressionPolicy.double_, reps: 10, repsMin: 6);

    test('atas rentang di semua set → bantuan berkurang, rep kembali ke bawah', () {
      final p = nextPrescription(workouts: [_hit('2026-09-01', 20, target: cfg, reps: 10)], cfg: cfg);
      expect(p.kind, PrescriptionKind.up);
      expect(p.weight, 17.5);
      expect(p.reps, 6);
      expect(p.why, contains('2.5 kg less help'));
    });

    test('di dalam rentang → bantuan sama, kejar satu rep lebih', () {
      final p = nextPrescription(workouts: [_sesi('2026-09-01', [(20, 8), (20, 7), (20, 7)], target: cfg)], cfg: cfg);
      expect(p.kind, PrescriptionKind.hold);
      expect(p.weight, 20);
      expect(p.reps, 8);
      expect(p.why, startsWith('Same help'));
    });

    test('mandek 3 sesi → bantuan bertambah', () {
      Workout s(String d) => _sesi(d, [(20, 5), (20, 5), (20, 4)], target: cfg);
      final p = nextPrescription(workouts: [s('2026-09-01'), s('2026-09-03'), s('2026-09-05')], cfg: cfg);
      expect(p.kind, PrescriptionKind.deload);
      expect(p.weight, 22.5);
      expect(p.why, contains('more help'));
    });
  });

  group('Heavy Duty (#232)', () {
    final cfg = _cfg(policy: ProgressionPolicy.hit, reps: 10, repsMin: 6);

    test('lewat batas atas → bantuan berkurang', () {
      final p = nextPrescription(workouts: [_sesi('2026-09-01', [(20, 11)], target: cfg)], cfg: cfg);
      expect(p.kind, PrescriptionKind.up);
      expect(p.weight, 17.5);
      expect(p.reps, 6);
      expect(p.why, contains('less help'));
    });

    test('dalam rentang → bantuan sama', () {
      final p = nextPrescription(workouts: [_sesi('2026-09-01', [(20, 8)], target: cfg)], cfg: cfg);
      expect(p.kind, PrescriptionKind.hold);
      expect(p.weight, 20);
      expect(p.why, contains('same help'));
    });

    test('dua kali di bawah batas → bantuan bertambah', () {
      final h = [_sesi('2026-09-01', [(20, 4)], target: cfg), _sesi('2026-09-03', [(20, 5)], target: cfg)];
      final p = nextPrescription(workouts: h, cfg: cfg);
      expect(p.kind, PrescriptionKind.deload);
      expect(p.weight, 22.5);
      expect(p.why, contains('more help'));
    });

    test('di nol bantuan tidak jatuh ke jalur bodyweight', () {
      final p = nextPrescription(workouts: [_sesi('2026-09-01', [(0, 11)], target: cfg)], cfg: cfg);
      expect(p.kind, PrescriptionKind.hold);
      expect(p.weight, 0);
      expect(p.why, contains('unassisted'));
    });
  });

  group('stall (#232)', () {
    test('bantuan yang berkurang lalu gagal adalah stall pertama, bukan lanjutan', () {
      final s = sessionsFor([_miss('2026-09-01', 25), _miss('2026-09-03', 22.5)], '0017', assisted: true);
      expect(stallCount(s, ProgressionPolicy.linear), 1);
    });

    test('gagal berulang pada bantuan yang sama tetap terhitung', () {
      final s = sessionsFor([_miss('2026-09-01', 22.5), _miss('2026-09-03', 22.5)], '0017', assisted: true);
      expect(stallCount(s, ProgressionPolicy.linear), 2);
    });

    test('bantuan yang bertambah (deload) juga memutus rentetan', () {
      final s = sessionsFor([_miss('2026-09-01', 20), _miss('2026-09-03', 22.5)], '0017', assisted: true);
      expect(stallCount(s, ProgressionPolicy.linear), 1);
    });
  });

  group('rencana sesi (#232)', () {
    test('tangga bantuan digeser dari bantuan terkecil, warm-up lebih banyak bantuan', () {
      final cfg = _cfg().copyWith(warmupSets: 1);
      final history = [_sesi('2026-09-01', [(30, 8), (25, 8), (20, 8)], target: cfg)];
      final plan = planExercise(cfg, history);
      expect(plan.prescription.kind, PrescriptionKind.up);
      expect([for (final s in plan.sets) if (s.isWork) s.weight], [27.5, 22.5, 17.5]);
      final warm = plan.sets.firstWhere((s) => s.isWarmup);
      expect(warm.weight, 27.5, reason: '150 % dari 17,5 = 26,25 → grid 2,5 → 27,5: pemanasan lebih ringan');
      expect(plan.target.assisted, isTrue, reason: 'arah ikut dibekukan ke target sesi');
    });

    test('deload menggeser seluruh tangga ke bantuan lebih banyak', () {
      final cfg = _cfg();
      Workout s(String d) => _sesi(d, [(25, 6), (20, 5), (20, 4)], target: cfg);
      final plan = planExercise(cfg, [s('2026-09-01'), s('2026-09-03'), s('2026-09-05')]);
      expect(plan.prescription.kind, PrescriptionKind.deload);
      final work = [for (final s in plan.sets) if (s.isWork) s.weight];
      expect(work.last, 22.5);
      expect(work.first, greaterThan(25));
    });
  });

  group('e1RM (#232)', () {
    final entry = _sesi('2026-09-01', [(20, 8), (20, 8)]).entries.first;

    test('entri assisted tidak menghasilkan estimasi', () {
      expect(bestSetOf(entry), isNull, reason: 'target beku bilang assisted');
      final noTarget = WorkoutEntry(exerciseId: '0017', sets: entry.sets);
      expect(bestSetOf(noTarget), isNotNull, reason: 'tanpa target dan tanpa pencarian: dibaca biasa');
      expect(bestSetOf(noTarget, isAssisted: (id) => id == '0017'), isNull);
      // Target beku menang atas pencarian: slot yang dipaksa biasa tetap punya e1RM.
      final forcedNormal = WorkoutEntry(exerciseId: '0017', target: _cfg(assisted: false), sets: entry.sets);
      expect(bestSetOf(forcedNormal, isAssisted: (_) => true), isNotNull);
    });

    test('tidak ada titik kurva, rekor, daftar kekuatan, maupun e1RM mingguan', () {
      final history = [_hit('2026-09-01', 25), _hit('2026-09-08', 20)];
      final today = DateTime(2026, 9, 10);
      expect(e1rmSeries(history, '0017'), isEmpty);
      expect(best1RM(history, '0017'), isNull);
      expect(is1RMRecord(history, '0017', _hit('2026-09-15', 15).entries.first), isNull);
      expect(weeklyE1rm(history, '0017', today).every((v) => v == 0), isTrue);
      expect(strengthByMovement(history, today), isEmpty);
      // Gerakan biasa di riwayat yang sama tetap masuk.
      final mixed = [
        ...history,
        Workout(date: '2026-09-09', entries: [
          WorkoutEntry(exerciseId: '0025', sets: const [SetRow(weight: 80, reps: 5, done: true)]),
        ]),
      ];
      expect(strengthByMovement(mixed, today).map((m) => m.exerciseId), ['0025']);
    });
  });

  group('rekor beban (#232)', () {
    test('rekor assisted = bantuan terkecil > 0, dipecahkan oleh angka lebih kecil', () {
      final history = [
        _sesi('2026-09-01', [(30, 8), (25, 8)]),
        _sesi('2026-09-08', [(0, 8), (22.5, 8)]),
      ];
      expect(recordLoadOf(history.last.entries.first, assisted: true), 22.5, reason: 'nol bukan rekor');
      expect(bestLoad(history, '0017', assisted: true), (load: 22.5, date: '2026-09-08'));
      expect(bestLoad(history, '0017', assisted: false), (load: 30, date: '2026-09-01'));

      final less = isLoadRecord(history, '0017', _hit('2026-09-15', 20).entries.first)!;
      expect(less.now, 20);
      expect(less.previous, 22.5);
      expect(isLoadRecord(history, '0017', _hit('2026-09-15', 25).entries.first), isNull,
          reason: 'lebih banyak bantuan bukan rekor');
      expect(isLoadRecord(const [], '0017', _hit('2026-09-15', 25).entries.first)!.previous, isNull);
    });

    test('arah rekor satu gerakan diambil dari entri terbaru, urutan daftar bebas', () {
      final oldestFirst = [_hit('2026-09-01', 30), _hit('2026-09-08', 25)];
      expect(exerciseIsAssisted(oldestFirst, '0017'), isTrue);
      expect(exerciseIsAssisted(oldestFirst.reversed.toList(), '0017'), isTrue);
      expect(exerciseIsAssisted(oldestFirst, '0025'), isFalse);
      expect(exerciseIsAssisted(oldestFirst, '0025', (_) => true), isTrue, reason: 'tanpa entri: pencarian');
    });

    test('lembar riwayat: "Terberat" jadi bantuan terkecil untuk assisted', () {
      final newestFirst = [_hit('2026-09-08', 20), _hit('2026-09-01', 25)];
      final r = recordsFor(newestFirst, '0017');
      expect(r.assisted, isTrue);
      expect(r.heaviest, 20);
      expect(r.heaviestDate, '2026-09-08');
      expect(r.best, isNull, reason: 'tanpa e1RM');
      expect(r.bestVolume, 25 * 8 * 3, reason: 'volume tidak ikut aturan arah — bukan bagian #232');
      // Gerakan biasa: arah lama.
      final bench = [
        Workout(date: '2026-09-08', entries: [
          WorkoutEntry(exerciseId: '0025', sets: const [SetRow(weight: 80, reps: 5, done: true)]),
        ]),
        Workout(date: '2026-09-01', entries: [
          WorkoutEntry(exerciseId: '0025', sets: const [SetRow(weight: 85, reps: 3, done: true)]),
        ]),
      ];
      final b = recordsFor(bench, '0025');
      expect(b.assisted, isFalse);
      expect(b.heaviest, 85);
      expect(b.best, isNotNull);
    });
  });

  group('teks', () {
    const id = Strings(AppLanguage.indonesian);
    const en = Strings(AppLanguage.english);

    test('alasan assisted diterjemahkan, alasan biasa tetap', () {
      expect(id.why('2.5 kg less help — all reps hit last session.'),
          '2.5 kg bantuan lebih sedikit — semua rep tercapai di sesi lalu.');
      expect(id.why('Reps short 3 sessions running — more help, back to 22.5 kg, then work it down again.'),
          'Rep kurang 3 sesi beruntun — bantuan lebih banyak, kembali ke 22.5 kg, lalu kurangi lagi.');
      expect(id.why('No help left to take away — move on to the unassisted exercise.'),
          'Bantuan sudah habis — pindah ke versi tanpa bantuan.');
      expect(id.why('Same help — go for 8 reps this time.'), 'Bantuan sama — kejar 8 rep kali ini.');
      expect(id.why('+2.5 kg — all reps hit last session.'), '+2.5 kg — semua rep tercapai di sesi lalu.');
      expect(en.why('2.5 kg less help — all reps hit last session.'), '2.5 kg less help — all reps hit last session.');
    });

    test('setiap alasan assisted dari engine punya terjemahan', () {
      final cfgLin = _cfg();
      final cfgDbl = _cfg(policy: ProgressionPolicy.double_, reps: 10, repsMin: 6);
      final cfgHit = _cfg(policy: ProgressionPolicy.hit, reps: 10, repsMin: 6);
      final cfgGs = _cfg(policy: ProgressionPolicy.greyskull, reps: 5);
      final whys = <String>[
        nextPrescription(workouts: [_hit('2026-09-01', 20)], cfg: cfgLin).why,
        nextPrescription(workouts: [_miss('2026-09-01', 20)], cfg: cfgLin).why,
        nextPrescription(workouts: [_miss('2026-09-01', 20), _miss('2026-09-03', 20), _miss('2026-09-05', 20)], cfg: cfgLin).why,
        nextPrescription(workouts: [_miss('2026-09-01', 20)], cfg: cfgGs).why,
        nextPrescription(workouts: [_sesi('2026-09-01', [(20, 5), (20, 5), (20, 12)], target: cfgGs)], cfg: cfgGs).why,
        nextPrescription(workouts: [_hit('2026-09-01', 0)], cfg: cfgLin).why,
        nextPrescription(workouts: [_hit('2026-09-01', 20, target: cfgDbl, reps: 10)], cfg: cfgDbl).why,
        nextPrescription(workouts: [_sesi('2026-09-01', [(20, 8), (20, 7), (20, 7)], target: cfgDbl)], cfg: cfgDbl).why,
        nextPrescription(workouts: [for (final d in ['01', '03', '05']) _sesi('2026-09-$d', [(20, 5), (20, 5), (20, 4)], target: cfgDbl)], cfg: cfgDbl).why,
        nextPrescription(workouts: [_sesi('2026-09-01', [(20, 11)], target: cfgHit)], cfg: cfgHit).why,
        nextPrescription(workouts: [_sesi('2026-09-01', [(20, 8)], target: cfgHit)], cfg: cfgHit).why,
        nextPrescription(workouts: [_sesi('2026-09-01', [(20, 4)], target: cfgHit)], cfg: cfgHit).why,
        nextPrescription(workouts: [_sesi('2026-09-01', [(20, 4)], target: cfgHit), _sesi('2026-09-03', [(20, 5)], target: cfgHit)], cfg: cfgHit).why,
      ];
      for (final w in whys) {
        expect(w, isNot(contains('+')), reason: 'assisted tidak pernah "+": $w');
        expect(id.why(w), isNot(w), reason: 'belum diterjemahkan: $w');
      }
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

    testWidgets('tri-state assisted: bawaan otomatis, bisa dipaksa dan dikembalikan, tersimpan', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      // Teks 130 % (NFR-11): tiga segmen dan keterangannya tidak boleh meluap.
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(ExerciseCatalog.load);

      RoutineEditorResult? result;
      const routine = Routine(id: 'pull', name: 'Pull', exercises: [ExerciseConfig(exerciseId: '0017')]);
      await tester.pumpWidget(_wrap(store, _launcher(const RoutineEditorScreen(routine: routine), (r) => result = r)));
      await tester.tap(find.text('GO'));
      await _settle(tester);

      // Gerakan pertama terbuka otomatis; blok tri-state ada di bawah picker
      // policy. SectionLabel menulis judulnya kapital.
      await _reveal(tester, find.text('ASSISTED MACHINE'));
      expect(find.text('ASSISTED MACHINE'), findsOneWidget);
      final tabs = tester.widget<SegmentedTabs>(find.byType(SegmentedTabs));
      expect(tabs.index, 0, reason: 'bawaan: otomatis');
      expect(tabs.labels, ['Auto', 'Assisted', 'Normal']);

      await tester.tap(find.text('Normal'));
      await _settle(tester);
      expect(tester.widget<SegmentedTabs>(find.byType(SegmentedTabs)).index, 2);

      await tester.tap(find.text('Assisted'));
      await _settle(tester);
      expect(tester.widget<SegmentedTabs>(find.byType(SegmentedTabs)).index, 1);

      await tester.ensureVisible(find.text('SAVE'));
      await tester.tap(find.text('SAVE'));
      await _settle(tester);
      final saved = result;
      expect(saved, isA<RoutineSaved>());
      expect((saved as RoutineSaved).routine.exercises.single.assisted, isTrue);

      await store.saveRoutine(saved.routine);
      final again = WorkoutStore();
      await again.load();
      expect(again.routineById('pull')!.exercises.single.assisted, isTrue);
    });

    testWidgets('kembali ke otomatis menghapus override, bukan menulis false', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.runAsync(ExerciseCatalog.load);

      RoutineEditorResult? result;
      const routine =
          Routine(id: 'pull', name: 'Pull', exercises: [ExerciseConfig(exerciseId: '0017', assisted: false)]);
      await tester.pumpWidget(_wrap(store, _launcher(const RoutineEditorScreen(routine: routine), (r) => result = r)));
      await tester.tap(find.text('GO'));
      await _settle(tester);
      await _reveal(tester, find.text('Auto'));
      expect(tester.widget<SegmentedTabs>(find.byType(SegmentedTabs)).index, 2);
      await tester.tap(find.text('Auto'));
      await _settle(tester);
      await tester.ensureVisible(find.text('SAVE'));
      await tester.tap(find.text('SAVE'));
      await _settle(tester);
      expect((result as RoutineSaved).routine.exercises.single.assisted, isNull);
    });
  });
}
