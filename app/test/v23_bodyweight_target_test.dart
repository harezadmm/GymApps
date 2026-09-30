/// Garis target berat badan (FR-F4): target tersimpan di setelan dalam kg dan
/// ikut gabung dua perangkat, tampil sebagai garis putus-putus di grafik yang
/// rentangnya ikut memuat target, dan batang terakhir plus "x kg to go"
/// diwarnai menurut arahnya — kriteria penerimaan PRD: "masukkan target
/// 75 kg, garis tampil, titik diwarnai sesuai arah ke target".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/charts.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/strings_bodyweight.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/settings.dart';
import 'package:gymapps/domain/stats.dart';
import 'package:gymapps/domain/units.dart';
import 'package:gymapps/features/stats/bodyweight_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(
  WorkoutStore store,
  Widget home, {
  AppLanguage lang = AppLanguage.english,
  Brightness brightness = Brightness.dark,
}) =>
    WorkoutScope(
      store: store,
      child: AppStrings(
        strings: Strings(lang),
        child: MaterialApp(theme: buildGymTheme(brightness: brightness), home: home),
      ),
    );

/// Kartu di dalam daftar berpadding 16, seperti di tab Stats.
Widget _card(WorkoutStore store, {AppLanguage lang = AppLanguage.english, Brightness brightness = Brightness.dark}) =>
    _wrap(
      store,
      Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: const [BodyweightCard()])),
      lang: lang,
      brightness: brightness,
    );

/// HP kecil yang umum: 360 × 780 dp.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Pump berjangka, bukan pumpAndSettle: animasi kedatangan batang tidak
/// pernah "tenang" selagi grafiknya dibangun ulang.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Catatan berat badan (kg) satu per hari, terlama dulu.
Future<void> _seed(WorkoutStore store, List<double> kgs) async {
  for (final (i, kg) in kgs.indexed) {
    await store.logBodyweight('2026-09-${(i + 1).toString().padLeft(2, '0')}', kg);
  }
}

BodyweightEntry _e(double kg) => BodyweightEntry(date: '2026-09-01', kg: kg);

/// Warna batang terakhir di grafik — batang yang disorot.
Color? _lastBar(WidgetTester tester) {
  final bars = tester.widgetList<AnimatedContainer>(
    find.descendant(of: find.byType(BarSeries), matching: find.byType(AnimatedContainer)),
  );
  return (bars.last.decoration as BoxDecoration).color;
}

