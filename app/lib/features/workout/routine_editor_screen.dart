/// Editor rutinitas — artboard `06 Routine Editor`.
///
/// Di sinilah target dibekukan: sets, rep range, beban awal, increment, rest,
/// warm-up, dan policy progresi per gerakan. Nilai-nilai inilah yang nanti
/// dibaca mesin progresi.
///
/// Editor tidak menyimpan sendiri. Hasilnya dikembalikan lewat `pop`, dan
/// pemanggil yang memutuskan ke mana perginya: tab Workout menulis ke store,
/// layar "susun split sendiri" menampungnya dulu sampai onboarding selesai.
library;

import 'package:flutter/material.dart';
import '../../core/weights.dart';
import '../../domain/units.dart';

import '../../core/format.dart';
import '../../core/gym_icons.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../domain/models.dart';
import '../../domain/progression.dart';
import '../session/session_launcher.dart';

/// Apa yang terjadi di editor, dikembalikan ke pemanggil.
sealed class RoutineEditorResult {
  const RoutineEditorResult();
}

class RoutineDeleted extends RoutineEditorResult {
  const RoutineDeleted();
}

class RoutineSaved extends RoutineEditorResult {
  const RoutineSaved(this.routine);
  final Routine routine;
}

/// Bagian tubuh yang lompatan 5 kg-nya wajar — sama dengan daftar openGym.
const _heavyBodyParts = {'upper legs', 'lower legs', 'back'};

/// Pilihan increment beban. Di luar ini jarang ada alat yang bisa dimuat.
const _increments = [0.5, 1.0, 1.25, 2.0, 2.5, 5.0, 10.0];
const _incrementsLb = [1.0, 2.5, 5.0, 10.0, 20.0];

enum _RowAction { moveUp, moveDown, replace, remove }

class RoutineEditorScreen extends StatefulWidget {
  const RoutineEditorScreen({super.key, required this.routine, this.allowDelete = true});

  final Routine routine;

  /// Rutinitas yang baru dibuat di layar susun split tidak perlu tombol hapus
  /// di sini — dihapus dari daftarnya sendiri.
  final bool allowDelete;

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late List<ExerciseConfig> _exercises = List.of(widget.routine.exercises);

  /// Identitas tiap baris, bergerak bersama barisnya. Key dari indeks membuat
  /// baris yang dipindah atau yang ada di bawah baris yang dihapus dianggap
  /// baris baru — dan memudar masuk lagi.
  late List<Key> _rowKeys = [for (final _ in _exercises) UniqueKey()];
  late ProgressionPolicy? _policy = widget.routine.policy;
  late final _nameController = TextEditingController(text: widget.routine.name);
  late final Future<ExerciseCatalog> _catalog = ExerciseCatalog.load();
  int _expanded = 0;
  bool _dirty = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _change(VoidCallback f) => setState(() {
        f();
        _dirty = true;
      });

  Routine get _result => widget.routine.copyWith(
        name: _nameController.text.trim().isEmpty ? widget.routine.name : _nameController.text.trim(),
        exercises: _exercises,
        policy: _policy,
      );

  void _save() => Navigator.of(context).pop(RoutineSaved(_result));

  Future<void> _add() async {
    final picked = await pickExercise(context);
    if (picked == null || !mounted) return;
    _change(() {
      _exercises = [..._exercises, _configFor(picked)];
      _rowKeys = [..._rowKeys, UniqueKey()];
      _expanded = _exercises.length - 1;
    });
  }

  ExerciseConfig _configFor(Exercise e, {ExerciseConfig? keep}) {
    final bw = e.equipment == 'body weight';
    return ExerciseConfig(
      exerciseId: e.id,
      sets: keep?.sets ?? 3,
      reps: keep?.reps ?? 12,
      repsMin: keep == null ? 8 : keep.repsMin,
      policy: keep?.policy,
      restSeconds: keep?.restSeconds ?? 90,
      warmupSets: keep?.warmupSets ?? 0,
      bodyweight: bw,
      heavyBodyPart: _heavyBodyParts.contains(e.bodyPart),
    );
  }

