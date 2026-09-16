/// Tab Stats — artboard `10 Stats`.
///
/// Tiga sudut pandang atas data yang sama: **Balance** (mana yang kebagian
/// volume), **Fatigue** (apakah pemulihannya cukup), **Strength** (apakah
/// bebannya naik).
library;

import 'package:flutter/material.dart';

import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/demo.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/muscle_volume.dart';

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
                for (final tone in MuscleMap.heatRamp) ...[
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
            BarSeries(
              values: demoWeeklySets,
              leftLabel: '8 wk ago',
              midLabel: '4 wk',
              rightLabel: 'now',
              baselineFraction: 0.6,
            ),
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
            for (final (i, entry) in demoRecovery.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text(context.t.region(entry.$1), style: Theme.of(context).textTheme.bodyLarge)),
                  Text(context.t.daysShort(entry.$2),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        // Di atas seminggu bukan lagi pemulihan, itu terlewat.
                        color: entry.$2 >= 7 ? c.warn : c.text2,
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
    return [
      GymCard(
        radius: GymRadius.large,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionLabel(context.t.estimated1RM)),
                Text('Barbell Row', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
                Icon(Icons.keyboard_arrow_down, size: 18, color: c.text2),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatDelta(demoE1rmPeak),
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1, color: c.text)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('kg', style: TextStyle(fontSize: 13, color: c.text2)),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.doneInk.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(GymRadius.pill),
                    ),
                    child: Text('+8.8% · 12 wk',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.doneInk)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            BarSeries(
                values: demoE1rm,
                leftLabel: context.t.catalogue('12 wk ago'),
                midLabel: context.t.catalogue('6 wk'),
                rightLabel: context.t.catalogue('now')),
          ],
        ),
      ),
      const SizedBox(height: 14),
      GymCard(
        radius: GymRadius.large,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(context.t.strengthByMovement),
            const SizedBox(height: 12),
            for (final (i, m) in demoMovements.indexed) ...[
              if (i > 0) const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(child: Text(m.name, style: Theme.of(context).textTheme.bodyLarge)),
                  Text('${m.value} kg',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.text)),
                  const SizedBox(width: 8),
                  _Change(delta: m.delta),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      GymCard(
        radius: GymRadius.large,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionLabel(context.t.bodyweight)),
                Text(context.t.targetWeight('75.0'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.accent)),
              ],
            ),
            const SizedBox(height: 14),
            BarSeries(
              values: demoBodyweight,
              leftLabel: context.t.catalogue('90 d'),
              midLabel: context.t.catalogue('45 d'),
              rightLabel: context.t.catalogue('now'),
              highlightColor: c.doneInk,
            ),
          ],
        ),
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
