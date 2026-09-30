/// Hitung pelat per sisi (FR-D16): "Bench 80 kg, bar 20 kg → 30 kg per
/// sisi", yaitu 25 + 5.
///
/// Yang dijaga: pemecah pelatnya serakah dari yang terberat dan kebal debu
/// float, "tanpa bar" untuk Smith machine dan sled, sisa yang jujur saat
/// pelatnya tidak cukup halus, bar dan pelat tersimpan dalam kg tapi tampil
/// dalam satuan pilihan, ikut gabung setelan dua perangkat, dan layarnya
/// benar-benar bisa dipakai: baris di kartu sesi, lembar per set, dialog di
/// Profil, dan bar per gerakan di editor rutinitas.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/gym_icons.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/strings_plates.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/plates.dart';
import 'package:gymapps/domain/settings.dart';
import 'package:gymapps/domain/units.dart';
import 'package:gymapps/features/profile/profile_screen.dart';
import 'package:gymapps/features/session/plates_sheet.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:gymapps/features/workout/routine_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kg = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
const _lb = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5];

PlateLoad _kgLoad(double total, {double bar = 20}) => plateLoad(total: total, bar: bar, available: _kg);

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

/// Pump berjangka, bukan pumpAndSettle: timer sesi tidak pernah "tenang".
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Gulir daftar editor sampai [f] terbangun dan terlihat (lihat
/// v23_assisted_test): ListView membangun anaknya malas, jadi blok di bawah
/// picker policy belum ada sebelum digulir.
Future<void> _reveal(WidgetTester tester, Finder f) async {
  final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  var offset = 0.0;
  while (f.evaluate().isEmpty && offset < position.maxScrollExtent) {
    offset = math.min(offset + 300, position.maxScrollExtent);
    position.jumpTo(offset);
    await tester.pump();
  }
  await tester.ensureVisible(f);
  await _settle(tester);
}

Widget _launcher(Widget page, void Function(RoutineEditorResult?) onResult) => Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onResult(
            await Navigator.of(context).push<RoutineEditorResult>(MaterialPageRoute(builder: (_) => page)),
          ),
          child: const Text('GO'),
        ),
      ),
    );

/// Layar sesi untuk satu daftar gerakan. Kuncinya selalu baru: dua
/// `pumpWidget` berturut-turut dengan SessionScreen tanpa kunci akan
/// memakai State yang sama — beserta daftar gerakan lamanya.
SessionScreen _session(List<SessionExercise> exercises) =>
    SessionScreen(key: UniqueKey(), routineName: 'Push', exercises: exercises);

