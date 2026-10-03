/// Membuka sesi dari rutinitas sungguhan, atau sesi bebas yang kosong.
///
/// Satu tempat untuk ini, dipakai Home, tab Workout, dan layar lain: dulu
/// setiap layar membuka sesi dengan daftar gerakan contoh yang sama, sehingga
/// sesi "Push" berisi Barbell Row.
library;

import 'package:flutter/material.dart';
import '../../domain/units.dart';

import '../../core/gym_icons.dart';
import '../../core/strings.dart';
import '../../core/strings_history.dart';
import '../../core/strings_session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/program.dart';
import '../../domain/session_plan.dart';
import '../../domain/settings.dart';
import '../history/workout_edit_screen.dart';
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
  // [cfg] dan [history] sudah dalam satuan tampilan (lihat units.dart), jadi
  // lompatan pelatnya juga dalam satuan itu.
  final plan = planExercise(withDefaults, history, routineDefault: routineDefault, unit: s.unit.label);
  final ex = catalog.byId(cfg.exerciseId);
  return SessionExercise(
    name: catalog.nameOf(cfg.exerciseId),
    // Gerakan yang hilang dari katalog (id dari cadangan lama) tetap butuh
    // ikon; dumbbell dari font yang sama dengan ikon alat lainnya.
    icon: ex?.icon ?? GymIcons.dumbbell,
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

/// Riwayat yang mendahului sesi yang dibuka ulang, terlama dulu — untuk kolom
/// PREV, target, dan cek PR. Sesi itu sendiri tidak boleh ikut (PR yang
/// dibandingkan dengan dirinya sendiri tidak pernah pecah), dan sesi yang
/// datang *sesudahnya* juga tidak: "sesi lalu" untuk latihan tanggal 20
/// bukan latihan tanggal 25.
///
/// [chronological] terlama dulu, seperti [WorkoutStore.chronological].
/// Dicocokkan lewat identitas dulu, lalu sidik jari [key] (default: sidik
/// jari [workout]) — sinkron bisa mengganti objeknya, dan draft hanya
/// menyimpan sidik jarinya. Tidak ketemu (sudah dihapus di HP lain) = seluruh
/// riwayat, karena memang tidak ada yang perlu dikeluarkan.
List<Workout> historyBefore(List<Workout> chronological, {Workout? workout, String? key}) {
  var i = workout == null ? -1 : chronological.indexWhere((w) => identical(w, workout));
  final k = key ?? (workout == null ? null : workoutKey(workout));
  if (i < 0 && k != null) i = chronological.indexWhere((w) => workoutKey(w) == k);
  return i < 0 ? chronological : chronological.sublist(0, i);
}

/// Draft yang cukup baru untuk dibuka otomatis saat aplikasi dimulai lagi.
///
/// Dua belas jam: HP yang dimatikan sistem selama sesi, atau aplikasi yang
/// ditutup di loker lalu dibuka lagi sepulang gym, masih "sesi yang sama".
/// Draft dari kemarin lusa tidak dibuka paksa — kartunya tetap ada di Home.
bool draftIsRecent(Map<String, dynamic> draft, {DateTime? now, Duration within = const Duration(hours: 12)}) {
  final saved = (draft['saved'] as num?)?.toInt();
  if (saved == null) return false;
  final age = (now ?? DateTime.now()).difference(DateTime.fromMillisecondsSinceEpoch(saved));
  return !age.isNegative && age <= within;
}

/// Lama sesi yang dipulihkan dari draft.
///
/// Waktu antara draft terakhir dan sekarang ikut dihitung kalau jaraknya
/// wajar untuk satu sesi (≤ 3 jam): aplikasi yang dimatikan sistem tidak
/// menghentikan orang yang sedang latihan. Kalau lebih lama, sesinya jelas
/// ditinggal, dan menambahkan semalaman ke durasinya adalah angka bohong.
Duration draftElapsed(Map<String, dynamic> draft, {DateTime? now}) {
  final base = Duration(seconds: (draft['elapsed'] as num?)?.toInt() ?? 0);
  final saved = (draft['saved'] as num?)?.toInt();
  if (saved == null) return base;
  final gap = (now ?? DateTime.now()).difference(DateTime.fromMillisecondsSinceEpoch(saved));
  if (gap.isNegative || gap > const Duration(hours: 3)) return base;
  return base + gap;
}

/// Pastikan tidak ada sesi setengah jalan yang akan tertimpa.
///
/// Dulu membuka sesi baru selagi ada draft menimpa draft itu tanpa bertanya
/// — HP yang dimatikan sistem di tengah latihan, lalu orangnya menekan
/// "Mulai sesi" di Home, dan semua set yang sudah dicatat hilang. Sekarang
/// ditanya: lanjutkan sesi yang tertinggal, atau buang lalu mulai baru.
///
/// true = boleh lanjut membuka sesi baru.
Future<bool> ensureNoDraft(BuildContext context) async {
  final store = WorkoutScope.read(context);
  final draft = store.draft;
  if (draft == null) return true;
  final c = context.gym;
  final t = context.t;
  var logged = 0;
  for (final e in (draft['ex'] as List? ?? const [])) {
    for (final s in ((e as Map)['sets'] as List? ?? const [])) {
      final m = s as Map;
      if (m['done'] == true && m['phase'] != 'warmup') logged++;
    }
  }
  final minutes = draftElapsed(draft).inMinutes;
  final choice = await showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
      title: Text(t.draftExistsTitle, style: Theme.of(dialog).textTheme.titleLarge),
      content: Text(t.draftExistsBody(draft['name'] as String? ?? '', logged, minutes),
          style: TextStyle(fontSize: 14, height: 1.4, color: c.text2)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop('discard'),
          child: Text(t.discardAndStart, style: TextStyle(fontWeight: FontWeight.w700, color: c.danger)),
        ),
        GymButton(
          label: t.continueUpper,
          height: 42,
          expand: false,
          onPressed: () => Navigator.of(dialog).pop('resume'),
        ),
      ],
    ),
  );
  if (!context.mounted) return false;
  switch (choice) {
    case 'discard':
      await store.clearDraft();
      return true;
    case 'resume':
      await resumeDraftSession(context);
      return false;
    default:
      return false;
  }
}

