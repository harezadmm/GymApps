import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/data/backend.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/units.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server palsu di memori. Yang diuji perilaku store saat push diterima atau
/// ditolak, bukan Supabase-nya.
class _FakeBackend implements Backend {
  @override
  String? get signedInEmail => null;

  _FakeBackend({this.rev, Map<String, dynamic>? state}) : state = state ?? {};

  int? rev;
  Map<String, dynamic> state;

  /// Kalau true, push pertama dijawab konflik. Meniru perangkat lain yang
  /// menulis lebih dulu selagi HP ini offline.
  bool conflictOnce = false;

  int pushes = 0;

  @override
  Future<int?> getRev() async => rev;

  @override
  Future<PulledState?> pull() async =>
      rev == null ? null : PulledState(rev: rev!, state: state);

  @override
  Future<PushResult> push({
    required int? baseRev,
    required Map<String, dynamic> state,
  }) async {
    pushes++;
    if (conflictOnce) {
      conflictOnce = false;
      return PushConflict(rev: rev ?? 1, state: this.state);
    }
    this.state = state;
    rev = (rev ?? 0) + 1;
    return PushAccepted(rev!);
  }
}

/// Backend yang selalu gagal, untuk menguji bahwa kegagalan jaringan tidak
/// pernah menyentuh data lokal.
class _BrokenBackend implements Backend {
  @override
  String? get signedInEmail => null;

  @override
  Future<int?> getRev() async => throw Exception('tidak ada jaringan');

  @override
  Future<PulledState?> pull() async => throw Exception('tidak ada jaringan');

  @override
  Future<PushResult> push({
    required int? baseRev,
    required Map<String, dynamic> state,
  }) async =>
      throw Exception('tidak ada jaringan');
}

