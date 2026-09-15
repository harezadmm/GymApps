import 'package:supabase_flutter/supabase_flutter.dart';

/// Satu-satunya sambungan antara aplikasi dan dokumen akun di server.
///
/// Kontraknya sengaja sama dengan yang dipakai openGym, karena aturan merge-nya
/// (lihat `reference/opengym/src/lib/sync-merge.js`) ditulis untuk kontrak ini:
///
/// * [getRev]  — revisi yang dipegang server, null kalau barisnya belum ada
/// * [pull]    — revisi + dokumen
/// * [push]    — kirim dokumen dengan `baseRev` yang terakhir dilihat perangkat
///
/// `baseRev` adalah intinya. Push yang membawa revisi basi **ditolak**, bukan
/// menimpa diam-diam salinan yang ditulis perangkat lain — itu yang membuat
/// FR-A4 ("dua HP offline, tidak ada data hilang") bisa dipenuhi. Penolakan
/// datang bersama dokumen server, dan pemanggilnya yang memutuskan cara merge.
abstract interface class Backend {
  Future<int?> getRev();
  Future<PulledState?> pull();
  Future<PushResult> push({required int? baseRev, required Map<String, dynamic> state});
}

class PulledState {
  const PulledState({required this.rev, required this.state});
  final int rev;
  final Map<String, dynamic> state;
}

/// Hasil push. Sengaja dua bentuk, bukan bool + field opsional, supaya kasus
/// konflik tidak bisa dibaca tanpa ikut membaca dokumen servernya.
sealed class PushResult {
  const PushResult();
}

class PushAccepted extends PushResult {
  const PushAccepted(this.rev);
  final int rev;
}

/// Server sudah lebih maju. [state] adalah salinannya — merge, lalu push ulang.
class PushConflict extends PushResult {
  const PushConflict({required this.rev, required this.state});
  final int rev;
  final Map<String, dynamic> state;
}

/// Dilempar kalau sebuah panggilan butuh sesi login dan tidak ada.
///
/// Bukan mengembalikan kosong: RLS tidak punya `auth.uid()` untuk dicocokkan,
/// dan jawaban kosong akan terbaca persis seperti "akunmu memang belum ada
/// datanya" — dua hal yang sangat berbeda bagi pengguna yang baru ganti HP.
class NotSignedIn implements Exception {
  const NotSignedIn();
  @override
  String toString() => 'NotSignedIn';
}

class SupabaseBackend implements Backend {
  SupabaseBackend(this._client);

  final SupabaseClient _client;

  static const _table = 'user_state';

  SupabaseClient get _authed {
    if (_client.auth.currentSession == null) throw const NotSignedIn();
    return _client;
  }

  @override
  Future<int?> getRev() async {
    final row = await _authed.from(_table).select('rev').maybeSingle();
    return row == null ? null : (row['rev'] as num).toInt();
  }

  @override
  Future<PulledState?> pull() async {
    final row = await _authed.from(_table).select('rev, state').maybeSingle();
    if (row == null) return null;
    return PulledState(
      rev: (row['rev'] as num).toInt(),
      state: Map<String, dynamic>.from(row['state'] as Map),
    );
  }

  /// [baseRev] null memaksa tulis — dipakai "adopsi salinan perangkat ini",
  /// sama seperti flag force di openGym.
  @override
  Future<PushResult> push({required int? baseRev, required Map<String, dynamic> state}) async {
    final data = await _authed.rpc('push_state', params: {
      'p_base_rev': baseRev,
      'p_state': state,
    });

    // push_state() mengembalikan tabel satu baris.
    final row = data is List ? data.first as Map : data as Map;
    final rev = (row['rev'] as num).toInt();
    if (row['ok'] == true) return PushAccepted(rev);
    return PushConflict(rev: rev, state: Map<String, dynamic>.from(row['state'] as Map));
  }
}
