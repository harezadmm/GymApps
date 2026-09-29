/// Grafik untuk layar Stats, History, dan ringkasan selesai.
///
/// Semuanya digambar sendiri dengan [CustomPainter], tanpa paket grafik: yang
/// dibutuhkan di sini cuma lima bentuk sederhana, dan satu paket grafik
/// membawa ratusan kilobyte plus tema sendiri yang harus dilawan (NFR-3).
///
/// Sejak v2.2 grafiknya bisa disentuh dan bergerak: batang tumbuh saat
/// pertama digambar, radar melayang ke bentuk barunya, peta otot bisa diketuk.
/// Semua gerak lewat `motion.dart` supaya "kurangi gerak" mematikan semuanya.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/muscle_volume.dart';
import 'body_map_data.dart';
import 'format.dart';
import 'motion.dart';
import 'theme.dart';

/// Grafik batang untuk deret waktu — e1RM, set mingguan, berat badan.
///
/// Batang terakhir disorot karena itu yang ditanyakan orang: "sekarang berapa?"
/// Ketuk batang lain untuk membaca nilainya di gelembung kecil; ketuk lagi
/// batang yang sama untuk melepasnya. Pilihan boleh dikendalikan induk lewat
/// [selected] + [onTap], atau dibiarkan diurus sendiri oleh widget ini.
class BarSeries extends StatefulWidget {
  const BarSeries({
    super.key,
    required this.values,
    required this.leftLabel,
    required this.midLabel,
    required this.rightLabel,
    this.highlightColor,
    this.height = 132,
    this.baselineFraction = 0,
    this.labels,
    this.valueFormat,
    this.selected,
    this.onTap,
    this.animate = true,
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
  ///
  /// Di atas nol, nilai ≤ 0 dianggap "tidak ada data" (minggu sebelum sesi
  /// pertama, minggu libur) dan tidak ikut menentukan dasar: digambar sebagai
  /// batang minimum, bukan menarik dasarnya ke nol.
  final double baselineFraction;

  /// Label per batang untuk gelembung ("-3w", tanggal). Sejajar indeks dengan
  /// [values]; boleh lebih pendek — batang tanpa label hanya menampilkan nilai.
  final List<String>? labels;

  /// Pembentuk teks nilai di gelembung. null = angka polos.
  final String Function(double value)? valueFormat;

  /// Batang yang sedang dipilih (dikendalikan induk). null = tidak ada.
  final int? selected;

  /// Dipanggil saat batang diketuk: indeksnya, atau null kalau batang yang
  /// sama diketuk lagi (dilepas).
  final ValueChanged<int?>? onTap;

  /// Tumbuh dari dasar saat pertama dibangun. Matikan untuk grafik yang
  /// digambar berulang di daftar panjang.
  final bool animate;

  @override
  State<BarSeries> createState() => _BarSeriesState();
}

class _BarSeriesState extends State<BarSeries> with SingleTickerProviderStateMixin {
  /// Satu pengendali untuk semua batang: tiap batang mengambil irisannya
  /// lewat [Interval], jadi total durasinya tetap ≤ 600 ms berapa pun jumlah
  /// batangnya — dua belas batang yang datang satu per satu selama dua detik
  /// bukan animasi, itu menunggu.
  late final _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
  bool _started = false;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _enter.value = 1;
    } else {
      _enter.forward();
    }
  }

