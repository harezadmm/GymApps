/// Padanan web_push_web.dart untuk Android: notifikasinya lewat
/// flutter_local_notifications, bukan Web Push.
library;

bool webPushSupported() => false;
bool runningStandalone() => false;
bool runningOnIos() => false;
String notificationPermission() => 'unsupported';
Future<Map<String, dynamic>?> subscribeWebPush(String vapidPublicKey) async => null;
Future<Map<String, dynamic>?> currentWebPushSubscription() async => null;
Future<void> unsubscribeWebPush() async {}
void unlockWebAudio() {}
void webBeep() {}
