/// Web Push untuk tanda istirahat selesai di versi web (lihat rest_alert.dart).
///
/// Di iPhone, push hanya ada untuk aplikasi web yang dipasang ke Home Screen
/// (iOS 16.4+), dan izinnya hanya bisa diminta langsung dari ketukan. Karena
/// itu [subscribeWebPush] memanggil `Notification.requestPermission()` sebagai
/// hal pertama, sebelum menunggu apa pun.
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

bool webPushSupported() =>
    globalContext.has('PushManager') && globalContext.has('Notification') && web.window.navigator.has('serviceWorker');

/// Dibuka dari ikon Home Screen, bukan dari tab Safari.
bool runningStandalone() {
  if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
  final legacy = web.window.navigator.getProperty<JSAny?>('standalone'.toJS);
  return legacy != null && legacy.isA<JSBoolean>() && (legacy as JSBoolean).toDart;
}

bool runningOnIos() {
  final ua = web.window.navigator.userAgent;
  return RegExp('iPhone|iPad|iPod').hasMatch(ua) ||
      // iPadOS menyamar sebagai Mac; bedanya layar sentuh.
      (ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1);
}

/// `default`, `granted`, `denied`, atau `unsupported`.
String notificationPermission() => globalContext.has('Notification') ? web.Notification.permission : 'unsupported';

Uint8List _base64UrlBytes(String s) {
  final pad = '=' * ((4 - s.length % 4) % 4);
  return base64Url.decode(s + pad);
}

Future<web.ServiceWorkerRegistration> _registration() async {
  final container = web.window.navigator.serviceWorker;
  await container.register('sw.js'.toJS).toDart;
  return container.ready.toDart;
}

Map<String, dynamic>? _subscriptionJson(web.PushSubscription? sub) {
  if (sub == null) return null;
  final raw = sub.toJSON().dartify();
  if (raw is! Map) return null;
  return jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
}

/// Minta izin, daftarkan sw.js, lalu berlangganan. null kalau izin ditolak
/// atau browser menolak berlangganan.
Future<Map<String, dynamic>?> subscribeWebPush(String vapidPublicKey) async {
  // Harus panggilan pertama: izin di Safari hanya boleh diminta selama
  // ketukan orangnya masih "hangat".
  final asking = web.Notification.requestPermission().toDart;
  final permission = (await asking).toDart;
  if (permission != 'granted') return null;
  final reg = await _registration();
  final existing = await reg.pushManager.getSubscription().toDart;
  if (existing != null) return _subscriptionJson(existing);
  final sub = await reg.pushManager
      .subscribe(web.PushSubscriptionOptionsInit(
        userVisibleOnly: true,
        applicationServerKey: _base64UrlBytes(vapidPublicKey).toJS,
      ))
      .toDart;
  return _subscriptionJson(sub);
}

/// Langganan yang sudah ada, tanpa meminta izin apa pun.
Future<Map<String, dynamic>?> currentWebPushSubscription() async {
  if (!webPushSupported() || notificationPermission() != 'granted') return null;
  final reg = await web.window.navigator.serviceWorker.getRegistration().toDart;
  if (reg == null) return null;
  return _subscriptionJson(await reg.pushManager.getSubscription().toDart);
}

Future<void> unsubscribeWebPush() async {
  final reg = await web.window.navigator.serviceWorker.getRegistration().toDart;
  final sub = await reg?.pushManager.getSubscription().toDart;
  await sub?.unsubscribe().toDart;
}

web.AudioContext? _audio;

/// Siapkan audio selagi ada ketukan. Safari hanya mengizinkan AudioContext
/// berbunyi kalau dibuat atau dilanjutkan dari gestur.
void unlockWebAudio() {
  try {
    _audio ??= web.AudioContext();
    if (_audio!.state == 'suspended') _audio!.resume();
  } catch (_) {}
}

/// Tiga nada pendek saat istirahat habis dan aplikasi sedang terbuka.
void webBeep() {
  final ctx = _audio;
  if (ctx == null) return;
  try {
    final start = ctx.currentTime;
    for (var i = 0; i < 3; i++) {
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = 880;
      final t0 = start + i * 0.28;
      gain.gain.setValueAtTime(0.0001, t0);
      gain.gain.exponentialRampToValueAtTime(0.4, t0 + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.2);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t0);
      osc.stop(t0 + 0.22);
    }
  } catch (_) {}
}