/// Sebut sekali rutinitas yang baru saja mengikuti sesi terakhirnya
/// ([WorkoutStore.takeAlignedRoutines]). Tidak melakukan apa-apa kalau tidak
/// ada.
void announceAlignedRoutines(ScaffoldMessengerState? messenger, Strings t, WorkoutStore store) {
  final names = store.takeAlignedRoutines();
  if (names.isEmpty || messenger == null) return;
  messenger.showSnackBar(SnackBar(
    content: Text(t.routinesFollowLastSession(names)),
    duration: const Duration(seconds: 6),
  ));
}

/// Buka layar sesi untuk satu rutinitas.
///
/// Gerakannya diambil dari rutinitas seperti tersimpan sekarang — yang sejak
/// v2.2 mengikuti susunan sesi terakhirnya — dan bebannya dari riwayat tiap
/// gerakan lewat mesin progresi.
Future<void> openRoutineSession(BuildContext context, Routine routine) async {
  if (!await ensureNoDraft(context) || !context.mounted) return;
  final store = WorkoutScope.read(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final t = context.t;
  // Rencana dari sebelum v2.2 diselaraskan dulu: rutinitasnya bisa masih isi
  // template padahal sesi terakhirnya sudah disusun ulang.
  final current = await store.alignBeforeSession(routine.id) ?? routine;
  final catalog = await ExerciseCatalog.load();
  final unit = store.settings.unit;
  final history = historyIn(store.chronological, unit);
  final exercises = [
    for (final (i, cfg) in current.exercises.indexed)
      buildSessionExercise(catalog, configIn(cfg, unit), history,
          routineDefault: current.policy, settings: store.settings, expanded: i == 0),
  ];
  announceAlignedRoutines(messenger, t, store);
  await navigator.push(MaterialPageRoute(
    builder: (_) => SessionScreen(
      routineName: current.name,
      routineId: current.id,
      exercises: exercises,
      history: history,
    ),
  ));
}

/// Buka sesi bebas yang kosong. Gerakan ditambah sambil jalan.
Future<void> openFreestyleSession(BuildContext context, String name) async {
  if (!await ensureNoDraft(context) || !context.mounted) return;
  final store = WorkoutScope.read(context);
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SessionScreen(
        routineName: name, exercises: const [], history: historyIn(store.chronological, store.settings.unit)),
  ));
}

