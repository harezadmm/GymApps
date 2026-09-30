/// "Jadikan rutinitas": sesi yang sudah selesai disimpan sebagai rutinitas
/// baru (FR-B8), dari ringkasan selesai maupun sheet detail riwayat (FR-F1).
///
/// Dua pintu masuk, satu alur: tanya nama — terisi nama rutinitas sesi itu,
/// atau tanggalnya untuk sesi tanpa nama — dan di program mode rotasi (FR-B2)
/// tanya juga apakah rutinitas barunya masuk urutan sesi. Angkanya disusun
/// [routineFromWorkout] dari set yang tercentang, lalu disimpan lewat
/// [WorkoutStore.saveRoutine].
library;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/strings_history_extras.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/routine_from_workout.dart';

/// Jawaban dialog: nama yang diketik, dan apakah masuk urutan rotasi.
class SaveAsRoutineAnswer {
  const SaveAsRoutineAnswer(this.name, {required this.addToRotation});

  final String name;
  final bool addToRotation;
}

/// Tanya nama lalu simpan [workout] (kg) sebagai rutinitas baru. Mengembalikan
/// rutinitas yang dibuat, atau null kalau dibatalkan — atau kalau tidak ada
/// set tercentang yang bisa dijadikan rutinitas; kasus terakhir diberi tahu
/// lewat SnackBar di sini, karena pemanggil tidak bisa membedakannya dari
/// batal.
///
/// Butuh [WorkoutScope] di atas [context].
Future<Routine?> saveWorkoutAsRoutine(BuildContext context, Workout workout) async {
  final store = WorkoutScope.read(context);
  final t = context.t;
  // Disusun dulu, sebelum bertanya nama: sesi yang tidak menghasilkan satu
  // gerakan pun tidak perlu ditanyai apa-apa.
  final draft = routineFromWorkout(workout, id: '', name: '', isAssisted: ExerciseCatalog.assistedById);
  if (draft.exercises.isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(t.nothingToSaveAsRoutine)));
    return null;
  }
  final program = store.program;
  // Hanya rotasi yang punya "urutan" untuk ditawarkan. Di mode weekday dan
  // tanpa program, rutinitas baru masuk seperti rutinitas baru mana pun.
  final askRotation = program != null && program.mode == ProgramMode.rotation;
  final routineName = workout.routine?.trim() ?? '';
  final answer = await showDialog<SaveAsRoutineAnswer>(
    context: context,
    builder: (_) => SaveAsRoutineDialog(
      initialName: routineName.isEmpty ? workout.date : routineName,
      askRotation: askRotation,
    ),
  );
  final name = answer?.name.trim() ?? '';
  if (answer == null || name.isEmpty) return null;
  final routine = draft.copyWith(id: WorkoutStore.newRoutineId(), name: name);
  await store.saveRoutine(routine, addToProgram: !askRotation || answer.addToRotation);
  return routine;
}

/// Dialog nama rutinitas, dengan kotak "tambahkan ke rotasi" kalau
/// [askRotation]. Mengembalikan [SaveAsRoutineAnswer] lewat `pop`, atau null
/// kalau ditutup.
class SaveAsRoutineDialog extends StatefulWidget {
  const SaveAsRoutineDialog({super.key, required this.initialName, required this.askRotation});

  final String initialName;
  final bool askRotation;

  @override
  State<SaveAsRoutineDialog> createState() => _SaveAsRoutineDialogState();
}

class _SaveAsRoutineDialogState extends State<SaveAsRoutineDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  /// Tercentang sejak awal: tab Workout hanya menampilkan rutinitas yang ada
  /// di urutan program, jadi rutinitas di luar urutan hanya terlihat di
  /// lembar "sesi lain" di Home. Yang memang menginginkannya di luar rotasi
  /// tinggal mematikan kotaknya.
  bool _addToRotation = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(SaveAsRoutineAnswer(_controller.text, addToRotation: _addToRotation));

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    OutlineInputBorder border(Color colour) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.control),
          borderSide: BorderSide(color: colour),
        );

    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
      title: Text(t.saveAsRoutine, style: Theme.of(context).textTheme.titleLarge),
      // Selebar dialognya: Column di dalam AlertDialog diukur dari anak
      // terlebarnya, dan TextField tanpa lebar pasti bisa menyempit.
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.saveAsRoutineHint, style: TextStyle(fontSize: 12.5, height: 1.35, color: c.text2)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submit(),
              style: TextStyle(fontSize: 15, color: c.text),
              decoration: InputDecoration(
                hintText: t.routineNameHint,
                hintStyle: TextStyle(fontSize: 15, color: c.text2),
                filled: true,
                fillColor: c.bgNested,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: border(c.border),
                enabledBorder: border(c.border),
                focusedBorder: border(c.accent),
              ),
            ),
            if (widget.askRotation) ...[
              const SizedBox(height: 6),
              // CheckboxListTile: seluruh barisnya bisa diketuk dan tingginya
              // ≥ 48 dp (NFR-11), bukan kotak 18 dp yang harus dibidik.
              CheckboxListTile(
                value: _addToRotation,
                onChanged: (v) => setState(() => _addToRotation = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: c.accent,
                title: Text(t.addToRotation, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                subtitle: Text(t.addToRotationHint, style: TextStyle(fontSize: 12, height: 1.3, color: c.text2)),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
        ),
        GymButton(label: t.save, height: 44, expand: false, onPressed: _submit),
      ],
    );
  }
}
