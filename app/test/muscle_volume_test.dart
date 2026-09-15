import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/body_map_data.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/muscle_volume.dart';

/// Katalog kecil buatan, supaya test tidak bergantung pada aset 870 KB.
ExerciseCatalog catalogOf(List<Exercise> items) => ExerciseCatalog.forTest(items);

const bench = Exercise(
  id: 'bench',
  name: 'Bench press',
  bodyPart: 'chest',
  equipment: 'barbell',
  target: 'pectorals',
  secondary: ['triceps', 'shoulders'],
);

const pushup = Exercise(
  id: 'pushup',
  name: 'Push-up',
  bodyPart: 'chest',
  equipment: 'body weight',
  target: 'pectorals',
  secondary: [],
);

Workout session(String date, String exerciseId, List<SetRow> sets) =>
    Workout(date: date, entries: [WorkoutEntry(exerciseId: exerciseId, sets: sets)]);

void main() {
  group('pemetaan nama otot', () {
    test('kosakata tg dan sm menunjuk kelompok yang sama', () {
      // `tg` memakai istilah anatomi, `sm` istilah sehari-hari. Kalau keduanya
      // tidak dipetakan, separuh volume gerakan majemuk hilang diam-diam.
      expect(muscleGroupFor('pectorals'), MuscleGroup.chest);
      expect(muscleGroupFor('chest'), MuscleGroup.chest);
      expect(muscleGroupFor('delts'), MuscleGroup.shoulders);
      expect(muscleGroupFor('shoulders'), MuscleGroup.shoulders);
      expect(muscleGroupFor('quadriceps'), MuscleGroup.quads);
    });

    test('nama yang tidak dikenal jadi null, bukan dilempar ke kelompok asal', () {
      expect(muscleGroupFor('cardiovascular system'), isNull);
      expect(muscleGroupFor(''), isNull);
    });
  });

  group('volumeByMuscle', () {
    test('beban × rep untuk set kerja yang tercentang', () {
      final v = volumeByMuscle(
        [session('2026-09-01', 'pushup', const [SetRow(weight: 50, reps: 10, done: true)])],
        catalogOf([pushup]),
      );
      expect(v[MuscleGroup.chest], 500);
    });

    test('warm-up dan set yang belum dicentang tidak menghasilkan volume', () {
      final v = volumeByMuscle(
        [
          session('2026-09-01', 'pushup', const [
            SetRow(weight: 50, reps: 10, done: true, phase: SetPhase.warmup),
            SetRow(weight: 50, reps: 10),
          ])
        ],
        catalogOf([pushup]),
      );
      expect(v, isEmpty);
    });

    test('set bodyweight dihitung repnya, bukan nol', () {
      // Push-up tanpa beban tetap melatih dada. Volume nol akan menghapusnya
      // dari peta seolah-olah tidak pernah dikerjakan.
      final v = volumeByMuscle(
        [session('2026-09-01', 'pushup', const [SetRow(weight: 0, reps: 20, done: true)])],
        catalogOf([pushup]),
      );
      expect(v[MuscleGroup.chest], 20);
    });

    test('otot pendukung ikut terhitung dengan bobot lebih kecil', () {
      final v = volumeByMuscle(
        [session('2026-09-01', 'bench', const [SetRow(weight: 100, reps: 5, done: true)])],
        catalogOf([bench]),
      );
      expect(v[MuscleGroup.chest], 500);
      expect(v[MuscleGroup.triceps], closeTo(500 * secondaryWeight, 0.001));
      expect(v[MuscleGroup.shoulders], closeTo(500 * secondaryWeight, 0.001));
    });

    test('gerakan yang tidak ada di katalog dilewati, bukan bikin crash', () {
      final v = volumeByMuscle(
        [session('2026-09-01', 'tidak-ada', const [SetRow(weight: 50, reps: 10, done: true)])],
        catalogOf([pushup]),
      );
      expect(v, isEmpty);
    });

    test('jendela tanggal menyaring sesi di luar rentang', () {
      final history = [
        session('2026-09-01', 'pushup', const [SetRow(weight: 10, reps: 10, done: true)]),
        session('2026-09-20', 'pushup', const [SetRow(weight: 90, reps: 10, done: true)]),
      ];
      final v = volumeByMuscle(history, catalogOf([pushup]),
          since: DateTime(2026, 9, 15), until: DateTime(2026, 9, 30));
      expect(v[MuscleGroup.chest], 900);
    });
  });

  group('muscleShare', () {
    test('dinormalkan ke otot tertinggi, bukan ke total', () {
      final share = muscleShare({MuscleGroup.chest: 100, MuscleGroup.biceps: 25});
      expect(share[MuscleGroup.chest], 1.0);
      expect(share[MuscleGroup.biceps], 0.25);
    });

    test('volume kosong menghasilkan share kosong', () {
      expect(muscleShare(const {}), isEmpty);
    });
  });

  group('heatLevelFor', () {
    test('tanpa volume tetap dapat tingkat 0, bukan dihilangkan', () {
      // Bagian tubuh yang tidak dilatih justru informasi yang dicari orang.
      expect(heatLevelFor(0), 0);
    });

    test('naik bertingkat sampai 4', () {
      expect(heatLevelFor(0.1), 1);
      expect(heatLevelFor(0.3), 2);
      expect(heatLevelFor(0.6), 3);
      expect(heatLevelFor(1.0), 4);
    });
  });

  group('regionShare', () {
    test('dua periode dibagi maksimum gabungan supaya bisa dibandingkan', () {
      final now = {MuscleGroup.chest: 100.0};
      final before = {MuscleGroup.chest: 50.0};
      final r = regionShare(now, before);
      expect(r.current['Chest'], 1.0);
      expect(r.previous['Chest'], 0.5);
    });

    test('tanpa data semua sumbu nol, bukan NaN', () {
      final r = regionShare(const {}, const {});
      expect(r.current.values.every((v) => v == 0), isTrue);
      expect(r.previous.values.every((v) => v == 0), isTrue);
    });
  });

  group('tabel peta tubuh', () {
    test('tiap bentuk punya kelompok atau ditandai siluet', () {
      expect(bodyHeatmapGroups.length, bodyHeatmapPaths.length);
      for (var i = 0; i < bodyHeatmapGroups.length; i++) {
        final g = bodyHeatmapGroups[i];
        final silhouette = bodyHeatmapLevels[i] < 0;
        expect(g < 0, silhouette,
            reason: 'bentuk $i: kelompok dan siluet harus sepakat');
        if (g >= 0) expect(g, lessThan(MuscleGroup.values.length));
      }
    });

    test('hamstring memang tidak punya bentuk di artwork Pen', () {
      // Didokumentasikan sebagai batasan, bukan kelalaian: kaki belakang di
      // artboard hanya siluet. Test ini akan gagal kalau artwork diganti,
      // yang memang saat untuk meninjau ulang banner "least volume".
      final hamstring = MuscleGroup.values.indexOf(MuscleGroup.hamstrings);
      expect(bodyHeatmapGroups.contains(hamstring), isFalse);
    });
  });
}
