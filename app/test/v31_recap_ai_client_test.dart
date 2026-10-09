/// Klien analisis AI recap: memanggil /api/recap-analyze dengan token akun,
/// memetakan status ke jenis galat yang bisa dijelaskan layar, dan menyimpan
/// hasil per akun + periode bersama sidik jari payload.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/data/recap_ai.dart';
import 'package:gymapps/domain/recap.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _endpoint = Uri.parse('https://gymapps.test/api/recap-analyze');
const _payload = {'v': 1, 'period': 'week'};
const _analysis = {
  'headline': 'Bench naik',
  'summary': 'Tiga sesi.',
  'strengths': ['Bench 60x8 → 62.5x8'],
  'critiques': ['Hamstring 0 set'],
  'suggestions': [
    {'title': 'Tambah hamstring', 'detail': '3 set Romanian Deadlift'},
  ],
  'nextFocus': 'Kaki',
};

/// Respons JSON UTF-8 — `http.Response` biasa menolak karakter di luar Latin-1.
http.Response _json(Object body, int status) => http.Response.bytes(utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

ServerRecapAnalyzer _analyzer(MockClient client, {String? token = 'tok-123'}) => ServerRecapAnalyzer(
      client: client,
      endpoint: _endpoint,
      token: () async => token,
      now: () => DateTime(2026, 10, 9, 10, 42),
    );

Future<RecapAiFailure?> _failureOf(Future<Object?> f) async {
  try {
    await f;
    return null;
  } on RecapAiException catch (e) {
    return e.kind;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('POST dengan token akun dan payload; hasil dipetakan', () async {
    late http.Request sent;
    final client = MockClient((r) async {
      sent = r;
      return _json({'analysis': _analysis, 'model': 'gemini-3.5-flash', 'remaining': 19}, 200);
    });
    final a = await _analyzer(client).analyze(_payload);
    expect(sent.method, 'POST');
    expect(sent.url, _endpoint);
    expect(sent.headers['authorization'], 'Bearer tok-123');
    expect(sent.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), {'payload': _payload});
    expect(a.headline, 'Bench naik');
    expect(a.strengths, ['Bench 60x8 → 62.5x8']);
    expect(a.suggestions.single.title, 'Tambah hamstring');
    expect(a.suggestions.single.detail, '3 set Romanian Deadlift');
    expect(a.nextFocus, 'Kaki');
    expect(a.model, 'gemini-3.5-flash');
    expect(a.createdAt, DateTime(2026, 10, 9, 10, 42));
  });

  test('tanpa token → notConnected tanpa memanggil server', () async {
    var called = false;
    final client = MockClient((r) async {
      called = true;
      return http.Response('{}', 200);
    });
    expect(await _failureOf(_analyzer(client, token: null).analyze(_payload)), RecapAiFailure.notConnected);
    expect(called, isFalse);
  });

  test('status → jenis galat', () async {
    Future<RecapAiFailure?> run(int status, [Map<String, dynamic> body = const {}]) =>
        _failureOf(_analyzer(MockClient((r) async => _json(body, status))).analyze(_payload));
    expect(await run(401, {'error': 'unauthorized'}), RecapAiFailure.notConnected);
    expect(await run(429, {'error': 'limit'}), RecapAiFailure.limit);
    expect(await run(503, {'error': 'busy'}), RecapAiFailure.busy);
    expect(await run(503, {'error': 'not_configured'}), RecapAiFailure.unavailable);
    expect(await run(400, {'error': 'empty'}), RecapAiFailure.empty);
    expect(await run(400, {'error': 'bad_payload'}), RecapAiFailure.failed);
    expect(await run(502, {'error': 'failed'}), RecapAiFailure.failed);
    expect(await run(404), RecapAiFailure.unavailable, reason: 'server lama tanpa fungsi ini');
    expect(await run(504), RecapAiFailure.busy, reason: 'batas waktu Vercel');
    expect(await run(503, {'error': 'auth_unavailable'}), RecapAiFailure.busy, reason: 'Supabase sedang bermasalah');
    expect(await run(429, {'error': 'in_progress'}), RecapAiFailure.busy, reason: 'analisis sebelumnya masih berjalan');
    expect(await run(200, {'nothing': true}), RecapAiFailure.failed, reason: 'jawaban tanpa analisis');
  });

  test('token gagal diperbarui (offline dengan token kedaluwarsa) → offline, bukan tidak tersambung', () async {
    var called = false;
    final analyzer = ServerRecapAnalyzer(
      client: MockClient((r) async {
        called = true;
        return http.Response('{}', 200);
      }),
      endpoint: _endpoint,
      token: () async => throw Exception('Failed host lookup'),
    );
    expect(await _failureOf(analyzer.analyze(_payload)), RecapAiFailure.offline);
    expect(called, isFalse);
  });

  test('jaringan putus → offline', () async {
    final client = MockClient((r) async => throw http.ClientException('Failed host lookup'));
    expect(await _failureOf(_analyzer(client).analyze(_payload)), RecapAiFailure.offline);
  });

  group('cache', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    final analysis = RecapAnalysis.fromJson({
      ..._analysis,
      'model': 'gemini-2.5-flash',
      'createdAt': '2026-10-09T10:42:00.000',
    });

    test('simpan dan muat per akun + periode', () async {
      final cache = RecapAiCache();
      final start = DateTime(2026, 10, 5);
      await cache.save('a@x.com', RecapPeriod.week, start, 'sidik-1', analysis);
      final hit = await cache.load('a@x.com', RecapPeriod.week, start);
      expect(hit!.fingerprint, 'sidik-1');
      expect(hit.analysis.headline, 'Bench naik');
      expect(hit.analysis.model, 'gemini-2.5-flash');
      expect(hit.analysis.createdAt, DateTime(2026, 10, 9, 10, 42));
      expect(await cache.load('b@x.com', RecapPeriod.week, start), isNull, reason: 'akun lain');
      expect(await cache.load('a@x.com', RecapPeriod.month, start), isNull, reason: 'periode lain');
    });

    test('hanya 30 analisis terakhir per akun yang disimpan', () async {
      final cache = RecapAiCache();
      for (var i = 0; i < 35; i++) {
        await cache.save('a@x.com', RecapPeriod.week, DateTime(2026, 1, 1 + 7 * i), 'f$i', analysis);
      }
      expect(await cache.load('a@x.com', RecapPeriod.week, DateTime(2026, 1, 1)), isNull);
      expect(await cache.load('a@x.com', RecapPeriod.week, DateTime(2026, 1, 1 + 7 * 34)), isNotNull);
      final prefs = await SharedPreferences.getInstance();
      final kept = prefs.getKeys().where((k) => k.startsWith('recap.ai.a@x.com.') && !k.endsWith('.index'));
      expect(kept.length, 30);
    });

    test('isi cache rusak dibaca sebagai kosong', () async {
      SharedPreferences.setMockInitialValues({'recap.ai.a@x.com.week.2026-10-05': '{rusak'});
      expect(await RecapAiCache().load('a@x.com', RecapPeriod.week, DateTime(2026, 10, 5)), isNull);
    });
  });
}
