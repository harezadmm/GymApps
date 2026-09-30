/// Tanda bahwa istirahat selesai (FR-H3).
///
/// Dulu timer istirahat habis dalam diam: kartunya hilang begitu saja. Di gym
/// HP biasanya tertelungkup di bangku atau di saku, layar terkunci, musik
/// berjalan — jadi tandanya tiga lapis:
///
/// * **Hitung mundur yang menempel** (Android) selama istirahat berjalan:
///   baris senyap di layar terkunci yang angkanya dihitung sistem
///   (chronometer), jadi sisa waktunya terlihat tanpa membuka HP dan tetap
///   berjalan walau aplikasi dimatikan.
/// * **Notifikasi terjadwal** (Android) di tenggat istirahat. Berbunyi dan
///   bergetar walau aplikasi di latar belakang atau layar terkunci, karena
///   yang membunyikannya sistem, bukan aplikasi ini. Id-nya sama dengan
///   hitung mundur, jadi ia menggantikan baris itu, bukan menumpuk di
///   bawahnya.
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

import 'package:clock/clock.dart';
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

/// Id bersama hitung mundur dan tanda selesai. Satu id berarti satu baris di
/// tray: alarm yang menyala menimpa hitung mundur, dan satu `cancel` menghapus
/// keduanya. Kalau id-nya beda, hitung mundur yang basi tetap nongkrong di
/// layar terkunci setelah istirahat selesai.
const _restId = 4201;

/// Satu notifikasi yang siap dikirim ke plugin: id, teks, dan detail
/// Android-nya. Dibangun fungsi murni ([countdownNotification] dan
/// [endAlertNotification]) supaya isinya bisa diperiksa di uji tanpa plugin.
@immutable
class RestNotification {
  const RestNotification({required this.id, required this.title, required this.body, required this.details});

  final int id;
  final String title;
  final String body;
  final NotificationDetails details;
}

/// Baris hitung mundur yang menempel selama istirahat.
///
/// Sistem yang menghitung dari [endsAt] lewat chronometer, jadi angkanya
/// tetap berjalan walau aplikasi dimatikan atau layar terkunci — aplikasi
/// tidak perlu bangun tiap detik untuk memperbaruinya. Senyap: yang berbunyi
/// tanda selesainya. [body] berisi gerakan dan set berikutnya supaya dari
/// layar terkunci orang tahu mau angkat apa.
RestNotification countdownNotification(DateTime endsAt, {required String title, required String body}) =>
    RestNotification(
      id: _restId,
      title: title,
      body: body,
      details: NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_countdown',
          'Rest countdown',
          channelDescription: 'Sisa waktu istirahat di layar terkunci, tanpa bunyi',
          // Kanal sendiri dengan penting rendah: tidak pernah melayang
          // (heads-up), tidak berbunyi, dan bisa dimatikan di setelan sistem
          // tanpa ikut mematikan tanda selesai di kanal `rest_timer`.
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          silent: true,
          channelShowBadge: false,
          category: AndroidNotificationCategory.stopwatch,
          icon: 'ic_stat_rest',
          visibility: NotificationVisibility.public,
          // Menempel dan tidak bisa digeser hilang: barisnya hanya pergi saat
          // istirahat selesai atau dibatalkan. Jadwal ulang (+15 s, set
          // berikutnya) menimpa baris yang sama tanpa berkedip atau bersuara.
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: true,
          when: endsAt.millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: true,
        ),
      ),
    );

/// Tanda istirahat selesai yang dijadwalkan di tenggat. Berbunyi dan bergetar
/// lewat kanal `rest_timer`, dan boleh digeser hilang.
RestNotification endAlertNotification({required String title, required String body}) => RestNotification(
      id: _restId,
      title: title,
      body: body,
      details: const NotificationDetails(
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
      ),
    );

/// Bagian plugin notifikasi yang dipakai [RestAlert]: cukup untuk
/// menampilkan, menjadwalkan, dan membatalkan satu notifikasi. Di uji diganti
/// tiruan yang mencatat panggilan, supaya urutan hitung mundur → alarm →
/// batal bisa diperiksa tanpa Android.
abstract interface class RestNotifier {
  /// Siapkan plugin. `false` berarti notifikasi tidak tersedia di sini.
  Future<bool> init();

  Future<void> requestPermission();

  /// Tampilkan sekarang. Id yang sama menimpa baris yang sedang tampil.
  Future<void> show(RestNotification n);

  /// Jadwalkan [n] di [at]. Id yang sama menggantikan jadwal yang lama.
  Future<void> schedule(RestNotification n, {required tz.TZDateTime at, required AndroidScheduleMode mode});

  /// Hapus yang tampil dan yang terjadwal dengan id ini, dua-duanya.
  Future<void> cancel(int id);
}

/// Plugin sungguhan: `flutter_local_notifications`.
class _PluginNotifier implements RestNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<bool> init() async {
    // Tanpa callback ketukan: mengetuk baris mana pun cukup membuka aplikasi.
    // Plugin hanya menyimpan "diluncurkan dari notifikasi" untuk ditanya lewat
    // getNotificationAppLaunchDetails, yang tidak dipanggil siapa pun — jadi
    // mulai dingin dari ketukan itu sama saja dengan mulai dari ikon peluncur,
    // tidak ada jalur yang bisa jatuh ke isolate yang belum siap.
    final ok = await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_rest')),
    );
    // null hanya kalau tidak ada implementasi platform, dan itu sudah
    // disaring `_supported`; yang dianggap gagal hanya `false` yang tegas.
    return ok ?? true;
  }

  @override
  Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  @override
  Future<void> show(RestNotification n) =>
      _plugin.show(id: n.id, title: n.title, body: n.body, notificationDetails: n.details);

  @override
  Future<void> schedule(RestNotification n, {required tz.TZDateTime at, required AndroidScheduleMode mode}) =>
      _plugin.zonedSchedule(
        id: n.id,
        scheduledDate: at,
        notificationDetails: n.details,
        androidScheduleMode: mode,
        title: n.title,
        body: n.body,
      );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

