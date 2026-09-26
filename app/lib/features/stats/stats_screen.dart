/// Tab Stats — artboard `10 Stats`.
///
/// Tiga sudut pandang atas data yang sama: **Balance** (mana yang kebagian
/// volume), **Fatigue** (apakah pemulihannya cukup), **Strength** (apakah
/// bebannya naik).
library;

import 'package:flutter/material.dart';
import '../../core/illustration.dart';
import '../../core/weights.dart';
import '../../domain/units.dart';

import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/muscle_volume.dart';
import '../../domain/stats.dart';
import '../session/exercise_history_sheet.dart';
import 'bodyweight_card.dart';
import 'dashboard_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _tab = 0;
  String _range = 'Last 30 days';

  late Future<ExerciseCatalog> _catalog;

  /// Volume periode terpilih dan periode sebelum itu, dihitung dari sesi.
  Map<MuscleGroup, double> _now = const {};
  Map<MuscleGroup, double> _before = const {};
  bool _ready = false;

  /// Katalog yang sudah termuat, untuk menamai gerakan dan memetakan otot.
  ExerciseCatalog? _cat;

  /// Gerakan yang ditampilkan di grafik e1RM. null = yang paling sering dicatat.
  String? _e1rmId;

  @override
  void initState() {
    super.initState();
    _catalog = ExerciseCatalog.load();
  }

  /// Dipanggil ulang setiap kali riwayat berubah, bukan sekali di initState:
  /// menyelesaikan satu sesi harus langsung terlihat di sini, dan `_recompute`
  /// perlu `context` yang belum aman dibaca saat initState.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _recompute(context.workouts.workouts);
  }

  int get _days => switch (_range) { 'Last 7 days' => 7, 'Last 90 days' => 90, _ => 30 };

  Future<void> _recompute(List<Workout> history) async {
    final catalog = await _catalog;
    _cat = catalog;
    // Jangkar waktu diambil dari sesi terakhir, bukan dari hari ini: orang yang
    // libur seminggu tidak boleh membuka layar ini dan melihat semuanya nol.
    final dates = history.map((w) => DateTime.tryParse(w.date)).nonNulls.toList()..sort();
    if (dates.isEmpty) {
      if (mounted) {
        setState(() {
          _now = const {};
          _before = const {};
          _ready = true;
        });
      }
      return;
    }
    final end = dates.last.add(const Duration(days: 1));
    final start = end.subtract(Duration(days: _days));
    final prevStart = start.subtract(Duration(days: _days));
    final now = volumeByMuscle(history, catalog, since: start, until: end);
    final before = volumeByMuscle(history, catalog, since: prevStart, until: start);
    if (!mounted) return;
    setState(() {
      _now = now;
      _before = before;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ScreenHeader(
          title: context.t.stats,
          actions: [
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(GymRadius.pill),
                border: Border.all(color: c.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _range,
                  dropdownColor: c.surface2,
                  borderRadius: BorderRadius.circular(GymRadius.control),
                  icon: Icon(Icons.keyboard_arrow_down, size: 18, color: c.text2),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text),
                  // `value` tetap kunci bahasa Inggris — itu yang dipakai
                  // menghitung jumlah hari. Hanya labelnya yang diterjemahkan.
                  items: [
                    for (final days in [7, 30, 90])
                      DropdownMenuItem(value: 'Last $days days', child: Text(context.t.lastDays(days))),
                  ],
                  onChanged: (v) {
                    setState(() => _range = v ?? _range);
                    _recompute(context.workouts.workouts);
                  },
                ),
              ),
            ),
          ],
        ),
        SegmentedTabs(
          labels: [context.t.balance, context.t.fatigue, context.t.strength],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 16),
        ...switch (_tab) {
          1 => _fatigue(context),
          2 => _strength(context),
          _ => _balance(context),
        },
      ],
    );
  }

  List<Widget> _balance(BuildContext context) {
    final c = context.gym;
    return [
      GymCard(
        radius: GymRadius.large,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionLabel(context.t.muscleHeatmap)),
                Text(context.t.volumeShare, style: TextStyle(fontSize: 12, color: c.text2)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: c.bgNested, borderRadius: BorderRadius.circular(GymRadius.card)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: MuscleMap(height: 240, share: _ready ? muscleShare(_now) : null),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(context.t.low, style: TextStyle(fontSize: 11, color: c.text2)),
                const SizedBox(width: 8),
                // Lima warna yang sama persis dengan yang dipakai peta di
                // atasnya — legenda yang tidak cocok dengan gambarnya lebih
                // buruk daripada tidak ada legenda.
                for (final tone in c.heatRamp) ...[
                  Expanded(
                    child: Container(
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: tone,
                        borderRadius: BorderRadius.circular(GymRadius.pill),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(context.t.high, style: TextStyle(fontSize: 11, color: c.text2)),
              ],
            ),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              if (!_ready) {
                return NoteBanner(
                  text: context.t.readingSessions,
                  icon: Icons.hourglass_empty,
                  tone: c.text2,
                );
              }
              if (_now.isEmpty) {
                return NoteBanner(
                  text: context.t.noSetsInRange,
                  icon: Icons.info_outline,
                  tone: c.text2,
                );
              }
              // Hamstring tidak punya bentuk di artwork Pen, jadi ia dikecualikan
              // dari saran ini: menyebut otot yang tidak bisa ditunjuk di peta
              // hanya membuat orang mencari-cari sesuatu yang tidak ada.
              final worst = leastWorked(_now,
                  among: MuscleGroup.values.toSet()..remove(MuscleGroup.hamstrings));
              return NoteBanner(
                text: context.t.leastVolume(context.t.muscle(muscleGroupLabel[worst]!)),
                icon: Icons.info_outline,
                tone: c.warn,
              );
            }),
          ],
        ),
      ),
      const SizedBox(height: 14),
      GymCard(
        radius: GymRadius.large,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(context.t.bodyRegionsWorked),
            const SizedBox(height: 6),
            Builder(builder: (context) {
              final r = regionShare(_now, _before);
              return RadarChart(axes: [
                for (final name in regionMuscles.keys)
                  RadarAxis(label: context.t.region(name), value: r.current[name] ?? 0, previous: r.previous[name] ?? 0),
              ]);
            }),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(colour: c.accent, label: _range),
                const SizedBox(width: 18),
                _Legend(colour: c.text3, label: context.t.previousPeriod),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _fatigue(BuildContext context) {
    final c = context.gym;
    return [
      GymCard(
        radius: GymRadius.large,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(context.t.weeklySetVolume),
            const SizedBox(height: 14),
            // Tab Fatigue tidak ada di artboard Pen — grafik ini tambahan,
            // jadi angkanya bukan tinggi batang hasil desain melainkan jumlah
            // set sungguhan, dan butuh baseline supaya bedanya kelihatan.
            Builder(builder: (context) {
              final weekly = weeklyWorkingSets(context.workouts.workouts, DateTime.now());
              return BarSeries(
                // Belum ada set sama sekali → biarkan grafik bilang "belum ada
                // data", bukan delapan batang setinggi nol.
                values: weekly.every((v) => v == 0) ? const [] : weekly,
                leftLabel: context.t.catalogue('8 wk ago'),
                midLabel: context.t.catalogue('4 wk'),
                rightLabel: context.t.catalogue('now'),
                baselineFraction: 0.6,
              );
            }),
          ],
        ),
      ),
      const SizedBox(height: 14),
      GymCard(
        radius: GymRadius.large,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(context.t.daysSinceWorked),
            const SizedBox(height: 12),
            if (_cat == null)
              Text(context.t.readingSessions, style: TextStyle(fontSize: 13, color: c.text2))
            else
              for (final (i, entry) in daysSinceRegion(context.workouts.workouts, _cat!, DateTime.now()).entries.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text(context.t.region(entry.key), style: Theme.of(context).textTheme.bodyLarge)),
                    Text(entry.value == null ? '—' : context.t.daysShort(entry.value!),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          // Di atas seminggu bukan lagi pemulihan, itu terlewat.
                          color: (entry.value ?? 0) >= 7 ? c.warn : c.text2,
                        )),
                  ],
                ),
              ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      NoteBanner(
        text: context.t.fatigueNote,
        icon: Icons.construction_outlined,
        tone: c.warn,
      ),
    ];
  }

  List<Widget> _strength(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final history = historyIn(context.workouts.workouts, context.unit);
    final now = DateTime.now();
    final logged = loggedExercises(history);
    final catalog = _cat;

    if (logged.isEmpty || catalog == null) {
      return [
        if (catalog == null)
          NoteBanner(text: t.readingSessions, icon: Icons.info_outline, tone: c.text2)
        else
          GymCard(
            radius: GymRadius.large,
            child: EmptyState(art: GymArt.emptyStats, title: t.noStrengthYet, body: t.noSetsInRange),
          ),
        const SizedBox(height: 14),
        const BodyweightCard(),
      ];
    }

    final id = logged.contains(_e1rmId) ? _e1rmId! : logged.first;
    final series = weeklyE1rm(history, id, now);
    final peak = series.last;
    final first = series.firstWhere((v) => v > 0, orElse: () => 0);
    final pct = first > 0 ? (peak - first) / first * 100 : 0.0;
    final movements = strengthByMovement(history, now, count: 12);

    return [
      GymCard(
        radius: GymRadius.large,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionLabel(t.estimated1RM)),
                // Pilih gerakan dari yang benar-benar pernah dicatat.
                PopupMenuButton<String>(
                  tooltip: t.pickExercise,
                  color: c.surface2,
                  onSelected: (v) => setState(() => _e1rmId = v),
                  itemBuilder: (context) => [
                    for (final x in logged)
                      PopupMenuItem(value: x, child: Text(catalog.nameOf(x))),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(catalog.nameOf(id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
                      ),
                      Icon(Icons.keyboard_arrow_down, size: 18, color: c.text2),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatDelta(double.parse(peak.toStringAsFixed(1))),
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1, color: c.text)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(context.unitLabel, style: TextStyle(fontSize: 13, color: c.text2)),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: (pct >= 0 ? c.doneInk : c.danger).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(GymRadius.pill),
                    ),
                    child: Text('${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}% · 12 wk',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: pct >= 0 ? c.doneInk : c.danger)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            BarSeries(
                values: series.every((v) => v == 0) ? const [] : series,
                baselineFraction: 0.6,
                leftLabel: t.catalogue('12 wk ago'),
                midLabel: t.catalogue('6 wk'),
                rightLabel: t.catalogue('now')),
          ],
        ),
      ),
      const SizedBox(height: 14),
      GymCard(
        radius: GymRadius.large,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(t.strengthByMovement),
            const SizedBox(height: 12),
            for (final (i, m) in movements.indexed) ...[
              if (i > 0) const SizedBox(height: 3),
              // Ketuk untuk riwayat dan rekor gerakan itu.
              InkWell(
                onTap: () => showExerciseHistory(context, exerciseId: m.exerciseId, name: catalog.nameOf(m.exerciseId)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(catalog.nameOf(m.exerciseId),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
                      ),
                      const SizedBox(width: 8),
                      Text('${m.best.toStringAsFixed(1)} ${context.unitLabel}',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.text)),
                      const SizedBox(width: 8),
                      _Change(delta: double.parse(m.delta.toStringAsFixed(1))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      const BodyweightCard(),
      const SizedBox(height: 14),
      GymButton(
        label: t.openDashboard,
        icon: Icons.space_dashboard_outlined,
        tone: GymButtonTone.neutral,
        height: 44,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardScreen())),
      ),
    ];
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: c.text2)),
      ],
    );
  }
}

class _Change extends StatelessWidget {
  const _Change({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final tone = delta > 0 ? c.doneInk : (delta < 0 ? c.danger : c.text2);
    final text = delta > 0 ? '+${formatDelta(delta)}' : formatDelta(delta);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(GymRadius.pill),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tone)),
    );
  }
}
