import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/progression.dart';

/// Test untuk engine progresi. Aturan CONTRIBUTING openGym yang ikut dibawa:
/// apa pun yang memutuskan beban berikutnya adalah fungsi murni yang diuji.

ExerciseConfig cfg({
  ProgressionPolicy? policy,
  int sets = 3,
  int reps = 8,
  int? repsMin,
  int? repsMax,
  double weight = 60,
  double? increment,
  bool heavy = false,
  LogMode mode = LogMode.reps,
  int seconds = 0,
  double? deloadFactor,
}) {
  return ExerciseConfig(
    exerciseId: 'ex1',
    policy: policy,
    mode: mode,
    sets: sets,
    reps: reps,
    repsMin: repsMin,
    repsMax: repsMax,
    weight: weight,
    seconds: seconds,
    increment: increment,
    deloadFactor: deloadFactor,
    heavyBodyPart: heavy,
  );
}

/// Satu sesi: daftar (beban, rep) untuk set kerja, semuanya tercentang kecuali
/// disebut lain.
Workout session(String date, List<(double, int)> rows, {ExerciseConfig? target, List<bool>? done}) {
  return Workout(date: date, entries: [
    WorkoutEntry(
      exerciseId: 'ex1',
      target: target,
      sets: [
        for (var i = 0; i < rows.length; i++)
          SetRow(weight: rows[i].$1, reps: rows[i].$2, done: done?[i] ?? true),
      ],
    ),
  ]);
}

