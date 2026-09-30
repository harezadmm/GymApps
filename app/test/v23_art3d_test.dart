/// Penjaga ikon 3D v2.3: berkasnya benar-benar ada dan ringan, dan dua layar
/// yang memakainya (ubin jalan pintas Home, kartu template program) tetap muat
/// di HP 360 dp maupun layar lebar 800 dp.
///
/// Luapan RenderFlex di widget test langsung gagal, jadi memompa layarnya di
/// dua lebar sudah menjadi penjaga tata letak.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/art3d.dart';
import 'package:gymapps/core/motion.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/features/home/home_screen.dart';
import 'package:gymapps/features/onboarding/onboarding_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, Widget home, {Brightness brightness = Brightness.dark}) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        child: MaterialApp(theme: buildGymTheme(brightness: brightness), home: Scaffold(body: home)),
      ),
    );

/// Lebar logis [width] dp dengan rasio piksel 3, tinggi 780 dp.
void _screen(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width * 3, 780 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Lebar dan tinggi kanvas dari header VP8X (WebP dengan alfa), atau null.
(int, int)? _vp8xSize(Uint8List b) {
  if (String.fromCharCodes(b.sublist(12, 16)) != 'VP8X') return null;
  int u24(int o) => b[o] | b[o + 1] << 8 | b[o + 2] << 16;
  return (u24(24) + 1, u24(27) + 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
  });

  group('berkas ikon 3D', () {
    test('setiap Gym3d punya berkas WebP transparan, persegi, dan di bawah 60 KB', () {
      expect(File('pubspec.yaml').readAsStringSync(), contains('assets/3d/'));
      for (final a in Gym3d.values) {
        final f = File(a.asset);
        expect(f.existsSync(), isTrue, reason: a.asset);
        final bytes = f.readAsBytesSync();
        expect(bytes.length, lessThanOrEqualTo(60 * 1024), reason: '${a.asset}: ${bytes.length} B');
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF', reason: a.asset);
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP', reason: a.asset);
        // VP8X membawa bendera alfa; tanpa alfa ikonnya berkotak di kartu.
        final size = _vp8xSize(bytes);
        expect(size, isNotNull, reason: '${a.asset} bukan WebP VP8X (tanpa alfa?)');
        expect(bytes[20] & 0x10, isNonZero, reason: '${a.asset} tanpa kanal alfa');
        expect(size!.$1, size.$2, reason: '${a.asset} tidak persegi: $size');
      }
    });

    test('tidak ada berkas yatim di assets/3d', () {
      // Berkas yang tidak dipakai enum tetap ikut terbundel ke APK.
      final onDisk = {
        for (final f in Directory('assets/3d').listSync().whereType<File>()) f.uri.pathSegments.last,
      };
      expect(onDisk, {for (final a in Gym3d.values) '${a.file}.webp'});
    });

    testWidgets('mesin Flutter bisa mendekode setiap berkasnya', (tester) async {
      await tester.runAsync(() async {
        for (final a in Gym3d.values) {
          final codec = await ui.instantiateImageCodec(File(a.asset).readAsBytesSync());
          final frame = await codec.getNextFrame();
          expect(frame.image.width, frame.image.height, reason: a.asset);
          frame.image.dispose();
          codec.dispose();
        }
      });
    });
  });

  group('Gym3dIcon', () {
    testWidgets('di luar Reveal membawa Reveal sendiri; di dalamnya tidak menambah', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildGymTheme(),
        home: const Scaffold(
          body: Column(children: [
            Gym3dIcon(Gym3d.kettlebell, size: 46),
            Reveal(child: Gym3dIcon(Gym3d.stopwatch, size: 46)),
          ]),
        ),
      ));
      // Satu Reveal milik ikon pertama + satu pembungkus eksplisit.
      expect(find.byType(Reveal), findsNWidgets(2));
      expect(find.descendant(of: find.byType(Reveal).last, matching: find.byType(Reveal)), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('hiasan: tidak muncul di pohon semantik', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        theme: buildGymTheme(),
        home: const Scaffold(body: Center(child: Gym3dIcon(Gym3d.dumbbell))),
      ));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });

    testWidgets('gerak dikurangi: ikon langsung tampil penuh tanpa animasi', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildGymTheme(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Center(child: Gym3dIcon(Gym3d.calendar))),
        ),
      ));
      final fade = tester.widget<FadeTransition>(
          find.descendant(of: find.byType(Reveal), matching: find.byType(FadeTransition)).first);
      expect(fade.opacity.value, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('mendekode seukuran tampilan, bukan 384 px penuh', (tester) async {
      _screen(tester, 360);
      await tester.pumpWidget(MaterialApp(
        theme: buildGymTheme(),
        home: const Scaffold(body: Center(child: Gym3dIcon(Gym3d.grippers, size: 46))),
      ));
      final image = tester.widget<Image>(find.byType(Image));
      // 46 dp × 3 = 138 px.
      expect(image.image, isA<ResizeImage>());
      final resized = image.image as ResizeImage;
      expect(resized.width, 138);
      expect(resized.height, 138);
      expect(image.filterQuality, FilterQuality.medium);
    });
  });

  group('Home', () {
    Future<WorkoutStore> storeWith(WidgetTester tester, {required bool program}) async {
      final store = WorkoutStore();
      await tester.runAsync(() async {
        await ExerciseCatalog.load();
        await store.load('a@x.com');
        if (program) await store.applyTemplate('ppl');
      });
      return store;
    }

    for (final width in [360.0, 800.0]) {
      for (final b in Brightness.values) {
        testWidgets('ubin jalan pintas memakai ikon 3D dan muat di ${width.toInt()} dp (${b.name})', (tester) async {
          _screen(tester, width);
          final store = await storeWith(tester, program: true);
          await tester.pumpWidget(_wrap(store, const HomeScreen(), brightness: b));
          await tester.pumpAndSettle();

          final tiles = {
            'Other session': Gym3d.calendar,
            'Freestyle': Gym3d.stopwatch,
            'Exercise Library': Gym3d.dumbbell,
            'Dashboard': Gym3d.fitnessWatch,
          };
          for (final e in tiles.entries) {
            final label = find.text(e.key);
            await tester.scrollUntilVisible(label, 200, scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
            expect(label, findsOneWidget);
            // Ikonnya di baris yang sama dengan labelnya.
            final row = find.ancestor(of: label, matching: find.byType(Row)).first;
            final icon = find.descendant(of: row, matching: find.byType(Gym3dIcon));
            expect(icon, findsOneWidget, reason: e.key);
            expect(tester.widget<Gym3dIcon>(icon).art, e.value, reason: e.key);
            // Tinggi ubin tetap 70 dp seperti sebelum ikon 3D.
            final tile = find.ancestor(of: label, matching: find.byType(InkWell)).first;
            expect(tester.getSize(tile).height, closeTo(70, 0.5), reason: e.key);
            expect(tester.getRect(icon).right, lessThanOrEqualTo(width), reason: e.key);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('tanpa program ubin "sesi lain" tetap redup dan tidak bisa diketuk', (tester) async {
      _screen(tester, 360);
      final store = await storeWith(tester, program: false);
      await tester.pumpWidget(_wrap(store, const HomeScreen()));
      await tester.pumpAndSettle();

      final label = find.text('Other session');
      await tester.scrollUntilVisible(label, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      final icon = find.ancestor(
          of: find.byWidgetPredicate((w) => w is Gym3dIcon && w.art == Gym3d.calendar),
          matching: find.byType(Opacity));
      expect(tester.widget<Opacity>(icon.first).opacity, 0.45);
      final ink = tester.widget<InkWell>(find.ancestor(of: label, matching: find.byType(InkWell)).first);
      expect(ink.onTap, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('pemilih program', () {
    test('keenam template punya ikon 3D yang berbeda', () {
      final arts = [for (final t in programTemplates) t.art];
      expect(arts.length, 6);
      expect(arts.toSet().length, arts.length);
    });

    for (final width in [360.0, 800.0]) {
      for (final b in Brightness.values) {
        testWidgets('kartu template muat di ${width.toInt()} dp dengan ikon masing-masing (${b.name})',
            (tester) async {
          _screen(tester, width);
          SharedPreferences.setMockInitialValues({});
          final store = WorkoutStore();
          await tester.runAsync(store.load);
          ProgramTemplate? picked;
          await tester.pumpWidget(_wrap(
            store,
            ProgramPickerScreen(onContinue: (t) => picked = t, onBuildOwn: () {}),
            brightness: b,
          ));
          await tester.pumpAndSettle();

          final list = find.byType(Scrollable).first;
          for (final t in programTemplates) {
            final title = find.text(t.name);
            await tester.scrollUntilVisible(title, 150, scrollable: list);
            await tester.pumpAndSettle();
            final card = find.ancestor(of: title, matching: find.byType(Material)).first;
            final icon = find.descendant(of: card, matching: find.byType(Gym3dIcon));
            expect(icon, findsOneWidget, reason: t.name);
            expect(tester.widget<Gym3dIcon>(icon).art, t.art, reason: t.name);
            expect(tester.getRect(icon).right, lessThan(tester.getRect(title).left), reason: t.name);
          }

          // Kolom ikon ikut memilih kartu, bukan area mati.
          final last = programTemplates.last;
          final lastIcon = find.byWidgetPredicate((w) => w is Gym3dIcon && w.art == last.art);
          await tester.tap(lastIcon);
          await tester.pumpAndSettle();
          await tester.tap(find.text('CONTINUE'));
          expect(picked?.id, last.id);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
