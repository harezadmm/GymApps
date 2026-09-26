/// Tab Home — artboard `04 Home`.
///
/// Satu pertanyaan yang dijawab layar ini: **hari ini latihan apa?** Semua yang
/// lain di bawahnya hanya konteks — dan semuanya dihitung dari program dan
/// riwayat yang tersimpan, bukan angka contoh.
library;

import 'package:flutter/material.dart';
import '../../core/weights.dart';
import '../../domain/units.dart';

import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/onerm.dart';
import '../../domain/program.dart';
import '../../domain/session_plan.dart';
import '../onboarding/program_flow.dart';
import '../session/session_launcher.dart';
import '../workout/routine_editor_screen.dart';

/// Ringkasan tujuh hari terakhir, dihitung dari riwayat.
class _Recent {
  _Recent(List<Workout> newestFirst, DateTime today) {
    final day = dateOnly(today);
    final weekAgo = isoDate(day.subtract(const Duration(days: 6)));
    final recent = newestFirst.where((w) => w.date.compareTo(weekAgo) >= 0).toList();
    final older = newestFirst.where((w) => w.date.compareTo(weekAgo) < 0).toList().reversed.toList();

    volume = 0;
    for (final w in recent) {
      for (final e in w.entries) {
        for (final s in e.sets) {
          if (s.done && !s.isWarmup) volume += s.weight * s.reps;
        }
      }
    }

    // Gerakan yang e1RM-nya minggu ini melewati semua sesi sebelumnya.
    final ids = {for (final w in recent) for (final e in w.entries) e.exerciseId};
    final all = newestFirst.reversed.toList();
    e1rmUp = ids.where((id) {
      final now = best1RM(all, id);
      final before = best1RM(older, id);
      return now != null && before != null && now.est > before.est;
    }).length;

    final last = lastTrainingDay(newestFirst);
    daysSince = last == null ? null : day.difference(last).inDays;
  }

  late double volume;
  late int e1rmUp;
  late int? daysSince;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final now = DateTime.now();
    final recent = _Recent(store.workouts, now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionLabel('${t.weekdayLong(now.weekday)} · ${now.day} ${t.monthShort(now.month)}'),
        const SizedBox(height: 4),
        Text(t.nextUp, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        if (store.loaded && store.draft != null) ...[
          _ResumeCard(draft: store.draft!),
          const SizedBox(height: 12),
        ],
        if (!store.loaded)
          const SizedBox(height: 200)
        else if (store.program == null || store.nextSessionOn(now) == null)
          _NoProgramCard(hasProgram: store.program != null)
        else
          _NextSessionCard(next: store.nextSessionOn(now)!, program: store.program!),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: SectionLabel(t.thisWeek)),
            Text(t.sessionsCount(_thisWeek(store.workouts, now, store.settings.weekStartsOn)),
                style: TextStyle(fontSize: 12, color: c.text2)),
          ],
        ),
        const SizedBox(height: 10),
        _WeekStrip(
            history: store.workouts, today: now, program: store.program, weekStartsOn: store.settings.weekStartsOn),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                value: kgTo(recent.volume, context.unit) >= 1000
                    ? context.volume(recent.volume)
                    : '${formatDelta(kgTo(recent.volume, context.unit).roundToDouble())} ${context.unitLabel}',
                label: t.volume7d,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                value: recent.e1rmUp > 0 ? '+${recent.e1rmUp}' : '0',
                label: t.e1rmUp,
                accent: recent.e1rmUp > 0,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                value: recent.daysSince == null ? '—' : t.daysShort(recent.daysSince!),
                label: t.sinceLast,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Sesi yang tercatat sejak awal minggu ini (setelan "Minggu mulai").
  static int _thisWeek(List<Workout> history, DateTime today, int weekStartsOn) {
    final from = isoDate(weekStart(today, weekStartsOn));
    return history.where((w) => w.date.compareTo(from) >= 0).length;
  }
}

/// Hari pertama minggu yang memuat [day], menurut [weekStartsOn] (1 = Senin).
DateTime weekStart(DateTime day, int weekStartsOn) {
  final d = dateOnly(day);
  final back = (d.weekday - weekStartsOn + 7) % 7;
  return d.subtract(Duration(days: back));
}