  @override
  void didUpdateWidget(BarSeries old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      _selected = widget.selected;
    } else if (old.values.length != widget.values.length && widget.selected == null && _selected != null) {
      // Deret berganti panjang (12 → 26 minggu). Semua deret di sini rata
      // kanan di "sekarang", jadi batang yang sama kini ada di indeks lama
      // ditambah selisih panjangnya — tanpa geseran ini "sekarang" yang
      // dipilih di 12 minggu menjadi "-14w" di 26 minggu. Batang yang
      // tergeser keluar dilepas. Pilihan yang dikendalikan induk
      // ([selected] tidak null) dibiarkan: itu urusan induknya.
      final moved = _selected! + widget.values.length - old.values.length;
      _selected = moved >= 0 && moved < widget.values.length ? moved : null;
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _tap(int i) {
    final next = _selected == i ? null : i;
    GymHaptics.tap();
    setState(() => _selected = next);
    widget.onTap?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final values = widget.values;
    final highlight = widget.highlightColor ?? c.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, box) {
              if (values.isEmpty) {
                return Center(child: Text('No data yet', style: TextStyle(fontSize: 12, color: c.text2)));
              }
              // Dasar yang ditarik dihitung dari nilai yang benar-benar ada:
              // nol ikut dihitung melebarkan rentang sampai nol, dan minggu
              // kosong berdiri setinggi sepertiga grafik seperti data.
              final real = widget.baselineFraction > 0 ? values.where((v) => v > 0) : values;
              final lo = (real.isEmpty ? values : real).reduce(math.min);
              final hi = values.reduce(math.max);
              final floor = widget.baselineFraction <= 0 ? 0.0 : lo - (hi - lo) * widget.baselineFraction - 0.01;
              final n = values.length;
              // Celah ikut menyempit saat batangnya rapat: 5 px tetap di
              // antara 52 batang memakan 255 px, dan di bawah ~320 dp lebar
              // batangnya jadi negatif. Seperempat slot menjaga batang tetap
              // tiga kali lebar celahnya; batas 1 px penjaga terakhir.
              final gap = math.min(5.0, box.maxWidth / n * 0.25);
              final w = math.max(1.0, (box.maxWidth - gap * (n - 1)) / n);
              // Semua nilai sama (mis. semuanya nol) → hi == floor. Tanpa
              // penjaga ini tingginya NaN dan layarnya gagal digambar.
              double fraction(double v) => hi <= floor ? 0.0 : ((v - floor) / (hi - floor)).clamp(0.0, 1.0);
              double heightOf(double frac) => math.max(6, frac * box.maxHeight);
              final picked = _selected != null && _selected! >= 0 && _selected! < n ? _selected : null;
              final interactive = widget.onTap != null || widget.labels != null || widget.valueFormat != null;

              return AnimatedBuilder(
                animation: _enter,
                builder: (context, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i < n; i++)
                        Positioned(
                          // Kolom sentuh menjangkau setengah celah ke kiri dan
                          // kanan: jari tidak setepat itu, dan menekan celah
                          // di antara dua batang harus tetap memilih salah satu.
                          left: i * (w + gap) - (i == 0 ? 0 : gap / 2),
                          width: w + (i == 0 ? 0 : gap / 2) + (i == n - 1 ? 0 : gap / 2),
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: interactive ? () => _tap(i) : null,
                            child: Padding(
                              padding: EdgeInsets.only(left: i == 0 ? 0 : gap / 2, right: i == n - 1 ? 0 : gap / 2),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedValue(
                                  value: fraction(values[i]),
                                  begin: fraction(values[i]),
                                  duration: widget.animate ? null : Duration.zero,
                                  builder: (context, frac) {
                                    final on = picked == null ? i == n - 1 : i == picked;
                                    // Tingginya sudah digerakkan dua sumber —
                                    // animasi masuk dan AnimatedValue saat data
                                    // berganti — jadi kotaknya polos. Kalau
                                    // tinggi juga lewat AnimatedContainer, ia
                                    // mengejar target yang pindah tiap frame:
                                    // batang tertinggal dan puluhan animasi
                                    // implisit dimulai ulang setiap frame.
                                    // Yang dianimasikan di sini hanya warna,
                                    // saat pilihan berpindah.
                                    return SizedBox(
                                      width: w,
                                      height: heightOf(frac) * _enterFor(i, n),
                                      child: AnimatedContainer(
                                        duration: GymMotion.of(context, GymMotion.quick),
                                        decoration: BoxDecoration(
                                          color: on ? highlight : c.chartIdle,
                                          borderRadius: BorderRadius.circular(GymRadius.bar),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (picked != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomSingleChildLayout(
                              delegate: _BubbleLayout(
                                anchorX: picked * (w + gap) + w / 2,
                                barTop: box.maxHeight - heightOf(fraction(values[picked])),
                              ),
                              child: _Bubble(
                                key: ValueKey(picked),
                                value: widget.valueFormat?.call(values[picked]) ?? formatDelta(values[picked]),
                                label: widget.labels != null && picked < widget.labels!.length ? widget.labels![picked] : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(widget.leftLabel, style: TextStyle(fontSize: 11, color: c.text3)),
            Expanded(child: Center(child: Text(widget.midLabel, style: TextStyle(fontSize: 11, color: c.text3)))),
            Text(widget.rightLabel, style: TextStyle(fontSize: 11, color: c.text3)),
          ],
        ),
      ],
    );
  }

  /// Irisan animasi masuk untuk batang ke-[i]: mulai bertingkat, semuanya
  /// selesai bersama di ujung.
  double _enterFor(int i, int n) {
    if (_enter.value >= 1) return 1;
    final start = n <= 1 ? 0.0 : (i / n) * 0.45;
    return Interval(start, start + 0.55, curve: GymMotion.curve).transform(_enter.value);
  }
}

/// Menaruh gelembung di atas batang terpilih, digeser ke dalam kalau batangnya
/// di ujung supaya tidak terpotong tepi kartu.
class _BubbleLayout extends SingleChildLayoutDelegate {
  const _BubbleLayout({required this.anchorX, required this.barTop});

  final double anchorX;
  final double barTop;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = (anchorX - childSize.width / 2).clamp(0.0, math.max(0.0, size.width - childSize.width)).toDouble();
    final y = math.max(0.0, barTop - childSize.height - 6);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_BubbleLayout old) => old.anchorX != anchorX || old.barTop != barTop;
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.value, this.label});

  final String value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    // Muncul dengan sedikit "pop": gelembung adalah jawaban atas ketukan, dan
    // jawaban yang tiba-tiba ada terasa seperti sudah ada sejak tadi.
    return AnimatedValue(
      value: 1,
      duration: GymMotion.quick,
      curve: GymMotion.pop,
      builder: (context, t) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.85 + 0.15 * t,
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(GymRadius.small),
              border: Border.all(color: c.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
                if (label != null) Text(label!, style: TextStyle(fontSize: 10.5, color: c.text2)),
              ],
            ),
          ),
        ),
      ),
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
///
/// Poligonnya melayang dari bentuk lama ke bentuk baru saat datanya berganti
/// (rentang 7 → 30 hari), bukan melompat: mata bisa mengikuti sumbu mana yang
/// membesar dan mana yang menciut.
class RadarChart extends StatefulWidget {
  const RadarChart({super.key, required this.axes, this.size = 230});

  final List<RadarAxis> axes;
  final double size;

  @override
  State<RadarChart> createState() => _RadarChartState();
}

class _RadarChartState extends State<RadarChart> {
  /// Bentuk asal animasi: yang terakhir digambar, supaya pergantian data di
  /// tengah animasi melanjutkan dari posisi saat itu, bukan mundur dulu.
  late List<RadarAxis> _from = [for (final a in widget.axes) RadarAxis(label: a.label, value: 0, previous: 0)];
  late List<RadarAxis> _shown = _from;
  int _generation = 0;

  static bool _same(List<RadarAxis> a, List<RadarAxis> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].value != b[i].value || a[i].previous != b[i].previous || a[i].label != b[i].label) return false;
    }
    return true;
  }

