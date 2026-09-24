/// Layar mencatat sesi latihan — artboard `08 Workout Session`.
///
/// Ini layar yang dipakai sambil berdiri di antara set, jadi aturannya berbeda
/// dari layar lain: angka besar, target sentuh lebar, dan tidak ada yang perlu
/// digulir untuk tahu set berikutnya berapa.
library;


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/keep_awake.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/program.dart';
import '../../domain/progression.dart';
import 'finish_screen.dart';
import 'rest_screen.dart';
import 'rest_timer.dart';
import 'session_launcher.dart';

/// Satu gerakan di dalam sesi yang sedang berjalan.
class SessionExercise {
  SessionExercise({
    required this.name,
    required this.config,
    required List<SetRow> sets,
    required List<String> previous,
    required this.icon,
    this.prescription,
    Duration? restDuration,
    this.restEnabled = true,
    this.expanded = false,
  })  : sets = List.of(sets),
        previous = List.of(previous),
        rowKeys = [for (var i = 0; i < sets.length; i++) UniqueKey()],
        restDuration = restDuration ?? const Duration(seconds: 90);

  final String name;
  final ExerciseConfig config;
  final List<SetRow> sets;

  /// Teks kolom PREV per baris — "70 × 8". Sengaja teks, bukan angka: kolom ini
  /// hanya untuk dibaca, dan sesi lama bisa punya jumlah set yang berbeda.
  final List<String> previous;

  /// Satu kunci per baris, bergerak bersama barisnya. Kotak input kg/rep
  /// memegang teksnya sendiri; tanpa kunci yang ikut pindah, menambah warm-up
  /// di depan membuat angka yang sedang diketik pindah ke baris lain.
  final List<Key> rowKeys;

  final IconData icon;

  /// Alasan target (FR-E5), dihitung sekali saat sesi disusun.
  final Prescription? prescription;

  Duration restDuration;
  bool restEnabled;
  bool expanded;

  int get doneCount => sets.where((s) => s.done && !s.isWarmup).length;
  int get workCount => sets.where((s) => !s.isWarmup).length;

  void addRow(SetRow row, {String previous = '—', bool atStart = false}) {
    final at = atStart ? 0 : sets.length;
    sets.insert(at, row);
    this.previous.insert(at.clamp(0, this.previous.length), previous);
    rowKeys.insert(at, UniqueKey());
  }

  void removeRowAt(int i) {
    sets.removeAt(i);
    if (i < previous.length) previous.removeAt(i);
    rowKeys.removeAt(i);
  }
}

