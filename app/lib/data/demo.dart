/// Data contoh untuk menjalankan layar sebelum store Supabase tersambung.
///
/// Sengaja satu file terpisah dan tidak dipanggil dari mana pun kecuali titik
/// masuk layar: saat store asli masuk, file ini dihapus utuh, bukan dicabut
/// sedikit-sedikit dari dalam widget.
library;

import 'package:flutter/material.dart';

import '../core/charts.dart';
import '../domain/models.dart';
import '../features/session/session_screen.dart';

const demoRoutineName = 'Pull';

ExerciseConfig _cfg(String id, {required double weight, required int reps, ProgressionPolicy? policy, int sets = 3, int? repsMin}) {
  return ExerciseConfig(
    exerciseId: id,
    policy: policy,
    sets: sets,
    reps: reps,
    repsMin: repsMin,
    weight: weight,
    heavyBodyPart: id == '0027',
  );
}

/// Riwayat dua sesi terakhir untuk Barbell Row, semuanya bersih — cukup untuk
/// membuat mesin progresi mengeluarkan "naik 5 kg" yang nyata, bukan teks palsu.
final demoHistory = <Workout>[
  // Id gerakan di sini adalah id katalog yang sebenarnya (assets/data/
  // exercises.json), bukan slug buatan: peta otot dan radar mencari otot target
  // lewat id ini, dan slug yang tidak cocok membuat keduanya kosong.
  ..._session('2026-09-05', [('0027', 70, 8), ('0198', 62.5, 10), ('0377', 22.5, 15), ('0165', 16, 12)]),
  ..._session('2026-09-08', [('0025', 80, 8), ('0334', 12, 15), ('0241', 30, 12), ('0095', 80, 12)]),
  ..._session('2026-09-11', [('0102', 100, 8), ('0085', 90, 10), ('1372', 60, 15)]),
  ..._session('2026-09-13', [('0027', 70, 8), ('0198', 65, 10), ('0377', 22.5, 15), ('0165', 16, 12)]),
];

/// Satu sesi: daftar (id gerakan, beban, rep) × 3 set kerja, semuanya tercentang.
List<Workout> _session(String date, List<(String, double, int)> rows) => [
      Workout(date: date, entries: [
        for (final (id, w, r) in rows)
          WorkoutEntry(
            exerciseId: id,
            target: _cfg(id, weight: w, reps: r),
            sets: [
              SetRow(weight: w, reps: r, done: true),
              SetRow(weight: w, reps: r, done: true),
              SetRow(weight: w, reps: r, done: true),
            ],
          ),
      ]),
    ];

List<SessionExercise> demoExercises() => [
      SessionExercise(
        name: 'Barbell Row',
        icon: Icons.rowing,
        config: _cfg('0027', weight: 72.5, reps: 8, policy: ProgressionPolicy.double_, repsMin: 6),
        expanded: true,
        sets: [
          const SetRow(weight: 40, reps: 10, done: true, phase: SetPhase.warmup),
          const SetRow(weight: 72.5, reps: 8, done: true),
          const SetRow(weight: 72.5, reps: 8, done: true),
          const SetRow(weight: 72.5, reps: 8),
        ],
        previous: ['—', '70 × 8', '70 × 8', '70 × 7'],
      ),
      SessionExercise(
        name: 'Lat Pulldown',
        icon: Icons.fitness_center,
        config: _cfg('0198', weight: 65, reps: 10),
        sets: [
          const SetRow(weight: 65, reps: 10),
          const SetRow(weight: 65, reps: 10),
          const SetRow(weight: 65, reps: 10),
        ],
        previous: ['62.5 × 10', '62.5 × 10', '62.5 × 9'],
      ),
      SessionExercise(
        name: 'Face Pull',
        icon: Icons.sports_martial_arts,
        config: _cfg('0377', weight: 22.5, reps: 15),
        sets: [
          const SetRow(weight: 22.5, reps: 15),
          const SetRow(weight: 22.5, reps: 15),
          const SetRow(weight: 22.5, reps: 15),
        ],
        previous: ['22.5 × 15', '22.5 × 15', '22.5 × 14'],
      ),
    ];

// ── Data contoh untuk layar Workout, Stats, dan History ─────────────────────

