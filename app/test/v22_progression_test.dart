/// Progressive overload untuk gerakan yang disusun sendiri.
///
/// Permintaan pemakai: "hari ini sudah custom gerakan untuk push day, next-nya
/// tetap tersimpan tapi bebannya otomatis bertambah". Dua hal dijaga di sini:
/// gerakan tambahan masuk ke rutinitas dan sesi berikutnya menaikkan bebannya,
/// dan set bertingkat (30 → 50 → 55) tidak diratakan jadi 55/55/55.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/progression.dart';
import 'package:gymapps/domain/routine_sync.dart';
import 'package:gymapps/domain/session_plan.dart';

Workout _session(String date, String id, List<SetRow> sets, ExerciseConfig target) => Workout(
      date: date,
      routine: 'Push',
      entries: [WorkoutEntry(exerciseId: id, target: target, sets: sets)],
    );

List<double> _weights(PlannedExercise p) => [for (final s in p.sets) if (s.isWork) s.weight];

void main() {
  group('set bertingkat', () {
    const dbl = ExerciseConfig(exerciseId: 'row', policy: ProgressionPolicy.double_, sets: 3, reps: 12, repsMin: 8);

    test('ditahan: bentuk tangganya sama persis, bukan diratakan ke beban puncak', () {
      // Kasus dari tangkapan layar pemakai: Chest Support Row 30×8, 50×8, 55×6.
      final history = [
        _session('2026-09-28', 'row', const [
          SetRow(weight: 30, reps: 8, done: true),
          SetRow(weight: 50, reps: 8, done: true),
          SetRow(weight: 55, reps: 6, done: true),
        ], dbl),
      ];
      final plan = planExercise(dbl, history);
      expect(plan.prescription.kind, PrescriptionKind.hold);
      expect(_weights(plan), [30, 50, 55]);
      expect(plan.sets.map((s) => s.reps).toSet(), {8});
    });

    test('naik: seluruh tangga naik selangkah', () {
      const lin = ExerciseConfig(exerciseId: 'row', policy: ProgressionPolicy.linear, sets: 3, reps: 8);
      final history = [
        _session('2026-09-28', 'row', const [
          SetRow(weight: 30, reps: 8, done: true),
          SetRow(weight: 50, reps: 8, done: true),
          SetRow(weight: 55, reps: 8, done: true),
        ], lin),
      ];
      final plan = planExercise(lin, history);
      expect(plan.prescription.kind, PrescriptionKind.up);
      expect(_weights(plan), [32.5, 52.5, 57.5]);
    });

    test('set tambahan di luar sesi lalu memakai beban puncak yang diresepkan', () {
      const lin = ExerciseConfig(exerciseId: 'row', policy: ProgressionPolicy.linear, sets: 4, reps: 8);
      final history = [
        _session('2026-09-28', 'row', const [
          SetRow(weight: 40, reps: 8, done: true),
          SetRow(weight: 50, reps: 8, done: true),
          SetRow(weight: 60, reps: 8, done: true),
        ], lin.copyWith(sets: 3)),
      ];
      // Sesi lalu lengkap menurut targetnya sendiri (3 set), jadi tangganya
      // naik; set keempat yang baru ditambah memakai beban puncak barunya.
      expect(_weights(planExercise(lin, history)), [42.5, 52.5, 62.5, 62.5]);
    });

    test('set yang sama berat tetap seperti sebelumnya', () {
      const lin = ExerciseConfig(exerciseId: 'bench', policy: ProgressionPolicy.linear, sets: 3, reps: 5);
      final history = [
        _session('2026-09-28', 'bench', const [
          SetRow(weight: 60, reps: 5, done: true),
          SetRow(weight: 60, reps: 5, done: true),
          SetRow(weight: 60, reps: 5, done: true),
        ], lin),
      ];
      expect(_weights(planExercise(lin, history)), [62.5, 62.5, 62.5]);
    });
  });

  test('gerakan yang ditambah di sesi masuk rutinitas dan bebannya naik di sesi berikutnya', () {
    const bench = ExerciseConfig(exerciseId: 'bench', sets: 3, reps: 5, weight: 60);
    const push = Routine(id: 'r1', name: 'Push', exercises: [bench], policy: ProgressionPolicy.linear);

    // Hari ini: Cable Fly ditambah di tengah sesi, mengikuti policy rutinitas
    // (linear), 3 × 12 di 20 kg semuanya tercapai.
    const fly = ExerciseConfig(exerciseId: 'fly', sets: 3, reps: 12, policy: ProgressionPolicy.linear);
    final today = Workout(date: '2026-09-29', routine: 'Push', entries: [
      WorkoutEntry(exerciseId: 'bench', target: bench, sets: const [
        SetRow(weight: 60, reps: 5, done: true),
        SetRow(weight: 60, reps: 5, done: true),
        SetRow(weight: 60, reps: 5, done: true),
      ]),
      WorkoutEntry(exerciseId: 'fly', target: fly, sets: const [
        SetRow(weight: 20, reps: 12, done: true),
        SetRow(weight: 20, reps: 12, done: true),
        SetRow(weight: 20, reps: 12, done: true),
      ]),
    ]);

    final synced = syncRoutineWithSession(push, [(bench, 3), (fly, 3)]);
    expect(synced.exercises.map((e) => e.exerciseId), ['bench', 'fly'], reason: 'gerakan tambahan tersimpan');

    final next = {
      for (final cfg in synced.exercises)
        cfg.exerciseId: planExercise(cfg, [today], routineDefault: synced.policy),
    };
    expect(_weights(next['fly']!), [22.5, 22.5, 22.5], reason: 'progressive overload: +2,5 kg');
    expect(_weights(next['bench']!), [62.5, 62.5, 62.5]);
  });
}
