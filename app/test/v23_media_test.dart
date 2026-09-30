/// Gambar dan animasi gerakan di library (FR-C1) dan layar galat katalog
/// yang ramah.
///
/// Yang dijaga: URL media dirakit dari nama berkas di aset dan null untuk
/// gerakan custom; setelan `showExerciseMedia` tersimpan, tergabung per
/// kolom, dan saat mati tidak ada satu pun NetworkImage — dibuktikan lewat
/// klien HTTP penghitung, bukan hanya dari pohon widget; URL yang gagal
/// tidak diminta lagi di rebuild berikutnya; dan katalog yang gagal dibaca
/// menampilkan kalimat ramah tanpa isi exception, dengan "Coba lagi" yang
/// benar-benar memuat ulang.
///
/// HttpClient bawaan flutter_test menjawab 400 untuk semua permintaan, jadi
/// setiap gambar di sini menempuh jalur gagal — persis keadaan offline.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/strings_media.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/settings.dart';
import 'package:gymapps/features/library/exercise_media.dart';
import 'package:gymapps/features/library/library_screen.dart';
import 'package:gymapps/features/profile/profile_screen.dart';
import 'package:gymapps/features/session/exercise_history_sheet.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _base = 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@7455efae41b330c265e7cd4b78dfa848e7ce5ebd';
const _benchJpg = '$_base/images/0025-EIeI8Vf.jpg';
const _benchGif = '$_base/videos/0025-EIeI8Vf.gif';

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

/// Pump berjangka: permintaan gambar tiruan selesai lewat microtask, lalu
/// Image butuh satu frame lagi untuk menggambar errorBuilder-nya. Bukan
/// pumpAndSettle — timer sesi dan pemutar kecil tidak pernah "tenang".
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Katalog dibaca dari aset lewat I/O sungguhan, yang tidak pernah selesai di
/// dalam zona waktu palsu widget test; dimuat sekali lewat `runAsync`.
Future<ExerciseCatalog> _catalog(WidgetTester tester) async => (await tester.runAsync(ExerciseCatalog.load))!;

/// URL sebuah Image yang sumbernya jaringan — langsung atau di balik
/// ResizeImage (cacheWidth/cacheHeight). null untuk sumber lain.
String? _urlOf(Image w) {
  final p = w.image;
  final inner = p is ResizeImage ? p.imageProvider : p;
  return inner is NetworkImage ? inner.url : null;
}

Finder _networkImages() => find.byWidgetPredicate((w) => w is Image && _urlOf(w) != null);

/// Klien HTTP yang mencatat URL yang diminta NetworkImage, lalu meneruskan
/// ke klien tiruan flutter_test (jawabannya selalu 400). NetworkImage hanya
/// memanggil [getUrl]; anggota lain tidak diperlukan.
class _CountingHttpClient implements HttpClient {
  _CountingHttpClient() : _inner = HttpClient();

  final HttpClient _inner;
  final requested = <String>[];

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    requested.add(url.toString());
    return _inner.getUrl(url);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// Pasang [_CountingHttpClient] untuk NetworkImage selama [body]. Dilepas di
/// akhir badan test, bukan di tearDown: pemeriksaan invarian flutter_test
/// menolak variabel debug painting yang masih terisi saat badan test selesai.
Future<void> _countRequests(Future<void> Function(List<String> requested) body) async {
  final client = _CountingHttpClient();
  debugNetworkImageHttpClientProvider = () => client;
  try {
    await body(client.requested);
  } finally {
    debugNetworkImageHttpClientProvider = null;
  }
}

/// Bench press di sesi, dengan ikon yang tidak dipakai widget lain di layar
/// supaya cadangannya bisa dihitung.
SessionExercise _sessionBench() => SessionExercise(
      name: 'Barbell Bench Press',
      icon: Icons.ac_unit,
      equipment: 'barbell',
      config: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, sets: 2, reps: 8, weight: 60),
      sets: const [SetRow(weight: 60, reps: 8), SetRow(weight: 60, reps: 8)],
      previous: const ['—', '—'],
      expanded: true,
    );