/// Aksi di menu ⋯ satu gerakan (FR-D8).
enum _ExerciseAction { moveUp, moveDown, replace, addWarmup, removeLastSet, remove }

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.routineName,
    required this.exercises,
    this.routineId,
    this.history = const [],
  });

  final String routineName;

  /// Rutinitas asal sesi ini. null untuk sesi bebas — dan sesi bebas tidak
  /// menggeser cursor program (FR-B3).
  final String? routineId;

  final List<SessionExercise> exercises;

  /// Riwayat untuk menghitung target, **terlama dulu**. Kosong berarti sesi ini
  /// jadi titik awal.
  final List<Workout> history;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _rest = RestTimer();
  final _elapsed = Stopwatch()..start();
  late final List<SessionExercise> _exercises = List.of(widget.exercises);

  /// Susunan gerakan saat sesi dibuka, untuk mengenali sesi yang menyimpang
  /// dari rutinitasnya (FR-B9).
  late final List<(String, int)> _planned = [
    for (final e in widget.exercises) (e.config.exerciseId, e.workCount),
  ];

  String? _nextLabel;

  /// Gerakan yang setnya ditambah di tengah sesi — dibawa ke ringkasan supaya
  /// bisa ditanyakan "perbarui rutinitasnya?" (FR-B9).
  String? _addedSetTo;

  bool _saving = false;

  /// Gerakan yang istirahatnya sedang berjalan. Kartu istirahat dan layar
  /// penuhnya harus menunjuk ke gerakan yang sama, bukan ke "yang kebetulan
  /// sedang terbuka".
  SessionExercise? _restingOn;

  SessionExercise? get _restingExercise =>
      _restingOn ?? (_exercises.isEmpty ? null : _exercises.firstWhere((e) => e.expanded, orElse: () => _exercises.first));

  @override
  void initState() {
    super.initState();
    KeepAwake.holdIfEnabled();
  }

  @override
  void dispose() {
    KeepAwake.release();
    _rest.dispose();
    super.dispose();
  }

  /// Dipanggil saat satu set dicentang.
  ///
  /// Mencentang set terakhir tidak memulai istirahat: tidak ada set berikutnya
  /// untuk diistirahatkan, dan menghitung mundur ke ruang kosong hanya membuat
  /// orang menunggu tanpa alasan.
  void _onSetToggled(SessionExercise ex, int index, bool done) {
    setState(() => ex.sets[index] = ex.sets[index].copyWith(done: done));
    if (!done || !ex.restEnabled) return;

    final next = index + 1;
    if (next >= ex.sets.length) return;

    final s = ex.sets[next];
    final t = context.t;
    final label = s.isWarmup ? t.warmupLabel : t.setLabel(ex.sets.take(next + 1).where((r) => !r.isWarmup).length);
    setState(() {
      _nextLabel = t.nextUpLine(label, weightLabel(s.weight, bodyweight: ex.config.bodyweight), s.reps);
      _restingOn = ex;
    });
    _rest.start(ex.restDuration);
    _openRestScreen(ex);
  }

  /// Angka yang diketik di tabel. Disimpan seketika ke baris — sebelumnya
  /// kotak input hanya memegang teksnya sendiri, dan beban yang diketik
  /// hilang begitu set dicentang.
  ///
  /// Beban yang diubah di satu set kerja ikut diteruskan ke set kerja di
  /// bawahnya yang belum dicentang dan masih memegang beban lama — perilaku
  /// openGym. Mengetik "60" tiga kali untuk tiga set yang sama itu kerja sia-sia.
  void _onEdited(SessionExercise ex, int index, {double? weight, int? reps}) {
    final old = ex.sets[index];
    ex.sets[index] = old.copyWith(weight: weight, reps: reps);
    if (weight == null || old.isWarmup) return;
    var cascaded = false;
    for (var j = index + 1; j < ex.sets.length; j++) {
      final s = ex.sets[j];
      if (s.isWarmup || s.done || s.weight != old.weight) continue;
      ex.sets[j] = s.copyWith(weight: weight);
      // Kunci baru supaya kotak input baris itu dibangun ulang dengan angka
      // barunya. Baris yang sedang diketik tidak disentuh, jadi fokus dan
      // kursornya tetap di tempat.
      ex.rowKeys[j] = UniqueKey();
      cascaded = true;
    }
    if (cascaded) setState(() {});
  }

  bool get _anythingLogged => _exercises.any((e) => e.sets.any((s) => s.done && !s.isWarmup));

  /// Susunan sesi berbeda dari rutinitasnya: gerakan ditambah, dibuang,
  /// diganti, diurutkan ulang, atau jumlah setnya berubah.
  bool get _drifted {
    if (widget.routineId == null) return false;
    final now = [for (final e in _exercises) (e.config.exerciseId, e.workCount)];
    if (now.length != _planned.length) return true;
    for (var i = 0; i < now.length; i++) {
      if (now[i] != _planned[i]) return true;
    }
    return false;
  }

  /// Selesai: simpan, tunjukkan ringkasannya, baru tutup sesinya. Menutup
  /// begitu saja akan membuang satu-satunya kesempatan menampilkan rekor dan
  /// target berikutnya selagi orangnya masih memperhatikan.
  ///
  /// Simpan lebih dulu, sebelum ringkasan dibuka: kalau aplikasi mati saat
  /// ringkasan terbuka, yang hilang cuma tampilan, bukan latihannya.
  Future<void> _finish() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_anythingLogged) {
      // Sesi tanpa satu set pun bukan latihan. Menyimpannya mengotori riwayat
      // dan menggeser rotasi seolah sesi itu dilakukan.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.noWorkingSets)));
      return;
    }
    _saving = true;
    _rest.skip();
    _elapsed.stop();

    final store = context.workouts;
    final workout = Workout(
      date: isoDate(DateTime.now()),
      routine: widget.routineName,
      durationSeconds: _elapsed.elapsed.inSeconds,
      entries: [
        for (final ex in _exercises)
          WorkoutEntry(exerciseId: ex.config.exerciseId, target: ex.config, sets: List.of(ex.sets)),
      ],
    );
    final drifted = _drifted;
    await store.addWorkout(workout, routineId: widget.routineId);
    if (!mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FinishScreen(
        routineName: widget.routineName,
        routineId: drifted ? widget.routineId : null,
        exercises: _exercises,
        history: widget.history,
        elapsed: _elapsed.elapsed,
        dateLabel: _dateLabel(context),
        addedSetTo: drifted ? _addedSetTo : null,
        drifted: drifted,
      ),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  /// Keluar dari sesi selalu ditanyakan. Tombol panah di kiri atas dulu
  /// langsung menyimpan sesi — keliru dari sisi mana pun: yang ingin
  /// menyimpan menekan Finish, yang menekan panah belum tentu selesai.
  Future<void> _confirmLeave() async {
    if (!_anythingLogged) {
      Navigator.of(context).pop();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        final c = context.gym;
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
          title: Text(context.t.leaveSessionTitle, style: Theme.of(context).textTheme.titleLarge),
          content: Text(context.t.leaveSessionBody, style: TextStyle(fontSize: 13.5, height: 1.45, color: c.text2)),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actionsOverflowDirection: VerticalDirection.up,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: Text(context.t.discard, style: TextStyle(fontWeight: FontWeight.w700, color: c.danger)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t.keepTraining, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
            ),
            GymButton(
              label: context.t.finishAndSave,
              height: 42,
              expand: false,
              onPressed: () => Navigator.of(context).pop('finish'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    switch (choice) {
      case 'discard':
        _rest.skip();
        Navigator.of(context).pop();
      case 'finish':
        await _finish();
    }
  }

  static String _dateLabel(BuildContext context) {
    final t = context.t;
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '${t.weekdayShort(now.weekday)} ${now.day} ${t.monthShort(now.month)} · $hh:$mm';
  }

  /// Mulai istirahat untuk satu gerakan dan tampilkan layar hitung mundurnya.
  Future<void> _startRest(SessionExercise ex) async {
    final next = ex.sets.indexWhere((s) => !s.done && !s.isWarmup);
    final t = context.t;
    setState(() {
      _restingOn = ex;
      _nextLabel = next < 0
          ? t.lastSetDone
          : t.nextUpLine(t.setLabel(ex.sets.take(next + 1).where((r) => !r.isWarmup).length),
              weightLabel(ex.sets[next].weight, bodyweight: ex.config.bodyweight), ex.sets[next].reps);
    });
    _rest.start(ex.restDuration);
    await _openRestScreen(ex);
  }

  Future<void> _openRestScreen(SessionExercise ex) => showRestScreen(
        context,
        timer: _rest,
        exerciseName: ex.name,
        nextLabel: _nextLabel ?? '',
        onEditDuration: () => _editRest(ex),
      );

  Future<void> _editRest(SessionExercise ex) async {
    final picked = await showRestDurationSheet(
      context,
      current: ex.restDuration,
      exerciseName: ex.name,
      routineName: widget.routineName,
    );
    if (picked == null || !mounted) return;
    setState(() => ex.restDuration = picked.duration);
    if (_rest.isRunning) _rest.retarget(picked.duration);

    if (picked.saveAsDefault) await _saveRestAsDefault(ex, picked.duration);
  }

  /// "Simpan sebagai bawaan" menulis ke rutinitas asal sesi ini. Sesi bebas
  /// tidak punya rutinitas untuk ditulisi, dan itu dikatakan apa adanya.
  Future<void> _saveRestAsDefault(SessionExercise ex, Duration d) async {
    final store = context.workouts;
    final id = widget.routineId;
    final routine = id == null ? null : store.routineById(id);
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    if (routine == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.defaultSavedOnSync(ex.name))));
      return;
    }
    final updated = [
      for (final cfg in routine.exercises)
        cfg.exerciseId == ex.config.exerciseId ? cfg.copyWith(restSeconds: d.inSeconds) : cfg,
    ];
    await store.saveRoutine(routine.copyWith(exercises: updated));
  }

  Future<void> _addExercise() async {
    final picked = await pickExercise(context);
    if (picked == null || !mounted) return;
    final catalog = await ExerciseCatalog.load();
    if (!mounted) return;
    final cfg = configForAdded(picked.id, widget.history);
    setState(() {
      for (final e in _exercises) {
        e.expanded = false;
      }
      _exercises.add(buildSessionExercise(catalog, cfg, widget.history, expanded: true));
    });
  }

  Future<void> _onExerciseAction(SessionExercise ex, _ExerciseAction action) async {
    final i = _exercises.indexOf(ex);
    if (i < 0) return;
    switch (action) {
      case _ExerciseAction.moveUp when i > 0:
        setState(() => _exercises.insert(i - 1, _exercises.removeAt(i)));
      case _ExerciseAction.moveDown when i < _exercises.length - 1:
        setState(() => _exercises.insert(i + 1, _exercises.removeAt(i)));
      case _ExerciseAction.replace:
        final picked = await pickExercise(context);
        if (picked == null || !mounted) return;
        final catalog = await ExerciseCatalog.load();
        if (!mounted) return;
        final cfg = configForAdded(picked.id, widget.history);
        setState(() => _exercises[_exercises.indexOf(ex)] =
            buildSessionExercise(catalog, cfg, widget.history, expanded: true));
      case _ExerciseAction.addWarmup:
        final firstWork = ex.sets.firstWhere((s) => !s.isWarmup, orElse: () => const SetRow());
        final inc = weightIncrement(ex.config, 'kg');
        setState(() {
          ex.addRow(
            SetRow(
              phase: SetPhase.warmup,
              weight: firstWork.weight <= 0 ? 0 : snapWeight(firstWork.weight * 0.5, inc),
              reps: 8,
            ),
            atStart: true,
          );
          ex.expanded = true;
        });
      case _ExerciseAction.removeLastSet when ex.sets.length > 1:
        setState(() => ex.removeRowAt(ex.sets.length - 1));
      case _ExerciseAction.remove:
        final ok = await _confirmRemove(ex);
        if (ok != true || !mounted) return;
        setState(() {
          _exercises.remove(ex);
          if (_restingOn == ex) _restingOn = null;
        });
      default:
        break;
    }
  }

  Future<bool?> _confirmRemove(SessionExercise ex) {
    // Menghapus gerakan yang belum disentuh tidak perlu ditanyakan. Yang
    // sudah punya set tercentang ditanyakan, karena itu data latihan.
    if (!ex.sets.any((s) => s.done)) return Future.value(true);
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final c = context.gym;
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
          title: Text('${context.t.removeExercise}?', style: Theme.of(context).textTheme.titleLarge),
          content: Text(ex.name, style: TextStyle(fontSize: 14, color: c.text2)),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
            ),
            GymButton(
              label: context.t.delete,
              height: 42,
              expand: false,
              tone: GymButtonTone.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final total = _exercises.fold(0, (a, e) => a + e.workCount);
    final done = _exercises.fold(0, (a, e) => a + e.doneCount);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                routineName: widget.routineName,
                elapsed: _elapsed,
                rest: _rest,
                onLeave: _confirmLeave,
                onFinish: _finish,
              ),
              LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 3,
                backgroundColor: c.surface2,
                valueColor: AlwaysStoppedAnimation(c.accent),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    AnimatedBuilder(
                      animation: _rest,
                      builder: (context, _) {
                        final resting = _restingExercise;
                        if (!_rest.isRunning || resting == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RestTimerCard(
                            timer: _rest,
                            nextLabel: _nextLabel ?? '',
                            onEditDuration: () => _editRest(resting),
                            onOpen: () => _openRestScreen(resting),
                          ),
                        );
                      },
                    ),
                    const _NotesField(),
                    const SizedBox(height: 12),
                    if (_exercises.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(context.t.emptySessionHint,
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: c.text2)),
                      ),
                    for (final (i, ex) in _exercises.indexed) ...[
                      _ExerciseCard(
                        key: ObjectKey(ex),
                        exercise: ex,
                        isFirst: i == 0,
                        isLast: i == _exercises.length - 1,
                        onToggleExpand: () => setState(() => ex.expanded = !ex.expanded),
                        onSetToggled: (i, v) => _onSetToggled(ex, i, v),
                        onEdited: (i, {weight, reps}) => _onEdited(ex, i, weight: weight, reps: reps),
                        onEditRest: () => _editRest(ex),
                        onToggleRest: (v) => setState(() => ex.restEnabled = v),
                        onStartRest: () => _startRest(ex),
                        onAction: (a) => _onExerciseAction(ex, a),
                        onAddSet: () => setState(() {
                          final last = ex.sets.lastWhere((s) => !s.isWarmup, orElse: () => const SetRow());
                          ex.addRow(SetRow(weight: last.weight, reps: last.reps, seconds: last.seconds));
                          _addedSetTo = ex.name;
                        }),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _DashedAction(icon: Icons.add, label: context.t.addExercise, onTap: _addExercise),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.routineName,
    required this.elapsed,
    required this.rest,
    required this.onLeave,
    required this.onFinish,
  });

  final String routineName;
  final Stopwatch elapsed;
  final RestTimer rest;
  final VoidCallback onLeave;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onLeave,
            icon: Icon(Icons.keyboard_arrow_down, color: c.text2),
            tooltip: context.t.minimise,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(routineName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
                // Waktu berjalan berdetak sendiri tiap detik. Dulu angkanya
                // hanya berubah saat layar kebetulan digambar ulang.
                StreamBuilder<int>(
                  stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
                  builder: (context, _) {
                    final e = elapsed.elapsed;
                    final text = e.inHours > 0
                        ? '${e.inHours}:${(e.inMinutes % 60).toString().padLeft(2, '0')}:${(e.inSeconds % 60).toString().padLeft(2, '0')}'
                        : '${e.inMinutes}:${(e.inSeconds % 60).toString().padLeft(2, '0')}';
                    return Text(context.t.elapsedOf(text), style: TextStyle(fontSize: 12, color: c.text2));
                  },
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: rest,
            builder: (context, _) {
              if (!rest.isRunning) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Pill(
                  color: c.accentSoft,
                  textColor: c.accent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: 6),
                      Text(formatRestWide(rest.remaining)),
                    ],
                  ),
                ),
              );
            },
          ),
          GymButton(label: context.t.finish, height: 38, expand: false, shape: GymButtonShape.pill, onPressed: onFinish),
        ],
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField();

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return TextField(
      style: TextStyle(fontSize: 14, color: c.text),
      decoration: InputDecoration(
        hintText: context.t.sessionNotes,
        hintStyle: TextStyle(fontSize: 14, color: c.text2),
        prefixIcon: Icon(Icons.notes, size: 18, color: c.text2),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.card),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.card),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.card),
          borderSide: BorderSide(color: c.accent),
        ),
      ),
    );
  }
}

