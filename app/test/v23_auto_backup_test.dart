/// Cadangan harian otomatis ke folder Download (FR-A5, FR-A6).
///
/// Sasaran PRD "nol sesi hilang" hanya terpenuhi kalau salinannya ada tanpa
/// orangnya ingat mengekspor. Yang dijaga di sini: keputusannya (sekali per
/// hari kalender lokal, nama berkas, tujuh berkas terakhir) sebagai fungsi
/// murni; store menulis tepat satu kali per hari lewat penulis palsu, tidak
/// sama sekali saat setelannya mati, dan berkasnya persis dokumen ekspor
/// yang dibaca "Impor cadangan"; sisi Dart MethodChannel mengirim nama dan
/// byte yang benar, memangkas lewat list/delete, dan memperlakukan
/// "unsupported" sebagai bukan apa-apa; dan baris di Profil menunjukkan
/// tanggal terakhir, memanggil penulis dari "Back up now", dan menjawab gagal
/// dengan satu snackbar — bukan dialog.
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/auto_backup.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/strings_backup.dart';
import 'package:gymapps/core/theme.dart';
import 'package:gymapps/core/widgets.dart';
import 'package:gymapps/data/exercise_catalog.dart';
import 'package:gymapps/data/workout_store.dart';
import 'package:gymapps/domain/models.dart';
import 'package:gymapps/domain/program.dart';
import 'package:gymapps/features/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiruan folder Download: menyimpan isi berkas dan mencatat setiap
/// panggilan, supaya "tepat satu kali" bisa dihitung.
class _FakeSink implements BackupSink {
  final files = <String, Uint8List>{};
  final log = <String>[];

  /// false = jawaban "unsupported" dari Android < 10.
  bool supported = true;

  /// Dilempar saat menulis, kalau diisi.
  Object? failWith;

  Iterable<String> get writes => log.where((l) => l.startsWith('write'));

  @override
  Future<bool> write(String name, Uint8List bytes) async {
    log.add('write $name');
    if (failWith != null) throw failWith!;
    if (!supported) return false;
    files[name] = bytes;
    return true;
  }

  @override
  Future<List<String>> list(String prefix) async {
    log.add('list $prefix');
    return [for (final n in files.keys) if (n.startsWith(prefix)) n];
  }

  @override
  Future<void> delete(String name) async {
    log.add('delete $name');
    files.remove(name);
  }
}

Workout _sesi(String date) => Workout(
      date: date,
      entries: [
        WorkoutEntry(exerciseId: '0025', sets: [for (var i = 0; i < 3; i++) SetRow(weight: 60, reps: 8, done: true)]),
      ],
    );

String _name(String date) => 'gymapps-backup-$date.json';

Map<String, dynamic> _decode(Uint8List bytes) => Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);

/// HP kecil yang umum: 360 × 780 dp.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Pump berjangka, bukan pumpAndSettle: animasi kedatangan tidak pernah
/// "tenang".
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Gulir daftar Profil sampai [f] terlihat, lalu pastikan seluruhnya masuk
/// layar: scrollUntilVisible berhenti begitu ujung barisnya muncul, dan
/// ketukan di baris yang baru setengah tampak jatuh di luar layar. Grup
/// yang baru dibangun saat masuk layar sedang digeser turun sebentar oleh
/// Reveal, jadi animasinya ditunggu dulu — ensureVisible di tengah geseran
/// itu meninggalkan barisnya beberapa piksel di atas layar setelah tenang.
Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await _settle(tester);
  await tester.ensureVisible(f);
  await _settle(tester);
}

