/// Layar sesi v3: header kaca dengan waktu besar, pil istirahat mengapung di
/// bawah (−15 / +15 / lewati), aksi gerakan sebagai tombol kaca, dan baris set
/// yang menandai baris aktif dan baris selesai.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/gym_icons.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/features/session/rest_pill.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.indonesian),
        child: MaterialApp(theme: buildGymTheme(brightness: Brightness.light), home: home),
      ),
    );

SessionExercise _bench({String name = 'Barbell Bench Press', bool expanded = true}) => SessionExercise(
      name: name,
      icon: Icons.fitness_center,
      config: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.double_, reps: 10, repsMin: 6),
      sets: const [SetRow(weight: 60, reps: 8), SetRow(weight: 60, reps: 8)],
      previous: const ['60 × 8', '60 × 8'],
      expanded: expanded,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = WorkoutStore();
    await store.load();
  });

  testWidgets('header: Selesai kaca berwarna, waktu berjalan 30/800, tanpa kapsul istirahat', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [_bench()])));
    await tester.pump();
    final finish = find.widgetWithText(GymButton, 'Selesai');
    expect(finish, findsOneWidget);
    expect(tester.widget<GlassSurface>(find.descendant(of: finish, matching: find.byType(GlassSurface))).tone,
        GlassTone.tinted);
    final elapsed = tester.widget<Text>(find.byKey(const ValueKey('session-elapsed')));
    expect(elapsed.style!.fontSize, 30);
    expect(find.byTooltip('Lewati istirahat'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('centang set → pil istirahat di bawah dengan −15/+15/lewati; daftar diberi ruang', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [_bench()])));
    await tester.pump();
    await tester.tap(find.byIcon(GymIcons.circle).first);
    await tester.pump(const Duration(milliseconds: 500));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump(const Duration(milliseconds: 500));

    final pill = find.byKey(const ValueKey('rest-pill'));
    expect(pill, findsOneWidget);
    expect(find.byType(RestPill), findsOneWidget);
    expect(find.text('−15'), findsOneWidget);
    expect(find.text('+15'), findsOneWidget);
    final rect = tester.getRect(pill);
    expect(rect.height, 64);
    expect(rect.bottom, lessThanOrEqualTo(780));
    final list = tester.widget<ListView>(find.byType(ListView));
    expect((list.padding as EdgeInsets).bottom, greaterThanOrEqualTo(90));
    expect(tester.getRect(find.byTooltip('Lewati istirahat').first).height, greaterThanOrEqualTo(44));

    await tester.tap(find.byKey(const ValueKey('rest-skip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RestPill), findsNothing);
    expect((tester.widget<ListView>(find.byType(ListView)).padding as EdgeInsets).bottom, lessThan(90));
    expect(tester.takeException(), isNull);
  });

  testWidgets('aksi gerakan: Riwayat gerakan & Superset sebagai tombol kaca; superset bisa dinyalakan', (tester) async {
    _phone(tester);
    final a = _bench();
    final b = _bench(name: 'Incline Press', expanded: false);
    await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [a, b])));
    await tester.pump();
    expect(find.text('Riwayat gerakan'), findsOneWidget);
    expect(find.text('Superset'), findsOneWidget);
    await tester.tap(find.text('Superset'));
    await tester.pump();
    expect(a.config.superset, isTrue);
    expect(find.text('Akhiri superset'), findsOneWidget);
  });

  testWidgets('baris set: yang aktif bergaris, yang selesai berlatar doneBg', (tester) async {
    _phone(tester);
    final ex = _bench();
    await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [ex])));
    await tester.pump();
    final c = GymColors.light;
    BoxDecoration cell(int i) =>
        tester.widget<Container>(find.byKey(ValueKey('kg-cell-${ex.name}-$i'))).decoration as BoxDecoration;
    expect(cell(0).border, isNotNull, reason: 'baris pertama aktif');
    expect(cell(1).border, isNull);

    await tester.tap(find.byIcon(GymIcons.circle).first);
    await tester.pump(const Duration(milliseconds: 500));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump(const Duration(milliseconds: 500));

    final row0 = tester.widget<AnimatedContainer>(find.byKey(ValueKey('set-row-${ex.name}-0')));
    expect((row0.decoration as BoxDecoration).color, c.doneBg);
    expect(cell(1).border, isNotNull, reason: 'baris kedua jadi aktif');
  });
}
