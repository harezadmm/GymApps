/// Satu-satunya tempat riwayat latihan hidup.
///
/// **Lokal dulu, server menyusul.** Sesi disimpan ke perangkat seketika, dan
/// baru kemudian didorong ke Supabase kalau ada. Urutannya sengaja begitu:
/// mencatat set tidak boleh menunggu jaringan. Orang menekan centang di antara
/// dua set, bukan di antara dua batang sinyal.
///
/// **Bentuk dokumennya sama dengan yang dipakai openGym** (lihat
/// `reference/opengym/src/lib/sync-merge.js`): satu objek berisi seluruh
/// keadaan akun, bukan tabel per-sesi. Itu yang membuat aturan merge dan
/// `baseRev` di [Backend] bisa dipakai apa adanya.
///
/// **Kenapa satu dokumen, bukan satu baris per sesi:** riwayat setahun orang
/// yang latihan empat kali seminggu kira-kira 200 KB. Menariknya sekaligus
/// lebih sederhana daripada menyatukan ratusan baris, dan konfliknya bisa
/// diselesaikan sekali, bukan per baris.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../domain/program.dart';
import '../domain/templates.dart';
import 'backend.dart';

/// Nomor bentuk dokumen. Dinaikkan kalau susunannya berubah sedemikian rupa
/// sehingga versi lama tidak bisa membacanya; pembacanya lalu bisa memutuskan
/// untuk memigrasi atau menolak dengan jujur, bukan salah membaca diam-diam.
const stateSchema = 1;

/// Hasil satu percobaan sinkronisasi, untuk ditampilkan di layar Profil.
enum SyncStatus {
  /// Belum pernah dicoba, atau Supabase memang tidak dikonfigurasi.
  idle,
  syncing,
  synced,

  /// Gagal — biasanya jaringan. Data lokalnya aman; percobaan berikutnya
  /// akan mengejar ketinggalan.
  failed,
}

class WorkoutStore extends ChangeNotifier {
  WorkoutStore([this._backend]);

  /// null = Supabase belum dikonfigurasi. Seluruh aplikasi tetap jalan;
  /// yang hilang hanya sinkronisasi antar perangkat.
  final Backend? _backend;

  static const _kDoc = 'state.doc';
  static const _kRev = 'state.baseRev';

  List<Workout> _workouts = const [];

  /// Rutinitas yang disimpan. Program menunjuk ke id-nya.
  List<Routine> _routines = const [];

  /// null = onboarding belum memilih program.
  Program? _program;

  bool _loaded = false;
  final _ready = Completer<void>();
  SyncStatus _sync = SyncStatus.idle;
  DateTime? _lastSyncedAt;

  /// Riwayat, terbaru dulu. Salinan tak-berubah: layar tidak boleh menyunting
  /// daftar ini diam-diam tanpa lewat [addWorkout].
  List<Workout> get workouts => List.unmodifiable(_workouts);

  /// Riwayat terlama dulu — urutan yang diminta mesin progresi. Memberi
  /// [workouts] ke sana membuat "sesi terakhir" terbaca sebagai sesi pertama.
  List<Workout> get chronological => List.unmodifiable(_workouts.reversed);

  List<Routine> get routines => List.unmodifiable(_routines);
  Program? get program => _program;

  /// Program sudah dipilih — onboarding tidak perlu diulang.
  bool get hasProgram => _program != null;