class RestAlert {
  RestAlert._();

  static RestNotifier _notifier = _PluginNotifier();
  static bool _ready = false;
  static bool _asked = false;

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Pasang tiruan plugin dan kosongkan keadaan — hanya untuk uji.
  @visibleForTesting
  static void debugUseNotifier(RestNotifier notifier) {
    _notifier = notifier;
    _ready = false;
    _asked = false;
    _queue = Future.value();
  }

  // ── Web Push ────────────────────────────────────────────────────────────

  static const _vapidKey = String.fromEnvironment('VAPID_PUBLIC_KEY');

  /// Token sesi Supabase untuk memanggil server alarm. Diisi `main.dart`;
  /// asinkron supaya token yang kedaluwarsa (halaman iOS yang baru bangun)
  /// sempat di-refresh, bukan ditolak 401 diam-diam.
  static Future<String?> Function()? webAccessToken;

  /// Jadwal dan batal dijalankan berurutan. Tanpa antrean ini, batal yang
  /// diketuk sebelum permintaan jadwal selesai (lewati istirahat, selesai
  /// sesi) tidak mengirim apa-apa, dan tanda "istirahat selesai" yang basi
  /// tetap datang. Di Android antrean ini juga yang menjamin hitung mundur
  /// dan alarmnya tidak pernah saling mendahului.
  static Future<void> _queue = Future.value();

  static Future<void> _serial(Future<void> Function() op) {
    final next = _queue.then((_) => op()).catchError((Object e) => debugPrint('alarm istirahat: $e'));
    _queue = next;
    return next;
  }

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
    final token = await webAccessToken?.call();
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
      _ready = await _notifier.init();
    } catch (e) {
      debugPrint('notifikasi tidak tersedia: $e');
    }
  }

  /// Minta izin notifikasi sekali, saat pertama kali istirahat dimulai —
  /// bukan saat aplikasi dibuka, ketika orang belum tahu untuk apa izinnya.
  static Future<void> _ensurePermission() async {
    if (_asked) return;
    _asked = true;
    try {
      await _notifier.requestPermission();
    } catch (e) {
      debugPrint('izin notifikasi: $e');
    }
  }

  /// Jadwalkan tanda istirahat selesai [after] dari sekarang dan, di Android,
  /// tampilkan hitung mundurnya. Jadwal yang lama diganti, bukan ditumpuk.
  ///
  /// [title] dan [body] untuk tanda selesai; [countdownTitle] dan
  /// [countdownBody] untuk baris hitung mundur yang menempel selagi menunggu.
  static Future<void> schedule(
    Duration after, {
    required String title,
    required String body,
    required String countdownTitle,
    required String countdownBody,
  }) =>
      _serial(() => _schedule(after, title, body, countdownTitle, countdownBody));

  static Future<void> _schedule(
    Duration after,
    String title,
    String body,
    String countdownTitle,
    String countdownBody,
  ) async {
    if (kIsWeb) return _scheduleWeb(after, title, body);
    if (!_supported) return;
    await init();
    if (!_ready) return;
    await _ensurePermission();
    // Satu tenggat untuk keduanya, dari jam yang sama, supaya angka hitung
    // mundur tepat menyentuh 0:00 saat alarmnya menyala.
    final endsAt = clock.now().add(after);
    // Hitung mundur dulu, baru alarmnya. Kalau dibalik dan sisanya cuma
    // sedetik, alarm bisa menyala sebelum hitung mundur tampil — dan hitung
    // mundur yang datang belakangan menimpa tanda selesainya.
    try {
      await _notifier.show(countdownNotification(endsAt, title: countdownTitle, body: countdownBody));
    } catch (e) {
      debugPrint('hitung mundur istirahat gagal tampil: $e');
    }
    final alert = endAlertNotification(title: title, body: body);
    final at = tz.TZDateTime.from(endsAt, tz.UTC);
    try {
      await _notifier.schedule(alert, at: at, mode: AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      // Izin alarm tepat waktu ditolak: tetap jadwalkan, sistem boleh telat
      // sedikit — lebih baik daripada tidak ada tanda sama sekali.
      debugPrint('alarm tepat ditolak, pakai jadwal longgar: $e');
      try {
        await _notifier.schedule(alert, at: at, mode: AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (e) {
        debugPrint('notifikasi istirahat gagal dijadwalkan: $e');
      }
    }
  }

  /// Batalkan tanda selesai yang terjadwal sekaligus hitung mundur yang
  /// sedang tampil: keduanya satu id, jadi satu panggilan ke plugin cukup.
  static Future<void> cancel() => _serial(_cancel);

  static Future<void> _cancel() async {
    if (kIsWeb) return _cancelWeb();
    if (!_supported || !_ready) return;
    try {
      await _notifier.cancel(_restId);
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
