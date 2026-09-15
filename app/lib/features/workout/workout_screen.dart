/// Tab Workout — artboard `05 Workout Tab`.
library;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/demo.dart';
import '../library/library_screen.dart';
import '../session/session_screen.dart';
import 'routine_editor_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int _tab = 0;

  /// Salinan yang bisa diubah. Saat store Supabase masuk, daftar ini diganti
  /// oleh state asli dan CRUD di bawah menulis ke sana.
  late final List<DemoRoutine> _routines = demoRoutines();

  Future<String?> _askName(String title, {String initial = ''}) => showDialog<String>(
        context: context,
        builder: (_) => _NameDialog(title: title, initial: initial),
      );

  Future<void> _newRoutine() async {
    final name = await _askName(context.t.newRoutineTitle);
    if (name == null || name.trim().isEmpty) return;
    // Rutinitas baru mulai kosong — 0 gerakan, bukan menyalin diam-diam isi
    // rutinitas lain yang kebetulan ada.
    setState(() => _routines.add(DemoRoutine(name.trim(), 0, 0)));
  }

  Future<void> _openEditor(DemoRoutine r) async {
    final result = await Navigator.of(context).push<RoutineEditorResult>(
      MaterialPageRoute(builder: (_) => RoutineEditorScreen(routineName: r.name)),
    );
    if (!mounted) return;
    switch (result) {
      case RoutineDeleted():
        setState(() {
          final wasNext = r.isNext;
          _routines.remove(r);
          if (wasNext && _routines.isNotEmpty) _routines.first.isNext = true;
        });
      case RoutineSaved(:final name) when name.isNotEmpty:
        setState(() => r.name = name);
      case _:
        break;
    }
  }

  Future<void> _rename(DemoRoutine r) async {
    final name = await _askName(context.t.renameRoutine, initial: r.name);
    if (name == null || name.trim().isEmpty) return;
    setState(() => r.name = name.trim());
  }

  void _duplicate(DemoRoutine r) {
    setState(() => _routines.insert(_routines.indexOf(r) + 1, r.copy('${r.name} copy')));
  }

  Future<void> _delete(DemoRoutine r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDeleteDialog(name: r.name),
    );
    if (ok != true) return;
    setState(() {
      final wasNext = r.isNext;
      _routines.remove(r);
      // Kalau yang dihapus adalah rutinitas berikutnya, cursor harus pindah —
      // kalau tidak, program kehilangan penunjuk dan Home tidak tahu apa-apa
      // yang harus dikerjakan.
      if (wasNext && _routines.isNotEmpty) _routines.first.isNext = true;
    });
  }

  void _openSession(String routineName) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SessionScreen(
        routineName: routineName,
        exercises: demoExercises(),
        history: demoHistory,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ScreenHeader(
          title: context.t.workout,
          actions: [
            SquareIconButton(icon: Icons.folder_outlined, onPressed: () {}),
            SquareIconButton(icon: Icons.add, tone: c.accent, onPressed: _newRoutine),
          ],
        ),
        SegmentedTabs(
          labels: [context.t.tracker, context.t.myPlan],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 16),
        if (_tab == 0) ..._tracker(context) else ..._plan(context),
      ],
    );
  }

  List<Widget> _tracker(BuildContext context) {
    final c = context.gym;
    return [
      GymCard(
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
                  Text(context.t.libraryFiltered(formatCount(demoExerciseCount), 'Gym A'),
                      style: TextStyle(fontSize: 12.5, color: c.text2)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(GymRadius.small),
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()),
                ),
                borderRadius: BorderRadius.circular(GymRadius.small),
                child: SizedBox(width: 42, height: 42, child: Icon(Icons.fitness_center, size: 20, color: c.accent)),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Text(context.t.newWorkout, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _StartCard(
              icon: Icons.bolt,
              title: context.t.startEmpty,
              detail: context.t.freestyleLog,
              onTap: () => _openSession('Freestyle'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StartCard(
              icon: Icons.playlist_play,
              title: context.t.fromProgram,
              detail: context.t.isNext(demoRoutineName),
              onTap: () => _openSession(demoRoutineName),
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
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: c.bgNested,
          borderRadius: BorderRadius.circular(GymRadius.control),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(context.t.rotationOf('Push / Pull / Legs'), style: TextStyle(fontSize: 13, color: c.text2)),
            ),
            // Posisi cursor di rotasi (FR-B3) — "rutinitas ke berapa dari
            // berapa", bukan progres sesi hari ini.
            Text('${_routines.indexWhere((r) => r.isNext) + 1} / ${_routines.length}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.accent)),
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (_routines.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(context.t.noRoutines,
                style: TextStyle(fontSize: 13.5, color: c.text2)),
          ),
        )
      else
        for (final r in _routines) ...[
          _RoutineRow(
            routine: r,
            onTap: () => _openSession(r.name),
            onAction: (action) => switch (action) {
              _RoutineAction.edit => _openEditor(r),
              _RoutineAction.rename => _rename(r),
              _RoutineAction.duplicate => _duplicate(r),
              _RoutineAction.delete => _delete(r),
            },
          ),
          const SizedBox(height: 10),
        ],
      const SizedBox(height: 4),
      _AddRoutineRow(onTap: _newRoutine),
    ];
  }

  List<Widget> _plan(BuildContext context) {
    final c = context.gym;
    return [
      GymCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(context.t.activeProgram),
            const SizedBox(height: 10),
            Text('Push / Pull / Legs', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(context.t.rotationNote,
                style: TextStyle(fontSize: 13, color: c.text2)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SettingsGroup(
        children: [
          for (final r in _routines)
            SettingsTile(
              icon: r.isNext ? Icons.play_circle_outline : Icons.circle_outlined,
              label: r.name,
              value: '${r.exercises} exercises',
              onTap: () => _openEditor(r),
            ),
        ],
      ),
      const SizedBox(height: 14),
      NoteBanner(
        text: 'Rotation order and the rest-day rule are not wired up yet — the cursor above is fixed.',
        icon: Icons.construction_outlined,
        tone: c.warn,
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
    return Material(
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
              Icon(Icons.add, size: 17, color: c.accent),
              const SizedBox(width: 8),
              Text(context.t.newRoutine,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: c.accent)),
            ],
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
    return Material(
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
    );
  }
}

enum _RoutineAction { edit, rename, duplicate, delete }

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.routine, required this.onTap, required this.onAction});

  final DemoRoutine routine;
  final VoidCallback onTap;
  final ValueChanged<_RoutineAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(GymRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 6, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.card),
            border: Border.all(color: routine.isNext ? c.accent : c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(routine.name, style: Theme.of(context).textTheme.titleLarge),
                        if (routine.isNext) ...[
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
                    Text(context.t.routineMeta(routine.exercises, routine.sets),
                        style: TextStyle(fontSize: 12.5, color: c.text2)),
                  ],
                ),
              ),
              PopupMenuButton<_RoutineAction>(
                icon: Icon(Icons.more_vert, size: 18, color: c.text2),
                tooltip: context.t.routineActions,
                color: c.surface2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.control)),
                onSelected: onAction,
                itemBuilder: (context) => [
                  _item(c, _RoutineAction.edit, Icons.tune, context.t.editExercises),
                  _item(c, _RoutineAction.rename, Icons.drive_file_rename_outline, context.t.rename),
                  _item(c, _RoutineAction.duplicate, Icons.copy_all_outlined, context.t.duplicate),
                  _item(c, _RoutineAction.delete, Icons.delete_outline, context.t.deleteWord, tone: c.danger),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
