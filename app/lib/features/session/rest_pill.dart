/// Pil istirahat yang mengapung di bawah layar sesi (spec UI-V3 §7.3):
/// titik hidup + "Istirahat", set berikutnya, sisa waktu besar, −15 / +15,
/// dan tombol lewati. Menggantikan kartu istirahat di daftar dan kapsul di
/// header — satu tempat, selalu di jangkauan ibu jari.
library;

import 'package:flutter/material.dart';

import '../../core/glass.dart';
import '../../core/gym_icons.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_v3.dart';
import '../../core/theme.dart';
import 'rest_timer.dart';

class RestPill extends StatelessWidget {
  const RestPill({
    super.key,
    required this.timer,
    required this.nextLabel,
    required this.onOpen,
    required this.onSkip,
  });

  final RestTimer timer;

  /// "Set 3 · 65 kg × 8" — supaya tidak perlu menggulir saat menunggu.
  final String nextLabel;

  /// Ketuk bagian teks → layar istirahat penuh.
  final VoidCallback onOpen;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return GlassSurface(
      tone: GlassTone.bar,
      blur: true,
      radius: 32,
      height: 64,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: AnimatedBuilder(
        animation: timer,
        builder: (context, _) => Row(
          children: [
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(t.restWord,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.text)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(nextLabel,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: c.text2)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Mengecil hanya kalau pilnya terlalu sempit (huruf sistem besar
            // di HP kecil); di ukuran normal angkanya tetap 22.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatRestWide(timer.remaining),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _AdjustButton(label: '−15', onTap: () => timer.adjust(const Duration(seconds: -15))),
            const SizedBox(width: 6),
            _AdjustButton(label: '+15', onTap: () => timer.adjust(const Duration(seconds: 15))),
            const SizedBox(width: 4),
            GlassIconButton(
              key: const ValueKey('rest-skip'),
              icon: GymIcons.skip,
              size: 44,
              iconSize: 20,
              tinted: true,
              tooltip: t.skipRest,
              onPressed: onSkip,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return GlassSurface(
      tone: GlassTone.clear,
      radius: 18,
      width: 44,
      height: 36,
      shadow: false,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            GymHaptics.tap();
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
        ),
      ),
    );
  }
}