  @override
  void didUpdateWidget(RadarChart old) {
    super.didUpdateWidget(old);
    if (_same(old.axes, widget.axes)) return;
    _from = _shown;
    _generation++;
  }

  List<RadarAxis> _lerp(double t) {
    final to = widget.axes;
    return [
      for (var i = 0; i < to.length; i++)
        RadarAxis(
          label: to[i].label,
          value: i < _from.length ? _from[i].value + (to[i].value - _from[i].value) * t : to[i].value,
          previous: i < _from.length ? _from[i].previous + (to[i].previous - _from[i].previous) * t : to[i].previous,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return SizedBox(
      height: widget.size,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_generation),
        tween: Tween(begin: 0, end: 1),
        duration: GymMotion.of(context, GymMotion.slow),
        curve: GymMotion.curve,
        builder: (context, t, _) {
          _shown = _lerp(t);
          return CustomPaint(
            painter: _RadarPainter(
              axes: _shown,
              grid: c.border,
              now: c.accent,
              previous: c.text3,
              label: c.text2,
            ),
            child: const SizedBox.expand(),
          );
        },
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
  bool shouldRepaint(_RadarPainter old) {
    if (old.axes.length != axes.length) return true;
    if (old.grid != grid || old.now != now || old.previous != previous || old.label != label) return true;
    for (var i = 0; i < axes.length; i++) {
      if (old.axes[i].value != axes[i].value ||
          old.axes[i].previous != axes[i].previous ||
          old.axes[i].label != axes[i].label) {
        return true;
      }
    }
    return false;
  }
}

/// Kalender aktivitas gaya kontribusi — satu kotak per hari.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.levels,
    required this.monthLabels,
    this.rows = 7,
    this.onTapCell,
  });

