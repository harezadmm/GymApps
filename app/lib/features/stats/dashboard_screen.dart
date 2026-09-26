/// Dashboard untuk layar lebar (milestone M4, FR-G1–G9, disederhanakan).
///
/// Tiga pertanyaan yang tidak bisa dijawab layar ponsel sekilas pandang:
/// seberapa rutin latihannya, gerakan mana yang naik minggu demi minggu, dan
/// gerakan mana yang sudah berhenti naik. Di laptop layar ini boleh melebar;
/// di ponsel tabelnya bisa digeser ke samping.
library;

import 'package:flutter/material.dart';
import '../../core/weights.dart';
import '../../domain/units.dart';

import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/onerm.dart';
import '../../domain/program.dart';
import '../../domain/stats.dart';
import '../session/exercise_history_sheet.dart';

const _weeks = 12;

/// e1RM terbaik per minggu untuk satu gerakan, terlama dulu; null = minggu
/// tanpa sesi gerakan itu.
List<double?> weeklyBest(List<Workout> history, String exerciseId, DateTime today, {int weeks = _weeks}) {
  final end = dateOnly(today).add(const Duration(days: 1));
  final out = List<double?>.filled(weeks, null);
  for (final w in history) {
    final d = DateTime.tryParse(w.date);
    if (d == null || !d.isBefore(end)) continue;
    final ago = end.difference(d).inDays ~/ 7;
    if (ago >= weeks) continue;
    for (final e in w.entries) {
      if (e.exerciseId != exerciseId) continue;
      final b = bestSetOf(e)?.est;
      if (b == null) continue;
      final i = weeks - 1 - ago;
      if (out[i] == null || b > out[i]!) out[i] = b;
    }
  }
  return out;
}

/// Gerakan yang dilatih dalam 3 minggu terakhir tapi e1RM-nya tidak melewati
/// rekor sebelum itu.
class StalledLift {
  const StalledLift({required this.exerciseId, required this.best, required this.weeks});
  final String exerciseId;
  final double best;
  final int weeks;
}

List<StalledLift> stalledLifts(List<Workout> history, DateTime today, {int window = 3}) {
  final out = <StalledLift>[];
  for (final id in loggedExercises(history)) {
    final series = weeklyBest(history, id, today, weeks: 26);
    final recent = series.sublist(series.length - window).whereType<double>();
    final before = series.sublist(0, series.length - window).whereType<double>();
    if (recent.isEmpty || before.isEmpty) continue;
    final bestBefore = before.reduce((a, b) => a > b ? a : b);
    final bestRecent = recent.reduce((a, b) => a > b ? a : b);
    if (bestRecent > bestBefore) continue;
    // Berapa minggu sejak rekor terakhir dipecahkan.
    var sinceRecord = 0;
    for (var i = series.length - 1; i >= 0; i--) {
      if (series[i] != null && series[i]! >= bestBefore) break;
      sinceRecord++;
    }
    out.add(StalledLift(exerciseId: id, best: bestBefore, weeks: sinceRecord));
  }
  out.sort((a, b) => b.weeks.compareTo(a.weeks));
  return out;
}

