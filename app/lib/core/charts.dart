/// Grafik untuk layar Stats, History, dan ringkasan selesai.
///
/// Semuanya digambar sendiri dengan [CustomPainter], tanpa paket grafik: yang
/// dibutuhkan di sini cuma empat bentuk sederhana, dan satu paket grafik
/// membawa ratusan kilobyte plus tema sendiri yang harus dilawan (NFR-3).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/muscle_volume.dart';
import 'body_map_data.dart';
import 'theme.dart';

/// Grafik batang untuk deret waktu — e1RM dan berat badan.
///
/// Batang terakhir disorot karena itu yang ditanyakan orang: "sekarang berapa?"
class BarSeries extends StatelessWidget {
  const BarSeries({
    super.key,
    required this.values,
    required this.leftLabel,
    required this.midLabel,
    required this.rightLabel,
    this.highlightColor,
    this.height = 132,
    this.baselineFraction = 0,
  });

  /// Tinggi batang relatif. Untuk data yang diambil dari Pen, angka ini adalah
  /// tinggi piksel batang di artboard, jadi proporsinya sama persis.
  final List<double> values;

  final String leftLabel;
  final String midLabel;
  final String rightLabel;
  final Color? highlightColor;
  final double height;

  /// Seberapa jauh dasar grafik ditarik ke bawah nilai terendah, sebagai
  /// pecahan dari rentang data.
  ///
  /// `0` menggambar apa adanya dari nol — itu yang dipakai data hasil Pen,
  /// yang baselinenya sudah dihitung di desain. Nilai di atas nol berguna nanti
  /// untuk data e1RM asli: pada rentang 85–90 kg, batang dari nol semuanya
  /// tampak sama tinggi dan kemajuannya hilang.
  final double baselineFraction;


  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, box) {
              if (values.isEmpty) {
                return Center(child: Text('No data yet', style: TextStyle(fontSize: 12, color: c.text2)));
              }
              final lo = values.reduce(math.min);
              final hi = values.reduce(math.max);
              final floor = baselineFraction <= 0 ? 0.0 : lo - (hi - lo) * baselineFraction - 0.01;
              const gap = 5.0;
              final w = (box.maxWidth - gap * (values.length - 1)) / values.length;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, v) in values.indexed) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Container(
                      width: w,
                      // Semua nilai sama (mis. semuanya nol) → hi == floor.
                      // Tanpa penjaga ini tingginya NaN dan layarnya gagal digambar.
                      height: hi <= floor ? 6 : math.max(6, ((v - floor) / (hi - floor)) * box.maxHeight),
                      decoration: BoxDecoration(
                        color: i == values.length - 1 ? (highlightColor ?? c.accent) : c.chartIdle,
                        borderRadius: BorderRadius.circular(GymRadius.bar),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(leftLabel, style: TextStyle(fontSize: 11, color: c.text3)),
            Expanded(child: Center(child: Text(midLabel, style: TextStyle(fontSize: 11, color: c.text3)))),
            Text(rightLabel, style: TextStyle(fontSize: 11, color: c.text3)),
          ],
        ),
      ],
    );
  }
}

/// Satu sumbu radar: nama region dan dua nilai 0..1 untuk dibandingkan.
class RadarAxis {
  const RadarAxis({required this.label, required this.value, required this.previous});
  final String label;
  final double value;
  final double previous;
}

/// Radar "body regions worked" — periode sekarang vs periode sebelumnya.
class RadarChart extends StatelessWidget {
  const RadarChart({super.key, required this.axes, this.size = 230});

  final List<RadarAxis> axes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return SizedBox(
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(
          axes: axes,
          grid: c.border,
          now: c.accent,
          previous: c.text3,
          label: c.text2,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.axes,
    required this.grid,
    required this.now,
    required this.previous,
    required this.label,
  });

  final List<RadarAxis> axes;
  final Color grid;
  final Color now;
  final Color previous;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    if (axes.length < 3) return;
    final centre = Offset(size.width / 2, size.height / 2);
    // Sisakan ruang untuk label di luar jaring.
    final r = math.min(size.width, size.height) / 2 - 34;

    Offset at(int i, double t) {
      final a = -math.pi / 2 + i * 2 * math.pi / axes.length;
      return centre + Offset(math.cos(a), math.sin(a)) * (r * t);
    }

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;

    for (final ring in [0.34, 0.67, 1.0]) {
      final p = Path();
      for (var i = 0; i < axes.length; i++) {
        final o = at(i, ring);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(p..close(), gridPaint);
    }
    for (var i = 0; i < axes.length; i++) {
      canvas.drawLine(centre, at(i, 1), gridPaint);
    }

    void polygon(double Function(RadarAxis) pick, Color colour, {required bool filled}) {
      final p = Path();
      for (var i = 0; i < axes.length; i++) {
        final o = at(i, pick(axes[i]).clamp(0.05, 1.0));
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      p.close();
      canvas.drawPath(p, Paint()..color = colour.withValues(alpha: filled ? 0.22 : 0.10));
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = filled ? 2 : 1.5
          ..color = colour,
      );
    }

    polygon((a) => a.previous, previous, filled: false);
    polygon((a) => a.value, now, filled: true);

    for (var i = 0; i < axes.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: axes[i].label,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: label),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final o = at(i, 1.22);
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.axes != axes;
}

/// Kalender aktivitas gaya kontribusi — satu kotak per hari.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key, required this.levels, required this.monthLabels, this.rows = 7});