  /// 0 = tidak latihan, 1..4 = makin banyak volume. Urut lama → baru, dibaca
  /// kolom per kolom (satu kolom = satu minggu).
  final List<int> levels;

  final List<String> monthLabels;
  final int rows;

  /// Ketukan pada satu kotak, dengan indeksnya di [levels].
  final ValueChanged<int>? onTapCell;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final weeks = (levels.length / rows).ceil();

    return LayoutBuilder(
      builder: (context, box) {
        const gap = 3.0;
        final cell = ((box.maxWidth - gap * (weeks - 1)) / weeks).clamp(4.0, 14.0);
        // Label bulan selebar kisinya, bukan selebar kartu. Di layar lebar
        // kotaknya berhenti di 14 px dan kisi tidak mengisi kartu; label yang
        // direntang sampai tepi kanan membuat minggu ini tampak di bawah
        // "Jul" padahal sekarang September.
        final width = weeks * cell + (weeks - 1) * gap;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Satu pudar masuk untuk seluruh kisi: 168 kotak yang datang satu
            // per satu hanya jadi kerlip, dan 168 pengendali animasi bukan
            // harga yang pantas untuk kerlip.
            AnimatedValue(
              value: 1,
              builder: (context, t) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: SizedBox(
                  height: rows * cell + (rows - 1) * gap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var w = 0; w < weeks; w++) ...[
                        if (w > 0) const SizedBox(width: gap),
                        Column(
                          children: [
                            for (var d = 0; d < rows; d++) ...[
                              if (d > 0) const SizedBox(height: gap),
                              _cell(c, cell, w * rows + d),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final m in monthLabels) Text(m, style: TextStyle(fontSize: 11, color: c.text3)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cell(GymColors c, double size, int index) {
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _tint(c, index < levels.length ? levels[index] : 0),
        borderRadius: BorderRadius.circular(GymRadius.cell),
      ),
    );
    if (onTapCell == null || index >= levels.length) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onTapCell!(index), child: box);
  }

  Color _tint(GymColors c, int level) => c.activityRamp[level.clamp(0, c.activityRamp.length - 1)];
}

/// Garis kecil tanpa sumbu — tren e1RM di samping nama gerakan.
///
/// Garisnya ditarik dari kiri ke kanan saat pertama dibangun, seperti pena
/// yang menggambar tren itu: mata langsung tahu ke mana arahnya.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.width,
    this.height = 22,
    this.color,
    this.fill = true,
    this.strokeWidth = 1.6,
  });

  final List<double> values;

  /// null = selebar ruang yang tersedia.
  final double? width;
  final double height;
  final Color? color;

  /// Isi tipis di bawah garis.
  final bool fill;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedValue(
        value: 1,
        builder: (context, t) => CustomPaint(
          painter: _SparkPainter(
            values: values,
            color: color ?? c.accent,
            fill: fill,
            strokeWidth: strokeWidth,
            progress: t.clamp(0.0, 1.0),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.color,
    required this.fill,
    required this.strokeWidth,
    required this.progress,
  });

  final List<double> values;
  final Color color;
  final bool fill;
  final double strokeWidth;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || progress <= 0) return;
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final pad = strokeWidth;
    final span = hi - lo;
    // Deret datar (semua nilai sama) digambar di tengah, bukan dibagi nol.
    double y(double v) => span <= 0 ? size.height / 2 : size.height - pad - (v - lo) / span * (size.height - pad * 2);
    final step = size.width / (values.length - 1);

    final line = Path()..moveTo(0, y(values[0]));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(i * step, y(values[i]));
    }

