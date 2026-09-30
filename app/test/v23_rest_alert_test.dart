/// Hitung mundur istirahat di notifikasi Android (FR-H3): baris senyap yang
/// menempel di layar terkunci selama istirahat, dengan sisa waktu yang
/// dihitung sistem, dan tanda selesai yang menimpanya karena id-nya sama.
///
/// Yang dijaga: detail notifikasinya persis (chronometer mundur ke tenggat,
/// senyap, menempel, kanal sendiri), hitung mundur dan tanda selesai berbagi
/// satu id, jadwal ulang tidak menumpuk baris kedua, batal menghapus
/// keduanya, dan antrean berurutan [RestAlert] membuat batal tidak pernah
/// mendahului jadwal yang belum selesai. Pluginnya diganti tiruan lewat
/// [RestAlert.debugUseNotifier], jadi tidak ada Android yang disentuh.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/rest_alert.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/strings_rest.dart';
import 'package:timezone/timezone.dart' as tz;

/// Tiruan plugin yang berlaku seperti tray Android: satu baris per id, baris
/// dengan id sama saling menimpa, dan `cancel` menghapus yang tampil sekaligus
/// yang terjadwal.
class _FakeNotifier implements RestNotifier {
  final shown = <int, RestNotification>{};
  final scheduled = <int, ({RestNotification n, tz.TZDateTime at, AndroidScheduleMode mode})>{};
  final log = <String>[];

  bool available = true;
  bool rejectExact = false;

  /// Menahan `show` sampai dibuka — untuk membuktikan batal menunggu giliran.
  Completer<void>? gate;

  @override
  Future<bool> init() async {
    log.add('init');
    return available;
  }

  @override
  Future<void> requestPermission() async => log.add('permission');

  @override
  Future<void> show(RestNotification n) async {
    await gate?.future;
    shown[n.id] = n;
    log.add('show ${n.id}');
  }

  @override
  Future<void> schedule(RestNotification n, {required tz.TZDateTime at, required AndroidScheduleMode mode}) async {
    if (rejectExact && mode == AndroidScheduleMode.exactAllowWhileIdle) {
      throw PlatformException(code: 'exact_alarms_not_permitted');
    }
    scheduled[n.id] = (n: n, at: at, mode: mode);
    log.add('schedule ${n.id} ${mode.name}');
  }

  @override
  Future<void> cancel(int id) async {
    shown.remove(id);
    scheduled.remove(id);
    log.add('cancel $id');
  }
}

final _now = DateTime(2026, 9, 15, 18);
const _en = Strings(AppLanguage.english);

/// Jadwalkan seperti layar sesi: jam dinding dibekukan di [now] supaya tenggat
/// yang dikirim ke plugin bisa dibandingkan persis.
Future<void> _schedule(
  DateTime now,
  Duration after, {
  String exercise = 'Bench Press',
  String next = 'Next: set 3 · 72.5 kg × 8',
}) =>
    withClock(
      Clock.fixed(now),
      () => RestAlert.schedule(
        after,
        title: _en.restOverTitle,
        body: _en.restOverBody(next),
        countdownTitle: _en.restCountdownTitle,
        countdownBody: _en.restCountdownBody(exercise, next),
      ),
    );

