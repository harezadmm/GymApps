/// Tab Stats — artboard `10 Stats`.
///
/// Tiga sudut pandang atas data yang sama: **Balance** (mana yang kebagian
/// volume), **Fatigue** (apakah pemulihannya cukup), **Strength** (apakah
/// bebannya naik).
///
/// Sejak v2.2 grafiknya bisa disentuh: ketuk otot di peta untuk porsinya,
/// ketuk batang untuk angkanya. Di layar ≥ 700 dp kartu disusun dua kolom
/// supaya tablet dan HP mendatar tidak menampilkan satu kolom kurus di tengah.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/gym_icons.dart';
import '../../core/illustration.dart';
import '../../core/layout.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_stats.dart';
import '../../core/strings_v3.dart';
import '../../core/theme.dart';
import '../../core/weights.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/muscle_volume.dart';
import '../../domain/stats.dart';
import '../../domain/units.dart';
import '../session/exercise_history_sheet.dart';
import 'bodyweight_card.dart';
import 'dashboard_screen.dart';

/// Lebar mulai dua kolom. Di bawah ini (semua HP tegak) satu kolom.
const statsWideBreakpoint = 700.0;

/// Ringkasan satu periode untuk baris KPI.
class PeriodSummary {
  const PeriodSummary({required this.sessions, required this.sets, required this.volumeKg});
  final int sessions;
  final int sets;

  /// kg·rep; set bodyweight tidak menyumbang — sama seperti ringkasan selesai.
  final double volumeKg;

  static const empty = PeriodSummary(sessions: 0, sets: 0, volumeKg: 0);
}

/// Jangkar periode: sehari setelah sesi terakhir, bukan hari ini. Orang yang
/// libur seminggu tidak boleh membuka layar ini dan melihat semuanya nol.
DateTime? periodEnd(List<Workout> history) {
  final dates = history.map((w) => DateTime.tryParse(w.date)).nonNulls.toList()..sort();
  return dates.isEmpty ? null : dates.last.add(const Duration(days: 1));
}

/// Sesi, set kerja, dan volume dalam [days] hari terakhir (dari sesi terakhir).
PeriodSummary periodSummary(List<Workout> history, int days) {
  final end = periodEnd(history);
  if (end == null) return PeriodSummary.empty;
  final start = end.subtract(Duration(days: days));
  var sessions = 0, sets = 0;
  var volume = 0.0;
  for (final w in history) {
    final d = DateTime.tryParse(w.date);
    if (d == null || d.isBefore(start) || !d.isBefore(end)) continue;
    sessions++;
    for (final e in w.entries) {
      for (final s in e.sets) {
        if (!s.done || s.isWarmup) continue;
        sets++;
        if (s.weight > 0 && s.reps > 0) volume += s.weight * s.reps;
      }
    }
  }
  return PeriodSummary(sessions: sessions, sets: sets, volumeKg: volume);
}

