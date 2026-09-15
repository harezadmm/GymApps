import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/features/session/rest_timer.dart';

/// Jalankan blok dengan waktu palsu, supaya istirahat 90 detik tidak perlu
/// benar-benar ditunggu 90 detik.
void withFakeTime(void Function(FakeAsync async) body) {
  fakeAsync((async) {
    withClock(async.getClock(DateTime(2026, 9, 15, 18)), () => body(async));
  });
}

void main() {
  group('format', () {
    test('menit:detik, detik selalu dua digit', () {
      expect(formatRest(const Duration(seconds: 90)), '1:30');
      expect(formatRest(const Duration(seconds: 5)), '0:05');
      expect(formatRest(const Duration(minutes: 5)), '5:00');
    });

    test('versi lebar memakai dua digit menit — angka besar tidak bergeser', () {
      // Kalau "9:05" jadi "10:05" saat menit naik, seluruh baris melompat.
      expect(formatRestWide(const Duration(seconds: 89)), '01:29');
      expect(formatRestWide(const Duration(seconds: 5)), '00:05');
    });

    test('durasi negatif dibaca nol, bukan "-0:01"', () {
      expect(formatRest(const Duration(seconds: -3)), '0:00');
      expect(formatRestWide(const Duration(seconds: -3)), '00:00');
    });
  });

  test('durasi dijepit ke rentang yang masuk akal', () {
    expect(clampRest(const Duration(seconds: 1)), minRest);
    expect(clampRest(const Duration(hours: 2)), maxRest);
    expect(clampRest(const Duration(seconds: 90)), const Duration(seconds: 90));
  });

  group('hitung mundur', () {
    test('berjalan dari durasi penuh dan berhenti sendiri saat habis', () {
      withFakeTime((async) {
        final t = RestTimer()..start(const Duration(seconds: 90));
        expect(t.isRunning, isTrue);
        expect(t.remaining, const Duration(seconds: 90));

        async.elapse(const Duration(seconds: 30));
        expect(t.remaining, const Duration(seconds: 60));
        expect(t.progress, closeTo(1 / 3, 0.01));

        async.elapse(const Duration(seconds: 60));
        expect(t.isRunning, isFalse, reason: 'habis berarti berhenti, bukan lanjut ke negatif');
        expect(t.remaining, Duration.zero);
        t.dispose();
      });
    });

    test('sisa waktu ikut jam dinding, tidak menumpuk keterlambatan tick', () {
      withFakeTime((async) {
        final t = RestTimer()..start(const Duration(seconds: 90));
        // Satu lompatan besar mensimulasikan UI yang macet: pendekatan
        // counter-per-tick akan kehilangan waktu di sini, pendekatan tenggat tidak.
        async.elapse(const Duration(seconds: 45));
        expect(t.remaining, const Duration(seconds: 45));
        t.dispose();
      });
    });
  });

  group('−15s / +15s', () {
    test('menambah waktu juga menambah total — cincin tidak melompat mundur', () {
      withFakeTime((async) {
        final t = RestTimer()..start(const Duration(seconds: 60));
        async.elapse(const Duration(seconds: 20));
        final before = t.progress;

        t.adjust(const Duration(seconds: 15));
        expect(t.remaining, const Duration(seconds: 55));
        expect(t.total, const Duration(seconds: 75));
        expect(t.progress, lessThan(before), reason: 'progres mundur, tapi mulus — bukan karena penyebutnya basi');
        t.dispose();
      });
    });

    test('mengurangi di bawah nol langsung mengakhiri istirahat', () {
      withFakeTime((async) {
        final t = RestTimer()..start(const Duration(seconds: 20));
        async.elapse(const Duration(seconds: 10));
        t.adjust(const Duration(seconds: -15));
        expect(t.isRunning, isFalse);
        t.dispose();
      });
    });

    test('tidak melakukan apa-apa kalau tidak sedang berjalan', () {
      withFakeTime((async) {
        final t = RestTimer();
        t.adjust(const Duration(seconds: 15));
        expect(t.isRunning, isFalse);
        t.dispose();
      });
    });
  });

  group('ganti durasi di tengah istirahat', () {
    test('waktu yang sudah lewat tetap dihitung, tidak mengulang dari awal', () {
      withFakeTime((async) {
        final t = RestTimer()..start(const Duration(seconds: 90));
        async.elapse(const Duration(seconds: 30));

        t.retarget(const Duration(minutes: 2));
        expect(t.total, const Duration(minutes: 2));
        expect(t.remaining, const Duration(seconds: 90), reason: '120 − 30 yang sudah lewat');
        t.dispose();
      });
    });

    test('durasi baru yang lebih pendek dari waktu berjalan langsung selesai', () {
      withFakeTime((async) {
        final t = RestTimer()..start(const Duration(minutes: 3));
        async.elapse(const Duration(seconds: 100));
        t.retarget(const Duration(seconds: 60));
        expect(t.isRunning, isFalse);
        t.dispose();
      });
    });

    test('mengganti durasi saat tidak berjalan hanya menyiapkan istirahat berikutnya', () {
      withFakeTime((async) {
        final t = RestTimer()..retarget(const Duration(minutes: 2));
        expect(t.isRunning, isFalse);
        expect(t.total, const Duration(minutes: 2));

        t.start();
        expect(t.remaining, const Duration(minutes: 2));
        t.dispose();
      });
    });
  });

  test('skip mengakhiri istirahat tanpa menunggu', () {
    withFakeTime((async) {
      final t = RestTimer()..start(const Duration(minutes: 5));
      t.skip();
      expect(t.isRunning, isFalse);
      // Tidak ada timer yang tertinggal hidup: fakeAsync akan protes kalau ada.
      async.elapse(const Duration(minutes: 10));
      t.dispose();
    });
  });
}