/// Lanjutkan sesi yang tertinggal di draft — aplikasi dimatikan atau HP mati
/// di tengah latihan. [restored] = dibuka otomatis saat aplikasi dimulai,
/// bukan karena kartunya diketuk.
Future<void> resumeDraftSession(BuildContext context, {bool restored = false}) async {
  final store = WorkoutScope.read(context);
  final draft = store.draft;
  if (draft == null) return;
  final navigator = Navigator.of(context);
  final catalog = await ExerciseCatalog.load();
  // Draft sebelum v1.8 tidak menulis satuan; waktu itu hanya ada kg.
  final draftUnit = WeightUnit.parse(draft['unit']);
  final unit = store.settings.unit;
  final exercises = <SessionExercise>[
    for (final raw in (draft['ex'] as List? ?? const []))
      () {
        final j = Map<String, dynamic>.from(raw as Map);
        final id = ((j['cfg'] as Map?)?['id'] as String?) ?? '';
        final ex = SessionExercise.fromDraft(j, catalog.byId(id)?.icon ?? GymIcons.dumbbell);
        if (draftUnit != unit) {
          // Satuan diganti di Profil sebelum sesi dilanjutkan.
          ex.config = configBetween(ex.config, draftUnit, unit);
          for (var i = 0; i < ex.sets.length; i++) {
            ex.sets[i] = setBetween(ex.sets[i], draftUnit, unit);
          }
        }
        return ex;
      }(),
  ];
  final planned = <(String, int)>[
    for (final p in (draft['planned'] as List? ?? const []))
      if (p is List && p.length == 2) ('${p[0]}', (p[1] as num).toInt()),
  ];
  final rest = draft['rest'];
  ({DateTime deadline, Duration total, int? exercise, String? next})? initialRest;
  if (rest is Map && rest['end'] is num) {
    initialRest = (
      deadline: DateTime.fromMillisecondsSinceEpoch((rest['end'] as num).toInt()),
      total: Duration(seconds: (rest['total'] as num?)?.toInt() ?? 90),
      exercise: (rest['on'] as num?)?.toInt(),
      next: rest['next'] as String?,
    );
  }
  // Draft sebelum v2.2 tidak menulis tanggal. Tanggal simpan terakhirnya
  // yang paling dekat dengan hari sesi itu dimulai.
  final saved = (draft['saved'] as num?)?.toInt();
  final date = draft['date'] as String? ??
      (saved == null ? null : isoDate(DateTime.fromMillisecondsSinceEpoch(saved)));
  // Draft dari sesi yang dibuka ulang di Riwayat: riwayatnya dipotong sama
  // seperti saat pertama kali dibuka ulang ([reopenWorkoutSession]). Tanpa
  // ini, sesi yang dilanjutkan dari draft membandingkan PR dengan catatan
  // aslinya sendiri.
  final replaces = draft['replaces'] as String?;
  final kgHistory =
      replaces == null ? store.chronological : historyBefore(store.chronological, key: replaces);
  await navigator.push(MaterialPageRoute(
    builder: (_) => SessionScreen(
      routineName: draft['name'] as String? ?? '',
      routineId: draft['rid'] as String?,
      exercises: exercises,
      history: historyIn(kgHistory, unit),
      initialElapsed: draftElapsed(draft),
      initialNotes: draft['notes'] as String?,
      planned: planned.isEmpty ? null : planned,
      initialDate: date,
      replacesKey: replaces,
      initialRest: initialRest,
      restored: restored,
    ),
  ));
}

