/// Dashboard untuk layar lebar (milestone M4, FR-G1–G9, disederhanakan).
///
/// Tiga pertanyaan yang tidak bisa dijawab layar ponsel sekilas pandang:
/// seberapa rutin latihannya, gerakan mana yang naik minggu demi minggu, dan
/// gerakan mana yang sudah berhenti naik. Di laptop layar ini boleh melebar;
/// di ponsel tabelnya bisa digeser ke samping.
///
/// Sejak v2.2 periodenya bisa dipilih (12/26/52 minggu), kartunya mengisi
/// satu, dua, atau tiga kolom mengikuti lebar, dan tarik ke bawah menyinkron.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_stats.dart';
import '../../core/theme.dart';
import '../../core/weights.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/assisted.dart';
import '../../domain/models.dart';
import '../../domain/onerm.dart';
import '../../domain/program.dart';
import '../../domain/progression.dart';
import '../../domain/stats.dart';
import '../../domain/units.dart';
import '../session/exercise_history_sheet.dart';

const _weeks = 12;

/// Pilihan periode di chip. 52 minggu = setahun penuh, cukup untuk melihat
/// siklus bulk/cut tanpa membuat tabelnya tak terhingga.
const dashboardPeriods = [12, 26, 52];

/// e1RM terbaik per minggu untuk satu gerakan, terlama dulu; null = minggu
/// tanpa sesi gerakan itu. Mesin assisted tidak menyumbang angka (#232).
List<double?> weeklyBest(List<Workout> history, String exerciseId, DateTime today,
    {int weeks = _weeks, AssistedLookup? isAssisted}) {
  final end = dateOnly(today).add(const Duration(days: 1));
  final out = List<double?>.filled(weeks, null);
  for (final w in history) {
    final d = DateTime.tryParse(w.date);
    if (d == null || !d.isBefore(end)) continue;
    final ago = end.difference(d).inDays ~/ 7;
    if (ago >= weeks) continue;
    for (final e in w.entries) {
      if (e.exerciseId != exerciseId) continue;
      final b = bestSetOf(e, isAssisted: isAssisted)?.est;
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

List<StalledLift> stalledLifts(List<Workout> history, DateTime today, {int window = 3, AssistedLookup? isAssisted}) {
  final out = <StalledLift>[];
  for (final id in loggedExercises(history)) {
    final series = weeklyBest(history, id, today, weeks: 26, isAssisted: isAssisted);
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

/// Deret mingguan yang dijumlahkan per [size] minggu. Dikelompokkan dari
/// kanan supaya kelompok terakhir selalu berakhir di "sekarang"; kalau
/// panjangnya tidak habis dibagi, kelompok paling kiri yang lebih pendek.
List<double> bucketSums(List<double> weekly, int size) {
  final out = <double>[];
  for (var end = weekly.length; end > 0; end -= size) {
    out.add(weekly.sublist(math.max(0, end - size), end).fold(0.0, (a, b) => a + b));
  }
  return out.reversed.toList();
}

/// Periode yang lebih panjang dari ini diringkas per [_bucketWeeks] minggu
/// di grafik sesi (hanya pilihan 52 minggu).
const _bucketAbove = 26;
const _bucketWeeks = 4;

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

/// Arah dua nilai terakhir yang terisi: 1 naik, -1 turun, 0 datar, null kalau
/// belum ada dua titik untuk dibandingkan.
int? trendOf(List<double?> values) {
  final filled = values.whereType<double>().toList();
  if (filled.length < 2) return null;
  final a = filled[filled.length - 2], b = filled.last;
  // Selisih di bawah 0,05 adalah pembulatan estimasi, bukan kemajuan.
  if ((b - a).abs() < 0.05) return 0;
  return b > a ? 1 : -1;
}

/// Deret untuk sparkline: minggu kosong membawa nilai sebelumnya, minggu
/// kosong di awal dibuang. Garis yang jatuh ke nol tiap minggu libur
/// menggambar jadwal, bukan kekuatan.
List<double> carried(List<double?> values) {
  final out = <double>[];
  double? last;
  for (final v in values) {
    if (v != null) last = v;
    if (last != null) out.add(last);
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
  int _weeksShown = _weeks;

  // Penanda lebar diubah sesudah frame, bukan langsung: pendengarnya
  // (pembungkus web di `main.dart`) ada di atas Navigator, dan menandainya
  // kotor dari initState (saat membangun) atau dispose (saat pohon dikunci)
  // memicu assertion "setState() called during build" di mode debug.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) wideLayout.value = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) => wideLayout.value = false);
    super.dispose();
  }

  /// Berapa kolom kartu untuk lebar ini: HP satu, tablet dua, laptop tiga.
  static int columnsFor(double width) => width < 700 ? 1 : (width < 1100 ? 2 : 3);

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final history = historyIn(store.workouts, context.unit);
    final now = DateTime.now();
    final weeks = _weeksShown;
    // Mesin assisted tidak punya e1RM (#232): tidak ada di tabel kekuatan
    // maupun daftar stagnan. Katalog dibaca lewat cache statis karena
    // angka-angka ini dihitung sebelum FutureBuilder di bawah mendapatnya.
    final lifts = strengthByMovement(history, now, count: 10, isAssisted: ExerciseCatalog.assistedById);
    // Minggu deload yang direncanakan bukan bukti stagnan (FR-B10): daftar ini
    // menilai kemajuan, jadi ia membaca riwayat yang sama dengan mesin progresi.
    // Grafik dan volume di bawah tetap memakai riwayat utuh.
    final stalled =
        stalledLifts(progressionHistory(history, store.routines), now, isAssisted: ExerciseCatalog.assistedById);
    final sessions = weeklySessions(history, now, weeks: weeks);
    final unit = context.unitLabel;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: FutureBuilder<ExerciseCatalog>(
          future: _catalog,
          builder: (context, snap) {
            final catalog = snap.data;
            return RefreshIndicator(
              color: c.accent,
              backgroundColor: c.surface,
              onRefresh: store.syncNow,
              child: LayoutBuilder(builder: (context, box) {
                final cols = columnsFor(box.maxWidth);
                final cards = [
                  _sessionsCard(context, sessions, weeks),
                  _summaryCard(context, history, weeks, now),
                  _stalledCard(context, stalled, catalog, unit),
                ];
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Row(children: [
                      SquareIconButton(
                        icon: Icons.arrow_back,
                        tooltip: t.back,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t.dashboard, style: Theme.of(context).textTheme.headlineMedium)),
                    ]),
                    const SizedBox(height: 12),
                    FilterChips(
                      labels: [for (final w in dashboardPeriods) t.weeksChip(w)],
                      index: math.max(0, dashboardPeriods.indexOf(weeks)),
                      onChanged: (i) => setState(() => _weeksShown = dashboardPeriods[i]),
                    ),
                    const SizedBox(height: 14),
                    ..._grid(cards, cols),
                    const SizedBox(height: 14),
                    // Tabel selalu selebar penuh: kolom minggunya yang butuh
                    // ruang, dan itulah alasan layar ini ada.
                    Reveal(
                      index: cards.length,
                      child: GymCard(
                        radius: GymRadius.large,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionLabel(t.e1rmByWeekN(weeks)),
                            const SizedBox(height: 10),
                            if (lifts.isEmpty)
                              Text(t.noSetsInRange, style: TextStyle(fontSize: 13, color: c.text2))
                            else
                              _E1rmTable(
                                weeks: weeks,
                                rows: [
                                  for (final m in lifts)
                                    (
                                      catalog?.nameOf(m.exerciseId) ?? '…',
                                      weeklyBest(history, m.exerciseId, now,
                                          weeks: weeks, isAssisted: ExerciseCatalog.assistedById),
                                    ),
                                ],
                                onTapRow: (i) => showExerciseHistory(context,
                                    exerciseId: lifts[i].exerciseId,
                                    name: catalog?.nameOf(lifts[i].exerciseId) ?? lifts[i].exerciseId),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            );
          },
        ),
      ),
    );
  }

  /// Kartu dibagi per baris sebanyak [cols]; baris terakhir yang kurang
  /// penuh dibiarkan melebar — kartu setengah lebar di samping ruang kosong
  /// terlihat seperti ada yang gagal dimuat.
  List<Widget> _grid(List<Widget> cards, int cols) {
    final out = <Widget>[];
    for (var i = 0; i < cards.length; i += cols) {
      if (i > 0) out.add(const SizedBox(height: 14));
      final row = cards.sublist(i, math.min(i + cols, cards.length));
      if (row.length == 1) {
        out.add(Reveal(index: i, child: row.first));
        continue;
      }
      out.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (j, card) in row.indexed) ...[
            if (j > 0) const SizedBox(width: 14),
            Expanded(child: Reveal(index: i + j, child: card)),
          ],
        ],
      ));
    }
    return out;
  }

  Widget _sessionsCard(BuildContext context, List<double> sessions, int weeks) {
    final t = context.t;
    // 52 batang di kartu selebar sepertiga laptop atau HP 360 dp masing-masing
    // ~5 px: terlalu tipis untuk dibaca, apalagi diketuk. Setahun diringkas
    // per 4 minggu; tabel e1RM di bawah tetap menyimpan rincian mingguannya.
    final size = weeks > _bucketAbove ? _bucketWeeks : 1;
    final values = bucketSums(sessions, size);
    final labels = <String>[];
    for (var end = weeks; end > 0; end -= size) {
      final start = math.max(0, end - size);
      labels.add(t.weekSpan(weeks - 1 - start, weeks - end));
    }
    return GymCard(
      radius: GymRadius.large,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(size == 1 ? t.sessionsPerWeek : t.sessionsPerNWeeks(size)),
          const SizedBox(height: 12),
          BarSeries(
            // Ganti kerapatan (mingguan ↔ 4-mingguan) = grafik baru: indeks
            // batang lama tidak berarti apa-apa di deret yang lain, jadi
            // pilihannya ikut dibuang, bukan digeser.
            key: ValueKey(size),
            values: values.every((v) => v == 0) ? const [] : values,
            labels: labels.reversed.toList(),
            valueFormat: (v) => t.sessionsCount(v.round()),
            leftLabel: t.weekAgo(weeks - 1),
            midLabel: t.weekAgo(weeks ~/ 2),
            rightLabel: t.weekAgo(0),
          ),
        ],
      ),
    );
  }

  /// Angka periode: sesi, set kerja, volume, rata-rata sesi per minggu.
  /// Jangkarnya hari ini, sama seperti grafik sesi di sebelahnya.
  Widget _summaryCard(BuildContext context, List<Workout> history, int weeks, DateTime now) {
    final c = context.gym;
    final t = context.t;
    final end = dateOnly(now).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: weeks * 7));
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
    // Riwayat sudah dalam satuan tampilan; volume ditulis lewat volumeText
    // langsung, bukan context.volume yang mengira masukannya kg.
    final unit = context.unit;
    return GymCard(
      radius: GymRadius.large,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(t.thisPeriod)),
              Text(t.weeksChip(weeks), style: TextStyle(fontSize: 12, color: c.text2)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Metric(label: t.sessionsKpi, value: sessions.toDouble(), format: (v) => v.round().toString(), color: c.hues.violet)),
              const SizedBox(width: 10),
              Expanded(child: _Metric(label: t.workingSetsKpi, value: sets.toDouble(), format: (v) => v.round().toString(), color: c.hues.cyan)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Metric(label: t.volumeKpi, value: volume, format: (v) => volumeText(v, unit), color: c.hues.orange)),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: '${t.sessionsKpi} ${t.perWeek}',
                  value: sessions / weeks,
                  format: (v) => v.toStringAsFixed(1),
                  color: c.hues.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stalledCard(BuildContext context, List<StalledLift> stalled, ExerciseCatalog? catalog, String unit) {
    final c = context.gym;
    final t = context.t;
    return GymCard(
      radius: GymRadius.large,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(t.stalledLifts),
          const SizedBox(height: 10),
          if (stalled.isEmpty)
            Text(t.noneStalled, style: TextStyle(fontSize: 13, color: c.text2))
          else
            for (final (i, s) in stalled.take(8).indexed) ...[
              if (i > 0) const SizedBox(height: 4),
              InkWell(
                onTap: () => showExerciseHistory(context,
                    exerciseId: s.exerciseId, name: catalog?.nameOf(s.exerciseId) ?? s.exerciseId),
                borderRadius: BorderRadius.circular(GymRadius.small),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(catalog?.nameOf(s.exerciseId) ?? '…',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
                        ),
                        const SizedBox(width: 8),
                        Text(t.weeksSinceRecord(s.weeks),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.warn,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            )),
                      ]),
                      const SizedBox(height: 6),
                      // Bilah "minggu sejak rekor": penuh di 12 minggu. Yang
                      // paling lama datar ada di atas, jadi bilahnya mengecil
                      // ke bawah — urutan yang terbaca tanpa membaca angka.
                      _ProgressBar(fraction: math.min(s.weeks, 12) / 12, color: c.warn),
                      const SizedBox(height: 4),
                      Text(t.stalledSince(formatDelta(s.best), s.weeks, unit),
                          style: TextStyle(fontSize: 12, color: c.text2)),
                    ],
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

