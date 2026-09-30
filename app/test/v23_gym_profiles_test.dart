/// Profil gym per tempat latihan (FR-C3) dan memori beban per gym (FR-C4).
///
/// Lahir dari orang yang latihan di dua tempat: gym dekat rumah punya
/// kettlebell, gym dekat kantor tidak, dan chest press "yang sama" di dua
/// gym tidak sama beratnya. Yang dijaga di sini: dokumen lama bermigrasi
/// tanpa kehilangan daftar alat, dua HP yang sama-sama menyunting gym tidak
/// saling menghapus, target dan PREV mengikuti gym, dan layarnya benar-benar
/// bisa dipakai — tambah, aktifkan, hapus, saring library, pilih gym saat
/// membuka sesi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/backend.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/progression.dart';
import 'package:gymapps/domain/session_plan.dart';
import 'package:gymapps/domain/settings.dart';
import 'package:gymapps/domain/units.dart';
import 'package:gymapps/features/home/home_screen.dart';
import 'package:gymapps/features/library/library_screen.dart';
import 'package:gymapps/features/profile/gym_profiles.dart';
import 'package:gymapps/features/profile/profile_screen.dart';
import 'package:gymapps/features/session/session_launcher.dart';
import 'package:gymapps/features/session/session_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server palsu di memori, seperti di workout_store_test: yang diuji
/// perilaku store saat push ditolak karena HP lain menulis lebih dulu.
class _FakeBackend implements Backend {
  @override
  String? get signedInEmail => null;

  int? rev;
  Map<String, dynamic> state = {};
  bool conflictOnce = false;

  @override
  Future<int?> getRev() async => rev;

  @override
  Future<PulledState?> pull() async => rev == null ? null : PulledState(rev: rev!, state: state);

  @override
  Future<PushResult> push({required int? baseRev, required Map<String, dynamic> state}) async {
    if (conflictOnce) {
      conflictOnce = false;
      return PushConflict(rev: rev ?? 1, state: this.state);
    }
    this.state = state;
    rev = (rev ?? 0) + 1;
    return PushAccepted(rev!);
  }
}

const _bench = ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, sets: 3, reps: 8);

/// Satu sesi bench press, tiga set kerja tercentang penuh, di satu gym.
Workout _sesi(String date, double w, {String? gym, String? routine, String? note}) => Workout(
      date: date,
      routine: routine,
      gymId: gym,
      entries: [
        WorkoutEntry(
          exerciseId: '0025',
          target: _bench,
          note: note,
          sets: [for (var i = 0; i < 3; i++) SetRow(weight: w, reps: 8, done: true)],
        ),
      ],
    );

const _default = GymProfile(id: defaultGymId, name: '', equipment: ['barbell']);
const _gymB = GymProfile(id: 'b', name: 'Gym B');
const _gymC = GymProfile(id: 'c', name: 'Gym C', equipment: ['dumbbell']);

Map<String, dynamic> _doc(List<GymProfile> gyms, {String? active}) =>
    TrainingSettings(gyms: gyms, activeGymId: active ?? gyms.first.id).toJson();

TrainingSettings _merged(Map<String, dynamic> base, Map<String, dynamic> mine, Map<String, dynamic> theirs) =>
    TrainingSettings.fromJson(WorkoutStore.mergeSettings(base: base, mine: mine, theirs: theirs));

