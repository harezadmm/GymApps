/// Layar Recap (v3.1): KPI dengan pembanding, navigasi periode, mingguan ↔
/// bulanan, konsistensi, progres beban & rep, rekor, set per otot, periode
/// kosong, dan kartu Analisis AI dengan semua keadaannya.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/backend.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/recap_ai.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/recap.dart';
import 'package:gymapps/features/recap/recap_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend yang selalu menerima dorongan — cukup supaya akun dianggap
/// tersambung ke server (`hasBackend`).
class _StubBackend implements Backend {
  @override
  String? get signedInEmail => null;
  @override
  Future<int?> getRev() async => null;
  @override
  Future<PulledState?> pull() async => null;
  @override
  Future<PushResult> push({required int? baseRev, required Map<String, dynamic> state}) async =>
      const PushAccepted(1);
}

class _FakeAnalyzer implements RecapAnalyzer {
  int calls = 0;
  Map<String, dynamic>? lastPayload;
  Completer<RecapAnalysis>? pending;
  Object? error;

  @override
  Future<RecapAnalysis> analyze(Map<String, dynamic> payload) {
    calls++;
    lastPayload = payload;
    if (error != null) return Future.error(error!);
    pending = Completer<RecapAnalysis>();
    return pending!.future;
  }
}

final _analysis = RecapAnalysis(
  headline: 'Bench naik, kaki perlu dikejar',
  summary: 'Tiga sesi minggu ini, satu lebih banyak dari minggu lalu.',
  strengths: const ['Barbell Bench Press 60x8 → 62.5x8.'],
  critiques: const ['Barbell Full Squat tertahan di 80x5.'],
  suggestions: const [RecapSuggestion(title: 'Tambah set kaki', detail: 'Tambahkan 3 set leg press.')],
  nextFocus: 'Kejar 6 rep di squat.',
  model: 'gemini-2.5-flash',
  createdAt: DateTime(2026, 10, 9, 10, 42),
);

final _today = DateTime(2026, 10, 9, 18, 0);

const _benchTarget = ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.double_, reps: 10, repsMin: 6);

SetRow _s(double w, int r, {SetPhase phase = SetPhase.work}) => SetRow(weight: w, reps: r, done: true, phase: phase);

Future<void> _seed(WorkoutStore store) async {
  Future<void> add(String date, List<WorkoutEntry> entries, {int? dur, String? routine}) =>
      store.addWorkout(Workout(date: date, entries: entries, durationSeconds: dur, routine: routine));
  await add('2026-09-20', [WorkoutEntry(exerciseId: '0025', sets: [_s(65, 5)])]);
  await add('2026-09-29', [WorkoutEntry(exerciseId: '0025', target: _benchTarget, sets: [_s(60, 8), _s(60, 8), _s(60, 8)])],
      dur: 3000, routine: 'Push');
  await add('2026-10-02', [WorkoutEntry(exerciseId: '0043', sets: [_s(80, 5), _s(80, 5), _s(80, 5), _s(80, 5)])], dur: 2700);
  await add('2026-10-05', [
    WorkoutEntry(
        exerciseId: '0025',
        target: _benchTarget,
        sets: [_s(40, 10, phase: SetPhase.warmup), _s(62.5, 8), _s(62.5, 8), _s(62.5, 7)]),
  ], dur: 3300, routine: 'Push');
  await add('2026-10-07', [WorkoutEntry(exerciseId: '0043', sets: [_s(80, 5), _s(80, 5), _s(80, 4), _s(80, 4)])], dur: 2400);
  await add('2026-10-09', [
    WorkoutEntry(exerciseId: '0025', target: _benchTarget, sets: [_s(62.5, 8), _s(62.5, 8), _s(62.5, 8)]),
    WorkoutEntry(exerciseId: '0150', sets: [_s(55, 12), _s(55, 11), _s(55, 10)]),
  ], dur: 3000);
}

Widget _wrap(WorkoutStore store, Widget home, {Brightness brightness = Brightness.light}) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.indonesian),
        child: MaterialApp(theme: buildGymTheme(brightness: brightness), home: home),
      ),
    );