typedef _EditCallback = void Function(int index, {double? weight, int? reps});

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.isFirst,
    required this.isLast,
    required this.onToggleExpand,
    required this.onSetToggled,
    required this.onEdited,
    required this.onEditRest,
    required this.onToggleRest,
    required this.onStartRest,
    required this.onAddSet,
    required this.onAction,
  });

  final SessionExercise exercise;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onToggleExpand;
  final void Function(int index, bool done) onSetToggled;
  final _EditCallback onEdited;
  final VoidCallback onEditRest;
  final ValueChanged<bool> onToggleRest;
  final VoidCallback onStartRest;
  final VoidCallback onAddSet;
  final ValueChanged<_ExerciseAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final ex = exercise;
    final p = ex.prescription;
    final policy = policyFor(ex.config);
    final firstWork = ex.sets.firstWhere((s) => !s.isWarmup, orElse: () => const SetRow());
    final t = context.t;
    final w = weightLabel(firstWork.weight, bodyweight: ex.config.bodyweight);

    PopupMenuItem<_ExerciseAction> item(_ExerciseAction a, IconData icon, String label,
            {bool enabled = true, Color? tone}) =>
        PopupMenuItem(
          value: a,
          enabled: enabled,
          height: 44,
          child: Row(
            children: [
              Icon(icon, size: 17, color: enabled ? (tone ?? c.text2) : c.text3),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: enabled ? (tone ?? c.text) : c.text3)),
            ],
          ),
        );

    return GymCard(
      radius: GymRadius.large,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(GymRadius.small),
                ),
                child: Icon(ex.icon, size: 20, color: c.text2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: onToggleExpand,
                  borderRadius: BorderRadius.circular(GymRadius.small),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 1),
                      Text(
                        ex.expanded
                            ? t.targetLine(w, firstWork.reps, policyName[policy]!.toLowerCase())
                            : t.setsTarget(ex.workCount, w, firstWork.reps),
                        style: TextStyle(fontSize: 12, color: c.text2),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleExpand,
                icon: Icon(ex.expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: c.text2),
                tooltip: ex.expanded ? t.collapse : t.expand,
              ),
              PopupMenuButton<_ExerciseAction>(
                icon: Icon(Icons.more_vert, size: 20, color: c.text2),
                tooltip: t.exerciseActions,
                color: c.surface2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.control)),
                onSelected: onAction,
                itemBuilder: (context) => [
                  item(_ExerciseAction.moveUp, Icons.arrow_upward, t.moveUp, enabled: !isFirst),
                  item(_ExerciseAction.moveDown, Icons.arrow_downward, t.moveDown, enabled: !isLast),
                  item(_ExerciseAction.replace, Icons.swap_horiz, t.replaceExercise),
                  item(_ExerciseAction.addWarmup, Icons.whatshot_outlined, t.addWarmup),
                  item(_ExerciseAction.removeLastSet, Icons.remove_circle_outline, t.removeLastSet,
                      enabled: ex.sets.length > 1),
                  item(_ExerciseAction.remove, Icons.delete_outline, t.removeExercise, tone: c.danger),
                ],
              ),
            ],
          ),
          if (ex.expanded)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _RestRow(exercise: ex, onEdit: onEditRest, onToggle: onToggleRest, onStart: onStartRest),
                  if (p != null) ...[
                    const SizedBox(height: 10),
                    _WhyBanner(text: p.why, kind: p.kind),
                  ],
                  const SizedBox(height: 12),
                  _SetTable(exercise: ex, onToggled: onSetToggled, onEdited: onEdited),
                  const SizedBox(height: 10),
                  _DashedAction(icon: Icons.add, label: t.addSet, onTap: onAddSet, compact: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Baris pengatur istirahat satu gerakan.
///
/// Semua isinya harus muat di HP 360 dp. Versi sebelumnya menaruh label,
/// durasi, tombol START berlabel, dan Switch berukuran penuh berjajar tanpa
/// batas, sehingga Switch terdorong keluar kartu dan tidak bisa disentuh.
class _RestRow extends StatelessWidget {
  const _RestRow({
    required this.exercise,
    required this.onEdit,
    required this.onToggle,
    required this.onStart,
  });

  final SessionExercise exercise;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final d = exercise.restDuration;
    final text = d.inSeconds % 60 == 0 ? '${d.inMinutes}m' : '${d.inMinutes}m ${d.inSeconds % 60}s';
    final on = exercise.restEnabled;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: c.bgNested,
        borderRadius: BorderRadius.circular(GymRadius.small),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 17, color: on ? c.text2 : c.text3),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(context.t.restTimer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: on ? c.text : c.text3)),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(GymRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(text,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? c.accent : c.text3)),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_outlined, size: 14, color: c.text2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Mulai istirahat tanpa harus mencentang set dulu — kadang orang
          // istirahat di tengah, atau baru ingat menekan setelah mulai.
          if (on)
            IconButton(
              onPressed: onStart,
              tooltip: context.t.start,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: c.accentSoft),
              icon: Icon(Icons.play_arrow_rounded, size: 20, color: c.accent),
            ),
          Switch(
            value: on,
            onChanged: onToggle,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

/// Kenapa angka targetnya segitu (FR-E5). Selalu ada isinya, jadi tidak perlu
/// kondisi "kalau ada alasan".
class _WhyBanner extends StatelessWidget {
  const _WhyBanner({required this.text, required this.kind});

  final String text;
  final PrescriptionKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final (icon, tint) = switch (kind) {
      PrescriptionKind.up => (Icons.trending_up, c.accent),
      PrescriptionKind.deload => (Icons.trending_down, c.warn),
      PrescriptionKind.hold => (Icons.trending_flat, c.text2),
      _ => (Icons.flag_outlined, c.text2),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(GymRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tint))),
        ],
      ),
    );
  }
}

