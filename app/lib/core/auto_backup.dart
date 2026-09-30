/// Cadangan harian otomatis ke folder Download HP (FR-A5, FR-A6).
///
/// Sasaran keamanan data PRD: nol sesi hilang. Ekspor manual (FR-A6) hanya
/// menolong orang yang ingat mengekspor, dan sinkron ke server hanya menolong
/// yang menyalakannya. HP yang rusak atau aplikasi yang terhapus sebelum dua
/// hal itu membawa seluruh riwayatnya pergi. Jadi sekali sehari — setelah
/// perubahan pertama yang tersimpan, atau saat akun dibuka kalau hari ini
/// belum — dokumen ekspor yang persis sama dengan "Ekspor cadangan" di Profil
/// ditulis ke `Download/GymApps/gymapps-backup-YYYY-MM-DD.json` di koleksi
/// Download publik: bertahan setelah aplikasi dihapus, terlihat di pengelola
/// berkas mana pun, dan bisa dibuka lagi lewat "Impor cadangan" yang sudah
/// ada. Tujuh berkas harian terakhir disimpan; yang lebih lama dihapus.
///
/// Hanya Android (NFR-9: Android 10+): web punya sinkron, iOS di luar
/// lingkup. Setelannya per perangkat (SharedPreferences), bukan di dokumen
/// yang disinkronkan — mematikannya di tablet tidak boleh ikut mematikan di
/// HP.
///
/// Keputusannya fungsi murni ([AutoBackup.shouldBackup],
/// [AutoBackup.fileName], [AutoBackup.pruneList]) supaya bisa diuji tanpa
/// Android; penulisannya lewat [BackupSink], yang di Android adalah
/// MethodChannel ke `MainActivity.kt` (MediaStore.Downloads) dan di platform
/// lain tidak berbuat apa-apa.
library;

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/program.dart' show isoDate;

/// Dokumen ekspor: isi `WorkoutStore.toDocument()` plus `exportedAt` — persis
/// yang ditulis "Ekspor cadangan" di Profil, dan yang dibaca "Impor cadangan".
/// Cadangan otomatis memakai fungsi yang sama supaya keduanya tidak pernah
/// berbeda diam-diam.
Map<String, dynamic> exportDocument(Map<String, dynamic> doc, DateTime now) =>
    {...doc, 'exportedAt': now.toIso8601String()};

/// [exportDocument] sebagai byte JSON, dengan indentasi yang sama dengan
/// ekspor manual supaya berkasnya tetap bisa dibaca orang kalau perlu.
Uint8List exportBytes(Map<String, dynamic> doc, DateTime now) =>
    utf8.encode(const JsonEncoder.withIndent(' ').convert(exportDocument(doc, now)));

/// Hasil satu percobaan cadangan, untuk snackbar "Simpan sekarang".
enum BackupOutcome {
  saved,

  /// Bukan Android 10+, atau tidak ada jembatan ke Android sama sekali.
  unsupported,
  failed,
}

/// Tempat berkas cadangan ditulis. Di Android [MethodChannelBackupSink]; di
/// platform lain [NoopBackupSink]; di uji tiruan yang mencatat panggilan.
abstract interface class BackupSink {
  /// Tulis [bytes] sebagai `Download/GymApps/[name]`, menimpa berkas dengan
  /// nama yang sama. `false` = platform ini tidak mendukungnya dan tidak ada
  /// yang ditulis. Kegagalan lain dilempar.
  Future<bool> write(String name, Uint8List bytes);

  /// Nama berkas di `Download/GymApps` yang berawalan [prefix].
  Future<List<String>> list(String prefix);

  /// Hapus `Download/GymApps/[name]`; tidak ada = tidak apa-apa.
  Future<void> delete(String name);
}

/// Jembatan ke `MainActivity.kt`: tiga metode di atas MediaStore.Downloads.
/// Android menjawab `"unsupported"` di bawah Android 10 dan tidak berbuat
/// apa-apa.
class MethodChannelBackupSink implements BackupSink {
  const MethodChannelBackupSink();

  static const channel = MethodChannel('dev.hariz.gymapps/backup');

  @override
  Future<bool> write(String name, Uint8List bytes) async {
    final r = await channel.invokeMethod<String>('writeDownload', {'name': name, 'bytes': bytes});
    return r != 'unsupported';
  }

  @override
  Future<List<String>> list(String prefix) async {
    final r = await channel.invokeMethod<Object>('listDownloads', {'prefix': prefix});
    return r is List ? [for (final n in r) if (n is String) n] : const [];
  }

  @override
  Future<void> delete(String name) async {
    await channel.invokeMethod<void>('deleteDownload', {'name': name});
  }
}

/// Platform tanpa cadangan otomatis (web, iOS): tidak menulis apa-apa dan
/// bilang begitu.
class NoopBackupSink implements BackupSink {
  const NoopBackupSink();

