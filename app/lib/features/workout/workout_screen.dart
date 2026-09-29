/// Tab Workout — artboard `05 Workout Tab`.
library;

import 'package:flutter/material.dart';
import '../../core/gym_icons.dart';

import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/program.dart';
import '../library/library_screen.dart';
import '../onboarding/program_flow.dart';
import '../session/session_launcher.dart';
import 'routine_editor_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int _tab = 0;

  Future<String?> _askName(String title, {String initial = ''}) => showDialog<String>(
        context: context,
        builder: (_) => _NameDialog(title: title, initial: initial),
      );

  Future<void> _newRoutine() async {
    final store = context.workouts;
    final name = await _askName(context.t.newRoutineTitle);
    if (name == null || name.trim().isEmpty || !mounted) return;
    // Rutinitas baru mulai kosong dan langsung dibuka di editor — rutinitas
    // tanpa gerakan tidak berguna, jadi langkah berikutnya jelas.
    // Double progression: gerakan baru di editor datang dengan rentang 8–12,
    // dan linear mengabaikan rentang itu.
    final routine = Routine(id: WorkoutStore.newRoutineId(), name: name.trim(), policy: ProgressionPolicy.double_);
    await store.saveRoutine(routine);
    if (mounted) await _openEditor(routine);
  }

  Future<void> _openEditor(Routine r) async {
    final store = context.workouts;
    final result = await Navigator.of(context).push<RoutineEditorResult>(
      MaterialPageRoute(builder: (_) => RoutineEditorScreen(routine: r)),
    );
    switch (result) {
      case RoutineDeleted():
        await store.deleteRoutine(r.id);
      case RoutineSaved(:final routine):
        await store.saveRoutine(routine);
      case null:
        break;
    }
  }

  Future<void> _rename(Routine r) async {
    final store = context.workouts;
    final name = await _askName(context.t.renameRoutine, initial: r.name);
    if (name == null || name.trim().isEmpty) return;
    await store.saveRoutine(r.copyWith(name: name.trim()));
  }

  Future<void> _duplicate(Routine r) => context.workouts.duplicateRoutine(r.id, '${r.name} copy');

  Future<void> _delete(Routine r) async {
    final store = context.workouts;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDeleteDialog(name: r.name),
    );
    if (ok != true) return;
    await store.deleteRoutine(r.id);
  }

  Future<void> _start(Routine r) async {
    if (r.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.emptyRoutineHint)));
      await _openEditor(r);
      return;
    }
    await openRoutineSession(context, r);
  }

  Future<void> _changeProgram() => chooseProgram(context);

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ScreenHeader(
          title: context.t.workout,
          actions: [
            SquareIconButton(icon: GymIcons.plus, tone: c.accent, onPressed: _newRoutine),
          ],
        ),
        SegmentedTabs(
          labels: [context.t.tracker, context.t.myPlan],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 16),
        // Isi tab memudar saat berganti, dan Column-nya diberi key supaya
        // AnimatedSwitcher tahu ini isi yang berbeda, bukan isi lama diubah.
        FadeSwap(
          child: Column(
            key: ValueKey(_tab),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _tab == 0 ? _tracker(context) : _plan(context),
          ),
        ),
      ],
    );
  }

  List<Widget> _tracker(BuildContext context) {
    final c = context.gym;
    final store = context.workouts;
    final program = store.program;
    final routines = program == null ? store.routines : programRoutines(program, store.routines);
    final next = store.nextSessionOn(DateTime.now());

    // Kartu-kartu datang bertingkat dari atas ke bawah saat tab terbuka:
    // library dulu, lalu dua kartu mulai, lalu daftar rutinitas satu per satu.
    return [
      Reveal(
        child: GymCard(
          radius: GymRadius.large,
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t.exerciseLibrary, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 3),
                    FutureBuilder<ExerciseCatalog>(
                      future: ExerciseCatalog.load(),
                      builder: (context, snap) => Text(
                        context.t.libraryCount(formatCount(snap.data?.all.length ?? 1324)),
                        style: TextStyle(fontSize: 12.5, color: c.text2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PressScale(
                scale: 0.92,
                child: Material(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(GymRadius.small),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()),
                    ),
                    borderRadius: BorderRadius.circular(GymRadius.small),
                    child: SizedBox(width: 42, height: 42, child: Icon(GymIcons.dumbbell, size: 20, color: c.accent)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 22),
      Text(context.t.newWorkout, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Reveal(
              index: 1,
              child: _StartCard(
                icon: GymIcons.edit,
                title: context.t.startEmpty,
                detail: context.t.freestyleLog,
                onTap: () => openFreestyleSession(context, context.t.freestyle),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Reveal(
              index: 2,
              child: _StartCard(
                icon: GymIcons.play,
                title: context.t.fromProgram,
                detail: next == null ? context.t.noProgramYet : context.t.isNext(next.routine.name),
                onTap: next == null ? () => setState(() => _tab = 1) : () => _start(next.routine),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(child: Text(context.t.routines, style: Theme.of(context).textTheme.titleLarge)),
          TextButton(
            onPressed: () => setState(() => _tab = 1),
            child: Text(context.t.editProgram,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
          ),
        ],
      ),
      const SizedBox(height: 4),
      if (program != null && routines.isNotEmpty)
        Reveal(
          index: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: c.bgNested,
              borderRadius: BorderRadius.circular(GymRadius.control),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                      program.mode == ProgramMode.weekday
                          ? context.t.weekdayOf(program.name)
                          : context.t.rotationOf(program.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.text2)),
                ),
                // Posisi cursor di rotasi (FR-B3) — "rutinitas ke berapa dari
                // berapa", bukan progres sesi hari ini.
                if (next != null)
                  Text('${routines.indexWhere((r) => r.id == next.routine.id) + 1} / ${routines.length}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.accent)),
              ],
            ),
          ),
        ),
      const SizedBox(height: 10),
      if (routines.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text(context.t.noRoutines, style: TextStyle(fontSize: 13.5, color: c.text2))),
        )
      else
        for (final (i, r) in routines.indexed) ...[
          Reveal(
            index: i + 4,
            child: _RoutineRow(
              routine: r,
              isNext: next?.routine.id == r.id,
              canMakeNext: program?.mode == ProgramMode.rotation && next?.routine.id != r.id,
              onTap: () => _start(r),
              onAction: (action) => switch (action) {
                _RoutineAction.edit => _openEditor(r),
                _RoutineAction.rename => _rename(r),
                _RoutineAction.duplicate => _duplicate(r),
                _RoutineAction.makeNext => store.setNext(r.id),
                _RoutineAction.delete => _delete(r),
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      const SizedBox(height: 4),
      Reveal(index: routines.length + 4, child: _AddRoutineRow(onTap: _newRoutine)),
    ];
  }

  List<Widget> _plan(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final program = store.program;

    if (program == null) {
      return [
        GymCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.noProgramYet, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(t.noProgramHint, style: TextStyle(fontSize: 13, color: c.text2)),
              const SizedBox(height: 14),
              GymButton(label: t.choosePlan, onPressed: _changeProgram),
            ],
          ),
        ),
      ];
    }

    final routines = programRoutines(program, store.routines);
    final next = store.nextSessionOn(DateTime.now());

    Future<void> move(int i, int delta) async {
      final order = [...program.order];
      final j = i + delta;
      if (j < 0 || j >= order.length) return;
      final nextId = next?.routine.id;
      final item = order.removeAt(i);
      order.insert(j, item);
      // Cursor tetap menunjuk rutinitas yang sama setelah urutannya diubah.
      final cursor = nextId == null ? program.cursor : order.indexOf(nextId);
      await store.updateProgram(program.copyWith(order: order, cursor: cursor < 0 ? 0 : cursor));
    }

    return [
      Reveal(
        child: GymCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(t.activeProgram),
              const SizedBox(height: 10),
              Text(program.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                program.mode == ProgramMode.weekday
                    ? '${t.weekdayMode} · ${[for (final d in [...program.days]..sort()) t.weekdayShort(d)].join(', ')}'
                    : '${t.rotationMode} · ${t.restRule(program.minRestDays)}',
                style: TextStyle(fontSize: 13, color: c.text2),
              ),
              const SizedBox(height: 14),
              GymButton(
                label: t.changeProgram.toUpperCase(),
                icon: GymIcons.dataTransfer,
                tone: GymButtonTone.neutral,
                height: 44,
                onPressed: _changeProgram,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Jadwal bisa diganti kapan saja — dulu mode dan hari latihan terkunci
      // sejak program dibuat, dan satu-satunya jalan adalah menyusun ulang
      // split dari nol.
      Reveal(
        index: 1,
        child: GymCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(t.scheduleTitle),
              const SizedBox(height: 10),
              FilterChips(
                labels: [t.rotationMode, t.weekdayMode],
                index: program.mode == ProgramMode.weekday ? 1 : 0,
                onChanged: (i) {
                  final weekday = i == 1;
                  if (weekday == (program.mode == ProgramMode.weekday)) return;
                  store.updateProgram(program.copyWith(
                    mode: weekday ? ProgramMode.weekday : ProgramMode.rotation,
                    days: weekday && program.days.isEmpty ? const [1, 3, 5] : program.days,
                    clearSkip: true,
                  ));
                },
              ),
              if (program.mode == ProgramMode.weekday) ...[
                const SizedBox(height: 12),
                Text(t.trainingDays, style: TextStyle(fontSize: 12.5, color: c.text2)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(t.weekdayShort(d)),
                        selected: program.days.contains(d),
                        onSelected: (on) {
                          final days = {...program.days};
                          on ? days.add(d) : days.remove(d);
                          // Paling tidak satu hari: jadwal tanpa hari latihan
                          // bukan jadwal.
                          if (days.isEmpty) return;
                          store.updateProgram(program.copyWith(days: days.toList()..sort(), clearSkip: true));
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      if (program.mode == ProgramMode.rotation) ...[
        const SizedBox(height: 12),
        Reveal(
          index: 2,
          child: GymCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.restDaysBetween, style: Theme.of(context).textTheme.bodyLarge),
                      Text(t.restDaysValue(program.minRestDays), style: TextStyle(fontSize: 12.5, color: c.text2)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: program.minRestDays <= 0
                      ? null
                      : () => store.updateProgram(program.copyWith(minRestDays: program.minRestDays - 1)),
                  icon: Icon(Icons.remove, color: c.accent),
                  tooltip: t.fewer,
                ),
                IconButton(
                  onPressed: program.minRestDays >= 7
                      ? null
                      : () => store.updateProgram(program.copyWith(minRestDays: program.minRestDays + 1)),
                  icon: Icon(GymIcons.plus, color: c.accent),
                  tooltip: t.more,
                ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 18),
      SectionLabel(t.order),
      const SizedBox(height: 8),
      Reveal(
        index: 3,
        child: SettingsGroup(
          children: [
            for (final (i, r) in routines.indexed)
              _OrderRow(
                name: r.name,
                detail: [
                  t.exerciseCount(r.exercises.length),
                  if (program.mode == ProgramMode.weekday)
                    [for (final d in weekdaysOf(program, store.routines, r.id)) t.weekdayShort(d)].join(', '),
                ].where((s) => s.isNotEmpty).join(' · '),
                isNext: next?.routine.id == r.id,
                canUp: i > 0,
                canDown: i < routines.length - 1,
                onTap: () => _openEditor(r),
                onUp: () => move(i, -1),
                onDown: () => move(i, 1),
                onMakeNext: program.mode == ProgramMode.rotation ? () => store.setNext(r.id) : null,
              ),
          ],
        ),
      ),
    ];
  }
}

PopupMenuItem<_RoutineAction> _item(
  GymColors c,
  _RoutineAction value,
  IconData icon,
  String label, {
  Color? tone,
}) {
  return PopupMenuItem(
    value: value,
    height: 44,
    child: Row(
      children: [
        Icon(icon, size: 17, color: tone ?? c.text2),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tone ?? c.text)),
      ],
    ),
  );
}

/// Baris "rutinitas baru" di bawah daftar.
class _AddRoutineRow extends StatelessWidget {
  const _AddRoutineRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return PressScale(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(GymRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GymRadius.control),
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GymRadius.control),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(GymIcons.plus, size: 17, color: c.accent),
                const SizedBox(width: 8),
                Text(context.t.newRoutine,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: c.accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    OutlineInputBorder border(Color colour) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.control),
          borderSide: BorderSide(color: colour),
        );

    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
      title: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        style: TextStyle(fontSize: 15, color: c.text),
        decoration: InputDecoration(
          hintText: context.t.routineNameHint,
          hintStyle: TextStyle(fontSize: 15, color: c.text2),
          filled: true,
          fillColor: c.bgNested,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: border(c.border),
          enabledBorder: border(c.border),
          focusedBorder: border(c.accent),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
        ),
        GymButton(label: context.t.save, height: 42, expand: false, onPressed: _submit),
      ],
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
      title: Text(context.t.deleteRoutineTitle(name), style: Theme.of(context).textTheme.titleLarge),
      content: Text(
        // Katakan apa yang hilang dan apa yang tidak. Sesi yang sudah tercatat
        // adalah fakta dan tidak ikut terhapus bersama rencananya.
        context.t.deleteRoutineBody,
        style: TextStyle(fontSize: 13.5, height: 1.45, color: c.text2),
      ),
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
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.icon, required this.title, required this.detail, required this.onTap});

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return PressScale(
      child: Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(GymRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: Container(
          height: 104,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.card),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: c.text2),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(detail, style: TextStyle(fontSize: 12, color: c.text2)),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

enum _RoutineAction { edit, rename, duplicate, makeNext, delete }

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.routine,
    required this.isNext,
    required this.canMakeNext,
    required this.onTap,
    required this.onAction,
  });

  final Routine routine;
  final bool isNext;
  final bool canMakeNext;
  final VoidCallback onTap;
  final ValueChanged<_RoutineAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return PressScale(
      child: Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(GymRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: AnimatedContainer(
          duration: GymMotion.of(context, GymMotion.normal),
          padding: const EdgeInsets.fromLTRB(16, 13, 6, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.card),
            border: Border.all(color: isNext ? c.accent : c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(routine.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
                        ),
                        if (isNext) ...[
                          const SizedBox(width: 10),
                          Pill(
                            color: c.accentSoft,
                            textColor: c.accent,
                            child: Text(context.t.next, style: const TextStyle(fontSize: 10, letterSpacing: 0.8)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(context.t.routineMeta(routine.exercises.length, routine.setCount),
                        style: TextStyle(fontSize: 12.5, color: c.text2)),
                  ],
                ),
              ),
              PopupMenuButton<_RoutineAction>(
                icon: Icon(GymIcons.moreVertical, size: 18, color: c.text2),
                tooltip: context.t.routineActions,
                color: c.surface2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.control)),
                onSelected: onAction,
                itemBuilder: (context) => [
                  _item(c, _RoutineAction.edit, Icons.tune, context.t.editExercises),
                  _item(c, _RoutineAction.rename, Icons.drive_file_rename_outline, context.t.rename),
                  _item(c, _RoutineAction.duplicate, Icons.copy_all_outlined, context.t.duplicate),
                  if (canMakeNext) _item(c, _RoutineAction.makeNext, Icons.skip_next_outlined, context.t.setAsNext),
                  _item(c, _RoutineAction.delete, Icons.delete_outline, context.t.deleteWord, tone: c.danger),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Satu baris di urutan program: ketuk untuk mengedit, panah untuk memindah.
class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.name,
    required this.detail,
    required this.isNext,
    required this.canUp,
    required this.canDown,
    required this.onTap,
    required this.onUp,
    required this.onDown,
    this.onMakeNext,
  });

  final String name;
  final String detail;
  final bool isNext;
  final bool canUp;
  final bool canDown;
  final VoidCallback onTap;
  final VoidCallback onUp;
  final VoidCallback onDown;

  /// null di mode hari tetap: di sana hari yang menentukan, bukan cursor.
  final VoidCallback? onMakeNext;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        child: Row(
          children: [
            InkWell(
              onTap: isNext ? null : onMakeNext,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(isNext ? Icons.play_circle : Icons.circle_outlined,
                    size: 20, color: isNext ? c.accent : c.text3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(detail, style: TextStyle(fontSize: 12, color: c.text2)),
                ],
              ),
            ),
            IconButton(
              onPressed: canUp ? onUp : null,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.arrow_upward, size: 18, color: canUp ? c.text2 : c.text3),
              tooltip: context.t.moveUp,
            ),
            IconButton(
              onPressed: canDown ? onDown : null,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.arrow_downward, size: 18, color: canDown ? c.text2 : c.text3),
              tooltip: context.t.moveDown,
            ),
          ],
        ),
      ),
    );
  }
}