GymColors _colors({Brightness brightness = Brightness.dark}) =>
    buildGymTheme(brightness: brightness).extension<GymColors>()!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('setelan target (FR-F4)', () {
    test('belum diatur: null dan tidak ditulis', () {
      const s = TrainingSettings();
      expect(s.bodyweightTarget, isNull);
      expect(s.toJson().containsKey('bwTarget'), isFalse);
      expect(TrainingSettings.fromJson(const {}).bodyweightTarget, isNull);
    });

    test('bolak-balik JSON dalam kg; copyWith: null = biarkan, hapus lewat clear', () {
      final s = const TrainingSettings().copyWith(bodyweightTarget: 75);
      expect(s.toJson()['bwTarget'], 75);
      expect(TrainingSettings.fromJson(s.toJson()).bodyweightTarget, 75);
      expect(s.copyWith(logRir: true).bodyweightTarget, 75, reason: 'kolom lain tidak menyentuhnya');
      expect(s.copyWith(bodyweightTarget: 70).bodyweightTarget, 70);
      expect(s.copyWith(clearBodyweightTarget: true).bodyweightTarget, isNull);
      expect(s.copyWith(clearBodyweightTarget: true).toJson().containsKey('bwTarget'), isFalse);
    });

    test('nilai rusak dari perangkat lain dibaca sebagai tanpa target', () {
      for (final bad in [0, -5, 'x', double.nan, double.infinity, true, null]) {
        expect(TrainingSettings.fromJson({'bwTarget': bad}).bodyweightTarget, isNull, reason: '$bad');
      }
      expect(TrainingSettings.fromJson({'bwTarget': 74.8}).bodyweightTarget, 74.8);
    });

    test('disimpan kg, ditampilkan dalam satuan pilihan — seperti berat badan', () {
      // Diatur 165 lb: kembali persis 165, dan tetap 74,84 kg di HP yang
      // memakai kg — target yang sama, bukan target lain.
      final s = const TrainingSettings(unit: WeightUnit.lb).copyWith(bodyweightTarget: toKg(165, WeightUnit.lb));
      expect(shown(s.bodyweightTarget!, WeightUnit.lb), 165);
      expect(shown(s.bodyweightTarget!, WeightUnit.kg), closeTo(74.84, 0.001));
      expect(shown(75, WeightUnit.lb), closeTo(165.3, 0.001));
    });

    test('gabung setelan dua perangkat: target per kolom', () {
      final base = {'bwTarget': 75.0, 'rest': 90};
      final mine = {'bwTarget': 72.0, 'rest': 90};
      final theirs = {'bwTarget': 75.0, 'rest': 120};
      final merged = WorkoutStore.mergeSettings(base: base, mine: mine, theirs: theirs);
      expect(merged['bwTarget'], 72, reason: 'diubah di sini');
      expect(merged['rest'], 120, reason: 'diubah di server');
      expect(TrainingSettings.fromJson(merged).bodyweightTarget, 72);
      // Diubah di server, tidak disentuh di sini: milik server.
      expect(WorkoutStore.mergeSettings(base: base, mine: base, theirs: {'bwTarget': 70.0})['bwTarget'], 70);
      // Dihapus di server, tidak disentuh di sini: ikut hilang.
      expect(WorkoutStore.mergeSettings(base: base, mine: base, theirs: const {}).containsKey('bwTarget'), isFalse);
      // Diatur di sini, server belum tahu: tetap.
      expect(WorkoutStore.mergeSettings(base: const {}, mine: {'bwTarget': 75.0}, theirs: const {})['bwTarget'], 75);
    });

    test('tersimpan ke disk dan dibaca ulang', () async {
      SharedPreferences.setMockInitialValues({});
      final a = WorkoutStore();
      await a.load('a@x.com');
      await a.updateSettings(a.settings.copyWith(bodyweightTarget: 75));
      final b = WorkoutStore();
      await b.load('a@x.com');
      expect(b.settings.bodyweightTarget, 75);
      await b.updateSettings(b.settings.copyWith(clearBodyweightTarget: true));
      final c = WorkoutStore();
      await c.load('a@x.com');
      expect(c.settings.bodyweightTarget, isNull);
    });
  });

  group('bodyweightGap', () {
    test('kg: sisa ke target, arah dari dua catatan terakhir, panah dari selisihnya', () {
      final toward = bodyweightGap([_e(80), _e(79), _e(78.4)], 75, WeightUnit.kg)!;
      expect(toward.toGo, 3.4, reason: '78,4 − 75 tanpa debu float');
      expect(toward.heading, TargetHeading.toward);
      expect(toward.delta, -0.6);
      expect(toward.onTarget, isFalse);

      final away = bodyweightGap([_e(78), _e(79)], 75, WeightUnit.kg)!;
      expect(away.toGo, 4);
      expect(away.heading, TargetHeading.away);
      expect(away.delta, 1);

      // Target di atas berat badan: naik = mendekat.
      final bulking = bodyweightGap([_e(70), _e(71.5)], 75, WeightUnit.kg)!;
      expect(bulking.toGo, 3.5);
      expect(bulking.heading, TargetHeading.toward);
      expect(bulking.delta, 1.5);
    });

    test('sudah di target: dalam setengah satuan tampilan, batasnya ikut', () {
      expect(bodyweightGap([_e(76), _e(75.5)], 75, WeightUnit.kg)!.onTarget, isTrue);
      expect(bodyweightGap([_e(76), _e(74.5)], 75, WeightUnit.kg)!.onTarget, isTrue);
      expect(bodyweightGap([_e(76), _e(75.51)], 75, WeightUnit.kg)!.onTarget, isFalse);
      expect(bodyweightGap([_e(76), _e(75.51)], 75, WeightUnit.kg)!.toGo, 0.51);
      // lb: 0,5 lb, dihitung dari angka tampilan 0,1 lb.
      final lb = bodyweightGap([_e(toKg(165.5, WeightUnit.lb))], toKg(165, WeightUnit.lb), WeightUnit.lb)!;
      expect(lb.toGo, 0.5);
      expect(lb.onTarget, isTrue);
      expect(bodyweightGap([_e(toKg(165.6, WeightUnit.lb))], toKg(165, WeightUnit.lb), WeightUnit.lb)!.onTarget, isFalse);
    });

    test('lb: sisa dan selisih dalam lb; dua catatan yang tampil sama tidak "mendekat"', () {
      final g = bodyweightGap(
        [_e(toKg(180, WeightUnit.lb)), _e(toKg(178.6, WeightUnit.lb))],
        toKg(165, WeightUnit.lb),
        WeightUnit.lb,
      )!;
      expect(g.toGo, 13.6);
      expect(g.heading, TargetHeading.toward);
      expect(g.delta, -1.4);
      // 80 kg dan 80,002 kg sama-sama tampil 176,4 lb: tidak bergerak.
      final still = bodyweightGap([_e(80), _e(80.002)], 75, WeightUnit.lb)!;
      expect(still.heading, isNull);
      expect(still.delta, 0);
      expect(still.toGo, closeTo(11.1, 0.0001), reason: '176,4 − 165,3');
    });

    test('tanpa catatan: null; satu catatan: tanpa arah; sama jauh dua sisi: tanpa arah', () {
      expect(bodyweightGap(const [], 75, WeightUnit.kg), isNull);
      final one = bodyweightGap([_e(78.4)], 75, WeightUnit.kg)!;
      expect(one.toGo, 3.4);
      expect(one.heading, isNull);
      expect(one.delta, isNull);
      // Melompati target dari 74 ke 76: sama jauhnya, bukan mendekat.
      final crossed = bodyweightGap([_e(74), _e(76)], 75, WeightUnit.kg)!;
      expect(crossed.heading, isNull);
      expect(crossed.delta, 2);
      expect(crossed.toGo, 1);
    });
  });

  group('teks', () {
    test('"x kg to go" / "x kg lagi", sudah di target, label garis dan tombol', () {
      const en = Strings(AppLanguage.english);
      const id = Strings(AppLanguage.indonesian);
      expect(en.toGo('3.4 kg'), '3.4 kg to go');
      expect(id.toGo('3.4 kg'), '3.4 kg lagi');
      expect(en.onTarget, 'On target');
      expect(id.onTarget, 'Sudah di target');
      expect(en.targetLineLabel('75 kg'), 'target 75 kg');
      expect(id.targetButton('165 lb'), 'Target 165 lb');
      expect(en.setBodyweightTarget, 'Set target');
      expect(id.clearBodyweightTarget, 'Hapus target');
    });
  });

  group('BarSeries garis acuan', () {
    Widget chart(double reference) => MaterialApp(
          theme: buildGymTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: BarSeries(
                values: const [10, 20, 30],
                reference: ChartReference(value: reference, label: 'goal'),
                leftLabel: 'a',
                midLabel: '',
                rightLabel: 'b',
              ),
            ),
          ),
        );

    testWidgets('acuan di atas semua batang melebarkan rentang; label tetap di dalam grafik', (tester) async {
      _phone(tester);
      await tester.pumpWidget(chart(60));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Tinggi grafik bawaan 132; batang 30 dari rentang 0–60 = separuhnya.
      expect(tester.getSize(find.byType(AnimatedContainer).last).height, closeTo(66, 0.5));
      final top = tester.getRect(find.byType(BarSeries)).top;
      final label = tester.getRect(find.text('goal'));
      expect(label.top, greaterThanOrEqualTo(top), reason: 'garis di tepi atas: label pindah ke bawah garis');
      expect(label.bottom, lessThanOrEqualTo(top + 132));

      // Acuan di dalam rentang: batang tidak berubah, label di atas garisnya.
      await tester.pumpWidget(chart(15));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AnimatedContainer).last).height, closeTo(132, 0.5));
      final lineY = top + 132 * (1 - 15 / 30);
      final above = tester.getRect(find.text('goal'));
      expect(above.bottom, lessThanOrEqualTo(lineY));
      expect(above.top, greaterThanOrEqualTo(top));
      expect(tester.takeException(), isNull);
    });
  });

  group('kartu berat badan', () {
    late WorkoutStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = WorkoutStore();
      await store.load();
    });

    testWidgets('atur target lewat dialog: garis dan "to go" muncul, batang terakhir hijau; hapus: hilang',
        (tester) async {
      _phone(tester);
      await _seed(store, [80, 79, 78.4]);
      await tester.pumpWidget(_card(store));
      await _settle(tester);
      expect(find.text('Set target'), findsOneWidget);
      expect(find.text('target 75 kg'), findsNothing);
      expect(_lastBar(tester), _colors().hues.pink, reason: 'tanpa target: warna kartu');

      await tester.tap(find.text('Set target'));
      await _settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Clear target'), findsNothing, reason: 'belum ada yang bisa dihapus');
      await tester.enterText(find.byType(TextField), '75');
      // Satu frame: tombol simpan baru hidup setelah isinya jadi angka.
      await tester.pump();
      await tester.tap(find.text('SAVE'));
      await _settle(tester);

      expect(store.settings.bodyweightTarget, 75);
      expect(find.text('target 75 kg'), findsOneWidget, reason: 'label garis di grafik');
      expect(find.text('Target 75 kg'), findsOneWidget, reason: 'tombolnya menyebut targetnya');
      expect(find.text('3.4 kg to go'), findsOneWidget);
      expect(find.byIcon(Icons.trending_down_outlined), findsOneWidget);
      expect(_lastBar(tester), _colors().doneInk, reason: '79 → 78,4 mendekati 75');
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Target 75 kg'));
      await _settle(tester);
      await tester.tap(find.text('Clear target'));
      await _settle(tester);
      expect(store.settings.bodyweightTarget, isNull);
      expect(find.text('target 75 kg'), findsNothing);
      expect(find.text('3.4 kg to go'), findsNothing);
      expect(find.text('Set target'), findsOneWidget);
      expect(_lastBar(tester), _colors().hues.pink);
      expect(tester.takeException(), isNull);
    });

    testWidgets('menjauh = peringatan; sudah di target = aksen dan "On target"', (tester) async {
      _phone(tester);
      await _seed(store, [78, 79]);
      await store.updateSettings(store.settings.copyWith(bodyweightTarget: 75));
      await tester.pumpWidget(_card(store));
      await _settle(tester);
      expect(find.text('4 kg to go'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_outlined), findsOneWidget);
      expect(_lastBar(tester), _colors().warn);

      await store.logBodyweight('2026-09-03', 75.3);
      await _settle(tester);
      expect(find.text('On target'), findsOneWidget);
      expect(find.textContaining('to go'), findsNothing);
      expect(_lastBar(tester), _colors().accent);
      expect(tester.takeException(), isNull);
    });

    testWidgets('satuan lb: dialog dalam lb, tersimpan kg, label dan sisa dalam lb', (tester) async {
      _phone(tester);
      await _seed(store, [80, 79, 78.4]);
      await store.updateSettings(store.settings.copyWith(unit: WeightUnit.lb));
      await tester.pumpWidget(_card(store));
      await _settle(tester);
      await tester.tap(find.text('Set target'));
      await _settle(tester);
      expect(find.text('lb'), findsOneWidget, reason: 'akhiran satuan di kotak angka');
      await tester.enterText(find.byType(TextField), '165');
      await tester.pump();
      await tester.tap(find.text('SAVE'));
      await _settle(tester);
      expect(store.settings.bodyweightTarget, closeTo(toKg(165, WeightUnit.lb), 0.0001));
      expect(find.text('target 165 lb'), findsOneWidget);
      expect(find.text('Target 165 lb'), findsOneWidget);
      expect(find.text('7.8 lb to go'), findsOneWidget, reason: '78,4 kg = 172,8 lb');

      // Dibuka lagi: angkanya kembali persis 165, bukan 164,9 hasil konversi.
      await tester.tap(find.text('Target 165 lb'));
      await _settle(tester);
      expect(find.widgetWithText(TextField, '165'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('target tanpa catatan: tombol menyebut target, tanpa sisa dan tanpa grafik', (tester) async {
      _phone(tester);
      await store.updateSettings(store.settings.copyWith(bodyweightTarget: 75));
      await tester.pumpWidget(_card(store));
      await _settle(tester);
      expect(find.text('Target 75 kg'), findsOneWidget);
      expect(find.byType(BarSeries), findsNothing);
      expect(find.textContaining('to go'), findsNothing);
      expect(find.text('No entries yet — log one to track the trend.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kurangi gerak: garis dan label langsung tampil dalam satu frame', (tester) async {
      _phone(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _seed(store, [80, 79, 78.4]);
      await store.updateSettings(store.settings.copyWith(bodyweightTarget: 75));
      await tester.pumpWidget(_card(store));
      await tester.pump();
      expect(find.text('target 75 kg'), findsOneWidget);
      expect(find.text('3.4 kg to go'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final lang in [AppLanguage.english, AppLanguage.indonesian]) {
      for (final brightness in [Brightness.dark, Brightness.light]) {
        final tag = '${lang == AppLanguage.indonesian ? 'id' : 'en'}/${brightness == Brightness.light ? 'terang' : 'gelap'}';
        testWidgets('[$tag] kartu utuh di 360 dp dengan huruf 1,3× (NFR-11)', (tester) async {
          _phone(tester);
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          // Angka lebar dan target jauh di bawah semua catatan: label, sisa
          // tiga digit, dan dua tombol sekaligus.
          await _seed(store, [102.5, 101, 100.4, 99.8]);
          await store.updateSettings(store.settings.copyWith(bodyweightTarget: 85));
          await tester.pumpWidget(_card(store, lang: lang, brightness: brightness));
          await _settle(tester);
          expect(tester.takeException(), isNull);
          expect(find.text('target 85 kg'), findsOneWidget);
          expect(find.text(lang == AppLanguage.indonesian ? '14.8 kg lagi' : '14.8 kg to go'), findsOneWidget);
          expect(_lastBar(tester), _colors(brightness: brightness).doneInk);

          await tester.tap(find.text('Target 85 kg'));
          await _settle(tester);
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