    for (final metric in line.computeMetrics()) {
      final part = metric.extractPath(0, metric.length * progress);
      if (fill) {
        final tangent = metric.getTangentForOffset(metric.length * progress);
        final endX = tangent?.position.dx ?? size.width * progress;
        final area = Path.from(part)
          ..lineTo(endX, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.12));
      }
      canvas.drawPath(
        part,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.fill != fill ||
      old.strokeWidth != strokeWidth ||
      old.values.length != values.length ||
      Iterable.generate(values.length).any((i) => old.values[i] != values[i]);
}

// ── Peta otot ──────────────────────────────────────────────────────────────

/// Kotak gambar artboard Pen (320 × 260) yang dimuat di dalam [size] sambil
/// menjaga rasio, ditaruh di tengah. Painter dan hit-test sama-sama memakai
/// ini: kalau keduanya menghitung sendiri, suatu hari mereka berbeda dan
/// ketukan mengenai otot yang salah.
Rect bodyMapRect(Size size) {
  const aspect = 320 / 260;
  var w = size.width;
  var h = w / aspect;
  if (h > size.height) {
    h = size.height;
    w = h * aspect;
  }
  return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
}

/// Membaca satu bentuk terenkode [bodyHeatmapPaths] menjadi [Path], dengan
/// [map] mengubah koordinat 0..1 ke piksel.
Path encodedBodyPath(List<double> enc, Offset Function(double x, double y) map) {
  final path = Path();
  var k = 0;
  while (k < enc.length) {
    switch (enc[k].toInt()) {
      case 0:
        final o = map(enc[k + 1], enc[k + 2]);
        path.moveTo(o.dx, o.dy);
        k += 3;
      case 1:
        final o = map(enc[k + 1], enc[k + 2]);
        path.lineTo(o.dx, o.dy);
        k += 3;
      case 2:
        final a = map(enc[k + 1], enc[k + 2]), b = map(enc[k + 3], enc[k + 4]), o = map(enc[k + 5], enc[k + 6]);
        path.cubicTo(a.dx, a.dy, b.dx, b.dy, o.dx, o.dy);
        k += 7;
      default:
        path.close();
        k += 1;
    }
  }
  return path;
}

/// Bentuk ke-[index] dalam piksel untuk peta seukuran [size].
Path bodyShapePath(int index, Size size) {
  final box = bodyMapRect(size);
  return encodedBodyPath(
    bodyHeatmapPaths[index],
    (x, y) => Offset(box.left + x * box.width, box.top + y * box.height),
  );
}

/// Kelompok otot di bawah titik [p] pada peta seukuran [size]; null kalau
/// mengenai siluet atau ruang kosong.
///
/// Dicari dari bentuk terakhir ke pertama: bentuk yang digambar belakangan
/// ada di atas, jadi itulah yang orang lihat dan maksudkan. Bentuk teratas
/// yang memuat titiknya yang menentukan — termasuk siluet: potongan siluet
/// yang digambar menutupi otot juga menutupi ketukannya, bukan dilewati
/// sampai ketemu otot yang tidak terlihat di situ.
MuscleGroup? muscleGroupAt(Offset p, Size size) {
  for (var i = bodyHeatmapPaths.length - 1; i >= 0; i--) {
    if (!bodyShapePath(i, size).contains(p)) continue;
    final g = bodyHeatmapGroups[i];
    return g < 0 ? null : MuscleGroup.values[g];
  }
  return null;
}

/// Peta otot depan-belakang — bentuknya diambil apa adanya dari artboard Pen
/// `10 Stats`, lihat [bodyHeatmapPaths].
///
/// Lima tingkat panas dan warnanya sama persis dengan legenda di desain, jadi
/// gambar di aplikasi dan gambar di Pen tidak akan perlahan menyimpang.
class MuscleMap extends StatelessWidget {
  const MuscleMap({super.key, this.height = 250, this.share, this.onTap, this.highlight});

