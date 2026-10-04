/// Aksi satu rutinitas — edit gerakan, ganti nama, duplikat, jadikan
/// berikutnya, hapus — beserta dialognya. Dipakai lembar Mulai sesi (tombol ⋯
/// di tiap baris) dan tab Program (tahan kartu), supaya kedua tempat itu
/// menawarkan hal yang sama.
library;

import 'package:flutter/material.dart';

import '../../core/gym_icons.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/program.dart';
import 'routine_editor_screen.dart';

enum RoutineAction { edit, rename, duplicate, makeNext, delete }

/// Buka editor rutinitas dan terapkan hasilnya ke store.
Future<void> openRoutineEditor(BuildContext context, Routine routine) async {
  final store = WorkoutScope.read(context);
  final result = await Navigator.of(context).push<RoutineEditorResult>(
    MaterialPageRoute(builder: (_) => RoutineEditorScreen(routine: routine)),
  );
  switch (result) {
    case RoutineDeleted():
      await store.deleteRoutine(routine.id);
    case RoutineSaved(:final routine):
      await store.saveRoutine(routine);
    case null:
      break;
  }
}

Future<String?> askRoutineName(BuildContext context, String title, {String initial = ''}) => showDialog<String>(
      context: context,
      builder: (_) => RoutineNameDialog(title: title, initial: initial),
    );

/// Lembar aksi untuk [routine]; menjalankan aksi yang dipilih.
Future<void> showRoutineActions(BuildContext context, Routine routine) async {
  final store = WorkoutScope.read(context);
  final program = store.program;
  final next = store.nextSessionOn(DateTime.now());
  final inProgram = program != null && programRoutines(program, store.routines).any((r) => r.id == routine.id);
  final canMakeNext = inProgram && program.mode == ProgramMode.rotation && next?.routine.id != routine.id;

  final action = await showModalBottomSheet<RoutineAction>(
    context: context,
    backgroundColor: context.gym.bg,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet))),
    builder: (sheet) {
      final c = sheet.gym;
      final t = sheet.t;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(routine.name, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 12),
              SettingsGroup(children: [
                SettingsTile(icon: GymIcons.sliders, label: t.editExercises, onTap: () => Navigator.of(sheet).pop(RoutineAction.edit)),
                SettingsTile(icon: GymIcons.edit, label: t.rename, onTap: () => Navigator.of(sheet).pop(RoutineAction.rename)),
                SettingsTile(icon: GymIcons.copy, label: t.duplicate, onTap: () => Navigator.of(sheet).pop(RoutineAction.duplicate)),
                if (canMakeNext)
                  SettingsTile(icon: GymIcons.skip, label: t.setAsNext, onTap: () => Navigator.of(sheet).pop(RoutineAction.makeNext)),
                SettingsTile(
                  icon: GymIcons.trash,
                  label: t.deleteWord,
                  tone: c.danger,
                  onTap: () => Navigator.of(sheet).pop(RoutineAction.delete),
                ),
              ]),
            ],
          ),
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case RoutineAction.edit:
      await openRoutineEditor(context, routine);
    case RoutineAction.rename:
      final name = await askRoutineName(context, context.t.renameRoutine, initial: routine.name);
      if (name == null || name.trim().isEmpty) return;
      await store.saveRoutine(routine.copyWith(name: name.trim()));
    case RoutineAction.duplicate:
      await store.duplicateRoutine(routine.id, '${routine.name} copy');
    case RoutineAction.makeNext:
      await store.setNext(routine.id);
    case RoutineAction.delete:
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => ConfirmDeleteRoutineDialog(name: routine.name),
      );
      if (ok == true) await store.deleteRoutine(routine.id);
  }
}

class RoutineNameDialog extends StatefulWidget {
  const RoutineNameDialog({super.key, required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<RoutineNameDialog> createState() => _RoutineNameDialogState();
}

class _RoutineNameDialogState extends State<RoutineNameDialog> {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.card)),
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

class ConfirmDeleteRoutineDialog extends StatelessWidget {
  const ConfirmDeleteRoutineDialog({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.card)),
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
