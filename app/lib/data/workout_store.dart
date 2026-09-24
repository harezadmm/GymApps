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

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../domain/program.dart';
import '../domain/templates.dart';
import 'backend.dart';
import 'exercise_catalog.dart';

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

  /// Supabase terpasang, tapi HP ini tidak punya sesi server untuk akun yang
  /// sedang masuk — biasanya karena masuknya terjadi tanpa sinyal. Riwayat
  /// tetap tersimpan lokal; masuk ulang saat online menyambungkannya.
  noSession,
}

/// Sidik jari satu sesi, dari isinya. Sesi tidak punya id, dan tanggal saja
/// tidak cukup: satu hari bisa punya dua sesi (pagi kardio, sore beban).
/// Dipakai untuk menggabung riwayat dua perangkat dan untuk mengingat sesi
/// yang sudah dihapus.
String workoutKey(Workout w) =>
    sha1.convert(utf8.encode(jsonEncode(w.toJson()))).toString().substring(0, 20);

class WorkoutStore extends ChangeNotifier {
  WorkoutStore([this._backend]);

  /// null = Supabase belum dikonfigurasi. Seluruh aplikasi tetap jalan;
  /// yang hilang hanya sinkronisasi antar perangkat.
  final Backend? _backend;

  // Dokumen disimpan per akun. Dulu satu kunci untuk seluruh perangkat, dan
  // itu membuat orang kedua yang masuk di HP yang sama melihat — lalu
  // mendorong ke akunnya sendiri — riwayat orang pertama.
  //
  // Akun kosong adalah slot dari masa sebelum ada pemisahan ini. Test
  // memakainya langsung; aplikasi hanya membacanya sekali untuk dipindahkan.
  static String _kDoc(String account) => account.isEmpty ? 'state.doc' : 'state.$account.doc';
  static String _kRev(String account) => account.isEmpty ? 'state.baseRev' : 'state.$account.baseRev';

  /// Program dipilih di HP ini sebelum server pernah terjangkau — biasanya
  /// onboarding yang terpaksa jalan karena tarikan pertama belum datang.
  static String _kPlanLocal(String account) => 'state.$account.planBeforeServer';

  /// Program atau rutinitas diubah di HP ini sejak dorongan terakhir yang
  /// diterima server. Tidak ada = tidak tahu, dan itu dianggap berubah.
  static String _kPlanDirty(String account) => 'state.$account.planDirty';

  /// Cursor rotasi bergeser di HP ini (sesi dicatat, lewati, jadikan
  /// berikutnya) sejak dorongan terakhir yang diterima. Terpisah dari
  /// [_kPlanDirty]: mengikuti program bukan mengubah program.
  static String _kCursorDirty(String account) => 'state.$account.cursorDirty';

  /// Dokumen berubah di HP ini sejak dorongan terakhir yang diterima. Kalau
  /// tidak, sinkron cukup bertanya revisi server — bukan mengunggah seluruh
  /// riwayat setiap kali layar dibuka.
  static String _kDocDirty(String account) => 'state.$account.docDirty';

  /// Berapa banyak sesi terhapus yang diingat. Cukup untuk menutup jeda antar
  /// sinkron dua perangkat, dan tidak membuat dokumennya membengkak.
  static const _removedCap = 500;

  List<Workout> _workouts = const [];

  /// Rutinitas yang disimpan. Program menunjuk ke id-nya.
  List<Routine> _routines = const [];

  /// null = onboarding belum memilih program.
  Program? _program;

  /// Gerakan yang dibuat sendiri karena tidak ada di katalog (FR-C2).
  List<Exercise> _customEx = const [];

  /// Sidik jari sesi yang dihapus di perangkat ini atau perangkat lain.
  /// Tanpa ini, sesi yang dihapus di HP muncul lagi begitu tablet yang masih
  /// menyimpannya ikut sinkron.
  List<String> _removed = const [];

  /// Akun yang dokumennya sedang terbuka. null = tidak ada yang masuk; store
  /// kosong dan tidak menulis apa pun ke disk.
  String? _account;

  /// Naik setiap kali akun dibuka atau ditutup. Pekerjaan asinkron yang
  /// dimulai untuk akun sebelumnya membandingkan angka ini dan berhenti —
  /// dokumen orang yang sudah keluar tidak boleh mendarat di akun berikutnya.
  int _generation = 0;

