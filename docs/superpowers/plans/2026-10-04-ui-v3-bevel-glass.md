# UI v3 "Bevel glass" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-skin GymApps (Android + web, one Flutter codebase) to the approved Pen mockup — liquid-glass controls, line icons, light + dark — while keeping every existing feature, then release v3.0.0.

**Architecture:** Tokens live in `GymColors`/`GlassTokens` (theme.dart); one `GlassSurface` primitive renders every glass control; shared widgets (`GymButton`, chips, tabs, tiles) are restyled in place so secondary screens inherit the look; the eight mocked screens are rebuilt to the spec's layout; navigation becomes 4 tabs + a center "+" sheet with Profile as a pushed page. Domain, store, and sync code are untouched.

**Tech Stack:** Flutter 3.47.2 (`D:\sdk\flutter-3.47.2`), Dart ^3.13, `flutter_test`, existing `GymIcons` font, Lottie (kept), no new dependencies.

**Spec:** `design/UI-V3.md` (this plan argues from it; executors read both).

## Global Constraints

- Flutter at `D:\sdk\flutter-3.47.2\bin` first in PATH; `PUB_CACHE=D:\sdk\pub-cache`, `TEMP=TMP=D:\sdk\tmp`, `GRADLE_USER_HOME=D:\sdk\gradle` (see `~/.claude/projects/C--/memory/gymapps-build-windows.md`).
- Run tests as `flutter test --concurrency=4` (RAM pressure); never `dart format` old files.
- No new pub dependencies. No `cacheWidth/cacheHeight` outside `decodePx`.
- Text contrast ≥ 4,5:1 for text/text2/accent/done/warn in both themes and all 5 accents (spec §10).
- Button labels sentence case; snackbar actions stay uppercase.
- Blur (`BackdropFilter`) only in tab bar, rest pill, session header.
- Strings in both languages (`_('EN', 'ID')`), Indonesian as in the mockup.
- Credentials never in the repo; `.secrets/` ignored. Version `3.0.0+24`.
- Commit messages end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`; PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## Review Focus

1. **Accent picker × glass:** a user with the green/orange/pink accent must get a glass gradient and ring/heat ramps derived from that accent, never the violet defaults — test in Task 1 covers all 5 accents, both themes.
2. **Rest pill vs. keyboard:** the floating rest pill must not cover the focused KG field; the list gets bottom padding when the pill shows, and the pill hides behind the keyboard inset — test in Task 10 checks the set row stays above the pill.
3. **Dark-mode selected states:** the segmented thumb (`segThumb`) and today's day dot must be visibly distinct from their track in dark mode — Task 3 test checks `segThumb != surface2` per theme.
4. **Profile as a pushed route:** sign-out from Profile must pop back to the shell before `_signOut` replaces the stage (otherwise a dead route stays on top) — Task 7 test signs out from the pushed Profile and expects the login stage without leftover routes.
5. **Program tab with no program:** loose routines and "Pilih program" must still render and start sessions — Task 9 test runs ProgramScreen with `program == null` and two loose routines.

---

## Phase A — foundation

### Task 1: Tokens, typography, glass tokens

**Files:**
- Modify: `app/lib/core/theme.dart`
- Modify: `app/pubspec.yaml` (remove Manrope fonts)
- Delete: `app/assets/fonts/Manrope-*.ttf`
- Test: `app/test/v30_theme_glass_test.dart` (create)

**Interfaces:**
- Produces: `GymColors` gains `warnSoft`, `warm`, `ringTrack`, `ringA/ringB/ringC`, `segThumb`, `sparkTop`, `sparkBottom`, `washA`, `washB`, `cardShadow` (`BoxShadow`), `glass` (`GlassTokens`); `GymHues` gains `pinkSoft/cyanSoft/orangeSoft` and `soft(Color ink)`; `GymRadius.tile = 18`, `GymRadius.chip = 16`, `GymRadius.button = 26`; `buildGymTheme` unchanged signature; `c.block()` removed.
- `class GlassTokens { tintA, tintB, glow, clear, bar, edgeTop, edgeLow, sheenTop = #FFFFFF5C; }` with `static GlassTokens fromAccent(Color fill, Color accent, {required bool light})`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/v30_theme_glass_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
          // Putih di atas bagian bawah gradien glass (yang lebih gelap) — label
          // tombol utama.
          expect(_contrast(Colors.white, _opaque(c.glass.tintB, c.bg)), greaterThanOrEqualTo(4.5));
        });
        test('glass dan ramp mengikuti aksen $name', () {
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
      expect(theme.textTheme.headlineMedium!.fontFamily, isNull);
      expect(theme.fontFamily, 'Inter');
      expect(theme.textTheme.headlineMedium!.fontSize, 28);
      expect(theme.textTheme.headlineMedium!.fontWeight, FontWeight.w800);
      expect(theme.textTheme.titleLarge!.fontSize, 17);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/v30_theme_glass_test.dart --concurrency=4`
Expected: FAIL — `warnSoft`, `glass`, `segThumb` undefined.

- [ ] **Step 3: Implement tokens**

In `theme.dart`:

```dart
/// Token permukaan kaca (spec §1). Diturunkan dari aksen di [buildGymTheme].
@immutable
class GlassTokens {
  const GlassTokens({
    required this.tintA,
    required this.tintB,
    required this.glow,
    required this.clear,
    required this.bar,
    required this.edgeTop,
    required this.edgeLow,
  });

  final Color tintA;
  final Color tintB;
  final Color glow;
  final Color clear;
  final Color bar;
  final Color edgeTop;
  final Color edgeLow;

  static const sheenTop = Color(0x5CFFFFFF);

  static const lightBase = GlassTokens(
    tintA: Color(0xF27A6AF2), tintB: Color(0xEB5546D6), glow: Color(0x4D5546D6),
    clear: Color(0xCCECECF3), bar: Color(0xBFFFFFFF), edgeTop: Color(0xE6FFFFFF), edgeLow: Color(0x33FFFFFF),
  );
  static const darkBase = GlassTokens(
    tintA: Color(0xE6A396FF), tintB: Color(0xD96C5CEB), glow: Color(0x596C5CEB),
    clear: Color(0x1AFFFFFF), bar: Color(0xBF1E1E24), edgeTop: Color(0x59FFFFFF), edgeLow: Color(0x0DFFFFFF),
  );

  /// Gradien dari aksen pilihan: atas sedikit lebih terang dari [fill],
  /// bawah = [fill]. Aksen violet bawaan memakai nilai Pen apa adanya.
  static GlassTokens fromAccent(Color fill, Color accent, {required bool light}) {
    final base = light ? lightBase : darkBase;
    if (fill.toARGB32() == (light ? 0xFF5546D6 : 0xFF6C5CEB)) return base;
    final top = light
        ? HSLColor.fromColor(fill).withLightness((HSLColor.fromColor(fill).lightness + 0.08).clamp(0, 1)).toColor()
        : accent;
    return GlassTokens(
      tintA: top.withValues(alpha: light ? 0.95 : 0.90),
      tintB: fill.withValues(alpha: light ? 0.92 : 0.85),
      glow: fill.withValues(alpha: light ? 0.30 : 0.35),
      clear: base.clear, bar: base.bar, edgeTop: base.edgeTop, edgeLow: base.edgeLow,
    );
  }

  GlassTokens lerp(GlassTokens o, double t) => GlassTokens(
        tintA: Color.lerp(tintA, o.tintA, t)!, tintB: Color.lerp(tintB, o.tintB, t)!, glow: Color.lerp(glow, o.glow, t)!,
        clear: Color.lerp(clear, o.clear, t)!, bar: Color.lerp(bar, o.bar, t)!,
        edgeTop: Color.lerp(edgeTop, o.edgeTop, t)!, edgeLow: Color.lerp(edgeLow, o.edgeLow, t)!,
      );
}
```

Replace `GymColors.dark`/`light` values with spec §1 (bg, bgNested, surface, surface2, border, text, text2, text3, accent, accentFill `#5546D6`/`#6C5CEB`, accentSoft `#EEEBFD`/`#2A2546`, doneBg `#E8F7EE`/`#15291C`, doneInk `#15804A`/`#4ADE80`, warn `#A8560A`/`#FFAD5C`, warnSoft `#FFF1E3`/`#3A2A17`, warm `#FF8A3D`, danger `#D93A40`/`#FF6B6B`, selected = accentSoft, chartIdle, silhouette `#E1E1E8`/`#2B2B32`, ringTrack `#EFEFF3`/`#2A2A30`, ringA `#FFB020`, ringB `#2FCB7E`, ringC `#7C6CFF`, segThumb `#FFFFFF`/`#3B3B44`, washA/washB, `cardShadow = BoxShadow(color: Color(0x0F14142B), offset: Offset(0, 4), blurRadius: 18)`, `glass: GlassTokens.lightBase/darkBase`). Add fields to constructor, `copyWith`, `lerp` (glass via `glass.lerp`). Remove `block()`; `tint()` alphas → 0.12 light / 0.22 dark.

`GymHues`: add `pinkSoft, cyanSoft, orangeSoft` (spec table) and
```dart
Color soft(Color ink, GymColors c) => ink == pink ? pinkSoft : ink == cyan ? cyanSoft : ink == orange ? orangeSoft : ink == violet ? c.accentSoft : c.tint(ink);
```
Light ink: violet `#5B4BD9`, pink `#C42F7D`, cyan `#0F7F9A`, orange `#B85C08`, lime `#4D7C0F`, green `#15803D`; dark: `#A396FF`, `#FF7FC0`, `#5ED3EE`, `#FFAD5C`, `#D9FF5C`, `#34D399`.

In `buildGymTheme`: `fill = light ? _fillFor(lightAccent(pick)) : _fillFor(pick)` with default pairs updated (`0xFF8F7FFF → 0xFF5546D6` light / `0xFF6C5CEB` dark), `shownAccent` light default `#5B4BD6`; then
```dart
final heat0 = Color.alphaBlend(shownAccent.withValues(alpha: light ? 0.25 : 0.18), base.surface);
final c = base.copyWith(
  accent: shownAccent, accentFill: fill, accentSoft: light ? ... (default #EEEBFD when pick is violet, else alphaBlend(shownAccent@0.12, surface)) ...,
  selected: accentSoft, chartIdle: shownAccent.withValues(alpha: light ? 0.16 : 0.20),
  sparkTop: shownAccent.withValues(alpha: light ? 0.28 : 0.33), sparkBottom: shownAccent.withValues(alpha: 0),
  heatRamp: _ramp(heat0, shownAccent),
  activityRamp: [base.surface2, ramp[1], ramp[2], ramp[3], shownAccent],
  glass: GlassTokens.fromAccent(fill, shownAccent, light: light),
  hues: base.hues.copyWith(violet: shownAccent),   // add copyWith to GymHues
);
```
TextTheme (Inter only): displaySmall 30/800 h1.05 ls −0.6; headlineMedium 28/800 ls −0.6; headlineSmall 22/800 ls −0.3; titleLarge 17/700; titleMedium 15/700; bodyLarge 14/500; bodyMedium 13/400 text2; labelSmall 11/700 ls 0.6 text2. Remove `fontFamily: 'Manrope'` everywhere; `GymRadius` add `tile = 18`, `chip = 16`, `button = 26`, `segment = 12`, `segTrack = 16`, `nav = 33`. Chip theme: background surface, side `BorderSide(color: c.border)`, selected `accentFill`. Switch theme: selected track `c.doneInk`, off track `surface2`, thumb white. Remove Manrope from `pubspec.yaml` and delete the three TTFs.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/v30_theme_glass_test.dart --concurrency=4` → PASS. Then `flutter analyze` → fix every `block(` caller later tasks will replace; for now change `bodyweight_card.dart` and `dashboard_screen.dart` `c.block(x)` → `c.hues.soft(x, c)` so analyze is clean.

- [ ] **Step 5: Commit**

```bash
git checkout -b v3-bevel-glass
git add -A app/lib/core/theme.dart app/pubspec.yaml app/assets/fonts app/test/v30_theme_glass_test.dart app/lib/features/stats/bodyweight_card.dart app/lib/features/stats/dashboard_screen.dart
git commit -m "v3: token warna, kaca, dan tipografi Inter dari mockup Pen"
```

### Task 2: `GlassSurface` and `GlassIconButton`

**Files:**
- Create: `app/lib/core/glass.dart`
- Test: `app/test/v30_theme_glass_test.dart` (append group)

**Interfaces:**
- `enum GlassTone { tinted, clear, bar }`
- `class GlassSurface extends StatelessWidget { const GlassSurface({required this.child, this.tone = GlassTone.clear, this.radius = GymRadius.button, this.blur = false, this.padding, this.shadow = true, this.width, this.height, this.alignment}); }`
- `class GlassIconButton extends StatelessWidget { const GlassIconButton({required this.icon, required this.onPressed, this.size = 38, this.iconSize = 18, this.tinted = false, this.tooltip, this.color}); }` — wraps a 44 dp hit target.
- `Color glassInk(BuildContext context, GlassTone tone)` → white for tinted, `c.text` otherwise.

- [ ] **Step 1: Write the failing test** (append to v30 test file)

```dart
  group('GlassSurface', () {
    testWidgets('tinted memakai gradien aksen dan teks putih; clear memakai warna clear', (tester) async {
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
      final tinted = decorated.firstWhere((d) => (d.decoration as BoxDecoration).gradient != null);
      final g = (tinted.decoration as BoxDecoration).gradient as LinearGradient;
      expect(g.colors.first, GlassTokens.darkBase.tintA);
      expect(find.byType(BackdropFilter), findsOneWidget, reason: 'blur hanya kalau diminta');
      final ctx = tester.element(find.byType(Scaffold));
      expect(glassInk(ctx, GlassTone.tinted), Colors.white);
      expect(glassInk(ctx, GlassTone.clear), GymColors.dark.text);
    });

    testWidgets('GlassIconButton: target sentuh 44 dan tooltip', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: buildGymTheme(),
        home: Scaffold(body: Center(child: GlassIconButton(icon: Icons.add, tooltip: 'Tambah', onPressed: () => taps++))),
      ));
      expect(tester.getSize(find.byType(GlassIconButton)), const Size(44, 44));
      await tester.tap(find.byTooltip('Tambah'));
      expect(taps, 1);
    });
  });
