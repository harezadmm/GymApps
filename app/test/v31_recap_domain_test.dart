/// Recap mingguan/bulanan (v3.1): rentang periode, total dan pembanding,
/// progres per gerakan, rekor, hari latihan, ember volume, set per otot,
/// dan berat badan. Semua dihitung dari set yang benar-benar tercatat.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/muscle_volume.dart';
import 'package:gymapps/domain/onerm.dart';
import 'package:gymapps/domain/recap.dart';
import 'package:gymapps/domain/settings.dart';
import 'package:gymapps/domain/units.dart';

const _bench = Exercise(
  id: 'bench',
  name: 'Barbell Bench Press',
  bodyPart: 'chest',
  equipment: 'barbell',
  target: 'pectorals',
  secondary: ['triceps'],
);
const _squat = Exercise(
  id: 'squat',
  name: 'Barbell Squat',
  bodyPart: 'upper legs',
  equipment: 'barbell',
  target: 'quads',
  secondary: ['glutes'],
);
const _pulldown = Exercise(
  id: 'pulldown',
  name: 'Lat Pulldown',
  bodyPart: 'back',
  equipment: 'cable',
  target: 'lats',
  secondary: ['biceps'],
);

final _catalog = ExerciseCatalog.forTest(const [_bench, _squat, _pulldown]);

const _benchTarget = ExerciseConfig(exerciseId: 'bench', policy: ProgressionPolicy.double_, reps: 10, repsMin: 6);

SetRow _s(double w, int r, {bool done = true, SetPhase phase = SetPhase.work}) =>
    SetRow(weight: w, reps: r, done: done, phase: phase);

WorkoutEntry _e(String id, List<SetRow> sets, {ExerciseConfig? target}) =>
    WorkoutEntry(exerciseId: id, sets: sets, target: target);

Workout _w(String date, List<WorkoutEntry> entries, {int? dur, String? routine}) =>
    Workout(date: date, entries: entries, durationSeconds: dur, routine: routine);

/// Riwayat contoh, terbaru dulu seperti `WorkoutStore.workouts`.
/// Minggu sebelumnya: 28 Sep – 4 Okt 2026. Minggu ini: 5 – 11 Okt 2026.
final _history = <Workout>[
  _w('2026-10-09', [
    _e('bench', [_s(62.5, 8), _s(62.5, 8), _s(62.5, 8)], target: _benchTarget),
    _e('pulldown', [_s(55, 12), _s(55, 11), _s(55, 10)]),
  ], dur: 3000),
  _w('2026-10-07', [
    _e('squat', [_s(80, 5), _s(80, 5), _s(80, 4), _s(80, 4)]),
  ], dur: 2400),
  _w('2026-10-05', [
    _e('bench', [_s(40, 10, phase: SetPhase.warmup), _s(62.5, 8), _s(62.5, 8), _s(62.5, 7), _s(62.5, 6, done: false)],
        target: _benchTarget),
  ], dur: 3300),
  _w('2026-10-02', [
    _e('squat', [_s(80, 5), _s(80, 5), _s(80, 5), _s(80, 5)]),
  ], dur: 2700),
  _w('2026-09-29', [
    _e('bench', [_s(60, 8), _s(60, 8), _s(60, 8)], target: _benchTarget),
  ], dur: 3000),
  _w('2026-09-20', [
    _e('bench', [_s(65, 5)]),
  ]),
];

const _bw = [
  BodyweightEntry(date: '2026-10-01', kg: 73.0),
  BodyweightEntry(date: '2026-10-06', kg: 72.8),
  BodyweightEntry(date: '2026-10-10', kg: 72.4),
];

DateTime _d(int y, int m, int d) => DateTime(y, m, d);