/// Jumlah gerakan di katalog. Dipakai di kartu library sebelum aset selesai
/// dimuat, supaya angkanya tidak melompat dari 0.
const demoExerciseCount = 1324;

class DemoRoutine {
  DemoRoutine(this.name, this.exercises, this.sets, {this.isNext = false});

  /// Bisa diubah: layar Workout menamai ulang, menggandakan, dan menghapus
  /// rutinitas langsung di daftar ini sampai store Supabase masuk.
  String name;
  int exercises;
  int sets;
  bool isNext;

  DemoRoutine copy(String newName) => DemoRoutine(newName, exercises, sets);
}

List<DemoRoutine> demoRoutines() => [
      DemoRoutine('Push', 5, 18),
      DemoRoutine('Pull', 6, 20, isNext: true),
      DemoRoutine('Legs', 5, 17),
    ];

/// Gerakan yang bisa disunting di Routine Editor.
class EditableExercise {
  EditableExercise({
    required this.name,
    required this.muscle,
    required this.gear,
    required this.config,
    required this.increment,
    required this.restSeconds,
    List<String>? intensifiers,
  }) : intensifiers = intensifiers ?? [];

  final String name;
  final String muscle;
  final String gear;
  ExerciseConfig config;
  final double increment;
  final int restSeconds;
  final List<String> intensifiers;
}

List<EditableExercise> demoEditableExercises() => [
      EditableExercise(
        name: 'Barbell Row',
        muscle: 'Back',
        gear: 'Barbell',
        increment: 2.5,
        restSeconds: 120,
        intensifiers: ['Drop set'],
        config: const ExerciseConfig(
          exerciseId: '0027',
          policy: ProgressionPolicy.double_,
          sets: 3,
          reps: 12,
          repsMin: 8,
          weight: 72.5,
        ),
      ),
      EditableExercise(
        name: 'Lat Pulldown',
        muscle: 'Back',
        gear: 'Cable',
        increment: 2.5,
        restSeconds: 90,
        config: const ExerciseConfig(
          exerciseId: '0198',
          policy: ProgressionPolicy.double_,
          sets: 3,
          reps: 12,
          repsMin: 8,
          weight: 65,
        ),
      ),
      EditableExercise(
        name: 'Face Pull',
        muscle: 'Shoulders',
        gear: 'Cable',
        increment: 2.5,
        restSeconds: 60,
        config: const ExerciseConfig(
          exerciseId: '0377',
          policy: ProgressionPolicy.double_,
          sets: 3,
          reps: 15,
          repsMin: 12,
          weight: 22.5,
        ),
      ),
      EditableExercise(
        name: 'Hammer Curl',
        muscle: 'Arms',
        gear: 'Dumbbell',
        increment: 2.5,
        restSeconds: 60,
        config: const ExerciseConfig(
          exerciseId: '0165',
          policy: ProgressionPolicy.linear,
          sets: 3,
          reps: 12,
          repsMin: 8,
          weight: 16,
        ),
      ),
      EditableExercise(
        name: 'Rear Delt Fly',
        muscle: 'Shoulders',
        gear: 'Dumbbell',
        increment: 1.25,
        restSeconds: 60,
        config: const ExerciseConfig(
          exerciseId: '2292',
          policy: ProgressionPolicy.linear,
          sets: 3,
          reps: 15,
          repsMin: 12,
          weight: 10,
        ),
      ),
      EditableExercise(
        name: 'Barbell Shrug',
        muscle: 'Back',
        gear: 'Barbell',
        increment: 5,
        restSeconds: 90,
        config: const ExerciseConfig(
          exerciseId: '0095',
          policy: ProgressionPolicy.linear,
          sets: 3,
          reps: 12,
          repsMin: 8,
          weight: 80,
          heavyBodyPart: true,
        ),
      ),
    ];

const demoRegionAxes = <RadarAxis>[
  RadarAxis(label: 'Chest', value: 0.86, previous: 0.68),
  RadarAxis(label: 'Core', value: 0.58, previous: 0.48),
  RadarAxis(label: 'Arms', value: 0.72, previous: 0.61),
  RadarAxis(label: 'Legs', value: 0.92, previous: 0.74),
  RadarAxis(label: 'Shoulders', value: 0.64, previous: 0.55),
  RadarAxis(label: 'Back', value: 0.97, previous: 0.79),
];