  final double height;

  /// Porsi volume 0..1 per kelompok otot, dari sesi yang benar-benar tercatat.
  ///
  /// null berarti belum ada data — petanya digambar seluruhnya gelap, bukan
  /// memakai tingkat bawaan desain. Peta yang menyala tanpa satu pun sesi
  /// tercatat adalah kebohongan yang sangat meyakinkan.
  final Map<MuscleGroup, double>? share;

  /// Ketukan pada satu otot. Siluet dan ruang kosong tidak memanggil ini.
  final ValueChanged<MuscleGroup>? onTap;

  /// Kelompok yang diberi garis tepi aksen — otot yang sedang dilihat.
  final MuscleGroup? highlight;

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
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, height);
          final paint = CustomPaint(
            painter: _BodyPainter(
              levels: _levels,
              silhouette: c.silhouette,
              ramp: c.heatRamp,
              highlight: highlight == null ? -1 : highlight!.index,
              outline: c.accent,
            ),
            child: const SizedBox.expand(),
          );
          if (onTap == null) return paint;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final g = muscleGroupAt(d.localPosition, size);
              if (g == null) return;
              GymHaptics.tap();
              onTap!(g);
            },
            child: paint,
          );
        },
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.levels,
    required this.silhouette,
    required this.ramp,
    this.highlight = -1,
    this.outline,
  });

  final List<int> levels;
  final Color silhouette;
  final List<Color> ramp;

  /// Indeks [MuscleGroup] yang digoreskan garis tepi; -1 = tidak ada.
  final int highlight;
  final Color? outline;

  @override
  void paint(Canvas canvas, Size size) {
    final box = bodyMapRect(size);
    Offset map(double x, double y) => Offset(box.left + x * box.width, box.top + y * box.height);

    final stroked = <Path>[];
    for (var i = 0; i < bodyHeatmapPaths.length; i++) {
      final level = i < levels.length ? levels[i] : -1;
      final colour = level < 0 ? silhouette : ramp[level.clamp(0, ramp.length - 1)];
      final path = encodedBodyPath(bodyHeatmapPaths[i], map);
      canvas.drawPath(path, Paint()..color = colour..isAntiAlias = true);
      if (highlight >= 0 && bodyHeatmapGroups[i] == highlight) stroked.add(path);
    }
    // Garis tepi digambar setelah semua isian, supaya bentuk tetangga yang
    // digambar belakangan tidak menutupi separuh garisnya.
    if (stroked.isNotEmpty && outline != null) {
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = outline!
        ..isAntiAlias = true;
      for (final p in stroked) {
        canvas.drawPath(p, pen);
      }
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.silhouette != silhouette ||
      old.ramp.first != ramp.first ||
      old.highlight != highlight ||
      old.outline != outline ||
      old.levels.length != levels.length ||
      Iterable.generate(levels.length).any((i) => old.levels[i] != levels[i]);
}

/// Glyph bagian tubuh untuk kategori Library: siluet tubuh dari peta otot
/// yang sama dengan layar Stats, dengan kelompok otot yang dimaksud diwarnai.
///
/// Ini pengganti ikon anatomi dari IconScout yang terlalu rinci untuk 24 px.
/// Bentuknya sudah ada di aplikasi ([bodyHeatmapPaths]), jadi tidak ada aset
/// tambahan, dan gambarnya sama dengan yang orang lihat di Statistik.
class MuscleGlyph extends StatelessWidget {
  const MuscleGlyph({super.key, required this.groups, this.size = 26, this.color, this.base});

  /// Indeks [MuscleGroup] yang disorot; kosong = seluruh tubuh (kardio).
  final List<int> groups;
  final double size;
  final Color? color;
  final Color? base;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MuscleGlyphPainter(
          groups: groups,
          color: color ?? c.accent,
          base: base ?? (color ?? c.accent).withValues(alpha: 0.30),
        ),
      ),
    );
  }
}

