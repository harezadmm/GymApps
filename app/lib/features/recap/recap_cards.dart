/// Kartu-kartu layar Recap: KPI, konsistensi, volume, progres beban & rep,
/// rekor, dan set per otot. Datanya disiapkan `buildRecap`; di sini bentuknya.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/charts.dart';
import '../../core/gym_icons.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_recap.dart';
import '../../core/strings_v3.dart';
import '../../core/theme.dart';
import '../../core/weights.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../domain/models.dart';
import '../../domain/muscle_volume.dart';
import '../../domain/program.dart';
import '../../domain/recap.dart';
import '../session/exercise_history_sheet.dart';

/// "+3" / "−2" untuk selisih bilangan bulat; null kalau tidak ada pembanding
/// atau sama.
ChangePill? _intChange(int now, int before) {
  if (before == 0 && now == 0) return null;
  final d = now - before;
  if (d == 0) return null;
  return ChangePill('${d > 0 ? '+' : '−'}${d.abs()}', tone: d > 0 ? ChangeTone.up : ChangeTone.down);
}

ChangePill? _pctChange(double now, double before) {
  if (before <= 0) return null;
  final pct = ((now - before) / before * 100).round();
  if (pct == 0) return null;
  return ChangePill('${pct > 0 ? '+' : '−'}${pct.abs()}%', tone: pct > 0 ? ChangeTone.up : ChangeTone.down);
}

class RecapKpiGrid extends StatelessWidget {
  const RecapKpiGrid({super.key, required this.recap});

  final Recap recap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final now = recap.now, before = recap.before;
    final minutesChange = (now.minutes == 0 && before.minutes == 0) || now.minutes == before.minutes
        ? null
        : ChangePill(t.minutesDelta(now.minutes - before.minutes),
            tone: now.minutes > before.minutes ? ChangeTone.up : ChangeTone.down);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: GymIcons.calendar,
                hue: c.hues.violet,
                value: '${now.sessions}',
                label: t.kpiSessions,
                change: _intChange(now.sessions, before.sessions),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTile(
                icon: GymIcons.scale,
                hue: c.hues.orange,
                value: context.volume(now.volume),
                label: t.kpiVolume,
                change: _pctChange(now.volume, before.volume),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: GymIcons.clock,
                hue: c.hues.green,
                value: t.hoursMinutes(now.minutes),
                label: t.kpiTime,
                change: minutesChange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTile(
                icon: GymIcons.menu,
                hue: c.hues.cyan,
                value: '${now.workingSets}',
                label: t.kpiSets,
                change: _intChange(now.workingSets, before.workingSets),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.icon, required this.hue, required this.value, required this.label, this.change});

  final IconData icon;
  final Color hue;
  final String value;
  final String label;
  final Widget? change;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return GymCard(
      radius: GymRadius.tile,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HueTile(icon: icon, hue: hue, size: 34, radius: 11, iconSize: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: change == null ? null : FittedBox(fit: BoxFit.scaleDown, child: change),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: c.text2)),
        ],
      ),
    );
  }
}

/// Hari latihan dalam periode, rata-rata menit, istirahat terpanjang,
/// rencana program, dan berat badan.
class RecapConsistencyCard extends StatelessWidget {
  const RecapConsistencyCard({
    super.key,
    required this.recap,
    required this.today,
    required this.weekStartsOn,
    this.planned,
    this.planDone,
  });

