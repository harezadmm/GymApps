/// Setelan "layar tetap menyala" dan penerapannya selama sesi.
///
/// Dulu tombolnya di Profil hanya mengubah state lokal widget — tidak
/// tersimpan, tidak berpengaruh. Padahal ini setelan yang paling terasa di
/// gym: layar yang padam di tengah set berarti membuka kunci dengan tangan
/// berkapur setiap dua menit.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class KeepAwake {
  KeepAwake._();

  /// Setelan perangkat, bukan per akun: ini soal ponsel yang dipakai, bukan
  /// orang yang masuk.
  static const _key = 'settings.keepAwake';

  static Future<bool> get enabled async => (await SharedPreferences.getInstance()).getBool(_key) ?? true;

  static Future<void> set(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(_key, value);
  }

  /// Tahan layar menyala kalau setelannya mengizinkan. Dipanggil saat sesi
  /// dibuka. Gagal (platform tanpa dukungan, test host) tidak apa-apa.
  static Future<void> holdIfEnabled() async {
    if (!await enabled) return;
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('wakelock tidak tersedia: $e');
    }
  }

  static Future<void> release() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('wakelock tidak tersedia: $e');
    }
  }
}