  Routine? routineById(String id) {
    for (final r in _routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Sesi yang disarankan berikutnya, dihitung dari program dan riwayat.
  NextSession? nextSessionOn(DateTime today) {
    final p = _program;
    if (p == null) return null;
    return nextSession(program: p, routines: _routines, history: _workouts, today: today);
  }

  bool get loaded => _loaded;

  /// Selesai saat [load] pertama kali rampung. Layar yang harus memutuskan
  /// sesuatu dari isi store (misalnya "onboarding perlu diulang?") menunggu
  /// ini, bukan menebak dari store yang belum terbaca.
  Future<void> get ready => _ready.future;
  SyncStatus get syncStatus => _sync;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasBackend => _backend != null;

  /// Baca dari disk. Dipanggil sekali saat aplikasi mulai.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDoc);
    if (raw != null) {
      try {
        final doc = jsonDecode(raw);
        if (doc is! Map) throw const FormatException('dokumen bukan objek');
        _workouts = _workoutsIn(doc);
        _routines = _routinesIn(doc);
        _program = _programIn(doc);
      } on FormatException catch (e) {
        // Dokumen rusak. Dibiarkan di disk, tidak ditimpa: kalau ini bug
        // penulisan, menghapusnya akan menghapus riwayat orang selamanya.
        debugPrint('state.doc tidak bisa dibaca, riwayat dikosongkan: $e');
        _workouts = const [];
      }
    }
    _loaded = true;
    if (!_ready.isCompleted) _ready.complete();
    notifyListeners();
    unawaited(syncNow());
  }

  /// Simpan satu sesi yang baru selesai.
  ///
  /// Menulis ke disk dulu lalu memberi tahu layar, baru mendorong ke server.
  /// Kalau dorongannya gagal, sesinya tetap ada.
  Future<void> addWorkout(Workout workout, {String? routineId}) async {
    _workouts = [workout, ..._workouts];
    // Sesi dari program menggeser cursor-nya (FR-B3). Sesi bebas tidak.
    final p = _program;
    if (p != null) _program = advanceAfter(p, routineId);
    await _commit();
  }

  /// Pasang program baru beserta rutinitasnya, menggantikan yang lama.
  ///
  /// Riwayat tidak disentuh: sesi yang sudah tercatat adalah fakta, dan ganti
  /// program tidak mengubah apa yang dulu diangkat.
  Future<void> setProgram(Program program, List<Routine> routines) async {
    _program = program;
    _routines = List.of(routines);
    await _commit();
  }

  /// Pasang template bawaan. false kalau id-nya tidak dikenal.
  Future<bool> applyTemplate(String templateId) async {
    final bundle = buildTemplate(templateId);
    if (bundle == null) return false;
    await setProgram(bundle.program, bundle.routines);
    return true;
  }

  /// Simpan rutinitas: ganti yang id-nya sama, atau tambahkan. Rutinitas baru
  /// ikut masuk ke urutan program supaya muncul di rotasi.
  Future<void> saveRoutine(Routine routine) async {
    final i = _routines.indexWhere((r) => r.id == routine.id);
    if (i >= 0) {
      _routines = [..._routines]..[i] = routine;
    } else {
      _routines = [..._routines, routine];
      final p = _program ?? const Program(name: 'My split');
      _program = p.copyWith(order: [...p.order, routine.id]);
    }
    await _commit();
  }

  /// Hapus rutinitas dan keluarkan dari urutan program. Cursor dijaga tetap
  /// menunjuk ke rutinitas yang sama kalau masih ada.
  Future<void> deleteRoutine(String id) async {
    _routines = _routines.where((r) => r.id != id).toList();
    final p = _program;
    if (p != null) {
      final idx = p.order.indexOf(id);
      final order = [...p.order]..remove(id);
      var cursor = p.cursor;
      if (idx >= 0 && idx < cursor) cursor--;
      _program = p.copyWith(order: order, cursor: order.isEmpty ? 0 : cursor % order.length);
    }
    await _commit();
  }

  /// Salin rutinitas tepat di belakang aslinya, di daftar dan di urutan program.
  Future<Routine?> duplicateRoutine(String id, String newName) async {
    final src = routineById(id);
    if (src == null) return null;
    final copy = src.copyWith(id: newRoutineId(), name: newName);
    final i = _routines.indexOf(src);
    _routines = [..._routines]..insert(i + 1, copy);
    final p = _program;
    if (p != null) {
      final at = p.order.indexOf(id);
      final order = [...p.order];
      at < 0 ? order.add(copy.id) : order.insert(at + 1, copy.id);
      var cursor = p.cursor;
      if (at >= 0 && at < cursor) cursor++;
      _program = p.copyWith(order: order, cursor: cursor);
    }
    await _commit();
    return copy;
  }

  /// Ganti aturan program (nama, mode, hari, istirahat, urutan).
  Future<void> updateProgram(Program program) async {
    _program = program;
    await _commit();
  }

  /// Jadikan rutinitas ini sesi berikutnya di rotasi.
  Future<void> setNext(String routineId) async {
    final p = _program;
    if (p == null) return;
    final idx = p.order.indexOf(routineId);
    if (idx < 0) return;
    _program = p.copyWith(cursor: idx, clearSkip: true);
    await _commit();
  }

  /// Lewati sesi berikutnya tanpa mencatat apa pun (FR-B4).
  Future<void> skipNext(DateTime today) async {
    final p = _program;
    final next = nextSessionOn(today);
    if (p == null || next == null) return;
    _program = skipNextIn(p, next);
    await _commit();
  }

  static int _idSeq = 0;

  /// Id yang cukup unik untuk satu orang: waktu dalam mikrodetik plus urutan,
  /// supaya dua rutinitas yang dibuat dalam satu ketukan tidak bertabrakan.
  static String newRoutineId() =>
      'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_idSeq++).toRadixString(36)}';

  Future<void> _commit() async {
    await _persist();
    notifyListeners();
    unawaited(syncNow());
  }

  /// Hapus satu sesi dari riwayat. Dicocokkan lewat identitas objek, bukan
  /// tanggal: satu hari bisa punya dua sesi (pagi kardio, sore beban).
  Future<void> removeWorkout(Workout workout) async {
    final i = _workouts.indexWhere((w) => identical(w, workout));
    if (i < 0) return;
    _workouts = [..._workouts]..removeAt(i);
    await _commit();
  }

  /// Hapus semua riwayat. Untuk tombol "hapus data" dan untuk test.
  Future<void> clear() async {
    _workouts = const [];
    _routines = const [];
    _program = null;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDoc, jsonEncode(toDocument()));
  }

  /// Bentuk dokumen yang dikirim ke server dan ditulis ke disk.
  Map<String, dynamic> toDocument() => {
        'schema': stateSchema,
        'workouts': [for (final w in _workouts) w.toJson()],
        if (_routines.isNotEmpty) 'routines': [for (final r in _routines) r.toJson()],
        if (_program != null) 'program': _program!.toJson(),
      };

