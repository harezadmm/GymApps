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
import '../../domain/settings.dart';
import '../library/library_screen.dart';
import 'session_screen.dart';

/// Susun satu gerakan untuk dibuka di layar sesi.
SessionExercise buildSessionExercise(
  ExerciseCatalog catalog,
  ExerciseConfig cfg,
  List<Workout> history, {
  ProgressionPolicy? routineDefault,
  TrainingSettings? settings,
  bool expanded = false,
}) {
  final s = settings ?? const TrainingSettings();
  // Faktor deload dari Profil berlaku untuk gerakan yang tidak menentukan
  // sendiri.
  final withDefaults = cfg.deloadFactor == null ? cfg.copyWith(deloadFactor: s.deloadFactor) : cfg;
  final plan = planExercise(withDefaults, history, routineDefault: routineDefault);
  final ex = catalog.byId(cfg.exerciseId);
  return SessionExercise(
    name: catalog.nameOf(cfg.exerciseId),
    icon: ex?.icon ?? Icons.fitness_center,
    config: plan.target,
    sets: plan.sets,
    previous: plan.previous,
    prescription: plan.prescription,
    restDuration: Duration(seconds: s.restFor(cfg)),
    expanded: expanded,
    lastNote: lastEntryFor(history, cfg.exerciseId)?.note,
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
      buildSessionExercise(catalog, cfg, history,
          routineDefault: routine.policy, settings: store.settings, expanded: i == 0),
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

/// Lanjutkan sesi yang tertinggal di draft — aplikasi dimatikan atau HP mati
/// di tengah latihan.
Future<void> resumeDraftSession(BuildContext context) async {
  final store = WorkoutScope.read(context);
  final draft = store.draft;
  if (draft == null) return;
  final navigator = Navigator.of(context);
  final catalog = await ExerciseCatalog.load();
  final exercises = <SessionExercise>[
    for (final raw in (draft['ex'] as List? ?? const []))
      () {
        final j = Map<String, dynamic>.from(raw as Map);
        final id = ((j['cfg'] as Map?)?['id'] as String?) ?? '';
        return SessionExercise.fromDraft(j, catalog.byId(id)?.icon ?? Icons.fitness_center);
      }(),
  ];
  final planned = <(String, int)>[
    for (final p in (draft['planned'] as List? ?? const []))
      if (p is List && p.length == 2) ('${p[0]}', (p[1] as num).toInt()),
  ];
  await navigator.push(MaterialPageRoute(
    builder: (_) => SessionScreen(
      routineName: draft['name'] as String? ?? '',
      routineId: draft['rid'] as String?,
      exercises: exercises,
      history: store.chronological,
      initialElapsed: Duration(seconds: (draft['elapsed'] as num?)?.toInt() ?? 0),
      initialNotes: draft['notes'] as String?,
      planned: planned.isEmpty ? null : planned,
    ),
  ));
}

/// Buka library sebagai pemilih. null kalau batal.
Future<Exercise?> pickExercise(BuildContext context) => Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen(picking: true)),
    );
