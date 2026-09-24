import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/stats.dart';

Workout _w(String date, String id, double weight, List<int> reps) => Workout(date: date, entries: [
      WorkoutEntry(exerciseId: id, sets: [for (final r in reps) SetRow(weight: weight, reps: r, done: true)]),
    ]);

void main() {
  final today = DateTime(2026, 9, 24);

  test('set kerja per minggu, minggu ini paling kanan', () {
    final weekly = weeklyWorkingSets([_w('2026-09-24', '0025', 60, [8, 8, 8]), _w('2026-09-10', '0025', 60, [8, 8])], today);
    expect(weekly.length, 8);
    expect(weekly.last, 3);
    expect(weekly[5], 2);
  });

  test('riwayat kosong → semua nol, bukan error', () {
    expect(weeklyWorkingSets(const [], today).every((v) => v == 0), isTrue);
    expect(strengthByMovement(const [], today), isEmpty);
  });

  test('e1RM mingguan membawa nilai terakhir di minggu tanpa sesi', () {
    final series = weeklyE1rm([_w('2026-08-20', '0025', 80, [5]), _w('2026-09-24', '0025', 85, [5])], '0025', today);
    expect(series.length, 12);
    expect(series.last, greaterThan(series[series.length - 3]));
    expect(series[series.length - 2], series[series.length - 3]);
  });

  test('kekuatan per gerakan: terbaik dulu, selisih terhadap 4 minggu lalu', () {
    final h = [_w('2026-08-01', '0025', 80, [5]), _w('2026-09-20', '0025', 90, [5]), _w('2026-09-21', '0027', 60, [8])];
    final m = strengthByMovement(h, today);
    expect(m.first.exerciseId, '0025');
    expect(m.first.delta, greaterThan(0));
    expect(m.last.delta, 0);
  });

  test('hari sejak region dilatih', () {
    final catalog = ExerciseCatalog.forTest(const [
      Exercise(id: '0025', name: 'Bench', bodyPart: 'chest', equipment: 'barbell', target: 'pectorals', secondary: []),
    ]);
    final d = daysSinceRegion([_w('2026-09-21', '0025', 60, [8])], catalog, today);
    expect(d['Chest'], 3);
    expect(d['Legs'], isNull);
  });
}