/// Tinggi batang e1RM, 12 minggu — diambil dari artboard Pen `10 Stats`
/// (node "Bar 1".."Bar 12"), jadi bentuk grafiknya sama persis.
///
/// Ini **tinggi batang**, bukan kilogram. Angka besar di atas grafik dibaca
/// dari [demoE1rmPeak] — memakai nilai terakhir daftar ini akan menampilkan
/// "104 kg" yang tidak berarti apa-apa.
const demoE1rm = <double>[44, 54, 54, 63, 57, 72, 75, 72, 85, 88, 85, 104];

/// e1RM sekarang seperti tertulis di artboard.
const demoE1rmPeak = 90.6;

/// Tinggi batang berat badan dari artboard Pen yang sama.
const demoBodyweight = <double>[74, 72, 68, 65, 61, 60, 56, 55, 53, 52];

const demoWeeklySets = <double>[52, 58, 61, 55, 64, 68, 66, 71];

/// Berapa hari sejak kelompok otot itu terakhir dilatih.
const demoRecovery = <(String, int)>[
  ('Chest', 2),
  ('Back', 0),
  ('Shoulders', 0),
  ('Arms', 2),
  ('Legs', 3),
  ('Calves', 9),
];

class DemoMovement {
  const DemoMovement(this.name, this.value, this.delta);
  final String name;
  final String value;
  final double delta;
}

const demoMovements = <DemoMovement>[
  DemoMovement('Squat', '142.5', 5),
  DemoMovement('Bench Press', '102.4', 2.5),
  DemoMovement('Deadlift', '178.0', 0),
  DemoMovement('Overhead Press', '62.1', -1.5),
];

class DemoSession {
  const DemoSession({
    required this.day,
    required this.weekday,
    required this.routine,
    required this.duration,
    required this.volume,
    required this.sets,
    this.hasPr = false,
  });

  final String day;
  final String weekday;
  final String routine;
  final String duration;
  final String volume;
  final int sets;
  final bool hasPr;
}

const demoSessions = <DemoSession>[
  DemoSession(day: '16', weekday: 'Tue', routine: 'Pull', duration: '58:12', volume: '12.4 t', sets: 20, hasPr: true),
  DemoSession(day: '13', weekday: 'Sat', routine: 'Legs', duration: '1:04:30', volume: '15.1 t', sets: 18),
  DemoSession(day: '11', weekday: 'Thu', routine: 'Push', duration: '52:47', volume: '11.2 t', sets: 18, hasPr: true),
  DemoSession(day: '08', weekday: 'Mon', routine: 'Legs', duration: '1:01:12', volume: '14.6 t', sets: 17),
  DemoSession(day: '05', weekday: 'Fri', routine: 'Pull', duration: '55:03', volume: '12.0 t', sets: 20),
];

const demoSessionsThisYear = 128;

/// Level 0..4 per hari untuk heatmap aktivitas — 24 minggu × 7 hari, dibaca
/// langsung dari artboard Pen `11 History` (node "Week 1".."Week 24").
const demoActivityLevels = <int>[
  0, 1, 3, 4, 0, 2, 3, 3, 4, 0, 2, 4, 0, 1, 1, 3, 4, 0, 2, 3, 4, 4, 0, 2, 4, 0, 1, 3, 3, 4, 0, 2, 3, 4, 0, 0, 2, 4, 0, 1, 3, 4, 4, 0, 2, 3, 4, 0, 2, 2, 4, 0, 1, 3, 4, 0, 0, 2, 3, 4, 0, 2, 4, 4, 0, 1, 3, 4, 0, 2, 2, 3, 4, 0, 2, 4, 0, 0, 1, 3, 4, 0, 2, 3, 3, 4, 0, 2, 4, 0, 1, 1, 3, 4, 0, 2, 3, 4, 4, 0, 2, 4, 0, 1, 3, 3, 4, 0, 2, 3, 4, 0, 0, 2, 4, 0, 1, 3, 4, 4, 0, 2, 3, 4, 0, 2, 2, 4, 0, 1, 3, 4, 0, 0, 2, 3, 4, 0, 2, 4, 4, 0, 1, 3, 4, 0, 2, 2, 3, 4, 0, 2, 4, 0, 0, 1, 3, 4, 0, 2, 3, 3, 4, 0, 2, 4, 0, 1,
];
