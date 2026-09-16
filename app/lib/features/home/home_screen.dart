/// Tab Home — artboard `04 Home`.
///
/// Satu pertanyaan yang dijawab layar ini: **hari ini latihan apa?** Semua yang
/// lain di bawahnya hanya konteks.
library;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/demo.dart';
import '../../data/workout_store.dart';
import '../session/session_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.programName = 'Push / Pull / Legs'});

  /// Program yang dipilih saat onboarding — ditulis di bawah nama rutinitas.
  final String programName;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(context.t.catalogue('Tuesday · 16 Sep')),
                  const SizedBox(height: 4),
                  Text(context.t.nextUp, style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
            ),
            Pill(
              onTap: () {},
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monitor_weight_outlined),
                  SizedBox(width: 6),
                  // Angka berat badan tidak diterjemahkan: satuannya sama di
                  // kedua bahasa dan formatnya sudah ditangani formatWeight.
                  Text('78.4 kg'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _NextSessionCard(programName: programName),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: SectionLabel(context.t.thisWeek)),
            Text(context.t.plannedOf(2, 4), style: TextStyle(fontSize: 12, color: c.text2)),
          ],
        ),
        const SizedBox(height: 10),
        const _WeekStrip(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatTile(value: '18.4 t', label: context.t.volume7d)),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(value: '+3', label: context.t.e1rmUp, accent: true)),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(value: '4d', label: context.t.sinceLast)),
          ],
        ),
      ],
    );
  }
}

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({required this.programName});

  final String programName;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final all = demoExercises();
    const shown = 3;
    final preview = all.take(shown).toList();
    final hidden = all.length - preview.length;

    return GymCard(
      radius: GymRadius.hero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(context.t.nextSession)),
              Pill(
                color: c.accentSoft,
                textColor: c.accent,
                child: Text(context.t.dueToday, style: const TextStyle(fontSize: 10, letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(demoRoutineName, style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.t.rotationOf(programName),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.text2)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(context.t.routineSummary(all.length, 52, 4),
              style: TextStyle(fontSize: 13, color: c.text2)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: c.bgNested,
              borderRadius: BorderRadius.circular(GymRadius.control),
            ),
            child: Column(
              children: [
                for (final e in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.name, style: Theme.of(context).textTheme.bodyLarge)),
                        Text(
                          '${formatWeight(e.config.weight)} kg × ${e.config.reps}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text2),
                        ),
                      ],
                    ),
                  ),
                if (hidden > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(context.t.moreItems(hidden), style: TextStyle(fontSize: 12, color: c.text3)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GymButton(
            label: context.t.startSession,
            icon: Icons.play_arrow,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SessionScreen(
                  routineName: demoRoutineName,
                  exercises: demoExercises(),
                  history: context.workouts.workouts,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GymButton(
                  label: context.t.skip,
                  icon: Icons.skip_next,
                  tone: GymButtonTone.neutral,
                  height: 44,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GymButton(
                  label: context.t.freestyle,
                  icon: Icons.bolt,
                  tone: GymButtonTone.neutral,
                  height: 44,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SessionScreen(
                        routineName: 'Freestyle',
                        exercises: demoExercises(),
                        history: context.workouts.workouts,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip();

  static const _days = [
    ('M', '16', _DayState.done),
    ('T', '17', _DayState.today),
    ('W', '18', _DayState.plain),
    ('T', '19', _DayState.plain),
    ('F', '20', _DayState.plain),
    ('S', '21', _DayState.plain),
    ('S', '22', _DayState.plain),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Row(
      children: [
        for (final (i, day) in _days.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: day.$3 == _DayState.done ? c.accent : c.surface,
                borderRadius: BorderRadius.circular(GymRadius.card),
                border: Border.all(
                  color: switch (day.$3) {
                    _DayState.done => Colors.transparent,
                    _DayState.today => c.accent,
                    _DayState.plain => c.border,
                  },
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day.$1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: day.$3 == _DayState.done ? c.accentInk : c.text2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    day.$2,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: day.$3 == _DayState.done ? c.accentInk : c.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _DayState { done, today, plain }

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.accent = false});

  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return GymCard(
      radius: GymRadius.card,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: accent ? c.accent : c.text),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: c.text2)),
        ],
      ),
    );
  }
}
