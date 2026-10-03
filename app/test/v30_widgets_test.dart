/// Komponen bersama UI v3: tombol kaca, tab segmented, chip, tile hue,
/// odometer, cincin, baris setelan tanpa cakram, dan label tombol yang bukan
/// lagi KAPITAL.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    final glass = tester.widget<GlassSurface>(
        find.descendant(of: find.byType(GymButton), matching: find.byType(GlassSurface)));
    expect(glass.tone, GlassTone.tinted);
    final style = tester.widget<Text>(find.text('Mulai sesi')).style!;
    expect(style.color, Colors.white);
    expect(style.fontSize, 15);
  });

  testWidgets('GymButton neutral = kaca clear; danger berteks danger', (tester) async {
    await tester.pumpWidget(_app(Column(children: [
      GymButton(label: 'Lewati', tone: GymButtonTone.neutral, onPressed: () {}),
      GymButton(label: 'Hapus', tone: GymButtonTone.danger, onPressed: () {}),
    ])));
    final glasses = tester.widgetList<GlassSurface>(find.byType(GlassSurface)).toList();
    expect(glasses, hasLength(2));
    expect(glasses.every((g) => g.tone == GlassTone.clear), isTrue);
    expect(tester.widget<Text>(find.text('Hapus')).style!.color, GymColors.dark.danger);
  });

  test('semua label tombol di Strings bukan KAPITAL', () {
    for (final lang in AppLanguage.values) {
      final t = Strings(lang);
      for (final s in [
        t.save, t.delete, t.done, t.startSession, t.finish, t.addExercise, t.addSet, t.skipRest, t.logOut,
        t.choosePlan, t.finishAndSave, t.signIn, t.cont, t.resume, t.edit, t.start, t.newRoutine, t.discard,
      ]) {
        expect(s, isNot(equals(s.toUpperCase())), reason: '"$s" masih kapital');
      }
    }
  });

  testWidgets('SegmentedTabs: thumb segThumb bergeser ke indeks, tinggi 44', (tester) async {
    var idx = 0;
    await tester.pumpWidget(_app(StatefulBuilder(
      builder: (context, set) => SegmentedTabs(labels: const ['A', 'B', 'C'], index: idx, onChanged: (i) => set(() => idx = i)),
    )));
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(idx, 2);
    final thumb = tester.widget<DecoratedBox>(find.byKey(const ValueKey('seg-thumb')));
    expect((thumb.decoration as BoxDecoration).color, GymColors.dark.segThumb);
    expect(tester.getSize(find.byType(SegmentedTabs)).height, 44);
  });

  testWidgets('FilterChips: terpilih kaca tinted, lainnya bergaris hairline, tinggi 32', (tester) async {
    await tester.pumpWidget(_app(FilterChips(labels: const ['Semua', 'Push'], index: 0, onChanged: (_) {})));
    expect(find.descendant(of: find.byType(FilterChips), matching: find.byType(GlassSurface)), findsOneWidget);
    expect(tester.getSize(find.byType(FilterChips)).height, 32);
    expect(tester.widget<Text>(find.text('Semua')).style!.color, Colors.white);
  });

  testWidgets('HueTile, TagPill, Odometer, RingGauge tergambar', (tester) async {
    await tester.pumpWidget(_app(
      Column(children: [
        HueTile(icon: Icons.fitness_center, hue: GymColors.light.hues.pink),
        const TagPill('Hari ini'),
        const Odometer(value: 5430, unit: 'kg'),
        RingGauge(fraction: 0.66, color: GymColors.light.ringA, value: '2/3', label: 'Sesi minggu ini'),
      ]),
      b: Brightness.light,
    ));
    await tester.pumpAndSettle();
    expect(find.text('HARI INI'), findsOneWidget);
    for (final d in ['5', '4', '3', '0']) {
      expect(find.text(d), findsOneWidget);
    }
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('Sesi minggu ini'), findsOneWidget);
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
    expect(find.text('kg'), findsOneWidget);
  });

  testWidgets('GymCard membawa bayangan kartu', (tester) async {
    await tester.pumpWidget(_app(const GymCard(child: Text('isi'))));
    final box = tester.widget<Container>(find.descendant(of: find.byType(GymCard), matching: find.byType(Container)).first);
    final deco = box.decoration as BoxDecoration;
    expect(deco.boxShadow, isNotNull);
    expect(deco.boxShadow!.first.blurRadius, 18);
  });
}
