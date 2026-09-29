/// Penjaga v2.2 untuk Statistik dan Dashboard: grafik yang bisa disentuh,
/// peta otot yang bisa diketuk, dan tata letak yang tidak meluber di HP 360 dp
/// maupun melebar di tablet/laptop.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/body_map_data.dart';
import 'package:gymapps/core/charts.dart';
import 'package:gymapps/core/layout.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/strings_stats.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/muscle_volume.dart';
import 'package:gymapps/features/stats/dashboard_screen.dart';
import 'package:gymapps/features/stats/stats_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        child: MaterialApp(theme: buildGymTheme(), home: home),
      ),
    );

/// Layar dengan lebar [dp] logis pada rasio 2 (atau 3 untuk HP 360 dp).
void _screen(WidgetTester tester, double dp, {double height = 800}) {
  final ratio = dp <= 400 ? 3.0 : 2.0;
  tester.view.physicalSize = Size(dp * ratio, height * ratio);
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
}

Workout _w(String date, String id, double weight, List<int> reps) => Workout(date: date, entries: [
      WorkoutEntry(exerciseId: id, sets: [for (final r in reps) SetRow(weight: weight, reps: r, done: true)]),
    ]);

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Tiga sesi bench/squat dalam dua minggu terakhir — cukup untuk mengisi
/// peta otot, radar, set mingguan, e1RM, dan tabel dashboard.
Future<void> _seed(WorkoutStore store) async {
  final today = DateTime.now();
  await store.addWorkout(_w(_iso(today.subtract(const Duration(days: 12))), '0025', 60, [8, 8, 8]));
  await store.addWorkout(_w(_iso(today.subtract(const Duration(days: 5))), '0043', 80, [5, 5, 5]));
  await store.addWorkout(_w(_iso(today.subtract(const Duration(days: 1))), '0025', 62.5, [8, 8, 7]));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('muscleGroupAt', () {
    test('titik di tengah sebuah bentuk mengembalikan kelompok bentuk itu', () {
      const size = Size(320, 260);
      var checked = 0;
      // Dari bentuk terakhir ke depan, sama seperti urutan hit-test: bentuk
      // yang digambar belakangan ada di atas.
      for (var i = bodyHeatmapPaths.length - 1; i >= 0 && checked < 3; i--) {
        final g = bodyHeatmapGroups[i];
        if (g < 0) continue;
        final enc = bodyHeatmapPaths[i];
        var sx = 0.0, sy = 0.0, n = 0, k = 0;
        while (k < enc.length) {
          final op = enc[k].toInt();
          if (op == 0 || op == 1) {
            sx += enc[k + 1];
            sy += enc[k + 2];
            n++;
            k += 3;
          } else if (op == 2) {
            k += 7;
          } else {
            k += 1;
          }
        }
        final p = Offset(sx / n * size.width, sy / n * size.height);
        // Bentuk cekung bisa punya titik rata-rata di luar dirinya; lewati.
        if (!bodyShapePath(i, size).contains(p)) continue;
        // Titik yang tertutup bentuk lain di atasnya (termasuk siluet) bukan
        // milik bentuk ini lagi — yang terlihat dan terketuk bentuk atasnya.
        var covered = false;
        for (var j = i + 1; j < bodyHeatmapPaths.length && !covered; j++) {
          covered = bodyShapePath(j, size).contains(p);
        }
        if (covered) continue;
        expect(muscleGroupAt(p, size), MuscleGroup.values[g], reason: 'bentuk #$i');
        checked++;
      }
      expect(checked, greaterThan(0));
    });

    test('pojok kosong dan siluet tidak mengenai otot', () {
      expect(muscleGroupAt(const Offset(1, 1), const Size(320, 260)), isNull);
    });

    test('potongan siluet yang digambar di atas otot menghalangi ketukan', () {
      const size = Size(320, 260);
      final paths = [for (var i = 0; i < bodyHeatmapPaths.length; i++) bodyShapePath(i, size)];
      var found = 0;
      for (var y = 1.0; y < size.height && found < 5; y += 2) {
        for (var x = 1.0; x < size.width && found < 5; x += 2) {
          final p = Offset(x, y);
          final top = paths.lastIndexWhere((s) => s.contains(p));
          if (top < 0 || bodyHeatmapGroups[top] >= 0) continue;
          final under = [
            for (var i = 0; i < top; i++)
              if (bodyHeatmapGroups[i] >= 0 && paths[i].contains(p)) i,
          ];
          if (under.isEmpty) continue;
          expect(muscleGroupAt(p, size), isNull, reason: 'siluet #$top menutupi otot #${under.first} di $p');
          found++;
        }
      }
      expect(found, greaterThan(0), reason: 'data peta seharusnya punya siluet di atas otot');
    });
  });

  group('BarSeries', () {
    Widget bars(int n, {EdgeInsets padding = const EdgeInsets.all(16)}) => MaterialApp(
          theme: buildGymTheme(),
          home: Scaffold(
            body: Padding(
              padding: padding,
              child: BarSeries(
                values: [for (var i = 0; i < n; i++) (i % 5 + 1).toDouble()],
                labels: [for (var i = n - 1; i >= 0; i--) i == 0 ? 'now' : '-${i}w'],
                leftLabel: 'a',
                midLabel: '',
                rightLabel: 'b',
              ),
            ),
          ),
        );

    testWidgets('52 batang di 310 dp: celah menyempit, tidak ada lebar negatif', (tester) async {
      _screen(tester, 310);
      // 246 px = lebar dalam kartu Dashboard di 310 dp (padding daftar 16 +
      // padding kartu 16, kiri-kanan). Celah tetap 5 px dulu menghabiskan
      // 255 px di sini dan lebar batangnya negatif.
      await tester.pumpWidget(bars(52, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(BarSeries)).width, 246);
    });

    testWidgets('pilihan ikut bergeser saat deret memanjang, lepas kalau tergeser keluar', (tester) async {
      _screen(tester, 360);
      await tester.pumpWidget(bars(12));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(BarSeries));
      // Batang paling kanan = "now".
      await tester.tapAt(Offset(rect.right - 2, rect.top + 20));
      await tester.pumpAndSettle();
      expect(find.text('now'), findsOneWidget);

      await tester.pumpWidget(bars(26));
      await tester.pumpAndSettle();
      expect(find.text('now'), findsOneWidget, reason: 'masih batang "now", bukan -14w');
      expect(find.text('-14w'), findsNothing);

      // Batang paling kiri di 26 minggu (-25w) tidak ada di 12 minggu.
      await tester.tapAt(Offset(rect.left + 2, rect.top + 20));
      await tester.pumpAndSettle();
      expect(find.text('-25w'), findsOneWidget);
      await tester.pumpWidget(bars(12));
      await tester.pumpAndSettle();
      expect(find.text('-25w'), findsNothing);
      expect(find.text('-11w'), findsNothing);
    });
  });

  testWidgets('BarSeries: ketuk batang → onTap(indeks) dan gelembung berisi nilainya', (tester) async {
    _screen(tester, 360);
    int? tapped;
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildGymTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: BarSeries(
            values: const [10, 20, 30],
            labels: const ['-2w', '-1w', 'now'],
            valueFormat: (v) => '${v.round()} sets',
            leftLabel: 'a',
            midLabel: '',
            rightLabel: 'b',
            onTap: (i) {
              calls++;
              tapped = i;
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(BarSeries));
    // Kolom tengah, jauh di atas batangnya: target sentuh adalah seluruh
    // kolom, bukan hanya batang.
    final middle = Offset(rect.left + rect.width / 2, rect.top + 20);
    await tester.tapAt(middle);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tapped, 1);
    expect(find.text('20 sets'), findsOneWidget);
    expect(find.text('-1w'), findsOneWidget);

    // Ketuk lagi batang yang sama → dilepas.
    await tester.tapAt(middle);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tapped, isNull);
    expect(find.text('20 sets'), findsNothing);
  });

  group('StatsScreen', () {
    late WorkoutStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      wideLayout.value = false;
      store = WorkoutStore();
      await store.load();
      await _seed(store);
    });
    tearDown(() => wideLayout.value = false);

    Future<void> pumpStats(WidgetTester tester) async {
      // Katalog dibaca dari aset lewat I/O sungguhan; sekali dimuat ia
      // di-cache, dan layar mendapatkannya lewat Future yang sudah selesai.
      await tester.runAsync(() => ExerciseCatalog.load());
      await tester.pumpWidget(_wrap(store, const Scaffold(body: StatsScreen())));
      await tester.pumpAndSettle();
    }

    testWidgets('360 dp: ketiga tab tanpa overflow, chip 90 hari mengubah legenda', (tester) async {
      _screen(tester, 360);
      await pumpStats(tester);
      expect(find.text('Last 30 days'), findsOneWidget);
      expect(find.byType(MuscleMap), findsOneWidget);

      await tester.tap(find.text('90 days'));
      await tester.pumpAndSettle();
      expect(find.text('Last 90 days'), findsOneWidget);
      expect(find.text('Last 30 days'), findsNothing);

      await tester.tap(find.text('Fatigue'));
      await tester.pumpAndSettle();
      expect(find.text('WEEKLY SET VOLUME'), findsOneWidget);

      await tester.tap(find.text('Strength'));
      await tester.pumpAndSettle();
      expect(find.text('ESTIMATED 1RM'), findsOneWidget);
      expect(find.byType(Sparkline), findsWidgets);
    });

    testWidgets('800 dp: kartu dua kolom tanpa overflow', (tester) async {
      _screen(tester, 800, height: 1000);
      await pumpStats(tester);
      // Dua kartu Balance berdampingan: peta otot dan radar berbagi baris.
      final map = tester.getRect(find.byType(MuscleMap));
      final radar = tester.getRect(find.byType(RadarChart));
      expect(radar.left, greaterThan(map.right));

      await tester.tap(find.text('Strength'));
      await tester.pumpAndSettle();
      expect(find.text('ESTIMATED 1RM'), findsOneWidget);
    });

    testWidgets('ketuk otot di peta menampilkan porsinya, ketuk lagi melepas', (tester) async {
      _screen(tester, 360);
      await pumpStats(tester);
      final map = find.byType(MuscleMap);
      final rect = tester.getRect(map);
      // Cari titik yang mengenai otot lewat fungsi yang sama dengan hit-test.
      final size = rect.size;
      Offset? hit;
      MuscleGroup? group;
      for (var y = 0.05; y < 1 && hit == null; y += 0.02) {
        for (var x = 0.05; x < 0.5 && hit == null; x += 0.02) {
          final p = Offset(x * size.width, y * size.height);
          final g = muscleGroupAt(p, size);
          if (g != null) {
            hit = p;
            group = g;
          }
        }
      }
      expect(hit, isNotNull);
      await tester.tapAt(rect.topLeft + hit!);
      await tester.pumpAndSettle();
      final label = muscleGroupLabel[group]!;
      expect(find.textContaining('$label · '), findsOneWidget);
      expect(tester.widget<MuscleMap>(map).highlight, group);

      await tester.tapAt(rect.topLeft + hit);
      await tester.pumpAndSettle();
      expect(find.textContaining('$label · '), findsNothing);
      expect(tester.widget<MuscleMap>(map).highlight, isNull);
    });

    testWidgets('teks 1,5× di 360 dp: ubin KPI tidak meluber', (tester) async {
      _screen(tester, 360);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpStats(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Working sets'), findsOneWidget);
    });

    testWidgets('ganti rentang tidak membangun ulang tab: radar yang sama melayang', (tester) async {
      _screen(tester, 360);
      await pumpStats(tester);
      final radar = tester.state(find.byType(RadarChart));
      await tester.tap(find.text('90 days'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(RadarChart)), same(radar));
    });

    testWidgets('e1RM: minggu sebelum sesi pertama bilang "—", sumbu = gelembung', (tester) async {
      _screen(tester, 360);
      await pumpStats(tester);
      await tester.tap(find.text('Strength'));
      await tester.pumpAndSettle();
      final chart = find.byType(BarSeries).first;
      Finder inChart(String s) => find.descendant(of: chart, matching: find.text(s));
      // Sumbu kiri menyebut minggu yang sama dengan batang paling kirinya.
      expect(inChart('-11w'), findsOneWidget);
      expect(inChart('12 wk ago'), findsNothing);
      final rect = tester.getRect(chart);
      await tester.tapAt(Offset(rect.left + 2, rect.top + 20));
      await tester.pumpAndSettle();
      expect(inChart('—'), findsOneWidget);
      expect(inChart('0 kg'), findsNothing);
      expect(inChart('-11w'), findsNWidgets(2));
    });

    testWidgets('selama Dashboard terbuka, keputusan kolom ditahan', (tester) async {
      _screen(tester, 360);
      await pumpStats(tester);
      bool stacked() => tester.getRect(find.byType(RadarChart)).top > tester.getRect(find.byType(MuscleMap)).bottom;
      expect(stacked(), isTrue);

      // Di web, Dashboard melebarkan seluruh aplikasi; layar Stats di
      // bawahnya melihat lebar itu tapi tetap satu kolom.
      wideLayout.value = true;
      _screen(tester, 800, height: 1000);
      await tester.pumpAndSettle();
      expect(stacked(), isTrue);

      wideLayout.value = false;
      await tester.pumpAndSettle();
      expect(stacked(), isFalse);
    });
  });

  group('DashboardScreen', () {
    late WorkoutStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = WorkoutStore();
      await store.load();
      await _seed(store);
    });

    testWidgets('1200 dp: tiga kolom tanpa overflow, chip 26 minggu memperluas tabel', (tester) async {
      _screen(tester, 1200, height: 900);
      await tester.runAsync(() => ExerciseCatalog.load());
      await tester.pumpWidget(_wrap(store, const DashboardScreen()));
      await tester.pumpAndSettle();
      expect(find.text('E1RM BY WEEK — LAST 12 WEEKS'), findsOneWidget);
      expect(find.byType(Sparkline), findsWidgets);
      expect(find.text('-11w'), findsWidgets);

      await tester.tap(find.text('26 wk'));
      await tester.pumpAndSettle();
      expect(find.text('E1RM BY WEEK — LAST 26 WEEKS'), findsOneWidget);
      expect(find.text('-25w'), findsWidgets);
    });

    testWidgets('360 dp: satu kolom tanpa overflow', (tester) async {
      _screen(tester, 360);
      await tester.runAsync(() => ExerciseCatalog.load());
      await tester.pumpWidget(_wrap(store, const DashboardScreen()));
      await tester.pumpAndSettle();
      expect(find.text('SESSIONS PER WEEK'), findsOneWidget);
    });

    testWidgets('310 dp, 52 minggu: grafik sesi diringkas per 4 minggu', (tester) async {
      _screen(tester, 310);
      await tester.runAsync(() => ExerciseCatalog.load());
      await tester.pumpWidget(_wrap(store, const DashboardScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('52 wk'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('SESSIONS PER 4 WEEKS'), findsOneWidget);

      final chart = find.byType(BarSeries).first;
      final rect = tester.getRect(chart);
      await tester.tapAt(Offset(rect.right - 2, rect.top + 20));
      await tester.pumpAndSettle();
      // Ketiga sesi seed ada di empat minggu terakhir.
      expect(find.descendant(of: chart, matching: find.text('3 sessions')), findsOneWidget);
      expect(find.descendant(of: chart, matching: find.text('-3w – now')), findsOneWidget);
    });

    testWidgets('buka-tutup di bawah pendengar wideLayout: tanpa assertion, penanda kembali', (tester) async {
      wideLayout.value = false;
      addTearDown(() => wideLayout.value = false);
      await tester.runAsync(() => ExerciseCatalog.load());
      // Tiruan pembungkus web di main.dart: pendengar di atas Navigator.
      await tester.pumpWidget(WorkoutScope(
        store: store,
        child: AppStrings(
          strings: const Strings(AppLanguage.english),
          child: MaterialApp(
            theme: buildGymTheme(),
            builder: (context, child) => ValueListenableBuilder<bool>(
              valueListenable: wideLayout,
              builder: (context, wide, _) => Center(child: SizedBox(width: wide ? 1100 : 480, child: child)),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardScreen())),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(wideLayout.value, isTrue);

      Navigator.of(tester.element(find.byType(DashboardScreen))).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(wideLayout.value, isFalse);
    });
  });

  test('trendOf dan carried', () {
    expect(trendOf([null, 80, null, 85]), 1);
    expect(trendOf([90, 85]), -1);
    expect(trendOf([85, 85.01]), 0);
    expect(trendOf([null, 85]), isNull);
    expect(carried([null, 80, null, 85]), [80, 80, 85]);
  });

  test('bucketSums: dikelompokkan dari kanan, kelompok terakhir berakhir di "sekarang"', () {
    expect(bucketSums([1, 2, 3, 4, 5, 6], 4), [3, 18]);
    expect(bucketSums(List.filled(52, 1), 4), List.filled(13, 4));
    expect(bucketSums([1, 2, 3], 1), [1, 2, 3]);
    expect(bucketSums(const [], 4), isEmpty);
  });

  test('weekLabels dan weekSpan', () {
    const t = Strings(AppLanguage.english);
    expect(t.weekLabels(3), ['-2w', '-1w', 'now']);
    expect(t.weekSpan(51, 48), '-51w – -48w');
    expect(t.weekSpan(3, 0), '-3w – now');
    expect(t.weekSpan(5, 5), '-5w');
  });
}
