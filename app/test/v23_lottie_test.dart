/// v2.3 — animasi Lottie IconScout (`core/lottie_art.dart`).
///
/// Yang dijaga:
/// * berkasnya ada, terbaca sebagai Lottie, kecil, tanpa gambar raster, dan
///   warnanya dari palet "GymApps" — bukan #26262C yang hilang di kartu gelap;
/// * ringkasan sesi dan layar istirahat tetap muat di HP 360 dp;
/// * perayaan diputar sekali lalu diam di bingkai terakhir, jam pasir hanya
///   berulang selama istirahat berjalan, dan "kurangi gerak" membuat semuanya
///   satu bingkai diam.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/lottie_art.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/features/session/finish_screen.dart';
import 'package:gymapps/features/session/rest_screen.dart';
import 'package:gymapps/features/session/rest_timer.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Palet IconScout 824060 tanpa #26262C: warna itu sama dengan surface2 dan
/// tidak terlihat di atas kartu gelap.
const _palette = [0x8F7FFF, 0x6A5AE6, 0x4ADE80, 0xFFA94D, 0xFF5FB0];

/// Semua warna statis dan keyframe `"c":{"k":[r,g,b,a]}` di satu berkas.
List<List<num>> _colors(Object? node) {
  final out = <List<num>>[];
  void walk(Object? o) {
    if (o is Map) {
      final c = o['c'];
      if ((o['ty'] == 'fl' || o['ty'] == 'st') && c is Map) {
        final k = c['k'];
        if (k is List && k.isNotEmpty && k.first is num) {
          out.add(k.cast<num>());
        } else if (k is List) {
          for (final kf in k) {
            if (kf is Map && kf['s'] is List) out.add((kf['s'] as List).cast<num>());
          }
        }
      }
      o.values.forEach(walk);
    } else if (o is List) {
      o.forEach(walk);
    }
  }

  walk(node);
  return out;
}

bool _inPalette(List<num> c) => _palette.any(
      (rgb) =>
          ((c[0] * 255).round() - (rgb >> 16 & 0xFF)).abs() <= 2 &&
          ((c[1] * 255).round() - (rgb >> 8 & 0xFF)).abs() <= 2 &&
          ((c[2] * 255).round() - (rgb & 0xFF)).abs() <= 2,
    );

Widget _wrap(WorkoutStore store, Widget home, {bool reduceMotion = false, Brightness brightness = Brightness.dark}) =>
    WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        child: MaterialApp(
          theme: buildGymTheme(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: home,
        ),
      ),
    );

/// HP kecil yang umum: 360 × 780 dp.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Controller yang dipegang [GymLottieView] untuk satu animasi di layar.
AnimationController _controllerOf(WidgetTester tester, GymLottie art) {
  final lottie = tester.widget<Lottie>(
    find.descendant(
      of: find.byWidgetPredicate((w) => w is GymLottieView && w.art == art),
      matching: find.byType(Lottie),
    ),
  );
  return lottie.controller! as AnimationController;
}

/// Bench press dengan set kerja tercentang dan riwayat kosong: rekor pertama,
/// jadi kartu rekor ikut tampil.
SessionExercise _bench() => SessionExercise(
      name: 'Barbell Bench Press',
      icon: Icons.fitness_center,
      config: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, sets: 2, reps: 8, weight: 60),
      sets: const [SetRow(weight: 60, reps: 8, done: true), SetRow(weight: 62.5, reps: 8, done: true)],
      previous: const ['—', '—'],
    );