void main() {
  group('increment default (FR-E7)', () {
    test('2,5 kg tubuh atas, 5 kg tubuh bawah', () {
      expect(defaultIncrementFor(heavyBodyPart: false), 2.5);
      expect(defaultIncrementFor(heavyBodyPart: true), 5);
    });

    test('lb memakai 5 dan 10, bukan hasil konversi', () {
      expect(defaultIncrementFor(heavyBodyPart: false, unit: 'lb'), 5);
      expect(defaultIncrementFor(heavyBodyPart: true, unit: 'lb'), 10);
    });

    test('override per gerakan menang', () {
      expect(weightIncrement(cfg(increment: 1), 'kg'), 1);
    });
  });

  group('addStep', () {
    test('beban di grid di-snap ke grid', () {
      expect(addStep(60, 2.5, 2.5), 62.5);
    });

    test('beban di luar grid hanya ditambah, tidak dipaksa ke grid', () {
      // Sled 397 kg (berat alatnya sendiri ikut) dengan step 10 → 407, bukan 400.
      expect(addStep(397, 10, 10), 407);
    });

    test('tidak pernah negatif', () {
      expect(addStep(2.5, -10, 2.5), 0);
    });
  });

  test('snapWeight membulatkan ke kelipatan yang bisa dipasang', () {
    expect(snapWeight(61.3, 1.25), 61.25);
    expect(snapWeight(61, 2.5), 60);
  });

  group('deloadTo', () {
    test('mundur ke faktor lalu di-snap', () {
      expect(deloadTo(100, 2.5), 90);
    });

    test('kalau pembulatan tidak menurunkan beban, mundur satu step', () {
      expect(deloadTo(2.5, 2.5), 2.5);
      expect(deloadTo(5, 2.5), 2.5);
    });
  });

  group('readSession — membaca sesi dengan jujur', () {
    test('set yang tidak dicentang dibaca nol, bukan diabaikan (FR-E3)', () {
      final w = session('2026-09-01', [(60, 8), (60, 8), (60, 8)], done: [true, true, false]);
      final r = readSession(w.entries.first, date: w.date, fallback: cfg());
      expect(r.reps, [8, 8, 0]);
      expect(r.ok, isFalse);
    });

    test('warm-up tidak ikut dinilai (FR-D6)', () {
      final w = Workout(date: '2026-09-01', entries: [
        WorkoutEntry(exerciseId: 'ex1', target: cfg(), sets: const [
          SetRow(weight: 40, reps: 10, done: true, phase: SetPhase.warmup),
          SetRow(weight: 60, reps: 8, done: true),
          SetRow(weight: 60, reps: 8, done: true),
          SetRow(weight: 60, reps: 8, done: true),
        ]),
      ]);
      final r = readSession(w.entries.first, date: w.date, fallback: cfg());
      expect(r.reps, [8, 8, 8]);
      expect(r.weight, 60, reason: 'warm-up 40 kg tidak boleh jadi beban sesi');
      expect(r.ok, isTrue);
    });

    test('set kurang dari rencana bukan sesi yang berhasil', () {
      final w = session('2026-09-01', [(60, 8), (60, 8)], target: cfg(sets: 3));
      final r = readSession(w.entries.first, date: w.date, fallback: cfg());
      expect(r.ok, isFalse, reason: '2 dari 3 set — belum cukup');
    });
  });

  group('linear', () {
    test('semua rep tercapai → naik satu increment', () {
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(60, 8), (60, 8), (60, 8)], target: cfg())],
        cfg: cfg(policy: ProgressionPolicy.linear),
      );
      expect(p.kind, PrescriptionKind.up);
      expect(p.weight, 62.5);
      expect(p.why, contains('2.5'));
    });

    test('rep kurang → beban tetap, bukan naik (FR-E3)', () {
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(60, 8), (60, 8), (60, 6)], target: cfg())],
        cfg: cfg(policy: ProgressionPolicy.linear),
      );
      expect(p.kind, PrescriptionKind.hold);
      expect(p.weight, 60);
    });

    test('set tidak dicentang penuh juga tidak menaikkan beban', () {
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(60, 8), (60, 8), (60, 8)], target: cfg(), done: [true, true, false])],
        cfg: cfg(policy: ProgressionPolicy.linear),
      );
      expect(p.kind, PrescriptionKind.hold);
    });

    test('gagal 3 sesi berturut → deload 90% (FR-E4)', () {
      final w = [
        session('2026-09-01', [(60, 6), (60, 6), (60, 6)], target: cfg()),
        session('2026-09-03', [(60, 6), (60, 6), (60, 6)], target: cfg()),
        session('2026-09-05', [(60, 6), (60, 6), (60, 6)], target: cfg()),
      ];
      final p = nextPrescription(workouts: w, cfg: cfg(policy: ProgressionPolicy.linear));
      expect(p.kind, PrescriptionKind.deload);
      expect(p.weight, 55, reason: '60 × 0,9 = 54, di-snap ke grid 2,5 → 55');
    });

    test('beban berubah mengakhiri rentetan stall', () {
      // Gagal di 60, lalu turun sendiri ke 55 dan gagal lagi: dua kegagalan itu
      // tidak boleh dijumlahkan jadi alasan deload dari 55.
      final w = [
        session('2026-09-01', [(60, 6), (60, 6), (60, 6)], target: cfg()),
        session('2026-09-03', [(60, 6), (60, 6), (60, 6)], target: cfg()),
        session('2026-09-05', [(55, 6), (55, 6), (55, 6)], target: cfg()),
      ];
      final p = nextPrescription(workouts: w, cfg: cfg(policy: ProgressionPolicy.linear));
      expect(p.kind, PrescriptionKind.hold);
    });
  });

  group('greyskull', () {
    test('set terakhir dua kali target → lompatan ganda', () {
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(60, 8), (60, 8), (60, 16)], target: cfg(reps: 8))],
        cfg: cfg(policy: ProgressionPolicy.greyskull),
      );
      expect(p.kind, PrescriptionKind.up);
      expect(p.weight, 65, reason: '2 × 2,5 kg');
    });

    test('gagal sekali langsung deload', () {
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(60, 8), (60, 8), (60, 5)], target: cfg())],
        cfg: cfg(policy: ProgressionPolicy.greyskull),
      );
      expect(p.kind, PrescriptionKind.deload);
    });
  });

  group('double progression', () {
    test('puncak range di semua set → naik, rep balik ke bawah', () {
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(60, 12), (60, 12), (60, 12)], target: cfg(reps: 12, repsMin: 8))],
        cfg: cfg(policy: ProgressionPolicy.double_, reps: 12, repsMin: 8),
      );
      expect(p.kind, PrescriptionKind.up);
      expect(p.weight, 62.5);
      expect(p.reps, 8);
    });

    test('belum di puncak → beban sama, target rep naik satu', () {
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(60, 9), (60, 9), (60, 9)], target: cfg(reps: 12, repsMin: 8))],
        cfg: cfg(policy: ProgressionPolicy.double_, reps: 12, repsMin: 8),
      );
      expect(p.kind, PrescriptionKind.hold);
      expect(p.weight, 60);
      expect(p.reps, 10);
    });

    test('mengalahkan rekor rep pada beban yang sama bukan stall', () {
      // Tanpa pengecualian ini, rep range lebar akan selalu berakhir deload
      // meski jelas ada kemajuan 8 → 9 → 10.
      final t = cfg(reps: 12, repsMin: 8);
      final w = [
        session('2026-09-01', [(60, 8), (60, 8), (60, 8)], target: t),
        session('2026-09-03', [(60, 9), (60, 9), (60, 9)], target: t),
        session('2026-09-05', [(60, 10), (60, 10), (60, 10)], target: t),
      ];
      final p = nextPrescription(workouts: w, cfg: cfg(policy: ProgressionPolicy.double_, reps: 12, repsMin: 8));
      expect(p.kind, PrescriptionKind.hold);
      expect(p.reps, 11);
    });

    test('benar-benar mandek tiga sesi → deload', () {
      final t = cfg(reps: 12, repsMin: 8);
      final w = [
        session('2026-09-01', [(60, 8), (60, 8), (60, 8)], target: t),
        session('2026-09-03', [(60, 8), (60, 8), (60, 8)], target: t),
        session('2026-09-05', [(60, 8), (60, 8), (60, 8)], target: t),
      ];
      final p = nextPrescription(workouts: w, cfg: cfg(policy: ProgressionPolicy.double_, reps: 12, repsMin: 8));
      expect(p.kind, PrescriptionKind.deload);
      expect(p.weight, 55);
    });
  });

  group('hit — Heavy Duty (FR-E6)', () {
    ExerciseConfig hit({double weight = 60, int reps = 10, int repsMin = 6, double? increment}) =>
        cfg(policy: ProgressionPolicy.hit, sets: 1, reps: reps, repsMin: repsMin, weight: weight, increment: increment);

    test('rep ≥ batas atas → beban naik, target rep kembali ke batas bawah', () {
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(60, 10)], target: hit())],
        cfg: hit(),
      );
      expect(p.kind, PrescriptionKind.up);
      expect(p.weight, 62.5);
      expect(p.reps, 6);
    });

    test('rep di dalam range → beban tetap, target rep + 1', () {
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(60, 7)], target: hit())],
        cfg: hit(),
      );
      expect(p.kind, PrescriptionKind.hold);
      expect(p.weight, 60);
      expect(p.reps, 8);
    });

    test('rep < batas bawah sekali → belum deload', () {
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(60, 4)], target: hit())],
        cfg: hit(),
      );
      expect(p.kind, PrescriptionKind.hold);
      expect(p.weight, 60);
    });

    test('rep < batas bawah dua sesi berturut → deload + saran tambah istirahat', () {
      final w = [
        session('2026-09-01', [(60, 5)], target: hit()),
        session('2026-09-05', [(60, 4)], target: hit()),
      ];
      final p = nextPrescription(workouts: w, cfg: hit());
      expect(p.kind, PrescriptionKind.deload);
      expect(p.weight, 55);
      expect(p.why, contains('rest day'));
    });

    test('hanya membaca working set pertama — set tambahan diabaikan', () {
      // Set kedua yang lemah tidak boleh membatalkan kenaikan: metode HIT
      // menilai satu set ke failure, sisanya bukan bagian dari penilaian.
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(60, 10), (60, 3)], target: hit())],
        cfg: hit(),
      );
      expect(p.kind, PrescriptionKind.up);
    });

    test('warm-up diabaikan, working set pertama yang dibaca', () {
      final w = Workout(date: '2026-09-01', entries: [
        WorkoutEntry(exerciseId: 'ex1', target: hit(), sets: const [
          SetRow(weight: 40, reps: 12, done: true, phase: SetPhase.warmup),
          SetRow(weight: 60, reps: 7, done: true),
        ]),
      ]);
      final p = nextPrescription(workouts: [w], cfg: hit());
      expect(p.kind, PrescriptionKind.hold);
      expect(p.reps, 8, reason: '7 rep + 1, bukan dihitung dari warm-up 12 rep');
    });
  });

  group('bodyweight (FR-E8)', () {
    test('semua rep tercapai → +1 rep, bukan +2,5 kg', () {
      final t = cfg(weight: 0, reps: 12);
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(0, 12), (0, 12), (0, 12)], target: t)],
        cfg: cfg(policy: ProgressionPolicy.linear, weight: 0, reps: 12),
      );
      expect(p.kind, PrescriptionKind.up);
      expect(p.weight, 0);
      expect(p.reps, 13);
    });

    test('di plafon rep → tambah satu set, rep kembali ke bawah', () {
      final t = cfg(weight: 0, reps: 20, repsMax: 20);
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(0, 20), (0, 20), (0, 20)], target: t)],
        cfg: cfg(policy: ProgressionPolicy.linear, weight: 0, reps: 20, repsMax: 20),
      );
      expect(p.kind, PrescriptionKind.up);
      expect(p.sets, 4);
    });
  });

  group('time (plank, hang)', () {
    test('semua set tertahan penuh → target naik 5 detik', () {
      final t = cfg(mode: LogMode.time, seconds: 60, weight: 0);
      final w = Workout(date: '2026-09-01', entries: [
        WorkoutEntry(exerciseId: 'ex1', target: t, sets: const [
          SetRow(seconds: 60, done: true),
          SetRow(seconds: 60, done: true),
          SetRow(seconds: 60, done: true),
        ]),
      ]);
      final p = nextPrescription(
        workouts: [w],
        cfg: cfg(policy: ProgressionPolicy.time, mode: LogMode.time, seconds: 60, weight: 0),
      );
      expect(p.kind, PrescriptionKind.up);
      expect(p.seconds, 65);
    });
  });

  group('kasus tepi', () {
    test('belum ada riwayat → first, tanpa angka yang dikarang', () {
      final p = nextPrescription(workouts: const [], cfg: cfg(policy: ProgressionPolicy.linear));
      expect(p.kind, PrescriptionKind.first);
      expect(p.weight, isNull);
    });

    test('policy off tidak menyentuh apa pun', () {
      final p = nextPrescription(
        workouts: [session('2026-09-01', [(60, 8), (60, 8), (60, 8)], target: cfg())],
        cfg: cfg(policy: ProgressionPolicy.off),
      );
      expect(p.kind, PrescriptionKind.off);
      expect(p.weight, isNull);
    });

    test('sesi dari rutinitas deload tidak jadi dasar target (FR-B10)', () {
      final w = Workout(date: '2026-09-01', entries: [
        WorkoutEntry(
          exerciseId: 'ex1',
          target: cfg(),
          excluded: true,
          sets: const [SetRow(weight: 40, reps: 8, done: true)],
        ),
      ]);
      final p = nextPrescription(workouts: [w], cfg: cfg(policy: ProgressionPolicy.linear));
      expect(p.kind, PrescriptionKind.first, reason: 'sesi excluded dilewati seluruhnya');
    });

    test('setiap target punya alasan (FR-E5)', () {
      for (final policy in [
        ProgressionPolicy.linear,
        ProgressionPolicy.greyskull,
        ProgressionPolicy.double_,
        ProgressionPolicy.hit,
      ]) {
        final p = nextPrescription(
          workouts: [session('2026-09-01', [(60, 8), (60, 8), (60, 8)], target: cfg())],
          cfg: cfg(policy: policy, repsMin: 6),
        );
        expect(p.why, isNotEmpty, reason: '$policy tidak memberi alasan');
      }
    });
  });

  group('applyPrescription', () {
    test('tidak menimpa set yang sudah dicentang maupun warm-up', () {
      final sets = const [
        SetRow(weight: 40, reps: 10, done: true, phase: SetPhase.warmup),
        SetRow(weight: 60, reps: 8, done: true),
        SetRow(weight: 60, reps: 8),
      ];
      final out = applyPrescription(
        sets,
        const Prescription(
          policy: ProgressionPolicy.linear,
          kind: PrescriptionKind.up,
          weight: 62.5,
          reps: 8,
          why: 'naik',
        ),
      );
      expect(out[0].weight, 40, reason: 'warm-up tidak disentuh');
      expect(out[1].weight, 60, reason: 'set yang sudah dicatat tidak ditulis ulang');
      expect(out[2].weight, 62.5);
    });
  });
}
