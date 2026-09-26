/// Edit satu sesi yang sudah tercatat (FR-F1, FR-E2).
///
/// Log adalah fakta, tapi fakta yang salah ketik harus bisa dibetulkan:
/// 600 kg yang mestinya 60 dulu jadi "PR e1RM 800 kg" selamanya, dan target
/// sesi berikutnya ikut kacau. Karena target selalu dihitung ulang dari
/// riwayat, memperbaiki satu set di sini otomatis memperbaiki target berikutnya.
library;

import 'package:flutter/material.dart';
import '../../core/weights.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../domain/models.dart';
import '../../domain/program.dart';

class WorkoutEditScreen extends StatefulWidget {
  const WorkoutEditScreen({super.key, required this.workout, required this.catalog});

  final Workout workout;
  final ExerciseCatalog catalog;

  @override
  State<WorkoutEditScreen> createState() => _WorkoutEditScreenState();
}

class _WorkoutEditScreenState extends State<WorkoutEditScreen> {
  late String _date = widget.workout.date;
  late final List<List<SetRow>> _sets = [for (final e in widget.workout.entries) List.of(e.sets)];
  late final _notes = TextEditingController(text: widget.workout.notes ?? '');
  late final _entryNotes = [for (final e in widget.workout.entries) TextEditingController(text: e.note ?? '')];

  /// Satu kunci per baris supaya kotak input tidak bertukar isi saat baris
  /// dihapus.
  late final List<List<Key>> _keys = [
    for (final s in _sets) [for (var i = 0; i < s.length; i++) UniqueKey()],
  ];

  @override
  void dispose() {
    _notes.dispose();
    for (final c in _entryNotes) {
      c.dispose();
    }
    super.dispose();
  }

  Workout get _result {
    final entries = <WorkoutEntry>[];
    for (final (i, e) in widget.workout.entries.indexed) {
      final note = _entryNotes[i].text.trim();
      entries.add(e.copyWith(sets: _sets[i], note: note.isEmpty ? null : note, clearNote: note.isEmpty));
    }
    final notes = _notes.text.trim();
    return widget.workout.copyWith(
      date: _date,
      entries: entries,
      notes: notes.isEmpty ? null : notes,
      clearNotes: notes.isEmpty,
    );
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = isoDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: c.text2),
                    tooltip: t.cancel,
                  ),
                  Expanded(child: Text(t.editSession, style: Theme.of(context).textTheme.titleLarge)),
                  GymButton(
                    label: t.save,
                    height: 38,
                    expand: false,
                    shape: GymButtonShape.pill,
                    onPressed: () => Navigator.of(context).pop(_result),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  SettingsGroup(children: [
                    SettingsTile(icon: Icons.event, label: widget.workout.routine ?? t.freestyleSession, value: _date,
                        onTap: _pickDate),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: t.notesLabel),
                  ),
                  const SizedBox(height: 16),
                  for (final (i, e) in widget.workout.entries.indexed) ...[
                    GymCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.catalog.nameOf(e.exerciseId), style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          for (var j = 0; j < _sets[i].length; j++)
                            _EditRow(
                              key: _keys[i][j],
                              set: _sets[i][j],
                              timed: (e.target?.mode ?? LogMode.reps) == LogMode.time,
                              onChanged: (s) => _sets[i][j] = s,
                              onToggle: () => setState(() => _sets[i][j] = _sets[i][j].copyWith(done: !_sets[i][j].done)),
                              onDelete: () => setState(() {
                                _sets[i].removeAt(j);
                                _keys[i].removeAt(j);
                              }),
                            ),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              final last = _sets[i].lastWhere((s) => s.isWork, orElse: () => const SetRow());
                              _sets[i].add(SetRow(weight: last.weight, reps: last.reps, seconds: last.seconds, done: true));
                              _keys[i].add(UniqueKey());
                            }),
                            icon: Icon(Icons.add, size: 16, color: c.accent),
                            label: Text(t.addSet, style: TextStyle(color: c.accent, fontWeight: FontWeight.w700)),
                          ),
                          TextField(
                            controller: _entryNotes[i],
                            decoration: InputDecoration(hintText: t.exerciseNoteHint, isDense: true),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    super.key,
    required this.set,
    required this.timed,
    required this.onChanged,
    required this.onToggle,
    required this.onDelete,
  });

  final SetRow set;
  final bool timed;
  final ValueChanged<SetRow> onChanged;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final label = switch (set.phase) {
      SetPhase.warmup => 'W',
      SetPhase.drop => 'D',
      SetPhase.restPause => 'RP',
      SetPhase.work => '•',
    };
    InputDecoration deco(String hint) => InputDecoration(
          isDense: true,
          hintText: hint,
          filled: true,
          fillColor: c.surface2,
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(GymRadius.input), borderSide: BorderSide.none),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: set.isWork ? c.text2 : c.warn)),
          ),
          Expanded(
            child: TextFormField(
              initialValue: set.weight == 0 ? '' : context.wDelta(set.weight),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              textAlign: TextAlign.center,
              decoration: deco(context.unitLabel),
              onChanged: (v) =>
                  onChanged(set.copyWith(weight: context.typedToKg(double.tryParse(v.replaceAll(',', '.')) ?? 0))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: timed ? (set.seconds == 0 ? '' : '${set.seconds}') : (set.reps == 0 ? '' : '${set.reps}'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: deco(timed ? 's' : 'reps'),
              onChanged: (v) => onChanged(
                  timed ? set.copyWith(seconds: int.tryParse(v) ?? 0) : set.copyWith(reps: int.tryParse(v) ?? 0)),
            ),
          ),
          IconButton(
            onPressed: onToggle,
            visualDensity: VisualDensity.compact,
            icon: Icon(set.done ? Icons.check_circle : Icons.circle_outlined,
                color: set.done ? c.doneInk : c.text3, size: 22),
          ),
          IconButton(
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, color: c.text3, size: 18),
          ),
        ],
      ),
    );
  }
}