  /// 0 = tidak latihan, 1..4 = makin banyak volume. Urut lama → baru, dibaca
  /// kolom per kolom (satu kolom = satu minggu).
  final List<int> levels;

  final List<String> monthLabels;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final weeks = (levels.length / rows).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            const gap = 3.0;
            final cell = ((box.maxWidth - gap * (weeks - 1)) / weeks).clamp(4.0, 14.0);
            return SizedBox(
              height: rows * cell + (rows - 1) * gap,
              child: Row(
                children: [
                  for (var w = 0; w < weeks; w++) ...[
                    if (w > 0) const SizedBox(width: gap),
                    Column(
                      children: [
                        for (var d = 0; d < rows; d++) ...[
                          if (d > 0) const SizedBox(height: gap),
                          Container(
                            width: cell,
                            height: cell,
                            decoration: BoxDecoration(
                              color: _tint(c, w * rows + d < levels.length ? levels[w * rows + d] : 0),
                              borderRadius: BorderRadius.circular(GymRadius.cell),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final m in monthLabels) Text(m, style: TextStyle(fontSize: 11, color: c.text3)),
          ],
        ),
      ],
    );
  }

  Color _tint(GymColors c, int level) => c.activityRamp[level.clamp(0, c.activityRamp.length - 1)];
}

/// Peta otot depan-belakang — bentuknya diambil apa adanya dari artboard Pen
/// `10 Stats`, lihat [bodyHeatmapPaths].
///
/// Lima tingkat panas dan warnanya sama persis dengan legenda di desain, jadi
/// gambar di aplikasi dan gambar di Pen tidak akan perlahan menyimpang.
class MuscleMap extends StatelessWidget {
  const MuscleMap({super.key, this.height = 250, this.share});

  final double height;

  /// Porsi volume 0..1 per kelompok otot, dari sesi yang benar-benar tercatat.
  ///
  /// null berarti belum ada data — petanya digambar seluruhnya gelap, bukan
  /// memakai tingkat bawaan desain. Peta yang menyala tanpa satu pun sesi
  /// tercatat adalah kebohongan yang sangat meyakinkan.
  final Map<MuscleGroup, double>? share;

  /// Tingkat panas per bentuk, diturunkan dari [share].
  List<int> get _levels {
    final s = share;
    return [
      for (final g in bodyHeatmapGroups)
        if (g < 0) -1 else if (s == null) 0 else heatLevelFor(s[MuscleGroup.values[g]] ?? 0),
    ];
  }


  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _BodyPainter(levels: _levels, silhouette: c.silhouette, ramp: c.heatRamp),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({required this.levels, required this.silhouette, required this.ramp});

  final List<int> levels;
  final Color silhouette;
  final List<Color> ramp;

  /// Rasio kotak gambar aslinya di Pen (320 × 260). Dipertahankan supaya
  /// figurnya tidak melar saat kartunya lebih lebar.
  static const _aspect = 320 / 260;

  @override
  void paint(Canvas canvas, Size size) {
    // Muat di dalam kotak sambil menjaga rasio, lalu ditaruh di tengah.
    var w = size.width;
    var h = w / _aspect;
    if (h > size.height) {
      h = size.height;
      w = h * _aspect;
    }
    final dx = (size.width - w) / 2;
    final dy = (size.height - h) / 2;

    for (var i = 0; i < bodyHeatmapPaths.length; i++) {
      final enc = bodyHeatmapPaths[i];
      final level = i < levels.length ? levels[i] : -1;
      final colour = level < 0 ? silhouette : ramp[level.clamp(0, ramp.length - 1)];

      final path = Path();
      var k = 0;
      while (k < enc.length) {
        switch (enc[k].toInt()) {
          case 0:
            path.moveTo(dx + enc[k + 1] * w, dy + enc[k + 2] * h);
            k += 3;
          case 1:
            path.lineTo(dx + enc[k + 1] * w, dy + enc[k + 2] * h);
            k += 3;
          case 2:
            path.cubicTo(
              dx + enc[k + 1] * w, dy + enc[k + 2] * h,
              dx + enc[k + 3] * w, dy + enc[k + 4] * h,
              dx + enc[k + 5] * w, dy + enc[k + 6] * h,
            );
            k += 7;
          default:
            path.close();
            k += 1;
        }
      }
      canvas.drawPath(path, Paint()..color = colour..isAntiAlias = true);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.silhouette != silhouette ||
      old.ramp.first != ramp.first ||
      old.levels.length != levels.length ||
      Iterable.generate(levels.length).any((i) => old.levels[i] != levels[i]);
}
