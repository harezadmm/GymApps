/// Aksesibilitas v2.3 (NFR-11), dari audit anti-slop 001 temuan 4, 5, 9, 10:
/// target sentuh ≥ 44 dp, nama untuk tombol ikon-saja, dan huruf sistem 1,3×
/// yang tidak meluber di HP 360 dp.
///
/// Test skala huruf tidak memeriksa piksel satu per satu: RenderFlex yang
/// meluber melempar error di widget test, jadi `takeException()` yang null
/// sesudah layar ditata (dan digulir sampai bawah) sudah berarti layarnya
/// utuh. Dijalankan dalam dua bahasa karena terjemahan Indonesia sering lebih
/// panjang dari bahasa Inggrisnya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/program.dart';
import 'package:gymapps/features/history/history_screen.dart';
import 'package:gymapps/features/history/workout_edit_screen.dart';
import 'package:gymapps/features/home/home_screen.dart';
import 'package:gymapps/features/library/library_screen.dart';
import 'package:gymapps/features/profile/profile_screen.dart';
import 'package:gymapps/features/session/rest_screen.dart';
import 'package:gymapps/features/session/rest_timer.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:gymapps/features/workout/workout_screen.dart';
import 'package:gymapps/main.dart' show clampTextScale, maxTextScale;
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, Widget home, {AppLanguage lang = AppLanguage.english}) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: Strings(lang),
        child: MaterialApp(theme: buildGymTheme(), home: home),
      ),
    );

/// HP kecil yang umum: 360 × 780 dp.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Huruf sistem 1,3× — tepat di batas yang dijepit [clampTextScale], jadi
/// inilah huruf terbesar yang pernah dilihat layar mana pun.
void _bigText(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = maxTextScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Pump berjangka, bukan pumpAndSettle: animasi kedatangan dan timer sesi
/// tidak pernah "tenang".
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Gulir daftar utama sampai bawah lalu tata lagi: anak ListView yang di
/// luar layar belum pernah ditata, jadi luapannya baru ketahuan setelah
/// digulir. Daftar horizontal (chip filter) dilewati.
Future<void> _scrollThrough(WidgetTester tester) async {
  final list = find.byWidgetPredicate((w) => w is ScrollView && w.scrollDirection == Axis.vertical);
  if (list.evaluate().isEmpty) return;
  for (var i = 0; i < 3; i++) {
    await tester.drag(list.first, const Offset(0, -1200), warnIfMissed: false);
    await _settle(tester);
  }
}

/// Katalog dibaca dari aset lewat I/O sungguhan, yang tidak pernah selesai di
/// dalam zona waktu palsu widget test; dimuat sekali lewat `runAsync`.
Future<ExerciseCatalog> _catalog(WidgetTester tester) async => (await tester.runAsync(ExerciseCatalog.load))!;

Workout _sesi(String date, {required String routine, double w = 60}) => Workout(
      date: date,
      routine: routine,
      durationSeconds: 1800,
      entries: [
        WorkoutEntry(
          exerciseId: '0025',
          target: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.double_, reps: 10, repsMin: 6),
          sets: [SetRow(weight: w, reps: 8, done: true), SetRow(weight: w, reps: 7, done: true)],
        ),
      ],
    );

/// Program PPL, dua sesi hari ini (supaya "minggu ini" selalu terisi, hari
/// apa pun test ini dijalankan) dan satu sesi lampau untuk Riwayat.
Future<WorkoutStore> _storeWithData(WidgetTester tester) async {
  final store = WorkoutStore();
  await tester.runAsync(() async {
    await ExerciseCatalog.load();
    await store.load('a@x.com');
    await store.applyTemplate('ppl');
    final today = isoDate(DateTime.now());
    await store.addWorkout(_sesi(today, routine: 'Push'), routineId: 'ppl-0');
    await store.addWorkout(_sesi(today, routine: 'Pull', w: 40), routineId: 'ppl-1');
    await store.addWorkout(_sesi('2026-08-14', routine: 'Legs', w: 100), routineId: 'ppl-2');
  });
  return store;
}