  final Recap recap;
  final DateTime today;
  final int weekStartsOn;
  final int? planned;
  final int? planDone;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final trained = recap.trainedDays.toSet();
    final avg = recap.avgSessionMinutes;
    final facts = [
      if (avg != null) t.avgPerSession(avg),
      if (recap.trainedDays.length >= 2) t.longestRest(recap.longestRestDays),
    ];
    final start = recap.bodyweightStart, end = recap.bodyweightEnd;
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(t.consistencyTitle, style: Theme.of(context).textTheme.titleMedium)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(t.daysTrained(trained.length, recap.range.days),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12.5, color: c.text2)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recap.period == RecapPeriod.week)
            _WeekDots(range: recap.range, trained: trained, today: today)
          else
            _MonthGrid(range: recap.range, trained: trained, today: today, weekStartsOn: weekStartsOn),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(facts.join(' · '), style: TextStyle(fontSize: 12.5, height: 1.4, color: c.text2)),
          ],
          if (planned != null && planned! > 0 && planDone != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(planDone! >= planned! ? GymIcons.checkCircle : GymIcons.flag,
                    size: 15, color: planDone! >= planned! ? c.doneInk : c.text2),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(t.planProgress(planDone!, planned!),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.text)),
                ),
              ],
            ),
          ],
          if (end != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(GymIcons.scale, size: 15, color: c.text2),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    start == null ? t.bodyweightNow(context.wUnit(end)) : t.bodyweightTrend(context.w(start), context.wUnit(end)),
                    style: TextStyle(fontSize: 12.5, color: c.text2),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.range, required this.trained, required this.today});

  final RecapRange range;
  final Set<String> trained;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final now = dateOnly(today);
    return Row(
      children: [
        for (var i = 0; i < range.days; i++)
          Builder(builder: (context) {
            final d = DateTime(range.start.year, range.start.month, range.start.day + i);
            final done = trained.contains(isoDate(d));
            final isToday = d == now;
            return Expanded(
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(t.weekdayShort(d.weekday),
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.text2)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done ? c.accentFill : c.surface2,
                      shape: BoxShape.circle,
                      border: isToday && !done ? Border.all(color: c.accent, width: 1.5) : null,
                    ),
                    child: done
                        ? const Icon(GymIcons.check, size: 14, color: Colors.white)
                        : Text('${d.day}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.text2)),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.range, required this.trained, required this.today, required this.weekStartsOn});

  final RecapRange range;
  final Set<String> trained;
  final DateTime today;
  final int weekStartsOn;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final now = dateOnly(today);
    final lead = (range.start.weekday - weekStartsOn) % 7;
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var i = 0; i < range.days; i++) DateTime(range.start.year, range.start.month, range.start.day + i),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    Widget cell(DateTime? d) {
      if (d == null) return const SizedBox(height: 30);
      final done = trained.contains(isoDate(d));
      final isToday = d == now;
      return Center(
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? c.accentFill : null,
            shape: BoxShape.circle,
            border: isToday && !done ? Border.all(color: c.accent, width: 1.5) : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${d.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                  color: done ? Colors.white : c.text2,
                )),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(t.weekdayShort((weekStartsOn - 1 + i) % 7 + 1),
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.text3)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [for (var i = 0; i < 7; i++) Expanded(child: cell(cells[row * 7 + i]))]),
          ),
      ],
    );
  }
}

/// Volume per hari (minggu) atau per tujuh hari (bulan).
class RecapVolumeCard extends StatelessWidget {
  const RecapVolumeCard({super.key, required this.recap});

  final Recap recap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final week = recap.period == RecapPeriod.week;
    final end = DateTime(recap.range.end.year, recap.range.end.month, recap.range.end.day - 1);
    final labels = [
      for (final (i, s) in recap.bucketStarts.indexed)
        if (week)
          t.weekdayShort(s.weekday)
        else
          '${s.day}–${i == recap.bucketStarts.length - 1 ? end.day : recap.bucketStarts[i + 1].day - 1}',
    ];
    final values = recap.volumeBuckets;
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(week ? t.volumePerDay : t.volumePerWeek, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          BarSeries(
            values: values.every((v) => v <= 0) ? const [] : values,
            labels: labels,
            valueFormat: (v) => context.volume(v),
            leftLabel: labels.first,
            midLabel: labels[labels.length ~/ 2],
            rightLabel: labels.last,
          ),
        ],
      ),
    );
  }
}

String _setText(BuildContext context, SetRow s, LogMode mode) {
  final t = context.t;
  if (mode != LogMode.reps) return t.secondsShort(s.seconds);
  if (s.weight <= 0) return 'BW × ${s.reps}';
  return '${context.w(s.weight)} ${context.unitLabel} × ${s.reps}';
}

/// Top set periode lalu → periode ini, dengan pil perubahan perkiraan 1RM.
class RecapExercisesCard extends StatelessWidget {
  const RecapExercisesCard({super.key, required this.recap, this.catalog});