RecapScreen _screen(_FakeAnalyzer analyzer, {RecapPeriod period = RecapPeriod.week}) =>
    RecapScreen(initialPeriod: period, analyzer: analyzer, today: () => _today);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
}

Finder _scroll() => find.byType(Scrollable).first;

Future<WorkoutStore> _store(WidgetTester tester, {bool server = true, bool seed = true}) async {
  final store = WorkoutStore(server ? _StubBackend() : null);
  await tester.runAsync(() async {
    await ExerciseCatalog.load();
    await store.load('a@x.com');
    if (seed) await _seed(store);
  });
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
  });

  for (final brightness in Brightness.values) {
    testWidgets('mingguan (${brightness.name}): KPI + pembanding, AI siap, konsistensi, progres, rekor, otot',
        (tester) async {
      _phone(tester);
      final store = await _store(tester);
      await tester.pumpWidget(_wrap(store, _screen(_FakeAnalyzer()), brightness: brightness));
      await _settle(tester);
      expect(tester.takeException(), isNull);

      expect(find.text('Recap'), findsOneWidget);
      expect(find.text('5 – 11 Okt'), findsOneWidget);
      expect(find.text('Minggu ini'), findsOneWidget);
      for (final label in ['Sesi', 'Volume', 'Waktu latihan', 'Set kerja']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('3'), findsWidgets);
      expect(find.widgetWithText(ChangePill, '+1'), findsOneWidget);
      expect(find.text('2 j 25 mnt'), findsOneWidget);
      expect(find.widgetWithText(ChangePill, '+50 mnt'), findsOneWidget);
      expect(find.widgetWithText(ChangePill, '+6'), findsOneWidget);
      expect(find.widgetWithText(ChangePill, '+104%'), findsOneWidget);
      expect(find.text('Dibanding 5 hari pertama minggu lalu'), findsOneWidget);

      expect(find.text('Analisis AI'), findsOneWidget);
      expect(find.widgetWithText(GymButton, 'Analisis sekarang'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Konsistensi'), 200, scrollable: _scroll());
      expect(find.text('3 dari 7 hari'), findsOneWidget);
      expect(find.textContaining('rata-rata 48 mnt per sesi'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Progres beban & rep'), 200, scrollable: _scroll());
      await tester.scrollUntilVisible(find.text('60 kg × 8 → 62.5 kg × 8'), 200, scrollable: _scroll());
      expect(find.widgetWithText(ChangePill, '+3.2 kg'), findsOneWidget);
      expect(find.text('Pertama kali · 55 kg × 12'), findsOneWidget);
      expect(find.widgetWithText(ChangePill, 'baru'), findsOneWidget);
      expect(find.widgetWithText(ChangePill, 'tahan'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Rekor baru'), 200, scrollable: _scroll());
      await tester.scrollUntilVisible(find.text('Set kerja per otot'), 200, scrollable: _scroll());
      expect(find.text('6 set'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('navigasi periode: ‹ ke minggu lalu, › mati di minggu ini', (tester) async {
    _phone(tester);
    final store = await _store(tester);
    await tester.pumpWidget(_wrap(store, _screen(_FakeAnalyzer())));
    await _settle(tester);
    expect(tester.widget<GlassIconButton>(find.byKey(const ValueKey('recap-next'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('recap-prev')));
    await _settle(tester);
    expect(find.text('28 Sep – 4 Okt'), findsOneWidget);
    expect(find.text('Minggu lalu'), findsOneWidget);
    expect(tester.widget<GlassIconButton>(find.byKey(const ValueKey('recap-next'))).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('recap-next')));
    await _settle(tester);
    expect(find.text('5 – 11 Okt'), findsOneWidget);
  });

  testWidgets('bulanan: Oktober 2026 berjalan, 4 sesi vs 9 hari pertama September (0), volume per minggu',
      (tester) async {
    _phone(tester);
    final store = await _store(tester);
    await tester.pumpWidget(_wrap(store, _screen(_FakeAnalyzer())));
    await _settle(tester);
    await tester.tap(find.text('Bulanan'));
    await _settle(tester);
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(find.text('Bulan ini'), findsOneWidget);
    expect(find.widgetWithText(ChangePill, '+4'), findsOneWidget);
    expect(find.text('Dibanding 9 hari pertama bulan lalu'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Volume per minggu'), 200, scrollable: _scroll());
    expect(find.text('Volume per minggu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('periode kosong: EmptyState, tanpa kartu AI', (tester) async {
    _phone(tester);
    final store = await _store(tester, seed: false);
    await tester.pumpWidget(_wrap(store, _screen(_FakeAnalyzer())));
    await _settle(tester);
    expect(find.text('Belum ada sesi minggu ini'), findsOneWidget);
    expect(find.text('Analisis AI'), findsNothing);
  });

  group('Analisis AI', () {
    testWidgets('siap → memuat → hasil; dibuka ulang memakai cache tanpa memanggil AI', (tester) async {
      _phone(tester);
      final store = await _store(tester);
      final ai = _FakeAnalyzer();
      await tester.pumpWidget(_wrap(store, _screen(ai)));
      await _settle(tester);
      await tester.tap(find.widgetWithText(GymButton, 'Analisis sekarang'));
      await tester.pump();
      expect(find.text('Menganalisis latihanmu…'), findsOneWidget);
      expect(ai.calls, 1);
      expect(ai.lastPayload!['period'], 'week');
      expect(ai.lastPayload!['lang'], 'id');
      expect((ai.lastPayload!['totals'] as Map)['sessions'], 3);

      await tester.runAsync(() async {
        ai.pending!.complete(_analysis);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await _settle(tester);
      expect(find.text('Bench naik, kaki perlu dikejar'), findsOneWidget);
      for (final s in ['Sudah bagus', 'Kritik', 'Saran', 'Fokus berikutnya']) {
        await tester.scrollUntilVisible(find.text(s), 150, scrollable: _scroll());
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.text('Tambah set kaki'), findsOneWidget);
      expect(find.textContaining('gemini-2.5-flash'), findsOneWidget);
      expect(find.text('Analisis ulang'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Buka ulang: hasil dari cache, AI tidak dipanggil lagi.
      await tester.pumpWidget(const SizedBox());
      final again = _FakeAnalyzer();
      await tester.pumpWidget(_wrap(store, _screen(again)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await _settle(tester);
      expect(find.text('Bench naik, kaki perlu dikejar'), findsOneWidget);
      expect(find.text('Datamu berubah sejak analisis ini.'), findsNothing);
      expect(again.calls, 0);
    });

    testWidgets('data berubah sejak analisis: hasil lama tetap tampil dengan tanda', (tester) async {
      _phone(tester);
      final store = await _store(tester);
      final ai = _FakeAnalyzer();
      await tester.pumpWidget(_wrap(store, _screen(ai)));
      await _settle(tester);
      await tester.tap(find.widgetWithText(GymButton, 'Analisis sekarang'));
      await tester.pump();
      await tester.runAsync(() async {
        ai.pending!.complete(_analysis);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await _settle(tester);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => store.addWorkout(Workout(
            date: '2026-10-08',
            entries: [WorkoutEntry(exerciseId: '0150', sets: [_s(57.5, 10)])],
            durationSeconds: 1800,
          )));
      await tester.pumpWidget(_wrap(store, _screen(_FakeAnalyzer())));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await _settle(tester);
      expect(find.text('Bench naik, kaki perlu dikejar'), findsOneWidget);
      expect(find.text('Datamu berubah sejak analisis ini.'), findsOneWidget);
    });

    final cases = {
      RecapAiFailure.limit: 'Batas analisis AI hari ini tercapai. Coba lagi besok.',
      RecapAiFailure.notConnected: 'Analisis AI butuh akun yang tersambung ke server. Buka Profil → Paksa sinkron.',
      RecapAiFailure.busy: 'AI sedang sibuk. Coba lagi sebentar lagi.',
      RecapAiFailure.offline: 'Tidak ada koneksi. Periksa internet lalu coba lagi.',
    };
    for (final MapEntry(key: kind, value: message) in cases.entries) {
      testWidgets('galat ${kind.name} → pesan yang bisa ditindaklanjuti + Coba lagi', (tester) async {
        _phone(tester);
        final store = await _store(tester);
        final ai = _FakeAnalyzer()..error = RecapAiException(kind);
        await tester.pumpWidget(_wrap(store, _screen(ai)));
        await _settle(tester);
        await tester.tap(find.widgetWithText(GymButton, 'Analisis sekarang'));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await _settle(tester);
        expect(find.text(message), findsOneWidget);
        expect(find.widgetWithText(GymButton, 'Coba lagi'), findsOneWidget);
      });
    }

    testWidgets('akun lokal tanpa server: penjelasan, tanpa tombol analisis', (tester) async {
      _phone(tester);
      final store = await _store(tester, server: false);
      await tester.pumpWidget(_wrap(store, _screen(_FakeAnalyzer())));
      await _settle(tester);
      expect(find.text('Analisis AI tersedia untuk akun yang tersinkron ke server.'), findsOneWidget);
      expect(find.widgetWithText(GymButton, 'Analisis sekarang'), findsNothing);
    });
  });

  testWidgets('360 dp, huruf 1,5×: mingguan dengan hasil AI dan bulanan tanpa meluber', (tester) async {
    _phone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = await _store(tester);
    final ai = _FakeAnalyzer();
    await tester.pumpWidget(_wrap(store, _screen(ai)));
    await _settle(tester);
    // Huruf 1,5×: kartu AI jatuh di bawah lipatan — gulir dulu.
    final analyze = find.widgetWithText(GymButton, 'Analisis sekarang');
    await tester.scrollUntilVisible(analyze, 200, scrollable: _scroll());
    await tester.pump();
    await tester.tap(analyze);
    await tester.pump();
    expect(ai.calls, 1);
    await tester.runAsync(() async {
      ai.pending!.complete(_analysis);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await _settle(tester);
    for (var i = 0; i < 12; i++) {
      await tester.drag(_scroll(), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull);
    await tester.drag(_scroll(), const Offset(0, 20000));
    await _settle(tester);
    await tester.tap(find.text('Bulanan'));
    await _settle(tester);
    for (var i = 0; i < 12; i++) {
      await tester.drag(_scroll(), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mingguan → Bulanan dari minggu yang melintasi dua bulan: bulan berjalan, bukan bulan awal minggu',
      (tester) async {
    _phone(tester);
    final store = await _store(tester);
    await tester.pumpWidget(_wrap(
      store,
      RecapScreen(analyzer: _FakeAnalyzer(), today: () => DateTime(2026, 10, 1, 12)),
    ));
    await _settle(tester);
    expect(find.text('28 Sep – 4 Okt'), findsOneWidget);
    await tester.tap(find.text('Bulanan'));
    await _settle(tester);
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(find.text('Bulan ini'), findsOneWidget);
  });

  testWidgets('analisis yang masih berjalan tetap terlacak saat kartu dibuat ulang (pindah tab bolak-balik)',
      (tester) async {
    _phone(tester);
    final store = await _store(tester);
    final ai = _FakeAnalyzer();
    await tester.pumpWidget(_wrap(store, _screen(ai)));
    await _settle(tester);
    await tester.tap(find.widgetWithText(GymButton, 'Analisis sekarang'));
    await tester.pump();
    expect(ai.calls, 1);
    await tester.tap(find.text('Bulanan'));
    await _settle(tester);
    await tester.tap(find.text('Mingguan'));
    await _settle(tester);
    expect(find.text('Menganalisis latihanmu…'), findsOneWidget, reason: 'kartu baru menunggu permintaan yang sama');
    expect(find.widgetWithText(GymButton, 'Analisis sekarang'), findsNothing);
    await tester.runAsync(() async {
      ai.pending!.complete(_analysis);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await _settle(tester);
    expect(find.text('Bench naik, kaki perlu dikejar'), findsOneWidget);
    expect(ai.calls, 1, reason: 'tidak ada panggilan kedua');
  });
}
