/// Riwayat v2.2: sesi yang terlanjur diselesaikan bisa dibuka lagi, hapus bisa
/// diurungkan, sesi lampau bisa dicatat, dan editor bisa menyusun gerakan.
///
/// Lahir dari laporan pemakai: "salah selesai-in split padahal niatku cuma
/// selesai-in timer, malah selesai sesi" — dan tidak ada jalan kembali.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/charts.dart';
import 'package:gymapps/core/gym_icons.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/strings_history.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/program.dart';
import 'package:gymapps/features/history/history_screen.dart';
import 'package:gymapps/features/history/workout_edit_screen.dart';
import 'package:gymapps/features/session/session_launcher.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
        child: MaterialApp(theme: buildGymTheme(), home: home),
      ),
    );

/// Sesi bench press: dua set kerja tercentang, satu belum.
Workout _sesi(String date, {String? routine, double w = 60, int dur = 1800}) => Workout(
      date: date,
      routine: routine,
      durationSeconds: dur,
      entries: [
        WorkoutEntry(
          exerciseId: '0025',
          target: const ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.double_, reps: 10, repsMin: 6),
          sets: [
            SetRow(weight: w, reps: 8, done: true),
            SetRow(weight: w, reps: 7, done: true),
            SetRow(weight: w, reps: 6),
          ],
        ),
      ],
    );

/// HP kecil yang umum: 360 × 780 dp.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Pump berjangka, bukan pumpAndSettle: animasi kedatangan dan timer sesi
/// tidak pernah "tenang".
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Habiskan waktu SnackBar URUNGKAN (lima detik) beserta animasi keluarnya,
/// lalu beri store kesempatan menulis ke disk.
Future<void> _expireSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  await tester.pump();
}

/// Katalog dibaca dari aset lewat I/O sungguhan, yang tidak pernah selesai di
/// dalam zona waktu palsu widget test. Dimuat sekali lewat [WidgetTester.runAsync];
/// setelah itu `ExerciseCatalog.load()` di dalam layar langsung memakai cache.
Future<ExerciseCatalog> _catalog(WidgetTester tester) async =>
    (await tester.runAsync(ExerciseCatalog.load))!;

/// Baris sesi di daftar Riwayat. Bukan `find.byType(Dismissible)` saja:
/// SnackBar memakai Dismissible juga.
Finder _row(String title) => find.widgetWithText(Dismissible, title);

