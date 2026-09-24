/// Penjaga layar sesi dan onboarding.
///
/// Semua test di sini lahir dari laporan pemakai di emulator:
/// * Switch rest timer terdorong keluar kartu di HP 360 dp.
/// * Tombol ⋯ di kartu gerakan hanya ikon, tidak bisa diketuk.
/// * "ADD EXERCISE" dan "BUILD MY OWN" tidak melakukan apa-apa.
/// * Angka yang diketik di kolom KG hilang saat set dicentang.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/features/library/library_screen.dart';
import 'package:gymapps/features/onboarding/custom_split_screen.dart';
import 'package:gymapps/features/onboarding/onboarding_screens.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        child: MaterialApp(theme: buildGymTheme(), home: home),
      ),
    );

SessionExercise _bench({bool expanded = true}) => SessionExercise(
      name: 'Barbell Bench Press',
      icon: Icons.fitness_center,
      config: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.double_, reps: 10, repsMin: 6),
      sets: const [SetRow(weight: 60, reps: 8), SetRow(weight: 60, reps: 8)],
      previous: const ['60 × 8', '60 × 8'],
      expanded: expanded,
    );

/// HP kecil yang umum: 360 × 780 dp.
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

  testWidgets('baris rest timer muat di HP 360 dp dan switch-nya bisa diketuk', (tester) async {
    _phone(tester);
    final ex = _bench();
    await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [ex])));
    await tester.pump();

    // Luapan RenderFlex membuat test gagal dengan sendirinya. Yang dicek di
    // sini tambahan: switch-nya benar-benar di dalam layar dan menanggapi.
    final sw = find.byType(Switch);
    expect(sw, findsOneWidget);
    final box = tester.getRect(sw);
    expect(box.right, lessThanOrEqualTo(360));

    await tester.tap(sw);
    await tester.pump();
    expect(ex.restEnabled, isFalse);
  });

  testWidgets('tombol ⋯ membuka menu aksi gerakan', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [_bench(), _bench(expanded: false)])));
    await tester.pump();

    await tester.tap(find.byTooltip('Exercise actions').first);
    await tester.pumpAndSettle();
    expect(find.text('Move down'), findsOneWidget);
    expect(find.text('Replace exercise'), findsOneWidget);
    expect(find.text('Remove exercise'), findsOneWidget);

    // Hapus gerakan yang belum disentuh tidak perlu konfirmasi.
    await tester.tap(find.text('Remove exercise'));
    await tester.pumpAndSettle();
    expect(find.text('Barbell Bench Press'), findsOneWidget);
  });

  testWidgets('ADD EXERCISE membuka library sebagai pemilih', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(store, const SessionScreen(routineName: 'Freestyle', exercises: [])));
    await tester.pump();

    await tester.tap(find.text('ADD EXERCISE'));
    // Bukan pumpAndSettle: library menampilkan spinner selama katalog dibaca,
    // dan spinner tidak pernah "tenang".
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final lib = tester.widget<ExerciseLibraryScreen>(find.byType(ExerciseLibraryScreen));
    expect(lib.picking, isTrue);
  });

  testWidgets('kartu istirahat muat di HP 360 dp', (tester) async {
    _phone(tester);
    final ex = _bench();
    await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [ex])));
    await tester.pump();
    // Mencentang set pertama memulai istirahat, membuka layar hitung mundur
    // penuh; tutup lalu periksa kartu istirahat di daftar.
    await tester.tap(find.byIcon(Icons.circle_outlined).first);
    await tester.pump(const Duration(milliseconds: 500));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('REST'), findsWidgets);
  });

  testWidgets('beban yang diketik ikut tersimpan saat set dicentang', (tester) async {
    _phone(tester);
    final ex = _bench();
    await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [ex])));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, '62.5');
    await tester.pump();
    expect(ex.sets.first.weight, 62.5);

    await tester.tap(find.byIcon(Icons.circle_outlined).first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(ex.sets.first.done, isTrue);
    expect(ex.sets.first.weight, 62.5);
  });

  testWidgets('beban set pertama diteruskan ke set berikutnya yang belum dicentang', (tester) async {
    _phone(tester);
    final ex = SessionExercise(
      name: 'Barbell Bench Press',
      icon: Icons.fitness_center,
      config: const ExerciseConfig(exerciseId: '0025'),
      sets: const [SetRow(reps: 10), SetRow(reps: 10), SetRow(reps: 10)],
      previous: const ['—', '—', '—'],
      expanded: true,
    );
    await tester.pumpWidget(_wrap(store, SessionScreen(routineName: 'Push', exercises: [ex])));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, '60');
    await tester.pump();
    expect(ex.sets.map((s) => s.weight), [60, 60, 60]);
    // Kotak input set 2 ikut menampilkan angka barunya.
    expect(find.widgetWithText(TextFormField, '60'), findsNWidgets(3));
  });

  testWidgets('BUILD MY OWN memanggil callback-nya', (tester) async {
    _phone(tester);
    var called = false;
    await tester.pumpWidget(_wrap(
      store,
      ProgramPickerScreen(onContinue: (_) {}, onBuildOwn: () => called = true),
    ));
    await tester.scrollUntilVisible(find.text('BUILD MY OWN'), 200);
    await tester.tap(find.text('BUILD MY OWN'));
    expect(called, isTrue);
  });

  testWidgets('susun split sendiri mengembalikan program rotasi', (tester) async {
    _phone(tester);
    Object? result;
    await tester.pumpWidget(_wrap(
      store,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const CustomSplitScreen())),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Upper Lower Arms');
    await tester.scrollUntilVisible(find.text('ADD DAY'), 200,
        scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('ADD DAY'));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    final bundle = result as dynamic;
    expect(bundle.program.name, 'Upper Lower Arms');
    expect(bundle.program.mode, ProgramMode.rotation);
    expect(bundle.routines.length, 4);
    expect(bundle.program.order.length, 4);
  });
}