  /// Server sudah pernah menjawab untuk akun ini (tarik atau dorong berhasil).
  bool _serverSeen = false;

  /// Program saat ini dipilih sebelum server pernah menjawab. Kalau server
  /// ternyata punya rencana, rencana server yang menang: split buatan sendiri
  /// jauh lebih berharga daripada template yang dipilih karena layar
  /// onboarding muncul duluan.
  bool _planBeforeServer = false;

  /// Rencana di HP ini berubah sejak terakhir diterima server. Saat konflik,
  /// rencana HP ini hanya menang kalau memang diubah di sini — kalau tidak,
  /// HP yang sekadar ikut sinkron akan menimpa program yang baru diganti di
  /// HP lain dengan salinan lamanya.
  bool _planDirty = true;

  /// Berapa kali rencana diubah. Dipakai untuk tahu apakah ada perubahan baru
  /// selagi dorongan sedang di jalan.
  int _planEdits = 0;

  bool _cursorDirty = true;
  int _cursorEdits = 0;
  bool _docDirty = true;
  int _docEdits = 0;

  Future<void> _initialSync = Future.value();

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
  List<Exercise> get customExercises => List.unmodifiable(_customEx);
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

  /// Email akun yang datanya sedang terbuka, null kalau tidak ada.
  String? get account => _account;

  /// Sinkron pertama yang dimulai [load]. Menunggunya tidak memulai putaran
  /// sinkron tambahan seperti memanggil [syncNow] lagi.
  Future<void> get initialSync => _initialSync;

  /// Server pernah menjawab untuk akun ini — "tidak ada program" berarti
  /// memang tidak ada, bukan "belum tahu".
  bool get serverChecked => _serverSeen;

  /// Selesai saat [load] pertama kali rampung. Layar yang harus memutuskan
  /// sesuatu dari isi store (misalnya "onboarding perlu diulang?") menunggu
  /// ini, bukan menebak dari store yang belum terbaca.
  Future<void> get ready => _ready.future;
  SyncStatus get syncStatus => _sync;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasBackend => _backend != null;

  /// Buka dokumen milik [account] dari disk, menggantikan apa pun yang sedang
  /// terbuka. Dipanggil setiap kali seseorang masuk. Tanpa argumen, slot lama
  /// yang dipakai — hanya untuk test.
  Future<void> load([String account = '']) async {
    final gen = ++_generation;
    _account = account;
    _loaded = false;
    _empty();
    final prefs = await SharedPreferences.getInstance();
    if (gen != _generation) return;
    if (account.isNotEmpty) await _adoptLegacy(prefs, account);
    if (gen != _generation) return;
    _serverSeen = prefs.getInt(_kRev(account)) != null;
    _planBeforeServer = account.isNotEmpty && (prefs.getBool(_kPlanLocal(account)) ?? false);
    _planDirty = prefs.getBool(_kPlanDirty(account)) ?? true;
    _cursorDirty = prefs.getBool(_kCursorDirty(account)) ?? true;
    _docDirty = prefs.getBool(_kDocDirty(account)) ?? true;
    final raw = prefs.getString(_kDoc(account));
    if (raw != null) {
      try {
        final doc = jsonDecode(raw);
        if (doc is! Map) throw const FormatException('dokumen bukan objek');
        _workouts = _workoutsIn(doc);
        _routines = _routinesIn(doc);
        _program = _programIn(doc);
        _customEx = _customIn(doc);
        _removed = _removedIn(doc);
      } on FormatException catch (e) {
        // Dokumen rusak. Dibiarkan di disk, tidak ditimpa: kalau ini bug
        // penulisan, menghapusnya akan menghapus riwayat orang selamanya.
        debugPrint('state.doc tidak bisa dibaca, riwayat dikosongkan: $e');
        _workouts = const [];
      }
    }
    ExerciseCatalog.registerCustom(_customEx);
    _loaded = true;
    if (!_ready.isCompleted) _ready.complete();
    notifyListeners();
    _initialSync = syncNow();
    unawaited(_initialSync);
  }

  /// Tutup dokumen akun yang sedang terbuka tanpa menghapusnya dari disk.
  /// Dipanggil saat keluar: layar tidak boleh terus menampilkan riwayat orang
  /// yang sudah keluar, dan sinkron tidak boleh terus mendorongnya.
  void close() {
    _generation++;
    _account = null;
    _loaded = false;
    _empty();
    _sync = SyncStatus.idle;
    _lastSyncedAt = null;
    notifyListeners();
  }

