/// Layar library saat pencarian tidak menemukan apa pun: tetap ada jalan
/// keluar (tambah sebagai gerakan custom), dan barisnya tidak meluber di HP
/// 360 dp meski nama gerakannya panjang.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/features/library/library_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tidak ketemu → tombol tambah custom, tanpa luapan di 360 dp', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
    final store = WorkoutStore();
    await store.load();
    // Katalog dibaca dari aset sungguhan, jadi perlu IO nyata — dan harus
    // selesai sebelum layar dibuat, supaya layar mendapat versi yang sudah
    // di-cache alih-alih menunggu selamanya di dalam waktu palsu test.
    await tester.runAsync(() => ExerciseCatalog.load());

    await tester.pumpWidget(WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        child: MaterialApp(theme: buildGymTheme(), home: const ExerciseLibraryScreen(picking: true)),
      ),
    ));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'hariz special press with a very long name');
    await tester.pump();

    expect(find.textContaining('Nothing matches'), findsOneWidget);
    expect(find.textContaining('as custom exercise'), findsOneWidget);

    await tester.tap(find.textContaining('as custom exercise'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(CustomExerciseSheet), findsOneWidget);
    // Nama dari kueri langsung terisi.
    expect(find.widgetWithText(TextField, 'Hariz special press with a very long name'), findsOneWidget);
  });
}
