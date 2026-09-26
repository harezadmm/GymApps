/// Riwayat dan rekor satu gerakan, bisa dibuka dari dalam sesi (FR-F2).
///
/// Sebelum set berat orang ingin tahu tiga sesi terakhirnya — naik, turun,
/// kapan deload — tanpa harus keluar dari sesi. Kolom PREV hanya memberi satu
/// sesi.
library;

import 'package:flutter/material.dart';
import '../../domain/units.dart';

import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/onerm.dart';

/// Ringkasan rekor satu gerakan dari riwayat (terbaru dulu atau tidak, sama saja).
class ExerciseRecords {
  const ExerciseRecords({this.heaviest, this.heaviestDate, this.best, this.bestVolume, this.bestVolumeDate});

  final double? heaviest;
  final String? heaviestDate;
  final BestSet? best;
  final double? bestVolume;
  final String? bestVolumeDate;
}

ExerciseRecords recordsFor(List<Workout> workouts, String exerciseId) {
  double? heaviest;
  String? heaviestDate;
  double? volume;
  String? volumeDate;
  for (final w in workouts) {
    for (final e in w.entries) {
      if (e.exerciseId != exerciseId) continue;
      var v = 0.0;
      for (final s in e.sets) {
        if (!s.done || s.isWarmup) continue;
        v += s.weight * s.reps;
        if (s.weight > 0 && (heaviest == null || s.weight > heaviest)) {
          heaviest = s.weight;
          heaviestDate = w.date;
        }
      }
      if (v > 0 && (volume == null || v > volume)) {
        volume = v;
        volumeDate = w.date;
      }
    }
  }
  final chronological = [...workouts]..sort((a, b) => a.date.compareTo(b.date));
  return ExerciseRecords(
    heaviest: heaviest,
    heaviestDate: heaviestDate,
    best: best1RM(chronological, exerciseId),
    bestVolume: volume,
    bestVolumeDate: volumeDate,
  );
}

/// Sesi terakhir yang memuat gerakan ini, terbaru dulu.
List<(Workout, WorkoutEntry)> recentFor(List<Workout> newestFirst, String exerciseId, {int limit = 8}) {
  final out = <(Workout, WorkoutEntry)>[];
  for (final w in newestFirst) {
    for (final e in w.entries) {
      if (e.exerciseId == exerciseId && e.sets.any((s) => s.done && !s.isWarmup)) {
        out.add((w, e));
        break;
      }
    }
    if (out.length >= limit) break;
  }
  return out;
}

String setsSummary(WorkoutEntry e) {
  final done = [for (final s in e.sets) if (s.done && !s.isWarmup) s];
  if (done.isEmpty) return '—';
  final mode = e.target?.mode ?? LogMode.reps;
  return [
    for (final s in done)
      mode == LogMode.time
          ? '${s.seconds}s'
          : '${s.weight > 0 ? '${formatWeight(s.weight)}×' : ''}${s.reps}${switch (s.phase) {
              SetPhase.drop => ' D',
              SetPhase.restPause => ' RP',
              _ => '',
            }}',
  ].join(' · ');
}

Future<void> showExerciseHistory(BuildContext context, {required String exerciseId, required String name}) {
  final store = WorkoutScope.read(context);
  // Rekor dan riwayat dalam satuan tampilan.
  final unit = store.settings.unit;
  final shownHistory = historyIn(store.workouts, unit);
  final recent = recentFor(shownHistory, exerciseId);
  final records = recordsFor(shownHistory, exerciseId);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.gym.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet))),
    builder: (sheet) {
      final c = sheet.gym;
      final t = sheet.t;
      Widget record(String label, String value, String? date) => Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.bgNested, borderRadius: BorderRadius.circular(GymRadius.small)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: c.text2)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value, style: Theme.of(sheet).textTheme.titleMedium),
                  ),
                  if (date != null) Text(date, style: TextStyle(fontSize: 10.5, color: c.text3)),
                ],
              ),
            ),
          );
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, scroll) => SafeArea(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(name, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 14),
              if (recent.isEmpty)
                Text(t.noExerciseHistory, style: TextStyle(fontSize: 13.5, color: c.text2))
              else ...[
                Row(children: [
                  record(t.prHeaviest, records.heaviest == null ? '—' : '${formatWeight(records.heaviest!)} ${unit.label}',
                      records.heaviestDate),
                  const SizedBox(width: 8),
                  record(t.prBestE1rm, records.best == null ? '—' : '${formatDelta(records.best!.est)} ${unit.label}',
                      records.best?.date),
                  const SizedBox(width: 8),
                  record(t.prBestVolume,
                      records.bestVolume == null ? '—' : '${formatDelta(records.bestVolume!)} ${unit.label}', records.bestVolumeDate),
                ]),
                const SizedBox(height: 16),
                SectionLabel(t.history),
                const SizedBox(height: 8),
                for (final (w, e) in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: c.bgNested, borderRadius: BorderRadius.circular(GymRadius.small)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text([w.date, if (w.routine != null) w.routine!].join(' · '),
                              style: TextStyle(fontSize: 11.5, color: c.text2)),
                          const SizedBox(height: 3),
                          Text(setsSummary(e), style: Theme.of(sheet).textTheme.bodyLarge),
                          if (e.note != null) ...[
                            const SizedBox(height: 3),
                            Text(e.note!, style: TextStyle(fontSize: 12, color: c.warn)),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