/// Tombol yang membuka [page] lewat push dan mencatat hasilnya — cara
/// Riwayat membuka editor.
Widget _launcher(Widget page, void Function(Workout?) onResult) => Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onResult(
            await Navigator.of(context).push<Workout>(MaterialPageRoute(builder: (_) => page)),
          ),
          child: const Text('Go'),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
    store = WorkoutStore();
    await store.load();
  });

  group('store', () {
    test('replaceWorkoutByKey mengganti catatan di tempat tanpa menggeser rotasi', () async {
      await store.applyTemplate('ppl');
      final push = store.routines.first;
      await store.addWorkout(_sesi('2026-09-18'));
      await store.addWorkout(_sesi('2026-09-20', routine: push.name), routineId: push.id);
      expect(store.program!.cursor, 1);
      final original = store.workouts.first;
      final key = workoutKey(original);
      // Dokumen ini masih memuat versi lama — seperti HP lain yang belum
      // sempat menarik perubahan.
      final doc = store.toDocument();

      final fixed = _sesi('2026-09-20', routine: push.name, w: 62.5, dur: 2400);
      await store.replaceWorkoutByKey(key, fixed);
      expect(store.workouts.length, 2);
      expect(store.workouts.first.durationSeconds, 2400);
      expect(store.program!.cursor, 1, reason: 'sesi ini sudah menggeser rotasi waktu pertama selesai');

      final added = await store.importDocument(doc);
      expect(added, 0);
      expect(store.workouts.length, 2, reason: 'versi lama tidak hidup lagi dari dokumen lama');
    });

    test('replaceWorkoutByKey tetap menyimpan kalau aslinya sudah hilang', () async {
      await store.addWorkout(_sesi('2026-09-20'));
      final key = workoutKey(store.workouts.first);
      await store.removeWorkout(store.workouts.first);
      await store.replaceWorkoutByKey(key, _sesi('2026-09-20', w: 70));
      expect(store.workouts.single.entries.single.sets.first.weight, 70);
    });

    test('replaceWorkout: suntingan yang kembali ke isi semula mencabut tombstone-nya', () async {
      await store.addWorkout(_sesi('2026-09-20'));
      final k1 = workoutKey(store.workouts.first);

      // Suntingan pertama mengubur K1.
      final typo = _sesi('2026-09-20', w: 600);
      await store.replaceWorkout(store.workouts.first, typo);
      expect(store.toDocument()['removed'], [k1]);

      // Suntingan kedua mengembalikan isinya persis ke K1. Kalau K1 masih
      // terkubur, HP lain membuang sesi ini begitu sinkron.
      await store.replaceWorkout(store.workouts.first, _sesi('2026-09-20'));
      expect(workoutKey(store.workouts.single), k1);
      final removed = store.toDocument()['removed'] as List;
      expect(removed, isNot(contains(k1)));
      expect(removed, contains(workoutKey(typo)), reason: 'versi salah ketik tetap terkubur');
    });

    test('replaceWorkout: objek yang diganti sinkron tetap ketemu lewat sidik jari', () async {
      await store.addWorkout(_sesi('2026-09-20'));
      // Salinan dengan isi sama tapi objek lain — seperti setelah dokumen
      // dibaca ulang selagi editor terbuka.
      final copy = Workout.fromJson(store.workouts.first.toJson());
      await store.replaceWorkout(copy, _sesi('2026-09-20', w: 62.5));
      expect(store.workouts.single.entries.single.sets.first.weight, 62.5,
          reason: 'suntingan tidak boleh hilang diam-diam');
    });

    test('replaceWorkout: dua sesi sehari tidak bertukar tempat; tanggal baru ikut urutan tanggal', () async {
      await store.addWorkout(_sesi('2026-09-10'));
      await store.addWorkout(_sesi('2026-09-20', dur: 1000));
      await store.addWorkout(_sesi('2026-09-20', dur: 2000));
      expect(store.workouts.map((w) => w.durationSeconds), [2000, 1000, 1800]);

      // Sunting sesi kedua di hari yang sama, tanggal tetap: posisinya tetap.
      await store.replaceWorkout(store.workouts[1], _sesi('2026-09-20', w: 65, dur: 1000));
      expect(store.workouts.map((w) => w.durationSeconds), [2000, 1000, 1800]);
      expect(store.workouts[1].entries.single.sets.first.weight, 65);

      // Tanggalnya diganti: pindah ke tempat tanggal barunya.
      await store.replaceWorkout(store.workouts[0], _sesi('2026-09-05', dur: 2000));
      expect(store.workouts.map((w) => w.date), ['2026-09-20', '2026-09-10', '2026-09-05']);

      // Sesi yang dibuka ulang dan diselesaikan lagi juga tetap di tempatnya.
      await store.addWorkout(_sesi('2026-09-20', dur: 3000));
      await store.replaceWorkoutByKey(workoutKey(store.workouts[1]), _sesi('2026-09-20', w: 70, dur: 1000));
      expect(store.workouts.map((w) => w.durationSeconds), [3000, 1000, 1800, 2000]);
    });

    test('addManualWorkout urut menurut tanggal dan tidak menggeser cursor', () async {
      await store.applyTemplate('ppl');
      await store.addWorkout(_sesi('2026-09-10'));
      await store.addWorkout(_sesi('2026-09-20'));
      expect(store.program!.cursor, 0);

      await store.addManualWorkout(_sesi('2026-09-15', routine: 'Push'));
      expect(store.program!.cursor, 0, reason: 'sesi yang dicatat belakangan bukan bagian rotasi');
      expect(store.workouts.map((w) => w.date), ['2026-09-20', '2026-09-15', '2026-09-10']);

      final sameDay = _sesi('2026-09-15', w: 70);
      await store.addManualWorkout(sameDay);
      expect(store.workouts.map((w) => w.date), ['2026-09-20', '2026-09-15', '2026-09-15', '2026-09-10']);
      expect(identical(store.workouts[1], sameDay), isTrue, reason: 'tanggal sama: yang baru di depan');

      final oldest = _sesi('2026-09-01');
      await store.addManualWorkout(oldest);
      expect(store.workouts.last.date, '2026-09-01');
    });
  });

  group('launcher', () {
    test('historyBefore: identitas dulu, lalu sidik jari; tidak ketemu = semua', () {
      final a = _sesi('2026-09-10');
      final b = _sesi('2026-09-20');
      final c = _sesi('2026-09-25');
      final chrono = [a, b, c];
      expect(historyBefore(chrono, workout: b), [a]);
      expect(historyBefore(chrono, workout: Workout.fromJson(b.toJson())), [a]);
      expect(historyBefore(chrono, key: workoutKey(c)), [a, b]);
      expect(historyBefore(chrono, key: 'tidak-ada'), chrono);
    });

    testWidgets('reopenWorkoutSession membuka sesi berisi set yang sama tanpa menghapus aslinya', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.applyTemplate('ppl');
      final push = store.routines.first;
      await store.addWorkout(_sesi('2026-09-20', routine: push.name, w: 62.5), routineId: push.id);
      expect(store.program!.cursor, 1);
      final w = store.workouts.first;

      await tester.pumpWidget(_wrap(
        store,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => reopenWorkoutSession(context, w),
              child: const Text('Go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Go'));
      await _settle(tester);

      // Catatan asli dan rotasi tidak disentuh sampai sesi diselesaikan lagi:
      // kalau sesi yang dibuka ulang dibuang, tidak ada yang hilang.
      expect(store.workouts.single, same(w));
      expect(store.program!.cursor, 1);
      final screen = tester.widget<SessionScreen>(find.byType(SessionScreen));
      expect(screen.replacesKey, workoutKey(w));
      expect(screen.initialDate, '2026-09-20');
      expect(screen.routineName, push.name);
      expect(screen.routineId, push.id);
      expect(screen.initialElapsed, const Duration(seconds: 1800));
      final ex = screen.exercises.single;
      expect(ex.config.exerciseId, '0025');
      expect(
        ex.sets.map((s) => (s.weight, s.reps, s.done)),
        [(62.5, 8, true), (62.5, 7, true), (62.5, 6, false)],
        reason: 'set beserta centangnya dibawa apa adanya',
      );
      expect(ex.previous.length, ex.sets.length);
      expect(screen.planned, [for (final cfg in push.exercises) (cfg.exerciseId, cfg.sets)]);
    });

    testWidgets('reopenWorkoutSession: riwayatnya hanya sesi sebelum sesi yang dibuka ulang', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.addWorkout(_sesi('2026-09-10', w: 55));
      await store.addWorkout(_sesi('2026-09-20', w: 60));
      await store.addWorkout(_sesi('2026-09-25', w: 65));
      final mid = store.workouts[1];

      await tester.pumpWidget(_wrap(
        store,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => reopenWorkoutSession(context, mid),
              child: const Text('Go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Go'));
      await _settle(tester);

      final screen = tester.widget<SessionScreen>(find.byType(SessionScreen));
      expect(screen.history.map((w) => w.date), ['2026-09-10'],
          reason: 'bukan dirinya sendiri, dan bukan sesi tanggal 25 yang datang sesudahnya');
      expect(screen.exercises.single.previous.first, contains('55'), reason: 'PREV = sesi tanggal 10');
    });

    testWidgets('resumeDraftSession: draft sesi yang dibuka ulang tidak membandingkan dengan dirinya', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.addWorkout(_sesi('2026-09-10'));
      await store.addWorkout(_sesi('2026-09-20'));
      await store.addWorkout(_sesi('2026-09-25'));
      final key = workoutKey(store.workouts[1]);
      await store.saveDraft({
        'name': 'Push',
        'ex': const [],
        'date': '2026-09-20',
        'replaces': key,
        'saved': DateTime.now().millisecondsSinceEpoch,
      });

      await tester.pumpWidget(_wrap(
        store,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => resumeDraftSession(context),
              child: const Text('Go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Go'));
      await _settle(tester);

      final screen = tester.widget<SessionScreen>(find.byType(SessionScreen));
      expect(screen.replacesKey, key);
      expect(screen.history.map((w) => w.date), ['2026-09-10']);
    });
  });

  group('layar riwayat', () {
    testWidgets('sheet detail menampilkan RESUME SESSION; tombol + menawarkan dua pilihan', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);

      // Label bulan ikut muncul.
      expect(find.text('SEPTEMBER 2026'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(Dismissible), matching: find.text('Push')));
      await _settle(tester);
      expect(find.text('Resume session'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Konfirmasi sebelum dibuka ulang.
      await tester.tap(find.text('Resume session'));
      await _settle(tester);
      expect(find.text('Resume this session?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(store.workouts.length, 1, reason: 'batal tidak mengubah apa pun');

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await _settle(tester);

      await tester.tap(find.byIcon(GymIcons.plus));
      await _settle(tester);
      expect(find.text('Start a freestyle session now'), findsOneWidget);
      expect(find.text('Log a past session'), findsOneWidget);
    });

    testWidgets('lanjutkan dari sheet membuka SessionScreen; catatan asli menunggu sampai selesai', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.applyTemplate('ppl');
      final push = store.routines.first;
      await store.addWorkout(_sesi('2026-09-20', routine: push.name), routineId: push.id);
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);

      await tester.tap(find.descendant(of: find.byType(Dismissible), matching: find.text(push.name)));
      await _settle(tester);
      await tester.tap(find.text('Resume session'));
      await _settle(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Resume')));
      await _settle(tester);

      expect(find.byType(SessionScreen), findsOneWidget);
      expect(store.workouts.length, 1, reason: 'dibuang di tengah jalan = catatan asli masih ada');
      expect(store.program!.cursor, 1);
    });

    testWidgets('hapus lewat sheet lalu UNDO: store tidak pernah disentuh', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      final w = store.workouts.first;
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);

      await tester.tap(find.descendant(of: find.byType(Dismissible), matching: find.text('Push')));
      await _settle(tester);
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      expect(find.text('Delete this session?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await _settle(tester);

      // Baris hilang seketika, tapi store belum menghapus apa pun: tidak ada
      // tombstone yang bisa terdorong ke HP lain selama SnackBar tampil.
      expect(_row('Push'), findsNothing);
      expect(store.workouts.single, same(w));
      expect(store.toDocument()['removed'], isNull);

      expect(find.text('UNDO'), findsOneWidget);
      await tester.tap(find.text('UNDO'));
      await _settle(tester);
      expect(_row('Push'), findsOneWidget);

      // Lewat batas waktu SnackBar pun tetap utuh.
      await _expireSnackBar(tester);
      expect(store.workouts.single, same(w));
      expect(store.toDocument()['removed'], isNull, reason: 'diurungkan = tidak pernah dikubur');
      expect(_row('Push'), findsOneWidget);
    });

    testWidgets('hapus lewat sheet tanpa UNDO: dihapus saat SnackBar habis waktu', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      final key = workoutKey(store.workouts.first);
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);

      await tester.tap(find.descendant(of: find.byType(Dismissible), matching: find.text('Push')));
      await _settle(tester);
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await _settle(tester);
      expect(store.workouts.length, 1);

      await _expireSnackBar(tester);
      expect(find.text('UNDO'), findsNothing);
      expect(store.workouts, isEmpty);
      expect(store.toDocument()['removed'], [key]);
      expect(_row('Push'), findsNothing);
    });

    testWidgets('geser kiri menghapus setelah konfirmasi, dengan UNDO', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);

      await tester.drag(_row('Push'), const Offset(-500, 0));
      await _settle(tester);
      expect(find.text('Delete this session?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(_row('Push'), findsNothing);
      expect(store.workouts.length, 1, reason: 'hapusnya menunggu SnackBar tertutup');
      expect(find.text('UNDO'), findsOneWidget);
      await tester.tap(find.text('UNDO'));
      await _settle(tester);
      expect(_row('Push'), findsOneWidget);
      await _expireSnackBar(tester);
      expect(store.workouts.length, 1);
      expect(store.toDocument()['removed'], isNull);
    });

    testWidgets('hapus yang tertunda tetap jalan walau layar Riwayat sudah ditutup', (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      final show = ValueNotifier(true);
      addTearDown(show.dispose);
      await tester.pumpWidget(_wrap(
        store,
        Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, on, _) => on ? const HistoryScreen() : const Text('ELSEWHERE'),
          ),
        ),
      ));
      await _settle(tester);

      await tester.drag(_row('Push'), const Offset(-500, 0));
      await _settle(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await _settle(tester);

      // Pindah tab selagi SnackBar masih tampil.
      show.value = false;
      await _settle(tester);
      expect(find.byType(HistoryScreen), findsNothing);
      expect(store.workouts.length, 1);

      await _expireSnackBar(tester);
      expect(store.workouts, isEmpty, reason: 'store hidup lebih lama dari layar');
      expect(store.toDocument()['removed'], hasLength(1));
    });

    testWidgets('sesi yang menunggu dihapus hilang dari chip, label bulan, dan kotak aktivitas', (tester) async {
      _phone(tester);
      await _catalog(tester);
      // Tanggal relatif ke hari ini supaya kedua sesi masuk kotak 24 minggu.
      // Empat puluh hari lalu selalu jatuh di bulan yang berbeda.
      final now = DateTime.now();
      final old = now.subtract(const Duration(days: 40));
      await store.addWorkout(_sesi(isoDate(old), routine: 'Pull'));
      await store.addWorkout(_sesi(isoDate(now), routine: 'Push'));
      final oldMonth = '${const Strings(AppLanguage.english).monthLong(old.month)} ${old.year}'.toUpperCase();
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);

      List<String> chips() => tester.widget<FilterChips>(find.byType(FilterChips)).labels;
      int activeDays() => tester.widget<ActivityHeatmap>(find.byType(ActivityHeatmap)).levels.where((l) => l > 0).length;
      expect(chips(), ['All', 'Push', 'Pull']);
      expect(find.text(oldMonth), findsOneWidget);
      expect(activeDays(), 2);

      await tester.ensureVisible(_row('Pull'));
      await _settle(tester);
      await tester.drag(_row('Pull'), const Offset(-500, 0));
      await _settle(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await _settle(tester);

      expect(store.workouts.length, 2, reason: 'belum dihapus dari store');
      expect(chips(), ['All', 'Push']);
      expect(find.text(oldMonth), findsNothing);
      expect(activeDays(), 1);

      await tester.tap(find.text('UNDO'));
      await _settle(tester);
      expect(chips(), ['All', 'Push', 'Pull']);
      expect(find.text(oldMonth), findsOneWidget);
      expect(activeDays(), 2);
    });

    testWidgets('filter rutinitas: menggeser satu-satunya baris tidak melempar dan chip tetap di tempat',
        (tester) async {
      _phone(tester);
      await _catalog(tester);
      await store.addWorkout(_sesi('2026-09-18', routine: 'Pull'));
      await store.addWorkout(_sesi('2026-09-20', routine: 'Push'));
      await store.addWorkout(_sesi('2026-09-21', routine: 'Legs'));
      await tester.pumpWidget(_wrap(store, const Scaffold(body: HistoryScreen())));
      await _settle(tester);

      await tester.tap(find.descendant(of: find.byType(FilterChips), matching: find.text('Push')));
      await _settle(tester);
      expect(_row('Pull'), findsNothing);
      expect(_row('Push'), findsOneWidget);

      await tester.drag(_row('Push'), const Offset(-500, 0));
      await _settle(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await tester.pump(); // dialog tertutup, baris mulai menyusut
      await tester.pump(const Duration(milliseconds: 300)); // susut selesai → onDismissed
      await tester.pump(const Duration(milliseconds: 50)); // daftar sedang memudar
      // Store memberi tahu di tengah pudar — cukup satu status sinkron.
      // Baris membaca store (satuan beban), jadi baris yang masih ditahan
      // AnimatedSwitcher ikut dibangun ulang. Dulu kunci daftar berganti saat
      // baris terakhir tergeser, dan di sinilah Flutter melempar "A dismissed
      // Dismissible widget is still part of the tree".
      await store.updateSettings(store.settings);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('No Push sessions logged yet'), findsOneWidget);
      // Chip yang dipilih tidak melompat ke rutinitas berikutnya.
      final chips = tester.widget<FilterChips>(find.byType(FilterChips));
      expect(chips.labels[chips.index], 'Push');
      expect(_row('Pull'), findsNothing);

      await tester.tap(find.text('UNDO'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(_row('Push'), findsOneWidget);
    });
  });

  group('editor sesi', () {
    testWidgets('catat sesi: simpan tanpa set kerja ditolak', (tester) async {
      _phone(tester);
      final catalog = await _catalog(tester);
      await tester.pumpWidget(_wrap(
        store,
        WorkoutEditScreen(
          workout: const Workout(date: '2026-09-20', entries: []),
          catalog: catalog,
          isNew: true,
        ),
      ));
      await _settle(tester);
      expect(find.text('Log a session'), findsOneWidget);
      expect(find.text('Add exercise'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await _settle(tester);
      expect(find.text('No working sets logged.'), findsOneWidget);
      expect(find.byType(WorkoutEditScreen), findsOneWidget, reason: 'layar tidak ditutup');
    });

    testWidgets('set 0 × 0 yang tercentang bukan set kerja', (tester) async {
      _phone(tester);
      final catalog = await _catalog(tester);
      await tester.pumpWidget(_wrap(
        store,
        WorkoutEditScreen(
          workout: const Workout(date: '2026-09-20', entries: [
            WorkoutEntry(exerciseId: '0025', sets: [SetRow(done: true)]),
          ]),
          catalog: catalog,
        ),
      ));
      await _settle(tester);

      await tester.tap(find.text('Save'));
      await _settle(tester);
      expect(find.text('No working sets logged.'), findsOneWidget);
      expect(find.byType(WorkoutEditScreen), findsOneWidget);
    });

    testWidgets('gerakan tanpa riwayat ditambah dengan baris yang belum tercentang', (tester) async {
      _phone(tester);
      final catalog = await _catalog(tester);
      await tester.pumpWidget(_wrap(
        store,
        WorkoutEditScreen(
          workout: const Workout(date: '2026-09-20', entries: []),
          catalog: catalog,
          isNew: true,
        ),
      ));
      await _settle(tester);

      await tester.tap(find.text('Add exercise'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'Barbell Bench Press');
      await _settle(tester);
      await tester.tap(find.descendant(of: find.byType(ListView), matching: find.text('Barbell Bench Press')).first);
      await _settle(tester);

      expect(find.text('Barbell Bench Press'), findsOneWidget, reason: 'kembali ke editor dengan gerakan baru');
      expect(find.byIcon(GymIcons.circle), findsOneWidget);
      expect(find.byIcon(GymIcons.checkCircle), findsNothing, reason: '0 × 0 tidak boleh diklaim sudah dilakukan');

      await tester.tap(find.text('Save'));
      await _settle(tester);
      expect(find.text('No working sets logged.'), findsOneWidget);
    });

    testWidgets('hapus gerakan dengan set tercentang minta konfirmasi', (tester) async {
      _phone(tester);
      final catalog = await _catalog(tester);
      await tester.pumpWidget(_wrap(store, WorkoutEditScreen(workout: _sesi('2026-09-20'), catalog: catalog)));
      await _settle(tester);
      expect(find.text('Barbell Bench Press'), findsOneWidget);

      await tester.tap(find.byIcon(GymIcons.trash));
      await _settle(tester);
      expect(find.text('Remove this exercise?'), findsOneWidget);
      expect(find.text('2 ticked sets will be lost.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(find.text('Barbell Bench Press'), findsOneWidget);

      await tester.tap(find.byIcon(GymIcons.trash));
      await _settle(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await _settle(tester);
      expect(find.text('Barbell Bench Press'), findsNothing);
    });

    testWidgets('ketik beban lalu rep di baris yang sama: dua-duanya tersimpan', (tester) async {
      _phone(tester);
      final catalog = await _catalog(tester);
      Workout? result;
      await tester.pumpWidget(_wrap(
        store,
        _launcher(WorkoutEditScreen(workout: _sesi('2026-09-20', routine: 'Push'), catalog: catalog), (r) => result = r),
      ));
      await tester.tap(find.text('Go'));
      await _settle(tester);

      // Satuan bawaan di test adalah kg, jadi angka yang diketik = kg.
      await tester.enterText(find.widgetWithText(TextFormField, '60').first, '70');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextFormField, '8'), '9');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await _settle(tester);
      expect(result, isNotNull);
      final sets = result!.entries.single.sets;
      expect((sets[0].weight, sets[0].reps), (70.0, 9), reason: 'dulu jadi 60 × 9: rep ditulis di atas salinan lama');
      expect((sets[1].weight, sets[1].reps), (60.0, 7), reason: 'baris lain tidak ikut berubah');
    });

    testWidgets('tutup atau kembali dengan isi yang berubah minta konfirmasi; tanpa perubahan langsung keluar',
        (tester) async {
      _phone(tester);
      final catalog = await _catalog(tester);
      final results = <Workout?>[];
      Widget editor() => WorkoutEditScreen(
            workout: const Workout(date: '2026-09-20', entries: []),
            catalog: catalog,
            isNew: true,
          );
      await tester.pumpWidget(_wrap(store, _launcher(editor(), results.add)));

      // Belum ada yang diubah: tombol tutup langsung keluar.
      await tester.tap(find.text('Go'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Cancel'));
      await _settle(tester);
      expect(find.byType(WorkoutEditScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(results, [null]);

      // Sudah diketik: tombol tutup bertanya dulu.
      await tester.tap(find.text('Go'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'Latihan di gym kantor');
      await tester.pump();
      await tester.tap(find.byTooltip('Cancel'));
      await _settle(tester);
      expect(find.text('Discard this session?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await _settle(tester);
      expect(find.byType(WorkoutEditScreen), findsOneWidget);
      expect(find.text('Latihan di gym kantor'), findsOneWidget, reason: 'isinya tidak hilang');

      // Gestur kembali sistem juga lewat konfirmasi yang sama.
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Discard this session?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Discard')));
      await _settle(tester);
      expect(find.byType(WorkoutEditScreen), findsNothing);
      expect(results, [null, null]);
    });

    testWidgets('ganti rutinitas dan tanggal ikut tersimpan ke hasil', (tester) async {
      _phone(tester);
      await store.applyTemplate('ppl');
      final catalog = await _catalog(tester);
      Workout? result;
      await tester.pumpWidget(_wrap(
        store,
        _launcher(WorkoutEditScreen(workout: _sesi('2026-09-20', routine: 'Push'), catalog: catalog), (r) => result = r),
      ));
      await tester.tap(find.text('Go'));
      await _settle(tester);
      expect(find.text('Edit session'), findsOneWidget);

      await tester.tap(find.text('Routine'));
      await _settle(tester);
      await tester.tap(find.text('Pull'));
      await _settle(tester);
      expect(find.text('Pull'), findsOneWidget, reason: 'nilai tile berganti');

      // Pemilih tanggal membuka bulan sesinya (September 2026).
      await tester.tap(find.text('Date'));
      await _settle(tester);
      await tester.tap(find.text('18'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await _settle(tester);
      expect(find.text('2026-09-18'), findsOneWidget, reason: 'nilai tile berganti');

      await tester.tap(find.text('Save'));
      await _settle(tester);
      expect(result, isNotNull);
      expect(result!.routine, 'Pull');
      expect(result!.date, '2026-09-18');
      expect(result!.durationSeconds, 1800, reason: 'lama sesi tidak hilang saat disunting');
      expect(result!.entries.single.sets.where((s) => s.done).length, 2);
      expect(result!.entries.single.target, isNotNull, reason: 'target sesi lama dipertahankan');
    });
  });
}
