/// Data per akun dan sinkron yang tidak kehilangan apa pun.
///
/// Lahir dari laporan pemakai: "pastikan data user sync dengan database dan
/// data teratur pada akun yang login". Yang ketahuan saat menelusurinya:
/// * Satu dokumen untuk seluruh HP — akun kedua melihat riwayat akun pertama.
/// * HP baru mendorong dokumen kosong dengan baseRev null, dan push_state
///   memperlakukannya sebagai "timpa": riwayat di server hilang.
/// * Gabung per tanggal membuang sesi kedua di hari yang sama.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/data/backend.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/features/home/home_screen.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server palsu yang aturannya sama persis dengan `push_state()` di
/// `supabase/SETUP.sql`: baris belum ada → sisipkan; baseRev null atau sama
/// dengan revisi server → timpa; selain itu → konflik beserta dokumen server.
///
/// Satu baris per akun, seperti RLS: sesi siapa yang dipegang saat panggilan
/// dimulai, baris dia yang dibaca atau ditulis.
class _Row {
  int? rev;
  Map<String, dynamic>? state;
}

class _Server implements Backend {
  _Server({this.email});

  String? email;
  bool session = true;
  int pushes = 0;

  final _rows = <String?, _Row>{};
  _Row get _row => _rows.putIfAbsent(email, _Row.new);

  int? get rev => _row.rev;
  set rev(int? v) => _row.rev = v;
  Map<String, dynamic>? get state => _row.state;
  set state(Map<String, dynamic>? v) => _row.state = v;

  /// Kalau diisi, push menunggu ini dulu — untuk meniru jaringan lambat.
  Completer<void>? gate;

  /// Sama, untuk pull.
  Completer<void>? pullGate;

  /// Sekian push berikutnya dijawab konflik apa pun baseRev-nya — meniru
  /// perangkat lain yang terus menulis di antara dua dorongan.
  int forcedConflicts = 0;

  @override
  String? get signedInEmail => email;

  int revChecks = 0;

  @override
  Future<int?> getRev() async {
    if (!session) throw const NotSignedIn();
    revChecks++;
    return rev;
  }

  @override
  Future<PulledState?> pull() async {
    if (!session) throw const NotSignedIn();
    final row = _row;
    await pullGate?.future;
    final s = row.state;
    return row.rev == null || s == null ? null : PulledState(rev: row.rev!, state: _copy(s));
  }

  @override
  Future<PushResult> push({required int? baseRev, required Map<String, dynamic> state}) async {
    if (!session) throw const NotSignedIn();
    // Baris ditentukan saat permintaan dikirim, bukan saat jawabannya datang.
    final row = _row;
    await gate?.future;
    pushes++;
    final cur = row.rev;
    if (forcedConflicts > 0 && cur != null) {
      forcedConflicts--;
      row.rev = cur + 1;
      return PushConflict(rev: row.rev!, state: _copy(row.state!));
    }
    if (cur == null) {
      row.rev = 1;
      row.state = _copy(state);
      return const PushAccepted(1);
    }
    if (baseRev == null || baseRev == cur) {
      row.rev = cur + 1;
      row.state = _copy(state);
      return PushAccepted(row.rev!);
    }
    return PushConflict(rev: cur, state: _copy(row.state!));
  }

  /// Lewat JSON, seperti jsonb di Postgres — bukan berbagi objek yang sama.
  static Map<String, dynamic> _copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  List<String> get dates => [for (final w in (state?['workouts'] as List? ?? const [])) (w as Map)['date'] as String];
}