/// Set kerja per kelompok otot **utama** gerakan. Otot pendukung tidak
/// dihitung: "12 set dada" yang separuhnya dari trisep pushdown bukan angka
/// yang bisa dipakai menyusun program.
Map<MuscleGroup, int> setsByMuscle(List<Workout> history, ExerciseCatalog catalog,
    {DateTime? since, DateTime? until}) {
  final out = <MuscleGroup, int>{};
  for (final w in history) {
    final d = DateTime.tryParse(w.date);
    if (d != null) {
      if (since != null && d.isBefore(since)) continue;
      if (until != null && !d.isBefore(until)) continue;
    }
    for (final e in w.entries) {
      final ex = catalog.byId(e.exerciseId);
      final g = ex == null ? null : muscleGroupFor(ex.target);
      if (g == null) continue;
      final n = e.sets.where((s) => s.done && !s.isWarmup).length;
      if (n > 0) out[g] = (out[g] ?? 0) + n;
    }
  }
  return out;
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const _ranges = [7, 30, 90];

  int _tab = 0;

  /// Tetap kunci bahasa Inggris — itu yang dipakai [_days]; chip hanya
  /// menerjemahkan labelnya.
  String _range = 'Last 30 days';

  late Future<ExerciseCatalog> _catalog;

  /// Volume periode terpilih dan periode sebelum itu, dihitung dari sesi.
  Map<MuscleGroup, double> _now = const {};
  Map<MuscleGroup, double> _before = const {};
  Map<MuscleGroup, int> _sets = const {};
  bool _ready = false;

  /// Katalog yang sudah termuat, untuk menamai gerakan dan memetakan otot.
  ExerciseCatalog? _cat;

  /// Gerakan yang ditampilkan di grafik e1RM. null = yang paling sering dicatat.
  String? _e1rmId;

  /// Otot yang sedang diketuk di peta. null = tidak ada.
  MuscleGroup? _picked;

  /// Keputusan kolom terakhir (dua kolom atau satu), dipegang selama
  /// Dashboard terbuka. Di web, Dashboard melebarkan seluruh aplikasi ke
  /// 1100 px; layar ini masih terlihat di bawahnya selama transisi dorong
  /// dan tutup, dan tanpa penahan ini ia melompat ke dua kolom lalu kembali
  /// — setiap kartu diganti dan setiap Reveal diputar ulang dua kali.
  bool? _wide;

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
    final end = periodEnd(history);
    if (end == null) {
      if (mounted) {
        setState(() {
          _now = const {};
          _before = const {};
          _sets = const {};
          _ready = true;
        });
      }
      return;
    }
    final start = end.subtract(Duration(days: _days));
    final prevStart = start.subtract(Duration(days: _days));
    final now = volumeByMuscle(history, catalog, since: start, until: end);
    final before = volumeByMuscle(history, catalog, since: prevStart, until: start);
    final sets = setsByMuscle(history, catalog, since: start, until: end);
    if (!mounted) return;
    setState(() {
      _now = now;
      _before = before;
      _sets = sets;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Didengarkan, bukan sekadar dibaca: saat Dashboard ditutup, keputusan
    // yang ditahan harus dilepas walau ukuran layar tidak berubah (di HP
    // penanda ini tidak mengubah lebar apa pun, jadi tidak ada yang memicu
    // tata letak ulang).
    return ValueListenableBuilder<bool>(
      valueListenable: wideLayout,
      builder: (context, dashboardOpen, _) => LayoutBuilder(builder: (context, box) {
        if (!dashboardOpen || _wide == null) _wide = box.maxWidth >= statsWideBreakpoint;
        return _page(context, _wide!);
      }),
    );
  }

  Widget _page(BuildContext context, bool wide) {
    final c = context.gym;
    final t = context.t;
    final summary = periodSummary(context.workouts.workouts, _days);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ScreenHeader(title: t.stats),
        FilterChips(
          labels: [for (final d in _ranges) t.rangeChip(d)],
          index: math.max(0, _ranges.indexOf(_days)),
          onChanged: (i) {
            setState(() {
              _range = 'Last ${_ranges[i]} days';
              _picked = null;
            });
            _recompute(context.workouts.workouts);
          },
        ),
        const SizedBox(height: 14),
        Reveal(
          child: Row(
            children: [
              Expanded(
                child: _Kpi(
                  icon: GymIcons.calendar,
                  hue: c.hues.violet,
                  label: t.sessionsKpi,
                  value: summary.sessions.toDouble(),
                  format: (v) => v.round().toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Kpi(
                  icon: GymIcons.menu,
                  hue: c.hues.cyan,
                  label: t.workingSetsKpi,
                  value: summary.sets.toDouble(),
                  format: (v) => v.round().toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Kpi(
                  icon: GymIcons.scale,
                  hue: c.hues.orange,
                  label: t.volumeKpi,
                  value: summary.volumeKg,
                  format: context.volume,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SegmentedTabs(
          labels: [t.balance, t.fatigue, t.strength],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 16),
        // Isi tab memudar saat berganti tab — hanya tab. Ganti rentang
        // bukan isi baru: grafiknya sendiri yang bergerak ke data barunya
        // (radar melayang, batang tumbuh). Kalau rentang ikut di key, satu
        // ketukan chip membangun ulang seluruh tab, radar tidak pernah
        // melayang, dan setiap Reveal/CountUp diputar ulang.
        FadeSwap(
          child: Column(
            key: ValueKey(_tab),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: switch (_tab) {
              1 => _fatigue(context, wide),
              2 => _strength(context, wide),
              _ => _balance(context, wide),
            },
          ),
        ),
      ],
    );
  }

  /// Menyusun kartu: satu kolom di HP, dua kolom berdampingan di layar lebar.
  /// Tiap kartu datang bertingkat; [trailing] (banner, tombol) selalu selebar
  /// penuh di bawahnya.
  List<Widget> _layout(List<Widget> cards, bool wide, {List<Widget> trailing = const []}) {
    final out = <Widget>[];
    if (!wide) {
      for (final (i, card) in cards.indexed) {
        if (i > 0) out.add(const SizedBox(height: 14));
        out.add(Reveal(index: i, child: card));
      }
    } else {
      for (var i = 0; i < cards.length; i += 2) {
        if (i > 0) out.add(const SizedBox(height: 14));
        final second = i + 1 < cards.length ? cards[i + 1] : null;
        out.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Reveal(index: i, child: cards[i])),
            if (second != null) ...[
              const SizedBox(width: 14),
              Expanded(child: Reveal(index: i + 1, child: second)),
            ],
          ],
        ));
      }
    }
    for (final (i, w) in trailing.indexed) {
      out.add(const SizedBox(height: 14));
      out.add(Reveal(index: cards.length + i, child: w));
    }
    return out;
  }

  List<Widget> _balance(BuildContext context, bool wide) {
    final c = context.gym;
    final t = context.t;
    return _layout([
      GymCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(t.muscleHeatmap, trailing: t.volumeShare),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: c.bgNested, borderRadius: BorderRadius.circular(GymRadius.tile)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: MuscleMap(
                height: 244,
                share: _ready ? muscleShare(_now) : null,
                highlight: _picked,
                // Ketuk lagi otot yang sama → lepas.
                onTap: (g) => setState(() => _picked = _picked == g ? null : g),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(t.low, style: TextStyle(fontSize: 11, color: c.text2)),
                const SizedBox(width: 8),
                // Lima warna yang sama persis dengan yang dipakai peta di
                // atasnya — legenda yang tidak cocok dengan gambarnya lebih
                // buruk daripada tidak ada legenda.
                for (final tone in c.heatRamp) ...[
                  Expanded(
                    child: Container(
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(t.high, style: TextStyle(fontSize: 11, color: c.text2)),
              ],
            ),
            const SizedBox(height: 12),
            FadeSwap(child: KeyedSubtree(key: ValueKey(_picked), child: _balanceNote(context))),
          ],
        ),
      ),
      GymCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(t.bodyRegionsWorked),
            const SizedBox(height: 6),
            Builder(builder: (context) {
              final r = regionShare(_now, _before);
              return RadarChart(size: 236, axes: [
                for (final name in regionMuscles.keys)
                  RadarAxis(label: t.region(name), value: r.current[name] ?? 0, previous: r.previous[name] ?? 0),
              ]);
            }),
            const SizedBox(height: 6),
            // Wrap, bukan Row: di kolom sempit (dua kolom di 700 dp) atau
            // terjemahan yang panjang, legenda kedua turun baris, tidak
            // terpotong.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 4,
              children: [
                _Legend(colour: c.accent, label: t.lastDays(_days)),
                _Legend(colour: c.text3, label: t.previousPeriod),
              ],
            ),
          ],
        ),
      ),
    ], wide);
  }

  /// Baris di bawah legenda peta: detail otot yang diketuk, atau saran otot
  /// yang paling tertinggal kalau belum ada yang diketuk.
  Widget _balanceNote(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    if (!_ready) {
      return NoteBanner(text: t.readingSessions, icon: GymIcons.clock, tone: c.text2);
    }
    if (_now.isEmpty) {
      return NoteBanner(text: t.noSetsInRange, icon: GymIcons.info, tone: c.text2);
    }
    final picked = _picked;
    if (picked != null) {
      final total = _now.values.fold(0.0, (a, b) => a + b);
      final pct = total <= 0 ? 0 : ((_now[picked] ?? 0) / total * 100).round();
      return NoteBanner(
        text: t.muscleDetail(t.muscle(muscleGroupLabel[picked]!), pct, _sets[picked] ?? 0),
        icon: GymIcons.info,
        tone: c.accent,
      );
    }
    // Hamstring tidak punya bentuk di artwork Pen, jadi ia dikecualikan
    // dari saran ini: menyebut otot yang tidak bisa ditunjuk di peta
    // hanya membuat orang mencari-cari sesuatu yang tidak ada.
    final worst = leastWorked(_now, among: MuscleGroup.values.toSet()..remove(MuscleGroup.hamstrings));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoteBanner(
          text: t.leastVolume(t.muscle(muscleGroupLabel[worst]!)),
          icon: GymIcons.info,
          tone: c.warn,
        ),
        const SizedBox(height: 8),
        Text(t.tapMuscleHint, style: TextStyle(fontSize: 11.5, color: c.text2)),
      ],
    );
  }

  List<Widget> _fatigue(BuildContext context, bool wide) {
    final c = context.gym;
    final t = context.t;
    final history = context.workouts.workouts;
    final now = DateTime.now();
    const weeks = 8;
    return _layout(
      [
        GymCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(t.weeklySetVolume, subtitle: t.setsPerWeekSub(weeks)),
              const SizedBox(height: 14),
              // Tab Fatigue tidak ada di artboard Pen — grafik ini tambahan,
              // jadi angkanya bukan tinggi batang hasil desain melainkan jumlah
              // set sungguhan, dan butuh baseline supaya bedanya kelihatan.
              Builder(builder: (context) {
                final weekly = weeklyWorkingSets(history, now, weeks: weeks);
                // Rata-rata sejak minggu pertama yang punya set: minggu libur
                // sesudah mulai ikut menarik garisnya (itu memang beban yang
                // lebih rendah), tapi minggu sebelum sesi pertama bukan "nol
                // set" — orangnya belum memakai aplikasi.
                final firstLogged = weekly.indexWhere((v) => v > 0);
                final since = firstLogged < 0 ? const <double>[] : weekly.sublist(firstLogged);
                return BarSeries(
                  // Belum ada set sama sekali → biarkan grafik bilang "belum ada
                  // data", bukan delapan batang setinggi nol.
                  values: weekly.every((v) => v == 0) ? const [] : weekly,
                  labels: t.weekLabels(weeks),
                  valueFormat: (v) => t.setsSuffix(v.round()),
                  average: since.isEmpty ? null : since.fold(0.0, (a, b) => a + b) / since.length,
                  averageFormat: (v) => t.avgSets(v.round()),
                  // Sumbu dari fungsi yang sama dengan gelembungnya.
                  leftLabel: t.weekAgo(weeks - 1),
                  midLabel: t.weekAgo(weeks ~/ 2),
                  rightLabel: t.weekAgo(0),
                  baselineFraction: 0.6,
                );
              }),
            ],
          ),
        ),
        GymCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(t.daysSinceWorked),
              const SizedBox(height: 12),
              if (_cat == null)
                Text(t.readingSessions, style: TextStyle(fontSize: 13, color: c.text2))
              else
                for (final (i, entry) in daysSinceRegion(history, _cat!, now).entries.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text(t.region(entry.key), style: Theme.of(context).textTheme.bodyLarge)),
                      _DaysBar(key: ValueKey('days-bar-$i'), days: entry.value),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 34,
                        child: Text(
                          entry.value == null ? '—' : t.daysShort(entry.value!),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            // Di atas seminggu bukan lagi pemulihan, itu terlewat.
                            color: (entry.value ?? 0) >= 7 ? c.warn : c.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
            ],
          ),
        ),
      ],
      wide,
      trailing: [NoteBanner(text: t.fatigueNote, icon: GymIcons.info, tone: c.warn)],
    );
  }

  List<Widget> _strength(BuildContext context, bool wide) {
    final c = context.gym;
    final t = context.t;
    final history = historyIn(context.workouts.workouts, context.unit);
    final now = DateTime.now();
    final logged = loggedExercises(history);
    final catalog = _cat;

    if (logged.isEmpty || catalog == null) {
      return _layout([
        if (catalog == null)
          NoteBanner(text: t.readingSessions, icon: GymIcons.info, tone: c.text2)
        else
          GymCard(child: EmptyState(art: GymArt.emptyStats, title: t.noStrengthYet, body: t.noSetsInRange)),
        const BodyweightCard(),
      ], wide, trailing: [_dashboardButton(context)]);
    }

    final id = logged.contains(_e1rmId) ? _e1rmId! : logged.first;
    const weeks = 12;
    final series = weeklyE1rm(history, id, now, weeks: weeks);
    final peak = series.last;
    final first = series.firstWhere((v) => v > 0, orElse: () => 0);
    final pct = first > 0 ? (peak - first) / first * 100 : 0.0;
    final movements = strengthByMovement(history, now, count: 12);
    final unit = context.unitLabel;

    return _layout(
      [
        GymCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(t.estimated1RM, style: Theme.of(context).textTheme.titleMedium)),
                  const SizedBox(width: 8),
                  // Pilih gerakan dari yang benar-benar pernah dicatat. Tombol
                  // kaca bening kecil; menunya milik PopupMenuButton (ada).
                  PopupMenuButton<String>(
                    tooltip: t.pickExercise,
                    color: c.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.tile)),
                    onSelected: (v) => setState(() => _e1rmId = v),
                    itemBuilder: (context) => [
                      for (final x in logged) PopupMenuItem(value: x, child: Text(catalog.nameOf(x))),
                    ],
                    child: GlassSurface(
                      tone: GlassTone.clear,
                      radius: 16,
                      height: 32,
                      shadow: false,
                      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(catalog.nameOf(id),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
                          ),
                          const SizedBox(width: 4),
                          Icon(GymIcons.chevronDown, size: 16, color: c.text2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CountUp(
                    peak,
                    format: (v) => formatDelta(double.parse(v.toStringAsFixed(1))),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -0.8,
                      color: c.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(unit, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text2)),
                  ),
                  const SizedBox(width: 10),
                  // Pil persen mengecil kalau angkanya lebar (e1RM tiga digit
                  // di kolom sempit), bukan mendorong keluar kartu.
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: ChangePill(
                          t.pctOverWeeks('${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%', weeks),
                          tone: pct >= 0 ? ChangeTone.up : ChangeTone.down,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              BarSeries(
                values: series.every((v) => v == 0) ? const [] : series,
                labels: t.weekLabels(weeks),
                // e1RM tidak pernah nol untuk set sungguhan: nol di deret ini
                // adalah minggu sebelum sesi pertama gerakan itu. Gelembungnya
                // bilang "belum ada", bukan "0 kg"; BarSeries juga tidak
                // memakainya untuk menarik dasar grafik.
                valueFormat: (v) => v <= 0 ? '—' : '${formatDelta(double.parse(v.toStringAsFixed(1)))} $unit',
                baselineFraction: 0.6,
                leftLabel: t.weekAgo(weeks - 1),
                midLabel: t.weekAgo(weeks ~/ 2),
                rightLabel: t.weekAgo(0),
              ),
            ],
          ),
        ),
        GymCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(t.strengthByMovement, trailing: t.last12Weeks),
              const SizedBox(height: 2),
              for (final (i, m) in movements.indexed)
                // Ketuk untuk riwayat dan rekor gerakan itu.
                Reveal(
                  index: i,
                  child: InkWell(
                    onTap: () => showExerciseHistory(context, exerciseId: m.exerciseId, name: catalog.nameOf(m.exerciseId)),
                    borderRadius: BorderRadius.circular(GymRadius.small),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: i < movements.length - 1
                          ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border)))
                          : null,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(catalog.nameOf(m.exerciseId),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                                const SizedBox(height: 2),
                                Text(t.oneRmShort('${formatDelta(double.parse(m.best.toStringAsFixed(1)))} $unit'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12, color: c.text2, fontFeatures: const [FontFeature.tabularFigures()])),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Sama dengan tabel Dashboard: minggu kosong membawa
                          // nilai sebelumnya, minggu sebelum sesi pertama
                          // dibuang. weeklyE1rm mengisinya dengan nol, dan garis
                          // yang naik dari nol adalah tebing, bukan tren.
                          Sparkline(values: carried(weeklyBest(history, m.exerciseId, now))),
                          const SizedBox(width: 10),
                          // Pil selisih selebar tetap supaya kolomnya rata; isinya
                          // tanpa satuan — baris di kirinya sudah menyebut kg.
                          SizedBox(
                            width: 58,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Builder(builder: (context) {
                                final delta = double.parse(m.delta.toStringAsFixed(1));
                                return ChangePill(
                                  delta > 0 ? '+${formatDelta(delta)}' : formatDelta(delta),
                                  tone: delta > 0
                                      ? ChangeTone.up
                                      : delta < 0
                                          ? ChangeTone.down
                                          : ChangeTone.neutral,
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const BodyweightCard(),
      ],
      wide,
      trailing: [_dashboardButton(context)],
    );
  }

  /// Dashboard selalu bisa dibuka dari sini — juga saat belum ada angkatan,
  /// karena ubin Dashboard di Beranda sudah tidak ada.
  Widget _dashboardButton(BuildContext context) => GymButton(
        label: context.t.openDashboard,
        icon: GymIcons.chart,
        tone: GymButtonTone.neutral,
        height: 46,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardScreen())),
      );
}