  final Recap recap;
  final ExerciseCatalog? catalog;

  static const shown = 8;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final rows = recap.exercises.take(shown).toList();
    final hidden = recap.exercises.length - rows.length;
    return GymCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(t.loadRepsTitle, style: Theme.of(context).textTheme.titleMedium)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(t.vsPrevious,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, color: c.text2)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          for (final (i, e) in rows.indexed)
            Builder(builder: (context) {
              final name = catalog?.nameOf(e.exerciseId) ?? '…';
              final top = e.topSet, before = e.topSetBefore;
              final sub = top == null
                  ? t.setsSuffix(e.workingSets)
                  : e.isNew
                      ? t.firstTime(_setText(context, top, e.mode))
                      : before != null
                          ? '${_setText(context, before, e.mode)} → ${_setText(context, top, e.mode)}'
                          : _setText(context, top, e.mode);
              final delta = e.e1rmDelta;
              final ChangePill? pill = e.isNew
                  ? ChangePill(t.newTag, tone: ChangeTone.neutral)
                  : delta == null
                      ? null
                      : delta.abs() < 0.05
                          ? ChangePill(t.holdTag, tone: ChangeTone.neutral)
                          : ChangePill(
                              '${delta > 0 ? '+' : '−'}${context.wDelta(delta.abs())} ${context.unitLabel}',
                              tone: delta > 0 ? ChangeTone.up : ChangeTone.down,
                            );
              return InkWell(
                onTap: catalog == null ? null : () => showExerciseHistory(context, exerciseId: e.exerciseId, name: name),
                borderRadius: BorderRadius.circular(GymRadius.small),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: i < rows.length - 1 || hidden > 0
                      ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border)))
                      : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                            const SizedBox(height: 2),
                            Text(sub,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: c.text2, fontFeatures: const [FontFeature.tabularFigures()])),
                          ],
                        ),
                      ),
                      if (e.isRecord) ...[
                        const SizedBox(width: 8),
                        Icon(GymIcons.trophy, size: 16, color: c.warm),
                      ],
                      if (pill != null) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 96),
                          child: FittedBox(fit: BoxFit.scaleDown, child: pill),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(t.moreExercises(hidden), style: TextStyle(fontSize: 12, color: c.text3)),
            ),
        ],
      ),
    );
  }
}

class RecapRecordsCard extends StatelessWidget {
  const RecapRecordsCard({super.key, required this.recap, this.catalog});

  final Recap recap;
  final ExerciseCatalog? catalog;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(GymIcons.trophy, size: 16, color: c.warm),
              const SizedBox(width: 8),
              Expanded(child: Text(t.newRecordsTitle, style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          for (final e in recap.records)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(catalog?.nameOf(e.exerciseId) ?? '…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                  const SizedBox(height: 2),
                  Text(t.recordLine(context.wUnit(e.e1rm!), context.wUnit(e.bestBeforeRange!)),
                      style: TextStyle(fontSize: 12, color: c.text2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _oneDecimal(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? '${r.toInt()}' : '$r';
}

/// Set kerja per otot utama, terbanyak dulu.
class RecapMusclesCard extends StatelessWidget {
  const RecapMusclesCard({super.key, required this.recap});

  final Recap recap;

  static const shown = 8;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final rows = recap.muscleSets.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = rows.take(shown).toList();
    final most = top.isEmpty ? 1 : top.first.value;
    final weeks = recap.range.days / 7;
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.setsPerMuscle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final (i, e) in top.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.muscle(muscleGroupLabel[e.key]!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, color: c.text)),
                      if (recap.period == RecapPeriod.month)
                        Text(t.perWeekAvg(_oneDecimal(e.value / weeks)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: c.text3)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(GymRadius.pill),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: [
                          Positioned.fill(child: ColoredBox(color: c.surface2)),
                          AnimatedValue(
                            value: e.value / math.max(most, 1),
                            builder: (context, v) => FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: v.clamp(0.0, 1.0),
                              heightFactor: 1,
                              child: ColoredBox(color: c.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(t.setsSuffix(e.value),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
