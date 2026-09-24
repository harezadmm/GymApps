/// "Build my own" — susun split latihan sendiri (FR-B1: program custom).
///
/// Dipakai di dua tempat: onboarding dan tab Workout → My Plan → Ganti
/// program. Layar ini tidak menyimpan apa-apa sendiri; hasilnya dikembalikan
/// sebagai [ProgramBundle] lewat `pop`, dan pemanggil yang memasangnya.
library;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/templates.dart';
import '../workout/routine_editor_screen.dart';

class CustomSplitScreen extends StatefulWidget {
  const CustomSplitScreen({super.key});

  @override
  State<CustomSplitScreen> createState() => _CustomSplitScreenState();
}

class _CustomSplitScreenState extends State<CustomSplitScreen> {
  final _name = TextEditingController();
  ProgramMode _mode = ProgramMode.rotation;
  int _restDays = 0;

  /// Mode hari tetap: Senin, Rabu, Jumat sebagai titik awal yang wajar untuk
  /// tiga hari latihan.
  final Set<int> _weekdays = {1, 3, 5};

  late List<Routine> _days = [
    for (var i = 1; i <= 3; i++)
      Routine(id: WorkoutStore.newRoutineId(), name: 'Day $i', policy: ProgressionPolicy.double_),
  ];

