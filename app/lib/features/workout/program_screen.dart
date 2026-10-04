/// Tab Program — UI v3 (`design/UI-V3.md` §7.7). Menggantikan tab Workout
/// lama (Tracker / My Plan): program aktif, kisi rutinitas dengan volume
/// rencana dan tombol mulai, lalu aturan program. Memulai sesi bebas pindah
/// ke tombol + di tab bar.
library;

import 'package:flutter/material.dart';

import '../../core/gym_icons.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_v3.dart';
import '../../core/theme.dart';
import '../../core/weights.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/program.dart';
import '../../domain/session_plan.dart';
import '../../domain/units.dart';
import '../library/library_screen.dart';
import '../onboarding/program_flow.dart';
import '../session/session_launcher.dart';
import 'routine_actions.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  Future<void> _newRoutine() async {
    final store = context.workouts;
    final name = await askRoutineName(context, context.t.newRoutineTitle);
    if (name == null || name.trim().isEmpty || !mounted) return;
    // Rutinitas baru mulai kosong dan langsung dibuka di editor — rutinitas
    // tanpa gerakan tidak berguna, jadi langkah berikutnya jelas.
    final routine = Routine(id: WorkoutStore.newRoutineId(), name: name.trim(), policy: ProgressionPolicy.double_);
    await store.saveRoutine(routine);
    if (mounted) await openRoutineEditor(context, routine);
  }

  Future<void> _start(Routine r) async {
    if (r.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.emptyRoutineHint)));
      await openRoutineEditor(context, r);
      return;
    }
    await openRoutineSession(context, r);
  }

  Future<void> _buildOwn() async {
    final store = context.workouts;
    final built = await buildOwnSplit(context);
    if (built == null || !mounted) return;
    await store.setProgram(built.program, built.routines);
  }

  Future<void> _skip() async {
    final store = context.workouts;
    final messenger = ScaffoldMessenger.of(context);
    final msg = context.t.skipped;
    await store.skipNext(DateTime.now());
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Jadwal bisa diganti kapan saja — rotasi atau hari tetap.
  Future<void> _pickMode(Program program) async {
    final store = context.workouts;
    final picked = await showModalBottomSheet<ProgramMode>(
      context: context,
      backgroundColor: context.gym.bg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet))),
      builder: (sheet) {
        final t = sheet.t;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.modeLabel, style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 10),
                SelectRow(
                  title: t.rotationMode,
                  detail: t.rotationModeNote,
                  selected: program.mode == ProgramMode.rotation,
                  onTap: () => Navigator.of(sheet).pop(ProgramMode.rotation),
                ),
                SelectRow(
                  title: t.weekdayMode,
                  detail: t.weekdayModeNote,
                  selected: program.mode == ProgramMode.weekday,
                  onTap: () => Navigator.of(sheet).pop(ProgramMode.weekday),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || picked == program.mode) return;
    final weekday = picked == ProgramMode.weekday;
    await store.updateProgram(program.copyWith(
      mode: picked,
      days: weekday && program.days.isEmpty ? const [1, 3, 5] : program.days,
      clearSkip: true,
    ));
  }

  /// Sheet urutan rotasi: panah naik/turun, dan "jadikan berikutnya" dengan
  /// mengetuk lingkaran di kiri.
  Future<void> _reorder() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.gym.bg,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet))),
      builder: (sheet) {
        final c = sheet.gym;
        final t = sheet.t;
        // Dibaca dari store di dalam builder: WorkoutScope membangun ulang
        // sheet ini begitu urutannya tersimpan.
        final store = sheet.workouts;
        final program = store.program;
        if (program == null) return const SizedBox.shrink();
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

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.order, style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 12),
                SettingsGroup(children: [
                  for (final (i, r) in routines.indexed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: program.mode == ProgramMode.rotation && next?.routine.id != r.id
                                ? () => store.setNext(r.id)
                                : null,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(next?.routine.id == r.id ? GymIcons.play : GymIcons.circle,
                                  size: 18, color: next?.routine.id == r.id ? c.accent : c.text3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name, style: Theme.of(sheet).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  [
                                    t.exerciseCount(r.exercises.length),
                                    if (program.mode == ProgramMode.weekday)
                                      [for (final d in weekdaysOf(program, store.routines, r.id)) t.weekdayShort(d)].join(', '),
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  style: TextStyle(fontSize: 12, color: c.text2),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: i > 0 ? () => move(i, -1) : null,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(GymIcons.arrowUp, size: 18, color: i > 0 ? c.text2 : c.text3),
                            tooltip: t.moveUp,
                          ),
                          IconButton(
                            onPressed: i < routines.length - 1 ? () => move(i, 1) : null,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(GymIcons.arrowDown, size: 18, color: i < routines.length - 1 ? c.text2 : c.text3),
                            tooltip: t.moveDown,
                          ),
                        ],
                      ),
                    ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final program = store.program;
    final next = store.nextSessionOn(DateTime.now());
    final inProgram = program == null ? const <Routine>[] : programRoutines(program, store.routines);
    final ids = {for (final r in inProgram) r.id};
    final others = [for (final r in store.routines) if (!ids.contains(r.id)) r];
    final all = [...inProgram, ...others];
    final unit = context.unit;
    final history = historyIn(store.chronological, unit);

    final cards = <Widget>[
      for (final (i, r) in all.indexed)
        _RoutineCard(
          routine: r,
          isNext: next?.routine.id == r.id,
          volume: plannedSessionVolume(r, history, unit),
          unitLabel: context.unitLabel,
          hue: c.hues.at(i),
          onStart: () => _start(r),
          onTap: () => openRoutineEditor(context, r),
          onLongPress: () => showRoutineActions(context, r),
        ),
      _AddRoutineCard(onTap: _newRoutine),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ScreenHeader(
          title: t.programTab,
          actions: [
            GymButton(
              label: t.libraryButton,
              icon: GymIcons.dumbbell,
              tone: GymButtonTone.neutral,
              height: 34,
              expand: false,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()),
              ),
            ),
          ],
        ),
        Reveal(
          child: program == null
              ? _NoProgramCard(onChoose: () => chooseProgram(context), onBuild: _buildOwn)
              : _ProgramCard(
                  program: program,
                  routines: inProgram,
                  onChange: () => chooseProgram(context),
                  onSkip: program.mode == ProgramMode.rotation ? _skip : null,
                ),
        ),
        const SizedBox(height: 18),
        Reveal(
          index: 1,
          child: SectionTitle(
            t.routines,
            action: inProgram.length > 1 ? t.reorder : null,
            onAction: inProgram.length > 1 ? _reorder : null,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < cards.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Reveal(
            index: 2 + i ~/ 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: 10),
                Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox.shrink()),
              ],
            ),
          ),
        ],
        if (program != null) ...[
          const SizedBox(height: 18),
          Reveal(index: 3 + cards.length ~/ 2, child: SectionTitle(t.programRules)),
          const SizedBox(height: 10),
          Reveal(index: 4 + cards.length ~/ 2, child: _RulesCard(program: program, onPickMode: () => _pickMode(program))),
        ],
      ],
    );
  }
}

