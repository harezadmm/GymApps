/// Layar istirahat penuh layar.
///
/// **Tidak ada padanannya di artboard Pen** — Pen hanya punya kartu istirahat
/// di dalam sesi (`08 Workout Session`) dan sheet pengatur durasi (`08b`).
/// Layar ini memakai token yang sama supaya tidak terasa asing, tapi tata
/// letaknya baru.
///
/// Alasannya ada: kartu di dalam sesi harus berbagi tempat dengan tabel set,
/// jadi angkanya kecil. Saat istirahat, satu-satunya yang ingin dilihat orang
/// dari jarak satu lengan adalah sisa waktunya.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/gym_icons.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'rest_timer.dart';

/// Buka layar istirahat dan tunggu sampai ditutup.
///
/// [timer] dibagikan dengan layar sesi, jadi hitungannya tetap berjalan kalau
/// layar ini ditutup lebih awal — menutup layar bukan berarti membatalkan
/// istirahat.
Future<void> showRestScreen(
  BuildContext context, {
  required RestTimer timer,
  required String exerciseName,
  required String nextLabel,
  required Future<void> Function() onEditDuration,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RestScreen(
        timer: timer,
        exerciseName: exerciseName,
        nextLabel: nextLabel,
        onEditDuration: onEditDuration,
      ),
    ),
  );
}

class RestScreen extends StatefulWidget {
  const RestScreen({
    super.key,
    required this.timer,
    required this.exerciseName,
    required this.nextLabel,
    required this.onEditDuration,
  });

  final RestTimer timer;
  final String exerciseName;
  final String nextLabel;
  final Future<void> Function() onEditDuration;

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> {
  @override
  void initState() {
    super.initState();
    widget.timer.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.timer.removeListener(_onTick);
    super.dispose();
  }

  /// Tutup sendiri begitu waktunya habis — layar hitung mundur yang menampilkan
  /// 00:00 tidak punya tugas lagi.
  void _onTick() {
    if (!widget.timer.isRunning && mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.timer,
          builder: (context, _) {
            final t = widget.timer;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.keyboard_arrow_down, color: c.text2),
                        tooltip: context.t.backToSession,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionLabel(context.t.resting),
                            const SizedBox(height: 2),
                            Text(widget.exerciseName,
                                style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Cincin membesar sedikit saat layar terbuka — kedatangan,
                // bukan hiasan: detik-detiknya sendiri tidak dianimasikan.
                Reveal(
                  scale: true,
                  slide: false,
                  child: _Dial(progress: t.progress, remaining: t.remaining, total: t.total),
                ),
                const SizedBox(height: 22),
                if (widget.nextLabel.isNotEmpty)
                  Text(widget.nextLabel, style: TextStyle(fontSize: 14, color: c.text2)),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () async {
                    await widget.onEditDuration();
                    if (mounted) setState(() {});
                  },
                  icon: Icon(GymIcons.edit, size: 15, color: c.text2),
                  label: Text(context.t.changeDuration,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text2)),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GymButton(
                              label: '−15s',
                              height: 52,
                              tone: GymButtonTone.neutral,
                              onPressed: () => t.adjust(const Duration(seconds: -15)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GymButton(
                              label: '+15s',
                              height: 52,
                              tone: GymButtonTone.neutral,
                              onPressed: () => t.adjust(const Duration(seconds: 15)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GymButton(
                        label: context.t.skipRest,
                        onPressed: () {
                          GymHaptics.tap();
                          t.skip();
                          Navigator.of(context).maybePop();
                        },
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

/// Cincin besar plus angka di tengahnya.
class _Dial extends StatelessWidget {
  const _Dial({required this.progress, required this.remaining, required this.total});

  final double progress;
  final Duration remaining;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cincin ini menggambar ulang tiap detik. Tanpa batas repaint,
          // seluruh layar ikut digambar ulang bersamanya.
          RepaintBoundary(
            child: CustomPaint(
              size: const Size.square(260),
              painter: _RingPainter(progress: progress, track: c.surface2, ink: c.accent),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatRestWide(remaining),
                style: TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: c.text,
                  // Angka lebar-tetap: tanpa ini seluruh baris bergeser tiap
                  // detik saat lebar digitnya berubah.
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Text(context.t.ofDuration(formatRest(total)),
                  style: TextStyle(fontSize: 14, color: c.text2)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.ink});

  final double progress;
  final Color track;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = size.width / 2 - stroke / 2;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    // Berkurang searah jarum jam dari jam 12, seperti gelang berpasir: yang
    // tersisa yang diwarnai, bukan yang sudah lewat.
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * (1 - progress.clamp(0.0, 1.0)),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