Workout _sesi(String tanggal, {double berat = 60, String? rutinitas}) => Workout(
      date: tanggal,
      routine: rutinitas,
      entries: [
        WorkoutEntry(exerciseId: '0025', sets: [SetRow(weight: berat, reps: 8, done: true)]),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
  });

  group('data per akun', () {
    test('akun berbeda di HP yang sama, riwayat berbeda', () async {
      final store = WorkoutStore();
      await store.load('a@x.com');
      await store.addWorkout(_sesi('2026-09-20'));
      await store.applyTemplate('ppl');

      await store.load('b@x.com');
      expect(store.workouts, isEmpty);
      expect(store.hasProgram, isFalse);
      await store.addWorkout(_sesi('2026-09-21'));

      await store.load('a@x.com');
      expect(store.workouts.map((w) => w.date), ['2026-09-20']);
      expect(store.program?.name, 'Push / Pull / Legs');
    });

    test('keluar mengosongkan layar tanpa menghapus disk', () async {
      final store = WorkoutStore();
      await store.load('a@x.com');
      await store.addWorkout(_sesi('2026-09-20'));

      store.close();
      expect(store.workouts, isEmpty);
      expect(store.account, isNull);
      expect(store.loaded, isFalse);

      await store.load('a@x.com');
      expect(store.workouts.length, 1);
    });

    test('riwayat dari versi lama pindah ke akun pertama yang masuk, sekali', () async {
      SharedPreferences.setMockInitialValues({
        'state.doc': jsonEncode({
          'schema': stateSchema,
          'workouts': [_sesi('2026-09-10').toJson()],
        }),
        'state.baseRev': 7,
      });
      final store = WorkoutStore();
      await store.load('a@x.com');
      expect(store.workouts.map((w) => w.date), ['2026-09-10']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('state.doc'), isNull);
      // Revisinya milik baris server entah siapa — tidak ikut dipindah.
      expect(prefs.getInt('state.a@x.com.baseRev'), isNull);

      await store.load('b@x.com');
      expect(store.workouts, isEmpty);
    });
  });

  group('sinkron', () {
    test('HP baru menarik riwayat dan program dari server, tidak menimpanya', () async {
      // Keadaan akun di HP lama.
      final lama = WorkoutStore();
      await lama.load('lama@x.com');
      await lama.applyTemplate('ppl');
      await lama.addWorkout(_sesi('2026-09-18'), routineId: 'ppl-0');
      await lama.addWorkout(_sesi('2026-09-20'), routineId: 'ppl-1');
      final server = _Server()
        ..rev = 4
        ..state = lama.toDocument();

      final baru = WorkoutStore(server);
      await baru.load('a@x.com');
      await baru.syncNow();

      expect(baru.workouts.map((w) => w.date), ['2026-09-20', '2026-09-18']);
      expect(baru.hasProgram, isTrue);
      expect(baru.nextSessionOn(DateTime(2026, 9, 24))?.routine.name, 'Legs');
      expect(server.dates, ['2026-09-20', '2026-09-18']);
      expect(baru.syncStatus, SyncStatus.synced);
    });

    test('dua sesi di hari yang sama tetap dua setelah konflik', () async {
      SharedPreferences.setMockInitialValues({
        'state.a@x.com.doc': jsonEncode({
          'schema': stateSchema,
          'workouts': [
            _sesi('2026-09-16', berat: 80, rutinitas: 'Sore').toJson(),
            _sesi('2026-09-16', berat: 20, rutinitas: 'Pagi').toJson(),
          ],
        }),
        'state.a@x.com.baseRev': 1,
      });
      final server = _Server()
        ..rev = 3
        ..state = {
          'schema': stateSchema,
          'workouts': [_sesi('2026-09-14').toJson()],
        };

      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.syncNow();

      expect(store.workouts.map((w) => w.routine), ['Sore', 'Pagi', null]);
      expect(server.dates, ['2026-09-16', '2026-09-16', '2026-09-14']);
    });

    test('sesi yang sama persis tidak jadi dobel', () async {
      final server = _Server()
        ..rev = 2
        ..state = {
          'schema': stateSchema,
          'workouts': [_sesi('2026-09-16').toJson()],
        };
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.addWorkout(_sesi('2026-09-16'));
      await store.syncNow();
      expect(store.workouts.length, 1);
      expect(server.dates, ['2026-09-16']);
    });

    test('sesi yang dihapus di satu HP tidak hidup lagi dari HP lain', () async {
      // Dua HP, satu baris server. Kunci akunnya dibedakan hanya supaya
      // penyimpanan lokal kedua "HP" tidak bercampur di satu mock.
      final server = _Server();
      final hp = WorkoutStore(server);
      await hp.load('hp@x.com');
      await hp.addWorkout(_sesi('2026-09-14'));
      await hp.addWorkout(_sesi('2026-09-16'));
      await hp.syncNow();

      final tablet = WorkoutStore(server);
      await tablet.load('tablet@x.com');
      await tablet.syncNow();
      expect(tablet.workouts.length, 2);

      await hp.removeWorkout(hp.workouts.last); // sesi tanggal 14
      await hp.syncNow();
      expect(server.dates, ['2026-09-16']);

      // Tablet masih memegang sesi tanggal 14 dan revisi lama.
      await tablet.addWorkout(_sesi('2026-09-18'));
      await tablet.syncNow();
      expect(tablet.workouts.map((w) => w.date), ['2026-09-18', '2026-09-16']);
      expect(server.dates, ['2026-09-18', '2026-09-16']);
    });

    test('sesi server milik akun lain: tidak ada yang didorong', () async {
      final server = _Server(email: 'orang.lain@x.com');
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.addWorkout(_sesi('2026-09-16'));
      await store.syncNow();
      expect(server.pushes, 0);
      expect(server.state, isNull);
      expect(store.syncStatus, SyncStatus.noSession);
      expect(store.workouts.length, 1);
    });

    test('email server dibandingkan tanpa peduli huruf besar', () async {
      final server = _Server(email: 'A@X.com');
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.syncNow();
      expect(store.syncStatus, SyncStatus.synced);
    });

    test('tanpa sesi server: status jujur, data lokal utuh', () async {
      final server = _Server()..session = false;
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.addWorkout(_sesi('2026-09-16'));
      await store.syncNow();
      expect(store.syncStatus, SyncStatus.noSession);
      expect(store.workouts.length, 1);
    });

    test('sinkron yang bertumpuk tetap mengirim perubahan terakhir', () async {
      final server = _Server()..gate = Completer<void>();
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      final a = store.syncNow();
      await store.addWorkout(_sesi('2026-09-16'));
      final b = store.syncNow();
      server.gate!.complete();
      await Future.wait([a, b]);
      expect(server.dates, ['2026-09-16']);
    });

    test('keluar di tengah sinkron tidak menulis ke akun berikutnya', () async {
      final server = _Server(email: 'a@x.com')..gate = Completer<void>();
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.addWorkout(_sesi('2026-09-16'));
      final pending = store.syncNow();

      store.close();
      server.email = 'b@x.com';
      await store.load('b@x.com');
      server.gate!.complete();
      await pending;
      await store.syncNow();

      final prefs = await SharedPreferences.getInstance();
      expect(store.workouts, isEmpty);
      final docB = jsonDecode(prefs.getString('state.b@x.com.doc') ?? '{"workouts":[]}') as Map;
      expect(docB['workouts'], isEmpty);
      expect(server.dates, isEmpty); // baris b
      server.email = 'a@x.com';
      expect(server.dates, ['2026-09-16']); // baris a tetap dapat sesinya
    });
  });

  group('temuan review', () {
    test('onboarding sebelum server menjawab tidak menimpa split di server', () async {
      // HP baru, sinyal lemah: tarikan pertama belum datang, layar pilih
      // program muncul, orangnya memilih PPL. Di server ada split buatannya.
      final lama = WorkoutStore();
      await lama.load('lama@x.com');
      await lama.applyTemplate('heavy-duty');
      await lama.addWorkout(_sesi('2026-09-20'), routineId: 'heavy-duty-0');
      final server = _Server()
        ..rev = 6
        ..state = lama.toDocument()
        ..pullGate = Completer<void>();

      final baru = WorkoutStore(server);
      await baru.load('a@x.com');
      expect(baru.serverChecked, isFalse);
      await baru.applyTemplate('ppl');
      expect(baru.program!.name, 'Push / Pull / Legs');

      server.pullGate!.complete();
      await baru.syncNow();
      expect(baru.program!.name, 'Heavy Duty');
      expect(baru.routines.length, 4);
      expect((server.state!['program'] as Map)['name'], 'Heavy Duty');
      expect(baru.workouts.length, 1);

      // Sekali server sudah menjawab, pilihan di HP ini yang berlaku lagi.
      await baru.applyTemplate('ppl');
      await baru.syncNow();
      expect((server.state!['program'] as Map)['name'], 'Push / Pull / Legs');
    });

    test('program yang dipilih setelah server menjawab tetap milik HP ini', () async {
      final server = _Server();
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.syncNow();
      expect(store.serverChecked, isTrue);
      await store.applyTemplate('upper-lower');
      await store.syncNow();
      expect((server.state!['program'] as Map)['name'], store.program!.name);
    });

    test('konflik beruntun: tidak mengaku tersinkron sebelum benar-benar naik', () async {
      final server = _Server()
        ..rev = 1
        ..state = {'schema': stateSchema, 'workouts': <Object>[]};
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.syncNow();
      server.forcedConflicts = 2;
      await store.addWorkout(_sesi('2026-09-16'));
      await store.syncNow();
      expect(server.dates, ['2026-09-16']);
      expect(store.syncStatus, SyncStatus.synced);
    });

    test('sesi server berganti di tengah tarikan: tidak ada yang ditulis ke akun lain', () async {
      final server = _Server(email: 'a@x.com')..pullGate = Completer<void>();
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.addWorkout(_sesi('2026-09-16'));
      server.email = 'b@x.com';
      server.pullGate!.complete();
      await store.syncNow();
      expect(server.state, isNull); // baris b tidak tersentuh
      expect(store.syncStatus, SyncStatus.noSession);
      expect(store.workouts.length, 1);
    });
  });

  group('program diganti di HP lain', () {
    test('HP yang tidak mengubah apa pun mengambil program baru dari server', () async {
      final server = _Server();
      final hp = WorkoutStore(server);
      await hp.load('hp@x.com');
      await hp.applyTemplate('ppl');
      await hp.syncNow();

      final tablet = WorkoutStore(server);
      await tablet.load('tablet@x.com');
      await tablet.syncNow();
      expect(tablet.program!.name, 'Push / Pull / Legs');

      await hp.applyTemplate('upper-lower');
      await hp.syncNow();

      // Tablet cuma dibuka lagi — sinkron saat kembali ke aplikasi.
      await tablet.syncNow();
      expect(tablet.program!.name, 'Upper / Lower');
      expect((server.state!['program'] as Map)['name'], 'Upper / Lower');
    });

    test('dua-duanya mengubah: perubahan HP yang sinkron belakangan yang dipakai', () async {
      final server = _Server();
      final hp = WorkoutStore(server);
      await hp.load('hp@x.com');
      await hp.applyTemplate('ppl');
      await hp.syncNow();
      final tablet = WorkoutStore(server);
      await tablet.load('tablet@x.com');
      await tablet.syncNow();

      await hp.applyTemplate('upper-lower');
      await hp.syncNow();
      await tablet.applyTemplate('heavy-duty');
      await tablet.syncNow();
      expect(tablet.program!.name, 'Heavy Duty');
      expect((server.state!['program'] as Map)['name'], 'Heavy Duty');
    });

    test('HP yang cuma mencatat sesi offline tidak menimpa split baru dari HP lain', () async {
      // Temuan review: pergeseran cursor dulu dihitung "mengubah program".
      final server = _Server();
      final hp = WorkoutStore(server);
      await hp.load('hp@x.com');
      await hp.applyTemplate('ppl');
      await hp.syncNow();
      final tablet = WorkoutStore(server);
      await tablet.load('tablet@x.com');
      await tablet.syncNow();

      await tablet.applyTemplate('upper-lower');
      await tablet.syncNow();

      // HP di gym tanpa sinyal: mencatat Push dari rencana lama.
      server.session = false;
      await hp.addWorkout(_sesi('2026-09-24', rutinitas: 'Push'), routineId: 'ppl-0');
      server.session = true;
      await hp.syncNow();

      expect(hp.program!.name, 'Upper / Lower');
      expect(hp.routines.map((r) => r.name), ['Upper', 'Lower']);
      expect((server.state!['program'] as Map)['name'], 'Upper / Lower');
      expect(server.dates, ['2026-09-24']);
    });

    test('struktur dari HP lain, posisi rotasi dari HP ini kalau urutannya sama', () async {
      final server = _Server();
      final hp = WorkoutStore(server);
      await hp.load('hp@x.com');
      await hp.applyTemplate('ppl');
      await hp.syncNow();
      final tablet = WorkoutStore(server);
      await tablet.load('tablet@x.com');
      await tablet.syncNow();

      await tablet.updateProgram(tablet.program!.copyWith(name: 'PPL baru'));
      await tablet.syncNow();

      await hp.addWorkout(_sesi('2026-09-24', rutinitas: 'Push'), routineId: 'ppl-0');
      await hp.syncNow();
      expect(hp.program!.name, 'PPL baru');
      expect(hp.program!.cursor, 1);
      expect((server.state!['program'] as Map)['cursor'], 1);
    });

    test('dibuka lagi tanpa perubahan: tanya revisi, tidak mengunggah ulang', () async {
      final server = _Server();
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.addWorkout(_sesi('2026-09-16'));
      await store.syncNow();
      final pushes = server.pushes;

      await store.syncNow();
      await store.syncNow();
      expect(server.pushes, pushes);
      expect(server.revChecks, greaterThan(0));
      expect(store.syncStatus, SyncStatus.synced);
    });

    test('dibuka lagi tanpa perubahan tapi HP lain menulis: tetap ditarik', () async {
      final server = _Server();
      final hp = WorkoutStore(server);
      await hp.load('hp@x.com');
      await hp.syncNow();
      final tablet = WorkoutStore(server);
      await tablet.load('tablet@x.com');
      await tablet.syncNow();

      await tablet.addWorkout(_sesi('2026-09-20'));
      await tablet.syncNow();
      await hp.syncNow();
      expect(hp.workouts.map((w) => w.date), ['2026-09-20']);
    });

    test('status "berubah" bertahan setelah aplikasi ditutup', () async {
      final server = _Server()..session = false;
      final hp = WorkoutStore(server);
      await hp.load('hp@x.com');
      await hp.applyTemplate('ppl');
      await hp.syncNow();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('state.hp@x.com.planDirty'), isTrue);
    });
  });

  group('pilih sesi lain hari ini', () {
    test('jadwal Push, dikerjakan Legs: berikutnya kembali ke Push', () async {
      final store = WorkoutStore();
      await store.load('a@x.com');
      await store.applyTemplate('ppl');
      expect(store.nextSessionOn(DateTime(2026, 9, 24))!.routine.name, 'Push');

      await store.addWorkout(_sesi('2026-09-24'), routineId: 'ppl-2');
      expect(store.nextSessionOn(DateTime(2026, 9, 26))!.routine.name, 'Push');
    });

    testWidgets('tombol di Home membuka daftar rutinitas dan memulai yang dipilih', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final store = WorkoutStore();
      await tester.runAsync(() async {
        await ExerciseCatalog.load();
        await store.load('a@x.com');
        await store.applyTemplate('ppl');
      });

      await tester.pumpWidget(WorkoutScope(
        store: store,
        child: AppStrings(
          strings: const Strings(AppLanguage.english),
          child: MaterialApp(theme: buildGymTheme(), home: const Scaffold(body: HomeScreen())),
        ),
      ));
      await tester.pump();

      final button = find.text('Other session');
      await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('WHAT ARE YOU TRAINING TODAY?'), findsOneWidget);
      expect(find.text('Up next'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Legs')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final session = tester.widget<SessionScreen>(find.byType(SessionScreen));
      expect(session.routineName, 'Legs');
      expect(session.routineId, 'ppl-2');
      expect(tester.takeException(), isNull);
    });
  });
}
