/// Lembar "Mulai sesi" — dibuka dari tombol + di tengah tab bar (spec §7.2).
///
/// Satu tempat untuk semua cara memulai: sesi bebas, rutinitas program (yang
/// berikutnya ditandai), rutinitas di luar program, dan mencatat sesi yang
/// sudah lewat. Dulu pintu-pintu ini tersebar di Beranda, tab Workout, dan
/// tombol + Riwayat.
library;

import 'package:flutter/material.dart';

import '../../core/gym_icons.dart';
import '../../core/strings.dart';
import '../../core/strings_v3.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/program.dart';
import '../workout/routine_actions.dart';
import 'session_launcher.dart';

Future<void> showStartSessionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.gym.bg,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet))),
    builder: (_) => StartSessionSheet(host: context),
  );
}

class StartSessionSheet extends StatelessWidget {
  const StartSessionSheet({super.key, required this.host});

  /// Context layar di bawah lembar. Sesi dibuka dari sana setelah lembar
  /// ditutup — kalau dibuka dari context lembar, layar sesi ikut terbuang
  /// saat lembarnya pergi.
  final BuildContext host;

  void _go(BuildContext context, Future<void> Function(BuildContext host) action) {
    Navigator.of(context).pop();
    if (host.mounted) action(host);
  }

  /// Penjaga yang sama dengan Program dan Beranda: rutinitas kosong dibawa
  /// ke editor dengan petunjuk, bukan dibuka sebagai sesi tanpa gerakan.
  Future<void> _startRoutine(BuildContext h, Routine r) async {
    if (r.exercises.isEmpty) {
      ScaffoldMessenger.maybeOf(h)?.showSnackBar(SnackBar(content: Text(h.t.emptyRoutineHint)));
      await openRoutineEditor(h, r);
      return;
    }
    await openRoutineSession(h, r);
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
    final subtitle = program == null || next == null
        ? t.startSheetNoProgram
        : program.mode == ProgramMode.weekday
            // Hari libur pada mode hari tetap: sebut hari latihan berikutnya,
            // bukan "dijadwalkan hari ini".
            ? (next.early ? t.nextTrainingDay(t.weekdayLong(next.due.weekday)) : t.startSheetNextToday(next.routine.name))
            : t.startSheetNextRotation(next.routine.name);

    Widget routineRow(Routine r, int hueIndex) => _RoutineRow(
          routine: r,
          hue: c.hues.at(hueIndex),
          isNext: next?.routine.id == r.id,
          onTap: () => _go(context, (h) => _startRoutine(h, r)),
          onMore: () => showRoutineActions(context, r),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.startSheetTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: c.text2)),
            const SizedBox(height: 18),
            _FreestyleRow(onTap: () => _go(context, (h) => openFreestyleSession(h, h.t.freestyle))),
            if (inProgram.isNotEmpty) ...[
              const SizedBox(height: 18),
              SectionLabel(t.programRoutinesLabel),
              const SizedBox(height: 10),
              for (final (i, r) in inProgram.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                routineRow(r, i),
              ],
            ],
            if (others.isNotEmpty) ...[
              const SizedBox(height: 18),
              SectionLabel(t.otherRoutinesLabel),
              const SizedBox(height: 10),
              for (final (i, r) in others.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                routineRow(r, inProgram.length + i),
              ],
            ],
            const SizedBox(height: 18),
            _PastRow(onTap: () => _go(context, openManualEntry)),
          ],
        ),
      ),
    );
  }
}

/// Sesi bebas: baris bergaris putus-putus (garis tipis text3) — "kosong,
/// isi sambil jalan".
class _FreestyleRow extends StatelessWidget {
  const _FreestyleRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GymRadius.tile),
        side: BorderSide(color: c.text3, width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.tile),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(GymRadius.control)),
                child: Icon(GymIcons.plus, size: 20, color: c.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.freestyleRow, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
                    const SizedBox(height: 2),
                    Text(t.freestyleRowSub, style: TextStyle(fontSize: 12.5, color: c.text2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.routine,
    required this.hue,
    required this.isNext,
    required this.onTap,
    required this.onMore,
  });

  final Routine routine;
  final Color hue;
  final bool isNext;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.tile),
        border: isNext ? Border.all(color: c.accent, width: 1.5) : null,
        boxShadow: [c.cardShadow],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GymRadius.tile),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                HueTile(icon: GymIcons.dumbbell, hue: hue, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(routine.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
                          ),
                          if (isNext) ...[
                            const SizedBox(width: 8),
                            Pill(color: c.accentSoft, textColor: c.accent, child: Text(t.next)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(t.routineMeta(routine.exercises.length, routine.setCount),
                          style: TextStyle(fontSize: 12.5, color: c.text2)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Lingkaran 32 yang terlihat, area ketuk 44 di sekelilingnya.
                Tooltip(
                  message: t.routineActions,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onMore,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                            child: Icon(GymIcons.moreVertical, size: 16, color: c.text2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PastRow extends StatelessWidget {
  const _PastRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.tile),
        boxShadow: [c.cardShadow],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GymRadius.tile),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(GymRadius.small)),
                  child: Icon(GymIcons.calendar, size: 18, color: c.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(t.logPastRow, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                ),
                Icon(GymIcons.chevronRight, size: 18, color: c.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