void main() {
  group('rentang periode', () {
    test('minggu mulai Senin, Minggu, atau Sabtu', () {
      final fri = DateTime(2026, 10, 9, 23, 59);
      final mon = recapRangeFor(RecapPeriod.week, fri);
      expect(mon.start, _d(2026, 10, 5));
      expect(mon.end, _d(2026, 10, 12));
      expect(mon.days, 7);
      final sun = recapRangeFor(RecapPeriod.week, fri, weekStartsOn: DateTime.sunday);
      expect(sun.start, _d(2026, 10, 4));
      expect(sun.end, _d(2026, 10, 11));
      final sat = recapRangeFor(RecapPeriod.week, fri, weekStartsOn: DateTime.saturday);
      expect(sat.start, _d(2026, 10, 3));
      expect(sat.end, _d(2026, 10, 10));
      // Hari Minggu tetap milik minggu yang dimulai Senin sebelumnya.
      expect(recapRangeFor(RecapPeriod.week, _d(2026, 10, 11)).start, _d(2026, 10, 5));
    });

    test('bulan kalender, termasuk Desember → Januari dan Februari kabisat', () {
      final dec = recapRangeFor(RecapPeriod.month, _d(2026, 12, 15));
      expect(dec.start, _d(2026, 12, 1));
      expect(dec.end, _d(2027, 1, 1));
      expect(dec.days, 31);
      final jan = shiftRecapRange(RecapPeriod.month, dec, 1);
      expect(jan.start, _d(2027, 1, 1));
      expect(jan.end, _d(2027, 2, 1));
      expect(shiftRecapRange(RecapPeriod.month, jan, -1).start, _d(2026, 12, 1));
      expect(recapRangeFor(RecapPeriod.month, _d(2028, 2, 10)).days, 29);
    });

    test('geser minggu dan isi rentang', () {
      final week = recapRangeFor(RecapPeriod.week, _d(2026, 10, 9));
      final prev = shiftRecapRange(RecapPeriod.week, week, -1);
      expect(prev.start, _d(2026, 9, 28));
      expect(prev.end, _d(2026, 10, 5));
      expect(week.contains(_d(2026, 10, 5)), isTrue);
      expect(week.contains(_d(2026, 10, 12)), isFalse);
      expect(week.contains(DateTime(2026, 10, 11, 22)), isTrue);
    });
  });

  group('recap mingguan', () {
    late Recap r;
    setUp(() {
      r = buildRecap(
        history: _history,
        period: RecapPeriod.week,
        range: recapRangeFor(RecapPeriod.week, _d(2026, 10, 9)),
        catalog: _catalog,
        bodyweight: _bw,
      );
    });

    test('total periode ini dan periode sebelumnya', () {
      expect(r.previous.start, _d(2026, 9, 28));
      expect(r.now.sessions, 3);
      expect(r.before.sessions, 2);
      // Pemanasan dan set yang tidak dicentang bukan set kerja.
      expect(r.now.workingSets, 13);
      expect(r.before.workingSets, 7);
      expect(r.now.volume, closeTo(62.5 * 23 + 80 * 18 + 62.5 * 24 + 55 * 33, 1e-6));
      expect(r.before.volume, closeTo(60 * 24 + 80 * 20, 1e-6));
      expect(r.now.reps, 23 + 18 + 24 + 33);
      expect(r.before.reps, 24 + 20);
      expect(r.now.minutes, 145);
      expect(r.before.minutes, 95);
      expect(r.avgSessionMinutes, 48);
      expect(r.isEmpty, isFalse);
    });

    test('hari latihan, istirahat terpanjang, dan ember volume per hari', () {
      expect(r.trainedDays, ['2026-10-05', '2026-10-07', '2026-10-09']);
      expect(r.longestRestDays, 1);
      expect(r.volumeBuckets.length, 7);
      expect(r.bucketStarts.first, _d(2026, 10, 5));
      expect(r.volumeBuckets[0], closeTo(62.5 * 23, 1e-6));
      expect(r.volumeBuckets[1], 0);
      expect(r.volumeBuckets[2], closeTo(80 * 18, 1e-6));
      expect(r.volumeBuckets[4], closeTo(62.5 * 24 + 55 * 33, 1e-6));
    });

    test('progres per gerakan: urutan, top set, e1RM, pembanding, rentang rep, set terakhir', () {
      expect(r.exercises.map((e) => e.exerciseId), ['bench', 'pulldown', 'squat']);
      final bench = r.exercises.first;
      expect(bench.sessions, 2);
      expect(bench.workingSets, 6);
      expect(bench.volume, closeTo(62.5 * 47, 1e-6));
      expect(bench.topSet!.weight, 62.5);
      expect(bench.topSet!.reps, 8);
      expect(bench.topSetBefore!.weight, 60);
      expect(bench.topSetBefore!.reps, 8);
      expect(bench.e1rm, estimate1RM(62.5, 8));
      expect(bench.e1rmBefore, estimate1RM(60, 8));
      expect(bench.e1rmDelta, closeTo(estimate1RM(62.5, 8)! - estimate1RM(60, 8)!, 1e-6));
      expect(bench.repRange, '6-10');
      expect([for (final s in bench.lastSets) s.reps], [8, 8, 8]);
      expect(bench.isNew, isFalse);

      final pulldown = r.exercises[1];
      expect(pulldown.isNew, isTrue, reason: 'belum pernah dicatat sebelum minggu ini');
      expect(pulldown.topSetBefore, isNull);
      expect(pulldown.isRecord, isFalse, reason: 'gerakan pertama kali bukan rekor');
    });

    test('rekor hanya bila mengalahkan semua catatan sebelum periode', () {
      final bench = r.exercises.firstWhere((e) => e.exerciseId == 'bench');
      final best = [estimate1RM(60, 8)!, estimate1RM(65, 5)!].reduce((a, b) => a > b ? a : b);
      expect(bench.bestBeforeRange, best);
      expect(bench.isRecord, isTrue);
      final squat = r.exercises.firstWhere((e) => e.exerciseId == 'squat');
      expect(squat.isRecord, isFalse, reason: 'sama dengan sebelumnya, bukan rekor');
      expect(r.records.map((e) => e.exerciseId), ['bench']);
    });

    test('set kerja per otot utama dan berat badan', () {
      expect(r.muscleSets[MuscleGroup.chest], 6);
      expect(r.muscleSets[MuscleGroup.quads], 4);
      expect(r.muscleSets[MuscleGroup.lats], 3);
      expect(r.bodyweightStart, 73.0, reason: 'catatan terakhir sebelum periode jadi titik awal');
      expect(r.bodyweightEnd, 72.4);
    });

    test('tanpa katalog: set per otot kosong, sisanya tetap', () {
      final plain = buildRecap(
        history: _history,
        period: RecapPeriod.week,
        range: recapRangeFor(RecapPeriod.week, _d(2026, 10, 9)),
      );
      expect(plain.muscleSets, isEmpty);
      expect(plain.now.sessions, 3);
    });
  });

  group('recap bulanan', () {
    test('Oktober vs September, ember per minggu bulan', () {
      final r = buildRecap(
        history: _history,
        period: RecapPeriod.month,
        range: recapRangeFor(RecapPeriod.month, _d(2026, 10, 9)),
        catalog: _catalog,
      );
      expect(r.range.days, 31);
      expect(r.now.sessions, 4);
      expect(r.before.sessions, 2);
      expect(r.volumeBuckets.length, 5, reason: '1–7, 8–14, 15–21, 22–28, 29–31');
      expect(r.bucketStarts.map((d) => d.day), [1, 8, 15, 22, 29]);
      expect(r.volumeBuckets[0], closeTo(80 * 20 + 62.5 * 23 + 80 * 18, 1e-6));
      expect(r.volumeBuckets[1], closeTo(62.5 * 24 + 55 * 33, 1e-6));
      expect(r.volumeBuckets.skip(2).every((v) => v == 0), isTrue);
    });

    test('periode kosong', () {
      final r = buildRecap(
        history: _history,
        period: RecapPeriod.month,
        range: recapRangeFor(RecapPeriod.month, _d(2026, 6, 1)),
      );
      expect(r.isEmpty, isTrue);
      expect(r.exercises, isEmpty);
      expect(r.avgSessionMinutes, isNull);
      expect(r.longestRestDays, 0);
    });
  });


  group('payload AI', () {
    Recap week() => buildRecap(
          history: _history,
          period: RecapPeriod.week,
          range: recapRangeFor(RecapPeriod.week, _d(2026, 10, 9)),
          catalog: _catalog,
          bodyweight: _bw,
        );
    String name(String id) => _catalog.nameOf(id);

    test('kunci sesuai kontrak server, angka dalam kg', () {
      final p = recapPayload(week(), lang: 'id', unit: WeightUnit.kg, nameOf: name,
          program: const RecapProgram(name: 'PPL', mode: 'rotation', plannedSessions: 3));
      expect(p.keys.toSet(), {
        'v', 'period', 'lang', 'unit', 'range', 'totals', 'program', 'exercises', 'records', 'muscleSets', 'bodyweight',
      });
      expect(p['v'], 1);
      expect(p['period'], 'week');
      expect(p['range'], {'start': '2026-10-05', 'end': '2026-10-11', 'days': 7});
      final totals = p['totals'] as Map;
      expect(totals['sessions'], 3);
      expect(totals['sessionsBefore'], 2);
      expect(totals['workingSets'], 13);
      expect(totals['trainingMinutes'], 145);
      expect(totals['trainingMinutesBefore'], 95);
      expect(totals['avgSessionMinutes'], 48);
      expect(totals['trainingDays'], 3);
      expect(totals['longestRestDays'], 1);
      expect(totals['volume'], (62.5 * 23 + 80 * 18 + 62.5 * 24 + 55 * 33).round());
      expect(p['program'], {'name': 'PPL', 'mode': 'rotation', 'plannedSessions': 3});
      final bench = (p['exercises'] as List).first as Map;
      expect(bench['name'], 'Barbell Bench Press');
      expect(bench['sessions'], 2);
      expect(bench['sets'], 6);
      expect(bench['repRange'], '6-10');
      expect(bench['topSet'], '62.5x8');
      expect(bench['topSetBefore'], '60x8');
      expect(bench['e1rm'], estimate1RM(62.5, 8));
      expect(bench['lastSession'], '62.5x8, 62.5x8, 62.5x8');
      expect(bench['volumeBefore'], 60 * 24);
      expect(bench['record'], isTrue);
      expect(bench['new'], isFalse);
      final pulldown = (p['exercises'] as List)[1] as Map;
      expect(pulldown['new'], isTrue);
      expect(pulldown.containsKey('topSetBefore'), isFalse);
      expect((p['records'] as List).single['name'], 'Barbell Bench Press');
      expect(p['muscleSets'], {'chest': 6, 'lats': 3, 'quads': 4});
      expect(p['bodyweight'], {'start': 73.0, 'end': 72.4});
    });

    test('satuan lb dikonversi, berat badan juga', () {
      final p = recapPayload(week(), lang: 'en', unit: WeightUnit.lb, nameOf: name);
      expect(p['unit'], 'lb');
      expect(p.containsKey('program'), isFalse);
      final bench = (p['exercises'] as List).first as Map;
      expect(bench['topSet'], '${shown(62.5, WeightUnit.lb)}x8');
      expect((p['bodyweight'] as Map)['end'], shown(72.4, WeightUnit.lb));
    });

    test('bulan: set per otot per minggu ikut dikirim', () {
      final r = buildRecap(
        history: _history,
        period: RecapPeriod.month,
        range: recapRangeFor(RecapPeriod.month, _d(2026, 10, 9)),
        catalog: _catalog,
      );
      final p = recapPayload(r, lang: 'id', unit: WeightUnit.kg, nameOf: name);
      expect(p['period'], 'month');
      expect((p['muscleSetsPerWeek'] as Map)['chest'], (6 / (31 / 7) * 10).round() / 10);
      expect(p.containsKey('bodyweight'), isFalse);
    });

    test('batas 15 gerakan dan 10 rekor; ukuran < 24 KB', () {
      final many = <Workout>[
        for (var i = 0; i < 60; i++)
          _w('2026-10-0${5 + i % 5}', [
            _e('custom-$i', [_s(20.0 + i, 10), _s(20.0 + i, 10)]),
          ], dur: 3600),
        for (var i = 0; i < 60; i++)
          _w('2026-09-1${i % 9}', [
            _e('custom-$i', [_s(10.0 + i, 10)]),
          ]),
      ];
      final r = buildRecap(history: many, period: RecapPeriod.week, range: recapRangeFor(RecapPeriod.week, _d(2026, 10, 9)));
      final p = recapPayload(r, lang: 'id', unit: WeightUnit.kg,
          nameOf: (id) => 'Exercise with a rather long descriptive name number $id');
      expect((p['exercises'] as List).length, 15);
      expect((p['records'] as List).length, 10);
      expect(utf8.encode(jsonEncode(p)).length, lessThan(24 * 1024));
    });

    test('sidik jari stabil dan berubah saat data berubah', () {
      final a = recapPayload(week(), lang: 'id', unit: WeightUnit.kg, nameOf: name);
      final b = recapPayload(week(), lang: 'id', unit: WeightUnit.kg, nameOf: name);
      expect(payloadFingerprint(a), payloadFingerprint(b));
      final changed = buildRecap(
        history: [
          _w('2026-10-10', [_e('bench', [_s(65, 5)])]),
          ..._history,
        ],
        period: RecapPeriod.week,
        range: recapRangeFor(RecapPeriod.week, _d(2026, 10, 9)),
        catalog: _catalog,
        bodyweight: _bw,
      );
      final c = recapPayload(changed, lang: 'id', unit: WeightUnit.kg, nameOf: name);
      expect(payloadFingerprint(c), isNot(payloadFingerprint(a)));
      expect(payloadFingerprint(a), matches(RegExp(r'^[0-9a-f]{40}$')));
    });

    test('sesi rencana: hari tetap menghitung hari latihan di rentang, rotasi per minggu', () {
      final oct = recapRangeFor(RecapPeriod.month, _d(2026, 10, 9));
      const weekday = Program(name: 'UL', mode: ProgramMode.weekday, days: [1, 3, 5]);
      expect(plannedSessionsIn(weekday, oct), 13);
      const rotation = Program(name: 'PPL', order: ['a', 'b', 'c']);
      expect(plannedSessionsIn(rotation, recapRangeFor(RecapPeriod.week, _d(2026, 10, 9))), 3);
      expect(plannedSessionsIn(rotation, oct), 13);
    });
  });
}