Widget _profile(AppLanguage lang) => Scaffold(
      body: ProfileScreen(language: lang, onLanguageChanged: (_) {}, onSignOut: () {}, email: 'a@x.com'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
    ExerciseMedia.retryAll();
    store = WorkoutStore();
    await store.load();
  });

  group('URL media', () {
    test('gerakan bawaan: URL gambar dan GIF dari nama berkas; custom dan tanpa berkas: null', () {
      final e = Exercise.fromJson({
        'id': '0001', 'n': '3/4 sit-up', 'bp': 'waist', 'eq': 'body weight', 'tg': 'abs',
        'img': '0001-2gPfomN.jpg', 'gif': '0001-2gPfomN.gif',
      });
      expect(e.image, '0001-2gPfomN.jpg');
      expect(e.gif, '0001-2gPfomN.gif');
      expect(e.imageUrl, '$_base/images/0001-2gPfomN.jpg');
      expect(e.gifUrl, '$_base/videos/0001-2gPfomN.gif');
      // Bentuk aset dipertahankan: pulang-pergi lewat toJson.
      expect(e.toJson()['img'], '0001-2gPfomN.jpg');
      expect(e.toJson()['gif'], '0001-2gPfomN.gif');
      final back = Exercise.fromJson(e.toJson());
      expect(back.imageUrl, e.imageUrl);
      expect(back.gifUrl, e.gifUrl);
      // Custom tidak punya media, bahkan kalau dokumennya kebetulan membawa kuncinya.
      final custom = Exercise.fromJson({
        'id': 'custom-1', 'n': 'Meadows Row', 'bp': 'back', 'eq': 'barbell', 'tg': 'lats',
        'custom': true, 'img': 'x.jpg', 'gif': 'x.gif',
      });
      expect(custom.imageUrl, isNull);
      expect(custom.gifUrl, isNull);
      // Tanpa berkas, nilai kosong, atau bukan teks: null — bukan URL rusak.
      final bare = Exercise.fromJson({
        'id': '0002', 'n': 'x', 'bp': 'waist', 'eq': 'body weight', 'tg': 'abs', 'img': '', 'gif': 3,
      });
      expect(bare.imageUrl, isNull);
      expect(bare.gifUrl, isNull);
      expect(bare.toJson().containsKey('img'), isFalse);
      expect(bare.toJson().containsKey('gif'), isFalse);
    });

    testWidgets('katalog asli: 1.324 gerakan bawaan semua punya gambar dan GIF; lookup statis menemukannya',
        (tester) async {
      final catalog = await _catalog(tester);
      final builtin = [for (final e in catalog.all) if (!e.custom) e];
      expect(builtin.length, 1324);
      expect(builtin.every((e) => e.imageUrl != null && e.gifUrl != null), isTrue);
      expect(ExerciseCatalog.lookup('0025')?.imageUrl, _benchJpg);
      expect(ExerciseCatalog.lookup('0025')?.gifUrl, _benchGif);
      expect(ExerciseCatalog.lookup('tidak-ada'), isNull);
    });

    test('teks dua bahasa', () {
      const id = Strings(AppLanguage.indonesian);
      const en = Strings(AppLanguage.english);
      expect(id.showExerciseMedia, 'Gambar & animasi gerakan');
      expect(en.showExerciseMedia, 'Exercise images & animations');
      expect(id.tryAgain, 'Coba lagi');
      expect(en.tryAgain, 'Try again');
    });
  });

  group('setelan showExerciseMedia', () {
    test('bawaan nyala, hanya ditulis saat mati, dan dibaca ulang', () {
      const s = TrainingSettings();
      expect(s.showExerciseMedia, isTrue);
      expect(s.toJson().containsKey('media'), isFalse);
      final off = s.copyWith(showExerciseMedia: false);
      expect(off.toJson()['media'], false);
      expect(TrainingSettings.fromJson(off.toJson()).showExerciseMedia, isFalse);
      expect(TrainingSettings.fromJson(const {}).showExerciseMedia, isTrue);
      // Nilai aneh dari dokumen versi lain: hanya `false` yang mematikan.
      expect(TrainingSettings.fromJson(const {'media': 'off'}).showExerciseMedia, isTrue);
      expect(off.copyWith(unit: WeightUnit.lb).showExerciseMedia, isFalse, reason: 'copyWith tidak menyalakan lagi');
    });

    test('gabung per kolom: dimatikan di sini menang; dinyalakan lagi di server ikut', () {
      final off = WorkoutStore.mergeSettings(base: const {}, mine: const {'media': false}, theirs: const {});
      expect(off['media'], false);
      final on = WorkoutStore.mergeSettings(base: const {'media': false}, mine: const {'media': false}, theirs: const {});
      expect(on.containsKey('media'), isFalse, reason: 'server menghapus kuncinya, di sini tidak disentuh = nyala');
      final theirsOff = WorkoutStore.mergeSettings(base: const {}, mine: const {}, theirs: const {'media': false});
      expect(theirsOff['media'], false);
      expect(TrainingSettings.fromJson(theirsOff).showExerciseMedia, isFalse);
    });

    test('tersimpan ke disk dan dibaca ulang', () async {
      final a = WorkoutStore();
      await a.load('a@x.com');
      await a.updateSettings(a.settings.copyWith(showExerciseMedia: false));
      final b = WorkoutStore();
      await b.load('a@x.com');
      expect(b.settings.showExerciseMedia, isFalse);
    });
  });

  group('library', () {
    testWidgets('setelan mati: tidak ada NetworkImage dan nol permintaan; nyala: satu permintaan per URL, gagal → ikon',
        (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.updateSettings(store.settings.copyWith(showExerciseMedia: false));
      await _countRequests((requested) async {
        await tester.pumpWidget(_wrap(store, const ExerciseLibraryScreen()));
        await _settle(tester);
        expect(find.byType(Image), findsNothing);
        expect(find.byType(ExerciseThumb), findsWidgets, reason: 'barisnya tetap lewat widget yang sama');
        expect(requested, isEmpty);
        expect(tester.takeException(), isNull);
      });

      await store.updateSettings(store.settings.copyWith(showExerciseMedia: true));
      await _countRequests((requested) async {
        await tester.pump();
        expect(_networkImages(), findsWidgets);
        final first = _urlOf(tester.widget<Image>(_networkImages().first))!;
        expect(first, startsWith('$_base/images/'));
        expect(first, endsWith('.jpg'));
        expect(requested, contains(first));
        // 400 dari klien tiruan: dicatat gagal, ikon alat tetap, tanpa exception.
        await _settle(tester);
        expect(ExerciseMedia.hasFailed(first), isTrue);
        expect(find.byType(IconDisc), findsWidgets);
        expect(tester.takeException(), isNull);
        // Rebuild daftar (mengetik) tidak meminta ulang URL yang sudah gagal:
        // setiap URL tepat sekali, dan baris yang gagal kembali tanpa Image.
        final seen = requested.length;
        await tester.enterText(find.byType(TextField), 'sit-up');
        await _settle(tester);
        await tester.enterText(find.byType(TextField), 'sit-up ');
        await _settle(tester);
        expect(requested.toSet().length, requested.length, reason: 'satu permintaan per URL');
        expect(requested.length, greaterThanOrEqualTo(seen));
        expect(find.byType(ExerciseThumb), findsWidgets);
        expect(_networkImages(), findsNothing, reason: 'semua URL yang tampil sudah gagal dan dicatat');
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('URL yang gagal tidak diminta lagi oleh widget baru; retryAll mencobanya tepat sekali lagi',
        (tester) async {
      Widget thumb(Key key) => _wrap(
            store,
            Scaffold(
              body: Center(
                child: ExerciseThumb(key: key, url: _benchJpg, fallback: const IconDisc(Icons.ac_unit)),
              ),
            ),
          );
      await _countRequests((requested) async {
        await tester.pumpWidget(thumb(const ValueKey(1)));
        await _settle(tester);
        expect(requested, [_benchJpg]);
        expect(ExerciseMedia.hasFailed(_benchJpg), isTrue);
        expect(find.byIcon(Icons.ac_unit), findsOneWidget, reason: 'ikon cadangan');
        // Widget baru dengan URL yang sama: cadangan langsung, tanpa permintaan.
        await tester.pumpWidget(thumb(const ValueKey(2)));
        await _settle(tester);
        expect(requested, [_benchJpg]);
        expect(find.byType(Image), findsNothing);
        expect(find.byIcon(Icons.ac_unit), findsOneWidget);
        // Library dibuka lagi (retryAll): dicoba sekali lagi — sekali.
        ExerciseMedia.retryAll();
        await tester.pumpWidget(thumb(const ValueKey(3)));
        await _settle(tester);
        expect(requested, [_benchJpg, _benchJpg]);
        await tester.pumpWidget(thumb(const ValueKey(4)));
        await _settle(tester);
        expect(requested, [_benchJpg, _benchJpg]);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('detail gerakan: animasi di atas; gagal → placeholder ikon dengan satu kalimat, tanpa teks galat',
        (tester) async {
      _phone(tester);
      await _catalog(tester);
      await _countRequests((requested) async {
        await tester.pumpWidget(_wrap(store, const ExerciseLibraryScreen()));
        await _settle(tester);
        await tester.enterText(find.byType(TextField), 'barbell bench press');
        await _settle(tester);
        await tester.tap(find.text('Barbell Bench Press').first);
        await _settle(tester);
        expect(find.byType(ExerciseAnimation), findsOneWidget);
        expect(requested, contains(_benchGif));
        expect(find.text('Animation unavailable offline'), findsOneWidget);
        expect(find.textContaining('Exception'), findsNothing);
        expect(find.textContaining('400'), findsNothing);
        expect(find.text('History & records'), findsOneWidget, reason: 'detail lainnya tetap ada');
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('gerak dikurangi: detail memakai gambar diam, bukan GIF', (tester) async {
      _phone(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _catalog(tester);
      await _countRequests((requested) async {
        await tester.pumpWidget(_wrap(store, const ExerciseLibraryScreen()));
        await _settle(tester);
        await tester.enterText(find.byType(TextField), 'barbell bench press');
        await _settle(tester);
        await tester.tap(find.text('Barbell Bench Press').first);
        await _settle(tester);
        expect(find.byType(ExerciseAnimation), findsOneWidget);
        expect(requested, contains(_benchJpg));
        expect(requested, isNot(contains(_benchGif)));
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('setelan mati: detail tanpa animasi dan tanpa permintaan', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.updateSettings(store.settings.copyWith(showExerciseMedia: false));
      await _countRequests((requested) async {
        await tester.pumpWidget(_wrap(store, const ExerciseLibraryScreen()));
        await _settle(tester);
        await tester.enterText(find.byType(TextField), 'barbell bench press');
        await _settle(tester);
        await tester.tap(find.text('Barbell Bench Press').first);
        await _settle(tester);
        expect(find.byType(ExerciseAnimation), findsNothing);
        expect(find.byType(Image), findsNothing);
        expect(find.text('History & records'), findsOneWidget);
        expect(requested, isEmpty);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('katalog gagal dibaca: kalimat ramah tanpa isi exception, dan "Coba lagi" memuat ulang',
        (tester) async {
      _phone(tester);
      // Teks katalog asli dibaca sekali lewat I/O nyata; "Coba lagi" nanti
      // dipenuhi dari teks ini tanpa I/O, supaya selesai di zona waktu palsu.
      final json = (await tester.runAsync(() => rootBundle.loadString('assets/data/exercises.json')))!;
      ExerciseCatalog.resetForTest();
      ExerciseCatalog.readAsset = () async => throw const FormatException('aset rusak (sengaja)');
      addTearDown(() {
        ExerciseCatalog.readAsset = null;
        ExerciseCatalog.resetForTest();
      });
      await tester.pumpWidget(_wrap(store, const ExerciseLibraryScreen()));
      await _settle(tester);
      expect(find.text('Could not read the exercise catalogue.'), findsOneWidget);
      expect(find.textContaining('FormatException'), findsNothing);
      expect(find.textContaining('sengaja'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.getSize(find.byType(GymButton)).height, greaterThanOrEqualTo(44), reason: 'NFR-11');
      expect(tester.takeException(), isNull);

      // Masih gagal: tetap ramah, tombolnya tetap ada.
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(find.text('Could not read the exercise catalogue.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      ExerciseCatalog.readAsset = () async => json;
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(find.text('Could not read the exercise catalogue.'), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('3/4 Sit-up'), findsOneWidget, reason: 'daftar tampil setelah muat ulang');
      expect(tester.takeException(), isNull);
    });
  });

  group('kartu sesi dan lembar riwayat', () {
    testWidgets('kartu sesi: thumbnail di samping nama saat media nyala; mati → ikon saja, nol permintaan',
        (tester) async {
      _phone(tester);
      await _catalog(tester);
      await _countRequests((requested) async {
        await tester.pumpWidget(
            _wrap(store, SessionScreen(key: UniqueKey(), routineName: 'Push', exercises: [_sessionBench()])));
        await _settle(tester);
        expect(requested, [_benchJpg]);
        expect(find.byIcon(Icons.ac_unit), findsOneWidget, reason: 'ikon cadangan tetap ada');
        expect(tester.takeException(), isNull);
      });

      await store.updateSettings(store.settings.copyWith(showExerciseMedia: false));
      ExerciseMedia.retryAll();
      await _countRequests((requested) async {
        await tester.pumpWidget(
            _wrap(store, SessionScreen(key: UniqueKey(), routineName: 'Push', exercises: [_sessionBench()])));
        await _settle(tester);
        expect(requested, isEmpty);
        expect(find.byType(Image), findsNothing);
        expect(find.byIcon(Icons.ac_unit), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('lembar riwayat: thumbnail di samping nama gerakan', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await _countRequests((requested) async {
        await tester.pumpWidget(_wrap(
          store,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showExerciseHistory(context, exerciseId: '0025', name: 'Barbell Bench Press'),
                child: const Text('open'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await _settle(tester);
        expect(find.text('Barbell Bench Press'), findsOneWidget);
        expect(find.byType(ExerciseThumb), findsOneWidget);
        expect(requested, [_benchJpg]);
        expect(tester.takeException(), isNull);
      });
    });
  });

  group('Profil', () {
    testWidgets('saklar mematikan dan menyalakan setelan akun, dengan catatan di bawahnya', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(store, _profile(AppLanguage.english)));
      await tester.pumpAndSettle();
      final label = find.text('Exercise images & animations');
      await tester.scrollUntilVisible(label, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('Downloaded from the internet when shown; skipped while offline.'), findsOneWidget);
      final toggle = find.descendant(
        of: find.ancestor(of: label, matching: find.byType(SettingsTile)),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(store.settings.showExerciseMedia, isFalse);
      expect(tester.widget<Switch>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(store.settings.showExerciseMedia, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('[id] label dan catatan dalam bahasa Indonesia', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(store, _profile(AppLanguage.indonesian), lang: AppLanguage.indonesian));
      await tester.pumpAndSettle();
      final label = find.text('Gambar & animasi gerakan');
      await tester.scrollUntilVisible(label, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('Diunduh dari internet saat ditampilkan; dilewati saat offline.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