/// Satu gerakan di sesi dengan set kerja [weights] (satuan tampilan), sudah
/// terbuka. [bar] = override bar per gerakan, juga dalam satuan tampilan.
SessionExercise _ex({
  required String equipment,
  List<double> weights = const [60, 60],
  double? bar,
  String name = 'Barbell Bench Press',
}) =>
    SessionExercise(
      name: name,
      icon: Icons.fitness_center,
      equipment: equipment,
      config: ExerciseConfig(
        exerciseId: '0025',
        policy: ProgressionPolicy.linear,
        sets: weights.length,
        reps: 8,
        weight: weights.first,
        barWeight: bar,
      ),
      sets: [for (final w in weights) SetRow(weight: w, reps: 8)],
      previous: [for (final _ in weights) '—'],
      expanded: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('plateLoad (FR-D16)', () {
    test('kg: serakah dari pelat terberat, satu ukuran boleh berulang', () {
      // Kriteria penerimaan PRD: bench 80 kg, bar 20 kg → 30 kg per sisi.
      final bench = _kgLoad(80);
      expect(bench.perSide, [25, 5]);
      expect(bench.loaded, 80);
      expect(bench.remainder, 0);
      expect(bench.exact, isTrue);
      expect(bench.barTooHeavy, isFalse);
      expect(_kgLoad(60).perSide, [20]);
      expect(_kgLoad(100).perSide, [25, 15]);
      expect(_kgLoad(120).perSide, [25, 25], reason: 'pelat boleh berulang');
      expect(_kgLoad(62.5).perSide, [20, 1.25]);
      expect(_kgLoad(102.5).perSide, [25, 15, 1.25]);
      expect(_kgLoad(22.5).perSide, [1.25]);
    });

    test('lb: bar 45, pelat 45/35/25/10/5/2,5', () {
      PlateLoad lb(double total) => plateLoad(total: total, bar: 45, available: _lb);
      expect(lb(135).perSide, [45]);
      expect(lb(225).perSide, [45, 45]);
      expect(lb(315).perSide, [45, 45, 45]);
      expect(lb(185).perSide, [45, 25]);
      expect(lb(95).perSide, [25]);
      expect(lb(50).perSide, [2.5]);
      expect(lb(185).exact, isTrue);
    });

    test('tanpa bar (bar 0): seluruh beban dibagi ke dua sisi', () {
      expect(plateLoad(total: 40, bar: 0, available: _kg).perSide, [20]);
      expect(plateLoad(total: 90, bar: 0, available: _kg).perSide, [25, 20]);
      expect(plateLoad(total: 2.5, bar: 0, available: _kg).perSide, [1.25]);
      final smith = plateLoad(total: 90, bar: 0, available: _kg);
      expect(smith.loaded, 90);
      expect(smith.barTooHeavy, isFalse);
    });

    test('sisa: beban yang tidak bisa dibangun dilaporkan, yang terdekat tetap diberikan', () {
      final l = _kgLoad(61.5);
      expect(l.perSide, [20]);
      expect(l.loaded, 60);
      expect(l.remainder, 1.5, reason: 'sisa untuk dua sisi: 0,75 per sisi × 2');
      expect(l.exact, isFalse);
      expect(_kgLoad(60.75).remainder, 0.75, reason: 'pelat terkecil 1,25');
      final coarse = plateLoad(total: 62.5, bar: 20, available: [20, 10, 5]);
      expect(coarse.perSide, [20]);
      expect(coarse.remainder, 2.5);
      final none = plateLoad(total: 60, bar: 20, available: const []);
      expect(none.perSide, isEmpty);
      expect(none.loaded, 20);
      expect(none.remainder, 40);
      expect(none.barTooHeavy, isFalse);
    });

    test('nol persis: total = bar → bar kosong; total 0 tanpa bar → tidak ada apa-apa', () {
      final empty = _kgLoad(20);
      expect(empty.perSide, isEmpty);
      expect(empty.loaded, 20);
      expect(empty.remainder, 0);
      expect(empty.exact, isTrue);
      expect(empty.barTooHeavy, isFalse);
      final nothing = plateLoad(total: 0, bar: 0, available: _kg);
      expect(nothing.perSide, isEmpty);
      expect(nothing.loaded, 0);
      expect(nothing.remainder, 0);
      expect(nothing.exact, isTrue);
      expect(nothing.barTooHeavy, isFalse);
    });

    test('total di bawah bar: daftar kosong, sisa 0, penanda bar terlalu berat', () {
      final l = _kgLoad(15);
      expect(l.perSide, isEmpty);
      expect(l.remainder, 0);
      expect(l.barTooHeavy, isTrue);
      expect(l.loaded, 20, reason: 'yang terpasang adalah bar itu sendiri');
      expect(l.exact, isFalse);
      expect(_kgLoad(-5).barTooHeavy, isTrue);
      // Tanpa bar, tidak pernah "terlalu berat".
      expect(plateLoad(total: 5, bar: 0, available: _kg).barTooHeavy, isFalse);
    });

    test('debu float: 0,45 − 0,25 tidak menjadi 0,19999 yang menolak pelat 0,2', () {
      final fine = plateLoad(total: 20.9, bar: 20, available: [0.25, 0.2]);
      expect(fine.perSide, [0.25, 0.2]);
      expect(fine.exact, isTrue);
      expect(plateLoad(total: 20.3, bar: 20, available: [0.1, 0.05]).perSide, [0.1, 0.05]);
      expect(_kgLoad(27.5).perSide, [2.5, 1.25]);
      // Angka tersimpan dari lb punya pecahan panjang; dibulatkan ke 0,01.
      expect(_kgLoad(61.235).remainder, 1.24);
      expect(_kgLoad(61.235).loaded, 60);
    });

    test('daftar pelat boleh acak dan berulang; nol dan negatif diabaikan', () {
      expect(plateLoad(total: 100, bar: 20, available: [5, 25, 5, 20, 0, -2]).perSide, [25, 5, 5, 5]);
    });

    test('alat berpelat menurut katalog, dan bar yang berlaku untuk satu gerakan', () {
      for (final eq in ['barbell', 'ez barbell', 'olympic barbell', 'trap bar', 'smith machine', 'sled machine']) {
        expect(isPlateLoaded(eq), isTrue, reason: eq);
      }
      for (final eq in ['dumbbell', 'cable', 'leverage machine', 'body weight', 'kettlebell', '']) {
        expect(isPlateLoaded(eq), isFalse, reason: eq);
      }
      expect(defaultsToNoBar('smith machine'), isTrue);
      expect(defaultsToNoBar('sled machine'), isTrue);
      expect(defaultsToNoBar('barbell'), isFalse);
      expect(effectiveBar(equipment: 'barbell', globalBar: 20), 20);
      expect(effectiveBar(equipment: 'smith machine', globalBar: 20), 0, reason: 'Smith bawaan tanpa bar');
      expect(effectiveBar(equipment: 'smith machine', override: 7, globalBar: 20), 7, reason: 'bar Smith berbobot');
      expect(effectiveBar(equipment: 'barbell', override: 0, globalBar: 20), 0);
      expect(effectiveBar(equipment: 'barbell', override: 15, globalBar: 20), 15);
    });

    test('katalog sungguhan: bar-bar dan Smith berpelat, dumbel tidak', () async {
      final catalog = await ExerciseCatalog.load();
      expect(isPlateLoaded(catalog.byId('0025')!.equipment), isTrue, reason: 'barbell bench press');
      expect(isPlateLoaded(catalog.byId('0447')!.equipment), isTrue, reason: 'ez barbell curl');
      expect(isPlateLoaded(catalog.byId('0748')!.equipment), isTrue, reason: 'smith bench press');
      expect(isPlateLoaded(catalog.byId('0289')!.equipment), isFalse, reason: 'dumbbell bench press');
      expect(isPlateLoaded(catalog.byId('0017')!.equipment), isFalse, reason: 'assisted pull-up');
      final loaded = {for (final e in catalog.all) if (isPlateLoaded(e.equipment)) e.equipment};
      expect(loaded, plateLoadedEquipment, reason: 'setiap kunci benar-benar ada di katalog');
    });
  });

  group('setelan bar dan pelat', () {
    test('belum diatur: tidak ditulis, bawaan mengikuti satuan', () {
      const s = TrainingSettings();
      expect(s.toJson().containsKey('bar'), isFalse);
      expect(s.toJson().containsKey('plates'), isFalse);
      expect(s.barWeightIn(WeightUnit.kg), 20);
      expect(s.barWeightIn(WeightUnit.lb), 45);
      expect(s.platesIn(WeightUnit.kg), _kg);
      expect(s.platesIn(WeightUnit.lb), _lb);
      expect(plateChoices(WeightUnit.kg), containsAll(_kg));
      expect(plateChoices(WeightUnit.lb), containsAll(_lb));
    });

    test('bolak-balik JSON dalam kg, termasuk bar 0 (tanpa bar)', () {
      final s = const TrainingSettings().copyWith(barWeight: 0, plates: [20, 10, 5]);
      expect(s.toJson()['bar'], 0);
      expect(s.toJson()['plates'], [20, 10, 5]);
      final back = TrainingSettings.fromJson(s.toJson());
      expect(back.barWeight, 0);
      expect(back.plates, [20, 10, 5]);
      expect(back.barWeightIn(WeightUnit.kg), 0, reason: 'nol bukan "belum diatur"');
      expect(const TrainingSettings(barWeight: 15).toJson()['bar'], 15);
      // copyWith: null = jangan ubah; kembali ke bawaan lewat clear…
      expect(s.copyWith(logRir: true).barWeight, 0);
      expect(s.copyWith(clearBarWeight: true).barWeight, isNull);
      expect(s.copyWith(clearPlates: true).plates, isNull);
      expect(s.copyWith(barWeight: 15).barWeight, 15);
    });

    test('disimpan kg, ditampilkan dalam satuan pilihan — seperti beban lain', () {
      // Bar 20 kg yang dilihat dalam lb memang 44,09: itu bar yang sama.
      const kgBar = TrainingSettings(barWeight: 20);
      expect(kgBar.barWeightIn(WeightUnit.lb), closeTo(44.09, 0.001));
      expect(kgBar.barWeightIn(WeightUnit.kg), 20);
      // Diatur dalam lb: kembali persis, bukan 2,49 atau 1,3 (pembulatan 0,1 lb).
      final fromLb = const TrainingSettings(unit: WeightUnit.lb).copyWith(
        barWeight: toKg(45, WeightUnit.lb),
        plates: [for (final p in [45.0, 25.0, 2.5, 1.25]) toKg(p, WeightUnit.lb)],
      );
      expect(fromLb.barWeightIn(WeightUnit.lb), 45);
      expect(fromLb.platesIn(WeightUnit.lb), [45, 25, 2.5, 1.25]);
      expect(fromLb.platesIn(WeightUnit.kg).first, closeTo(20.41, 0.001));
      expect(plateShown(toKg(1.25, WeightUnit.lb), WeightUnit.lb), 1.25);
      // Daftar diurutkan terberat dulu; duplikat dan nol dibuang.
      expect(const TrainingSettings(plates: [5, 20, 5, 0, 10]).platesIn(WeightUnit.kg), [20, 10, 5]);
      expect(const TrainingSettings(plates: []).platesIn(WeightUnit.kg), isEmpty);
    });

    test('nilai rusak dari perangkat lain dibaca sebagai belum diatur', () {
      expect(TrainingSettings.fromJson({'bar': -5}).barWeight, isNull);
      expect(TrainingSettings.fromJson({'bar': 'x'}).barWeight, isNull);
      expect(TrainingSettings.fromJson({'plates': 'x'}).plates, isNull);
      expect(TrainingSettings.fromJson({'plates': [5, 'x', -1, 0, 2.5]}).plates, [5, 2.5]);
    });

    test('gabung setelan dua perangkat: bar dan pelat per kolom', () {
      final base = {'bar': 20.0, 'plates': [20.0, 10.0]};
      final mine = {'bar': 15.0, 'plates': [20.0, 10.0]};
      final theirs = {'bar': 20.0, 'plates': [25.0, 20.0, 10.0]};
      final merged = WorkoutStore.mergeSettings(base: base, mine: mine, theirs: theirs);
      expect(merged['bar'], 15, reason: 'diubah di sini');
      expect(merged['plates'], [25, 20, 10], reason: 'diubah di server');
      final s = TrainingSettings.fromJson(merged);
      expect(s.barWeightIn(WeightUnit.kg), 15);
      expect(s.platesIn(WeightUnit.kg), [25, 20, 10]);
      // Dikembalikan ke bawaan di server, tidak disentuh di sini: ikut hilang.
      final cleared = WorkoutStore.mergeSettings(base: base, mine: base, theirs: const {});
      expect(cleared.containsKey('bar'), isFalse);
      expect(cleared.containsKey('plates'), isFalse);
      // Diatur di sini, server belum tahu: tetap.
      expect(WorkoutStore.mergeSettings(base: const {}, mine: {'bar': 0.0}, theirs: const {})['bar'], 0);
    });

    test('tersimpan ke disk dan dibaca ulang', () async {
      SharedPreferences.setMockInitialValues({});
      final a = WorkoutStore();
      await a.load('a@x.com');
      await a.updateSettings(a.settings.copyWith(barWeight: 0, plates: [20, 10]));
      final b = WorkoutStore();
      await b.load('a@x.com');
      expect(b.settings.barWeight, 0);
      expect(b.settings.plates, [20, 10]);
    });

    test('override bar per gerakan: JSON, copyWith, dan konversi satuan', () {
      const c = ExerciseConfig(exerciseId: '0025', barWeight: 0);
      expect(c.toJson()['bar'], 0);
      expect(ExerciseConfig.fromJson(c.toJson()).barWeight, 0);
      expect(const ExerciseConfig(exerciseId: '0025').toJson().containsKey('bar'), isFalse);
      expect(ExerciseConfig.fromJson({'id': '0025', 'bar': -1}).barWeight, isNull);
      expect(ExerciseConfig.fromJson({'id': '0025', 'bar': 'x'}).barWeight, isNull);
      expect(c.copyWith(sets: 4).barWeight, 0);
      expect(c.copyWith(barWeight: 15).barWeight, 15);
      expect(c.copyWith(clearBarWeight: true).barWeight, isNull);
      // 45 lb tersimpan sebagai kg dan tampil 45 lb lagi; 0 dan null tidak tersentuh.
      const lbCfg = ExerciseConfig(exerciseId: '0025', barWeight: 45);
      final kg = configToKg(lbCfg, WeightUnit.lb);
      expect(kg.barWeight, closeTo(20.412, 0.001), reason: 'tidak dibulatkan saat disimpan, seperti beban');
      expect(configIn(kg, WeightUnit.lb).barWeight, 45);
      expect(configIn(c, WeightUnit.lb).barWeight, 0);
      expect(configIn(const ExerciseConfig(exerciseId: '0025'), WeightUnit.lb).barWeight, isNull);
      expect(configBetween(lbCfg, WeightUnit.lb, WeightUnit.kg).barWeight, closeTo(20.41, 0.001));
    });
  });

  group('teks', () {
    test('bentuk teks mengikuti bahasa: koma desimal di Indonesia', () {
      const id = Strings(AppLanguage.indonesian);
      const en = Strings(AppLanguage.english);
      expect(en.perSide(en.plateList([20, 5, 2.5])), 'per side: 20 + 5 + 2.5');
      expect(id.perSide(id.plateList([20, 5, 2.5])), 'per sisi: 20 + 5 + 2,5');
      expect(id.weightUnit(1.25, 'kg'), '1,25 kg');
      expect(en.weightUnit(61.235, 'kg'), '61.24 kg');
      expect(id.plateList(const []), isEmpty);
    });
  });

  group('layar sesi', () {
    late WorkoutStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ExerciseCatalog.registerCustom(const []);
      store = WorkoutStore();
      await store.load();
    });

    testWidgets('gerakan barbel: baris pelat di kartu, lembar per set kerja dengan bentuk teks', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(store, _session([_ex(equipment: 'barbell', weights: [60, 80])])));
      await _settle(tester);
      expect(find.byTooltip('Show plates per side'), findsOneWidget);
      expect(find.text('per side: 20'), findsOneWidget, reason: 'set kerja pertama 60 kg');
      expect(tester.getSize(find.byType(PlatesRow)).height, greaterThanOrEqualTo(44), reason: 'NFR-11');
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(PlatesRow));
      await _settle(tester);
      expect(find.byType(PlatesSheet), findsOneWidget);
      expect(find.text('per side: 20'), findsNWidgets(2), reason: 'baris kartu + set 1');
      expect(find.text('per side: 25 + 5'), findsOneWidget, reason: 'set 2: 80 kg → 30 per sisi');
      expect(find.textContaining('30 kg per side'), findsOneWidget, reason: 'kriteria penerimaan FR-D16');
      expect(find.textContaining('Bar 20 kg'), findsOneWidget);
      expect(find.byType(PlateDiscs), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('gerakan dumbel tidak punya baris pelat', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(
        store,
        _session([_ex(equipment: 'dumbbell', name: 'Dumbbell Bench Press')]),
      ));
      await _settle(tester);
      expect(find.byType(PlatesRow), findsNothing);
      expect(find.byTooltip('Show plates per side'), findsNothing);
      // Tanpa alat yang dikenal (test lama, id di luar katalog) juga tidak.
      await tester.pumpWidget(_wrap(store, _session([_ex(equipment: '')])));
      await _settle(tester);
      expect(find.byType(PlatesRow), findsNothing);
    });

    testWidgets('Smith machine bawaan tanpa bar; override bar per gerakan menang', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(store, _session([_ex(equipment: 'smith machine', weights: [40])])));
      await _settle(tester);
      expect(find.text('per side: 20'), findsOneWidget, reason: '40 kg tanpa bar');

      await tester.pumpWidget(_wrap(store, _session([_ex(equipment: 'smith machine', weights: [40], bar: 7.5)])));
      await _settle(tester);
      expect(find.text('per side: 15 + 1.25'), findsOneWidget, reason: 'bar Smith 7,5 kg → 16,25 per sisi');

      await tester.pumpWidget(_wrap(store, _session([_ex(equipment: 'barbell', weights: [60], bar: 10)])));
      await _settle(tester);
      expect(find.text('per side: 25'), findsOneWidget, reason: 'bar teknik 10 kg');
      expect(tester.takeException(), isNull);
    });

    testWidgets('beban yang tidak pas: penanda di baris, peringatan di lembar', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(store, _session([_ex(equipment: 'barbell', weights: [61.5])])));
      await _settle(tester);
      expect(find.text('per side: 20'), findsOneWidget);
      expect(find.descendant(of: find.byType(PlatesRow), matching: find.byIcon(GymIcons.info)), findsOneWidget);

      await tester.tap(find.byType(PlatesRow));
      await _settle(tester);
      expect(find.textContaining('closest 60 kg (1.5 kg short)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('beban di bawah bar dan set tanpa beban dikatakan apa adanya', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(store, _session([_ex(equipment: 'barbell', weights: [15, 0])])));
      await _settle(tester);
      expect(find.text('Lighter than the bar (20 kg)'), findsOneWidget);
      await tester.tap(find.byType(PlatesRow));
      await _settle(tester);
      expect(find.text('Lighter than the bar (20 kg)'), findsNWidgets(2));
      expect(find.text('No weight entered yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('satuan lb: bar 45 dan pelat lb; angka sesi sudah dalam lb', (tester) async {
      _phone(tester);
      await store.updateSettings(store.settings.copyWith(unit: WeightUnit.lb));
      await tester.pumpWidget(_wrap(store, _session([_ex(equipment: 'barbell', weights: [135, 185])])));
      await _settle(tester);
      expect(find.text('per side: 45'), findsOneWidget);
      await tester.tap(find.byType(PlatesRow));
      await _settle(tester);
      expect(find.textContaining('45 lb per side'), findsOneWidget);
      expect(find.text('per side: 45 + 25'), findsOneWidget);
      expect(find.textContaining('Bar 45 lb'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bar dan pelat dari Profil dipakai sesi', (tester) async {
      _phone(tester);
      await store.updateSettings(store.settings.copyWith(barWeight: 15, plates: [20, 10, 5, 2.5]));
      await tester.pumpWidget(_wrap(store, _session([_ex(equipment: 'barbell', weights: [60])])));
      await _settle(tester);
      expect(find.text('per side: 20 + 2.5'), findsOneWidget, reason: '(60 − 15) ÷ 2 = 22,5');
    });

    for (final lang in [AppLanguage.english, AppLanguage.indonesian]) {
      final tag = lang == AppLanguage.indonesian ? 'id' : 'en';
      testWidgets('[$tag] baris dan lembar pelat utuh di 360 dp dengan huruf 1,3×', (tester) async {
        _phone(tester);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(_wrap(
          store,
          _session([_ex(equipment: 'barbell', weights: [102.5, 61.5, 15])]),
          lang: lang,
        ));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(PlatesRow));
        await _settle(tester);
        expect(find.byType(PlatesSheet), findsOneWidget);
        expect(find.text(lang == AppLanguage.indonesian ? 'per sisi: 25 + 15 + 1,25' : 'per side: 25 + 15 + 1.25'),
            findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Profil', () {
    Widget profile(WorkoutStore store) => _wrap(
          store,
          Scaffold(
            body: ProfileScreen(language: AppLanguage.english, onLanguageChanged: (_) {}, onSignOut: () {}, email: 'a@x.com'),
          ),
        );

    Future<void> scrollTo(WidgetTester tester, Finder f) async {
      await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
    }

    /// Ketuk satu baris setelan: digulir dulu, karena baris di atas yang
    /// terakhir digulir bisa berhenti 44 dp di luar tepi atas layar.
    Future<void> tapTile(WidgetTester tester, String label) async {
      await scrollTo(tester, find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('berat bar: preset tanpa bar, angka yang diketik, kembali ke bawaan; pelat: nyala-mati dan bawaan',
        (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({});
      final store = WorkoutStore();
      await store.load('a@x.com');
      await tester.pumpWidget(profile(store));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Plates available'));
      expect(find.text('20 kg'), findsOneWidget, reason: 'bawaan kg');
      expect(find.text('7 sizes'), findsOneWidget);

      // Preset "tanpa bar" menutup dialog seketika.
      await tapTile(tester, 'Bar weight');
      expect(find.text('Weight of the empty bar. Smith machines and plate-loaded machines count from zero.'), findsOneWidget);
      await tester.tap(find.text('No bar'));
      await tester.pumpAndSettle();
      expect(store.settings.barWeight, 0);
      expect(find.text('No bar'), findsOneWidget, reason: 'nilai di baris');

      // Angka yang diketik, dalam satuan tampilan, disimpan sebagai kg.
      await tapTile(tester, 'Bar weight');
      await tester.enterText(find.byType(TextField), '15');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(store.settings.barWeight, 15);
      expect(find.text('15 kg'), findsOneWidget);

      // "Bawaan" menghapus nilainya, bukan menulis 20.
      await tapTile(tester, 'Bar weight');
      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();
      expect(store.settings.barWeight, isNull);
      expect(find.text('20 kg'), findsOneWidget);

      // Pelat: matikan 1,25, nyalakan 2, lalu kembali ke bawaan.
      await tapTile(tester, 'Plates available');
      await tester.tap(find.text('1.25 kg'));
      await tester.pumpAndSettle();
      expect(store.settings.platesIn(WeightUnit.kg), [25, 20, 15, 10, 5, 2.5]);
      await tester.tap(find.text('2 kg'));
      await tester.pumpAndSettle();
      expect(store.settings.platesIn(WeightUnit.kg), [25, 20, 15, 10, 5, 2.5, 2]);
      await tester.tap(find.text('Use default plates'));
      await tester.pumpAndSettle();
      expect(store.settings.plates, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dalam lb: dialog dan chip memakai angka lb, tersimpan kg', (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({});
      final store = WorkoutStore();
      await store.load('a@x.com');
      await store.updateSettings(store.settings.copyWith(unit: WeightUnit.lb));
      await tester.pumpWidget(profile(store));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Plates available'));
      expect(find.text('45 lb'), findsOneWidget);
      expect(find.text('6 sizes'), findsOneWidget);
      await tapTile(tester, 'Bar weight');
      await tester.tap(find.text('35 lb'));
      await tester.pumpAndSettle();
      expect(store.settings.barWeight, closeTo(toKg(35, WeightUnit.lb), 0.0001));
      expect(store.settings.barWeightIn(WeightUnit.lb), 35);
      expect(find.text('35 lb'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('editor rutinitas', () {
    late WorkoutStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ExerciseCatalog.registerCustom(const []);
      store = WorkoutStore();
      await store.load();
    });

    /// Ketuk − atau + di stepper yang sedang menampilkan [current].
    Future<void> step(WidgetTester tester, Finder current, IconData icon) async {
      final row = find.ancestor(of: current, matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: row, matching: find.byIcon(icon)));
      await _settle(tester);
    }

    testWidgets('bar per gerakan: global → tanpa bar → 2,5 → 5 kg, tersimpan ke rutinitas', (tester) async {
      _phone(tester);
      await tester.runAsync(ExerciseCatalog.load);
      RoutineEditorResult? result;
      const routine = Routine(id: 'push', name: 'Push', exercises: [ExerciseConfig(exerciseId: '0025')]);
      await tester.pumpWidget(_wrap(store, _launcher(const RoutineEditorScreen(routine: routine), (r) => result = r)));
      await tester.tap(find.text('GO'));
      await _settle(tester);

      await _reveal(tester, find.text('BAR FOR PLATE MATH'));
      expect(find.text('Global · 20 kg'), findsOneWidget);
      await step(tester, find.text('Global · 20 kg'), Icons.add);
      expect(find.text('No bar'), findsOneWidget);
      await step(tester, find.text('No bar'), Icons.add);
      // "2.5 kg" juga nilai kolom kelipatan; kolom bar yang terakhir di pohon.
      await step(tester, find.text('2.5 kg').last, Icons.add);
      expect(find.text('5 kg'), findsOneWidget);

      await tester.ensureVisible(find.text('SAVE'));
      await tester.tap(find.text('SAVE'));
      await _settle(tester);
      expect(result, isA<RoutineSaved>());
      expect((result as RoutineSaved).routine.exercises.single.barWeight, 5);
    });

    testWidgets('− dari tanpa bar kembali ke global (null); Smith machine menyebut global tanpa bar', (tester) async {
      _phone(tester);
      await tester.runAsync(ExerciseCatalog.load);
      RoutineEditorResult? result;
      const routine = Routine(id: 'push', name: 'Push', exercises: [ExerciseConfig(exerciseId: '0025', barWeight: 5)]);
      await tester.pumpWidget(_wrap(store, _launcher(const RoutineEditorScreen(routine: routine), (r) => result = r)));
      await tester.tap(find.text('GO'));
      await _settle(tester);
      await _reveal(tester, find.text('5 kg'));
      await step(tester, find.text('5 kg'), Icons.remove);
      await step(tester, find.text('2.5 kg').last, Icons.remove);
      expect(find.text('No bar'), findsOneWidget);
      await step(tester, find.text('No bar'), Icons.remove);
      expect(find.text('Global · 20 kg'), findsOneWidget);
      await tester.ensureVisible(find.text('SAVE'));
      await tester.tap(find.text('SAVE'));
      await _settle(tester);
      expect((result as RoutineSaved).routine.exercises.single.barWeight, isNull);

      // Smith bench press: globalnya "tanpa bar"; dumbel: kolomnya tidak ada.
      const smith = Routine(id: 's', name: 'Smith', exercises: [ExerciseConfig(exerciseId: '0748')]);
      // Pohon baru: Navigator lama masih memegang rute editor yang tadi.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_wrap(store, _launcher(const RoutineEditorScreen(routine: smith), (_) {})));
      await tester.tap(find.text('GO'));
      await _settle(tester);
      await _reveal(tester, find.text('BAR FOR PLATE MATH'));
      expect(find.text('Global · No bar'), findsOneWidget);

      const db = Routine(id: 'd', name: 'DB', exercises: [ExerciseConfig(exerciseId: '0289')]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_wrap(store, _launcher(const RoutineEditorScreen(routine: db), (_) {})));
      await tester.tap(find.text('GO'));
      await _settle(tester);
      await _reveal(tester, find.text('PROGRESSION POLICY'));
      expect(find.text('BAR FOR PLATE MATH'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
