/// Layar mencatat sesi latihan — artboard `08 Workout Session`.
///
/// Ini layar yang dipakai sambil berdiri di antara set, jadi aturannya berbeda
/// dari layar lain: angka besar, target sentuh lebar, dan tidak ada yang perlu
/// digulir untuk tahu set berikutnya berapa.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/progression.dart';
import 'finish_screen.dart';
import 'rest_screen.dart';
import 'rest_timer.dart';

/// Satu gerakan di dalam sesi yang sedang berjalan.
class SessionExercise {
  SessionExercise({
    required this.name,
    required this.config,
    required this.sets,
    required this.previous,
    required this.icon,
    this.restDuration = const Duration(seconds: 90),
    this.restEnabled = true,
    this.expanded = false,
  });

  final String name;
  final ExerciseConfig config;
  final List<SetRow> sets;

  /// Teks kolom PREV per baris — "70 × 8". Sengaja teks, bukan angka: kolom ini
  /// hanya untuk dibaca, dan sesi lama bisa punya jumlah set yang berbeda.
  final List<String> previous;

  final IconData icon;
  Duration restDuration;
  bool restEnabled;
  bool expanded;

  int get doneCount => sets.where((s) => s.done && !s.isWarmup).length;
  int get workCount => sets.where((s) => !s.isWarmup).length;
}

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.routineName,
    required this.exercises,
    this.history = const [],
  });

  final String routineName;
  final List<SessionExercise> exercises;

  /// Riwayat untuk menghitung target. Kosong berarti sesi ini jadi titik awal.
  final List<Workout> history;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _rest = RestTimer();
  final _elapsed = Stopwatch()..start();
  String? _nextLabel;

  /// Gerakan yang setnya ditambah di tengah sesi — dibawa ke ringkasan supaya
  /// bisa ditanyakan "perbarui rutinitasnya?" (FR-D10).
  String? _addedSetTo;

  /// Gerakan yang istirahatnya sedang berjalan. Kartu istirahat dan layar
  /// penuhnya harus menunjuk ke gerakan yang sama, bukan ke "yang kebetulan
  /// sedang terbuka".
  SessionExercise get _restingExercise =>
      widget.exercises.firstWhere((e) => e.expanded, orElse: () => widget.exercises.first);

  @override
  void dispose() {
    _rest.dispose();
    super.dispose();
  }

  /// Dipanggil saat satu set dicentang.
  ///
  /// Mencentang set terakhir tidak memulai istirahat: tidak ada set berikutnya
  /// untuk diistirahatkan, dan menghitung mundur ke ruang kosong hanya membuat
  /// orang menunggu tanpa alasan.
  void _onSetToggled(SessionExercise ex, int index, bool done) {
    setState(() {
      ex.sets[index] = ex.sets[index].copyWith(done: done);
    });
    if (!done || !ex.restEnabled) return;

    final next = index + 1;
    if (next >= ex.sets.length) return;

    final s = ex.sets[next];
    final t = context.t;
    final label = s.isWarmup
        ? t.warmupLabel
        : t.setLabel(ex.sets.take(next + 1).where((r) => !r.isWarmup).length);
    setState(() => _nextLabel = t.nextUpLine(label, formatWeight(s.weight), s.reps));
    _rest.start(ex.restDuration);
    _openRestScreen(ex);
  }

  /// Selesai: simpan, tunjukkan ringkasannya, baru tutup sesinya. Menutup
  /// begitu saja akan membuang satu-satunya kesempatan menampilkan rekor dan
  /// target berikutnya selagi orangnya masih memperhatikan.
  ///
  /// Simpan lebih dulu, sebelum ringkasan dibuka: kalau aplikasi mati saat
  /// ringkasan terbuka, yang hilang cuma tampilan, bukan latihannya.
  Future<void> _finish() async {
    _rest.skip();
    _elapsed.stop();

    // Riwayat untuk ringkasan diambil dari snapshot sebelum sesi ini masuk —
    // kalau tidak, setiap sesi akan memecahkan rekornya sendiri.
    await context.workouts.addWorkout(Workout(
      date: _isoDate(),
      routine: widget.routineName,
      durationSeconds: _elapsed.elapsed.inSeconds,
      entries: [
        for (final ex in widget.exercises)
          WorkoutEntry(exerciseId: ex.config.exerciseId, target: ex.config, sets: ex.sets),
      ],
    ));
    if (!mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FinishScreen(
        routineName: widget.routineName,
        exercises: widget.exercises,
        history: widget.history,
        elapsed: _elapsed.elapsed,
        dateLabel: _dateLabel(),
        addedSetTo: _addedSetTo,
      ),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  /// `YYYY-MM-DD` untuk disimpan. Berbeda dari [_dateLabel], yang untuk dibaca
  /// manusia: satu dipakai mengurutkan dan mencocokkan, satunya ditampilkan.
  static String _isoDate() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  static String _dateLabel() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]} · $hh:$mm';
  }

  /// Mulai istirahat untuk satu gerakan dan tampilkan layar hitung mundurnya.
  Future<void> _startRest(SessionExercise ex) async {
    final next = ex.sets.indexWhere((s) => !s.done && !s.isWarmup);
    final t = context.t;
    setState(() => _nextLabel = next < 0
        ? t.lastSetDone
        : t.nextUpLine(
            t.setLabel(ex.sets.take(next + 1).where((r) => !r.isWarmup).length),
            formatWeight(ex.sets[next].weight),
            ex.sets[next].reps));
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

    if (picked.saveAsDefault) {
      // Menyimpan ke konfigurasi rutinitas menyusul bersama store Supabase;
      // untuk sekarang jangan diam-diam berpura-pura tersimpan.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.defaultSavedOnSync(ex.name))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final total = widget.exercises.fold(0, (a, e) => a + e.workCount);
    final done = widget.exercises.fold(0, (a, e) => a + e.doneCount);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              routineName: widget.routineName,
              elapsed: _elapsed.elapsed,
              rest: _rest,
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
                children: [
                  AnimatedBuilder(
                    animation: _rest,
                    builder: (context, _) {
                      if (!_rest.isRunning) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: RestTimerCard(
                          timer: _rest,
                          nextLabel: _nextLabel ?? '',
                          onEditDuration: () => _editRest(_restingExercise),
                          onOpen: () => _openRestScreen(_restingExercise),
                        ),
                      );
                    },
                  ),
                  const _NotesField(),
                  const SizedBox(height: 12),
                  for (final ex in widget.exercises) ...[
                    _ExerciseCard(
                      exercise: ex,
                      history: widget.history,
                      onToggleExpand: () => setState(() => ex.expanded = !ex.expanded),
                      onSetToggled: (i, v) => _onSetToggled(ex, i, v),
                      onEditRest: () => _editRest(ex),
                      onToggleRest: (v) => setState(() => ex.restEnabled = v),
                      onStartRest: () => _startRest(ex),
                      onAddSet: () => setState(() {
                        final last = ex.sets.lastWhere((s) => !s.isWarmup, orElse: () => const SetRow());
                        ex.sets.add(SetRow(weight: last.weight, reps: last.reps));
                        ex.previous.add('—');
                        _addedSetTo = ex.name;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _DashedAction(
                    icon: Icons.add,
                    label: context.t.addExercise,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.routineName, required this.elapsed, required this.rest, required this.onFinish});

  final String routineName;
  final Duration elapsed;
  final RestTimer rest;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onFinish,
            icon: Icon(Icons.keyboard_arrow_down, color: c.text2),
            tooltip: context.t.minimise,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(routineName, style: Theme.of(context).textTheme.titleLarge),
                Text(
                    context.t.elapsedOf(
                        '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}'),
                    style: TextStyle(fontSize: 12, color: c.text2)),
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

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.history,
    required this.onToggleExpand,
    required this.onSetToggled,
    required this.onEditRest,
    required this.onToggleRest,
    required this.onStartRest,
    required this.onAddSet,
  });

  final SessionExercise exercise;
  final List<Workout> history;
  final VoidCallback onToggleExpand;
  final void Function(int index, bool done) onSetToggled;
  final VoidCallback onEditRest;
  final ValueChanged<bool> onToggleRest;
  final VoidCallback onStartRest;
  final VoidCallback onAddSet;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final ex = exercise;
    final p = nextPrescription(workouts: history, cfg: ex.config);

    return GymCard(
      radius: GymRadius.large,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ex.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 1),
                    Text(
                      ex.expanded
                          ? context.t.targetLine(formatWeight(ex.config.weight), ex.config.reps,
                              policyName[policyFor(ex.config)]!.toLowerCase())
                          : context.t
                              .setsTarget(ex.workCount, formatWeight(ex.config.weight), ex.config.reps),
                      style: TextStyle(fontSize: 12, color: c.text2),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggleExpand,
                icon: Icon(ex.expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: c.text2),
                tooltip: ex.expanded ? 'Collapse' : 'Expand',
              ),
              Icon(Icons.more_vert, size: 18, color: c.text2),
            ],
          ),
          if (ex.expanded) ...[
            const SizedBox(height: 12),
            _RestRow(exercise: ex, onEdit: onEditRest, onToggle: onToggleRest, onStart: onStartRest),
            const SizedBox(height: 10),
            _WhyBanner(text: p.why, kind: p.kind),
            const SizedBox(height: 12),
            _SetTable(exercise: ex, onToggled: onSetToggled),
            const SizedBox(height: 10),
            _DashedAction(icon: Icons.add, label: context.t.addSet, onTap: onAddSet, compact: true),
          ],
        ],
      ),
    );
  }
}

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

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: c.bgNested,
        borderRadius: BorderRadius.circular(GymRadius.small),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 17, color: c.text2),
          const SizedBox(width: 10),
          Text(context.t.restTimer, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(width: 10),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(GymRadius.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                  const SizedBox(width: 5),
                  Icon(Icons.edit_outlined, size: 14, color: c.text2),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Mulai istirahat tanpa harus mencentang set dulu — kadang orang
          // istirahat di tengah, atau baru ingat menekan setelah mulai.
          if (exercise.restEnabled)
            GymButton(
              label: context.t.start,
              height: 32,
              expand: false,
              shape: GymButtonShape.pill,
              onPressed: onStart,
            ),
          Switch(value: exercise.restEnabled, onChanged: onToggle),
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
  const _SetTable({required this.exercise, required this.onToggled});

  final SessionExercise exercise;
  final void Function(int index, bool done) onToggled;

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
              padding: const EdgeInsets.only(bottom: 6),
              child: _SetRowTile(
                label: s.isWarmup ? 'W' : '$workIndex',
                labelColor: s.isWarmup ? c.warn : c.doneInk,
                previous: i < exercise.previous.length ? exercise.previous[i] : '—',
                set: s,
                onToggled: (v) => onToggled(i, v),
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
    required this.onToggled,
  });

  final String label;
  final Color labelColor;
  final String previous;
  final SetRow set;
  final ValueChanged<bool> onToggled;

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
            child: Text(previous, style: TextStyle(fontSize: 12, color: c.text2)),
          ),
          Expanded(child: _Cell(value: formatWeight(set.weight), done: done)),
          Expanded(child: _Cell(value: '${set.reps}', done: done)),
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
  const _Cell({required this.value, required this.done});

  final String value;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final style = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: c.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    if (done) return Center(child: Text(value, style: style));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: TextFormField(
        initialValue: value,
        textAlign: TextAlign.center,
        style: style,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: c.surface2,
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
