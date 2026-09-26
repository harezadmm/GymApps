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
/// Di web, Safari menghentikan JavaScript saat layar terkunci, jadi timer di
/// halaman tidak bisa berbunyi. Gantinya **Web Push**: saat istirahat mulai,
/// server (`web-api/api/rest-alarm.js`) diminta mengirim push di tenggatnya.
/// Push itu dibunyikan sistem, walau layar terkunci. Hanya bekerja kalau
/// orangnya menyalakan "Notifikasi istirahat" di Profil — dan di iPhone hanya
/// dari aplikasi yang dipasang ke Home Screen (iOS 16.4+).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;

import 'web_push_stub.dart' if (dart.library.js_interop) 'web_push_web.dart' as wp;

/// Keadaan notifikasi istirahat di versi web, untuk baris di Profil.
enum WebRestPush {
  /// Build ini tidak punya kunci push, atau browsernya tidak mendukung.
  unavailable,

  /// iPhone yang membuka lewat tab Safari: push hanya ada untuk aplikasi yang
  /// dipasang ke Home Screen.
  needsHomeScreen,

  /// Izin ditolak; hanya bisa dibuka lagi dari pengaturan browser/iOS.
  blocked,
  off,
  on,
}

class RestAlert {
  RestAlert._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _asked = false;
  static const _id = 4201;

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // ── Web Push ────────────────────────────────────────────────────────────

  static const _vapidKey = String.fromEnvironment('VAPID_PUBLIC_KEY');

  /// Token sesi Supabase untuk memanggil server alarm. Diisi `main.dart`.
  static String? Function()? webAccessToken;

  static bool _webScheduled = false;

  static Future<WebRestPush> webState() async {
    if (!kIsWeb || _vapidKey.isEmpty || !wp.webPushSupported()) {
      // Safari di tab biasa tidak punya PushManager sama sekali.
      if (kIsWeb && _vapidKey.isNotEmpty && wp.runningOnIos() && !wp.runningStandalone()) {
        return WebRestPush.needsHomeScreen;
      }
      return WebRestPush.unavailable;
    }
    if (wp.runningOnIos() && !wp.runningStandalone()) return WebRestPush.needsHomeScreen;
    final permission = wp.notificationPermission();
    if (permission == 'denied') return WebRestPush.blocked;
    if (permission != 'granted') return WebRestPush.off;
    return await wp.currentWebPushSubscription() == null ? WebRestPush.off : WebRestPush.on;
  }

  /// Nyalakan dari ketukan. Mengembalikan keadaan sesudahnya.
  static Future<WebRestPush> enableWeb() async {
    wp.unlockWebAudio();
    try {
      await wp.subscribeWebPush(_vapidKey);
    } catch (e) {
      debugPrint('langganan push gagal: $e');
    }
    return webState();
  }

  static Future<WebRestPush> disableWeb() async {
    try {
      await wp.unsubscribeWebPush();
    } catch (e) {
      debugPrint('berhenti langganan: $e');
    }
    return webState();
  }

  static Future<bool> _postAlarm(Map<String, dynamic> body) async {
    final token = webAccessToken?.call();
    if (token == null) return false;
    try {
      final r = await http.post(
        Uri.base.resolve('api/rest-alarm'),
        headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (e) {
      debugPrint('alarm istirahat: $e');
      return false;
    }
  }

  static Future<void> _scheduleWeb(Duration after, String title, String body) async {
    // Istirahat biasanya mulai dari ketukan centang set: saat yang tepat untuk
    // menyiapkan bunyi di halaman.
    wp.unlockWebAudio();
    final sub = await wp.currentWebPushSubscription();
    if (sub == null) return;
    _webScheduled = await _postAlarm({
      'action': 'schedule',
      'delaySeconds': after.inSeconds.clamp(1, 1860),
      'subscription': sub,
      'title': title,
      'body': body,
    });
  }

  static Future<void> _cancelWeb() async {
    if (!_webScheduled) return;
    _webScheduled = false;
    await _postAlarm({'action': 'cancel'});
  }

  static Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_rest')),
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
    if (kIsWeb) return _scheduleWeb(after, title, body);
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
        icon: 'ic_stat_rest',
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
    if (kIsWeb) return _cancelWeb();
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
    if (kIsWeb) wp.webBeep();
    await cancel();
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    await SystemSound.play(SystemSoundType.alert);
  }
}
