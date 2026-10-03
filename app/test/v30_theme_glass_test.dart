/// v3 "Bevel glass": token warna dua tema, kaca yang mengikuti aksen, dan
/// tipografi Inter — kontrak antara mockup Pen dan `theme.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/glass.dart';
import 'package:gymapps/core/theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _opaque(Color fg, Color bg) => Color.alphaBlend(fg, bg);

void main() {
  group('token v3', () {
    for (final brightness in Brightness.values) {
      for (final accent in accentChoices) {
        final c = buildGymTheme(accent: accent, brightness: brightness).extension<GymColors>()!;
        final name = '${brightness.name} ${accent.toARGB32().toRadixString(16)}';
        test('kontras teks $name', () {
          expect(_contrast(c.text, c.surface), greaterThanOrEqualTo(4.5));
          expect(_contrast(c.text2, c.surface), greaterThanOrEqualTo(4.5));
          expect(_contrast(c.text2, c.bg), greaterThanOrEqualTo(4.5));
          expect(_contrast(c.accent, c.bg), greaterThanOrEqualTo(4.5));
          expect(_contrast(c.accentInk, c.accentFill), greaterThanOrEqualTo(4.5));
          expect(_contrast(c.doneInk, c.doneBg), greaterThanOrEqualTo(4.5));
          expect(_contrast(c.warn, c.warnSoft), greaterThanOrEqualTo(4.5));
          // Putih di atas bagian bawah gradien kaca (yang lebih gelap) — label
          // tombol utama.
          expect(_contrast(Colors.white, _opaque(c.glass.tintB, c.bg)), greaterThanOrEqualTo(4.5));
        });
        test('kaca dan ramp mengikuti aksen $name', () {
          final hsl = HSLColor.fromColor(c.glass.tintB.withValues(alpha: 1));
          final want = HSLColor.fromColor(c.accentFill);
          expect((hsl.hue - want.hue).abs(), lessThan(2));
          expect(HSLColor.fromColor(c.heatRamp.last).hue, closeTo(HSLColor.fromColor(c.accent).hue, 2));
          expect(c.activityRamp.first, c.surface2);
          expect(c.activityRamp.last, c.accent);
          expect(c.segThumb, isNot(c.surface2));
        });
      }
    }

    test('nilai Pen untuk aksen bawaan', () {
      final light = buildGymTheme(brightness: Brightness.light).extension<GymColors>()!;
      final dark = buildGymTheme().extension<GymColors>()!;
      expect(light.bg, const Color(0xFFF2F2F6));
      expect(light.surface2, const Color(0xFFF4F4F7));
      expect(light.border, const Color(0xFFE7E7EC));
      expect(light.accentSoft, const Color(0xFFEEEBFD));
      expect(light.glass.clear, const Color(0xCCECECF3));
      expect(light.glass.tintA, const Color(0xF27A6AF2));
      expect(dark.bg, const Color(0xFF0D0D10));
      expect(dark.surface, const Color(0xFF1C1C20));
      expect(dark.segThumb, const Color(0xFF3B3B44));
      expect(dark.glass.bar, const Color(0xBF1E1E24));
      expect(dark.hues.pinkSoft, const Color(0xFF3A1F2E));
    });

    test('tipografi Inter saja, judul 28/800', () {
      final theme = buildGymTheme();
      // ThemeData menyalin fontFamily ke seluruh textTheme; yang penting
      // bukan lagi Manrope.
      expect(theme.textTheme.headlineMedium!.fontFamily, anyOf(isNull, 'Inter'));
      expect(theme.textTheme.displaySmall!.fontFamily, anyOf(isNull, 'Inter'));
      expect(theme.textTheme.headlineMedium!.fontSize, 28);
      expect(theme.textTheme.headlineMedium!.fontWeight, FontWeight.w800);
      expect(theme.textTheme.titleLarge!.fontSize, 17);
    });
  });

  group('GlassSurface', () {
    testWidgets('tinted memakai gradien aksen dan tinta putih; blur hanya kalau diminta', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildGymTheme(),
        home: const Scaffold(
          body: Column(children: [
            GlassSurface(tone: GlassTone.tinted, child: SizedBox(width: 100, height: 40)),
            GlassSurface(tone: GlassTone.clear, blur: true, child: SizedBox(width: 100, height: 40)),
          ]),
        ),
      ));
      final decorated = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).toList();
      final tinted = decorated.firstWhere((d) {
        final deco = d.decoration;
        return deco is BoxDecoration && deco.gradient is LinearGradient && (deco.gradient as LinearGradient).colors.first == GlassTokens.darkBase.tintA;
      });
      expect(tinted, isNotNull);
      expect(find.byType(BackdropFilter), findsOneWidget, reason: 'blur hanya kalau diminta');
      final ctx = tester.element(find.byType(Scaffold));
      expect(glassInk(ctx, GlassTone.tinted), Colors.white);
      expect(glassInk(ctx, GlassTone.clear), GymColors.dark.text);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GlassIconButton: target sentuh 44, tooltip, dan ketukan', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: buildGymTheme(),
        home: Scaffold(body: Center(child: GlassIconButton(icon: Icons.add, tooltip: 'Tambah', onPressed: () => taps++))),
      ));
      expect(tester.getSize(find.byType(GlassIconButton)), const Size(44, 44));
      await tester.tap(find.byTooltip('Tambah'));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