Workout _sesi(String tanggal, {int entri = 1, double berat = 60}) => Workout(
      date: tanggal,
      entries: [
        for (var i = 0; i < entri; i++)
          WorkoutEntry(
            exerciseId: 'bench-press-$i',
            sets: [
              SetRow(weight: berat, reps: 8, done: true),
              SetRow(weight: berat, reps: 7, done: true),
            ],
          ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('simpan lokal', () {
    test('sesi baru masuk ke daftar', () async {
      final store = WorkoutStore();
      await store.load();
      await store.addWorkout(_sesi('2026-09-16'));
      expect(store.workouts.length, 1);
      expect(store.workouts.first.date, '2026-09-16');
    });

    test('sesi bertahan setelah aplikasi ditutup', () async {
      // Inti seluruh berkas ini. Sebelum ada store, tepat di sinilah data
      // latihan orang hilang setiap kali aplikasi dimatikan.
      final pertama = WorkoutStore();
      await pertama.load();
      await pertama.addWorkout(_sesi('2026-09-16', berat: 72.5));

      final kedua = WorkoutStore();
      await kedua.load();
      expect(kedua.workouts.length, 1);
      expect(kedua.workouts.first.entries.first.sets.first.weight, 72.5);
    });

    test('terbaru berada di urutan pertama', () async {
      final store = WorkoutStore();
      await store.load();
      await store.addWorkout(_sesi('2026-09-14'));
      await store.addWorkout(_sesi('2026-09-16'));
      expect(store.workouts.map((w) => w.date), ['2026-09-16', '2026-09-14']);
    });

    test('bentuk set pulih utuh, bukan cuma berat dan repetisi', () async {
      final pertama = WorkoutStore();
      await pertama.load();
      await pertama.addWorkout(Workout(date: '2026-09-16', entries: [
        WorkoutEntry(exerciseId: 'plank', sets: [
          SetRow(weight: 0, reps: 0, seconds: 45, done: true, phase: SetPhase.warmup, rir: 2),
        ]),
      ]));

      final kedua = WorkoutStore();
      await kedua.load();
      final s = kedua.workouts.first.entries.first.sets.first;
      expect(s.seconds, 45);
      expect(s.phase, SetPhase.warmup);
      expect(s.rir, 2);
    });

    test('dokumen rusak tidak membuat aplikasi gagal jalan', () async {
      SharedPreferences.setMockInitialValues({'state.doc': 'bukan json'});
      final store = WorkoutStore();
      await store.load();
      expect(store.loaded, isTrue);
      expect(store.workouts, isEmpty);
    });

    test('hapus mengosongkan riwayat di disk juga', () async {
      final pertama = WorkoutStore();
      await pertama.load();
      await pertama.addWorkout(_sesi('2026-09-16'));
      await pertama.clear();

      final kedua = WorkoutStore();
      await kedua.load();
      expect(kedua.workouts, isEmpty);
    });
  });

  group('sinkron', () {
    test('tanpa backend aplikasi tetap jalan', () async {
      final store = WorkoutStore();
      await store.load();
      await store.addWorkout(_sesi('2026-09-16'));
      expect(store.hasBackend, isFalse);
      expect(store.syncStatus, SyncStatus.idle);
      expect(store.workouts.length, 1);
    });

    test('sesi didorong ke server', () async {
      final server = _FakeBackend();
      final store = WorkoutStore(server);
      await store.load();
      await store.addWorkout(_sesi('2026-09-16'));
      await store.syncNow();

      expect(store.syncStatus, SyncStatus.synced);
      expect((server.state['workouts'] as List).length, 1);
      expect(server.state['schema'], stateSchema);
    });

    test('jaringan mati tidak menghilangkan sesi', () async {
      final store = WorkoutStore(_BrokenBackend());
      await store.load();
      await store.addWorkout(_sesi('2026-09-16'));
      await store.syncNow();

      expect(store.syncStatus, SyncStatus.failed);
      expect(store.workouts.length, 1);
    });

    test('konflik menggabung, bukan menimpa', () async {
      // Tablet menyimpan sesi tanggal 14 selagi HP ini offline mencatat
      // tanggal 16. Setelah sinkron, keduanya harus ada.
      final server = _FakeBackend(rev: 3, state: {
        'schema': stateSchema,
        'workouts': [_sesi('2026-09-14').toJson()],
      })
        ..conflictOnce = true;

      final store = WorkoutStore(server);
      await store.load();
      await store.addWorkout(_sesi('2026-09-16'));
      await store.syncNow();

      expect(store.workouts.map((w) => w.date), ['2026-09-16', '2026-09-14']);
      expect((server.state['workouts'] as List).length, 2);
    });

    test('sesi berbeda di tanggal yang sama sama-sama dipertahankan', () async {
      // Dulu digabung per tanggal dan yang setnya lebih banyak menang — yang
      // lain dibuang. Padahal dua sesi berbeda di satu hari itu biasa (pagi
      // kardio, sore beban), dan membuang salah satunya berarti menghapus
      // latihan. Sesi yang sama persis tetap cukup sekali; lihat
      // account_sync_test.dart.
      final server = _FakeBackend(rev: 2, state: {
        'schema': stateSchema,
        'workouts': [_sesi('2026-09-16', entri: 1).toJson()],
      })
        ..conflictOnce = true;

      final store = WorkoutStore(server);
      await store.load();
      await store.addWorkout(_sesi('2026-09-16', entri: 4));
      await store.syncNow();

      expect(store.workouts.length, 2);
      expect(store.workouts.map((w) => w.entries.length).toSet(), {1, 4});
    });

    test('setelan yang diubah di dua perangkat sama-sama dipertahankan', () async {
      // HP mengganti unit ke lb; tablet (offline) menyalakan RIR. Dulu satu
      // perangkat menimpa seluruh setelan, dan unit balik ke kg diam-diam.
      final server = _FakeBackend();
      final store = WorkoutStore(server);
      await store.load();
      await store.syncNow();
      expect(store.syncStatus, SyncStatus.synced);

      server
        ..state = {...server.state, 'settings': {'unit': 'lb'}}
        ..rev = server.rev! + 1
        ..conflictOnce = true;

      await store.updateSettings(store.settings.copyWith(logRir: true));
      await store.syncNow();

      expect(store.settings.logRir, isTrue);
      expect(store.settings.unit, WeightUnit.lb);
      expect(server.state['settings'], {'rir': true, 'unit': 'lb'});
    });

    test('mergeSettings: kolom yang tidak diubah di sini ikut server', () {
      expect(
        WorkoutStore.mergeSettings(
          base: {'rest': 120, 'unit': 'lb'},
          mine: {'rest': 120, 'unit': 'lb', 'rir': true},
          theirs: {'rest': 90},
        ),
        {'rest': 90, 'rir': true},
      );
    });
  });
  group('program dan rutinitas', () {
    test('template terpasang dan bertahan setelah aplikasi ditutup', () async {
      final a = WorkoutStore();
      await a.load();
      expect(a.hasProgram, isFalse);
      expect(await a.applyTemplate('ppl'), isTrue);

      final b = WorkoutStore();
      await b.load();
      expect(b.hasProgram, isTrue);
      expect(b.program!.name, 'Push / Pull / Legs');
      expect(b.routines.map((r) => r.name), ['Push', 'Pull', 'Legs']);
      expect(b.routines.first.exercises, isNotEmpty);
    });

    test('sesi dari program menggeser cursor, freestyle tidak', () async {
      final store = WorkoutStore();
      await store.load();
      await store.applyTemplate('ppl');
      final push = store.routines.first;

      await store.addWorkout(_sesi('2026-09-20'), routineId: push.id);
      expect(store.program!.cursor, 1);
      await store.addWorkout(_sesi('2026-09-21'));
      expect(store.program!.cursor, 1);
    });

    test('rutinitas baru masuk urutan program, hapus mengeluarkannya', () async {
      final store = WorkoutStore();
      await store.load();
      await store.applyTemplate('upper-lower');
      const extra = Routine(id: 'arms', name: 'Arms');
      await store.saveRoutine(extra);
      expect(store.program!.order.last, 'arms');

      await store.deleteRoutine('arms');
      expect(store.program!.order, isNot(contains('arms')));
      expect(store.routines.map((r) => r.id), isNot(contains('arms')));
    });

    test('hapus rutinitas sebelum cursor tidak menggeser sesi berikutnya', () async {
      final store = WorkoutStore();
      await store.load();
      await store.applyTemplate('ppl');
      await store.setNext('ppl-2'); // Legs berikutnya
      await store.deleteRoutine('ppl-0'); // hapus Push
      final next = store.nextSessionOn(DateTime(2026, 9, 21))!;
      expect(next.routine.name, 'Legs');
    });

    test('duplikat masuk tepat di belakang aslinya', () async {
      final store = WorkoutStore();
      await store.load();
      await store.applyTemplate('ppl');
      await store.duplicateRoutine('ppl-0', 'Push copy');
      expect(store.routines.map((r) => r.name).take(2), ['Push', 'Push copy']);
      expect(store.program!.order.length, 4);
    });

    test('rutinitas dan program ikut terkirim ke server', () async {
      final server = _FakeBackend();
      final store = WorkoutStore(server);
      await store.load();
      await store.applyTemplate('heavy-duty');
      await store.syncNow();
      expect((server.state['routines'] as List).length, 4);
      expect((server.state['program'] as Map)['rest'], 3);
    });

    test('riwayat kronologis terlama dulu', () async {
      final store = WorkoutStore();
      await store.load();
      await store.addWorkout(_sesi('2026-09-10'));
      await store.addWorkout(_sesi('2026-09-20'));
      expect(store.workouts.first.date, '2026-09-20');
      expect(store.chronological.first.date, '2026-09-10');
    });
  });
}