```

- [ ] **Step 2: Run test → FAIL** (`GlassSurface` undefined).

- [ ] **Step 3: Implement `glass.dart`**

```dart
/// Permukaan kaca (spec §1): isian, kilau atas, tepi gradien 1 px, bayangan.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

enum GlassTone { tinted, clear, bar }

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
  /// bergulir (tab bar, pil istirahat, header sesi). Mahal: satu saveLayer.
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
        foregroundPainter: _GlassEdgePainter(radius: radius, edgeTop: g.edgeTop, edgeLow: g.edgeLow,
            highlight: tone == GlassTone.tinted ? const Color(0x8CFFFFFF) : const Color(0xB3FFFFFF)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: border,
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [GlassTokens.sheenTop, Color(0x00FFFFFF)], stops: [0, 0.5]),
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
    if (blur) {
      body = ClipRRect(borderRadius: border, child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: body));
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
/// plus garis sorot putih tipis di tepi atas.
class _GlassEdgePainter extends CustomPainter {
  _GlassEdgePainter({required this.radius, required this.edgeTop, required this.edgeLow, required this.highlight});
  final double radius;
  final Color edgeTop, edgeLow, highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius - 0.5));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [edgeTop, edgeLow, edgeTop], stops: const [0, 0.55, 1]).createShader(rect),
    );
    final inset = radius.clamp(0, size.width / 2).toDouble();
    canvas.drawLine(Offset(inset, 1.5), Offset(size.width - inset, 1.5),
        Paint()..color = highlight..strokeWidth = 1..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) =>
      old.radius != radius || old.edgeTop != edgeTop || old.edgeLow != edgeLow || old.highlight != highlight;
}

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
  final bool tinted;
  final String? tooltip;
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
                onTap: onPressed == null ? null : () { GymHaptics.tap(); onPressed!(); },
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
```

- [ ] **Step 4: Run tests → PASS.** `flutter analyze` clean.

- [ ] **Step 5: Commit** `git add app/lib/core/glass.dart app/test/v30_theme_glass_test.dart && git commit -m "v3: GlassSurface dan GlassIconButton"`

### Task 3: Shared widgets restyle + sentence-case labels

**Files:**
- Modify: `app/lib/core/widgets.dart` (GymButton, GymCard, SegmentedTabs, FilterChips, SettingsTile/Group, Pill, NoteBanner, ScreenHeader, SquareIconButton, SectionTitle, AvatarCircle, IconDisc; add `HueTile`, `TagPill`, `Odometer`, `RingGauge`; remove `StatBlock`)
- Modify: `app/lib/core/strings.dart`, `strings_home.dart`, `strings_history.dart`, `strings_session.dart`, `strings_stats.dart` (uppercase button labels → sentence case)
- Modify tests that find uppercase labels (list below)
- Test: `app/test/v30_widgets_test.dart` (create)

**Interfaces:**
- `GymButton` API unchanged; renders `GlassSurface`. `GymButtonTone.danger` → `GlassSurface(tone: clear)` with danger overlay: `DecoratedBox(color: c.danger.withValues(alpha: .12))`, label danger.
- `HueTile({required IconData icon, required Color hue, double size = 44, double radius = 14, double? iconSize})`
- `TagPill(String text)`; `Pill` unchanged API, new look (r8, pad 3/7, 10.5/700).
- `Odometer({required double value, required String unit})` — digits of `value.round()`.
- `RingGauge({required double fraction, required Color color, required String value, required String label, Duration delay})`.
- `SectionTitle(title, {action, onAction})` action color accent.
- `SettingsTile` adds nothing; drops the disc.

Label table (EN → EN new | ID → ID new): signIn `Sign in|Masuk`; signUp `Create account|Buat akun`; buildMyOwn `Build my own|Susun sendiri`; cont `Continue|Lanjut`; save `Save|Simpan`; add `Add|Tambah`; delete `Delete|Hapus`; done `Done|Selesai`; dueToday `Today|Hari ini` (TagPill uppercases itself); startSession `Start session|Mulai sesi`; upNext `Up next|Berikutnya`; newRoutine `New routine|Rutinitas baru`; addExercise `Add exercise|Tambah gerakan`; deleteRoutine `Delete routine|Hapus rutinitas`; finish `Finish|Selesai`; start `Start|Mulai`; addSet `Add set|Tambah set`; skipRest `Skip rest|Lewati istirahat`; logOut `Log out|Keluar`; next `Next|Berikutnya`; cancelUpper `Cancel|Batal`; addDay `Add day|Tambah hari`; dueTomorrow `Tomorrow|Besok`; choosePlan `Choose program|Pilih program`; replace `Replace|Ganti`; keepTraining `Keep training|Lanjut latihan`; discard `Discard|Buang`; finishAndSave `Finish & save|Selesai & simpan`; customTag `Custom|Sendiri`; supersetBadge unchanged; resume `Resume|Lanjutkan`; edit `Edit|Edit`; importAction `Import|Impor`; sendLink `Send link|Kirim link`; strings_home viewHistory `View history|Lihat riwayat`; strings_history: `useLayoutForRoutine` `Use this layout for a routine|Pakai susunan ini untuk rutinitas`, `resumeSession` `Resume session|Lanjutkan sesi`, `go` `Go|Mulai`, `backToSessionUpper` `Back to session|Kembali ke sesi`, `saveToRoutine` `Save to routine|Simpan ke rutinitas`, `revertUpper` `Revert|Batalkan`, `changeProgram` `Change program|Ganti program`, `openDashboard` `Open dashboard|Buka dashboard`, `logBodyweight` `Log bodyweight|Catat berat badan`, `connect` `Connect|Sambungkan`. (Grep each file for remaining `_('[A-Z ]{3,}'` and convert; keep `SET/PREV/KG/REPS/SEC/RIR`, `UNDO/URUNGKAN`.)

Tests to update (sed, exact strings): `'GO'→'Go'`, `'DELETE'→'Delete'`, `'SAVE'→'Save'`, `'FINISH & SAVE'→'Finish & save'`, `'FINISH'→'Finish'`, `'RESUME SESSION'→'Resume session'`, `'RESUME'→'Resume'`, `'ADD EXERCISE'→'Add exercise'`, `'CONTINUE'→'Continue'`, `'BUILD MY OWN'→'Build my own'`, `'VIEW HISTORY'→'View history'`, `'SIGN IN'→'Sign in'`, `'BACK TO SESSION'→'Back to session'`, `'SAVE TO ROUTINE'→'Save to routine'`, `'ADD DAY'→'Add day'`, `'USE THIS LAYOUT FOR A ROUTINE'→'Use this layout for a routine'`, `'EDIT'→'Edit'`, `'UP NEXT'→'Up next'`, `byTooltip('SKIP REST')→('Skip rest')`, `byTooltip('LEWATI ISTIRAHAT')→('Lewati istirahat')`, `'Connect'` stays. Keep `'UNDO'`, `'Cancel'`.

- [ ] **Step 1: Write the failing widget test**

```dart
// app/test/v30_widgets_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/glass.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';

Widget _app(Widget child, {Brightness b = Brightness.dark}) => MaterialApp(
      theme: buildGymTheme(brightness: b),
      home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
    );

void main() {
  testWidgets('GymButton primary = kaca tinted dengan label putih kalimat biasa', (tester) async {
    await tester.pumpWidget(_app(GymButton(label: 'Mulai sesi', onPressed: () {})));
    final glass = tester.widget<GlassSurface>(find.descendant(of: find.byType(GymButton), matching: find.byType(GlassSurface)));
    expect(glass.tone, GlassTone.tinted);
    expect(tester.widget<Text>(find.text('Mulai sesi')).style!.color, Colors.white);
    expect(tester.widget<Text>(find.text('Mulai sesi')).style!.fontSize, 15);
  });

  testWidgets('GymButton neutral = kaca clear; danger berteks danger', (tester) async {
    await tester.pumpWidget(_app(Column(children: [
      GymButton(label: 'Lewati', tone: GymButtonTone.neutral, onPressed: () {}),
      GymButton(label: 'Hapus', tone: GymButtonTone.danger, onPressed: () {}),
    ])));
    final glasses = tester.widgetList<GlassSurface>(find.byType(GlassSurface)).toList();
    expect(glasses.every((g) => g.tone == GlassTone.clear), isTrue);
    expect(tester.widget<Text>(find.text('Hapus')).style!.color, GymColors.dark.danger);
  });

  testWidgets('semua label tombol di Strings bukan KAPITAL', (tester) async {
    for (final lang in AppLanguage.values) {
      final t = Strings(lang);
      for (final s in [t.save, t.delete, t.done, t.startSession, t.finish, t.addExercise, t.addSet, t.skipRest, t.logOut, t.choosePlan, t.finishAndSave, t.signIn, t.cont]) {
        expect(s, isNot(equals(s.toUpperCase())), reason: '$s masih kapital');
      }
    }
  });

  testWidgets('SegmentedTabs: thumb segThumb bergeser ke indeks', (tester) async {
    var idx = 0;
    await tester.pumpWidget(_app(StatefulBuilder(builder: (context, set) => SegmentedTabs(
      labels: const ['A', 'B', 'C'], index: idx, onChanged: (i) => set(() => idx = i)))));
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(idx, 2);
    final thumb = tester.widget<DecoratedBox>(find.byKey(const ValueKey('seg-thumb')));
    expect((thumb.decoration as BoxDecoration).color, GymColors.dark.segThumb);
    expect(tester.getSize(find.byType(SegmentedTabs)).height, 44);
  });

  testWidgets('FilterChips: terpilih kaca tinted, lainnya bergaris hairline', (tester) async {
    await tester.pumpWidget(_app(FilterChips(labels: const ['Semua', 'Push'], index: 0, onChanged: (_) {})));
    expect(find.descendant(of: find.byType(FilterChips), matching: find.byType(GlassSurface)), findsOneWidget);
    expect(tester.getSize(find.byType(FilterChips)).height, 32);
  });

  testWidgets('HueTile, TagPill, Odometer, RingGauge tergambar', (tester) async {
    await tester.pumpWidget(_app(Column(children: [
      HueTile(icon: Icons.fitness_center, hue: GymColors.dark.hues.pink),
      const TagPill('Hari ini'),
      const Odometer(value: 5430, unit: 'kg'),
      RingGauge(fraction: 0.66, color: GymColors.dark.ringA, value: '2/3', label: 'Sesi minggu ini'),
    ]), b: Brightness.light));
    await tester.pumpAndSettle();
    expect(find.text('HARI INI'), findsOneWidget);
    for (final d in ['5', '4', '3', '0']) {
      expect(find.text(d), findsOneWidget);
    }
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(tester.getSize(find.byType(HueTile)), const Size(44, 44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsTile tanpa cakram: ikon 18 text2, nilai dan chevron', (tester) async {
    await tester.pumpWidget(_app(SettingsGroup(children: [
      SettingsTile(icon: Icons.scale, label: 'Satuan berat', value: 'kg', onTap: () {}),
    ])));
    expect(find.byType(IconDisc), findsNothing);
    final icon = tester.widget<Icon>(find.byIcon(Icons.scale));
    expect(icon.size, 18);
    expect(icon.color, GymColors.dark.text2);
  });
}
```

- [ ] **Step 2: Run → FAIL** (HueTile etc. undefined; labels uppercase).

- [ ] **Step 3: Implement** in `widgets.dart`:

`GymButton.build`:
```dart
final c = context.gym;
final tone = switch (this.tone) { GymButtonTone.primary => GlassTone.tinted, _ => GlassTone.clear };
final fg = switch (this.tone) { GymButtonTone.primary => Colors.white, GymButtonTone.danger => c.danger, _ => c.text };
final big = height >= 48;
final text = Text(label, maxLines: 1, style: TextStyle(fontSize: big ? 15 : 13.5, fontWeight: big ? FontWeight.w700 : FontWeight.w600, color: fg));
return PressScale(
  enabled: onPressed != null,
  child: AnimatedOpacity(
    duration: GymMotion.of(context, GymMotion.quick),
    opacity: onPressed == null ? 0.45 : 1,
    child: SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: GlassSurface(
        tone: tone,
        radius: height / 2,
        child: Stack(fit: StackFit.passthrough, children: [
          if (this.tone == GymButtonTone.danger)
            DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(height / 2), color: c.danger.withValues(alpha: 0.12))),
          Material(type: MaterialType.transparency, child: InkWell(
            onTap: onPressed == null ? null : () { if (this.tone == GymButtonTone.primary) GymHaptics.confirm(); onPressed!(); },
            borderRadius: BorderRadius.circular(height / 2),
            child: Padding(padding: EdgeInsets.symmetric(horizontal: expand ? 12 : 18), child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: big ? 17 : 15, color: fg), const SizedBox(width: 8)],
              if (expand) Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: text)) else text,
            ])),
          )),
        ]),
      ),
    ),
  ),
);
```
`GymCard`: `boxShadow: [c.cardShadow]` when `color == null`; radius default `GymRadius.card` (22). `SegmentedTabs`: height 44, padding 4, track `surface2` r16, thumb `DecoratedBox(key: ValueKey('seg-thumb'), decoration: BoxDecoration(color: c.segThumb, borderRadius: r12, boxShadow: [BoxShadow(color: Color(0x1A14142B), offset: Offset(0, 2), blurRadius: 8)]))`, labels 13 w700 `text` / w600 `text2`. `FilterChips`: height 32; selected → `GlassSurface(tone: tinted, radius: 16, padding: EdgeInsets.symmetric(horizontal: 14))` white 13/600; else `DecoratedBox(color: surface, border: Border.all(color: border), r16)`. `IconDisc`: bg `c.hues.soft(hue, c)`, icon `hue` (keeps API). `SettingsTile`: `Icon(icon, size: 18, color: tone ?? c.text2)`, gap 12, padding `EdgeInsets.symmetric(horizontal: 16, vertical: 13)`, value 13.5 text2, chevron 16 text3. `SettingsGroup`: r20, `Divider(indent: 46)`. `Pill`: pad `EdgeInsets.symmetric(horizontal: 7, vertical: 3)`, r8, 10.5/700. `TagPill`: `Container(padding 9/5, accentSoft r10, Text(text.toUpperCase(), 10/700 accent, letterSpacing 0.6))`. `NoteBanner`: `(bg, ink) = tone == c.warn ? (c.warnSoft, c.warn) : tone == c.accent ? (c.accentSoft, c.accent) : (c.surface2, c.text2)`, r14, pad 12/10, text 12.5/600 ink. `ScreenHeader`: title `headlineMedium`. `SquareIconButton` → delegates to `GlassIconButton(icon, onPressed, tooltip, color: tone)`. `SectionTitle`: title titleLarge; action `TextStyle(13, w600, c.accent)`. `AvatarCircle`: bg accentSoft, text accent w700. Add:

```dart
class HueTile extends StatelessWidget {
  const HueTile({super.key, required this.icon, required this.hue, this.size = 44, this.radius = 14, this.iconSize});
  final IconData icon; final Color hue; final double size; final double radius; final double? iconSize;
  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(width: size, height: size, alignment: Alignment.center,
      decoration: BoxDecoration(color: c.hues.soft(hue, c), borderRadius: BorderRadius.circular(radius)),
      child: Icon(icon, size: iconSize ?? size * 0.45, color: hue));
  }
}