SessionExercise _bench({bool expanded = true}) => SessionExercise(
      name: 'Barbell Bench Press',
      icon: Icons.fitness_center,
      config: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.double_, reps: 10, repsMin: 6, weight: 60),
      sets: const [SetRow(weight: 60, reps: 8), SetRow(weight: 60, reps: 8), SetRow(weight: 60, reps: 8)],
      // PREV terpanjang yang wajar: memudar di ujung kolom, bukan meluber.
      previous: const ['62.5 × 10', '62.5 × 10', '62.5 × 10'],
      expanded: expanded,
    );

SessionExercise _fly() => SessionExercise(
      name: 'Cable Fly',
      icon: Icons.fitness_center,
      config: const ExerciseConfig(exerciseId: 'fly', sets: 3, reps: 12, repsMin: 8, weight: 20, policy: ProgressionPolicy.double_),
      sets: const [SetRow(weight: 20, reps: 12), SetRow(weight: 20, reps: 12)],
      previous: const ['—', '—'],
      expanded: false,
    );

Widget _profile(AppLanguage lang) => Scaffold(
      body: ProfileScreen(language: lang, onLanguageChanged: (_) {}, onSignOut: () {}, email: 'a@x.com'),
    );

/// InkWell terdekat yang membungkus [inner] — kotak sentuh kontrol itu.
Finder _hitBox(Finder inner) => find.ancestor(of: inner, matching: find.byType(InkWell)).first;

