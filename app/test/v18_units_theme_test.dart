/// v1.8: satuan lb dan tema terang.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/format.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/weights.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/session_plan.dart';
import 'package:gymapps/domain/settings.dart';
import 'package:gymapps/domain/units.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bench = ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, sets: 3, reps: 5);

Workout _session(String date, double weight, {int reps = 5, ExerciseConfig target = _bench}) => Workout(
      date: date,
      entries: [
        WorkoutEntry(
          exerciseId: '0025',
          target: target.copyWith(weight: weight),
          sets: [for (var i = 0; i < 3; i++) SetRow(weight: weight, reps: reps, done: true)],
        ),
      ],
    );

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('satuan lb', () {
    test('satuan tersimpan di setelan dan kg tidak ditulis', () {
      expect(const TrainingSettings().toJson().containsKey('unit'), isFalse);
      final lb = const TrainingSettings().copyWith(unit: WeightUnit.lb);
      expect(lb.toJson()['unit'], 'lb');
      expect(TrainingSettings.fromJson(lb.toJson()).unit, WeightUnit.lb);
      expect(TrainingSettings.fromJson(const {}).unit, WeightUnit.kg);
    });

    test('135 lb dicatat, disimpan sebagai kg, dibaca lagi tepat 135 lb', () {
      final logged = _session('2026-09-20', 135);
      final stored = workoutToKg(logged, WeightUnit.lb);
      expect(stored.entries.first.sets.first.weight, closeTo(61.235, 0.001));
      expect(stored.entries.first.target!.weight, closeTo(61.235, 0.001));
      final back = historyIn([stored], WeightUnit.lb).first;
      expect(back.entries.first.sets.first.weight, 135);
      expect(shown(stored.entries.first.sets.first.weight, WeightUnit.lb), 135);
    });

    test('pemakai kg tidak tersentuh sama sekali', () {
      final h = [_session('2026-09-20', 60)];
      expect(identical(historyIn(h, WeightUnit.kg), h), isTrue);
      expect(identical(workoutToKg(h.first, WeightUnit.kg), h.first), isTrue);
    });

    test('progresi dalam lb melompat 5 lb, bukan 2,5 kg yang jadi 5,51 lb', () {
      final stored = [workoutToKg(_session('2026-09-20', 135), WeightUnit.lb)];
      final cfgKg = _bench.copyWith(weight: toKg(135, WeightUnit.lb));
      final plan = planExercise(configIn(cfgKg, WeightUnit.lb), historyIn(stored, WeightUnit.lb), unit: 'lb');
      final work = plan.sets.firstWhere((s) => !s.isWarmup);
      expect(work.weight, 140);
      expect(plan.prescription.why, contains('lb'));
      // Disimpan balik: 140 lb tetap 140 lb.
      expect(shown(toKg(work.weight, WeightUnit.lb), WeightUnit.lb), 140);
    });

    test('draft sesi dalam kg dibuka setelah pindah ke lb', () {
      const s = SetRow(weight: 100, reps: 5);
      expect(setBetween(s, WeightUnit.kg, WeightUnit.lb).weight, 220.5);
      expect(setBetween(const SetRow(weight: 0, reps: 8), WeightUnit.kg, WeightUnit.lb).weight, 0);
    });

    test('kg hasil konversi dari lb tampil dibulatkan, bukan pecahan panjang', () {
      expect(formatWeight(toKg(140, WeightUnit.lb)), '63.5');
      expect(formatWeight(63.502931800000006), '63.5');
      expect(formatWeight(72.5), '72.5');
      expect(formatWeight(65), '65');
      expect(formatWeight(61.235), '61.24');
    });

    test('volume: ton untuk kg, ribuan lb untuk lb', () {
      expect(volumeText(1234, WeightUnit.kg), '1.2 t');
      expect(volumeText(2645, WeightUnit.lb), '2.6k lb');
      expect(volumeText(420, WeightUnit.kg), '420 kg', reason: 'sesi kecil tidak ditulis 0.4 t');
      expect(volumeText(925.6, WeightUnit.lb), '926 lb');
    });

    testWidgets('layar yang membaca store menampilkan lb', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = WorkoutStore();
      await store.load();
      await store.updateSettings(store.settings.copyWith(unit: WeightUnit.lb));
      await tester.pumpWidget(WorkoutScope(
        store: store,
        child: MaterialApp(
          home: Builder(builder: (context) => Text('${context.wUnit(100)} · ${context.volume(1000)}')),
        ),
      ));
      expect(find.text('220.5 lb · 2.2k lb'), findsOneWidget);
    });

    testWidgets('satuan diganti selagi sesi terbuka: angka sesi ikut dikonversi', (tester) async {
      // Tanpa konversi, 60 (kg) akan tetap tertulis 60 lalu disimpan sebagai
      // 60 lb = 27 kg.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final store = WorkoutStore();
      await store.load();
      final ex = SessionExercise(
        name: 'Barbell Bench Press',
        icon: Icons.fitness_center,
        config: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, reps: 8, weight: 60),
        sets: const [SetRow(weight: 60, reps: 8)],
        previous: const ['60 × 8'],
        expanded: true,
      );
      await tester.pumpWidget(WorkoutScope(
        store: store,
        child: AppStrings(
          strings: const Strings(AppLanguage.english),
          child: MaterialApp(theme: buildGymTheme(), home: SessionScreen(routineName: 'Push', exercises: [ex])),
        ),
      ));
      await tester.pump();
      expect(find.text('60'), findsWidgets);
      await store.updateSettings(store.settings.copyWith(unit: WeightUnit.lb));
      await tester.pump();
      expect(ex.sets.first.weight, 132.3);
      expect(ex.config.weight, 132.3);
      expect(toKg(ex.sets.first.weight, WeightUnit.lb), closeTo(60, 0.05));
      await tester.pumpWidget(const SizedBox());
    });

    test('alasan target dalam lb ikut diterjemahkan', () {
      const id = Strings(AppLanguage.indonesian);
      expect(id.why('+5 lb — all reps hit last session.'), '+5 lb — semua rep tercapai di sesi lalu.');
    });
  });

  group('tema terang', () {
    test('tema gelap tetap bawaan dan tidak berubah', () {
      final c = buildGymTheme().extension<GymColors>()!;
      expect(c.bg, const Color(0xFF0C0C0F));
      expect(c.isLight, isFalse);
    });

    test('teks terbaca di tema terang (≥ 4,5:1)', () {
      final c = buildGymTheme(brightness: Brightness.light).extension<GymColors>()!;
      expect(c.isLight, isTrue);
      expect(_contrast(c.text, c.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(c.text2, c.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(c.doneInk, c.doneBg), greaterThanOrEqualTo(4.5));
    });

    test('tema gelap: isian tombol tiap aksen ≥ 4,5:1 dengan teks putih, aksen terbaca di atas latar', () {
      for (final a in accentChoices) {
        final c = buildGymTheme(accent: a).extension<GymColors>()!;
        expect(_contrast(c.accentFill, c.accentInk), greaterThanOrEqualTo(4.5), reason: a.toString());
        expect(_contrast(c.accent, c.bg), greaterThanOrEqualTo(4.5), reason: a.toString());
        expect(_contrast(c.text2, c.surface), greaterThanOrEqualTo(4.5));
      }
    });

    test('text3 terbaca sebagai teks (≥ 4,5:1) di atas kartu dan latar, di kedua tema', () {
      // Audit anti-slop 001 temuan 5: text3 dulu ≈ 3,5:1 dan disebut
      // "dekoratif", padahal dipakai ±49 label sungguhan. Dijaga di atas
      // surface DAN bg karena label itu ada di kartu maupun langsung di latar.
      for (final b in Brightness.values) {
        final c = buildGymTheme(brightness: b).extension<GymColors>()!;
        expect(_contrast(c.text3, c.surface), greaterThanOrEqualTo(4.5), reason: '$b di atas surface');
        expect(_contrast(c.text3, c.bg), greaterThanOrEqualTo(4.5), reason: '$b di atas bg');
        // Tetap lebih redup dari text2: hierarki teksnya tidak hilang.
        expect(_contrast(c.text3, c.surface), lessThan(_contrast(c.text2, c.surface)), reason: '$b');
      }
    });

    test('setiap pilihan aksen digelapkan cukup untuk teks putih dan untuk tautan di atas putih', () {
      for (final a in [...accentChoices, const Color(0xFFFFD60A)]) {
        final shownAccent = lightAccent(a);
        expect(_contrast(shownAccent, Colors.white), greaterThanOrEqualTo(4.5), reason: a.toString());
        final c = buildGymTheme(accent: a, brightness: Brightness.light).extension<GymColors>()!;
        expect(c.accentBase, a);
        expect(c.accent, shownAccent);
      }
    });
  });
}
