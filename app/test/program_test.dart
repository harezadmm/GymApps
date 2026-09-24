import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/program.dart';
import 'package:gymapps/domain/progression.dart';
import 'package:gymapps/domain/session_plan.dart';
import 'package:gymapps/domain/templates.dart';

Routine _r(String id) => Routine(id: id, name: id.toUpperCase(), exercises: const [ExerciseConfig(exerciseId: '0025')]);

final _ppl = [_r('push'), _r('pull'), _r('legs')];
const _rot = Program(name: 'PPL', order: ['push', 'pull', 'legs']);

Workout _w(String date, {String? routine}) => Workout(date: date, routine: routine, entries: const []);

void main() {
  group('rotasi', () {
    test('sesi berikutnya mengikuti cursor, bukan hari', () {
      final n = nextSession(program: _rot.copyWith(cursor: 1), routines: _ppl, history: const [], today: DateTime(2026, 9, 21));
      expect(n!.routine.id, 'pull');
      expect(n.early, isFalse);
    });

    test('selesai Push → berikutnya Pull', () {
      expect(advanceAfter(_rot, 'push').cursor, 1);
    });

    test('memilih manual Push saat cursor di Legs → berikutnya Pull (FR-B4)', () {
      final p = _rot.copyWith(cursor: 2);
      expect(advanceAfter(p, 'push').cursor, 1);
    });

    test('Legs selesai berputar kembali ke Push', () {
      expect(advanceAfter(_rot.copyWith(cursor: 2), 'legs').cursor, 0);
    });

    test('sesi freestyle tidak menggeser cursor (FR-B3)', () {
      expect(advanceAfter(_rot.copyWith(cursor: 1), null).cursor, 1);
    });

    test('skip menggeser tanpa mencatat', () {
      final n = nextSession(program: _rot, routines: _ppl, history: const [], today: DateTime(2026, 9, 21))!;
      expect(skipNextIn(_rot, n).cursor, 1);
    });

    test('Heavy Duty: sesi Senin, Selasa masih pulih, jatuh tempo Kamis (FR-B5)', () {
      final p = _rot.copyWith(minRestDays: 3);
      final n = nextSession(program: p, routines: _ppl, history: [_w('2026-09-21')], today: DateTime(2026, 9, 22))!;
      expect(n.early, isTrue);
      expect(n.due, DateTime(2026, 9, 24));
      expect(n.due.weekday, DateTime.thursday);
    });

    test('masa istirahat lewat → jatuh tempo hari ini', () {
      final p = _rot.copyWith(minRestDays: 3);
      final n = nextSession(program: p, routines: _ppl, history: [_w('2026-09-21')], today: DateTime(2026, 9, 26))!;
      expect(n.early, isFalse);
      expect(n.due, DateTime(2026, 9, 26));
    });

    test('program tanpa rutinitas tidak punya sesi berikutnya', () {
      expect(nextSession(program: const Program(name: 'x'), routines: const [], history: const [], today: DateTime(2026)), isNull);
    });
  });

  group('weekday', () {
    final bro = [_r('chest'), _r('back'), _r('shoulders'), _r('legs'), _r('arms')];
    const p = Program(
      name: 'Bro',
      mode: ProgramMode.weekday,
      days: [1, 2, 3, 4, 5],
      order: ['chest', 'back', 'shoulders', 'legs', 'arms'],
    );

    test('Rabu = Shoulders', () {
      final n = nextSession(program: p, routines: bro, history: const [], today: DateTime(2026, 9, 23))!;
      expect(n.routine.id, 'shoulders');
      expect(n.early, isFalse);
    });

    test('Sabtu bukan hari latihan → Senin Chest, ditandai belum waktunya', () {
      final n = nextSession(program: p, routines: bro, history: const [], today: DateTime(2026, 9, 26))!;
      expect(n.routine.id, 'chest');
      expect(n.due.weekday, DateTime.monday);
      expect(n.early, isTrue);
    });

    test('sudah latihan hari ini → sesi berikutnya besok', () {
      final n = nextSession(program: p, routines: bro, history: [_w('2026-09-23')], today: DateTime(2026, 9, 23))!;
      expect(n.routine.id, 'legs');
    });

    test('skip hari ini melompat ke hari latihan berikutnya', () {
      final today = DateTime(2026, 9, 23);
      final n = nextSession(program: p, routines: bro, history: const [], today: today)!;
      final skipped = skipNextIn(p, n);
      final after = nextSession(program: skipped, routines: bro, history: const [], today: today)!;
      expect(after.routine.id, 'legs');
    });

    test('hari latihan lebih banyak dari rutinitas → rutinitas berputar', () {
      const two = Program(name: 'UL', mode: ProgramMode.weekday, days: [1, 2, 4, 5], order: ['chest', 'back']);
      expect(weekdaysOf(two, bro, 'chest'), [1, 4]);
      expect(weekdaysOf(two, bro, 'back'), [2, 5]);
    });
  });

  group('template', () {
    for (final id in templateIds) {
      test('$id menghasilkan rutinitas yang bisa dijalankan', () {
        final b = buildTemplate(id)!;
        expect(b.routines, isNotEmpty);
        expect(b.program.order, [for (final r in b.routines) r.id]);
        for (final r in b.routines) {
          expect(r.exercises, isNotEmpty, reason: '${r.name} kosong');
        }
      });
    }

    test('Bro split: 5 rutinitas Senin–Jumat, 4–5 gerakan, 8–12 rep (FR-B6)', () {
      final b = buildTemplate('bro-split')!;
      expect(b.routines.map((r) => r.name), ['Chest', 'Back', 'Shoulders', 'Legs', 'Arms']);
      expect(b.program.mode, ProgramMode.weekday);
      expect(b.program.days, [1, 2, 3, 4, 5]);
      for (final r in b.routines) {
        expect(r.exercises.length, inInclusiveRange(4, 5));
        for (final e in r.exercises) {
          expect(e.sets, inInclusiveRange(3, 4));
          expect((e.repsMin, e.reps), (8, 12));
        }
      }
    });

    test('Heavy Duty: rotasi 4, 1 working set, 6–10, hit, 3 hari istirahat (FR-B7)', () {
      final b = buildTemplate('heavy-duty')!;
      expect(b.routines.length, 4);
      expect(b.program.mode, ProgramMode.rotation);
      expect(b.program.minRestDays, 3);
      for (final r in b.routines) {
        expect(r.policy, ProgressionPolicy.hit);
        for (final e in r.exercises) {
          expect(e.sets, 1);
          expect((e.repsMin, e.reps), (6, 10));
        }
      }
    });

    test('id yang tidak dikenal → null', () => expect(buildTemplate('nope'), isNull));
  });

  group('menyusun sesi', () {
    const cfg = ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.double_, sets: 3, reps: 10, repsMin: 6);

    Workout done(String date, double w, List<int> reps) => Workout(date: date, entries: [
          WorkoutEntry(
            exerciseId: '0025',
            target: cfg.copyWith(weight: w),
            sets: [for (final r in reps) SetRow(weight: w, reps: r, done: true)],
          ),
        ]);

    test('sesi pertama: baris mulai dari bawah range, PREV kosong', () {
      final p = planExercise(cfg, const []);
      expect(p.prescription.kind, PrescriptionKind.first);
      expect(p.sets.map((s) => s.reps), [6, 6, 6]);
      expect(p.previous, ['—', '—', '—']);
    });

    test('target yang disimpan tetap membawa batas atas range', () {
      final p = planExercise(cfg, [done('2026-09-20', 60, [8, 8, 7])]);
      expect(p.target.reps, 10);
      expect(p.target.repsMin, 6);
    });

    test('riwayat terlama dulu: yang dibaca sesi terbaru, bukan sesi pertama', () {
      final history = [done('2026-09-10', 50, [10, 10, 10]), done('2026-09-20', 60, [7, 7, 7])];
      final p = planExercise(cfg, history);
      // Sesi terbaru 60 kg × 7 → tahan beban, panjat ke 8. Kalau yang terbaca
      // sesi 10 September, hasilnya "naik ke 52.5 kg" — salah.
      expect(p.sets.first.weight, 60);
      expect(p.sets.first.reps, 8);
      expect(p.previous, ['60 × 7', '60 × 7', '60 × 7']);
    });

    test('warm-up disiapkan di depan dan PREV-nya tidak mencuri set kerja', () {
      const hit = ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.hit, sets: 1, reps: 10, repsMin: 6, warmupSets: 2);
      final history = [
        Workout(date: '2026-09-20', entries: [
          WorkoutEntry(exerciseId: '0025', target: hit.copyWith(weight: 80), sets: const [
            SetRow(weight: 40, reps: 8, done: true, phase: SetPhase.warmup),
            SetRow(weight: 60, reps: 5, done: true, phase: SetPhase.warmup),
            SetRow(weight: 80, reps: 7, done: true),
          ]),
        ]),
      ];
      final p = planExercise(hit, history);
      expect(p.sets.map((s) => s.isWarmup), [true, true, false]);
      expect(p.sets.last.weight, 80);
      expect(p.sets.last.reps, 8);
      expect(p.sets.first.weight, 40);
      expect(p.previous, ['40 × 8', '60 × 5', '80 × 7']);
    });
  });
}
