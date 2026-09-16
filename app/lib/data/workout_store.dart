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
  bool _loaded = false;
  SyncStatus _sync = SyncStatus.idle;
  DateTime? _lastSyncedAt;

  /// Riwayat, terbaru dulu. Salinan tak-berubah: layar tidak boleh menyunting
  /// daftar ini diam-diam tanpa lewat [addWorkout].
  List<Workout> get workouts => List.unmodifiable(_workouts);

  bool get loaded => _loaded;
  SyncStatus get syncStatus => _sync;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasBackend => _backend != null;

  /// Baca dari disk. Dipanggil sekali saat aplikasi mulai.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDoc);
    if (raw != null) {
      try {
        _workouts = _decode(raw);
      } on FormatException catch (e) {
        // Dokumen rusak. Dibiarkan di disk, tidak ditimpa: kalau ini bug
        // penulisan, menghapusnya akan menghapus riwayat orang selamanya.
        debugPrint('state.doc tidak bisa dibaca, riwayat dikosongkan: $e');
        _workouts = const [];
      }
    }
    _loaded = true;
    notifyListeners();
    unawaited(syncNow());
  }

  /// Simpan satu sesi yang baru selesai.
  ///
  /// Menulis ke disk dulu lalu memberi tahu layar, baru mendorong ke server.
  /// Kalau dorongannya gagal, sesinya tetap ada.
  Future<void> addWorkout(Workout workout) async {
    _workouts = [workout, ..._workouts];
    await _persist();
    notifyListeners();
    unawaited(syncNow());
  }

  /// Hapus semua riwayat. Untuk tombol "hapus data" dan untuk test.
  Future<void> clear() async {
    _workouts = const [];
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
      };

  List<Workout> _decode(String raw) {
    final doc = jsonDecode(raw);
    if (doc is! Map) throw const FormatException('dokumen bukan objek');
    return _workoutsIn(doc);
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
}

extension WorkoutStoreX on BuildContext {
  /// Riwayat latihan, hidup. Membacanya membuat widget ini ikut tergambar
  /// ulang setiap kali ada sesi baru.
  WorkoutStore get workouts => WorkoutScope.of(this);
}