/// InkWell di dalam [tooltip]: untuk tombol yang Tooltip-nya membungkus
/// InkWell-nya (bukan sebaliknya), seperti tombol library dan pensil di
/// kartu istirahat.
Finder _hitBoxIn(Finder tooltip) => find.descendant(of: tooltip, matching: find.byType(InkWell)).first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
    store = WorkoutStore();
    await store.load();
  });

  group('skala huruf', () {
    test('dijepit ke 1,3: 2,0 jadi 1,3 dan 1,0 tidak disentuh', () {
      final big = clampTextScale(const MediaQueryData(textScaler: TextScaler.linear(2)));
      expect(big.textScaler.scale(10), closeTo(13, 0.001));
      final normal = clampTextScale(const MediaQueryData(textScaler: TextScaler.linear(1)));
      expect(normal.textScaler.scale(10), 10);
      expect(maxTextScale, 1.3);
    });

    testWidgets('penjepitnya berlaku lewat MaterialApp.builder, bukan per Text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      double? seen;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(data: clampTextScale(MediaQuery.of(context)), child: child!),
        home: Builder(builder: (context) {
          seen = MediaQuery.textScalerOf(context).scale(10);
          return const SizedBox();
        }),
      ));
      expect(seen, closeTo(13, 0.001));
    });

    for (final lang in [AppLanguage.english, AppLanguage.indonesian]) {
      final tag = lang == AppLanguage.indonesian ? 'id' : 'en';

      testWidgets('[$tag] Home utuh di 360 dp dengan huruf 1,3×', (tester) async {
        _phone(tester);
        _bigText(tester);
        final s = await _storeWithData(tester);
        await tester.pumpWidget(_wrap(s, Scaffold(body: HomeScreen(email: 'a@x.com')), lang: lang));
        await _settle(tester);
        await _scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('[$tag] sesi berjalan utuh: kartu gerakan, istirahat penuh, kartu istirahat', (tester) async {
        _phone(tester);
        _bigText(tester);
        await tester.pumpWidget(_wrap(
          store,
          SessionScreen(routineName: 'Push', exercises: [_bench(), _fly()], initialElapsed: const Duration(minutes: 12)),
          lang: lang,
        ));
        await _settle(tester);
        expect(tester.takeException(), isNull);

        // Centang set pertama: istirahat mulai dan layar hitung mundur terbuka.
        await tester.tap(find.byIcon(Icons.circle_outlined).first);
        await _settle(tester);
        expect(find.byType(RestScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Kembali ke daftar: kartu istirahat dan kapsul di bilah atas tampil,
        // dengan huruf besar dan bahasa yang lebih panjang.
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await _settle(tester);
        expect(find.text('REST'), findsWidgets);
        await _scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('[$tag] Riwayat utuh di 360 dp dengan huruf 1,3×', (tester) async {
        _phone(tester);
        _bigText(tester);
        final s = await _storeWithData(tester);
        await tester.pumpWidget(_wrap(s, const Scaffold(body: HistoryScreen()), lang: lang));
        await _settle(tester);
        await _scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('[$tag] Profil utuh di 360 dp dengan huruf 1,3×', (tester) async {
        _phone(tester);
        _bigText(tester);
        final s = await _storeWithData(tester);
        await tester.pumpWidget(_wrap(s, _profile(lang), lang: lang));
        await _settle(tester);
        await _scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('[$tag] Library utuh di 360 dp dengan huruf 1,3×', (tester) async {
        _phone(tester);
        _bigText(tester);
        await _catalog(tester);
        await tester.pumpWidget(_wrap(store, const ExerciseLibraryScreen(), lang: lang));
        await tester.pump();
        await _settle(tester);
        await _scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('target sentuh ≥ 44 dp', () {
    testWidgets('SquareIconButton: lingkaran 42 di dalam kotak sentuh 44 yang benar-benar menerima ketukan', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: buildGymTheme(),
        home: Scaffold(body: Center(child: SquareIconButton(icon: Icons.add, tooltip: 'Add', onPressed: () => taps++))),
      ));
      final rect = tester.getRect(find.byType(SquareIconButton));
      expect(rect.width, greaterThanOrEqualTo(44));
      expect(rect.height, greaterThanOrEqualTo(44));
      // Sudut kotak — di luar lingkaran 42 dp — tetap mengenai tombolnya.
      await tester.tapAt(rect.topLeft + const Offset(1, 1));
      await tester.pump();
      expect(taps, 1);
      expect(find.byTooltip('Add'), findsOneWidget);
    });

    test('GymButton menolak tinggi di bawah 44 dp', () {
      expect(GymButton.minHeight, 44);
      expect(() => GymButton(label: 'x', height: 40), throwsA(isA<AssertionError>()));
    });

    testWidgets('sheet durasi istirahat: stepper 44 dp, preset ≥ 44 dp', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(
        store,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRestDurationSheet(
                context,
                current: const Duration(seconds: 90),
                exerciseName: 'Bench',
                routineName: 'Push',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      for (final icon in [Icons.remove, Icons.add]) {
        final buttons = find.byIcon(icon);
        expect(buttons, findsNWidgets(2), reason: 'menit dan detik');
        for (var i = 0; i < 2; i++) {
          final size = tester.getSize(_hitBox(buttons.at(i)));
          expect(size.width, greaterThanOrEqualTo(44));
          expect(size.height, greaterThanOrEqualTo(44));
        }
      }
      expect(tester.getSize(_hitBox(find.text('1:30'))).height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
    });

    testWidgets('layar sesi di 360 dp: FINISH, sel centang, tombol −/+ ≥ 44 dp dan tabel tetap muat', (tester) async {
      _phone(tester);
      final ex = _bench();
      await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [ex])));
      await _settle(tester);
      expect(tester.takeException(), isNull);

      expect(tester.getSize(find.widgetWithText(GymButton, 'FINISH')).height, greaterThanOrEqualTo(44));

      final check = tester.getRect(_hitBox(find.byIcon(Icons.circle_outlined).first));
      expect(check.width, greaterThanOrEqualTo(44));
      expect(check.height, greaterThanOrEqualTo(44));
      expect(check.right, lessThanOrEqualTo(360), reason: 'tabel harus tetap muat di HP 360 dp');

      final minus = tester.getSize(_hitBox(find.byIcon(Icons.remove).first));
      expect(minus.height, greaterThanOrEqualTo(44));
      expect(minus.width, greaterThanOrEqualTo(28));
      // Yang mengalah bukan kotak angkanya: "102.5" masih muat. Kotak
      // pertama adalah catatan sesi; kolom beban set pertama sesudahnya.
      expect(tester.getSize(find.byType(TextField).at(1)).width, greaterThanOrEqualTo(52));

      // Sudut kotak sentuh sel centang — jauh dari ikon 24 dp — tetap mencentang.
      await tester.tapAt(check.topLeft + const Offset(2, 2));
      await _settle(tester);
      expect(ex.sets.first.done, isTrue);
    });

    testWidgets('FilterChips: pil 36 dp di dalam kotak sentuh 44 dp yang menerima ketukan di tepinya', (tester) async {
      int? picked;
      await tester.pumpWidget(MaterialApp(
        theme: buildGymTheme(),
        home: Scaffold(body: FilterChips(labels: const ['All', 'Push'], index: 0, onChanged: (i) => picked = i)),
      ));
      final chip = _hitBox(find.text('Push'));
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(44));
      // Tepi atas kotak sentuh, di luar pil 36 dp.
      await tester.tapAt(tester.getRect(chip).topCenter + const Offset(0, 2));
      await tester.pump();
      expect(picked, 1);
    });

    testWidgets('AvatarCircle 40 dp di header punya kotak sentuh 44 dp', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildGymTheme(),
        home: Scaffold(body: Center(child: AvatarCircle(text: 'HZ', tooltip: 'Open profile', onTap: () {}))),
      ));
      final size = tester.getSize(find.byType(AvatarCircle));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('tombol ikon-saja punya nama', () {
    testWidgets('Workout: + rutinitas baru, tombol library, dan penanda "berikutnya"', (tester) async {
      _phone(tester);
      final s = await _storeWithData(tester);
      await tester.pumpWidget(_wrap(s, const Scaffold(body: WorkoutScreen())));
      await _settle(tester);
      expect(find.byTooltip('New routine'), findsOneWidget);
      expect(find.byTooltip('Exercise Library'), findsOneWidget);
      expect(tester.getSize(_hitBoxIn(find.byTooltip('Exercise Library'))).height, greaterThanOrEqualTo(44));

      await tester.tap(find.text('My Plan'));
      await _settle(tester);
      await _scrollThrough(tester);
      expect(find.byTooltip('Next up'), findsOneWidget);
      expect(find.byTooltip('Make next'), findsNWidgets(2));
      expect(tester.getSize(_hitBoxIn(find.byTooltip('Make next').first)).width, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
    });

    testWidgets('editor riwayat: centang dan ✕ tiap set bernama, dan tidak lagi 40 dp', (tester) async {
      _phone(tester);
      final catalog = await _catalog(tester);
      await tester.pumpWidget(_wrap(store, WorkoutEditScreen(workout: _sesi('2026-09-20', routine: 'Push'), catalog: catalog)));
      await _settle(tester);
      expect(find.byTooltip('Mark set not done'), findsNWidgets(2));
      expect(find.byTooltip('Remove set'), findsNWidgets(2));
      final close = find.ancestor(of: find.byTooltip('Remove set').first, matching: find.byType(IconButton)).first;
      expect(tester.getSize(close).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(close).width, greaterThanOrEqualTo(44));
    });

    testWidgets('sesi: −/+ beban punya label semantik, pensil di kartu istirahat punya tooltip', (tester) async {
      _phone(tester);
      // Dilepas di akhir badan test: pemeriksaan "handle masih hidup"
      // berjalan sebelum addTearDown, jadi tidak bisa dititipkan ke sana.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [_bench()])));
      await _settle(tester);
      expect(find.bySemanticsLabel('decrease weight'), findsWidgets);
      expect(find.bySemanticsLabel('increase weight'), findsWidgets);

      await tester.tap(find.byIcon(Icons.circle_outlined).first);
      await _settle(tester);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await _settle(tester);
      expect(find.byTooltip('Change duration'), findsOneWidget);
      final pencil = tester.getSize(_hitBoxIn(find.byTooltip('Change duration')));
      expect(pencil.width, greaterThanOrEqualTo(44));
      expect(pencil.height, greaterThanOrEqualTo(44));
      handle.dispose();
    });
  });
}