class _MuscleGlyphPainter extends CustomPainter {
  _MuscleGlyphPainter({required this.groups, required this.color, required this.base});

  final List<int> groups;
  final Color color;
  final Color base;

  /// Figur depan menempati separuh kiri artboard 320×260, figur belakang
  /// separuh kanan. Pilih figur yang memuat lebih banyak bentuk yang disorot.
  static (int, int) _rangeOf(bool front) => front ? (0, 48) : (48, bodyHeatmapPaths.length);

  Rect _bounds(int from, int to) {
    var l = 1.0, t = 1.0, r = 0.0, b = 0.0;
    for (var i = from; i < to; i++) {
      if (bodyHeatmapGroups[i] != -1) continue;
      final enc = bodyHeatmapPaths[i];
      var k = 0;
      while (k < enc.length) {
        final op = enc[k].toInt();
        final n = op == 0 || op == 1 ? 1 : (op == 2 ? 3 : 0);
        for (var j = 0; j < n; j++) {
          final x = enc[k + 1 + j * 2], y = enc[k + 2 + j * 2];
          if (x < l) l = x;
          if (x > r) r = x;
          if (y < t) t = y;
          if (y > b) b = y;
        }
        k += 1 + n * 2;
      }
    }
    return Rect.fromLTRB(l, t, r, b);
  }

  @override
  void paint(Canvas canvas, Size size) {
    var frontHits = 0, backHits = 0;
    for (var i = 0; i < bodyHeatmapGroups.length; i++) {
      if (groups.contains(bodyHeatmapGroups[i])) {
        if (i < 48) {
          frontHits++;
        } else {
          backHits++;
        }
      }
    }
    final front = groups.isEmpty || frontHits >= backHits;
    final (from, to) = _rangeOf(front);
    final box = _bounds(from, to);
    // Artboard 320×260: sumbu x dan y punya skala berbeda.
    final wPx = box.width * 320, hPx = box.height * 260;
    final scale = math.min(size.width / wPx, size.height / hPx);
    final dx = (size.width - wPx * scale) / 2 - box.left * 320 * scale;
    final dy = (size.height - hPx * scale) / 2 - box.top * 260 * scale;
    Offset p(double x, double y) => Offset(dx + x * 320 * scale, dy + y * 260 * scale);

    for (final pass in [false, true]) {
      for (var i = from; i < to; i++) {
        final g = bodyHeatmapGroups[i];
        final hit = groups.isEmpty ? g != -1 : groups.contains(g);
        if (pass != hit) continue;
        if (!pass && g != -1) continue; // bentuk otot lain: tidak digambar, cukup siluet
        canvas.drawPath(encodedBodyPath(bodyHeatmapPaths[i], p), Paint()..color = hit ? color : base..isAntiAlias = true);
      }
    }
  }

  @override
  bool shouldRepaint(_MuscleGlyphPainter old) =>
      old.color != color || old.base != base || old.groups.join(',') != groups.join(',');
}