void main() {
  late _FakeNotifier fake;

  setUp(() {
    // Di host uji defaultTargetPlatform memang android, tapi ditegaskan:
    // RestAlert hanya bekerja di Android, dan test ini tentang Android.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    fake = _FakeNotifier();
    RestAlert.debugUseNotifier(fake);
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('countdownNotification', () {
    test('chronometer mundur ke tenggat, senyap, menempel, di kanal sendiri', () {
      final endsAt = DateTime(2026, 9, 15, 18, 1, 30);
      final n = countdownNotification(endsAt, title: 'Resting', body: 'Bench Press — Next: set 3');
      final a = n.details.android!;
      expect(a.channelId, 'rest_countdown');
      expect(a.importance, Importance.low);
      expect(a.priority, Priority.low);
      expect(a.playSound, isFalse);
      expect(a.enableVibration, isFalse);
      expect(a.silent, isTrue);
      expect(a.usesChronometer, isTrue);
      expect(a.chronometerCountDown, isTrue);
      expect(a.when, endsAt.millisecondsSinceEpoch, reason: 'sistem menghitung mundur ke tenggat, bukan dari sekarang');
      expect(a.showWhen, isTrue);
      expect(a.ongoing, isTrue);
      expect(a.onlyAlertOnce, isTrue);
      expect(a.autoCancel, isFalse);
      expect(a.visibility, NotificationVisibility.public, reason: 'gunanya justru terbaca di layar terkunci');
      expect(n.title, 'Resting');
      expect(n.body, 'Bench Press — Next: set 3');
    });

    test('berbagi id dengan tanda selesai, yang tidak menempel dan boleh digeser hilang', () {
      final countdown = countdownNotification(DateTime(2026), title: 'a', body: 'b');
      final alert = endAlertNotification(title: 'Rest over', body: 'Back to it.');
      expect(alert.id, countdown.id, reason: 'satu id: alarm menimpa hitung mundur, satu batal menghapus keduanya');
      final a = alert.details.android!;
      expect(a.channelId, 'rest_timer');
      expect(a.importance, Importance.high);
      expect(a.ongoing, isFalse);
      expect(a.autoCancel, isTrue);
      expect(a.usesChronometer, isFalse);
      expect(alert.title, 'Rest over');
      expect(alert.body, 'Back to it.');
    });
  });

  group('jadwal dan batal', () {
    test('satu jadwal: hitung mundur tampil dulu, lalu alarm di tenggat yang sama, satu id', () async {
      await _schedule(_now, const Duration(seconds: 90));
      expect(fake.shown, hasLength(1));
      expect(fake.scheduled, hasLength(1));
      final id = fake.shown.keys.single;
      expect(fake.scheduled.keys.single, id);

      final endsAt = _now.add(const Duration(seconds: 90));
      final countdown = fake.shown[id]!;
      expect(countdown.details.android!.when, endsAt.millisecondsSinceEpoch);
      expect(countdown.title, 'Resting');
      expect(countdown.body, 'Bench Press — Next: set 3 · 72.5 kg × 8');

      final alarm = fake.scheduled[id]!;
      expect(alarm.at.millisecondsSinceEpoch, endsAt.millisecondsSinceEpoch,
          reason: 'angka hitung mundur harus menyentuh 0:00 tepat saat alarm menyala');
      expect(alarm.mode, AndroidScheduleMode.exactAllowWhileIdle);
      expect(alarm.n.title, 'Rest over');
      expect(alarm.n.body, 'Next: set 3 · 72.5 kg × 8');

      expect(fake.log, ['init', 'permission', 'show $id', 'schedule $id exactAllowWhileIdle'],
          reason: 'hitung mundur dulu: alarm yang lebih dulu bisa tertimpa hitung mundur pada sisa sedetik');
    });

    test('jadwal ulang (+15 s, set berikutnya, istirahat baru) menimpa baris yang sama — tidak menumpuk', () async {
      await _schedule(_now, const Duration(seconds: 90));
      // +15 s pada detik ke-10: sisa 80 + 15.
      await _schedule(_now.add(const Duration(seconds: 10)), const Duration(seconds: 95));
      expect(fake.shown, hasLength(1));
      expect(fake.scheduled, hasLength(1));
      final moved = _now.add(const Duration(seconds: 105)).millisecondsSinceEpoch;
      expect(fake.shown.values.single.details.android!.when, moved);
      expect(fake.scheduled.values.single.at.millisecondsSinceEpoch, moved);

      // Istirahat baru untuk gerakan lain: masih satu baris, teksnya ikut.
      await _schedule(_now.add(const Duration(minutes: 2)), const Duration(seconds: 60),
          exercise: 'Squat', next: 'Next: set 1 · 100 kg × 5');
      expect(fake.shown, hasLength(1));
      expect(fake.scheduled, hasLength(1));
      expect(fake.shown.values.single.body, 'Squat — Next: set 1 · 100 kg × 5');
      expect(fake.scheduled.values.single.n.body, 'Next: set 1 · 100 kg × 5');

      expect(fake.log.where((l) => l.startsWith('show')), hasLength(3), reason: 'tiga kali tampil, satu id');
      expect(fake.log.where((l) => l.startsWith('cancel')), isEmpty, reason: 'menimpa, bukan hapus lalu buat lagi');
      expect(fake.log.where((l) => l == 'permission'), hasLength(1), reason: 'izin ditanya sekali saja');
    });

    test('batal menghapus hitung mundur dan alarm sekaligus', () async {
      await _schedule(_now, const Duration(seconds: 90));
      final id = fake.shown.keys.single;
      await RestAlert.cancel();
      expect(fake.shown, isEmpty);
      expect(fake.scheduled, isEmpty);
      expect(fake.log.last, 'cancel $id');
    });

    test('batal yang diketuk selagi jadwal masih berjalan menunggu gilirannya', () async {
      fake.gate = Completer<void>();
      final scheduling = _schedule(_now, const Duration(seconds: 90));
      final cancelling = RestAlert.cancel();
      // Semua microtask sudah jalan; plugin masih tertahan di `show`.
      await Future<void>.delayed(Duration.zero);
      expect(fake.log.any((l) => l.startsWith('cancel')), isFalse,
          reason: 'batal yang mendahului jadwal membiarkan alarm basi tetap datang');

      fake.gate!.complete();
      await scheduling;
      await cancelling;
      final id = fake.log.last.split(' ').last;
      expect(fake.log, ['init', 'permission', 'show $id', 'schedule $id exactAllowWhileIdle', 'cancel $id']);
      expect(fake.shown, isEmpty);
      expect(fake.scheduled, isEmpty);
    });

    test('alarm tepat ditolak: jatuh ke jadwal longgar, hitung mundurnya tetap tampil', () async {
      fake.rejectExact = true;
      await _schedule(_now, const Duration(seconds: 90));
      expect(fake.shown, hasLength(1));
      expect(fake.scheduled, hasLength(1));
      expect(fake.scheduled.values.single.mode, AndroidScheduleMode.inexactAllowWhileIdle);
      expect(fake.scheduled.keys.single, fake.shown.keys.single);
    });

    test('plugin tidak tersedia: tidak ada yang tampil dan tidak ada yang meledak', () async {
      fake.available = false;
      await _schedule(_now, const Duration(seconds: 90));
      await RestAlert.cancel();
      expect(fake.shown, isEmpty);
      expect(fake.scheduled, isEmpty);
      expect(fake.log, ['init'], reason: 'tanpa plugin, batal pun tidak perlu memanggil apa-apa');
    });

    test('di luar Android plugin tidak disentuh sama sekali', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await _schedule(_now, const Duration(seconds: 90));
      await RestAlert.cancel();
      expect(fake.log, isEmpty);
    });
  });

  group('teks', () {
    test('judul dua bahasa; isi menyebut gerakan dan set berikutnya, yang kosong dilewati', () {
      const id = Strings(AppLanguage.indonesian);
      expect(_en.restCountdownTitle, 'Resting');
      expect(id.restCountdownTitle, 'Sedang istirahat');
      expect(_en.restCountdownBody('Bench Press', 'Next: set 3 · 72.5 kg × 8'), 'Bench Press — Next: set 3 · 72.5 kg × 8');
      expect(id.restCountdownBody('Bench Press', id.lastSetDone), 'Bench Press — Set terakhir selesai');
      expect(_en.restCountdownBody('Bench Press', ''), 'Bench Press');
      expect(_en.restCountdownBody('', 'Next: Squat'), 'Next: Squat');
    });
  });
}
