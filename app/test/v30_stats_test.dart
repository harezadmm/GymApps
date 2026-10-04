/// Statistik v3 (spec UI-V3 §7.6): KPI dengan HueTile, tiga tab bergaya
/// kartu judul 15/700, Kelelahan dengan garis rata-rata dan bilah 110×8,
/// Kekuatan dengan sparkline per gerakan, kartu berat badan ringkas
/// (sparkline, bukan batang) dengan tombol Catat tinted, dan Buka dashboard
/// sebagai tombol kaca bening.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/charts.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/features/stats/bodyweight_card.dart';
import 'package:gymapps/features/stats/stats_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, {Brightness brightness = Brightness.light}) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.indonesian),
        child: MaterialApp(
          theme: buildGymTheme(brightness: brightness),
          home: const Scaffold(body: StatsScreen()),
        ),
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Workout _w(String date, String id, double weight, List<int> reps) => Workout(date: date, entries: [
      WorkoutEntry(exerciseId: id, sets: [for (final r in reps) SetRow(weight: weight, reps: r, done: true)]),
    ]);

String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> _seed(WorkoutStore store) async {
  final today = DateTime.now();
  await store.addWorkout(_w(_iso(today.subtract(const Duration(days: 12))), '0025', 60, [8, 8, 8]));
  await store.addWorkout(_w(_iso(today.subtract(const Duration(days: 5))), '0043', 80, [5, 5, 5]));
  await store.addWorkout(_w(_iso(today.subtract(const Duration(days: 1))), '0025', 62.5, [8, 8, 7]));
  await store.logBodyweight(_iso(today.subtract(const Duration(days: 30))), 73.0);
  await store.logBodyweight(_iso(today), 72.4);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
    store = WorkoutStore();
    await store.load();
    await _seed(store);
  });

  Future<void> pump(WidgetTester tester, {Brightness brightness = Brightness.light}) async {
    await tester.runAsync(ExerciseCatalog.load);
    await tester.pumpWidget(_wrap(store, brightness: brightness));
    await tester.pumpAndSettle();
  }

  Finder scroll() => find.byType(Scrollable).first;

  for (final brightness in Brightness.values) {
    testWidgets('Keseimbangan (${brightness.name}): KPI HueTile ×3, judul kartu, legenda, radar', (tester) async {
      _phone(tester);
      await pump(tester, brightness: brightness);
      expect(tester.takeException(), isNull);

      expect(find.text('Statistik'), findsOneWidget);
      expect(find.byType(HueTile), findsNWidgets(3), reason: 'tiga ubin KPI');
      expect(find.text('Set kerja'), findsOneWidget);
      expect(find.byType(SegmentedTabs), findsOneWidget);

      expect(find.text('Peta panas otot'), findsOneWidget);
      expect(find.text('porsi volume'), findsOneWidget);
      expect(find.byType(MuscleMap), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Tinggi'), 150, scrollable: scroll());
      expect(find.text('Rendah'), findsOneWidget);
      expect(find.text('Tinggi'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Region tubuh yang dilatih'), 150, scrollable: scroll());
      expect(find.byType(RadarChart), findsOneWidget);
      expect(find.text('Periode sebelumnya'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Kelelahan: subjudul 8 minggu, garis rata-rata, bilah hari 110×8', (tester) async {
    _phone(tester);
    await pump(tester);
    await tester.tap(find.text('Kelelahan'));
    await tester.pumpAndSettle();

    expect(find.text('Volume set mingguan'), findsOneWidget);
    expect(find.text('Set kerja per minggu, 8 minggu'), findsOneWidget);
    final bars = tester.widget<BarSeries>(find.byType(BarSeries).first);
    expect(bars.average, isNotNull, reason: 'garis rata-rata set per minggu');
    expect(bars.averageFormat!(51), 'rata-rata 51 set');

    await tester.scrollUntilVisible(find.text('Hari sejak terakhir dilatih'), 150, scrollable: scroll());
    final bar = find.byKey(const ValueKey('days-bar-0'));
    expect(bar, findsOneWidget);
    expect(tester.getSize(bar), const Size(110, 8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kekuatan: 1RM, sparkline per gerakan, berat badan ringkas, Buka dashboard', (tester) async {
    _phone(tester);
    await pump(tester);
    await tester.tap(find.text('Kekuatan'));
    await tester.pumpAndSettle();

    expect(find.text('Perkiraan 1RM'), findsOneWidget);
    expect(find.byType(ChangePill), findsWidgets, reason: 'pil persen 12 mgg dan pil delta per gerakan');
    await tester.scrollUntilVisible(find.text('Kekuatan per gerakan'), 150, scrollable: scroll());
    expect(find.text('12 mgg terakhir'), findsOneWidget);
    expect(find.byType(Sparkline), findsWidgets);
    expect(find.textContaining('1RM '), findsWidgets, reason: 'sub baris "1RM 109 kg"');

    await tester.scrollUntilVisible(find.text('Berat badan'), 150, scrollable: scroll());
    final bw = find.byType(BodyweightCard);
    expect(find.descendant(of: bw, matching: find.text('72.4 kg')), findsOneWidget);
    expect(find.descendant(of: bw, matching: find.textContaining('/ 30 hari')), findsOneWidget);
    expect(find.descendant(of: bw, matching: find.byType(Sparkline)), findsOneWidget);
    expect(find.descendant(of: bw, matching: find.byType(BarSeries)), findsNothing);
    final log = find.widgetWithText(GymButton, 'Catat');
    expect(log, findsOneWidget);
    expect(tester.widget<GymButton>(log).tone, GymButtonTone.primary);
    expect(tester.widget<GymButton>(log).height, 34);

    await tester.scrollUntilVisible(find.text('Buka dashboard'), 150, scrollable: scroll());
    final dash = find.widgetWithText(GymButton, 'Buka dashboard');
    expect(tester.widget<GymButton>(dash).tone, GymButtonTone.neutral);
    expect(tester.takeException(), isNull);
  });
}
