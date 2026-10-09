/// Layar Recap mingguan/bulanan (spec `design/RECAP-AI.md` §3).
///
/// Halaman dorong dari Beranda atau Statistik. Angkanya dihitung ulang setiap
/// build dari riwayat di store — sesi yang baru selesai langsung terlihat.
library;

import 'package:flutter/material.dart';

import '../../core/gym_icons.dart';
import '../../core/illustration.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_history.dart';
import '../../core/strings_recap.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/recap_ai.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/program.dart';
import '../../domain/recap.dart';
import 'recap_ai_card.dart';
import 'recap_cards.dart';

class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key, this.initialPeriod = RecapPeriod.week, this.anchor, this.analyzer, this.today});

  final RecapPeriod initialPeriod;

  /// Satu hari di dalam periode yang dibuka pertama kali. Bawaan: hari ini.
  final DateTime? anchor;

  /// Bawaan: fungsi server. Tes menyuntikkan analis tiruan.
  final RecapAnalyzer? analyzer;

  /// Jam untuk "hari ini" — tes memakai tanggal tetap.
  final DateTime Function()? today;

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  late RecapPeriod _period = widget.initialPeriod;
  RecapRange? _range;
  late final Future<ExerciseCatalog> _catalog = ExerciseCatalog.load();
  late final RecapAnalyzer _analyzer = widget.analyzer ?? ServerRecapAnalyzer();

  DateTime get _now => (widget.today ?? DateTime.now)();

  int get _weekStart => WorkoutScope.read(context).settings.weekStartsOn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _range ??= recapRangeFor(_period, widget.anchor ?? _now, weekStartsOn: _weekStart);
  }

  void _setPeriod(int i) {
    final p = i == 0 ? RecapPeriod.week : RecapPeriod.month;
    if (p == _period) return;
    final r = _range!;
    // Minggu → bulan: bulan tempat minggu itu dimulai. Bulan → minggu: minggu
    // ini kalau bulannya bulan ini, selain itu minggu terakhir bulan itu.
    final anchor = p == RecapPeriod.month
        // Minggu yang berjalan melintasi dua bulan → bulan hari ini.
        ? (r.contains(_now) ? _now : r.start)
        : r.contains(_now)
            ? _now
            : DateTime(r.end.year, r.end.month, r.end.day - 1);
    setState(() {
      _period = p;
      _range = recapRangeFor(p, anchor, weekStartsOn: _weekStart);
    });
  }

  void _shift(int delta) => setState(() => _range = shiftRecapRange(_period, _range!, delta));

  String _rangeLabel(Strings t, RecapRange r) {
    if (_period == RecapPeriod.month) return '${t.monthLong(r.start.month)} ${r.start.year}';
    final a = r.start, b = DateTime(r.end.year, r.end.month, r.end.day - 1);
    final yearA = a.year != _now.year ? ' ${a.year}' : '';
    final yearB = b.year != _now.year ? ' ${b.year}' : '';
    if (a.month == b.month && a.year == b.year) return '${a.day} – ${b.day} ${t.monthShort(b.month)}$yearB';
    return '${a.day} ${t.monthShort(a.month)}$yearA – ${b.day} ${t.monthShort(b.month)}$yearB';
  }

  String _rangeSub(Strings t, RecapRange r) {
    final current = recapRangeFor(_period, _now, weekStartsOn: _weekStart);
    final week = _period == RecapPeriod.week;
    if (r == current) return week ? t.thisWeekLabel : t.thisMonthLabel;
    if (r == shiftRecapRange(_period, current, -1)) return week ? t.lastWeekLabel : t.lastMonthLabel;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final range = _range!;
    final today = dateOnly(_now);
    final canNext = !shiftRecapRange(_period, range, 1).start.isAfter(today);
    final canPrev = store.workouts.any((w) {
      final d = DateTime.tryParse(w.date);
      return d != null && d.isBefore(range.start);
    });
    final sub = _rangeSub(t, range);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: FutureBuilder<ExerciseCatalog>(
          future: _catalog,
          builder: (context, snap) {
            final catalog = snap.data;
            final recap = buildRecap(
              history: store.workouts,
              period: _period,
              range: range,
              catalog: catalog,
              bodyweight: store.bodyweightLog,
              today: _now,
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      GlassIconButton(
                        icon: GymIcons.arrowLeft,
                        tooltip: t.back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Text(t.recapTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
                SegmentedTabs(
                  labels: [t.recapWeekly, t.recapMonthly],
                  index: _period == RecapPeriod.week ? 0 : 1,
                  onChanged: _setPeriod,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    GlassIconButton(
                      key: const ValueKey('recap-prev'),
                      icon: GymIcons.arrowLeft,
                      size: 34,
                      iconSize: 16,
                      tooltip: t.recapPrev,
                      onPressed: canPrev ? () => _shift(-1) : null,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_rangeLabel(t, range),
                                maxLines: 1, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text)),
                          ),
                          if (sub.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(sub, style: TextStyle(fontSize: 12.5, color: c.text2)),
                          ],
                        ],
                      ),
                    ),
                    GlassIconButton(
                      key: const ValueKey('recap-next'),
                      icon: GymIcons.arrowRight,
                      size: 34,
                      iconSize: 16,
                      tooltip: t.recapNext,
                      onPressed: canNext ? () => _shift(1) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Ganti periode memudarkan isi lama dan memunculkan yang baru;
                // kartu AI ikut berganti keadaan karena kuncinya periode.
                FadeSwap(
                  child: Column(
                    key: ValueKey('${_period.name}-${isoDate(range.start)}'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: recap.isEmpty
                        ? [
                            EmptyState(
                              art: GymArt.emptyStats,
                              title: range.contains(_now)
                                  ? (_period == RecapPeriod.week ? t.recapEmptyThisWeek : t.recapEmptyThisMonth)
                                  : t.recapEmptyPast,
                              body: t.recapEmptyBody,
                            ),
                          ]
                        : _cards(context, recap, catalog),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _cards(BuildContext context, Recap recap, ExerciseCatalog? catalog) {
    final t = context.t;
    final store = context.workouts;
    final program = store.program;
    final routines = program == null ? const <Routine>[] : programRoutines(program, store.routines);
    final names = {for (final r in routines) r.name};
    final planned = program == null ? null : plannedSessionsIn(program, recap.range);
    final planDone = program == null
        ? null
        : store.workouts.where((w) {
            final d = DateTime.tryParse(w.date);
            return d != null && recap.range.contains(d) && names.contains(w.routine);
          }).length;
    final payload = catalog == null
        ? null
        : recapPayload(
            recap,
            lang: t.lang == AppLanguage.indonesian ? 'id' : 'en',
            unit: store.settings.unit,
            nameOf: catalog.nameOf,
            program: program == null || planned == null
                ? null
                : RecapProgram(name: program.name, mode: program.mode.name, plannedSessions: planned),
          );
    final elapsed = recap.elapsedDays;
    return [
      Reveal(child: RecapKpiGrid(recap: recap)),
      if (elapsed != null) ...[
        const SizedBox(height: 8),
        Text(
          t.comparedFirstDays(elapsed, week: recap.period == RecapPeriod.week),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: context.gym.text2),
        ),
      ],
      const SizedBox(height: 16),
      Reveal(
        index: 1,
        child: RecapAiCard(
          key: ValueKey('ai-${recap.period.name}-${isoDate(recap.range.start)}'),
          available: store.hasBackend,
          payload: payload,
          account: store.account ?? '',
          period: recap.period,
          start: recap.range.start,
          analyzer: _analyzer,
        ),
      ),
      const SizedBox(height: 16),
      Reveal(
        index: 2,
        child: RecapConsistencyCard(
          recap: recap,
          today: _now,
          weekStartsOn: store.settings.weekStartsOn,
          planned: planned,
          planDone: planDone,
        ),
      ),
      const SizedBox(height: 16),
      Reveal(index: 3, child: RecapVolumeCard(recap: recap)),
      if (recap.exercises.isNotEmpty) ...[
        const SizedBox(height: 16),
        Reveal(index: 4, child: RecapExercisesCard(recap: recap, catalog: catalog)),
      ],
      if (recap.records.isNotEmpty) ...[
        const SizedBox(height: 16),
        Reveal(index: 5, child: RecapRecordsCard(recap: recap, catalog: catalog)),
      ],
      if (recap.muscleSets.isNotEmpty) ...[
        const SizedBox(height: 16),
        Reveal(index: 6, child: RecapMusclesCard(recap: recap)),
      ],
    ];
  }
}