class _SetTable extends StatelessWidget {
  const _SetTable({required this.exercise, required this.onToggled, required this.onEdited});

  final SessionExercise exercise;
  final void Function(int index, bool done) onToggled;
  final _EditCallback onEdited;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    var workIndex = 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              SizedBox(width: 34, child: SectionLabel(context.t.setCol)),
              SizedBox(width: 62, child: SectionLabel(context.t.prevCol)),
              Expanded(child: Center(child: SectionLabel(context.t.kgCol))),
              Expanded(child: Center(child: SectionLabel(context.t.repsCol))),
              const SizedBox(width: 38),
            ],
          ),
        ),
        for (var i = 0; i < exercise.sets.length; i++)
          Builder(builder: (context) {
            final s = exercise.sets[i];
            if (!s.isWarmup) workIndex++;
            return Padding(
              key: exercise.rowKeys[i],
              padding: const EdgeInsets.only(bottom: 6),
              child: _SetRowTile(
                label: s.isWarmup ? 'W' : '$workIndex',
                labelColor: s.isWarmup ? c.warn : c.doneInk,
                previous: i < exercise.previous.length ? exercise.previous[i] : '—',
                set: s,
                bodyweight: exercise.config.bodyweight,
                onToggled: (v) => onToggled(i, v),
                onWeight: (w) => onEdited(i, weight: w),
                onReps: (r) => onEdited(i, reps: r),
              ),
            );
          }),
      ],
    );
  }
}

