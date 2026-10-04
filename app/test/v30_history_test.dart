/// Riwayat v3 (spec UI-V3 §7.5): header dengan tombol kaca, kartu Aktivitas
/// dengan "n sesi tahun ini", baris sesi 72 dp dengan HueTile + lencana set
/// kerja dan meta "Sab, 3 Okt · 30 mnt · 960 kg"; sesi bebas memakai ikon
/// alarm. Geser-hapus, URUNGKAN, dan sheet detail tetap ada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/gym_icons.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/features/history/history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, {Brightness brightness = Brightness.light}) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.indonesian),
        child: MaterialApp(
          theme: buildGymTheme(brightness: brightness),
          home: const Scaffold(body: HistoryScreen()),
        ),
      ),
    );

/// Dua set kerja tercentang (60 × 8 = 480 masing-masing → 960 kg), satu belum.
Workout _sesi(String date, {String? routine, int dur = 1800}) => Workout(
      date: date,
      routine: routine,
      durationSeconds: dur,
      entries: [
        WorkoutEntry(
          exerciseId: '0025',
          target: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, reps: 8, weight: 60),
          sets: const [
            SetRow(weight: 60, reps: 8, done: true),
            SetRow(weight: 60, reps: 8, done: true),
            SetRow(weight: 60, reps: 8),
          ],
        ),
      ],
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

Finder _row(String title) => find.widgetWithText(Dismissible, title);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutStore store;
  late String pushDate;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
    store = WorkoutStore();
    await store.load();
    await store.applyTemplate('ppl');
    final push = store.routines.first;
    final now = DateTime.now();
    // Dua sesi tahun ini: Push kemarin, sesi bebas dua hari lalu.
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    pushDate = iso(now.subtract(const Duration(days: 1)));
    await store.addWorkout(_sesi(iso(now.subtract(const Duration(days: 2))), dur: 2700));
    await store.addWorkout(_sesi(pushDate, routine: push.name), routineId: push.id);
  });

  for (final brightness in Brightness.values) {
    testWidgets('baris sesi v3 (${brightness.name}): HueTile + lencana set, meta mnt, header kaca', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(store, brightness: brightness));
      await _settle(tester);
      expect(tester.takeException(), isNull);

      // Header: judul + tombol kaca plus.
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.widgetWithIcon(GlassIconButton, GymIcons.plus), findsOneWidget);

      // Kartu aktivitas.
      expect(find.text('Aktivitas'), findsOneWidget);
      expect(find.text('2 sesi tahun ini'), findsOneWidget);

      // Dua baris, masing-masing dengan tile hue dan lencana "2" set kerja.
      expect(find.byType(Dismissible), findsNWidgets(2));
      final push = _row('Push');
      expect(push, findsOneWidget);
      expect(find.descendant(of: push, matching: find.byType(HueTile)), findsOneWidget);
      expect(find.descendant(of: push, matching: find.byKey(ValueKey('session-badge-$pushDate'))), findsOneWidget);
      expect(find.descendant(of: push, matching: find.text('2')), findsOneWidget);
      expect(find.descendant(of: push, matching: find.textContaining('30 mnt')), findsOneWidget);
      expect(find.descendant(of: push, matching: find.textContaining('960 kg')), findsOneWidget);
      expect(find.descendant(of: push, matching: find.byIcon(GymIcons.dumbbell)), findsOneWidget);

      // Sesi bebas: ikon alarm, durasi 45 menit.
      final free = _row('Bebas');
      expect(free, findsOneWidget);
      expect(find.descendant(of: free, matching: find.byIcon(GymIcons.alarm)), findsOneWidget);
      expect(find.descendant(of: free, matching: find.textContaining('45 mnt')), findsOneWidget);

      // Tinggi baris 72 dp.
      final rowBox = tester.getSize(find.descendant(of: push, matching: find.byType(InkWell)).first);
      expect(rowBox.height, closeTo(72, 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ketuk baris → sheet detail dengan tombol kaca: Lanjutkan sesi (primer) dan Hapus (danger)',
      (tester) async {
    _phone(tester);
    await tester.runAsync(ExerciseCatalog.load);
    await tester.pumpWidget(_wrap(store));
    await _settle(tester);
    await tester.tap(find.descendant(of: _row('Push'), matching: find.text('Push')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _settle(tester);

    final resume = find.widgetWithText(GymButton, 'Lanjutkan sesi');
    expect(resume, findsOneWidget);
    expect(tester.widget<GymButton>(resume).tone, GymButtonTone.primary);
    final del = find.widgetWithText(GymButton, 'Hapus');
    await tester.scrollUntilVisible(del, 200, scrollable: find.byType(Scrollable).last);
    expect(tester.widget<GymButton>(del).tone, GymButtonTone.danger);
    expect(find.widgetWithText(GymButton, 'Edit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
