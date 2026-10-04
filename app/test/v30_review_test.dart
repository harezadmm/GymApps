/// Perbaikan dari review branch v3 (rilis 3.0.1): subjudul lembar Mulai di
/// hari libur, kontras saklar/gelembung/angka rekor/tombol danger, baris
/// Riwayat pada font besar, sasaran sentuh ≥ 44 dp, penjaga rutinitas kosong
/// dari lembar Mulai, meta "hari ini", cincin set kerja hanya sesi program,
/// tombol Dashboard saat kosong, avatar tanpa email, ikon pil status.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/charts.dart';
import 'package:gymapps/domain/program.dart';
import 'package:gymapps/core/gym_icons.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/routine_sync.dart';
import 'package:gymapps/features/history/history_screen.dart';
import 'package:gymapps/features/home/home_cards.dart';
import 'package:gymapps/features/home/home_screen.dart';
import 'package:gymapps/features/profile/profile_screen.dart';
import 'package:gymapps/features/session/finish_screen.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:gymapps/features/session/start_session_sheet.dart';
import 'package:gymapps/features/stats/stats_screen.dart';
import 'package:gymapps/features/workout/program_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _t = Strings(AppLanguage.indonesian);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _wrap(WorkoutStore store, Widget home, {Brightness brightness = Brightness.light}) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: _t,
        child: MaterialApp(theme: buildGymTheme(brightness: brightness), home: home),
      ),
    );

/// [n] set kerja tercentang 60 × 8.
Workout _sesi(String date, {String? routine, int n = 3, int dur = 1800}) => Workout(
      date: date,
      routine: routine,
      durationSeconds: dur,
      entries: [
        WorkoutEntry(
          exerciseId: '0025',
          target: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, reps: 8, weight: 60),
          sets: [for (var i = 0; i < n; i++) const SetRow(weight: 60, reps: 8, done: true)],
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

Finder _scroll() => find.byType(Scrollable).first;

/// Tombol yang membuka lembar Mulai sesi dari sebuah layar induk.
Widget _startHost() => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(onPressed: () => showStartSessionSheet(context), child: const Text('Go')),
        ),
      ),
    );