FinishScreen _finish() => FinishScreen(
      // Nama panjang sengaja: kolom judul berbagi baris dengan popper 96 dp.
      routineName: 'Upper Body Power — Heavy Day',
      exercises: [_bench()],
      history: const [],
      elapsed: const Duration(minutes: 42, seconds: 10),
      dateLabel: 'Wed, 30 Sep',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('berkas Lottie', () {
    test('terdaftar di pubspec', () {
      expect(File('pubspec.yaml').readAsStringSync(), contains('assets/lottie/'));
    });

    for (final art in GymLottie.values) {
      test('${art.file}: ada, terbaca, kecil, tanpa gambar, warna dari palet', () {
        final file = File(art.asset);
        expect(file.existsSync(), isTrue, reason: art.asset);
        final bytes = file.readAsBytesSync();
        expect(bytes.length, lessThan(150 * 1024), reason: 'berkas Lottie harus < 150 KB');

        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        // Aset gambar ("p"/"u") berarti raster tertanam: berat, tidak ikut
        // warna tema, dan buram di layar 3×.
        for (final a in (json['assets'] as List? ?? const [])) {
          final m = a as Map<String, dynamic>;
          expect(m.containsKey('p') || m.containsKey('u'), isFalse, reason: 'gambar tertanam di ${art.file}');
        }

        final colors = _colors(json);
        expect(colors, isNotEmpty);
        for (final c in colors) {
          expect(_inPalette(c), isTrue, reason: '${art.file}: warna $c bukan dari palet GymApps');
        }

        final composition = LottieComposition.parseJsonBytes(bytes);
        expect(composition.images, isEmpty);
        expect(composition.duration, greaterThan(Duration.zero));
        // Tebal garis minimum dihitung dari kanvas ini.
        expect(composition.bounds.width, GymLottie.canvas);
        expect(composition.bounds.height, GymLottie.canvas);
      });
    }
  });

  group('ringkasan sesi', () {
    late WorkoutStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = WorkoutStore();
      await store.load();
    });

    for (final brightness in Brightness.values) {
      testWidgets('muat di 360 dp (${brightness.name}); popper dan piala diputar sekali lalu diam', (tester) async {
        _phone(tester);
        await tester.pumpWidget(_wrap(store, _finish(), brightness: brightness));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        expect(find.byWidgetPredicate((w) => w is GymLottieView && w.art == GymLottie.sessionDone), findsOneWidget);
        expect(find.byWidgetPredicate((w) => w is GymLottieView && w.art == GymLottie.newRecord), findsOneWidget);
        final done = _controllerOf(tester, GymLottie.sessionDone);
        final record = _controllerOf(tester, GymLottie.newRecord);
        expect(done.isAnimating, isTrue);
        expect(record.isAnimating, isTrue);

        // Lebih lama dari animasi terpanjang (piala 2,6 detik).
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 100));
        expect(done.isAnimating, isFalse, reason: 'perayaan tidak berulang');
        expect(done.value, GymLottie.sessionDone.end, reason: 'berhenti di puncak letusan');
        expect(record.isAnimating, isFalse);
        expect(record.value, GymLottie.newRecord.end);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('kurangi gerak: bingkai terakhir langsung, tanpa gerak', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(store, _finish(), reduceMotion: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      for (final art in [GymLottie.sessionDone, GymLottie.newRecord]) {
        final c = _controllerOf(tester, art);
        expect(c.isAnimating, isFalse, reason: art.name);
        expect(c.value, art.still, reason: art.name);
      }
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('layar istirahat', () {
    late WorkoutStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = WorkoutStore();
      await store.load();
    });

    Future<RestTimer> open(WidgetTester tester, {bool reduceMotion = false}) async {
      final timer = RestTimer()..start(const Duration(seconds: 90));
      await tester.pumpWidget(_wrap(
        store,
        RestScreen(
          timer: timer,
          exerciseName: 'Barbell Bench Press',
          nextLabel: 'Next: set 2 · 60 kg × 8',
          onEditDuration: () async {},
        ),
        reduceMotion: reduceMotion,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      return timer;
    }

    Future<void> close(WidgetTester tester, RestTimer timer) async {
      await tester.pumpWidget(const SizedBox());
      timer.skip();
      timer.dispose();
    }

    testWidgets('muat di 360 dp; jam pasir berulang selama istirahat berjalan', (tester) async {
      _phone(tester);
      final timer = await open(tester);
      expect(tester.takeException(), isNull);
      final hourglass = _controllerOf(tester, GymLottie.resting);
      expect(hourglass.isAnimating, isTrue);
      await tester.pump(const Duration(seconds: 6));
      // Masih berputar setelah satu putaran penuh (±5,3 detik diperlambat).
      expect(hourglass.isAnimating, isTrue);
      // Tidak ada yang keluar dari layar di kanan kepala layar.
      final box = tester.getRect(find.byType(GymLottieView));
      expect(box.right, lessThanOrEqualTo(360));
      await close(tester, timer);
    });

    testWidgets('kurangi gerak: jam pasir diam tegak', (tester) async {
      _phone(tester);
      final timer = await open(tester, reduceMotion: true);
      expect(tester.takeException(), isNull);
      final hourglass = _controllerOf(tester, GymLottie.resting);
      expect(hourglass.isAnimating, isFalse);
      expect(hourglass.value, GymLottie.resting.still);
      await tester.pump(const Duration(seconds: 2));
      expect(hourglass.isAnimating, isFalse);
      await close(tester, timer);
    });
  });
}
