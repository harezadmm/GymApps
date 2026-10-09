/// Analisis AI untuk recap mingguan/bulanan (spec `design/RECAP-AI.md`).
///
/// Aplikasi tidak pernah memegang kunci Gemini: ringkasan angka dikirim ke
/// fungsi server `/api/recap-analyze` bersama token akun, dan server yang
/// berbicara dengan model. Hasilnya disimpan lokal per akun + periode,
/// supaya membuka recap yang sama tidak memanggil AI lagi.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/server_api.dart';
import '../domain/program.dart';
import '../domain/recap.dart';

class RecapSuggestion {
  const RecapSuggestion({required this.title, required this.detail});

  final String title;
  final String detail;

  Map<String, dynamic> toJson() => {'title': title, 'detail': detail};
}

class RecapAnalysis {
  const RecapAnalysis({
    required this.headline,
    required this.summary,
    required this.strengths,
    required this.critiques,
    required this.suggestions,
    required this.nextFocus,
    required this.model,
    required this.createdAt,
  });

  final String headline;
  final String summary;
  final List<String> strengths;
  final List<String> critiques;
  final List<RecapSuggestion> suggestions;
  final String nextFocus;

  /// Model yang menulisnya, ditampilkan kecil di bawah hasil.
  final String model;
  final DateTime createdAt;

  static List<String> _strings(Object? v) => [
        for (final s in (v is List ? v : const []))
          if (s is String && s.trim().isNotEmpty) s.trim(),
      ];

  /// Membaca jawaban server atau isi cache. Melempar [FormatException] kalau
  /// bentuknya tidak dikenali.
  factory RecapAnalysis.fromJson(Map<String, dynamic> j) {
    final headline = j['headline'], summary = j['summary'];
    if (headline is! String || headline.isEmpty || summary is! String) {
      throw const FormatException('analisis tanpa judul/ringkasan');
    }
    return RecapAnalysis(
      headline: headline,
      summary: summary,
      strengths: _strings(j['strengths']),
      critiques: _strings(j['critiques']),
      suggestions: [
        for (final s in (j['suggestions'] is List ? j['suggestions'] as List : const []))
          if (s is Map && s['title'] is String && s['detail'] is String)
            RecapSuggestion(title: s['title'] as String, detail: s['detail'] as String),
      ],
      nextFocus: j['nextFocus'] is String ? j['nextFocus'] as String : '',
      model: j['model'] is String ? j['model'] as String : '',
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'headline': headline,
        'summary': summary,
        'strengths': strengths,
        'critiques': critiques,
        'suggestions': [for (final s in suggestions) s.toJson()],
        'nextFocus': nextFocus,
        'model': model,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Alasan analisis tidak bisa dibuat — masing-masing punya kalimatnya sendiri
/// di layar, karena tindakan yang bisa diambil berbeda.
enum RecapAiFailure {
  /// Akun belum tersambung ke server (akun lokal, atau sesi Supabase habis).
  notConnected,

  /// Tidak ada jaringan.
  offline,

  /// Batas analisis harian akun ini tercapai.
  limit,

  /// Semua model sedang penuh — coba lagi sebentar lagi.
  busy,

  /// Server belum punya fungsi ini atau kuncinya belum diisi.
  unavailable,

  /// Periode tanpa sesi.
  empty,

  /// Lainnya.
  failed,
}

class RecapAiException implements Exception {
  const RecapAiException(this.kind);

  final RecapAiFailure kind;

  @override
  String toString() => 'RecapAiException(${kind.name})';
}

abstract interface class RecapAnalyzer {
  Future<RecapAnalysis> analyze(Map<String, dynamic> payload);
}

/// Analisis lewat fungsi server.
class ServerRecapAnalyzer implements RecapAnalyzer {
  ServerRecapAnalyzer({this._client, this._token, this._endpoint, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final http.Client? _client;
  final Future<String?> Function()? _token;
  final Uri? _endpoint;
  final DateTime Function() _now;

  /// Server sendiri menyerah di 60 detik; sedikit lebih lama di sini supaya
  /// jawabannya, bukan batas waktu kita, yang menentukan.
  static const timeout = Duration(seconds: 75);

  @override
  Future<RecapAnalysis> analyze(Map<String, dynamic> payload) async {
    final tokenFn = _token ?? ServerApi.accessToken;
    final token = tokenFn == null ? null : await tokenFn();
    if (token == null || token.isEmpty) throw const RecapAiException(RecapAiFailure.notConnected);

    final client = _client ?? http.Client();
    http.Response res;
    try {
      res = await client
          .post(
            _endpoint ?? ServerApi.endpoint('api/recap-analyze'),
            headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
            body: jsonEncode({'payload': payload}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const RecapAiException(RecapAiFailure.busy);
    } on http.ClientException {
      throw const RecapAiException(RecapAiFailure.offline);
    } catch (_) {
      // SocketException dan kerabatnya di HP — semuanya "tidak tersambung".
      throw const RecapAiException(RecapAiFailure.offline);
    } finally {
      if (_client == null) client.close();
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }
    final error = body?['error'];
    switch (res.statusCode) {
      case 200:
        final a = body?['analysis'];
        if (a is! Map<String, dynamic>) throw const RecapAiException(RecapAiFailure.failed);
        try {
          return RecapAnalysis.fromJson({
            ...a,
            'model': body?['model'] is String ? body!['model'] : '',
            'createdAt': _now().toIso8601String(),
          });
        } on FormatException {
          throw const RecapAiException(RecapAiFailure.failed);
        }
      case 401:
        throw const RecapAiException(RecapAiFailure.notConnected);
      case 429:
        throw const RecapAiException(RecapAiFailure.limit);
      case 404:
        throw const RecapAiException(RecapAiFailure.unavailable);
      case 400 when error == 'empty':
        throw const RecapAiException(RecapAiFailure.empty);
      case 503:
        throw RecapAiException(error == 'busy' ? RecapAiFailure.busy : RecapAiFailure.unavailable);
      default:
        throw const RecapAiException(RecapAiFailure.failed);
    }
  }
}

/// Hasil analisis tersimpan beserta sidik jari payload yang dianalisis.
class CachedRecapAnalysis {
  const CachedRecapAnalysis({required this.fingerprint, required this.analysis});

  final String fingerprint;
  final RecapAnalysis analysis;
}

/// Simpanan lokal hasil analisis — per perangkat, tidak ikut sinkron. Hasil
/// AI bukan data latihan; kalau hilang, cukup dianalisis ulang.
class RecapAiCache {
  /// Analisis yang disimpan per akun. Lebih dari setahun mingguan + bulanan
  /// tidak perlu; yang terlama dibuang.
  static const keep = 30;

  static String _key(String account, RecapPeriod period, DateTime start) =>
      'recap.ai.$account.${period.name}.${isoDate(start)}';
  static String _index(String account) => 'recap.ai.$account.index';

  Future<CachedRecapAnalysis?> load(String account, RecapPeriod period, DateTime start) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(account, period, start));
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return CachedRecapAnalysis(
        fingerprint: j['fingerprint'] as String,
        analysis: RecapAnalysis.fromJson(j['analysis'] as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String account, RecapPeriod period, DateTime start, String fingerprint, RecapAnalysis a) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(account, period, start);
    await prefs.setString(key, jsonEncode({'fingerprint': fingerprint, 'analysis': a.toJson()}));
    final index = [...?prefs.getStringList(_index(account))]
      ..remove(key)
      ..add(key);
    while (index.length > keep) {
      await prefs.remove(index.removeAt(0));
    }
    await prefs.setStringList(_index(account), index);
  }
}