/// Habiskan waktu SnackBar beserta animasi keluarnya, supaya test tidak
/// berakhir dengan timer yang masih menggantung.
Future<void> _expireSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Widget _profile(WorkoutStore store, AppLanguage lang) => WorkoutScope(
      store: store,
      child: AppStrings(
        strings: Strings(lang),
        child: MaterialApp(
          theme: buildGymTheme(),
          home: Scaffold(
            body: ProfileScreen(language: lang, onLanguageChanged: (_) {}, onSignOut: () {}, email: 'a@x.com'),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSink sink;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExerciseCatalog.registerCustom(const []);
    sink = _FakeSink();
    AutoBackup.debugUseSink(sink);
  });

  tearDown(() => AutoBackup.debugUseSink(null));

  group('keputusan (murni)', () {
    test('shouldBackup: belum pernah, atau hari kalender lokalnya berbeda', () {
      expect(AutoBackup.shouldBackup(null, DateTime(2026, 9, 30, 9)), isTrue);
      expect(AutoBackup.shouldBackup('2026-09-30', DateTime(2026, 9, 30, 9)), isFalse);
      expect(AutoBackup.shouldBackup('2026-09-30', DateTime(2026, 9, 30, 23, 59, 59)), isFalse);
      // Dua menit kemudian sudah hari lain.
      expect(AutoBackup.shouldBackup('2026-09-30', DateTime(2026, 10, 1, 0, 0, 1)), isTrue);
      // Berbeda ke arah mana pun: jam HP yang dimundurkan menghasilkan satu
      // berkas ekstra, bukan satu hari tanpa cadangan.
      expect(AutoBackup.shouldBackup('2026-10-02', DateTime(2026, 10, 1, 12)), isTrue);
      expect(AutoBackup.shouldBackup('2026-09-29', DateTime(2026, 9, 30, 0)), isTrue);
    });

    test('shouldBackup: yang dihitung hari lokal, bukan hari UTC', () {
      // Jam dinding 23:30 lokal, diberikan sebagai UTC: tetap hari yang sama
      // — di Jakarta (UTC+7) tanggal UTC-nya sudah berbeda, dan itu bukan
      // alasan membuat cadangan kedua.
      final local = DateTime(2026, 9, 30, 23, 30);
      expect(AutoBackup.shouldBackup('2026-09-30', local.toUtc()), isFalse);
      expect(AutoBackup.shouldBackup('2026-09-30', local.toUtc().add(const Duration(minutes: 31))), isTrue);
      // Instan UTC mana pun dinilai dari tanggal lokalnya.
      final utc = DateTime.utc(2026, 9, 30, 20);
      expect(AutoBackup.shouldBackup(isoDate(utc.toLocal()), utc), isFalse);
      expect(AutoBackup.shouldBackup(isoDate(utc.toLocal()), utc.add(const Duration(days: 1))), isTrue);
    });

    test('fileName: awalan, tanggal lokal dua digit, .json — sama dengan ekspor manual', () {
      expect(AutoBackup.fileName(DateTime(2026, 9, 5, 7, 30)), 'gymapps-backup-2026-09-05.json');
      expect(AutoBackup.fileName(DateTime(2026, 12, 31, 23, 59)), 'gymapps-backup-2026-12-31.json');
      expect(AutoBackup.fileName(DateTime(2026, 9, 5, 23, 30).toUtc()), 'gymapps-backup-2026-09-05.json');
      expect(AutoBackup.fileName(DateTime(2026, 9, 5)), '${AutoBackup.prefix}2026-09-05.json');
    });

    test('pruneList: menyisakan 7 terbaru menurut nama, hanya berkas kita, tanpa duplikat', () {
      final ours = [for (var d = 21; d <= 30; d++) _name('2026-09-$d')]..shuffle();
      final names = [
        ...ours,
        _name('2026-09-30'), // duplikat: dua baris MediaStore untuk satu nama
        // Setelah pasang ulang MediaStore menamai berkas kita begini karena
        // nama aslinya dipakai berkas pemasangan lama (yang tidak terlihat
        // oleh kita): tetap berkas kita, ikut dihitung dan bisa dipangkas.
        'gymapps-backup-2026-09-30 (1).json',
        'gymapps-history-2026-09-30.csv',
        'notes.txt',
      ];
      expect(
        AutoBackup.pruneList(names),
        [_name('2026-09-24'), _name('2026-09-23'), _name('2026-09-22'), _name('2026-09-21')],
        reason: 'terlama dulu, dan yang dihapus hanya milik kita',
      );
      expect(
        AutoBackup.pruneList(['gymapps-backup-2026-09-30 (1).json', _name('2026-09-29')], keep: 1),
        [_name('2026-09-29')],
        reason: 'varian " (1)" hari yang sama lebih baru daripada hari sebelumnya',
      );
      expect(AutoBackup.pruneList([for (var d = 24; d <= 30; d++) _name('2026-09-$d')]), isEmpty);
      expect(AutoBackup.pruneList(const ['notes.txt']), isEmpty);
      expect(AutoBackup.pruneList(const []), isEmpty);
      expect(AutoBackup.pruneList([_name('2026-09-29'), _name('2026-09-30')], keep: 1), [_name('2026-09-29')]);
      expect(AutoBackup.pruneList([_name('2026-09-30')], keep: 0), [_name('2026-09-30')]);
    });

    test('pruneList: urutan dari nama, jadi tahun baru tidak mengalahkan tahun lama', () {
      expect(
        AutoBackup.pruneList([_name('2025-12-31'), _name('2026-01-01')], keep: 1),
        [_name('2025-12-31')],
      );
    });

    test('worthBackingUp: ada sesi, rutinitas, program, atau berat badan; akun kosong tidak', () {
      expect(AutoBackup.worthBackingUp({'schema': 1, 'workouts': []}), isFalse);
      expect(AutoBackup.worthBackingUp({'schema': 1}), isFalse);
      expect(AutoBackup.worthBackingUp({'schema': 1, 'workouts': [], 'settings': {'unit': 'lb'}}), isFalse,
          reason: 'setelan saja tidak perlu berkas di Download');
      expect(AutoBackup.worthBackingUp({'schema': 1, 'workouts': [_sesi('2026-09-30').toJson()]}), isTrue);
      expect(AutoBackup.worthBackingUp({'schema': 1, 'workouts': [], 'program': {'name': 'PPL'}}), isTrue);
      expect(AutoBackup.worthBackingUp({'schema': 1, 'workouts': [], 'routines': [{'id': 'r1'}]}), isTrue);
      expect(AutoBackup.worthBackingUp({'schema': 1, 'workouts': [], 'bw': [{'date': '2026-09-30', 'kg': 80}]}), isTrue);
    });

    test('exportDocument/exportBytes: isi dokumen plus exportedAt, terbaca kembali', () {
      final doc = {'schema': 1, 'workouts': [_sesi('2026-09-30').toJson()]};
      final now = DateTime(2026, 9, 30, 8, 15);
      expect(exportDocument(doc, now), {...doc, 'exportedAt': '2026-09-30T08:15:00.000'});
      expect(_decode(exportBytes(doc, now)), exportDocument(doc, now));
      expect(doc.containsKey('exportedAt'), isFalse, reason: 'dokumen asal tidak disentuh');
    });

    test('label tanggal di Profil: "28 Sep", tahun ikut hanya kalau bukan tahun ini', () {
      const en = Strings(AppLanguage.english);
      const id = Strings(AppLanguage.indonesian);
      expect(en.backupDateLabel('2026-05-03', DateTime(2026, 9, 30)), '3 May');
      expect(id.backupDateLabel('2026-05-03', DateTime(2026, 9, 30)), '3 Mei');
      expect(en.backupDateLabel('2026-05-03', DateTime(2027, 1, 2)), '3 May 2026');
      expect(en.backupDateLabel('rusak', DateTime(2026, 9, 30)), 'rusak');
    });
  });

  group('WorkoutStore', () {
    test('perubahan tersimpan pertama hari itu menulis satu berkas; berikutnya di hari yang sama tidak', () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 30, 9)), () async {
        final store = WorkoutStore();
        await store.load('a@x.com');
        await AutoBackup.idle;
        expect(sink.writes, isEmpty, reason: 'akun kosong: tidak ada yang layak dicadangkan');

        await store.addWorkout(_sesi('2026-09-30'));
        await AutoBackup.idle;
        expect(sink.writes.toList(), ['write ${_name('2026-09-30')}']);
        expect(AutoBackup.lastBackupDate.value, '2026-09-30');

        await store.addWorkout(_sesi('2026-09-29'));
        await store.updateSettings(store.settings.copyWith(logRir: true));
        await AutoBackup.idle;
        expect(sink.writes.length, 1, reason: 'sekali sehari');
        expect((_decode(sink.files[_name('2026-09-30')]!)['workouts'] as List).length, 1,
            reason: 'berkasnya potret saat perubahan pertama');
      });
    });

    test('berkasnya persis dokumen ekspor Profil: Impor cadangan membacanya', () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 30, 9)), () async {
        final store = WorkoutStore();
        await store.load('a@x.com');
        await store.addWorkout(_sesi('2026-09-30'));
        await store.addWorkout(_sesi('2026-09-28'));
        // Cadangan harian adalah potret perubahan pertama (satu sesi);
        // "Simpan sekarang" menulis dokumen utuh saat ini — itu yang
        // dibandingkan dengan ekspor.
        expect(await AutoBackup.backupNow(store.backupDocument), BackupOutcome.saved);
        final doc = _decode(sink.files[_name('2026-09-30')]!);
        expect(doc, exportDocument(store.toDocument(), DateTime(2026, 9, 30, 9)));
        expect(doc['exportedAt'], '2026-09-30T09:00:00.000');

        final fresh = WorkoutStore();
        await fresh.load('b@x.com');
        expect(await fresh.importDocument(doc), 2);
        expect(fresh.workouts.map((w) => w.date), ['2026-09-30', '2026-09-28']);
      });
    });

    test('akun dibuka (aplikasi dibuka) tanpa cadangan hari ini menulis; tanggalnya tersimpan di perangkat', () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 30, 9)), () async {
        final store = WorkoutStore();
        await store.load('a@x.com');
        await store.addWorkout(_sesi('2026-09-30'));
        await AutoBackup.idle;
      });
      expect(sink.files.keys, [_name('2026-09-30')]);

      // Dibuka lagi besok pagi, tanpa mencatat apa pun: riwayat kemarin
      // langsung punya salinan hari ini.
      await withClock(Clock.fixed(DateTime(2026, 10, 1, 7)), () async {
        final store = WorkoutStore();
        await store.load('a@x.com');
        await AutoBackup.idle;
      });
      expect(sink.files.keys, [_name('2026-09-30'), _name('2026-10-01')]);

      // Proses baru di hari yang sama (keadaan memori kosong, prefs tetap):
      // tanggal terakhir dibaca dari perangkat, tidak menulis lagi.
      AutoBackup.debugUseSink(sink);
      await withClock(Clock.fixed(DateTime(2026, 10, 1, 20)), () async {
        final store = WorkoutStore();
        await store.load('a@x.com');
        await store.addWorkout(_sesi('2026-10-01'));
        await AutoBackup.idle;
      });
      expect(sink.writes.length, 2);
      expect(AutoBackup.lastBackupDate.value, '2026-10-01');
    });

    test('setelan mati: tidak ada tulisan; dinyalakan lagi dan dipicu, langsung menulis', () async {
      await AutoBackup.setEnabled(false);
      expect(await AutoBackup.enabled, isFalse);
      await withClock(Clock.fixed(DateTime(2026, 9, 30, 9)), () async {
        final store = WorkoutStore();
        await store.load('a@x.com');
        await store.addWorkout(_sesi('2026-09-30'));
        await AutoBackup.idle;
        expect(sink.log, isEmpty);

        await AutoBackup.setEnabled(true);
        await AutoBackup.maybeBackup(store.backupDocument);
        expect(sink.files.keys, [_name('2026-09-30')]);
      });
    });

    test('setelan itu milik perangkat: tidak ikut dokumen yang disinkronkan', () async {
      await AutoBackup.setEnabled(false);
      final store = WorkoutStore();
      await store.load('a@x.com');
      expect(jsonEncode(store.toDocument()), isNot(contains('autoBackup')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings.autoBackup'), isFalse);
    });

    test('berkas lama dipangkas sampai 7, berkas lain di folder tidak disentuh', () async {
      for (var d = 22; d <= 29; d++) {
        sink.files[_name('2026-09-$d')] = Uint8List(0);
      }
      sink.files['gymapps-history-2026-09-30.csv'] = Uint8List(0);
      await withClock(Clock.fixed(DateTime(2026, 9, 30, 9)), () async {
        final store = WorkoutStore();
        await store.load('a@x.com');
        await store.addWorkout(_sesi('2026-09-30'));
        await AutoBackup.idle;
      });
      expect(sink.files.keys.where((n) => n.startsWith(AutoBackup.prefix)).toList()..sort(),
          [for (var d = 24; d <= 30; d++) _name('2026-09-$d')]);
      expect(sink.files.containsKey('gymapps-history-2026-09-30.csv'), isTrue);
      expect(sink.log.where((l) => l.startsWith('delete')).toList(),
          ['delete ${_name('2026-09-23')}', 'delete ${_name('2026-09-22')}']);
    });

    test('gagal menulis (Android menolak): tanggal tidak dicatat, dicoba lagi pada perubahan berikutnya', () async {
      sink.failWith = PlatformException(code: 'io', message: 'penyimpanan penuh');
      await withClock(Clock.fixed(DateTime(2026, 9, 30, 9)), () async {
        final store = WorkoutStore();
        await store.load('a@x.com');
        await store.addWorkout(_sesi('2026-09-30'));
        await AutoBackup.idle;
        expect(sink.files, isEmpty);
        expect(AutoBackup.lastBackupDate.value, isNull);

        sink.failWith = null;
        await store.addWorkout(_sesi('2026-09-29'));
        await AutoBackup.idle;
        expect(sink.files.keys, [_name('2026-09-30')]);
        expect(AutoBackup.lastBackupDate.value, '2026-09-30');
      });
    });

    test('tanpa jembatan ke Android (MissingPluginException): diam, dan tidak dicoba lagi', () async {
      sink.failWith = MissingPluginException('tidak ada');
      await withClock(Clock.fixed(DateTime(2026, 9, 30, 9)), () async {
        final store = WorkoutStore();
        await store.load('a@x.com');
        await store.addWorkout(_sesi('2026-09-30'));
        await store.addWorkout(_sesi('2026-09-29'));
        await AutoBackup.idle;
        expect(sink.writes.length, 1);
        expect(await AutoBackup.backupNow(store.backupDocument), BackupOutcome.unsupported);
        expect(sink.writes.length, 1, reason: '"Simpan sekarang" pun tidak mengetuk lagi');
      });
    });

    test('jawaban "unsupported" (Android < 10): bukan apa-apa — tanpa tanggal, tanpa pangkas', () async {
      sink.supported = false;
      await withClock(Clock.fixed(DateTime(2026, 9, 30, 9)), () async {
        final store = WorkoutStore();
        await store.load('a@x.com');
        await store.addWorkout(_sesi('2026-09-30'));
        await AutoBackup.idle;
        expect(sink.log, ['write ${_name('2026-09-30')}']);
        expect(AutoBackup.lastBackupDate.value, isNull);
        expect(await AutoBackup.backupNow(store.backupDocument), BackupOutcome.unsupported);
      });
    });

    test('"Simpan sekarang" selalu menulis, walau hari ini sudah ada', () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 30, 9)), () async {
        final store = WorkoutStore();
        await store.load('a@x.com');
        await store.addWorkout(_sesi('2026-09-30'));
        await AutoBackup.idle;
        await store.addWorkout(_sesi('2026-09-29'));
        expect(await AutoBackup.backupNow(store.backupDocument), BackupOutcome.saved);
        expect(sink.writes.length, 2);
        expect((_decode(sink.files[_name('2026-09-30')]!)['workouts'] as List).length, 2,
            reason: 'berkas hari yang sama ditimpa dengan isi terbaru');
      });
    });

    test('bukan Android: tidak ada cadangan, setelannya mati', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(AutoBackup.supported, isFalse);
      expect(await AutoBackup.enabled, isFalse);
      final store = WorkoutStore();
      await store.load('a@x.com');
      await store.addWorkout(_sesi('2026-09-30'));
      await AutoBackup.idle;
      expect(sink.log, isEmpty);
      expect(await AutoBackup.backupNow(store.backupDocument), BackupOutcome.unsupported);
    });
  });

  group('MethodChannel ke Android', () {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;
    Object? Function(MethodCall call)? reply;

    setUp(() {
      calls = [];
      reply = null;
      // Penulis bawaan: di host uji defaultTargetPlatform adalah android,
      // jadi ini MethodChannelBackupSink yang sungguhan.
      AutoBackup.debugUseSink(null);
      messenger.setMockMethodCallHandler(MethodChannelBackupSink.channel, (call) async {
        calls.add(call);
        return reply?.call(call);
      });
    });

    tearDown(() => messenger.setMockMethodCallHandler(MethodChannelBackupSink.channel, null));

    test('writeDownload membawa nama dan byte JSON; lalu listDownloads dan deleteDownload untuk yang lebih lama dari 7',
        () async {
      reply = (call) => switch (call.method) {
            'writeDownload' => 'ok',
            'listDownloads' => [for (var d = 22; d <= 30; d++) _name('2026-09-$d'), 'notes.txt'],
            _ => 'ok',
          };
      final doc = {'schema': 1, 'workouts': [_sesi('2026-09-30').toJson()]};
      final outcome =
          await withClock(Clock.fixed(DateTime(2026, 9, 30, 12)), () => AutoBackup.backupNow(() => doc));
      expect(outcome, BackupOutcome.saved);

      expect(calls.map((c) => c.method).toList(), ['writeDownload', 'listDownloads', 'deleteDownload', 'deleteDownload']);
      final write = calls.first.arguments as Map;
      expect(write['name'], _name('2026-09-30'));
      expect(write['bytes'], isA<Uint8List>(), reason: 'byte mentah lewat codec standar, bukan teks');
      expect(_decode(write['bytes'] as Uint8List), exportDocument(doc, DateTime(2026, 9, 30, 12)));
      expect((calls[1].arguments as Map)['prefix'], AutoBackup.prefix);
      expect(calls.skip(2).map((c) => (c.arguments as Map)['name']), [_name('2026-09-23'), _name('2026-09-22')]);
      expect(AutoBackup.lastBackupDate.value, '2026-09-30');
    });

    test('jawaban "unsupported": tidak apa-apa — tanpa tanggal, tanpa pangkas, dan tidak diganggu lagi', () async {
      reply = (_) => 'unsupported';
      expect(await AutoBackup.backupNow(() => {'schema': 1, 'workouts': []}), BackupOutcome.unsupported);
      expect(calls.map((c) => c.method), ['writeDownload']);
      expect(AutoBackup.lastBackupDate.value, isNull);

      await AutoBackup.maybeBackup(() => {'schema': 1, 'workouts': [_sesi('2026-09-30').toJson()]});
      expect(calls, hasLength(1), reason: 'Android < 10 tidak ditanya lagi selama proses ini');
    });

    test('galat dari Android adalah kegagalan, bukan diam: dilaporkan, tanggal tidak dicatat, dicoba lagi', () async {
      reply = (_) => throw PlatformException(code: 'io', message: 'penyimpanan penuh');
      expect(await AutoBackup.backupNow(() => {'schema': 1, 'workouts': []}), BackupOutcome.failed);
      expect(AutoBackup.lastBackupDate.value, isNull);

      reply = (_) => 'ok';
      expect(await AutoBackup.backupNow(() => {'schema': 1, 'workouts': []}), BackupOutcome.saved);
      expect(calls.where((c) => c.method == 'writeDownload'), hasLength(2));
    });

    test('tanpa jembatan sama sekali (MissingPluginException): unsupported yang diam', () async {
      messenger.setMockMethodCallHandler(MethodChannelBackupSink.channel, null);
      expect(await AutoBackup.backupNow(() => {'schema': 1, 'workouts': []}), BackupOutcome.unsupported);
      expect(AutoBackup.lastBackupDate.value, isNull);
    });

    test('listDownloads yang menjawab bukan daftar dibaca sebagai kosong', () async {
      const channelSink = MethodChannelBackupSink();
      reply = (_) => 'unsupported';
      expect(await channelSink.list(AutoBackup.prefix), isEmpty);
      reply = (_) => ['a.json', 7, null];
      expect(await channelSink.list(AutoBackup.prefix), ['a.json']);
    });
  });

  group('layar Profil', () {
    for (final (lang, tag) in [(AppLanguage.english, 'en'), (AppLanguage.indonesian, 'id')]) {
      testWidgets('[$tag] baris menunjukkan tanggal terakhir; "Back up now" memanggil penulis dan satu snackbar',
          (tester) async {
        _phone(tester);
        SharedPreferences.setMockInitialValues({'backup.lastDate': '2026-05-03'});
        AutoBackup.debugUseSink(sink);
        final t = Strings(lang);
        final store = WorkoutStore();
        // Sesi dicatat pada hari cadangan terakhir itu sendiri: tanggal dari
        // prefs dihormati, tidak ada tulisan — barisnya harus menunjukkan
        // 3 Mei, bukan hari ini.
        await withClock(Clock.fixed(DateTime(2026, 5, 3, 9)), () async {
          await store.load('a@x.com');
          await store.addWorkout(_sesi('2026-05-03'));
          await AutoBackup.idle;
        });
        expect(sink.writes, isEmpty, reason: 'tanggal terakhir dari prefs dihormati');

        await tester.pumpWidget(_profile(store, lang));
        await _settle(tester);
        // Judul grup (SectionLabel menulisnya dalam huruf kapital) adalah anak
        // ListView tersendiri yang dibuang begitu lewat di atas layar, jadi
        // digulir sampai terlihat — bukan diandalkan ikut terbangun bersama
        // grupnya.
        await _scrollTo(tester, find.text(t.autoBackupTitle.toUpperCase()));
        expect(find.text(t.autoBackupTitle.toUpperCase()), findsOneWidget);
        final row = find.text(t.backUpNow);
        await _scrollTo(tester, row);
        expect(find.text(t.dailyBackup), findsOneWidget);
        expect(find.text(t.autoBackupNote), findsOneWidget);
        expect(find.text(t.lastBackup(t.backupDateLabel('2026-05-03', DateTime.now()))), findsOneWidget);

        await tester.tap(row);
        await _settle(tester);
        final now = DateTime.now();
        expect(sink.writes.toList(), ['write ${AutoBackup.fileName(now)}']);
        expect(find.text(t.backupSavedTo(AutoBackup.fileName(now))), findsOneWidget);
        expect(find.text(t.lastBackup(t.backupDateLabel(isoDate(now), now))), findsOneWidget,
            reason: 'baris ikut berubah tanpa membuka ulang layar');
        expect(find.byType(AlertDialog), findsNothing);
        await _expireSnackBar(tester);
      });
    }

    testWidgets('belum pernah: "Never"; saklar mengikuti setelan perangkat dan menyalakannya langsung mencadangkan',
        (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({'settings.autoBackup': false});
      AutoBackup.debugUseSink(sink);
      final store = WorkoutStore();
      await store.load('a@x.com');
      await store.addWorkout(_sesi('2026-09-30'));
      await AutoBackup.idle;
      expect(sink.log, isEmpty);

      await tester.pumpWidget(_profile(store, AppLanguage.english));
      await _settle(tester);
      await _scrollTo(tester, find.text('Daily backup'));
      expect(find.text('Never'), findsOneWidget);
      final toggle = find.descendant(of: find.widgetWithText(SettingsTile, 'Daily backup'), matching: find.byType(Switch));
      expect(tester.widget<Switch>(toggle).value, isFalse);

      await tester.tap(toggle);
      await _settle(tester);
      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(await AutoBackup.enabled, isTrue);
      expect(sink.writes.toList(), ['write ${AutoBackup.fileName(DateTime.now())}']);
      expect(find.text('Never'), findsNothing);
    });

    testWidgets('gagal: satu snackbar, tanpa dialog; Android < 10 disebut apa adanya', (tester) async {
      _phone(tester);
      AutoBackup.debugUseSink(sink);
      final store = WorkoutStore();
      await store.load('a@x.com');
      await tester.pumpWidget(_profile(store, AppLanguage.english));
      await _settle(tester);
      final row = find.text('Back up now');
      await _scrollTo(tester, row);

      sink.failWith = PlatformException(code: 'io', message: 'penyimpanan penuh');
      await tester.tap(row);
      await _settle(tester);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text("Couldn't write to Download/GymApps. Export backup still works."), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Never'), findsOneWidget);
      await _expireSnackBar(tester);

      sink.failWith = null;
      sink.supported = false;
      await tester.tap(row);
      await _settle(tester);
      expect(find.text('Automatic backup needs Android 10 or newer.'), findsOneWidget);
      await _expireSnackBar(tester);
    });

    testWidgets('bukan Android: grupnya tidak ada sama sekali', (tester) async {
      _phone(tester);
      // Dikembalikan di akhir badan test, bukan lewat addTearDown: binding
      // widget test memeriksa variabel debug foundation sebelum tearDown.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final store = WorkoutStore();
        await store.load('a@x.com');
        await tester.pumpWidget(_profile(store, AppLanguage.english));
        await _settle(tester);
        for (var i = 0; i < 3; i++) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200), warnIfMissed: false);
          await _settle(tester);
        }
        expect(find.text('AUTOMATIC BACKUP'), findsNothing);
        expect(find.text('Daily backup'), findsNothing);
        expect(find.text('Back up now'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
