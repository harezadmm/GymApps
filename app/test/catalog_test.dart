/// Pencarian katalog dan gerakan custom.
///
/// Lahir dari laporan pemakai: mengetik "single arm lat pulldown" menghasilkan
/// "Nothing matches", padahal katalog punya "Cable One Arm Pulldown" — dan
/// tidak ada jalan untuk menambah gerakan yang memang tidak ada.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Exercise _e(String id, String name, String bp, String eq, String tg) =>
    Exercise(id: id, name: name, bodyPart: bp, equipment: eq, target: tg, secondary: const []);

final _catalog = ExerciseCatalog.forTest([
  _e('3563', 'Cable One Arm Pulldown', 'back', 'cable', 'lats'),
  _e('2330', 'Cable Lat Pulldown Full Range Of Motion', 'back', 'cable', 'lats'),
  _e('0025', 'Barbell Bench Press', 'chest', 'barbell', 'pectorals'),
  _e('0294', 'Dumbbell Biceps Curl', 'upper arms', 'dumbbell', 'biceps'),
  _e('0400', 'Dumbbell Forearm Curl', 'lower arms', 'dumbbell', 'forearms'),
  _e('2133', 'Farmer Walk', 'upper legs', 'dumbbell', 'quads'),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
  });

  group('pencarian', () {
    test('"single arm lat pulldown" menemukan Cable One Arm Pulldown', () {
      final r = _catalog.search('single arm lat pulldown ');
      expect(r.first.id, '3563');
    });

    test('urutan kata bebas', () {
      expect(_catalog.search('press bench').map((e) => e.id), ['0025']);
    });

    test('singkatan: db curl', () {
      expect(_catalog.search('db curl').map((e) => e.id), contains('0294'));
    });

    test('"pull-down" dan "pull down" sama dengan "pulldown"', () {
      expect(_catalog.search('pull-down').length, 2);
      expect(_catalog.search('pull down').length, 2);
    });

    test('kata dicocokkan di awal kata: "arm" tidak menemukan "Farmer Walk"', () {
      expect(_catalog.search('arm').map((e) => e.id), isNot(contains('2133')));
    });

    test('kueri kosong mengembalikan semuanya', () {
      expect(_catalog.search('   ').length, 6);
    });
  });

  group('gerakan custom', () {
    test('tersimpan, ikut katalog, dan bertahan setelah aplikasi ditutup', () async {
      final a = WorkoutStore();
      await a.load();
      final ex = await a.addCustomExercise(name: 'Meadows Row', bodyPart: 'back', target: 'lats', equipment: 'barbell');
      expect(ex.custom, isTrue);
      expect(_catalog.byId(ex.id)?.name, 'Meadows Row');
      expect(_catalog.search('meadows').first.id, ex.id);

      ExerciseCatalog.registerCustom(const []);
      final b = WorkoutStore();
      await b.load();
      expect(b.customExercises.map((e) => e.name), ['Meadows Row']);
      expect(_catalog.nameOf(ex.id), 'Meadows Row');
    });

    test('nama yang sama tidak membuat duplikat', () async {
      final s = WorkoutStore();
      await s.load();
      final a = await s.addCustomExercise(name: 'Meadows Row', bodyPart: 'back', target: 'lats');
      final b = await s.addCustomExercise(name: 'meadows row ', bodyPart: 'back', target: 'lats');
      expect(b.id, a.id);
      expect(s.customExercises.length, 1);
    });

    test('nama custom tidak diubah huruf besarnya', () {
      final e = Exercise.fromJson({'id': 'custom-x', 'n': 'DB row on bench', 'custom': true});
      expect(e.name, 'DB row on bench');
    });
  });
}
