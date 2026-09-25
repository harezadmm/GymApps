/// Tanda bahwa istirahat selesai.
///
/// Dulu timer istirahat habis dalam diam: kartunya hilang begitu saja. Di gym
/// HP biasanya tertelungkup di bangku atau di saku, layar terkunci, musik
/// berjalan — jadi tandanya dua lapis:
///
/// * **Notifikasi terjadwal** (Android) di tenggat istirahat. Berbunyi dan
///   bergetar walau aplikasi di latar belakang atau layar terkunci, karena
///   yang membunyikannya sistem, bukan aplikasi ini.
/// * **Getar dan bunyi langsung** kalau aplikasi sedang terbuka saat waktunya
///   habis. Notifikasinya dibatalkan supaya tidak berbunyi dua kali.
///
/// Di web tidak ada penjadwalan yang bisa diandalkan (Safari menghentikan
/// JavaScript saat layar terkunci), jadi yang ada hanya tanda langsung.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class RestAlert {
  RestAlert._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _asked = false;
  static const _id = 4201;

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      _ready = true;
    } catch (e) {
      debugPrint('notifikasi tidak tersedia: $e');
    }
  }

  /// Minta izin notifikasi sekali, saat pertama kali istirahat dimulai —
  /// bukan saat aplikasi dibuka, ketika orang belum tahu untuk apa izinnya.
  static Future<void> _ensurePermission() async {
    if (_asked) return;
    _asked = true;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('izin notifikasi: $e');
    }
  }

  /// Jadwalkan tanda istirahat selesai [after] dari sekarang. Jadwal yang
  /// lama diganti.
  static Future<void> schedule(Duration after, {required String title, required String body}) async {
    if (!_supported) return;
    await init();
    if (!_ready) return;
    await _ensurePermission();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'rest_timer',
        'Rest timer',
        channelDescription: 'Tanda saat istirahat antar set selesai',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      ),
    );
    final at = tz.TZDateTime.now(tz.UTC).add(after);
    try {
      await _plugin.zonedSchedule(
        id: _id,
        scheduledDate: at,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      // Izin alarm tepat waktu ditolak: tetap jadwalkan, sistem boleh telat
      // sedikit — lebih baik daripada tidak ada tanda sama sekali.
      debugPrint('alarm tepat ditolak, pakai jadwal longgar: $e');
      try {
        await _plugin.zonedSchedule(
          id: _id,
          scheduledDate: at,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
        );
      } catch (e) {
        debugPrint('notifikasi istirahat gagal dijadwalkan: $e');
      }
    }
  }

  static Future<void> cancel() async {
    if (!_supported || !_ready) return;
    try {
      await _plugin.cancel(id: _id);
    } catch (e) {
      debugPrint('batal notifikasi: $e');
    }
  }

  /// Istirahat habis selagi aplikasi terbuka: getar tiga kali dan satu bunyi,
  /// lalu batalkan notifikasi yang sedianya menyusul.
  static Future<void> ringNow() async {
    await cancel();
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    await SystemSound.play(SystemSoundType.alert);
  }
}
