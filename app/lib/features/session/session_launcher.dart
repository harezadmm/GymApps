/// Membuka sesi dari rutinitas sungguhan, atau sesi bebas yang kosong.
///
/// Satu tempat untuk ini, dipakai Home, tab Workout, dan layar lain: dulu
/// setiap layar membuka sesi dengan daftar gerakan contoh yang sama, sehingga
/// sesi "Push" berisi Barbell Row.
library;

import 'package:flutter/material.dart';

import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/session_plan.dart';
import '../library/library_screen.dart';
import 'session_screen.dart';

/// Susun satu gerakan untuk dibuka di layar sesi.
SessionExercise buildSessionExercise(
  ExerciseCatalog catalog,
  ExerciseConfig cfg,
  List<Workout> history, {
  ProgressionPolicy? routineDefault,
  bool expanded = false,
}) {
  final plan = planExercise(cfg, history, routineDefault: routineDefault);
  final ex = catalog.byId(cfg.exerciseId);
  return SessionExercise(
    name: catalog.nameOf(cfg.exerciseId),
    icon: ex?.icon ?? Icons.fitness_center,
    config: plan.target,
    sets: plan.sets,
    previous: plan.previous,
    prescription: plan.prescription,
    restDuration: Duration(seconds: cfg.restSeconds ?? 90),
    expanded: expanded,
  );
}

/// Konfigurasi untuk gerakan yang ditambahkan di luar rutinitas.
///
/// Kalau gerakan itu pernah dicatat, target terakhirnya yang dipakai — sesi
/// bebas tidak boleh mulai dengan meminta orang mengetik ulang minggu lalu.
ExerciseConfig configForAdded(String exerciseId, List<Workout> history) {
  final last = lastEntryFor(history, exerciseId)?.target;
  if (last != null) return last;
  return ExerciseConfig(exerciseId: exerciseId, sets: 3, reps: 12, repsMin: 8, policy: ProgressionPolicy.double_);
}

/// Buka layar sesi untuk satu rutinitas.
Future<void> openRoutineSession(BuildContext context, Routine routine) async {
  final store = WorkoutScope.read(context);
  final navigator = Navigator.of(context);
  final catalog = await ExerciseCatalog.load();
  final history = store.chronological;
  final exercises = [
    for (final (i, cfg) in routine.exercises.indexed)
      buildSessionExercise(catalog, cfg, history, routineDefault: routine.policy, expanded: i == 0),
  ];
  await navigator.push(MaterialPageRoute(
    builder: (_) => SessionScreen(
      routineName: routine.name,
      routineId: routine.id,
      exercises: exercises,
      history: history,
    ),
  ));
}

/// Buka sesi bebas yang kosong. Gerakan ditambah sambil jalan.
Future<void> openFreestyleSession(BuildContext context, String name) async {
  final store = WorkoutScope.read(context);
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SessionScreen(routineName: name, exercises: const [], history: store.chronological),
  ));
}

/// Buka library sebagai pemilih. null kalau batal.
Future<Exercise?> pickExercise(BuildContext context) => Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen(picking: true)),
    );
