/// Penjaga Home v2.2: blok statistik yang bisa diketuk, bilah progres minggu,
/// dan sheet per hari dari strip minggu.
///
/// Semua dijalankan di HP 360 dp karena tiga blok statistik sejajar plus
/// kolom "x dari y sesi" adalah tempat luapan paling gampang lolos — luapan
/// RenderFlex di test langsung gagal, jadi test ini sekaligus penjaga tata
/// letaknya.
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
import 'package:gymapps/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        // Scaffold seperti di aplikasi asli: Home duduk di dalam Scaffold
        // milik HomeShell, dan snackbar sinkron butuh ScaffoldMessenger.
        child: MaterialApp(theme: buildGymTheme(), home: Scaffold(body: home)),
      ),
    );

/// HP kecil yang umum: 360 × 780 dp.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Workout _sesi(String tanggal, {required String rutinitas, double berat = 60}) => Workout(
      date: tanggal,
      routine: rutinitas,
      entries: [
        WorkoutEntry(exerciseId: '0025', sets: [
          SetRow(weight: berat, reps: 8, done: true),
          SetRow(weight: berat, reps: 8, done: true),
        ]),
      ],
    );

/// Program PPL plus dua sesi hari ini. Dua-duanya hari ini supaya "minggu
/// ini" selalu memuat keduanya, hari apa pun test ini dijalankan — kemarin
/// bisa jadi minggu lalu kalau hari ini Senin.
Future<WorkoutStore> _storeWithWeek(WidgetTester tester) async {
  final store = WorkoutStore();
  await tester.runAsync(() async {
    await ExerciseCatalog.load();
    await store.load('a@x.com');
    await store.applyTemplate('ppl');
    final today = isoDate(DateTime.now());
    await store.addWorkout(_sesi(today, rutinitas: 'Push'), routineId: 'ppl-0');
    await store.addWorkout(_sesi(today, rutinitas: 'Pull', berat: 40), routineId: 'ppl-1');
  });
  return store;
}

Finder get _scrollable => find.byType(Scrollable).first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
  });

  testWidgets('StatBlock menampilkan valueWidget menggantikan teks nilai', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildGymTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 120,
            child: StatBlock(
              label: 'Volume',
              value: 'TEKS-LAMA',
              color: GymColors.dark.hues.orange,
              valueWidget: const Text('WIDGET'),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('WIDGET'), findsOneWidget);
    expect(find.text('TEKS-LAMA'), findsNothing);
  });

  testWidgets('Home dengan program dan dua sesi minggu ini muat di 360 dp dan menampilkan "2 of 3 sessions"',
      (tester) async {
    _phone(tester);
    final store = await _storeWithWeek(tester);
    await tester.pumpWidget(_wrap(store, const HomeScreen()));
    await tester.pumpAndSettle();

    // PPL = tiga rutinitas per putaran; dua sesi sudah tercatat.
    expect(find.text('2 of 3 sessions'), findsOneWidget);

    // Gulir sampai blok statistik ikut dibangun dan diukur — ListView malas,
    // dan luapan di bawah lipatan tidak akan ketahuan tanpa ini.
    await tester.scrollUntilVisible(find.text('Volume 7d'), 200, scrollable: _scrollable);
    await tester.pumpAndSettle();
    expect(find.text('Volume 7d'), findsOneWidget);
    expect(find.text('e1RM up'), findsOneWidget);
    expect(find.text('Since last'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ketuk kotak hari yang punya sesi: sheet memuat nama rutinitasnya dan membuka Riwayat',
      (tester) async {
    _phone(tester);
    final store = await _storeWithWeek(tester);
    int? opened;
    await tester.pumpWidget(_wrap(store, HomeScreen(onOpenTab: (i) => opened = i)));
    await tester.pumpAndSettle();

    final cell = find.byKey(ValueKey('home-day-${isoDate(DateTime.now())}'));
    await tester.scrollUntilVisible(cell, 200, scrollable: _scrollable);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Push')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Pull')), findsOneWidget);
    // Dua set kerja per sesi; volumenya dalam kg karena satuan bawaan kg.
    expect(find.descendant(of: sheet, matching: find.text('2 sets · 960 kg')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('2 sets · 640 kg')), findsOneWidget);

    await tester.tap(find.text('View history'));
    await tester.pumpAndSettle();
    expect(opened, 3);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kotak hari kosong: sheet bilang tidak ada sesi', (tester) async {
    _phone(tester);
    final store = await _storeWithWeek(tester);
    await tester.pumpWidget(_wrap(store, const HomeScreen()));
    await tester.pumpAndSettle();

    // Hari pertama minggu ini, kecuali hari ini memang hari pertama —
    // kalau begitu ambil hari terakhir, yang pasti masih kosong.
    final today = DateTime.now();
    var day = weekStart(today, store.settings.weekStartsOn);
    if (isoDate(day) == isoDate(today)) day = day.add(const Duration(days: 6));
    final cell = find.byKey(ValueKey('home-day-${isoDate(day)}'));
    await tester.scrollUntilVisible(cell, 200, scrollable: _scrollable);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('No sessions')), findsOneWidget);
    // Tanpa onOpenTab tidak ada tombol yang menjanjikan tab yang tak bisa dibuka.
    expect(find.text('View history'), findsNothing);
  });

  testWidgets('ketuk blok statistik membuka tab yang menjelaskannya', (tester) async {
    _phone(tester);
    final store = await _storeWithWeek(tester);
    int? opened;
    await tester.pumpWidget(_wrap(store, HomeScreen(onOpenTab: (i) => opened = i)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Volume 7d'), 200, scrollable: _scrollable);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Volume 7d'));
    await tester.pump();
    expect(opened, 2);

    await tester.tap(find.text('e1RM up'));
    await tester.pump();
    expect(opened, 2);

    await tester.tap(find.text('Since last'));
    await tester.pump();
    expect(opened, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tanpa onOpenTab blok statistik tetap tergambar tanpa error', (tester) async {
    _phone(tester);
    final store = await _storeWithWeek(tester);
    await tester.pumpWidget(_wrap(store, const HomeScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Volume 7d'), 200, scrollable: _scrollable);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volume 7d'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