/// Kartu program aktif: kicker, nama, meta, dan dua tombol kaca bening.
class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program, required this.routines, required this.onChange, this.onSkip});

  final Program program;
  final List<Routine> routines;
  final VoidCallback onChange;

  /// null di mode hari tetap — di sana hari yang menentukan, bukan cursor.
  final VoidCallback? onSkip;

  /// Policy yang dipakai terbanyak di rutinitas program — "double
  /// progression" di kartu, bukan daftar per rutinitas.
  String _policyLabel(Strings t) {
    final counts = <ProgressionPolicy, int>{};
    for (final r in routines) {
      final p = r.policy;
      if (p == null) continue;
      counts[p] = (counts[p] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';
    final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    return t.policy(policyName[top] ?? top.name).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final schedule = program.mode == ProgramMode.weekday
        ? t.weekdayCount([for (final d in [...program.days]..sort()) t.weekdayShort(d)].join(', '))
        : t.rotationCount(routines.length);
    final meta = [schedule, _policyLabel(t)].where((s) => s.isNotEmpty).join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.card),
        boxShadow: [c.cardShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Wash violet tipis di pojok kanan atas, seperti latar Beranda.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1, -1),
                  radius: 1.2,
                  colors: [c.washB, c.washB.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.activeProgramKicker,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.accent)),
                const SizedBox(height: 4),
                Text(program.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.text2)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GymButton(
                        label: t.changeProgram,
                        icon: GymIcons.swap,
                        tone: GymButtonTone.neutral,
                        height: 42,
                        onPressed: onChange,
                      ),
                    ),
                    if (onSkip != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: GymButton(
                          label: t.skipSessionBtn,
                          icon: GymIcons.skip,
                          tone: GymButtonTone.neutral,
                          height: 42,
                          onPressed: onSkip,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoProgramCard extends StatelessWidget {
  const _NoProgramCard({required this.onChoose, required this.onBuild});

  final VoidCallback onChoose;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.noProgramYet, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(t.noProgramHint, style: TextStyle(fontSize: 13, height: 1.4, color: c.text2)),
          const SizedBox(height: 16),
          GymButton(label: t.choosePlan, onPressed: onChoose),
          const SizedBox(height: 10),
          GymButton(label: t.buildMyOwn, icon: GymIcons.sliders, tone: GymButtonTone.neutral, height: 44, onPressed: onBuild),
        ],
      ),
    );
  }
}