  static List<Routine> _routinesIn(Map doc) => [
        for (final r in (doc['routines'] as List? ?? const []))
          Routine.fromJson(Map<String, dynamic>.from(r as Map)),
      ];

  static Program? _programIn(Map doc) {
    final p = doc['program'];
    return p is Map ? Program.fromJson(Map<String, dynamic>.from(p)) : null;
  }

  /// Ambil daftar sesi dari sebuah dokumen, entah datang dari disk atau server.
  static List<Workout> _workoutsIn(Map doc) => [
        for (final w in (doc['workouts'] as List? ?? const []))
          Workout.fromJson(Map<String, dynamic>.from(w as Map)),
      ];

  /// Dorong keadaan lokal ke server, tarik kalau server lebih maju.
  ///
  /// Aman dipanggil kapan saja: tanpa backend ia langsung selesai tanpa
  /// melakukan apa pun, dan kegagalan tidak pernah menyentuh data lokal.
  Future<void> syncNow() async {
    final backend = _backend;
    if (backend == null || !_loaded) return;

    _sync = SyncStatus.syncing;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final baseRev = prefs.getInt(_kRev);
      final result = await backend.push(baseRev: baseRev, state: toDocument());

      switch (result) {
        case PushAccepted(rev: final rev):
          await prefs.setInt(_kRev, rev);

        // Perangkat lain menulis lebih dulu. Untuk sekarang salinan server
        // yang menang dan riwayat lokal digabung dengannya, bukan ditimpa —
        // sesi yang baru dicatat di HP ini tidak boleh hilang karena tablet
        // menyimpan duluan.
        case PushConflict(rev: final rev, state: final theirs):
          _workouts = _merge(_workouts, _workoutsIn(theirs));
          // Rencana tidak digabung per baris: yang ada di perangkat ini yang
          // dipakai, kecuali perangkat ini belum punya rencana sama sekali —
          // misalnya baru dipasang dan belum lewat onboarding.
          if (_program == null) {
            _program = _programIn(theirs);
            _routines = _routinesIn(theirs);
          }
          await _persist();
          final retry = await backend.push(baseRev: rev, state: toDocument());
          if (retry case PushAccepted(rev: final newRev)) {
            await prefs.setInt(_kRev, newRev);
          }
      }

      _sync = SyncStatus.synced;
      _lastSyncedAt = DateTime.now();
    } on NotSignedIn {
      // Belum masuk ke Supabase. Bukan kegagalan yang perlu dikeluhkan —
      // aplikasi memang boleh dipakai tanpa akun server.
      _sync = SyncStatus.idle;
    } catch (e) {
      debugPrint('sync gagal: $e');
      _sync = SyncStatus.failed;
    }
    notifyListeners();
  }

  /// Gabung dua riwayat berdasarkan tanggal sesi.
  ///
  /// Sengaja sederhana dan bisa ditebak: satu tanggal hanya boleh punya satu
  /// sesi, dan yang entri-nya lebih banyak yang dipakai. Aturan yang lebih
  /// pintar butuh stempel waktu per set, dan itu belum ada.
  static List<Workout> _merge(List<Workout> mine, List<Workout> theirs) {
    final byDate = <String, Workout>{};
    for (final w in [...theirs, ...mine]) {
      final existing = byDate[w.date];
      if (existing == null || w.entries.length > existing.entries.length) {
        byDate[w.date] = w;
      }
    }
    final out = byDate.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return out;
  }
}

/// Menyalurkan [WorkoutStore] ke seluruh pohon widget.
///
/// `InheritedNotifier`, bukan `InheritedWidget` biasa seperti `AppStrings`:
/// store-nya berubah sendiri (sesi selesai, sinkron kelar), jadi layar yang
/// membacanya harus ikut menggambar ulang tanpa ada yang memanggil setState.
class WorkoutScope extends InheritedNotifier<WorkoutStore> {
  const WorkoutScope({super.key, required WorkoutStore store, required super.child})
      : super(notifier: store);

  static WorkoutStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WorkoutScope>();
    assert(scope?.notifier != null, 'WorkoutScope tidak ada di atas widget ini');
    return scope!.notifier!;
  }

  /// Ambil store tanpa ikut berlangganan perubahannya.
  ///
  /// Untuk pemanggil yang hanya ingin *menyuruh* store melakukan sesuatu dan
  /// tidak menggambar apa pun dari isinya — misalnya memicu sinkron setelah
  /// masuk. Memakai [of] di sana akan menandai widget-nya bergantung pada
  /// setiap perubahan riwayat tanpa alasan.
  static WorkoutStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<WorkoutScope>();
    assert(scope?.notifier != null, 'WorkoutScope tidak ada di atas widget ini');
    return scope!.notifier!;
  }
}

extension WorkoutStoreX on BuildContext {
  /// Riwayat latihan, hidup. Membacanya membuat widget ini ikut tergambar
  /// ulang setiap kali ada sesi baru.
  WorkoutStore get workouts => WorkoutScope.of(this);
}