  @override
  Future<bool> write(String name, Uint8List bytes) async => false;

  @override
  Future<List<String>> list(String prefix) async => const [];

  @override
  Future<void> delete(String name) async {}
}

class AutoBackup {
  AutoBackup._();

  /// Awalan nama berkas. Yang tidak berawalan ini bukan milik aplikasi dan
  /// tidak pernah dihapus.
  static const prefix = 'gymapps-backup-';

  /// Berapa berkas harian yang disimpan. Seminggu cukup untuk "kemarin saya
  /// tidak sengaja menghapus sesi" tanpa memenuhi Download dengan salinan
  /// riwayat yang sama.
  static const keep = 7;

  /// Setelan perangkat, seperti `KeepAwake`: soal HP ini, bukan akun.
  static const _kEnabled = 'settings.autoBackup';
  static const _kLastDate = 'backup.lastDate';

  /// Nama berkas yang kita buat: awalan, tanggal, `.json` — termasuk varian
  /// `… (1).json` yang diberikan MediaStore saat nama itu sudah dipakai
  /// berkas pemasangan lama. Tanpa izin penyimpanan, daftar dari Android
  /// hanya berisi baris milik pemasangan ini (berkas pemasangan lama tidak
  /// terlihat, apalagi terhapus), jadi nama berpola ini di daftar itu pasti
  /// kita yang membuat. Berkas yang diganti namanya orangnya bukan lagi
  /// urusan kita.
  static final _ownName = RegExp(r'^gymapps-backup-\d{4}-\d{2}-\d{2}( \(\d+\))?\.json$');

  // ── Keputusan (murni) ─────────────────────────────────────────────────

  /// Hari ini belum ada cadangan? [lastBackupDate] tanggal `YYYY-MM-DD`
  /// lokal dari cadangan terakhir (null = belum pernah), [today] jam
  /// sekarang.
  ///
  /// Yang dibandingkan hari kalender **lokal**: "sekali sehari" menurut hari
  /// yang dilihat orangnya, jadi 23:59 dan 00:01 adalah dua hari walau
  /// selisihnya dua menit, dan tengah malam UTC bukan batas apa-apa di
  /// Jakarta. Tanggal terakhir yang berbeda ke arah mana pun berarti cadangan
  /// lagi — jam HP yang dimundurkan paling-paling menghasilkan satu berkas
  /// ekstra, bukan satu hari tanpa cadangan.
  static bool shouldBackup(String? lastBackupDate, DateTime today) => lastBackupDate != isoDate(today.toLocal());

  /// `gymapps-backup-YYYY-MM-DD.json` dari tanggal lokal [date] — nama yang
  /// sama dengan ekspor manual di hari itu.
  static String fileName(DateTime date) => '$prefix${isoDate(date.toLocal())}.json';

  /// Dari nama-nama berkas di folder, yang harus dihapus: berkas kita yang
  /// bukan [keep] terbaru. Urutannya dari nama — tanggal ISO urut secara
  /// leksikal — bukan dari waktu ubah berkas, yang bergeser saat orangnya
  /// menyalin foldernya. Nama yang bukan pola kita dilewati.
  static List<String> pruneList(Iterable<String> names, {int keep = AutoBackup.keep}) {
    final ours = names.where(_ownName.hasMatch).toSet().toList()..sort((a, b) => b.compareTo(a));
    return ours.sublist(keep.clamp(0, ours.length));
  }

  /// Layak dicadangkan otomatis: ada sesi, rutinitas, program, atau catatan
  /// berat badan — sesuatu yang hilangnya terasa. Akun yang baru dibuka dan
  /// belum lewat onboarding tidak perlu berkas kosong di Download — dan
  /// kalau berkas hari ini terlanjur kosong, program yang dipilih sesudahnya
  /// baru masuk cadangan besok.
  static bool worthBackingUp(Map<String, dynamic> doc) {
    bool filled(String key) {
      final v = doc[key];
      return v is List && v.isNotEmpty;
    }

    return filled('workouts') || filled('routines') || filled('bw') || doc['program'] != null;
  }

  // ── Keadaan perangkat ─────────────────────────────────────────────────

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static BackupSink? _override;
  static BackupSink get _sink =>
      _override ?? (supported ? const MethodChannelBackupSink() : const NoopBackupSink());

  /// Jembatan ke Android menjawab "unsupported" atau tidak ada sama sekali
  /// (Android < 10, MainActivity lama, host uji). Tidak dicoba lagi selama
  /// proses ini: menyandikan dokumen 200 KB di setiap perubahan hanya untuk
  /// ditolak lagi itu sia-sia.
  static bool _unavailable = false;

  /// Tanggal cadangan terakhir (`YYYY-MM-DD` lokal), null = belum pernah.
  /// ValueNotifier supaya baris di Profil ikut berubah saat cadangan otomatis
  /// jalan selagi layarnya terbuka.
  static final ValueNotifier<String?> lastBackupDate = ValueNotifier<String?>(null);

