/// Editor rutinitas — artboard `06 Routine Editor`.
///
/// Di sinilah target dibekukan: sets, rep range, increment, rest, dan policy
/// progresi per gerakan. Nilai-nilai inilah yang nanti dibaca mesin progresi.
library;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../data/demo.dart';

/// Apa yang terjadi di editor, dikembalikan ke layar Workout.
sealed class RoutineEditorResult {
  const RoutineEditorResult();

  static const deleted = RoutineDeleted();
  factory RoutineEditorResult.saved(String name) = RoutineSaved;
}

class RoutineDeleted extends RoutineEditorResult {
  const RoutineDeleted();
}

class RoutineSaved extends RoutineEditorResult {
  const RoutineSaved(this.name);
  final String name;
}

class RoutineEditorScreen extends StatefulWidget {
  const RoutineEditorScreen({super.key, required this.routineName});

  final String routineName;

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late final List<EditableExercise> _exercises = demoEditableExercises();
  late final _nameController = TextEditingController(text: widget.routineName);
  int _expanded = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _deleteRoutine() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final c = context.gym;
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
          title: Text(context.t.deleteRoutineTitle(_nameController.text),
              style: Theme.of(context).textTheme.titleLarge),
          content: Text(
            'The routine and its exercise targets are removed. Sessions you '
            'already logged with it stay in your history.',
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
      },
    );
    if (ok != true || !mounted) return;
    // Layar Workout memegang daftarnya, jadi hasilnya dikembalikan lewat pop
    // dan penghapusan sebenarnya terjadi di sana — satu tempat yang memiliki
    // daftar, bukan dua yang saling menebak.
    Navigator.of(context).pop(RoutineEditorResult.deleted);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back, color: c.text2),
                    tooltip: context.t.back,
                  ),
                  Expanded(child: Text(context.t.editRoutine, style: Theme.of(context).textTheme.titleLarge)),
                  GymButton(
                    label: context.t.save,
                    height: 36,
                    expand: false,
                    shape: GymButtonShape.pill,
                    onPressed: () {
                      // Belum ada store: katakan apa adanya alih-alih menutup
                      // layar seolah-olah tersimpan.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.t.keptInMemory)),
                      );
                      Navigator.of(context).pop(RoutineEditorResult.saved(_nameController.text.trim()));
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  GymCard(
                    radius: GymRadius.control,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(context.t.routineName),
                        TextField(
                          controller: _nameController,
                          style: Theme.of(context).textTheme.titleLarge,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MetaCard(
                          icon: Icons.trending_up,
                          label: context.t.defaultPolicy,
                          value: 'Double progression',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetaCard(icon: Icons.timer_outlined, label: context.t.defaultRest, value: '120 s'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionLabel(context.t.exercisesCount(_exercises.length)),
                  const SizedBox(height: 10),
                  for (final (i, ex) in _exercises.indexed) ...[
                    _ExerciseEditor(
                      exercise: ex,
                      expanded: i == _expanded,
                      onToggle: () => setState(() => _expanded = i == _expanded ? -1 : i),
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 4),
                  _AddExercise(onTap: () {}),
                  const SizedBox(height: 24),
                  GymButton(
                    label: context.t.deleteRoutine,
                    icon: Icons.delete_outline,
                    tone: GymButtonTone.danger,
                    onPressed: _deleteRoutine,
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

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return GymCard(
      radius: GymRadius.card,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: c.text2),
              const SizedBox(width: 6),
              Expanded(child: SectionLabel(label)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
        ],
      ),
    );
  }
}

class _ExerciseEditor extends StatelessWidget {
  const _ExerciseEditor({
    required this.exercise,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
  });

  final EditableExercise exercise;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  String get _summary {
    final cfg = exercise.config;
    final reps = cfg.repsMin == null ? '${cfg.reps}' : '${cfg.repsMin}–${cfg.reps}';
    final policy = policyName[cfg.policy ?? ProgressionPolicy.linear]!.split(' ').first.toLowerCase();
    return '${cfg.sets} × $reps · ${formatWeight(cfg.weight)} kg · $policy';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final cfg = exercise.config;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.card),
        border: Border.all(color: expanded ? c.accent : c.border),
      ),
      padding: EdgeInsets.fromLTRB(10, 10, 10, expanded ? 14 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Pegangan geser — mengubah urutan gerakan belum aktif, tapi
              // tempatnya sudah benar supaya tata letaknya tidak bergeser nanti.
              Icon(Icons.drag_indicator, size: 18, color: c.text3),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(expanded ? '${exercise.muscle} · ${exercise.gear}' : _summary,
                        style: TextStyle(fontSize: 12.5, color: c.text2)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggle,
                icon: Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: c.text2),
                tooltip: expanded ? context.t.collapse : context.t.expand,
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StepperField(
                    label: context.t.sets,
                    value: '${cfg.sets}',
                    onMinus: () {
                      exercise.config = cfg.copyWith(sets: (cfg.sets - 1).clamp(1, 12));
                      onChanged();
                    },
                    onPlus: () {
                      exercise.config = cfg.copyWith(sets: (cfg.sets + 1).clamp(1, 12));
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ReadField(
                    label: context.t.reps,
                    value: cfg.repsMin == null ? '${cfg.reps}' : '${cfg.repsMin} – ${cfg.reps}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _ReadField(label: context.t.increment, value: '${formatDelta(exercise.increment)} kg')),
                const SizedBox(width: 10),
                Expanded(child: _ReadField(label: context.t.rest, value: '${exercise.restSeconds} s')),
              ],
            ),
            const SizedBox(height: 12),
            SectionLabel(context.t.progressionPolicy),
            const SizedBox(height: 6),
            _PolicyPicker(
              value: cfg.policy ?? ProgressionPolicy.linear,
              mode: cfg.mode,
              onChanged: (p) {
                exercise.config = cfg.copyWith(policy: p);
                onChanged();
              },
            ),
            const SizedBox(height: 14),
            SectionLabel(context.t.intensifiers),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final name in ['Drop set', 'Rest-pause', 'Superset']) ...[
                  _Intensifier(
                    label: name,
                    on: exercise.intensifiers.contains(name),
                    onTap: () {
                      exercise.intensifiers.contains(name)
                          ? exercise.intensifiers.remove(name)
                          : exercise.intensifiers.add(name);
                      onChanged();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({required this.label, required this.value, required this.onMinus, required this.onPlus});

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(GymRadius.segment),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              IconButton(onPressed: onMinus, icon: Icon(Icons.remove, size: 18, color: c.accent), tooltip: context.t.fewer),
              Expanded(
                child: Center(
                  child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
                ),
              ),
              IconButton(onPressed: onPlus, icon: Icon(Icons.add, size: 18, color: c.accent), tooltip: context.t.more),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nilai yang belum bisa diubah dari layar ini. Ditulis biasa, bukan disamarkan
/// sebagai input — tombol yang tidak melakukan apa-apa lebih buruk daripada
/// tidak ada tombol.
class _ReadField extends StatelessWidget {
  const _ReadField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 6),
        Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(GymRadius.segment),
            border: Border.all(color: c.border),
          ),
          child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
        ),
      ],
    );
  }
}

class _PolicyPicker extends StatelessWidget {
  const _PolicyPicker({required this.value, required this.mode, required this.onChanged});

  final ProgressionPolicy value;
  final LogMode mode;
  final ValueChanged<ProgressionPolicy> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final options = policiesFor[mode] ?? const [ProgressionPolicy.off];
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(GymRadius.segment),
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProgressionPolicy>(
          value: options.contains(value) ? value : options.first,
          isExpanded: true,
          dropdownColor: c.surface2,
          borderRadius: BorderRadius.circular(GymRadius.control),
          icon: Icon(Icons.keyboard_arrow_down, color: c.text2),
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.text),
          items: [
            for (final p in options)
              DropdownMenuItem(value: p, child: Text(policyName[p]!)),
          ],
          onChanged: (p) => p == null ? null : onChanged(p),
        ),
      ),
    );
  }
}

class _Intensifier extends StatelessWidget {
  const _Intensifier({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Material(
      color: on ? c.accentSoft : c.surface2,
      borderRadius: BorderRadius.circular(GymRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.pill),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.pill),
            border: Border.all(color: on ? c.accent : c.border),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? c.accent : c.text2),
          ),
        ),
      ),
    );
  }
}

class _AddExercise extends StatelessWidget {
  const _AddExercise({required this.onTap});

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
              Text(context.t.addExercise,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: c.accent)),
            ],
          ),
        ),
      ),
    );
  }
}