class _SetRowTile extends StatelessWidget {
  const _SetRowTile({
    required this.label,
    required this.labelColor,
    required this.previous,
    required this.set,
    required this.bodyweight,
    required this.onToggled,
    required this.onWeight,
    required this.onReps,
  });

  final String label;
  final Color labelColor;
  final String previous;
  final SetRow set;
  final bool bodyweight;
  final ValueChanged<bool> onToggled;
  final ValueChanged<double> onWeight;
  final ValueChanged<int> onReps;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final done = set.done;

    return AnimatedContainer(
      duration: GymMotion.of(context, GymMotion.quick),
      curve: GymMotion.curve,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        // Baris selesai jadi hijau gelap, tapi angkanya tetap putih penuh:
        // membaca beban dari jarak satu lengan lebih penting daripada
        // menegaskan bahwa baris itu sudah lewat (FR-D3).
        color: done ? c.doneBg : c.bgNested,
        borderRadius: BorderRadius.circular(GymRadius.small),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: done ? labelColor : c.text2)),
          ),
          SizedBox(
            width: 62,
            child: Text(previous, maxLines: 1, overflow: TextOverflow.fade, softWrap: false,
                style: TextStyle(fontSize: 12, color: c.text2)),
          ),
          Expanded(
            child: _Cell(
              text: set.weight == 0 ? '' : formatDelta(set.weight),
              doneText: formatWeight(set.weight),
              hint: bodyweight ? 'BW' : 'kg',
              done: done,
              decimal: true,
              onChanged: (v) => onWeight(double.tryParse(v.replaceAll(',', '.')) ?? 0),
            ),
          ),
          Expanded(
            child: _Cell(
              text: set.reps == 0 ? '' : '${set.reps}',
              doneText: '${set.reps}',
              hint: '0',
              done: done,
              decimal: false,
              onChanged: (v) => onReps(int.tryParse(v) ?? 0),
            ),
          ),
          SizedBox(
            width: 38,
            child: Semantics(
              button: true,
              checked: done,
              label: context.t.markSetDone(label),
              child: InkWell(
                onTap: () {
                  // Getar hanya saat menandai selesai — itu momen "tercatat".
                  // Membatalkan centang tidak perlu dirayakan.
                  if (!done) GymHaptics.confirm();
                  FocusScope.of(context).unfocus();
                  onToggled(!done);
                },
                borderRadius: BorderRadius.circular(GymRadius.pill),
                child: AnimatedSwitcher(
                  duration: GymMotion.of(context, GymMotion.quick),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    done ? Icons.check_circle : Icons.circle_outlined,
                    key: ValueKey(done),
                    size: 24,
                    color: done ? c.doneInk : c.text3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sel angka. Baris yang belum dicentang tampil sebagai kotak input — itu yang
/// membedakan "sudah tercatat" dari "silakan isi" tanpa teks tambahan.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.text,
    required this.doneText,
    required this.hint,
    required this.done,
    required this.decimal,
    required this.onChanged,
  });

  final String text;
  final String doneText;
  final String hint;
  final bool done;
  final bool decimal;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final style = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: c.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    if (done) return Center(child: Text(doneText, style: style));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: TextFormField(
        initialValue: text,
        textAlign: TextAlign.center,
        style: style,
        onChanged: onChanged,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.allow(decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]')),
          LengthLimitingTextInputFormatter(decimal ? 6 : 3),
        ],
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: c.surface2,
          hintText: hint,
          hintStyle: style.copyWith(color: c.text3, fontWeight: FontWeight.w600),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GymRadius.input),
            borderSide: BorderSide(color: c.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GymRadius.input),
            borderSide: BorderSide(color: c.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GymRadius.input),
            borderSide: BorderSide(color: c.accent),
          ),
        ),
      ),
    );
  }
}

class _DashedAction extends StatelessWidget {
  const _DashedAction({required this.icon, required this.label, required this.onTap, this.compact = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(compact ? GymRadius.small : GymRadius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: Container(
          height: compact ? 36 : 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? GymRadius.small : GymRadius.control),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: compact ? c.text2 : c.accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: compact ? c.text2 : c.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
