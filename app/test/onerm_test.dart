import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/onerm.dart';

WorkoutEntry entry(List<(double, int)> rows, {List<bool>? done, int warmups = 0}) {
  return WorkoutEntry(
    exerciseId: 'ex1',
    sets: [
      for (var i = 0; i < rows.length; i++)
        SetRow(
          weight: rows[i].$1,
          reps: rows[i].$2,
          done: done?[i] ?? true,
          phase: i < warmups ? SetPhase.warmup : SetPhase.work,
        ),
    ],
  );
}

void main() {
  group('estimate1RM', () {
    test('Epley: 80 kg × 5 → 93,3', () {
      expect(estimate1RM(80, 5), 93.3);
    });

    test('satu rep bukan estimasi — itu pengukurannya', () {
      expect(estimate1RM(140, 1), 140);
    });

    test('di atas 12 rep menolak menebak, bukan mengarang', () {
      // Di rep setinggi itu ketiga rumus berselisih dua digit, dan angkanya
      // lebih bicara soal daya tahan daripada kekuatan maksimal.
      expect(estimate1RM(60, 13), isNull);
      expect(estimate1RM(60, 12), isNotNull);
    });

    test('null, bukan nol, kalau tidak bisa dihitung', () {
      // Nol akan terbaca sebagai "kekuatanmu nol" — bohong yang berbeda dari
      // "tidak tahu", dan grafik tren akan menukik ke lantai.
      expect(estimate1RM(0, 5), isNull);
      expect(estimate1RM(80, 0), isNull);
      expect(estimate1RM(-10, 5), isNull);
      expect(estimate1RM(double.nan, 5), isNull);
    });

    test('rumus-rumusnya menyebar seiring naiknya rep — alasan repCap ada', () {
      double gapAt(int r) =>
          (estimate1RM(100, r, OneRmFormula.epley)! - estimate1RM(100, r, OneRmFormula.lombardi)!).abs();

      expect(gapAt(2), lessThan(1), reason: 'di rep rendah semuanya sepakat');
      expect(gapAt(12), greaterThan(10), reason: 'di plafon repCap selisihnya sudah dua digit');
      expect(gapAt(12), greaterThan(gapAt(8)));
      expect(gapAt(8), greaterThan(gapAt(4)));
    });
  });

  group('bestSetOf', () {
    test('memilih estimasi tertinggi, bukan beban tertinggi', () {
      // 100×5 (116,7) mengalahkan 110×1 (110) — beban lebih ringan, estimasi
      // lebih tinggi. Itu memang inti dari mengestimasi, bukan bug.
      final best = bestSetOf(entry([(110, 1), (100, 5)]))!;
      expect(best.est, 116.7);
      expect(best.weight, 100);
      expect(best.reps, 5);
    });

    test('warm-up dan set yang tidak dicentang tidak ikut dihitung', () {
      final e = entry([(120, 3), (60, 8), (200, 5)], warmups: 1, done: [true, true, false]);
      final best = bestSetOf(e)!;
      expect(best.weight, 60, reason: 'warm-up 120 dan set 200 yang belum dicentang dilewati');
    });

    test('set tanpa beban tidak menghasilkan estimasi', () {
      expect(bestSetOf(entry([(0, 20)])), isNull);
    });
  });

  group('deret dan rekor', () {
    final history = [
      Workout(date: '2026-09-01', entries: [entry([(100, 5)])]),
      Workout(date: '2026-09-08', entries: [entry([(105, 5)])]),
      Workout(date: '2026-09-15', entries: [entry([(102.5, 5)])]),
    ];

    test('satu titik per sesi, kronologis', () {
      final pts = e1rmSeries(history, 'ex1');
      expect(pts.length, 3);
      expect(pts.map((p) => p.date), ['2026-09-01', '2026-09-08', '2026-09-15']);
    });

    test('sesi tanpa gerakan itu tidak menyisipkan titik kosong', () {
      final mixed = [
        ...history,
        Workout(date: '2026-09-22', entries: [WorkoutEntry(exerciseId: 'lain', sets: const [SetRow(weight: 50, reps: 5, done: true)])]),
      ];
      expect(e1rmSeries(mixed, 'ex1').length, 3);
    });

    test('best1RM membawa serta beban dan rep asalnya', () {
      final best = best1RM(history, 'ex1')!;
      expect(best.weight, 105);
      expect(best.reps, 5);
      expect(best.date, '2026-09-08');
    });

    test('rekor baru dibandingkan dengan riwayat yang belum memuat sesi ini', () {
      final rec = is1RMRecord(history, 'ex1', entry([(110, 5)]))!;
      expect(rec.now.weight, 110);
      expect(rec.previous, best1RM(history, 'ex1')!.est);
    });

    test('bukan rekor kalau tidak melewati yang lama', () {
      expect(is1RMRecord(history, 'ex1', entry([(100, 5)])), isNull);
    });

    test('rekor pertama tidak punya pembanding', () {
      final rec = is1RMRecord(const [], 'ex1', entry([(60, 5)]))!;
      expect(rec.previous, isNull);
    });
  });
}
