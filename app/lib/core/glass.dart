/// Permukaan kaca (UI v3, spec §1): isian berwarna atau bening, kilau di
/// separuh atas, tepi gradien 1 px, sorot putih tipis di tepi atas, dan
/// bayangan lembut. Tombol utama, chip terpilih, tombol ikon, tab bar, dan
/// pil istirahat semuanya dibangun dari satu widget ini supaya "kaca"-nya
/// satu rupa di seluruh aplikasi.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

enum GlassTone {
  /// Gradien aksen — tombol utama, chip terpilih, tombol tengah tab bar.
  tinted,

  /// Bening — tombol sekunder, tombol ikon, pemilih.
  clear,

  /// Bilah yang mengapung — tab bar, pil istirahat.
  bar,
}

/// Warna teks/ikon di atas permukaan [tone]: putih di atas kaca berwarna,
/// warna teks biasa di atas kaca bening.
Color glassInk(BuildContext context, GlassTone tone) => tone == GlassTone.tinted ? Colors.white : context.gym.text;

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.tone = GlassTone.clear,
    this.radius = GymRadius.button,
    this.blur = false,
    this.padding,
    this.shadow = true,
    this.width,
    this.height,
    this.alignment,
  });

  final Widget child;
  final GlassTone tone;
  final double radius;

  /// Blur latar hanya untuk permukaan yang mengapung di atas isi yang
  /// bergulir (tab bar, pil istirahat, header sesi). Mahal — satu saveLayer
  /// dan pembacaan ulang latar per widget — dan tidak terlihat di tombol yang
  /// duduk di atas latar polos.
  final bool blur;
  final EdgeInsetsGeometry? padding;
  final bool shadow;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final g = c.glass;
    final border = BorderRadius.circular(radius);
    final fill = switch (tone) {
      GlassTone.tinted => BoxDecoration(
          borderRadius: border,
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [g.tintA, g.tintB]),
        ),
      GlassTone.clear => BoxDecoration(borderRadius: border, color: g.clear),
      GlassTone.bar => BoxDecoration(borderRadius: border, color: g.bar),
    };
    final shadows = !shadow
        ? const <BoxShadow>[]
        : switch (tone) {
            GlassTone.tinted => [BoxShadow(color: g.glow, offset: const Offset(0, 6), blurRadius: 16)],
            GlassTone.clear => const [BoxShadow(color: Color(0x1414142B), offset: Offset(0, 6), blurRadius: 16)],
            GlassTone.bar => const [BoxShadow(color: Color(0x2414142B), offset: Offset(0, 10), blurRadius: 30)],
          };
    Widget body = DecoratedBox(
      decoration: fill,
      child: CustomPaint(
        foregroundPainter: _GlassEdgePainter(
          radius: radius,
          edgeTop: g.edgeTop,
          edgeLow: g.edgeLow,
          highlight: tone == GlassTone.tinted ? const Color(0x8CFFFFFF) : const Color(0xB3FFFFFF),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: border,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [GlassTokens.sheenTop, Color(0x00FFFFFF)],
              stops: [0, 0.5],
            ),
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
    if (blur) {
      body = ClipRRect(
        borderRadius: border,
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: body),
      );
    }
    return Container(
      width: width,
      height: height,
      alignment: alignment,
      decoration: BoxDecoration(borderRadius: border, boxShadow: shadows),
      child: body,
    );
  }
}

/// Tepi 1 px di dalam: gradien vertikal edgeTop → edgeLow (55 %) → edgeTop,
/// plus garis sorot putih tipis di tepi atas — dua hal yang membuat permukaan
/// datar terbaca sebagai kaca yang punya tebal.
class _GlassEdgePainter extends CustomPainter {
  _GlassEdgePainter({required this.radius, required this.edgeTop, required this.edgeLow, required this.highlight});

  final double radius;
  final Color edgeTop;
  final Color edgeLow;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final r = (radius - 0.5).clamp(0.0, size.shortestSide / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [edgeTop, edgeLow, edgeTop],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    final inset = radius.clamp(0.0, size.width / 2);
    if (size.width - inset * 2 > 2) {
      canvas.drawLine(
        Offset(inset, 1.5),
        Offset(size.width - inset, 1.5),
        Paint()
          ..color = highlight
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) =>
      old.radius != radius || old.edgeTop != edgeTop || old.edgeLow != edgeLow || old.highlight != highlight;
}

/// Tombol ikon bulat dari kaca: 38 dp di header layar, 40 di header sesi, 34
/// di kartu rutinitas. Area sentuhnya selalu 44 dp (NFR-12).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 38,
    this.iconSize = 18,
    this.tinted = false,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  /// Kaca berwarna (ikon putih) untuk aksi utama; bening untuk yang lain.
  final bool tinted;
  final String? tooltip;

  /// Warna ikon; null = mengikuti [glassInk].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = tinted ? GlassTone.tinted : GlassTone.clear;
    final button = PressScale(
      enabled: onPressed != null,
      scale: 0.92,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: GlassSurface(
            tone: tone,
            radius: size / 2,
            width: size,
            height: size,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed == null
                    ? null
                    : () {
                        GymHaptics.tap();
                        onPressed!();
                      },
                child: Center(child: Icon(icon, size: iconSize, color: color ?? glassInk(context, tone))),
              ),
            ),
          ),
        ),
      ),
    );
    final labelled = Semantics(button: true, label: tooltip, child: button);
    return tooltip == null ? labelled : Tooltip(message: tooltip!, child: labelled);
  }
}