  bool _named = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nama hari bawaan mengikuti bahasa yang aktif, sekali saja — setelah itu
    // nama yang sudah diubah orang tidak boleh ditimpa lagi.
    if (!_named) {
      _named = true;
      final t = context.t;
      _days = [for (final (i, d) in _days.indexed) d.copyWith(name: t.dayName(i + 1))];
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _edit(int i) async {
    final result = await Navigator.of(context).push<RoutineEditorResult>(
      MaterialPageRoute(builder: (_) => RoutineEditorScreen(routine: _days[i], allowDelete: false)),
    );
    if (result case RoutineSaved(:final routine)) {
      setState(() => _days = [..._days]..[i] = routine);
    }
  }

  void _addDay() => setState(() => _days = [
        ..._days,
        Routine(
          id: WorkoutStore.newRoutineId(),
          name: context.t.dayName(_days.length + 1),
          policy: ProgressionPolicy.double_,
        ),
      ]);

  void _removeDay(int i) => setState(() => _days = [..._days]..removeAt(i));

  /// Hari mana yang dipegang tiap rutinitas di mode hari tetap — rutinitas
  /// dibagikan berurutan ke hari yang dipilih, berputar kalau hari lebih banyak.
  List<int> _daysOf(int routineIndex) {
    if (_days.isEmpty) return const [];
    final sorted = _weekdays.toList()..sort();
    return [
      for (final (i, d) in sorted.indexed)
        if (i % _days.length == routineIndex) d,
    ];
  }

  void _continue() {
    final t = context.t;
    String? problem;
    if (_days.isEmpty) problem = t.needOneDay;
    if (_mode == ProgramMode.weekday && _weekdays.isEmpty) problem = t.needOneWeekday;
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final name = _name.text.trim().isEmpty ? t.mySplit : _name.text.trim();
    final program = Program(
      name: name,
      mode: _mode,
      order: [for (final d in _days) d.id],
      minRestDays: _mode == ProgramMode.rotation ? _restDays : 0,
      days: _mode == ProgramMode.weekday ? (_weekdays.toList()..sort()) : const [],
    );
    Navigator.of(context).pop(ProgramBundle(program, _days));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final anyEmpty = _days.any((d) => d.exercises.isEmpty);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back, color: c.text2),
                    tooltip: t.back,
                  ),
                  Expanded(child: Text(t.customSplit, style: Theme.of(context).textTheme.titleLarge)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Text(t.customSplitSub, style: TextStyle(fontSize: 13.5, height: 1.4, color: c.text2)),
                  const SizedBox(height: 16),
                  GymCard(
                    radius: GymRadius.control,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(t.splitName),
                        TextField(
                          controller: _name,
                          style: Theme.of(context).textTheme.titleLarge,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: t.splitNameHint,
                            hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(color: c.text3),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SectionLabel(t.scheduling),
                  const SizedBox(height: 8),
                  SegmentedTabs(
                    labels: [t.rotationMode, t.weekdayMode],
                    index: _mode == ProgramMode.rotation ? 0 : 1,
                    onChanged: (i) => setState(() => _mode = i == 0 ? ProgramMode.rotation : ProgramMode.weekday),
                  ),
                  const SizedBox(height: 8),
                  Text(_mode == ProgramMode.rotation ? t.rotationModeNote : t.weekdayModeNote,
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: c.text2)),
                  const SizedBox(height: 12),
                  if (_mode == ProgramMode.rotation)
                    GymCard(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.restDaysBetween, style: Theme.of(context).textTheme.bodyLarge),
                                Text(t.restDaysValue(_restDays), style: TextStyle(fontSize: 12.5, color: c.text2)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _restDays <= 0 ? null : () => setState(() => _restDays--),
                            icon: Icon(Icons.remove, color: _restDays <= 0 ? c.text3 : c.accent),
                            tooltip: t.fewer,
                          ),
                          IconButton(
                            onPressed: _restDays >= 7 ? null : () => setState(() => _restDays++),
                            icon: Icon(Icons.add, color: _restDays >= 7 ? c.text3 : c.accent),
                            tooltip: t.more,
                          ),
                        ],
                      ),
                    )
                  else
                    _WeekdayPicker(
                      selected: _weekdays,
                      onToggle: (d) => setState(() => _weekdays.contains(d) ? _weekdays.remove(d) : _weekdays.add(d)),
                    ),
                  const SizedBox(height: 20),
                  SectionLabel(t.days),
                  const SizedBox(height: 8),
                  for (final (i, d) in _days.indexed) ...[
                    _DayCard(
                      routine: d,
                      weekdays: _mode == ProgramMode.weekday
                          ? [for (final w in _daysOf(i)) t.weekdayShort(w)].join(', ')
                          : null,
                      onTap: () => _edit(i),
                      onRemove: () => _removeDay(i),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _AddDayRow(onTap: _addDay),
                  if (anyEmpty && _days.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    NoteBanner(text: t.emptyDaysNote, icon: Icons.info_outline, tone: c.text2),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: GymButton(label: t.cont, onPressed: _continue),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onToggle});

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Row(
      children: [
        for (var d = 1; d <= 7; d++) ...[
          if (d > 1) const SizedBox(width: 6),
          Expanded(
            child: Material(
              color: selected.contains(d) ? c.accent : c.surface,
              borderRadius: BorderRadius.circular(GymRadius.card),
              child: InkWell(
                onTap: () => onToggle(d),
                borderRadius: BorderRadius.circular(GymRadius.card),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(GymRadius.card),
                    border: Border.all(color: selected.contains(d) ? Colors.transparent : c.border),
                  ),
                  child: Text(
                    context.t.weekdayShort(d),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected.contains(d) ? c.accentInk : c.text2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.routine, required this.weekdays, required this.onTap, required this.onRemove});

  final Routine routine;
  final String? weekdays;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final empty = routine.exercises.isEmpty;
    final detail = [
      if (weekdays != null && weekdays!.isNotEmpty) weekdays!,
      empty ? t.tapToAddExercises : t.routineMeta(routine.exercises.length, routine.setCount),
    ].join(' · ');

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(GymRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.card),
            border: Border.all(color: empty ? c.border : c.accent.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routine.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(detail, style: TextStyle(fontSize: 12.5, color: empty ? c.accent : c.text2)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.text3),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline, size: 20, color: c.text2),
                tooltip: t.removeDay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddDayRow extends StatelessWidget {
  const _AddDayRow({required this.onTap});

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
              Text(context.t.addDay,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: c.accent)),
            ],
          ),
        ),
      ),
    );
  }
}