Widget _wrap(WorkoutStore store, Widget home) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: const Strings(AppLanguage.english),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
  });

  group('migrasi setelan', () {
    test('dokumen lama dengan kunci eq menjadi satu gym bawaan yang membawa daftar itu', () {
      final s = TrainingSettings.fromJson({'eq': ['barbell', 'dumbbell']});
      expect(s.gyms.length, 1);
      expect(s.gyms.single.id, defaultGymId);
      expect(s.gyms.single.name, isEmpty, reason: 'nama bawaan dua bahasa diberikan UI, bukan disimpan');
      expect(s.gyms.single.equipment, ['barbell', 'dumbbell']);
      expect(s.activeGymId, defaultGymId);
      expect(s.equipment, ['barbell', 'dumbbell']);
      expect(s.hasEquipment('dumbbell'), isTrue);
      expect(s.hasEquipment('kettlebell'), isFalse);
      expect(s.hasEquipment('body weight'), isTrue);
    });

    test('dokumen kosong mendapat satu gym bawaan tanpa batasan alat', () {
      final s = TrainingSettings.fromJson({});
      expect(s.gyms.length, 1);
      expect(s.gyms.single.id, defaultGymId);
      expect(s.gyms.single.equipment, isNull);
      expect(s.activeGymId, defaultGymId);
      expect(s.hasEquipment('kettlebell'), isTrue);
    });

    test('akun satu gym: eq seperti dulu plus penanda activeGymId, tanpa daftar gyms', () {
      // Build lama di HP lain hanya mengenal `eq`; daftar gym tidak perlu
      // ditulis untuk satu gym bawaan. Penandanya yang membedakan dokumen ini
      // dari dokumen build lama saat digabung (lihat mergeGymSettings).
      expect(const TrainingSettings(gyms: [_default]).toJson(), {'eq': ['barbell'], 'activeGymId': 'default'});
      expect(const TrainingSettings().toJson(), {'activeGymId': 'default'});
    });

    test('dua gym bolak-balik JSON utuh, dan eq mencerminkan gym aktif', () {
      const s = TrainingSettings(gyms: [_default, _gymB], activeGymId: 'b');
      final j = s.toJson();
      expect(j['gyms'], hasLength(2));
      expect(j['activeGymId'], 'b');
      expect(j.containsKey('eq'), isFalse, reason: 'Gym B tanpa batasan alat: tidak ada cermin');

      final back = TrainingSettings.fromJson(j);
      expect(back.gyms.map((g) => g.id), ['default', 'b']);
      expect(back.gyms.first.equipment, ['barbell']);
      expect(back.gyms.last.name, 'Gym B');
      expect(back.activeGymId, 'b');

      final atDefault = TrainingSettings.fromJson(s.withActiveGym(defaultGymId).toJson());
      expect(atDefault.toJson()['eq'], ['barbell'], reason: 'cermin mengikuti gym aktif');
    });

    test('id gym aktif yang tidak dikenal jatuh ke gym pertama, bukan melempar', () {
      final s = TrainingSettings.fromJson({
        'gyms': [_gymB.toJson(), _gymC.toJson()],
        'activeGymId': 'hilang',
      });
      expect(s.activeGymId, 'b');
      expect(s.activeGym.id, 'b');
      expect(s.withActiveGym('hilang').activeGymId, 'b', reason: 'id tak dikenal tidak mengubah apa pun');
    });

    test('hapus gym: yang terakhir tidak pernah, menghapus yang aktif memindahkan aktif', () {
      const s = TrainingSettings(gyms: [_default, _gymB], activeGymId: 'b');
      final afterB = s.withoutGym('b');
      expect(afterB.gyms.map((g) => g.id), ['default']);
      expect(afterB.activeGymId, defaultGymId);
      expect(afterB.withoutGym(defaultGymId).gyms, hasLength(1), reason: 'daftar kosong tidak punya arti');
      expect(s.withoutGym('tidak-ada').gyms, hasLength(2));
    });

    test('alat per gym: diubah di satu gym, gym lain tidak tersentuh', () {
      const s = TrainingSettings(gyms: [_default, _gymB]);
      final t = s.withGymEquipment('b', ['kettlebell']);
      expect(t.gymById('b')!.equipment, ['kettlebell']);
      expect(t.gymById(defaultGymId)!.equipment, ['barbell']);
      expect(t.withGymEquipment('b', null).gymById('b')!.equipment, isNull);
    });
  });

  group('gabung setelan dua perangkat', () {
    test('gym yang ditambah di dua HP sama-sama dipertahankan', () {
      // HP menambah Gym B, tablet (offline) menambah Gym C. Sebagai satu
      // kolom, salah satunya hilang; per id, dua-duanya ada.
      final m = _merged(_doc([_default]), _doc([_default, _gymB]), _doc([_default, _gymC]));
      expect(m.gyms.map((g) => g.id), ['default', 'b', 'c']);
      expect(m.gymById('c')!.equipment, ['dumbbell']);
      expect(m.activeGymId, defaultGymId);
    });

    test('gym yang diubah di sini menang, yang tidak disentuh ikut server', () {
      final base = _doc([_default, _gymB, _gymC]);
      final mine = _doc([_default, _gymB.copyWith(name: 'Gym B (baru)'), _gymC]);
      final theirs = _doc([_default, _gymB.copyWith(equipment: ['cable']), _gymC.copyWith(name: 'Gym C2')]);
      final m = _merged(base, mine, theirs);
      expect(m.gymById('b')!.name, 'Gym B (baru)', reason: 'diubah di sini');
      expect(m.gymById('b')!.equipment, isNull, reason: 'aturan per kolom: satu sisi utuh');
      expect(m.gymById('c')!.name, 'Gym C2', reason: 'tidak disentuh di sini, ikut server');
    });

    test('dihapus di HP lain: ikut terhapus kalau tidak disentuh, tetap kalau diubah di sini', () {
      final base = _doc([_default, _gymB, _gymC]);
      final theirs = _doc([_default]);
      final untouched = _merged(base, _doc([_default, _gymB, _gymC]), theirs);
      expect(untouched.gyms.map((g) => g.id), ['default']);

      final edited = _merged(base, _doc([_default, _gymB.copyWith(name: 'Gym B!'), _gymC]), theirs);
      expect(edited.gyms.map((g) => g.id), ['default', 'b'], reason: 'perubahan menang atas penghapusan');
    });

    test('gym aktif mengikuti aturan per kolom', () {
      final base = _doc([_default, _gymB, _gymC]);
      expect(_merged(base, _doc([_default, _gymB, _gymC], active: 'b'), _doc([_default, _gymB, _gymC], active: 'c'))
          .activeGymId, 'b', reason: 'diganti di sini');
      expect(_merged(base, _doc([_default, _gymB, _gymC]), _doc([_default, _gymB, _gymC], active: 'c')).activeGymId,
          'c', reason: 'hanya diganti di server');
      expect(_merged(base, _doc([_default, _gymB, _gymC], active: 'c'), _doc([_default, _gymB])).activeGymId,
          defaultGymId, reason: 'gym aktif dihapus di server: jatuh ke gym pertama');
    });

    test('build lama di HP lain hanya menulis eq: daftar gym tidak hilang, alatnya masuk ke gym aktif', () {
      final base = _doc([_default, _gymB]);
      final m = _merged(base, base, {'eq': ['dumbbell', 'cable']});
      expect(m.gyms.map((g) => g.id), ['default', 'b']);
      expect(m.gymById(defaultGymId)!.equipment, ['dumbbell', 'cable']);
      // Cermin eq ditulis ulang dari hasil gabungan.
      expect(WorkoutStore.mergeSettings(base: base, mine: base, theirs: {'eq': ['dumbbell', 'cable']})['eq'],
          ['dumbbell', 'cable']);
    });

    test('kolom lain tetap per kolom, dan akun bawaan tidak mendapat kolom gyms', () {
      expect(
        WorkoutStore.mergeSettings(
          base: {'rest': 120, 'eq': ['barbell']},
          mine: {'rest': 120, 'rir': true, 'eq': ['barbell'], 'activeGymId': 'default'},
          theirs: {'rest': 90, 'eq': ['dumbbell']},
        ),
        {'rest': 90, 'rir': true, 'eq': ['dumbbell'], 'activeGymId': 'default'},
      );
    });

    test('sinkron dengan konflik: gym dari HP ini dan dari server dua-duanya ada', () async {
      final server = _FakeBackend();
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.syncNow();
      expect(store.syncStatus, SyncStatus.synced);

      // Tablet menambah Gym C dan menulis lebih dulu.
      server
        ..state = {...server.state, 'settings': _doc([GymProfile.fallback, _gymC])}
        ..rev = server.rev! + 1
        ..conflictOnce = true;

      await store.updateSettings(store.settings.withGym(_gymB));
      await store.syncNow();

      expect(store.settings.gyms.map((g) => g.id), containsAll(['default', 'b', 'c']));
      expect(store.settings.gyms, hasLength(3));
      final pushed = TrainingSettings.fromJson(Map<String, dynamic>.from(server.state['settings'] as Map));
      expect(pushed.gyms, hasLength(3));
    });

    test('sinkron dengan build lama di HP lain: daftar gym tidak hilang, alatnya tetap masuk', () async {
      // Build lama membaca dan menulis hanya `eq`, dan membuang kolom yang
      // tidak dikenalnya. Dokumennya tiba tanpa `gyms` maupun penanda; kalau
      // dibaca sebagai "semua gym dihapus", Gym B lenyap pada setiap sinkron.
      final server = _FakeBackend();
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.updateSettings(store.settings.withGym(_gymB));
      await store.syncNow();
      expect(store.syncStatus, SyncStatus.synced);

      server
        ..state = {...server.state, 'settings': {'eq': ['dumbbell']}}
        ..rev = server.rev! + 1
        ..conflictOnce = true;

      await store.updateSettings(store.settings.copyWith(logRir: true));
      await store.syncNow();

      expect(store.settings.gyms.map((g) => g.id), ['default', 'b']);
      expect(store.settings.gymById(defaultGymId)!.equipment, ['dumbbell'], reason: 'alat dari build lama');
      expect(store.settings.logRir, isTrue);
      final pushed = Map<String, dynamic>.from(server.state['settings'] as Map);
      expect(pushed['eq'], ['dumbbell'], reason: 'cermin untuk build lama');
      expect(pushed['gyms'], hasLength(2));
    });

    test('gym yang dihapus di HP lain sampai tinggal gym bawaan ikut terhapus di sini', () async {
      // Kebalikan dari kasus build lama: dokumen build baru tanpa `gyms` tapi
      // dengan penanda berarti memang tinggal satu gym.
      final server = _FakeBackend();
      final store = WorkoutStore(server);
      await store.load('a@x.com');
      await store.updateSettings(store.settings.withGym(_gymB));
      await store.syncNow();

      server
        ..state = {...server.state, 'settings': const TrainingSettings().toJson()}
        ..rev = server.rev! + 1
        ..conflictOnce = true;

      await store.updateSettings(store.settings.copyWith(logRir: true));
      await store.syncNow();

      expect(store.settings.gyms.map((g) => g.id), ['default']);
    });
  });

  group('memori beban per gym (FR-C4)', () {
    // Chest press 60 kg di Gym A (bawaan), 50 kg di Gym B — kriteria
    // penerimaan FR-C4. Terlama dulu, seperti yang diminta planExercise.
    final history = [
      _sesi('2026-09-20', 60, gym: defaultGymId, note: 'kursi 4'),
      _sesi('2026-09-22', 50, gym: 'b', note: 'kursi 2'),
      _sesi('2026-09-24', 60, gym: defaultGymId),
    ];

    test('target dan PREV mengikuti gym aktif', () {
      final atB = planExercise(_bench, history, gymId: 'b');
      expect(atB.prescription.weight, 52.5, reason: '50 kg sukses di B → +2,5');
      expect(atB.previous.first, '50 × 8');
      expect(atB.lastNote, 'kursi 2');

      final atA = planExercise(_bench, history, gymId: defaultGymId);
      expect(atA.prescription.weight, 62.5);
      expect(atA.previous.first, '60 × 8');
      expect(atA.lastNote, isNull, reason: 'catatan dari sesi terakhir di gym itu, bukan sesi lama');
    });

    test('gym yang belum pernah mencatat gerakan itu memakai seluruh riwayat', () {
      final atC = planExercise(_bench, history, gymId: 'c');
      expect(atC.prescription.weight, 62.5, reason: 'sesi terakhir di mana pun: 60 kg');
      expect(atC.previous.first, '60 × 8');
      expect(identical(gymHistory(history, '0025', 'c'), history), isTrue);
      expect(identical(gymHistory(history, '0025', null), history), isTrue);
    });

    test('riwayat sebelum profil gym ada milik gym bawaan, bukan dibuang', () {
      final old = [
        _sesi('2026-09-20', 60),
        _sesi('2026-09-22', 50, gym: 'b'),
      ];
      expect(planExercise(_bench, old, gymId: defaultGymId).prescription.weight, 62.5);
      expect(planExercise(_bench, old, gymId: 'b').prescription.weight, 52.5);
      expect(planExercise(_bench, old).prescription.weight, 52.5, reason: 'tanpa gym: sesi terakhir');
    });

    test('saringan rutinitas deload tetap berlaku sesudah riwayat dipersempit ke gym', () {
      const deload = Routine(id: 'd', name: 'Deload', exercises: [_bench], excludedFromProgression: true);
      final mixed = [
        _sesi('2026-09-20', 60, gym: 'b'),
        _sesi('2026-09-22', 40, gym: 'b', routine: 'Deload'),
      ];
      final plan = planExercise(_bench, mixed, gymId: 'b', routines: const [deload]);
      expect(plan.prescription.weight, 62.5, reason: 'sesi deload bukan dasar target');
      expect(plan.previous.first, '40 × 8', reason: 'tapi PREV tetap fakta');
    });

    test('sesi gym lain tidak ikut menghitung rentetan gagal', () {
      const dbl = ExerciseConfig(exerciseId: '0025', policy: ProgressionPolicy.linear, sets: 3, reps: 8);
      Workout miss(String date, String gym) => Workout(date: date, gymId: gym, entries: [
            WorkoutEntry(exerciseId: '0025', target: dbl, sets: const [
              SetRow(weight: 60, reps: 8, done: true),
              SetRow(weight: 60, reps: 6, done: true),
              SetRow(weight: 60, reps: 5, done: true),
            ]),
          ]);
      final h = [miss('2026-09-01', 'b'), miss('2026-09-03', 'b'), miss('2026-09-05', 'b'), miss('2026-09-07', 'a')];
      expect(planExercise(dbl, h, gymId: 'b').prescription.kind, PrescriptionKind.deload);
      expect(planExercise(dbl, h, gymId: 'a').prescription.kind, PrescriptionKind.hold,
          reason: 'di gym A baru gagal sekali');
    });
  });

  group('Workout.gymId', () {
    test('bolak-balik JSON lewat kunci gym; tidak ada = null = gym bawaan', () {
      final w = _sesi('2026-09-20', 60, gym: 'b');
      expect(w.toJson()['gym'], 'b');
      expect(Workout.fromJson(w.toJson()).gymId, 'b');
      final old = Workout.fromJson({'date': '2026-09-20', 'entries': []});
      expect(old.gymId, isNull);
      expect(old.gymOrDefault, defaultGymId);
      expect(old.toJson().containsKey('gym'), isFalse);
      expect(Workout.fromJson({'date': '2026-09-20', 'gym': 7, 'entries': []}).gymId, isNull);
    });

    test('bertahan lewat copyWith, konversi satuan, dan disk', () async {
      final w = _sesi('2026-09-20', 60, gym: 'b');
      expect(w.copyWith(notes: 'x').gymId, 'b');
      expect(workoutToKg(w, WeightUnit.lb).gymId, 'b');

      final a = WorkoutStore();
      await a.load('a@x.com');
      await a.addWorkout(w);
      final b = WorkoutStore();
      await b.load('a@x.com');
      expect(b.workouts.single.gymId, 'b');
    });
  });

  group('layar', () {
    Widget profile(WorkoutStore store) => _wrap(
          store,
          Scaffold(
            body: ProfileScreen(
              language: AppLanguage.english,
              onLanguageChanged: (_) {},
              onSignOut: () {},
              email: 'a@x.com',
            ),
          ),
        );

    Future<void> scrollTo(WidgetTester tester, Finder f) async {
      await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
    }

    testWidgets('Profil: tambah gym, aktifkan lewat ketukan, hapus; gym terakhir tidak bisa dihapus',
        (tester) async {
      _phone(tester);
      final store = WorkoutStore();
      await store.load('a@x.com');
      await tester.pumpWidget(profile(store));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Add gym'));
      expect(find.text('My gym'), findsOneWidget, reason: 'nama bawaan dari UI');
      expect(find.text('Active'), findsOneWidget);

      // Tambah lewat dialog nama.
      await tester.tap(find.text('Add gym'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Gym B');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('Gym B'), findsOneWidget);
      expect(store.settings.gyms, hasLength(2));
      expect(store.settings.activeGymId, defaultGymId, reason: 'gym baru tidak langsung aktif');

      // Ketuk = aktifkan.
      await scrollTo(tester, find.text('Gym B'));
      await tester.tap(find.text('Gym B'));
      await tester.pumpAndSettle();
      final bId = store.settings.gyms.last.id;
      expect(store.settings.activeGymId, bId);
      expect(find.text('Active'), findsOneWidget);

      // Hapus lewat ⋯ → sheet → dialog konfirmasi.
      final options = find.descendant(of: find.widgetWithText(SelectRow, 'Gym B'), matching: find.byTooltip('Gym options'));
      await tester.tap(options);
      await tester.pumpAndSettle();
      expect(find.text('Equipment at this gym'), findsOneWidget);
      await tester.tap(find.text('Delete gym'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();
      expect(find.text('Gym B'), findsNothing);
      expect(store.settings.gyms, hasLength(1));
      expect(store.settings.activeGymId, defaultGymId, reason: 'menghapus gym aktif memindahkan aktif');

      // Gym terakhir: tidak ada pilihan hapus, aksi lain tetap ada.
      await tester.tap(find.byTooltip('Gym options'));
      await tester.pumpAndSettle();
      expect(find.text('Delete gym'), findsNothing);
      expect(find.text('Rename gym'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Profil: ganti nama gym bawaan; menyimpan nama bawaan lagi tetap dua bahasa', (tester) async {
      _phone(tester);
      final store = WorkoutStore();
      await store.load('a@x.com');
      await tester.pumpWidget(profile(store));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Add gym'));

      await tester.tap(find.byTooltip('Gym options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename gym'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(store.settings.activeGym.name, isEmpty, reason: 'nama bawaan tidak disimpan');

      await tester.tap(find.byTooltip('Gym options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename gym'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Gym Rumah');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(store.settings.activeGym.name, 'Gym Rumah');
      expect(find.text('Gym Rumah'), findsOneWidget);
      expect(find.text('My gym'), findsNothing);
    });

    testWidgets('library: saringan "Alat saya" mengikuti gym aktif', (tester) async {
      _phone(tester);
      final store = WorkoutStore();
      await store.load('a@x.com');
      // Gym bawaan tanpa kettlebell (aktif), Gym B dengan semua alat.
      await store.updateSettings(store.settings.withGymEquipment(defaultGymId, ['barbell']).withGym(_gymB));
      await tester.runAsync(() => ExerciseCatalog.load());

      await tester.pumpWidget(_wrap(store, const ExerciseLibraryScreen(picking: true)));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'kettlebell advanced windmill');
      await tester.pump();
      expect(find.text('Kettlebell Advanced Windmill'), findsNothing);
      expect(find.textContaining('Nothing matches'), findsOneWidget);

      await store.updateSettings(store.settings.withActiveGym('b'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Kettlebell Advanced Windmill'), findsOneWidget);
      expect(find.textContaining('Nothing matches'), findsNothing);

      await store.updateSettings(store.settings.withActiveGym(defaultGymId));
      await tester.pump();
      await tester.pump();
      expect(find.text('Kettlebell Advanced Windmill'), findsNothing);
    });

    testWidgets('Home: chip gym hanya tampil dengan lebih dari satu gym, dan mengganti gym aktif', (tester) async {
      _phone(tester);
      final store = WorkoutStore();
      await store.load('a@x.com');
      await tester.pumpWidget(_wrap(store, Scaffold(body: HomeScreen(email: 'a@x.com'))));
      await tester.pumpAndSettle();
      expect(find.byType(GymChip), findsNothing, reason: 'akun satu gym tidak melihat apa pun');

      await store.updateSettings(store.settings.withGym(_gymB));
      await tester.pumpAndSettle();
      expect(find.text('My gym'), findsOneWidget);
      expect(tester.getSize(find.byType(GymChip)).height, greaterThanOrEqualTo(44), reason: 'NFR-11');

      await tester.tap(find.byType(GymChip));
      await tester.pumpAndSettle();
      expect(find.text('Training where today?'), findsOneWidget);
      await tester.tap(find.text('Gym B'));
      await tester.pumpAndSettle();
      expect(store.settings.activeGymId, 'b');
      expect(find.text('Gym B'), findsOneWidget, reason: 'chip mengikuti gym aktif');
      expect(tester.takeException(), isNull);
    });

    testWidgets('membuka sesi dengan dua gym: pemilih dulu, pilihannya jadi gym sesi dan gym aktif',
        (tester) async {
      _phone(tester);
      final store = WorkoutStore();
      await tester.runAsync(() async {
        await ExerciseCatalog.load();
        await store.load('a@x.com');
        await store.applyTemplate('ppl');
        await store.updateSettings(store.settings.withGym(_gymB));
      });
      final push = store.routines.first;
      await tester.pumpWidget(_wrap(
        store,
        Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(onPressed: () => openRoutineSession(context, push), child: const Text('go')),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('go'));
      await _settle(tester);
      expect(find.text('Training where today?'), findsOneWidget);
      expect(find.byType(SessionScreen), findsNothing);

      await tester.tap(find.text('Gym B'));
      await _settle(tester);
      expect(store.settings.activeGymId, 'b');
      expect(find.byType(SessionScreen), findsOneWidget);
      expect(tester.widget<SessionScreen>(find.byType(SessionScreen)).gymId, 'b');
      // Chip gym di bilah atas sesi.
      expect(find.descendant(of: find.byType(SessionScreen), matching: find.text('Gym B')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('membuka sesi dengan satu gym: langsung, tanpa pemilih dan tanpa chip', (tester) async {
      _phone(tester);
      final store = WorkoutStore();
      await tester.runAsync(() async {
        await ExerciseCatalog.load();
        await store.load('a@x.com');
        await store.applyTemplate('ppl');
      });
      final push = store.routines.first;
      await tester.pumpWidget(_wrap(
        store,
        Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(onPressed: () => openRoutineSession(context, push), child: const Text('go')),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('go'));
      await _settle(tester);
      expect(find.text('Training where today?'), findsNothing);
      expect(find.byType(SessionScreen), findsOneWidget);
      expect(tester.widget<SessionScreen>(find.byType(SessionScreen)).gymId, defaultGymId,
          reason: 'sesi tetap mencatat gymnya walau cuma satu');
      expect(find.text('My gym'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