/// Judul kartu 15/700 dengan keterangan kecil di kanan atau subjudul di bawah.
class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title, {this.trailing, this.subtitle});

  final String title;
  final String? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(trailing!, style: TextStyle(fontSize: 12, color: c.text2)),
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: TextStyle(fontSize: 12, color: c.text2)),
        ],
      ],
    );
  }
}

/// Ubin KPI: tile hue 30 di atas, angka 20/800 yang menghitung naik, label.
class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.hue,
    required this.label,
    required this.value,
    required this.format,
  });

  final IconData icon;
  final Color hue;
  final String label;
  final double value;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    // Tinggi minimum, bukan tetap: dengan teks diperbesar (1,5× di HP 360 dp)
    // isinya lebih tinggi dari 108 dan ubin tetap meluber. Labelnya satu baris
    // yang mengecil, bukan dua baris — ketiga ubin punya isi setinggi sama,
    // jadi tetap sama tinggi walau salah satu labelnya panjang.
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.tile),
        boxShadow: [c.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          HueTile(icon: icon, hue: hue, size: 30, radius: 10, iconSize: 15),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: CountUp(
                  value,
                  format: format,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: c.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label, maxLines: 1, style: TextStyle(fontSize: 11.5, height: 1.2, color: c.text2)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bilah "hari sejak dilatih" 110×8: penuh di 14 hari. Oranye begitu lewat
/// seminggu — itu bukan pemulihan lagi.
class _DaysBar extends StatelessWidget {
  const _DaysBar({super.key, required this.days});

  final int? days;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final d = days;
    final fraction = d == null ? 0.0 : math.min(d, 14) / 14;
    final tone = (d ?? 0) >= 7 ? c.warn : c.accent;
    return SizedBox(
      width: 110,
      height: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GymRadius.pill),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: c.surface2)),
            AnimatedValue(
              value: fraction,
              builder: (context, v) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v.clamp(0.0, 1.0),
                heightFactor: 1,
                child: ColoredBox(color: tone),
              ),
            ),
          ],
        ),
      ),
    );
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
        Container(width: 9, height: 9, decoration: BoxDecoration(color: colour, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        // Flexible: di Wrap, baris ini mendapat lebar kartu sebagai batas, dan
        // label yang diperbesar 1,5× harus memotong, bukan meluber.
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.text2)),
        ),
      ],
    );
  }
}