  void _empty() {
    _serverSeen = false;
    _planBeforeServer = false;
    _planDirty = true;
    _cursorDirty = true;
    _docDirty = true;
    _workouts = const [];
    _routines = const [];
    _program = null;
    _customEx = const [];
    _removed = const [];
    ExerciseCatalog.registerCustom(const []);
  }

  /// Riwayat yang ditulis sebelum dokumen dipisah per akun ada di satu kunci
  /// bersama. Pemiliknya hampir pasti orang yang masuk pertama sesudah
  /// pembaruan — HP pribadi, satu pemakai — jadi dokumen itu dipindahkan ke
  /// akunnya, sekali, lalu kunci lamanya dihapus supaya akun berikutnya tidak
  /// ikut mewarisinya.
  ///
  /// Revisi server-nya sengaja tidak ikut dipindahkan. Revisi itu milik baris
  /// server entah akun siapa; tanpa revisi, sinkron pertama menarik dan
  /// menggabung dulu, yang aman untuk akun mana pun.
  static Future<void> _adoptLegacy(SharedPreferences prefs, String account) async {
    final legacy = prefs.getString(_kDoc(''));
    if (legacy == null) return;
    if (prefs.getString(_kDoc(account)) == null) {
      await prefs.setString(_kDoc(account), legacy);
    }
    await prefs.remove(_kDoc(''));
    await prefs.remove(_kRev(''));
  }

  /// Simpan satu sesi yang baru selesai.
  ///
  /// Menulis ke disk dulu lalu memberi tahu layar, baru mendorong ke server.
  /// Kalau dorongannya gagal, sesinya tetap ada.
  Future<void> addWorkout(Workout workout, {String? routineId}) async {
    _workouts = [workout, ..._workouts];
    // Sesi dari program menggeser cursor-nya (FR-B3). Sesi bebas tidak.
    final p = _program;
    if (p != null) {
      _program = advanceAfter(p, routineId);
      if (routineId != null) await _markCursor();
    }
    await _commit();
  }