/// Sesi yang ditinggal di tengah jalan — aplikasi dimatikan, HP mati.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.draft});

  final Map<String, dynamic> draft;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    var logged = 0;
    for (final e in (draft['ex'] as List? ?? const [])) {
      for (final s in ((e as Map)['sets'] as List? ?? const [])) {
        final m = s as Map;
        if (m['done'] == true && m['phase'] != 'warmup') logged++;
      }
    }
    final minutes = (((draft['elapsed'] as num?)?.toInt() ?? 0) / 60).round();
    return GymCard(
      radius: GymRadius.large,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.play_circle_outline, size: 18, color: c.warn),
            const SizedBox(width: 8),
            Expanded(child: SectionLabel(t.resumeTitle)),
          ]),
          const SizedBox(height: 8),
          Text(t.resumeDetail(draft['name'] as String? ?? '', logged, minutes),
              style: TextStyle(fontSize: 13.5, color: c.text)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GymButton(
                label: t.discardDraft,
                tone: GymButtonTone.neutral,
                height: 42,
                onPressed: () async {
                  final store = WorkoutScope.read(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: c.surface,
                      content: Text(t.discardDraftConfirm),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.cancel)),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(t.discardDraft, style: TextStyle(color: c.danger)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await store.clearDraft();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GymButton(label: t.resume, height: 42, onPressed: () => resumeDraftSession(context)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _NoProgramCard extends StatelessWidget {
  const _NoProgramCard({required this.hasProgram});

  final bool hasProgram;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return GymCard(
      radius: GymRadius.hero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.noProgramYet, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(t.noProgramHint, style: TextStyle(fontSize: 13, height: 1.4, color: c.text2)),
          const SizedBox(height: 16),
          GymButton(label: t.choosePlan, onPressed: () => chooseProgram(context)),
          const SizedBox(height: 10),
          GymButton(
            label: t.freestyle,
            icon: Icons.edit_note_outlined,
            tone: GymButtonTone.neutral,
            height: 44,
            onPressed: () => openFreestyleSession(context, t.freestyle),
          ),
        ],
      ),
    );
  }
}

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({required this.next, required this.program});

  final NextSession next;
  final Program program;

  Future<void> _start(BuildContext context, [Routine? pick]) async {
    final routine = pick ?? next.routine;
    if (routine.exercises.isNotEmpty) {
      await openRoutineSession(context, routine);
      return;
    }
    final store = context.workouts;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.emptyRoutineHint)));
    final result = await Navigator.of(context).push<RoutineEditorResult>(
      MaterialPageRoute(builder: (_) => RoutineEditorScreen(routine: routine)),
    );
    switch (result) {
      case RoutineSaved(:final routine):
        await store.saveRoutine(routine);
      case RoutineDeleted():
        await store.deleteRoutine(routine.id);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final routine = next.routine;
    final history = store.chronological;

    final dueLabel = switch (next.daysAway) {
      0 => t.dueToday,
      1 => t.dueTomorrow,
      _ => t.dueOn(t.weekdayShort(next.due.weekday).toUpperCase()),
    };
    final dayName = t.weekdayLong(next.due.weekday);

    // Kapan rutinitas ini terakhir dilatih — dicocokkan lewat nama, karena
    // itulah yang tersimpan di setiap sesi.
    final lastOfRoutine = lastTrainingDay([for (final w in store.workouts) if (w.routine == routine.name) w]);
    final sinceText = lastOfRoutine == null
        ? t.notTrainedYet
        : t.lastTrained(dateOnly(DateTime.now()).difference(lastOfRoutine).inDays);

    const shown = 3;
    final preview = routine.exercises.take(shown).toList();
    final hidden = routine.exercises.length - preview.length;

    return GymCard(
      radius: GymRadius.hero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(t.nextSession)),
              Pill(
                color: next.early ? c.surface2 : c.accentSoft,
                textColor: next.early ? c.text2 : c.accent,
                child: Text(dueLabel, style: const TextStyle(fontSize: 10, letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(routine.name, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          Text(
            program.mode == ProgramMode.weekday ? t.weekdayOf(program.name) : t.rotationOf(program.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: c.text2),
          ),
          const SizedBox(height: 8),
          Text('${t.routineOverview(routine.exercises.length, routine.setCount)} · $sinceText',
              style: TextStyle(fontSize: 13, color: c.text2)),
          if (next.early) ...[
            const SizedBox(height: 10),
            NoteBanner(
              text: program.mode == ProgramMode.weekday ? t.nextTrainingDay(dayName) : t.recoverUntil(dayName),
              icon: Icons.bedtime_outlined,
              tone: c.warn,
            ),
          ],
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 14),
            FutureBuilder<ExerciseCatalog>(
              future: ExerciseCatalog.load(),
              builder: (context, snap) {
                final catalog = snap.data;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.bgNested,
                    borderRadius: BorderRadius.circular(GymRadius.control),
                  ),
                  child: Column(
                    children: [
                      for (final cfg in preview)
                        Builder(builder: (context) {
                          // Target yang sama persis dengan yang akan terbuka
                          // di layar sesi — dihitung dengan fungsi yang sama.
                          final unit = context.unit;
                          final plan = planExercise(configIn(cfg, unit), historyIn(history, unit),
                              routineDefault: routine.policy, unit: unit.label);
                          final work = plan.sets.firstWhere((s) => !s.isWarmup, orElse: () => const SetRow());
                          final target = work.weight > 0
                              ? '${formatWeight(work.weight)} ${context.unitLabel} × ${work.reps}'
                              : '${plan.sets.where((s) => !s.isWarmup).length} × ${work.reps}';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(catalog?.nameOf(cfg.exerciseId) ?? '…',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyLarge),
                                ),
                                const SizedBox(width: 8),
                                Text(target,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text2)),
                              ],
                            ),
                          );
                        }),
                      if (hidden > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(t.moreItems(hidden), style: TextStyle(fontSize: 12, color: c.text3)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          GymButton(label: t.startSession, icon: Icons.play_arrow, onPressed: () => _start(context)),
          const SizedBox(height: 10),
          // Jadwal bilang Push, badan bilang Legs. Rutinitas lain dari split
          // yang sama bisa langsung dimulai dari sini; cursor rotasi lalu
          // bergeser ke sesudah rutinitas yang benar-benar dikerjakan.
          GymButton(
            label: t.otherSession,
            icon: Icons.swap_horiz,
            tone: GymButtonTone.neutral,
            height: 44,
            onPressed: () async {
              final picked = await pickOtherRoutine(context, program: program, current: routine);
              if (picked != null && context.mounted) await _start(context, picked);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GymButton(
                  label: t.skip,
                  icon: Icons.skip_next,
                  tone: GymButtonTone.neutral,
                  height: 44,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final msg = t.skipped;
                    await store.skipNext(DateTime.now());
                    messenger.showSnackBar(SnackBar(content: Text(msg)));
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GymButton(
                  label: t.freestyle,
                  icon: Icons.edit_note_outlined,
                  tone: GymButtonTone.neutral,
                  height: 44,
                  onPressed: () => openFreestyleSession(context, t.freestyle),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sheet "hari ini latihan apa?": semua rutinitas, urutan rotasi dulu.
/// null kalau ditutup tanpa memilih.
Future<Routine?> pickOtherRoutine(BuildContext context, {required Program program, required Routine current}) {
  final store = WorkoutScope.read(context);
  final inProgram = programRoutines(program, store.routines);
  final ids = {for (final r in inProgram) r.id};
  final others = [for (final r in store.routines) if (!ids.contains(r.id)) r];
  return showModalBottomSheet<Routine>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.gym.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet)),
    ),
    builder: (sheet) {
      final c = sheet.gym;
      final t = sheet.t;
      Widget tile(Routine r, {String? note}) {
        final isNext = r.id == current.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isNext ? c.accentSoft : c.bgNested,
            borderRadius: BorderRadius.circular(GymRadius.control),
            child: InkWell(
              borderRadius: BorderRadius.circular(GymRadius.control),
              onTap: () => Navigator.of(sheet).pop(r),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(sheet).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            [t.routineOverview(r.exercises.length, r.setCount), ?note].join(' · '),
                            style: TextStyle(fontSize: 12.5, color: c.text2),
                          ),
                        ],
                      ),
                    ),
                    if (isNext)
                      Pill(
                        color: c.accent,
                        textColor: c.accentInk,
                        child: Text(t.upNext, style: const TextStyle(fontSize: 10, letterSpacing: 0.8)),
                      )
                    else
                      Icon(Icons.play_arrow, color: c.text2),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scroll) => SafeArea(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              SectionLabel(t.otherSessionTitle),
              const SizedBox(height: 4),
              Text(program.mode == ProgramMode.weekday ? t.otherSessionHintWeekday : t.otherSessionHint,
                  style: TextStyle(fontSize: 13, color: c.text2)),
              const SizedBox(height: 14),
              for (final r in inProgram) tile(r),
              for (final r in others) tile(r, note: t.notInProgram),
            ],
          ),
        ),
      );
    },
  );
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.history, required this.today, required this.program, this.weekStartsOn = 1});

  final List<Workout> history;
  final DateTime today;
  final Program? program;
  final int weekStartsOn;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final day = dateOnly(today);
    final monday = weekStart(day, weekStartsOn);
    final trained = {for (final w in history) w.date};
    final planned = program?.mode == ProgramMode.weekday ? program!.days.toSet() : const <int>{};

    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Builder(builder: (context) {
            final d = monday.add(Duration(days: i));
            final done = trained.contains(isoDate(d));
            final isToday = d == day;
            final plannedDay = planned.contains(d.weekday) && !done;
            return Expanded(
              child: Container(
                height: 62,
                decoration: BoxDecoration(
                  color: done ? c.accent : c.surface,
                  borderRadius: BorderRadius.circular(GymRadius.card),
                  border: Border.all(
                    color: done ? Colors.transparent : (isToday ? c.accent : c.border),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.t.weekdayShort(d.weekday).substring(0, 1),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: done ? c.accentInk : c.text2),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${d.day}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: done ? c.accentInk : c.text),
                    ),
                    // Titik kecil untuk hari latihan yang direncanakan di mode
                    // hari tetap — supaya "hari ini libur" terlihat tanpa teks.
                    if (plannedDay)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: accent ? c.accent : c.text),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: c.text2)),
        ],
      ),
    );
  }
}