SessionExercise _ex(String id, String name, double w) => SessionExercise(
      name: name,
      icon: Icons.fitness_center,
      config: ExerciseConfig(exerciseId: id, policy: ProgressionPolicy.linear, sets: 2, reps: 8, weight: w),
      sets: [SetRow(weight: w, reps: 8, done: true), SetRow(weight: w, reps: 8, done: true)],
      previous: const ['—', '—'],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
    store = WorkoutStore();
    await store.load('a@x.com');
  });

  group('lembar Mulai sesi', () {
    testWidgets('hari tetap di hari libur: subjudul menyebut hari latihan berikutnya, bukan "hari ini"',
        (tester) async {
      _phone(tester);
      await tester.runAsync(() => ExerciseCatalog.load());
      await store.applyTemplate('ppl');
      final p = store.program!;
      final now = DateTime.now();
      // Satu-satunya hari latihan = besok, jadi hari ini pasti libur.
      final tomorrow = now.weekday % 7 + 1;
      await store.updateProgram(Program(
        name: p.name,
        templateId: p.templateId,
        mode: ProgramMode.weekday,
        order: p.order,
        cursor: p.cursor,
        days: [tomorrow],
      ));
      await tester.pumpWidget(_wrap(store, _startHost()));
      await tester.tap(find.text('Go'));
      await _settle(tester);
      expect(find.textContaining('dijadwalkan hari ini'), findsNothing);
      expect(find.text(_t.nextTrainingDay(_t.weekdayLong(tomorrow))), findsOneWidget);
    });

    testWidgets('rutinitas kosong → petunjuk dan editor, bukan sesi kosong', (tester) async {
      _phone(tester);
      await tester.runAsync(() => ExerciseCatalog.load());
      await store.applyTemplate('ppl');
      await store.saveRoutine(const Routine(id: 'kosong', name: 'Kosong', exercises: []));
      await tester.pumpWidget(_wrap(store, _startHost()));
      await tester.tap(find.text('Go'));
      await _settle(tester);
      await tester.scrollUntilVisible(find.text('Kosong'), 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Kosong'));
      await _settle(tester);
      expect(find.byType(SessionScreen), findsNothing);
      expect(find.text(_t.emptyRoutineHint), findsOneWidget);
    });

    testWidgets('tombol ⋯ di baris rutinitas punya sasaran sentuh 44 dp', (tester) async {
      _phone(tester);
      await tester.runAsync(() => ExerciseCatalog.load());
      await store.applyTemplate('ppl');
      await tester.pumpWidget(_wrap(store, _startHost()));
      await tester.tap(find.text('Go'));
      await _settle(tester);
      final more = find.byTooltip(_t.routineActions).first;
      final size = tester.getSize(more);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('kontras', () {
    test('saklar OFF di tema terang memakai thumb text2, ON tetap putih', () {
      final theme = buildGymTheme(brightness: Brightness.light);
      final c = theme.extension<GymColors>()!;
      final thumb = theme.switchTheme.thumbColor!;
      expect(thumb.resolve({}), c.text2);
      expect(thumb.resolve({WidgetState.selected}), Colors.white);
      expect(_contrast(c.text2, c.surface2), greaterThanOrEqualTo(3));
    });

    for (final brightness in Brightness.values) {
      testWidgets('gelembung BarSeries berlatar accentFill (${brightness.name})', (tester) async {
        await tester.pumpWidget(_wrap(
          store,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: BarSeries(
                values: const [10, 20, 30],
                labels: const ['a', 'b', 'c'],
                leftLabel: 'a',
                midLabel: 'b',
                rightLabel: 'c',
                animate: false,
              ),
            ),
          ),
          brightness: brightness,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        final c = Theme.of(tester.element(find.byType(BarSeries))).extension<GymColors>()!;
        expect(_contrast(Colors.white, c.accentFill), greaterThanOrEqualTo(4.5));
        final bubble = find.descendant(
          of: find.byType(BarSeries),
          matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == c.accentFill),
        );
        expect(bubble, findsOneWidget);
      });
    }

    testWidgets('angka "Rekor baru" di ringkasan tidak diwarnai oranye', (tester) async {
      _phone(tester);
      await tester.runAsync(() => ExerciseCatalog.load());
      await tester.pumpWidget(_wrap(
        store,
        FinishScreen(
          routineName: 'Push',
          exercises: [_ex('0025', 'Barbell Bench Press', 60), _ex('0030', 'Dumbbell Fly', 20)],
          history: const [],
          elapsed: const Duration(minutes: 42, seconds: 10),
          dateLabel: 'Min 4 Okt · 18.40',
        ),
      ));
      await _settle(tester);
      final c = Theme.of(tester.element(find.byType(FinishScreen))).extension<GymColors>()!;
      final warmNumbers = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.style?.fontSize == 19 && t.style?.color == c.warm);
      expect(warmNumbers, isEmpty, reason: 'angka 19/800 oranye di kartu putih hanya 2,35:1');
    });

    testWidgets('label tombol danger di tema terang ≥ 4,5:1 di atas surface', (tester) async {
      await tester.pumpWidget(_wrap(
        store,
        Scaffold(body: Center(child: GymButton(label: 'Hapus', tone: GymButtonTone.danger, height: 44, onPressed: () {}))),
      ));
      await tester.pump();
      final c = Theme.of(tester.element(find.byType(GymButton))).extension<GymColors>()!;
      final label = tester.widget<Text>(find.text('Hapus'));
      expect(_contrast(label.style!.color!, c.surface), greaterThanOrEqualTo(4.5));
    });

    testWidgets('ikon pil status tidak putih di atas latar redup', (tester) async {
      _phone(tester);
      await tester.runAsync(() => ExerciseCatalog.load());
      await store.applyTemplate('ppl');
      await tester.pumpWidget(_wrap(store, Scaffold(body: HomeScreen(email: 'a@x.com', onOpenProfile: () {}))));
      await _settle(tester);
      final pills = find.byType(StatusPill);
      expect(pills, findsNWidgets(2));
      for (final pill in pills.evaluate()) {
        final icon = tester.widget<Icon>(find.descendant(of: find.byWidget(pill.widget), matching: find.byType(Icon)).first);
        expect(icon.color, isNot(Colors.white));
      }
    });
  });

  group('sasaran sentuh', () {
    testWidgets('GymButton 34 dp tetap punya area ketuk 44 dp', (tester) async {
      await tester.pumpWidget(_wrap(
        store,
        Scaffold(body: Center(child: GymButton(label: 'Catat', height: 34, expand: false, onPressed: () {}))),
      ));
      await tester.pump();
      expect(tester.getSize(find.byType(GymButton)).height, greaterThanOrEqualTo(44));
    });

    testWidgets('stepper istirahat minimum di Program: tombol ≥ 40×36', (tester) async {
      _phone(tester);
      await tester.runAsync(() => ExerciseCatalog.load());
      await store.applyTemplate('ppl');
      await tester.pumpWidget(_wrap(store, const Scaffold(body: ProgramScreen())));
      await _settle(tester);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('rest-plus')), 200, scrollable: _scroll());
      final size = tester.getSize(find.byKey(const ValueKey('rest-plus')));
      expect(size.width, greaterThanOrEqualTo(40));
      expect(size.height, greaterThanOrEqualTo(36));
    });

    testWidgets('titik aksen di Profil: area ketuk ≥ 32×44', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(
        store,
        Scaffold(
          body: ProfileScreen(
            language: AppLanguage.indonesian,
            onLanguageChanged: (_) {},
            onSignOut: () {},
            onAccentChanged: (_) {},
            email: 'a@x.com',
          ),
        ),
      ));
      await _settle(tester);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('accent-dot-0')), 200, scrollable: _scroll());
      final hit = find.ancestor(of: find.byKey(const ValueKey('accent-dot-0')), matching: find.byType(GestureDetector)).first;
      final size = tester.getSize(hit);
      expect(size.width, greaterThanOrEqualTo(32));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('tautan Batalkan di banner ringkasan setinggi ≥ 44', (tester) async {
      _phone(tester);
      await tester.runAsync(() => ExerciseCatalog.load());
      const routine = Routine(id: 'r1', name: 'Push', exercises: [
        ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, sets: 3, reps: 8, weight: 60),
      ]);
      await store.saveRoutine(routine);
      await tester.pumpWidget(_wrap(
        store,
        FinishScreen(
          routineName: 'Push',
          exercises: [_ex('0025', 'Barbell Bench Press', 60), _ex('0030', 'Dumbbell Fly', 20)],
          history: const [],
          elapsed: const Duration(minutes: 42),
          dateLabel: 'Min 4 Okt',
          originalRoutine: routine,
          diff: diffRoutine(routine, [('0025', 2), ('0030', 2)]),
          routineUpdated: true,
        ),
      ));
      await _settle(tester);
      await tester.scrollUntilVisible(find.text('Batalkan'), 200, scrollable: _scroll());
      final link = find.ancestor(of: find.text('Batalkan'), matching: find.byType(InkWell)).first;
      expect(tester.getSize(link).height, greaterThanOrEqualTo(44));
    });
  });

  group('Riwayat', () {
    testWidgets('baris sesi pada font 1,5× tidak meluber', (tester) async {
      _phone(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await store.applyTemplate('ppl');
      final today = isoDate(DateTime.now());
      await store.addWorkout(_sesi(today, routine: 'Push'), routineId: 'ppl-0');
      await store.addWorkout(_sesi(today, n: 5));
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(Dismissible), findsNWidgets(2));
      final row = find.descendant(of: find.byType(Dismissible).first, matching: find.byType(InkWell)).first;
      expect(tester.getSize(row).height, greaterThanOrEqualTo(72));
    });
  });

  group('Beranda', () {
    testWidgets('meta sesi berikutnya: dilatih hari ini → "hari ini", bukan "0 hari lalu"', (tester) async {
      _phone(tester);
      await tester.runAsync(() => ExerciseCatalog.load());
      await store.applyTemplate('ppl');
      final p = store.program!;
      // Satu rutinitas saja di rotasi, supaya sesi berikutnya = yang baru dilatih.
      await store.updateProgram(Program(name: p.name, templateId: p.templateId, order: ['ppl-0']));
      await store.addWorkout(_sesi(isoDate(DateTime.now()), routine: 'Push'), routineId: 'ppl-0');
      await tester.pumpWidget(_wrap(store, Scaffold(body: HomeScreen(email: 'a@x.com', onOpenProfile: () {}))));
      await _settle(tester);
      final card = tester.widget<NextSessionCard>(find.byType(NextSessionCard));
      expect(card.meta, contains('hari ini'));
      expect(card.meta, isNot(contains('0 hari')));
    });

    testWidgets('cincin set kerja hanya menghitung sesi program minggu ini', (tester) async {
      _phone(tester);
      await tester.runAsync(() => ExerciseCatalog.load());
      await store.applyTemplate('ppl');
      final today = isoDate(DateTime.now());
      await store.addWorkout(_sesi(today, routine: 'Push', n: 3), routineId: 'ppl-0');
      await store.addWorkout(_sesi(today, n: 5));
      await tester.pumpWidget(_wrap(store, Scaffold(body: HomeScreen(email: 'a@x.com', onOpenProfile: () {}))));
      await _settle(tester);
      final rings = tester.widget<RingsCard>(find.byType(RingsCard));
      expect(rings.setsDone, 3, reason: 'sesi bebas (5 set) bukan bagian rencana program');
    });

    testWidgets('avatar tetap tampil tanpa email selama ada tujuan Profil', (tester) async {
      _phone(tester);
      await tester.runAsync(() => ExerciseCatalog.load());
      await tester.pumpWidget(_wrap(store, Scaffold(body: HomeScreen(onOpenProfile: () {}))));
      await _settle(tester);
      expect(find.byType(AvatarCircle), findsOneWidget);
    });
  });

  group('Statistik', () {
    testWidgets('tanpa angkatan tercatat, tombol Buka dashboard tetap ada', (tester) async {
      _phone(tester);
      await tester.runAsync(() => ExerciseCatalog.load());
      await tester.pumpWidget(_wrap(store, const Scaffold(body: StatsScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kekuatan'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Buka dashboard'), 200, scrollable: _scroll());
      expect(find.widgetWithText(GymButton, 'Buka dashboard'), findsOneWidget);
      expect(find.byIcon(GymIcons.chart), findsWidgets);
    });
  });
}