  /// Pasang program baru beserta rutinitasnya, menggantikan yang lama.
  ///
  /// Riwayat tidak disentuh: sesi yang sudah tercatat adalah fakta, dan ganti
  /// program tidak mengubah apa yang dulu diangkat.
  Future<void> setProgram(Program program, List<Routine> routines) async {
    _program = program;
    _routines = List.of(routines);
    await _markPlan();
    final account = _account;
    if (_backend != null && !_serverSeen && account != null && account.isNotEmpty) {
      _planBeforeServer = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPlanLocal(account), true);
    }
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
    await _markPlan();
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
    await _markPlan();
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
    await _markPlan();
    await _commit();
    return copy;
  }

  /// Ganti aturan program (nama, mode, hari, istirahat, urutan).
  Future<void> updateProgram(Program program) async {
    _program = program;
    await _markPlan();
    await _commit();
  }

  /// Jadikan rutinitas ini sesi berikutnya di rotasi.
  Future<void> setNext(String routineId) async {
    final p = _program;
    if (p == null) return;
    final idx = p.order.indexOf(routineId);
    if (idx < 0) return;
    _program = p.copyWith(cursor: idx, clearSkip: true);
    await _markCursor();
    await _commit();
  }

  /// Lewati sesi berikutnya tanpa mencatat apa pun (FR-B4).
  Future<void> skipNext(DateTime today) async {
    final p = _program;
    final next = nextSessionOn(today);
    if (p == null || next == null) return;
    _program = skipNextIn(p, next);
    await _markCursor();
    await _commit();
  }

  /// Buat gerakan custom dan kembalikan hasilnya. Nama yang sama persis dengan
  /// gerakan custom yang sudah ada tidak membuat duplikat — yang lama dipakai.
  Future<Exercise> addCustomExercise({
    required String name,
    required String bodyPart,
    required String target,
    String equipment = '',
  }) async {
    final clean = name.trim();
    for (final e in _customEx) {
      if (e.name.toLowerCase() == clean.toLowerCase()) return e;
    }
    final ex = Exercise(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_idSeq++).toRadixString(36)}',
      name: clean,
      bodyPart: bodyPart,
      equipment: equipment,
      target: target,
      secondary: const [],
      custom: true,
    );
    _customEx = [..._customEx, ex];
    ExerciseCatalog.registerCustom(_customEx);
    await _commit();
    return ex;
  }

  static int _idSeq = 0;

  /// Id yang cukup unik untuk satu orang: waktu dalam mikrodetik plus urutan,
  /// supaya dua rutinitas yang dibuat dalam satu ketukan tidak bertabrakan.
  static String newRoutineId() =>
      'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_idSeq++).toRadixString(36)}';

  Future<void> _commit() async {
    await _markDoc();
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
    _removed = _capRemoved([..._removed, workoutKey(workout)]);
    await _commit();
  }

  Future<void> _markPlan() async {
    _planEdits++;
    _planDirty = true;
    await _flag(_kPlanDirty, true);
  }

  Future<void> _markCursor() async {
    _cursorEdits++;
    _cursorDirty = true;
    await _flag(_kCursorDirty, true);
  }

  Future<void> _markDoc() async {
    _docEdits++;
    _docDirty = true;
    await _flag(_kDocDirty, true);
  }

  Future<void> _flag(String Function(String) key, bool value) async {
    final account = _account;
    if (account == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key(account), value);
  }

  /// Dorongan diterima server. Tanda "berubah" hanya dilepas untuk bagian
  /// yang tidak diubah lagi selagi dorongan itu di jalan — perubahan yang
  /// datang di tengahnya belum ada di server.
  Future<void> _sent((int, int, int) atSend) async {
    final (plan, cursor, doc) = atSend;
    if (_planEdits == plan && _planDirty) {
      _planDirty = false;
      await _flag(_kPlanDirty, false);
    }
    if (_cursorEdits == cursor && _cursorDirty) {
      _cursorDirty = false;
      await _flag(_kCursorDirty, false);
    }
    if (_docEdits == doc && _docDirty) {
      _docDirty = false;
      await _flag(_kDocDirty, false);
    }
  }

  static List<String> _capRemoved(List<String> keys) {
    final unique = keys.toSet().toList();
    return unique.length <= _removedCap ? unique : unique.sublist(unique.length - _removedCap);
  }

  /// Hapus semua riwayat. Untuk tombol "hapus data" dan untuk test.
  Future<void> clear() async {
    _empty();
    await _markPlan();
    await _markDoc();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final account = _account;
    if (account == null) return;
    final gen = _generation;
    final doc = jsonEncode(toDocument());
    final prefs = await SharedPreferences.getInstance();
    if (gen != _generation) return;
    await prefs.setString(_kDoc(account), doc);
  }

  /// Bentuk dokumen yang dikirim ke server dan ditulis ke disk.
  Map<String, dynamic> toDocument() => {
        'schema': stateSchema,
        'workouts': [for (final w in _workouts) w.toJson()],
        if (_routines.isNotEmpty) 'routines': [for (final r in _routines) r.toJson()],
        if (_program != null) 'program': _program!.toJson(),
        if (_customEx.isNotEmpty) 'customEx': [for (final e in _customEx) e.toJson()],
        if (_removed.isNotEmpty) 'removed': _removed,
      };

  static List<String> _removedIn(Map doc) => [
        for (final k in (doc['removed'] as List? ?? const [])) if (k is String) k,
      ];

  static List<Exercise> _customIn(Map doc) => [
        for (final e in (doc['customEx'] as List? ?? const []))
          Exercise.fromJson({...Map<String, dynamic>.from(e as Map), 'custom': true}),
      ];

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

  Future<void>? _syncing;
  bool _syncAgain = false;

  /// Dorong keadaan lokal ke server, tarik kalau server lebih maju.
  ///
  /// Aman dipanggil kapan saja: tanpa backend ia langsung selesai tanpa
  /// melakukan apa pun, dan kegagalan tidak pernah menyentuh data lokal.
  ///
  /// Panggilan yang datang selagi sinkron berjalan tidak memulai sinkron
  /// kedua yang saling tindih — ia menunggu yang sedang jalan, lalu satu
  /// putaran lagi dijalankan supaya perubahan terbarunya ikut naik.
  Future<void> syncNow() {
    if (_backend == null || !_loaded || _account == null) return Future.value();
    final running = _syncing;
    if (running != null) {
      _syncAgain = true;
      return running;
    }
    final run = _syncLoop();
    _syncing = run;
    return run.whenComplete(() {
      if (identical(_syncing, run)) _syncing = null;
    });
  }

  Future<void> _syncLoop() async {
    // Dibatasi supaya konflik yang terus berulang (mustahil dalam pemakaian
    // biasa) tidak memutar sinkron tanpa henti. Perubahan yang tertinggal
    // ikut naik di sinkron berikutnya.
    var rounds = 0;
    do {
      _syncAgain = false;
      await _syncOnce();
    } while (_syncAgain && _loaded && _account != null && ++rounds < 4);
  }

  Future<void> _syncOnce() async {
    final backend = _backend!;
    final account = _account;
    final gen = _generation;
    if (account == null || !_loaded) return;
    bool stale() => gen != _generation;

    // Sesi server harus milik akun yang sedang terbuka. Kalau keluar dulu
    // gagal di tengah jalan, sesi orang sebelumnya bisa tertinggal — dan
    // mendorong dengan sesi itu berarti menulis riwayat orang ini ke baris
    // orang lain. Diperiksa ulang sebelum setiap tulis dan setiap gabung,
    // karena sesi bisa berganti selagi jaringan menjawab.
    bool wrongSession() {
      final who = backend.signedInEmail;
      return account.isNotEmpty && who != null && who.trim().toLowerCase() != account;
    }

    if (wrongSession()) {
      debugPrint('sesi server milik akun lain; sinkron dilewati');
      _sync = SyncStatus.noSession;
      notifyListeners();
      return;
    }

    _sync = SyncStatus.syncing;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      var baseRev = prefs.getInt(_kRev(account));

      // HP ini belum pernah sinkron untuk akun ini — HP baru, pasang ulang,
      // atau akun yang baru pertama kali masuk di sini. Dokumen server ditarik
      // dan digabung dulu. Tanpa langkah ini, push pertama membawa baseRev
      // kosong, dan push_state memperlakukannya sebagai "timpa": riwayat di
      // server diganti dokumen kosong milik HP baru.
      var pulledNow = false;
      if (baseRev == null) {
        pulledNow = true;
        final pulled = await backend.pull();
        if (stale()) return;
        if (wrongSession()) throw const NotSignedIn();
        _serverSeen = true;
        if (pulled != null) {
          _absorb(pulled.state, preferServerPlan: _planBeforeServer);
          await _persist();
          if (stale()) return;
          notifyListeners();
        }
        if (_planBeforeServer) {
          _planBeforeServer = false;
          await prefs.remove(_kPlanLocal(account));
        }
        // 0, bukan null: "saya kira barisnya belum ada". Kalau ternyata sudah
        // ada, server menjawab konflik dan dokumennya digabung, bukan ditimpa.
        baseRev = pulled?.rev ?? 0;
      }

      // Tidak ada yang berubah di HP ini: cukup tanya revisi server. Sama
      // dengan yang terakhir diterima = tidak ada yang perlu ditarik maupun
      // didorong. Ini jalur yang dilewati setiap kali aplikasi dibuka lagi.
      if (!pulledNow && !_docDirty) {
        final serverRev = await backend.getRev();
        if (stale()) return;
        if (serverRev == baseRev) {
          _serverSeen = true;
          _sync = SyncStatus.synced;
          _lastSyncedAt = DateTime.now();
          notifyListeners();
          return;
        }
      }

      if (wrongSession()) throw const NotSignedIn();
      var snap = (_planEdits, _cursorEdits, _docEdits);
      final result = await backend.push(baseRev: baseRev, state: toDocument());
      if (stale()) return;

      var accepted = false;
      switch (result) {
        case PushAccepted(rev: final rev):
          await prefs.setInt(_kRev(account), rev);
          await _sent(snap);
          accepted = true;

        // Perangkat lain menulis lebih dulu. Riwayat lokal digabung dengan
        // salinan server, bukan ditimpa — sesi yang baru dicatat di HP ini
        // tidak boleh hilang karena tablet menyimpan duluan.
        case PushConflict(rev: final rev, state: final theirs):
          if (wrongSession()) throw const NotSignedIn();
          _absorb(theirs);
          await _persist();
          if (stale()) return;
          notifyListeners();
          if (wrongSession()) throw const NotSignedIn();
          snap = (_planEdits, _cursorEdits, _docEdits);
          final retry = await backend.push(baseRev: rev, state: toDocument());
          if (stale()) return;
          if (retry case PushAccepted(rev: final newRev)) {
            await prefs.setInt(_kRev(account), newRev);
            await _sent(snap);
            accepted = true;
          } else {
            // Ditolak lagi: perangkat lain menulis di antara dua dorongan.
            // Satu putaran lagi, bukan klaim "tersinkron" yang tidak benar.
            _syncAgain = true;
          }
      }

      _serverSeen = true;
      if (accepted) {
        _sync = SyncStatus.synced;
        _lastSyncedAt = DateTime.now();
      } else {
        _sync = SyncStatus.failed;
      }
    } on NotSignedIn {
      // Supabase terpasang tapi tidak ada sesi server. Aplikasi tetap bisa
      // dipakai; yang hilang hanya sinkronnya, dan Profil menyebutnya.
      if (stale()) return;
      _sync = SyncStatus.noSession;
    } catch (e) {
      if (stale()) return;
      debugPrint('sync gagal: $e');
      _sync = SyncStatus.failed;
    }
    notifyListeners();
  }

  /// Gabungkan dokumen dari server ke keadaan lokal.
  void _absorb(Map theirs, {bool preferServerPlan = false}) {
    _removed = _capRemoved([..._removed, ..._removedIn(theirs)]);
    _workouts = _merge(_workouts, _workoutsIn(theirs), _removed.toSet());
    // Rencana tidak digabung per baris; satu sisi yang dipakai utuh. Milik
    // perangkat ini hanya menang kalau memang diubah di sini sejak sinkron
    // terakhir. Rencana server dipakai kalau perangkat ini belum punya rencana
    // (baru dipasang), rencananya dipilih sebelum server sempat ditanya, atau
    // perangkat ini tidak mengubah apa pun sementara HP lain mengubahnya.
    if (_program == null || (theirs['program'] is Map && (preferServerPlan || !_planDirty))) {
      final mine = _program;
      final server = _programIn(theirs);
      _program = server;
      _routines = _routinesIn(theirs);
      // Struktur rencana diambil dari server, tapi sesi yang dicatat di HP ini
      // menggeser cursor-nya. Selama urutan rutinitasnya masih sama, posisi
      // rotasi dari HP ini yang dipakai; kalau urutannya diganti di HP lain,
      // posisi lama tidak berarti apa-apa lagi dan milik server yang dipakai.
      if (mine != null && server != null && _cursorDirty && !preferServerPlan && listEquals(mine.order, server.order)) {
        _program = server.copyWith(cursor: mine.cursor, skippedOn: mine.skippedOn, clearSkip: mine.skippedOn == null);
      }
    }
    // Gerakan custom digabung per id: gerakan yang dibuat di HP lain dipakai
    // riwayat di sana, dan membuangnya membuat sesi itu kehilangan nama
    // gerakannya.
    final ids = {for (final e in _customEx) e.id};
    _customEx = [..._customEx, for (final e in _customIn(theirs)) if (!ids.contains(e.id)) e];
    ExerciseCatalog.registerCustom(_customEx);
  }

  /// Gabung dua riwayat: semua sesi dari keduanya, sesi yang sama persis
  /// cukup sekali, dan sesi yang pernah dihapus di perangkat mana pun tidak
  /// dihidupkan lagi.
  ///
  /// Dulu digabung per tanggal — satu tanggal satu sesi. Itu diam-diam
  /// membuang sesi kedua hari yang sama, bahkan yang dua-duanya dicatat di HP
  /// ini, begitu sinkron pertama kali bertemu konflik.
  static List<Workout> _merge(List<Workout> mine, List<Workout> theirs, Set<String> removed) {
    final seen = <String>{};
    final out = <(int, Workout)>[];
    for (final w in [...mine, ...theirs]) {
      final k = workoutKey(w);
      if (removed.contains(k) || !seen.add(k)) continue;
      out.add((out.length, w));
    }
    // Terbaru dulu. Urutan asal dipakai sebagai penentu untuk tanggal yang
    // sama, karena sort bawaan Dart tidak menjamin stabil.
    out.sort((a, b) {
      final byDate = b.$2.date.compareTo(a.$2.date);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
    return [for (final (_, w) in out) w];
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