class Odometer extends StatelessWidget {
  const Odometer({super.key, required this.value, required this.unit});
  final double value; final String unit;
  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final digits = value.round().toString();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final (i, d) in digits.split('').indexed) ...[
        if (i > 0) const SizedBox(width: 2),
        Container(width: 18, height: 26, alignment: Alignment.center,
          decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(6)),
          child: Text(d, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text, fontFeatures: const [FontFeature.tabularFigures()]))),
      ],
      const SizedBox(width: 5),
      Text(unit, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text2)),
    ]);
  }
}

class RingGauge extends StatelessWidget {
  const RingGauge({super.key, required this.fraction, required this.color, required this.value, required this.label, this.delay = Duration.zero, this.size = 86});
  final double fraction; final Color color; final String value; final String label; final Duration delay; final double size;
  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: size, height: size, child: AnimatedValue(value: fraction.clamp(0, 1), delay: delay,
        builder: (context, v) => CustomPaint(painter: _RingPainter(fraction: v, track: c.ringTrack, ink: color),
          child: Center(child: Text(value, style: TextStyle(fontSize: value.length > 4 ? 17 : 19, fontWeight: FontWeight.w700, color: c.text, fontFeatures: const [FontFeature.tabularFigures()]))))),
      ),
      const SizedBox(height: 8),
      Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.text2)),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.track, required this.ink});
  final double fraction; final Color track, ink;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final r = size.width / 2 - stroke / 2;
    final centre = size.center(Offset.zero);
    canvas.drawCircle(centre, r, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = track);
    if (fraction > 0) {
      canvas.drawArc(Rect.fromCircle(center: centre, radius: r), -math.pi / 2, 2 * math.pi * fraction, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round..color = ink);
    }
  }
  @override
  bool shouldRepaint(_RingPainter o) => o.fraction != fraction || o.track != track || o.ink != ink;
}
```
Remove `StatBlock`; delete its test in `v22_home_test.dart` (`StatBlock menampilkan valueWidget…`). Update strings and test finders per the table.

- [ ] **Step 4: Run** `flutter test --concurrency=4` → all pass except known Home/Stats/Session screen tests that later tasks rewrite — list the failures; they must only be in `v22_home_test`, `v22_stats_test`, `v22_session_test`, `session_screen_test` (REST text). Fix anything else now. `flutter analyze` clean.

- [ ] **Step 5: Commit** `git add -A app/lib app/test && git commit -m "v3: komponen bersama bergaya kaca, label tombol kalimat biasa"`

### Task 4: Remove 3D icons

**Files:**
- Delete: `app/lib/core/art3d.dart`, `app/assets/3d/*`, `app/test/v23_art3d_test.dart`
- Modify: `app/pubspec.yaml` (drop `assets/3d/`), `app/lib/features/onboarding/onboarding_screens.dart` (`ProgramTemplate.art: Gym3d` → `icon: IconData`), `app/lib/features/home/home_screen.dart` (remove `_QuickTile` imports; full rewrite comes in Task 8 — here only make it compile: replace `Gym3dIcon(art…)` with `HueTile(icon: GymIcons.dumbbell, hue: c.accent)` temporarily), `app/test/decode_size_test.dart` (`seen >= 1`), `app/test/assets_iconscout_test.dart` (drop 3d assertions if any)
- Test: `app/test/v30_widgets_test.dart` (append)

- [ ] **Step 1: Test**: append
```dart
  test('tidak ada lagi ikon 3D di aplikasi', () {
    expect(File('lib/core/art3d.dart').existsSync(), isFalse);
    expect(Directory('assets/3d').existsSync(), isFalse);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('assets/3d'), isFalse);
    expect(pubspec.contains('Manrope'), isFalse);
  });
```
(add `import 'dart:io';`.)
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement.** Template icons: ppl → `GymIcons.dumbbell`, bro split → `GymIcons.barbell`, upper/lower → `GymIcons.calendar`, heavy duty → `GymIcons.kettlebell`, full body → `GymIcons.ball`, custom → `GymIcons.sliders`; `_ProgramCard` shows `HueTile(icon: template.icon, hue: c.hues.at(index), size: 46, radius: 14)`. Check `grep -rn "Gym3d\|art3d" app/lib app/test` returns nothing.
- [ ] **Step 4: Run** `flutter test --concurrency=4` (same allowed failures as Task 3) + `flutter analyze`.
- [ ] **Step 5: Commit** `git add -A app && git commit -m "v3: ikon 3D dihapus, kartu template memakai ikon garis"`

### Task 5: Charts restyle + right glute shape

**Files:**
- Modify: `app/lib/core/charts.dart` (Sparkline, BarSeries, RadarChart, ActivityHeatmap)
- Modify: `app/lib/core/body_map_data.dart` (append mirrored shape)
- Test: `app/test/v30_charts_test.dart` (create); `app/test/muscle_volume_test.dart` unchanged (length equality still holds)

**Interfaces:**
- `Sparkline({values, width = 94, height = 36, color, fill = true, strokeWidth = 2.2, endDot = true})`
- `BarSeries` adds `double? average` and `String Function(double)? averageFormat`; bubble shown for `selected ?? last`.
- `smoothPath(List<Offset> pts)` top-level helper (Catmull-Rom → cubic), exported for tests.

- [ ] **Step 1: Test**
```dart
// app/test/v30_charts_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/body_map_data.dart';
import 'package:gymapps/core/charts.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/domain/muscle_volume.dart';

void main() {
  test('smoothPath melewati setiap titik dan mulus (kubik)', () {
    final pts = [const Offset(0, 30), const Offset(20, 10), const Offset(40, 20), const Offset(60, 5)];
    final path = smoothPath(pts);
    final metrics = path.computeMetrics().toList();
    expect(metrics, hasLength(1));
    expect(path.getBounds().left, 0);
    expect(path.getBounds().right, 60);
    expect(path.contains(const Offset(20, 10)) || path.getBounds().contains(const Offset(20, 10)), isTrue);
  });

  testWidgets('BarSeries: gelembung pada batang terakhir tanpa ketukan, garis rata-rata', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildGymTheme(), home: Scaffold(body: SizedBox(width: 318, child: BarSeries(
      values: const [38, 44, 41, 47, 52, 30, 46, 51], leftLabel: '-7 mgg', midLabel: '-4 mgg', rightLabel: 'sekarang',
      valueFormat: (v) => '${v.round()} set', average: 44, averageFormat: (v) => 'rata-rata ${v.round()} set')))));
    await tester.pumpAndSettle();
    expect(find.text('51 set'), findsOneWidget);
    expect(find.text('rata-rata 44 set'), findsOneWidget);
    expect(tester.widget<Text>(find.text('sekarang')).style!.color, GymColors.dark.accent);
  });

  testWidgets('Sparkline 94×36 dengan titik akhir', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildGymTheme(), home: const Scaffold(body: Center(child: Sparkline(values: [92, 94, 97, 97, 103, 109])))));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Sparkline)), const Size(94, 36));
    expect(tester.takeException(), isNull);
  });

  test('otot bokong ada di dua sisi tampak belakang', () {
    final glutes = [for (var i = 0; i < bodyHeatmapGroups.length; i++) if (bodyHeatmapGroups[i] == MuscleGroup.glutes.index) i];
    expect(glutes.length, greaterThanOrEqualTo(2));
    expect(bodyHeatmapPaths.length, bodyHeatmapGroups.length);
    expect(bodyHeatmapLevels.length, bodyHeatmapPaths.length);
    // Cermin: x pusat kedua bentuk simetris terhadap sumbu figur belakang (222,2/320).
    double cx(List<double> enc) { var s = 0.0, n = 0; var k = 0; while (k < enc.length) { final op = enc[k].toInt(); final m = op == 0 || op == 1 ? 1 : op == 2 ? 3 : 0; for (var j = 0; j < m; j++) { s += enc[k + 1 + j * 2]; n++; } k += 1 + m * 2; } return s / n; }
    final a = cx(bodyHeatmapPaths[glutes[glutes.length - 2]]), b = cx(bodyHeatmapPaths[glutes.last]);
    expect((a + b) / 2, closeTo(222.2 / 320, 0.01));
  });
}
```
- [ ] **Step 2: Run → FAIL** (`smoothPath`, `average` undefined; one glute).
- [ ] **Step 3: Implement.**
  - `smoothPath`: for i in 0..n-2: p0=pts[max(i-1,0)], p1=pts[i], p2=pts[i+1], p3=pts[min(i+2,n-1)]; c1 = p1 + (p2 − p0)/6; c2 = p2 − (p3 − p1)/6; `cubicTo`.
  - `_SparkPainter`: y mapping with pad 4; `line = smoothPath(points)`; area = extracted part + lineTo(endX, h) + lineTo(0, h) close, filled with `LinearGradient(sparkTop → sparkBottom)` shader; stroke 2.2 accent; when `progress >= 1 && endDot`: halo circle r7 `sparkTop`, dot r4 accent with stroke 2 `surface`.
  - `BarSeries`: `height` default 104; top 22 reserved for the bubble (total 126 + labels); grid lines at 0/50/100 % `c.border` 1 px; bar `ClipRRect(BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(3)))`; highlighted bar `DecoratedBox(gradient tintA→tintB)`, idle `chartIdle`; bubble `_Bubble` → accent bg r8, white 10.5/800, no label line unless `labels` provided (then label 10/600 white70); shown for `picked ?? n-1`; `average` → `Positioned` line at its fraction (`c.text3`, 1 px) + pill at left top of the line (`surface2` r8, text2 10.5/600); axis labels 10.5: left/mid `text2` w500, right `accent` w700. Keep existing `_tap`, selection shifting, and `animate` logic.
  - `RadarChart`: grid `c.border`; previous polygon stroke `text3` 1.5 + fill `text3 @ .10`; current fill `sparkTop`, stroke accent 2; vertices r4 accent stroke `surface` 2; labels 12.5/600 text2 at 1.24 r.
  - `ActivityHeatmap`: `GymRadius.cell = 2.5`.
  - `body_map_data.dart`: generate the mirrored entry with a one-off Dart script (`dart run` a scratch file printing `[op, 1.38875 - x, y, …]` for index 98 with control points also mirrored) and append to `bodyHeatmapLevels` (`3`), `bodyHeatmapPaths`, `bodyHeatmapGroups` (`10`). Update the header comment: "indeks 99 = cermin indeks 98 (bokong kanan)".
- [ ] **Step 4: Run** `flutter test test/v30_charts_test.dart test/muscle_volume_test.dart test/stats_test.dart --concurrency=4` → PASS.
- [ ] **Step 5: Commit** `git add -A app/lib/core/charts.dart app/lib/core/body_map_data.dart app/test/v30_charts_test.dart && git commit -m "v3: sparkline halus, batang membulat dengan rata-rata, radar baru, bokong kanan"`

### Task 6: Strings v3

**Files:**
- Create: `app/lib/core/strings_v3.dart` (`extension V3Strings on Strings`)
- Test: `app/test/v30_widgets_test.dart` (append)

**Interfaces (all `String`):** `homeTab`, `historyTab`, `programTab`, `statsTab`, `startTab` ("Mulai"/"Start"); `pickOther` ("Pilih lain"/"Pick another"); `strengthProgress` ("Progres kekuatan"/"Strength progress"); `seeAll` ("Semua"/"All"); `ringSessions` ("Sesi minggu ini"/"Sessions this week"); `ringSets` ("Set kerja"/"Working sets"); `ringVolume` ("Volume vs lalu"/"Volume vs last"); `syncedPill`, `syncNotYet` ("Belum sinkron"/"Not synced"), `syncNoServerPill` ("Tanpa server"/"No server"), `minutesAgo(int)` ("2 menit lalu"/"2 min ago"), `justNow`, `hoursAgo(int)`, `daysAgoShort(int)` ("5 hari lalu"/"5 days ago"); `rotationCount(int)` ("Rotasi · 3 rutinitas"), `weekdayCount(String days)` ("Hari tetap · Sen, Rab, Jum"); `pickProgramPill` ("Pilih program"); `moreExercises(int)` ("+2 lagi"/"+2 more"); `startSheetTitle` ("Mulai sesi"), `startSheetNextRotation(String)` ("Push adalah sesi berikutnya di rotasi"/"Push is next in the rotation"), `startSheetNextToday(String)`, `startSheetNoProgram`; `freestyleRow` ("Sesi bebas"/"Freestyle session"), `freestyleRowSub` ("Tambah gerakan sambil jalan"/"Add exercises as you go"); `programRoutinesLabel` ("RUTINITAS PROGRAM"/"PROGRAM ROUTINES"), `otherRoutinesLabel`; `logPastRow` ("Catat sesi yang sudah lewat"/"Log a past session"); `exerciseHistoryBtn` ("Riwayat gerakan"/"Exercise history"), `supersetBtn` ("Superset"), `endSupersetBtn` ("Akhiri superset"/"End superset"); `restWord` ("Istirahat"/"Rest"); `totalReps` ("Total rep"/"Total reps"), `targetsUp` ("Target naik"/"Targets up"), `newRecordsTitle` ("Rekor baru"/"New records"), `heaviestSet` ("beban terberat"/"heaviest set"), `holdTag` ("tahan"/"hold"), `newTag` ("baru"/"new"), `deloadTag` ("deload"), `undoLink` ("Batalkan"/"Undo"), `saveLink` ("Simpan"/"Save"), `saveAgainLink` ("Simpan lagi"/"Save again"), `layoutNotSavedV3` reuse existing `layoutNotSaved`; `sessionsThisYearV3(int)` ("23 sesi tahun ini"/"23 sessions this year"); `minutesShort(int)` ("48 mnt"/"48 min"); `libraryButton` ("Library gerakan"/"Exercise library"); `activeProgramKicker` ("PROGRAM AKTIF"/"ACTIVE PROGRAM"); `skipSessionBtn` ("Lewati sesi"/"Skip session"); `reorder` ("Urutkan"/"Reorder"); `addRoutineCard` ("Tambah rutinitas"/"Add routine"); `programRules` ("Aturan program"/"Program rules"); `modeLabel` ("Mode"); `minRestBetween` ("Istirahat minimum antar sesi"/"Minimum rest between sessions"); `daysValue(int)` ("0 hari"/"0 days"); `routineMetaComma(int ex, int sets)` ("4 gerakan, 12 set"); `profileNav` ("Profil"/"Profile"); `groupTraining` ("LATIHAN"/"TRAINING"), `groupAppearance` ("TAMPILAN"/"APPEARANCE"), `groupDataAccount` ("DATA & AKUN"/"DATA & ACCOUNT"); `weightUnitRow` ("Satuan berat"/"Weight unit"); `logRirRow` ("Catat RIR"/"Log RIR"); `restPushRow` ("Notifikasi istirahat"/"Rest notifications"); `weekStartsRow` ("Minggu dimulai"/"Week starts"); `forceSyncRow` ("Paksa sinkron"/"Force sync"); `aboutRow` ("Tentang aplikasi"/"About the app"); `logOutRow` ("Keluar"/"Log out"); `strengthNoData` ("Belum ada data kekuatan"/"No strength data yet"); `oneRmShort(String v)` ("1RM 109 kg"); `setsPerWeekSub(int w)` ("Set kerja per minggu, 8 minggu"/"Working sets per week, 8 weeks"); `avgSets(int)` ("rata-rata 44 set"/"avg 44 sets"); `pctOverWeeks(String pct, int w)` ("+18,5 % · 12 mgg"/"+18.5% · 12 wk"); `bwDelta(String d, int days)` ("−0,6 kg / 30 hari"/"−0.6 kg / 30 days"); `logShort` ("Catat"/"Log"); insight strings from spec §8: `insightNoProgram`, `insightNoProgramBody`, `insightRecovery`, `insightRecoveryBody(String routine, String day, String since)`, `insightRestDay`, `insightRestDayBody(String day, String routine)`, `insightUp(String routine, String n)`, `insightUpBody(String since, String names)`, `insightHold(String routine)`, `insightHoldBody(String since)`, `insightDeload(String routine)`, `insightDeloadBody(String name)`, `neverTrained` ("Belum pernah dilatih."/"Never trained yet."), `lastTrainedSentence(int days)` ("Terakhir dilatih 5 hari lalu."/"Last trained 5 days ago."), `numberWord(int)` (1–9 → kata; else digits), `andJoin(List<String>)` ("A dan B" / "A and B"; 3+: "A, B, dan C").

- [ ] **Step 1: Test** append: for both languages, every getter above is non-empty and the two languages differ for `pickOther`, `groupTraining`, `ringSessions`; `numberWord(2)` → 'dua'/'two'; `andJoin(['A','B','C'])` → 'A, B, dan C' / 'A, B, and C'.
- [ ] **Step 2: Run → FAIL.** **Step 3: Implement** following `strings_home.dart` pattern (`_v(en, id)`). **Step 4: PASS.** **Step 5: Commit** `v3: teks baru dua bahasa`.

---

## Phase B — shell and navigation

### Task 7: Glass tab bar, start sheet, Profile as a route

**Files:**
- Modify: `app/lib/main.dart` (HomeShell: 4 tabs + center button; `_GlassTabBar`; Profile pushed; `onOpenTab` mapping)
- Create: `app/lib/features/session/start_session_sheet.dart`
- Create: `app/lib/features/workout/routine_actions.dart` (`showRoutineActions(context, routine)` → bottom sheet with Edit · Rename · Duplicate · Set as next · Delete; moves `_NameDialog`, `_ConfirmDeleteDialog` out of `workout_screen.dart`)
- Modify: `app/lib/features/profile/profile_screen.dart` (wrap in `Scaffold` with nav header when `widget.asPage == true`)
- Test: `app/test/v30_shell_test.dart` (create)

**Interfaces:**
- `HomeShell` constructor unchanged. Tabs: `[HomeScreen, HistoryScreen, ProgramScreen, StatsScreen]`; `_tab` default 0. `HomeScreen.onOpenTab` indices: 1 history, 3 stats. `HomeScreen.onOpenProfile` pushes `ProfileScreen(asPage: true, …)`.
- `Future<void> showStartSessionSheet(BuildContext context)`.
- `ProgramScreen` placeholder until Task 9: in this task point tab 2 at the existing `WorkoutScreen` (renamed later).
- `ProfileScreen({…, this.asPage = false})`; when `asPage`, builds `Scaffold(backgroundColor: c.bg, body: SafeArea(child: ListView(…nav header…)))`; `onSignOut` wrapper pops first: `Navigator.of(context).pop(); widget.onSignOut();`.

- [ ] **Step 1: Test**
```dart
// app/test/v30_shell_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/glass.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/features/profile/profile_screen.dart';
import 'package:gymapps/features/session/start_session_sheet.dart';
import 'package:gymapps/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Widget _wrap(WorkoutStore store, {VoidCallback? onSignOut}) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.indonesian),
        child: MaterialApp(
          theme: buildGymTheme(),
          home: HomeShell(language: AppLanguage.indonesian, onLanguageChanged: (_) {}, onSignOut: onSignOut ?? () {}, email: 'hariz@gym.app'),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WorkoutStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
    store = WorkoutStore();
    await store.load('a@x.com');
    await store.applyTemplate('ppl');
  });

  testWidgets('empat tab berlabel + tombol tengah kaca; Profil bukan tab', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(store));
    await tester.pump(const Duration(seconds: 1));
    for (final label in ['Beranda', 'Riwayat', 'Program', 'Statistik']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Profil'), findsNothing);
    final center = find.byKey(const ValueKey('tab-start'));
    expect(tester.widget<GlassSurface>(find.descendant(of: center, matching: find.byType(GlassSurface))).tone, GlassTone.tinted);
    expect(tester.getSize(center), const Size(50, 50));
  });

  testWidgets('tombol + membuka lembar Mulai sesi dengan rutinitas program', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(store));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('tab-start')));
    await tester.pumpAndSettle();
    expect(find.byType(StartSessionSheet), findsOneWidget);
    expect(find.text('Sesi bebas'), findsOneWidget);
    expect(find.text('Catat sesi yang sudah lewat'), findsOneWidget);
    expect(find.descendant(of: find.byType(StartSessionSheet), matching: find.text('Push')), findsOneWidget);
    expect(find.text('Berikutnya'), findsOneWidget);
  });

  testWidgets('avatar membuka Profil sebagai halaman; Keluar menutupnya dulu', (tester) async {
    _phone(tester);
    var signedOut = 0;
    await tester.pumpWidget(_wrap(store, onSignOut: () => signedOut++));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Buka profil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Keluar'), 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(signedOut, 1);
    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('tab Riwayat dan Statistik dari Beranda memakai indeks baru', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(store));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();
    expect(find.text('Keseimbangan'), findsOneWidget);
    await tester.tap(find.text('Riwayat').first);
    await tester.pumpAndSettle();
    expect(find.text('Aktivitas'), findsOneWidget);
  });
}
```
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement.**
  - `_GlassTabBar` (in main.dart): `SafeArea(top: false, child: Padding(16, 6, 16, 14, child: GlassSurface(tone: bar, blur: true, radius: 33, height: 66, child: Row(children: [tab0, tab1, _StartButton(key: ValueKey('tab-start')), tab2, tab3]))))`; each tab `Expanded(Semantics(button, selected, label) → InkWell → Column(icon 22 (accent/text2), SizedBox(3), Text(label, 10.5, w600/w500)))`; `_StartButton` = `GlassSurface(tone: tinted, radius: 25, width: 50, height: 50, child: InkWell(onTap: () => showStartSessionSheet(context), child: Icon(GymIcons.plus, 24, white)))` wrapped in `Tooltip(t.startSheetTitle)`.
  - `HomeShell` children: `HomeScreen(email, onOpenProfile: _openProfile, onOpenTab: (i) => setState(() => _tab = i))`, `_LazyTab(HistoryScreen)`, `_LazyTab(WorkoutScreen)` (→ `ProgramScreen` in Task 9), `_LazyTab(StatsScreen)`. `_openProfile` pushes `MaterialPageRoute(builder: (_) => ProfileScreen(asPage: true, language…, onSignOut: widget.onSignOut, …))`.
  - `StartSessionSheet` (StatelessWidget rendered by `showModalBottomSheet(backgroundColor: c.bg, shape r28, isScrollControlled: true, builder: (_) => StartSessionSheet())`): per spec §7.2 using `HueTile`, `Pill`, `GymCard`-like rows (`Material` surface r18 + `cardShadow`); next routine stroke accent 1.5; ⋯ → `showRoutineActions`; rows call `Navigator.pop(sheet)` then `openRoutineSession(context, routine)` / `openFreestyleSession(context, t.freestyle)` / `openManualEntry(context)` using the **shell** context captured before the sheet (`final root = context;`).
  - `routine_actions.dart`: moves `_NameDialog`, `_ConfirmDeleteDialog` from workout_screen.dart (export as `RoutineNameDialog`, `ConfirmDeleteRoutineDialog`); `showRoutineActions` lists `SettingsTile`s in a sheet and performs: edit → push `RoutineEditorScreen` and apply result; rename → dialog + `saveRoutine`; duplicate → `duplicateRoutine(id, '${name} copy')`; set as next (rotation only, not already next) → `setNext`; delete → confirm → `deleteRoutine`.
  - ProfileScreen `asPage`: header row `GlassIconButton(arrowLeft, tooltip: t.back)` + `Text(t.profileNav, 16/700)` centered + 38 spacer; `onSignOut` → `_signOutFromPage()` pops then calls.
  - `HomeScreen`'s `AvatarCircle(tooltip: t.openProfile)` must read "Buka profil" in ID (check `t.openProfile` value; adjust string to 'Buka profil' if different).
- [ ] **Step 4: Run** `flutter test test/v30_shell_test.dart test/v22_draft_test.dart test/v25_routine_follow_test.dart --concurrency=4` → PASS (draft/v25 use HomeShell).
- [ ] **Step 5: Commit** `v3: tab bar kaca 4 tab + tombol mulai, lembar Mulai sesi, Profil jadi halaman`

---

## Phase C — screens

### Task 8: Home

**Files:**
- Create: `app/lib/features/home/home_insight.dart`
- Create: `app/lib/features/home/home_cards.dart` (`StatusPill`, `RingsCard`, `NextSessionCard`, `WeekCard`, `StrengthCard`)
- Modify: `app/lib/features/home/home_screen.dart` (header, sections; keep `_Recent`, `weekStart`, `pickOtherRoutine`, `_WeekStrip` sheet logic, `_ResumeCard`, `_NoProgramCard`, `initialsOf`)
- Delete from home_screen: `_QuickTile`, `_HeroFigure`, `_MiniStat`, `_WeekBar`, StatBlock rows
- Test: `app/test/v30_home_test.dart` (create); rewrite `app/test/v22_home_test.dart` (drop StatBlock + 'Volume 7d' tests; keep day-sheet tests with `opened == 1`)

**Interfaces:**
- `({String title, String body}) homeInsight({required Strings t, required NextSession? next, required bool weekdayMode, required List<(String name, PrescriptionKind kind)> targets, required int? daysSince})`.
- `class RingsCard extends StatelessWidget { const RingsCard({required this.sessionsDone, required this.sessionsPlanned, required this.setsDone, required this.setsPlanned, required this.volumeNow, required this.volumeBefore, required this.insight}); }`
- `class NextSessionCard` takes `next`, `program`, `onStart`, `onSkip`; rows computed with `planExercise` (same as today) and change pill from `plan.prescription.kind` + delta vs `cfg.weight`/`cfg.reps`.
- `WeekCard({history, today, program, routines, weekStartsOn, onViewHistory})` — day cell keys stay `ValueKey('home-day-$iso')`.
- `StrengthCard({history, catalog, onSeeAll})` → rows via `strengthByMovement(history, now, count: 3)` + `carried(weeklyBest(history, id, now))`.

- [ ] **Step 1: Tests**
```dart
// app/test/v30_home_test.dart (key cases)
test('insight: dua gerakan naik', () {
  final t = const Strings(AppLanguage.indonesian);
  final r = homeInsight(t: t, next: NextSession(routine: push, due: today, today: today), weekdayMode: false,
    targets: [('Dumbbell Fly', PrescriptionKind.up), ('Chest Press', PrescriptionKind.up), ('Curl', PrescriptionKind.hold)], daysSince: 5);
  expect(r.title, 'Push hari ini, dua gerakan siap naik');
  expect(r.body, 'Terakhir dilatih 5 hari lalu. Dumbbell Fly dan Chest Press naik targetnya sesi ini.');
});
test('insight: pemulihan', () { … expect(r.title, 'Hari pemulihan'); expect(r.body, contains('Push jatuh pada')); });
test('insight: tanpa program', () { … expect(r.title, 'Belum ada program'); });
testWidgets('Beranda: pil program & sinkron, tiga cincin, sesi berikutnya dengan Mulai sesi dan Lewati, minggu ini, progres kekuatan', (tester) async {
  _phone(tester); final store = await _storeWithWeek(tester);
  await tester.pumpWidget(_wrap(store, HomeScreen(onOpenTab: (i) => opened = i)));
  await tester.pumpAndSettle();
  expect(find.text('Push / Pull / Legs'), findsOneWidget);           // program pill
  expect(find.text('Sesi minggu ini'), findsOneWidget);
  expect(find.text('2/3'), findsOneWidget);                            // ring value
  expect(find.text('Sesi berikutnya'), findsOneWidget);
  expect(find.text('Pilih lain'), findsOneWidget);
  expect(find.text('Mulai sesi'), findsOneWidget);
  expect(find.text('Lewati'), findsOneWidget);
  await tester.scrollUntilVisible(find.text('Progres kekuatan'), 200, scrollable: _scrollable);
  expect(find.byType(Sparkline), findsWidgets);
  await tester.tap(find.text('Semua'));
  expect(opened, 3);
  expect(tester.takeException(), isNull);
});
testWidgets('kotak hari → sheet → Lihat riwayat membuka tab 1', …expect(opened, 1));
testWidgets('tanpa program: pil "Pilih program" dan kartu belum ada program', …);
```
(Indonesian strings; `_wrap` uses `Strings(AppLanguage.indonesian)`.)
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** per spec §7.1 and §8. Data: `sessionsDone/planned` from existing `_thisWeek`/`weekPlanned`; `setsDone` = working sets this week; `setsPlanned` = sum over the week's planned routines of `r.setCount` (rotation: `order.length` routines; weekday: routines of `program.days`), min 1; `volumeNow/Before` = `_volumeOf` sums for last 7 days vs the 7 before. Sync pill sub: `lastSyncedAt` → `t.justNow / minutesAgo / hoursAgo / daysAgoShort`. Background: `Stack([Positioned.fill(DecoratedBox(gradient: RadialGradient(center: Alignment(-0.6,-1), radius: 1.2, colors: [c.washA, transparent]))), …washB…, ListView])` — only when `HomeScreen` is inside the shell (always).
- [ ] **Step 4: Run** `flutter test test/v30_home_test.dart test/v22_home_test.dart test/v22_draft_test.dart --concurrency=4` → PASS.
- [ ] **Step 5: Commit** `v3: Beranda baru — pil status, cincin, insight, sesi berikutnya, minggu, kekuatan`

### Task 9: Program tab

**Files:**
- Create: `app/lib/features/workout/program_screen.dart` (`ProgramScreen`)
- Delete: `app/lib/features/workout/workout_screen.dart` (after moving `_OrderRow` into `program_screen.dart` as the reorder sheet)
- Modify: `app/lib/main.dart` (tab 2 → `ProgramScreen`)
- Test: `app/test/v30_program_test.dart`

**Interfaces:** `ProgramScreen()`; `double plannedSessionVolume(Routine r, List<Workout> historyIn, WeightUnit unit, ProgressionPolicy? policy)` (pure, in `app/lib/domain/session_plan.dart`): Σ over exercises of Σ working sets `weight × reps` from `planExercise(configIn(cfg, unit), history, routineDefault: r.policy, unit: unit.label)`.

- [ ] **Step 1: Tests**
```dart
test('plannedSessionVolume menjumlahkan beban × rep set kerja rencana', () { … expect(v, closeTo(expected, 0.01)); });
testWidgets('Program: kartu program, kisi rutinitas dengan odometer dan tombol mulai, aturan', (tester) async {
  … applyTemplate('ppl') …
  expect(find.text('PROGRAM AKTIF'), findsOneWidget);
  expect(find.text('Ganti program'), findsOneWidget);
  expect(find.text('Lewati sesi'), findsOneWidget);
  expect(find.text('Push'), findsOneWidget); expect(find.text('Berikutnya'), findsOneWidget);
  expect(find.byType(Odometer), findsNWidgets(3));
  expect(find.text('Tambah rutinitas'), findsOneWidget);
  await tester.scrollUntilVisible(find.text('Aturan program'), 200, scrollable: …);
  expect(find.text('Mode'), findsOneWidget); expect(find.text('Rotasi'), findsOneWidget);
  expect(find.text('Istirahat minimum antar sesi'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('rest-plus')));
  await tester.pump();
  expect(store.program!.minRestDays, 1);
});
testWidgets('Mulai di kartu Push membuka sesi Push', … tap ValueKey('start-ppl-0') → find.byType(SessionScreen) …);
testWidgets('tanpa program: Pilih program & Susun sendiri, rutinitas lepas tetap tampil', …);
testWidgets('Urutkan membuka sheet urutan dan memindah rutinitas', … expect(store.program!.order.first, 'ppl-1'));
```
- [ ] **Step 2 → FAIL. Step 3: Implement** per spec §7.7: grid via `Row` pairs; card `GymCard(radius: 20, padding: 14)` with `Border.all(accent, 1.5)` when next; `Odometer(value: kgTo(plannedSessionVolume(...), unit), unit: unitLabel)`; `GlassIconButton(play, size: 34, tinted: isNext, key: ValueKey('start-${r.id}'), tooltip: t.startSession)`; add card dashed via `CustomPaint` dash painter (reuse pattern: 1.2 px, dash 6/4, color text3); rules group with `_ModeRow` → `showModalBottomSheet` of two `SelectRow`s; weekday → `Wrap` of `FilterChip`s (existing code); rest stepper `ValueKey('rest-minus')/('rest-plus')`. Program meta: policy majority label via `t.policy(policyName[...])`. Skip session only in rotation. Loose routines (not in program) listed after program routines in the grid.
- [ ] **Step 4: Run** program + shell tests → PASS; grep `WorkoutScreen` in lib/test → none.
- [ ] **Step 5: Commit** `v3: tab Program menggantikan Workout — kartu program, kisi rutinitas, aturan`

### Task 10: Session + rest pill + rest screen

**Files:**
- Create: `app/lib/features/session/rest_pill.dart` (`RestPill`)
- Modify: `app/lib/features/session/session_screen.dart` (`_TopBar`, `_NotesField`, `_ExerciseCard`, `_RestRow`, `_SetTable`, `_SetRowTile`, `_Cell`, `_DashedAction`, body Stack with pill, remove in-list `RestTimerCard` + header capsule)
- Modify: `app/lib/features/session/rest_screen.dart` (buttons, ring colors)
- Modify tests: `app/test/session_screen_test.dart` ('REST' → `find.byType(RestPill)`), `app/test/v22_session_test.dart` (tooltips 'Skip rest'/'Lewati istirahat'; capsule geometry test → pill geometry), `app/test/v22_draft_test.dart` if it finds the capsule
- Test: `app/test/v30_session_test.dart`

**Interfaces:** `RestPill({required RestTimer timer, required String nextLabel, required VoidCallback onOpen, required VoidCallback onSkip})`; `SessionScreen` API unchanged. Exposed keys: `ValueKey('rest-pill')`, `ValueKey('rest-skip')`.

- [ ] **Step 1: Tests**
```dart
testWidgets('header: Selesai kaca, waktu 30/800; tidak ada kapsul istirahat di header', …);
testWidgets('centang set → pil istirahat muncul di bawah dengan −15/+15/lewati; daftar diberi ruang', (tester) async {
  … tap(find.byIcon(GymIcons.circle).first); pump 500ms; pop rest screen; pump …
  expect(find.byKey(const ValueKey('rest-pill')), findsOneWidget);
  expect(find.text('−15'), findsOneWidget); expect(find.text('+15'), findsOneWidget);
  final pill = tester.getRect(find.byKey(const ValueKey('rest-pill')));
  expect(pill.bottom, lessThanOrEqualTo(780)); expect(pill.height, 64);
  final list = tester.widget<ListView>(find.byType(ListView));
  expect((list.padding as EdgeInsets).bottom, greaterThanOrEqualTo(90));
  await tester.tap(find.byKey(const ValueKey('rest-skip'))); await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('rest-pill')), findsNothing);
});
testWidgets('aksi gerakan: Riwayat gerakan dan Superset sebagai tombol kaca', … expect(find.text('Riwayat gerakan'), findsOneWidget); tap 'Superset' → ex.config.superset true; label becomes 'Akhiri superset');
testWidgets('baris aktif bergaris, baris selesai doneBg', …);
```
- [ ] **Step 2 → FAIL. Step 3: Implement** per spec §7.3. Body: `Column([_TopBar, progress, Expanded(Stack([ListView(padding bottom: resting ? 94 : 28), Positioned(bottom, left: 16, right: 16, child: AnimatedSlide/AnimatedBuilder(rest) → RestPill)]))])`; keyboard: `Padding(bottom: MediaQuery.viewInsetsOf(context).bottom)` around the pill so it rises above the keyboard. `_TopBar`: `GlassIconButton(chevronDown, size: 40, tooltip: t.minimise)`, title column, `GymButton(label: t.finish, height: 40, expand: false)`. Set row per spec; `_Cell` pill: `Container(height: 40, surface2 r12, border active ? Border.all(c.text, 1.5) : null)` with `Row(step−, TextField, step+)`; done row: text only. Exercise actions row below add-set. Rest screen: `GymButton` neutral/primary (already) + ring colors `ringTrack`/`accent`.
- [ ] **Step 4: Run** `flutter test test/v30_session_test.dart test/session_screen_test.dart test/v22_session_test.dart test/v22_draft_test.dart test/v17_features_test.dart --concurrency=4` → PASS.
- [ ] **Step 5: Commit** `v3: layar sesi — header kaca, tabel set baru, pil istirahat mengapung`

### Task 11: Finish screen

**Files:** Modify `app/lib/features/session/finish_screen.dart`; test `app/test/v30_finish_test.dart`.
- [ ] **Step 1: Test**: build `FinishScreen` with two exercises (one PR) → expects 'Sesi selesai', 'Durasi', 'Volume', 'Set kerja', 'Total rep', 'Rekor baru' (twice: grid + card title), 'Target naik', 'Target sesi berikutnya', `find.byType(MuscleMap)` one, `find.text('Selesai')` button; sync card variant: `routineUpdated: true` → 'Batalkan' link; tapping it → store routine reverted and text 'Simpan lagi'.
- [ ] **Step 2 → FAIL. Step 3: Implement** per spec §7.4 (`_Metric` → `_StatTile` 65 high with `HueTile`-like surface2 tile; big stats row; records card; next targets with `Pill` variants: up doneBg "+1 rep"/"+2,5 kg" (reps delta when weight equal), hold surface2 `t.holdTag`, deload warnSoft, first `t.newTag`); `_RoutineSyncCard` → banner with link text instead of buttons (`TextButton`), states per spec.
- [ ] **Step 4: PASS. Step 5: Commit** `v3: ringkasan sesi baru`

### Task 12: History

**Files:** Modify `app/lib/features/history/history_screen.dart`; tests: update `app/test/v22_history_test.dart` (month label stays 'SEPTEMBER 2026'; detail sheet button labels now 'Resume session', 'Edit', 'Delete' — already changed in Task 3), add `app/test/v30_history_test.dart`.
- [ ] **Step 1: Test**: rows show `HueTile`, badge with working-set count (`find.text('2')` inside row key `ValueKey('session-badge-…')`), meta 'Sab, 3 Okt · 48 mnt · 6,1 t' format via `t.minutesShort`; header plus is `GlassIconButton`; 'Aktivitas' + `sessionsThisYearV3`.
- [ ] **Step 2 → FAIL. Step 3: Implement** per spec §7.5 (row 72, tile with badge `Positioned(right: -4, bottom: -4)`, hue = `c.hues.at(index of routine name in program order, else hash)`; freestyle = orange + alarm). Keep `Dismissible`, undo, sheets.
- [ ] **Step 4: Run** history tests → PASS. **Step 5: Commit** `v3: Riwayat baru`

### Task 13: Stats (3 tabs) + bodyweight + dashboard

**Files:** Modify `app/lib/features/stats/stats_screen.dart`, `bodyweight_card.dart`, `dashboard_screen.dart`; update `app/test/v22_stats_test.dart` ('WEEKLY SET VOLUME' → 'Weekly set volume', 'ESTIMATED 1RM' → 'Estimated 1RM', KPI 'Working sets' stays; dashboard titles unchanged unless `SectionLabel` → keep `SectionLabel` in dashboard); add `app/test/v30_stats_test.dart`.
- [ ] **Step 1: Test**: KPI tiles contain `HueTile`s (3); tabs `SegmentedTabs`; Keseimbangan shows 'Peta panas otot', 'porsi volume', 'Rendah', 'Tinggi', 'Region tubuh yang dilatih'; Kelelahan shows `averageFormat` pill text 'rata-rata N set' and 'Hari sejak terakhir dilatih'; Kekuatan shows 'Perkiraan 1RM', `Sparkline`s, 'Berat badan', 'Catat', 'Buka dashboard'; bodyweight with ≥ 2 entries shows a `Sparkline`, no `BarSeries`.
- [ ] **Step 2 → FAIL. Step 3: Implement** per spec §7.6; `_Kpi` → surface card r18 + `HueTile(size 30, radius 10, iconSize 15)` + `CountUp` 20/800 + label; `SectionLabel` card titles → `Text(titleMedium)`; strength rows per spec; `_DaysBar` 110×8; `BodyweightCard` per spec; dashboard `_Metric` → surface card + `HueTile`.
- [ ] **Step 4: Run** stats tests → PASS. **Step 5: Commit** `v3: Statistik tiga tab bergaya baru, berat badan ringkas`

### Task 14: Profile

**Files:** Modify `app/lib/features/profile/profile_screen.dart`; update `app/test/profile_screen_test.dart` (labels: 'Satuan berat', group titles; logout now a row 'Keluar'/'Log out'); add cases to `app/test/v30_shell_test.dart` (accent dot tap changes accent).
- [ ] **Step 1: Test**: groups 'LATIHAN', 'TAMPILAN', 'DATA & AKUN'; rows per spec; five accent dots `find.byKey(ValueKey('accent-dot-$i'))`, tapping index 2 calls `onAccentChanged` with `accentChoices[2]`; sync row text 'Tersinkron · …' or 'Tanpa server'.
- [ ] **Step 2 → FAIL. Step 3: Implement** per spec §7.8 (keep all handlers; `_pick…` sheets now `bg` + r28 + `SelectRow`).
- [ ] **Step 4: PASS. Step 5: Commit** `v3: Profil baru`

### Task 15: Secondary screens sweep, analyze, full test run

**Files:** `login_screen.dart`, `register_screen.dart`, `field.dart`, `onboarding_screens.dart`, `custom_split_screen.dart`, `equipment_picker.dart`, `library_screen.dart`, `routine_editor_screen.dart`, `workout_edit_screen.dart`, `exercise_history_sheet.dart`, `rest_timer.dart` (duration sheet).
- [ ] **Step 1:** `grep -rn "IconDisc\|c\.tint(\|GymRadius.hero\|GymRadius.large\|SectionLabel(" app/lib/features` — for each: `GymRadius.hero/large` → `card`; `IconDisc` in library categories → keep (restyled); sheets → `bg` + r28; `_SearchField` → surface r16 + hairline; `_OutlinedAction`/`_AddDayRow`/`_AddExercise` dashed outlines → `text3` 1.2 stroke; `GymField` → surface fill, r14, hairline border, accent focus.
- [ ] **Step 2:** `flutter analyze` → 0 issues. `flutter test --concurrency=4 > D:/sdk/tmp/v3-tests.log` → all pass (≈ 400+). Fix regressions.
- [ ] **Step 3:** Golden-ish smoke: run `flutter run -d chrome`? No — instead `flutter build web --release` later (Task 16). Here run the emulator debug build only if MuMu is up; otherwise skip (documented).
- [ ] **Step 4: Commit** `v3: layar sekunder mengikuti token baru; analyze bersih`

### Task 16: Version, docs, build, release, deploy

- [ ] **Step 1:** `pubspec.yaml` version `3.0.0+24`; `design/UI-V2.md` add a top note "Digantikan UI-V3.md (v3.0.0)"; update `docs/PRD.md` §UI reference line if it names v2.
- [ ] **Step 2:** `flutter test --concurrency=4` final pass; `flutter analyze`.
- [ ] **Step 3:** Commit + push branch; `gh pr create` (body: summary, screenshots from Pen exports `gymapps_v3_terang.png`/`gelap.png` as attachments optional, test plan; ends with the Claude Code line). Check CI with `mcp__ccd_pr__get_status` + single `gh run view`.
- [ ] **Step 4:** `gh pr merge <n> --rebase`; `git checkout main && git pull`; verify `git diff v3-bevel-glass main --stat` empty.
- [ ] **Step 5:** `pwsh scripts/build-android.ps1` (release, 3 ABIs) in background with log; after: `gradlew --stop`; verify APKs with `verify_apk.py` pattern (version 3.0.0, no `assets/3d`, fonts without Manrope).
- [ ] **Step 6:** `gh release create v3.0.0 --target main --title "v3.0.0 — UI Bevel glass" --notes-file <scratch>/release-3.0.0.md app/build/app/outputs/flutter-apk/*.apk`.
- [ ] **Step 7:** `pwsh scripts/deploy-web.ps1` in background with log; verify `https://gymapps-hariz.vercel.app/version.json` reports 3.0.0 and run `D:\sdk\pw\gymapps-webkit-boot.mjs` (login screen renders; tap field; screenshot).
- [ ] **Step 8:** Update memory `gymapps-project.md` (v3 paragraph: tokens file, glass primitive, nav change, blur rule) and send the user the APK/web links.

---

## Self-review notes

- Spec coverage: §1 → T1/T2; §2 → T1/T3; §3 → T1/T3; §4 → T4 (+ icon mapping used in screen tasks); §5 → T7/T9; §6 → T3/T5/T10 (RestPill); §7.1 → T8; §7.2 → T7; §7.3 → T10; §7.4 → T11; §7.5 → T12; §7.6 → T13; §7.7 → T9; §7.8 → T14; §7.9 → T15; §8 → T8; §9 → T8/T10; §10 → T1 tests, T7 labels; §11 → T3/T4/T8/T9/T10/T14.
- Type consistency: `GlassSurface(tone, radius, blur, padding, shadow, width, height, alignment)` used identically in T3/T7/T10; `HueTile(icon, hue, size, radius, iconSize)`; `RingGauge(fraction, color, value, label, delay)`; `Odometer(value, unit)`; `homeInsight` record `(title, body)`; `plannedSessionVolume(Routine, List<Workout>, WeightUnit, ProgressionPolicy?)`.
- Review Focus tests live in T1 (accents), T10 (pill vs keyboard/list padding), T3 (segThumb), T7 (sign-out from pushed Profile), T9 (no program).