List<double> weeklySessions(List<Workout> history, DateTime today, {int weeks = _weeks}) {
  final end = dateOnly(today).add(const Duration(days: 1));
  final out = List<double>.filled(weeks, 0);
  for (final w in history) {
    final d = DateTime.tryParse(w.date);
    if (d == null || !d.isBefore(end)) continue;
    final ago = end.difference(d).inDays ~/ 7;
    if (ago < weeks) out[weeks - 1 - ago] += 1;
  }
  return out;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Future<ExerciseCatalog> _catalog = ExerciseCatalog.load();

  @override
  void initState() {
    super.initState();
    wideLayout.value = true;
  }

  @override
  void dispose() {
    wideLayout.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final history = historyIn(context.workouts.workouts, context.unit);
    final now = DateTime.now();
    final lifts = strengthByMovement(history, now, count: 10);
    final stalled = stalledLifts(history, now);
    final sessions = weeklySessions(history, now);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: FutureBuilder<ExerciseCatalog>(
          future: _catalog,
          builder: (context, snap) {
            final catalog = snap.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back, color: c.text2),
                    tooltip: t.back,
                  ),
                  Text(t.dashboard, style: Theme.of(context).textTheme.headlineMedium),
                ]),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, box) {
                  final wide = box.maxWidth >= 900;
                  final sessionsCard = GymCard(
                    radius: GymRadius.large,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(t.sessionsPerWeek),
                        const SizedBox(height: 12),
                        BarSeries(
                          values: sessions.every((v) => v == 0) ? const [] : sessions,
                          leftLabel: t.catalogue('12 wk ago'),
                          midLabel: t.catalogue('6 wk'),
                          rightLabel: t.catalogue('now'),
                        ),
                      ],
                    ),
                  );
                  final stalledCard = GymCard(
                    radius: GymRadius.large,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(t.stalledLifts),
                        const SizedBox(height: 10),
                        if (stalled.isEmpty)
                          Text(t.noneStalled, style: TextStyle(fontSize: 13, color: c.text2))
                        else
                          for (final s in stalled.take(8))
                            InkWell(
                              onTap: () => showExerciseHistory(context,
                                  exerciseId: s.exerciseId, name: catalog?.nameOf(s.exerciseId) ?? s.exerciseId),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(children: [
                                  Icon(Icons.trending_flat, size: 16, color: c.warn),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(catalog?.nameOf(s.exerciseId) ?? '…',
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(t.stalledSince(formatDelta(s.best), s.weeks, context.unitLabel),
                                      style: TextStyle(fontSize: 12, color: c.text2)),
                                ]),
                              ),
                            ),
                      ],
                    ),
                  );
                  if (!wide) return Column(children: [sessionsCard, const SizedBox(height: 12), stalledCard]);
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: sessionsCard),
                    const SizedBox(width: 12),
                    Expanded(child: stalledCard),
                  ]);
                }),
                const SizedBox(height: 12),
                GymCard(
                  radius: GymRadius.large,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionLabel(t.e1rmByWeek),
                      const SizedBox(height: 10),
                      if (lifts.isEmpty)
                        Text(t.noSetsInRange, style: TextStyle(fontSize: 13, color: c.text2))
                      else
                        _E1rmTable(
                            rows: [
                              for (final m in lifts)
                                (catalog?.nameOf(m.exerciseId) ?? '…', weeklyBest(history, m.exerciseId, now)),
                            ],
                            onTapRow: (i) => showExerciseHistory(context,
                                exerciseId: lifts[i].exerciseId,
                                name: catalog?.nameOf(lifts[i].exerciseId) ?? lifts[i].exerciseId),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _E1rmTable extends StatelessWidget {
  const _E1rmTable({required this.rows, required this.onTapRow});

  final List<(String, List<double?>)> rows;
  final ValueChanged<int> onTapRow;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    const cell = 54.0;
    const rowHeight = 34.0;
    TextStyle head = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.text2);
    // Nama gerakan tetap di kiri; kolom minggu digeser sendiri dan mulai dari
    // ujung kanan, supaya di layar HP yang pertama terlihat minggu terbaru.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              for (final (r, (name, _)) in rows.indexed)
                InkWell(
                  onTap: () => onTapRow(r),
                  child: SizedBox(
                    height: rowHeight,
                    width: double.infinity,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 20,
                  child: Row(children: [
                    for (var i = 0; i < _weeks; i++)
                      SizedBox(width: cell, child: Text(i == _weeks - 1 ? context.t.catalogue('now') : '-${_weeks - 1 - i}w', style: head)),
                  ]),
                ),
                for (final (r, (_, values)) in rows.indexed)
                  InkWell(
                    onTap: () => onTapRow(r),
                    child: SizedBox(
                      height: rowHeight,
                      child: Row(children: [
                        for (var i = 0; i < values.length; i++)
                          SizedBox(
                            width: cell,
                            child: Text(
                              values[i] == null ? '·' : values[i]!.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: values[i] == null
                                    ? c.text3
                                    : (i > 0 && _prevValue(values, i) != null && values[i]! > _prevValue(values, i)!)
                                        ? c.doneInk
                                        : c.text,
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static double? _prevValue(List<double?> v, int i) {
    for (var j = i - 1; j >= 0; j--) {
      if (v[j] != null) return v[j];
    }
    return null;
  }
}