/// Satu angka kartu ringkasan: label kecil, angka yang menghitung naik.
class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.format, required this.color});

  final String label;
  final double value;
  final String Function(double) format;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(color: c.block(color), borderRadius: BorderRadius.circular(GymRadius.control)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.text2)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountUp(
              value,
              format: format,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bilah tipis yang mengisi ke targetnya saat pertama dibangun.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return SizedBox(
      height: 4,
      width: double.infinity,
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
                child: ColoredBox(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _E1rmTable extends StatelessWidget {
  const _E1rmTable({required this.rows, required this.onTapRow, this.weeks = _weeks});

  final List<(String, List<double?>)> rows;
  final ValueChanged<int> onTapRow;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    const cell = 54.0;
    const rowHeight = 34.0;
    const sparkWidth = 56.0;
    TextStyle head = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.text2);
    // Nama gerakan dan tren tetap di kiri; kolom minggu digeser sendiri dan
    // mulai dari ujung kanan, supaya di layar HP yang pertama terlihat minggu
    // terbaru.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
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
        const SizedBox(width: 8),
        // Sparkline + panah: ringkasan satu baris sebelum angkanya.
        SizedBox(
          width: sparkWidth + 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20, child: Text(t.trend, style: head)),
              for (final (r, (_, values)) in rows.indexed)
                InkWell(
                  onTap: () => onTapRow(r),
                  child: SizedBox(
                    height: rowHeight,
                    child: Row(children: [
                      Sparkline(values: carried(values), width: sparkWidth, height: 18),
                      const SizedBox(width: 6),
                      _TrendArrow(trend: trendOf(values)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
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
                    for (final label in t.weekLabels(weeks)) SizedBox(width: cell, child: Text(label, style: head)),
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

/// ↑ naik (hijau), → datar (abu), ↓ turun (merah), · belum ada pembanding.
class _TrendArrow extends StatelessWidget {
  const _TrendArrow({required this.trend});

  final int? trend;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final (glyph, tone) = switch (trend) {
      1 => ('↑', c.doneInk),
      -1 => ('↓', c.danger),
      0 => ('→', c.text2),
      _ => ('·', c.text3),
    };
    return SizedBox(
      width: 16,
      child: Text(glyph, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tone)),
    );
  }
}