  Future<void> _rowAction(int i, _RowAction a) async {
    switch (a) {
      case _RowAction.moveUp when i > 0:
        _change(() {
          final list = [..._exercises];
          final item = list.removeAt(i);
          list.insert(i - 1, item);
          _exercises = list;
          _rowKeys = [..._rowKeys]..insert(i - 1, _rowKeys[i])..removeAt(i + 1);
          _expanded = i - 1;
        });
      case _RowAction.moveDown when i < _exercises.length - 1:
        _change(() {
          final list = [..._exercises];
          final item = list.removeAt(i);
          list.insert(i + 1, item);
          _exercises = list;
          final keys = [..._rowKeys];
          keys.insert(i + 1, keys.removeAt(i));
          _rowKeys = keys;
          _expanded = i + 1;
        });
      case _RowAction.replace:
        final picked = await pickExercise(context);
        if (picked == null || !mounted) return;
        _change(() => _exercises = [..._exercises]..[i] = _configFor(picked, keep: _exercises[i]));
      case _RowAction.remove:
        _change(() {
          _exercises = [..._exercises]..removeAt(i);
          _rowKeys = [..._rowKeys]..removeAt(i);
          if (_expanded >= _exercises.length) _expanded = _exercises.length - 1;
        });
      default:
        break;
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final keep = await showDialog<bool>(
      context: context,
      builder: (context) {
        final c = context.gym;
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
          title: Text(context.t.discardChangesTitle, style: Theme.of(context).textTheme.titleLarge),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.t.discard, style: TextStyle(fontWeight: FontWeight.w700, color: c.danger)),
            ),
            GymButton(label: context.t.save, height: 42, expand: false, onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );
    if (!mounted) return false;
    if (keep == true) {
      _save();
      return false;
    }
    return keep == false;
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
          content: Text(context.t.deleteRoutineBody, style: TextStyle(fontSize: 13.5, height: 1.45, color: c.text2)),
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
    Navigator.of(context).pop(const RoutineDeleted());
  }

  Future<void> _leave() async {
    final leave = await _confirmDiscard();
    if (!mounted || !leave) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 16, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(GymIcons.arrowLeft, size: 22, color: c.text2),
                      tooltip: t.back,
                    ),
                    Expanded(child: Text(t.editRoutine, style: Theme.of(context).textTheme.titleLarge)),
                    GymButton(label: t.save, height: 36, expand: false, shape: GymButtonShape.pill, onPressed: _save),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<ExerciseCatalog>(
                  future: _catalog,
                  builder: (context, snap) {
                    final catalog = snap.data;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        GymCard(
                          radius: GymRadius.control,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel(t.routineName),
                              TextField(
                                controller: _nameController,
                                onChanged: (_) => _dirty = true,
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
                        SectionLabel(t.defaultPolicy),
                        const SizedBox(height: 6),
                        _PolicyPicker(
                          value: _policy ?? ProgressionPolicy.linear,
                          mode: LogMode.reps,
                          onChanged: (p) => _change(() => _policy = p),
                        ),
                        const SizedBox(height: 20),
                        SectionLabel(t.exercisesCount(_exercises.length)),
                        const SizedBox(height: 10),
                        if (_exercises.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(t.noExercisesYet, style: TextStyle(fontSize: 13.5, color: c.text2)),
                          ),
                        // Key-nya di Reveal: gerakan yang dipindah membawa
                        // keadaan animasinya, jadi menaikkan satu baris tidak
                        // membuatnya memudar masuk lagi — hanya gerakan yang
                        // baru ditambahkan yang datang dengan gerak.
                        for (final (i, cfg) in _exercises.indexed) ...[
                          Reveal(
                            key: _rowKeys[i],
                            index: i,
                            child: _ExerciseEditor(
                              name: catalog?.nameOf(cfg.exerciseId) ?? '…',
                              subtitle: catalog?.byId(cfg.exerciseId)?.subtitle ?? '',
                              config: cfg,
                              routinePolicy: _policy,
                              expanded: i == _expanded,
                              isFirst: i == 0,
                              isLast: i == _exercises.length - 1,
                              onToggle: () => setState(() => _expanded = i == _expanded ? -1 : i),
                              onChanged: (next) => _change(() => _exercises = [..._exercises]..[i] = next),
                              onAction: (a) => _rowAction(i, a),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 4),
                        PressScale(child: _AddExercise(onTap: _add)),
                        if (widget.allowDelete) ...[
                          const SizedBox(height: 24),
                          GymButton(
                            label: t.deleteRoutine,
                            icon: GymIcons.trash,
                            tone: GymButtonTone.danger,
                            onPressed: _deleteRoutine,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseEditor extends StatelessWidget {
  const _ExerciseEditor({
    required this.name,
    required this.subtitle,
    required this.config,
    required this.routinePolicy,
    required this.expanded,
    required this.isFirst,
    required this.isLast,
    required this.onToggle,
    required this.onChanged,
    required this.onAction,
  });

  final String name;
  final String subtitle;
  final ExerciseConfig config;
  final ProgressionPolicy? routinePolicy;
  final bool expanded;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onToggle;
  final ValueChanged<ExerciseConfig> onChanged;
  final ValueChanged<_RowAction> onAction;

  int get _lo => config.repsMin ?? config.reps;

  String _summary(BuildContext context) {
    final reps = config.repsMin == null ? '${config.reps}' : '${config.repsMin}–${config.reps}';
    final name = policyName[policyFor(config, routineDefault: routinePolicy)]!;
    // Bahasa Inggris cukup kata pertama ("linear", "double"); terjemahannya
    // tidak bisa dipotong begitu ("progresi"), jadi pakai nama lengkapnya.
    final policy = context.t.lang == AppLanguage.indonesian
        ? context.t.policy(name).toLowerCase()
        : name.split(' ').first.toLowerCase();
    final w = config.weight > 0 ? ' · ${context.wUnit(config.weight)}' : '';
    return '${config.sets} × $reps$w · $policy';
  }

  /// Rep range dipertahankan sah: bawah tidak pernah melewati atas. Kalau
  /// keduanya sama, targetnya satu angka (linear, 5×5) dan `repsMin` dilepas.
  ExerciseConfig _withRange(int lo, int hi) {
    final top = hi.clamp(1, 50);
    final bottom = lo.clamp(1, top);
    return ExerciseConfig(
      exerciseId: config.exerciseId,
      policy: config.policy,
      mode: config.mode,
      sets: config.sets,
      reps: top,
      repsMin: bottom == top ? null : bottom,
      repsMax: config.repsMax,
      weight: config.weight,
      seconds: config.seconds,
      increment: config.increment,
      restSeconds: config.restSeconds,
      deloadFactor: config.deloadFactor,
      bodyweight: config.bodyweight,
      heavyBodyPart: config.heavyBodyPart,
      warmupSets: config.warmupSets,
      superset: config.superset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    // Konfigurasi tersimpan dalam kg; yang disunting angka tampilannya, lalu
    // hanya kolom yang diubah yang dikonversi balik (konversi bolak-balik
    // seluruh konfigurasi akan menggeser increment 2,5 kg jadi 2,499 kg).
    final unit = context.unit;
    final shownConfig = configIn(config, unit);
    final inc = weightIncrement(shownConfig, unit.label);
    final steps = unit == WeightUnit.lb ? _incrementsLb : _increments;
    final rest = config.restSeconds ?? 90;

    PopupMenuItem<_RowAction> item(_RowAction a, IconData icon, String label, {bool enabled = true, Color? tone}) =>
        PopupMenuItem(
          value: a,
          enabled: enabled,
          height: 44,
          child: Row(children: [
            Icon(icon, size: 17, color: enabled ? (tone ?? c.text2) : c.text3),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: enabled ? (tone ?? c.text) : c.text3)),
          ]),
        );

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.card),
        border: Border.all(color: expanded ? c.accent : c.border),
      ),
      padding: EdgeInsets.fromLTRB(14, 8, 2, expanded ? 14 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
                        const SizedBox(height: 2),
                        Text(expanded ? subtitle : _summary(context), style: TextStyle(fontSize: 12.5, color: c.text2)),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggle,
                icon: Icon(expanded ? GymIcons.chevronUp : GymIcons.chevronDown, size: 22, color: c.text2),
                tooltip: expanded ? t.collapse : t.expand,
              ),
              PopupMenuButton<_RowAction>(
                icon: Icon(GymIcons.moreVertical, size: 20, color: c.text2),
                tooltip: t.exerciseActions,
                color: c.surface2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.control)),
                onSelected: onAction,
                itemBuilder: (context) => [
                  item(_RowAction.moveUp, GymIcons.arrowUp, t.moveUp, enabled: !isFirst),
                  item(_RowAction.moveDown, GymIcons.arrowDown, t.moveDown, enabled: !isLast),
                  item(_RowAction.replace, GymIcons.swap, t.replaceExercise),
                  item(_RowAction.remove, GymIcons.trash, t.removeExercise, tone: c.danger),
                ],
              ),
            ],
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _StepperField(
                        label: t.sets,
                        value: '${config.sets}',
                        onMinus: () => onChanged(config.copyWith(sets: (config.sets - 1).clamp(1, 12))),
                        onPlus: () => onChanged(config.copyWith(sets: (config.sets + 1).clamp(1, 12))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StepperField(
                        label: t.warmups,
                        value: '${config.warmupSets}',
                        onMinus: () => onChanged(config.copyWith(warmupSets: (config.warmupSets - 1).clamp(0, 3))),
                        onPlus: () => onChanged(config.copyWith(warmupSets: (config.warmupSets + 1).clamp(0, 3))),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  SectionLabel(t.measuredBy),
                  const SizedBox(height: 6),
                  FilterChips(
                    labels: [t.modeReps, t.modeTime],
                    index: config.mode == LogMode.time ? 1 : 0,
                    onChanged: (i) {
                      final time = i == 1;
                      if (time == (config.mode == LogMode.time)) return;
                      onChanged(config.copyWith(
                        mode: time ? LogMode.time : LogMode.reps,
                        policy: time ? ProgressionPolicy.time : ProgressionPolicy.double_,
                        seconds: time && config.seconds == 0 ? 30 : config.seconds,
                      ));
                    },
                  ),
                  const SizedBox(height: 10),
                  if (config.mode == LogMode.time)
                    _StepperField(
                      label: t.targetSeconds,
                      value: '${config.seconds} s',
                      onMinus: () => onChanged(config.copyWith(seconds: (config.seconds - 5).clamp(5, 600))),
                      onPlus: () => onChanged(config.copyWith(seconds: (config.seconds + 5).clamp(5, 600))),
                    )
                  else ...[
                  SectionLabel(t.repRange),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: _StepperField(
                        value: '$_lo',
                        onMinus: () => onChanged(_withRange(_lo - 1, config.reps)),
                        onPlus: () => onChanged(_withRange(_lo + 1, config.reps)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('–', style: TextStyle(fontSize: 18, color: c.text2)),
                    ),
                    Expanded(
                      child: _StepperField(
                        value: '${config.reps}',
                        onMinus: () => onChanged(_withRange(_lo, config.reps - 1)),
                        onPlus: () => onChanged(_withRange(_lo, config.reps + 1)),
                      ),
                    ),
                  ]),
                  ],
                  if (config.bodyweight && config.mode == LogMode.reps) ...[
                    const SizedBox(height: 10),
                    _StepperField(
                      label: t.repCeiling,
                      value: '${config.repsMax ?? bodyweightRepCeiling}',
                      onMinus: () => onChanged(config.copyWith(
                          repsMax: ((config.repsMax ?? bodyweightRepCeiling) - 1).clamp(config.reps, 50))),
                      onPlus: () => onChanged(config.copyWith(
                          repsMax: ((config.repsMax ?? bodyweightRepCeiling) + 1).clamp(config.reps, 50))),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _StepperField(
                        label: t.startingWeight,
                        value: config.weight == 0 ? (config.bodyweight ? 'BW' : '—') : context.wUnit(config.weight),
                        onMinus: () => onChanged(config.copyWith(
                            weight: toKg((shownConfig.weight - inc).clamp(0, 2000).toDouble(), unit))),
                        onPlus: () => onChanged(config.copyWith(weight: toKg(shownConfig.weight + inc, unit))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StepperField(
                        label: t.increment,
                        value: '${formatDelta(inc)} ${unit.label}',
                        onMinus: () {
                          final i = steps.lastIndexWhere((x) => x < inc - 1e-6);
                          if (i >= 0) onChanged(config.copyWith(increment: toKg(steps[i], unit)));
                        },
                        onPlus: () {
                          final i = steps.indexWhere((x) => x > inc + 1e-6);
                          if (i >= 0) onChanged(config.copyWith(increment: toKg(steps[i], unit)));
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _StepperField(
                    label: t.rest,
                    value: '$rest s',
                    onMinus: () => onChanged(config.copyWith(restSeconds: (rest - 15).clamp(15, 600))),
                    onPlus: () => onChanged(config.copyWith(restSeconds: (rest + 15).clamp(15, 600))),
                  ),
                  const SizedBox(height: 12),
                  SectionLabel(t.progressionPolicy),
                  const SizedBox(height: 6),
                  _PolicyPicker(
                    value: policyFor(config, routineDefault: routinePolicy),
                    mode: config.mode,
                    onChanged: (p) => onChanged(config.copyWith(policy: p)),
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.supersetWithNext, style: Theme.of(context).textTheme.bodyLarge),
                      value: config.superset,
                      onChanged: (v) => onChanged(config.copyWith(superset: v)),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({this.label, required this.value, required this.onMinus, required this.onPlus});

  final String? label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          SectionLabel(label!),
          const SizedBox(height: 6),
        ],
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(GymRadius.segment),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onMinus,
                visualDensity: VisualDensity.compact,
                icon: Icon(GymIcons.minus, size: 16, color: c.accent),
                tooltip: context.t.fewer,
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
                  ),
                ),
              ),
              IconButton(
                onPressed: onPlus,
                visualDensity: VisualDensity.compact,
                icon: Icon(GymIcons.add, size: 16, color: c.accent),
                tooltip: context.t.more,
              ),
            ],
          ),
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
          icon: Icon(GymIcons.chevronDown, size: 22, color: c.text2),
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.text),
          items: [
            for (final p in options) DropdownMenuItem(value: p, child: Text(context.t.policy(policyName[p]!))),
          ],
          onChanged: (p) => p == null ? null : onChanged(p),
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
              Icon(GymIcons.add, size: 15, color: c.accent),
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