  static bool _enabled = true;
  static Future<void>? _loading;

  static Future<void> _load() => _loading ??= _loadPrefs();

  static Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabled) ?? true;
    lastBackupDate.value = prefs.getString(_kLastDate);
  }

  /// Nyala? Bawaan nyala di Android; di platform lain selalu mati.
  static Future<bool> get enabled async {
    if (!supported) return false;
    await _load();
    return _enabled;
  }

  static Future<void> setEnabled(bool value) async {
    await _load();
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }

  /// Pasang tiruan penulis dan kosongkan keadaan — hanya untuk uji. null
  /// mengembalikan penulis bawaan (MethodChannel di Android).
  @visibleForTesting
  static void debugUseSink(BackupSink? sink) {
    _override = sink;
    _unavailable = false;
    _loading = null;
    _enabled = true;
    lastBackupDate.value = null;
    _queue = Future.value();
  }

  /// Semua pekerjaan berurutan: dua persist beruntun di hari pertama tidak
  /// boleh menulis berkas yang sama dua kali sekaligus, dan "Simpan sekarang"
  /// tidak boleh berjalan di tengah cadangan otomatis.
  static Future<void> _queue = Future.value();

  static Future<T> _serial<T>(Future<T> Function() op) {
    final next = _queue.then((_) => op());
    _queue = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  /// Selesai saat semua yang mengantre rampung — untuk uji.
  @visibleForTesting
  static Future<void> get idle => _queue;

  /// Buat cadangan hari ini kalau belum ada. Dipanggil `WorkoutStore` setelah
  /// setiap dokumen tersimpan dan saat akun dibuka; tidak pernah ditunggu
  /// pemanggilnya dan tidak pernah melempar — mencatat set tidak boleh
  /// menunggu MediaStore, dan cadangan yang gagal bukan alasan sesi gagal
  /// tersimpan.
  ///
  /// [document] dipanggil malas, hanya kalau memang akan menulis: menyusun
  /// dokumen di setiap perubahan lalu membuangnya itu mahal. null = tidak
  /// ada akun yang terbuka.
  static Future<void> maybeBackup(Map<String, dynamic>? Function() document) {
    if (!supported || _unavailable) return Future.value();
    return _serial(() async {
      try {
        await _load();
        if (!_enabled || _unavailable) return;
        final now = clock.now();
        if (!shouldBackup(lastBackupDate.value, now)) return;
        final doc = document();
        if (doc == null || !worthBackingUp(doc)) return;
        await _write(doc, now);
      } catch (e) {
        debugPrint('cadangan otomatis: $e');
      }
    });
  }

  /// "Simpan sekarang" dari Profil: selalu menulis, walau hari ini sudah ada
  /// — orangnya baru mencatat sesuatu dan ingin berkasnya memuat itu.
  static Future<BackupOutcome> backupNow(Map<String, dynamic>? Function() document) {
    if (!supported || _unavailable) return Future.value(BackupOutcome.unsupported);
    return _serial(() async {
      try {
        await _load();
        final doc = document();
        return doc == null ? BackupOutcome.failed : await _write(doc, clock.now());
      } catch (e) {
        debugPrint('simpan cadangan: $e');
        return BackupOutcome.failed;
      }
    });
  }

  static Future<BackupOutcome> _write(Map<String, dynamic> doc, DateTime now) async {
    try {
      if (!await _sink.write(fileName(now), exportBytes(doc, now))) {
        _unavailable = true;
        return BackupOutcome.unsupported;
      }
    } on PlatformException catch (e) {
      // Android menolak (penyimpanan penuh, MediaStore rewel): kegagalan
      // sungguhan yang pantas disebut di Profil, dan dicoba lagi lain kali.
      debugPrint('cadangan ke Download gagal: ${e.code} ${e.message}');
      return BackupOutcome.failed;
    } catch (_) {
      // Tidak ada yang menjawab di sisi Android (MissingPluginException,
      // atau host uji tanpa binding): bukan sesuatu yang bisa diperbaiki
      // orangnya, jadi diam dan tidak dicoba lagi.
      _unavailable = true;
      return BackupOutcome.unsupported;
    }
    final date = isoDate(now.toLocal());
    lastBackupDate.value = date;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastDate, date);
    await _prune();
    return BackupOutcome.saved;
  }

  /// Buang berkas harian yang lebih lama dari [keep] terbaru. Gagal di sini
  /// tidak menggagalkan cadangannya: berkas hari ini sudah aman.
  static Future<void> _prune() async {
    try {
      for (final name in pruneList(await _sink.list(prefix))) {
        await _sink.delete(name);
      }
    } catch (e) {
      debugPrint('membersihkan cadangan lama: $e');
    }
  }
}