/// Buka lagi sesi yang terlanjur diselesaikan sebagai sesi berjalan.
///
/// Set yang sudah tercatat dibawa apa adanya — termasuk centangnya — dan
/// stopwatch melanjutkan dari lama sesi yang tersimpan, bukan mulai dari nol.
/// Catatan aslinya tetap di Riwayat sampai sesi ini diselesaikan lagi, lalu
/// diganti di tempatnya ([SessionScreen.replacesKey] →
/// [WorkoutStore.replaceWorkoutByKey]). Kalau sesi yang dibuka ulang dibuang,
/// catatan aslinya masih utuh. Tanggalnya juga tanggal sesi aslinya.
///
/// Riwayat untuk kolom PREV, target, dan PR hanya sesi *sebelum* sesi ini
/// ([historyBefore]): yang disebut "sesi lalu" harus sesi sebelumnya, bukan
/// sesi yang sedang dibuka ulang, dan bukan sesi yang dicatat sesudahnya.
Future<void> reopenWorkoutSession(BuildContext context, Workout workout) async {
  if (!await ensureNoDraft(context) || !context.mounted) return;
  final store = WorkoutScope.read(context);
  final navigator = Navigator.of(context);
  final t = context.t;
  final catalog = await ExerciseCatalog.load();
  final unit = store.settings.unit;
  final kgHistory = historyBefore(store.chronological, workout: workout);
  final history = historyIn(kgHistory, unit);
  final shown = historyIn([workout], unit).first;
  Routine? routine;
  for (final r in store.routines) {
    if (r.name == workout.routine) {
      routine = r;
      break;
    }
  }
  final exercises = <SessionExercise>[];
  for (final (i, entry) in workout.entries.indexed) {
    final id = entry.exerciseId;
    // Riwayat lama tanpa target dibekukan ke target terakhir gerakan itu
    // *sebelum* sesi ini, sama seperti gerakan yang ditambah di sesi bebas.
    final cfgKg = entry.target ?? configForAdded(id, kgHistory);
    final cfg = configIn(cfgKg, unit);
    // planExercise hanya diminta PREV dan alasannya; baris setnya dibuang,
    // karena set yang dipakai adalah yang sudah tercatat.
    final plan = planExercise(cfg, history, unit: unit.label);
    final sets = shown.entries[i].sets;
    final previous = [
      for (var j = 0; j < sets.length; j++) j < plan.previous.length ? plan.previous[j] : '—',
    ];
    exercises.add(SessionExercise(
      name: catalog.nameOf(id),
      icon: catalog.byId(id)?.icon ?? GymIcons.dumbbell,
      config: cfg,
      sets: sets,
      previous: previous,
      prescription: plan.prescription,
      restDuration: Duration(seconds: store.settings.restFor(cfgKg)),
      expanded: i == 0,
      note: entry.note,
      lastNote: lastEntryFor(history, id)?.note,
    ));
  }
  await navigator.push(MaterialPageRoute(
    builder: (_) => SessionScreen(
      routineName: workout.routine ?? t.freestyleSession,
      routineId: routine?.id,
      exercises: exercises,
      history: history,
      initialElapsed: Duration(seconds: workout.durationSeconds ?? 0),
      initialNotes: workout.notes,
      // Rencana diambil dari rutinitasnya sekarang, supaya penanda "sesi
      // menyimpang dari rutinitas" menilai terhadap rutinitas, bukan terhadap
      // isi sesi yang sedang dibuka ulang (yang selalu sama dengan dirinya).
      planned: routine == null ? null : [for (final cfg in routine.exercises) (cfg.exerciseId, cfg.sets)],
      initialDate: workout.date,
      replacesKey: workoutKey(workout),
    ),
  ));
}

/// Catat sesi yang sudah lewat lewat editor — tanggal, rutinitas, gerakan, dan
/// set diketik, bukan dijalankan. Hasilnya masuk lewat
/// [WorkoutStore.addManualWorkout] supaya tidak menggeser rotasi program.
Future<void> openManualEntry(BuildContext context) async {
  final store = WorkoutScope.read(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final t = context.t;
  final catalog = await ExerciseCatalog.load();
  final result = await navigator.push<Workout>(MaterialPageRoute(
    builder: (_) => WorkoutEditScreen(
      workout: Workout(date: isoDate(DateTime.now()), entries: const []),
      catalog: catalog,
      isNew: true,
    ),
  ));
  if (result == null) return;
  await store.addManualWorkout(result);
  messenger?.showSnackBar(SnackBar(content: Text(t.sessionLogged)));
}

/// Buka library sebagai pemilih. null kalau batal.
Future<Exercise?> pickExercise(BuildContext context) => Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen(picking: true)),
    );