/// Kartu rutinitas di kisi dua kolom: nama + tag, meta, odometer volume
/// rencana sesi berikutnya, tombol mulai. Ketuk → editor; tahan → aksi.
class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.isNext,
    required this.volume,
    required this.unitLabel,
    required this.hue,
    required this.onStart,
    required this.onTap,
    required this.onLongPress,
  });

  final Routine routine;
  final bool isNext;
  final double volume;
  final String unitLabel;
  final Color hue;
  final VoidCallback onStart;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return Container(
      height: 128,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.group),
        border: isNext ? Border.all(color: c.accent, width: 1.5) : null,
        boxShadow: [c.cardShadow],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(GymRadius.group),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(routine.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                        ),
                        if (isNext) ...[
                          const SizedBox(width: 6),
                          // Mengecil, bukan meluber, kalau nama rutinitasnya
                          // panjang di kolom selebar setengah layar HP kecil.
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Pill(color: c.accentSoft, textColor: c.accent, child: Text(t.next)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(t.routineMetaComma(routine.exercises.length, routine.setCount),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.text2)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Odometer(value: volume, unit: unitLabel),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GlassIconButton(
                      key: ValueKey('start-${routine.id}'),
                      icon: GymIcons.play,
                      size: 34,
                      iconSize: 14,
                      tinted: isNext,
                      tooltip: t.startSession,
                      color: isNext ? null : hue,
                      onPressed: onStart,
                    ),
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

/// Kartu "Tambah rutinitas" bergaris putus-putus.
class _AddRoutineCard extends StatelessWidget {
  const _AddRoutineCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return SizedBox(
      height: 128,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: c.text3, radius: GymRadius.group),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(GymRadius.group),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                  child: Icon(GymIcons.plus, size: 18, color: c.text),
                ),
                const SizedBox(height: 8),
                Text(t.addRoutineCard, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.6), Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.radius != radius;
}

/// Aturan program: mode (sheet pilihan), hari latihan (hari tetap), atau
/// istirahat minimum antar sesi (rotasi, stepper).
class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.program, required this.onPickMode});

  final Program program;
  final VoidCallback onPickMode;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final weekday = program.mode == ProgramMode.weekday;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.group),
        boxShadow: [c.cardShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onPickMode,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(t.modeLabel, style: TextStyle(fontSize: 14, color: c.text))),
                  Text(weekday ? t.weekdayMode : t.rotationMode, style: TextStyle(fontSize: 13.5, color: c.text2)),
                  const SizedBox(width: 10),
                  Icon(GymIcons.chevronRight, size: 16, color: c.text2),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: c.border, indent: 16, endIndent: 16),
          if (weekday)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.trainingDays, style: TextStyle(fontSize: 14, color: c.text)),
                  const SizedBox(height: 10),
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
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(child: Text(t.minRestBetween, style: TextStyle(fontSize: 14, color: c.text))),
                  const SizedBox(width: 10),
                  _Stepper(
                    value: t.daysValue(program.minRestDays),
                    canMinus: program.minRestDays > 0,
                    canPlus: program.minRestDays < 7,
                    onMinus: () => store.updateProgram(program.copyWith(minRestDays: program.minRestDays - 1)),
                    onPlus: () => store.updateProgram(program.copyWith(minRestDays: program.minRestDays + 1)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.canMinus,
    required this.canPlus,
    required this.onMinus,
    required this.onPlus,
  });

  final String value;
  final bool canMinus;
  final bool canPlus;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    Widget button(Key key, IconData icon, bool enabled, VoidCallback onTap, String tooltip) => Tooltip(
          message: tooltip,
          child: Material(
            color: c.segThumb,
            shape: const CircleBorder(),
            child: InkWell(
              key: key,
              customBorder: const CircleBorder(),
              onTap: enabled
                  ? () {
                      GymHaptics.tap();
                      onTap();
                    }
                  : null,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(icon, size: 13, color: enabled ? c.text : c.text3),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(GymRadius.segTrack)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(const ValueKey('rest-minus'), GymIcons.minus, canMinus, onMinus, t.fewer),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
          button(const ValueKey('rest-plus'), GymIcons.plus, canPlus, onPlus, t.more),
        ],
      ),
    );
  }
}
