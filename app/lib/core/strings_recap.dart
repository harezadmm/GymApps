/// Teks recap mingguan/bulanan dan analisis AI (v3.1).
///
/// Satu extension per fitur, seperti `strings_v3.dart`: pemanggilnya tetap
/// `context.t.xxx`.
library;

import 'strings.dart';

extension RecapStrings on Strings {
  String _r(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  // ── Layar ──
  String get recapTitle => _r('Recap', 'Recap');
  String get recapWeekly => _r('Weekly', 'Mingguan');
  String get recapMonthly => _r('Monthly', 'Bulanan');
  String get thisWeekLabel => _r('This week', 'Minggu ini');
  String get lastWeekLabel => _r('Last week', 'Minggu lalu');
  String get thisMonthLabel => _r('This month', 'Bulan ini');
  String get lastMonthLabel => _r('Last month', 'Bulan lalu');
  String get recapPrev => _r('Previous period', 'Periode sebelumnya');
  String get recapNext => _r('Next period', 'Periode berikutnya');

  // ── KPI ──
  String get kpiSessions => _r('Sessions', 'Sesi');
  String get kpiVolume => _r('Volume', 'Volume');
  String get kpiTime => _r('Training time', 'Waktu latihan');
  String get kpiSets => _r('Working sets', 'Set kerja');

  /// 145 → "2 h 25 min" / "2 j 25 mnt"; di bawah sejam cukup menitnya.
  String hoursMinutes(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    if (h == 0) return _r('$m min', '$m mnt');
    if (m == 0) return _r('$h h', '$h j');
    return _r('$h h $m min', '$h j $m mnt');
  }

  String minutesDelta(int minutes) => _r('${minutes > 0 ? '+' : ''}$minutes min', '${minutes > 0 ? '+' : ''}$minutes mnt');

  // ── Konsistensi ──
  String get consistencyTitle => _r('Consistency', 'Konsistensi');
  String daysTrained(int n, int of) => _r('$n of $of days', '$n dari $of hari');
  String avgPerSession(int min) => _r('avg $min min per session', 'rata-rata $min mnt per sesi');
  String longestRest(int days) =>
      _r(days == 1 ? 'longest rest 1 day' : 'longest rest $days days', 'istirahat terpanjang $days hari');
  String planProgress(int done, int planned) => _r('Plan: $done of $planned sessions', 'Rencana: $done dari $planned sesi');
  String bodyweightTrend(String from, String to) => _r('Bodyweight $from → $to', 'Berat badan $from → $to');
  String bodyweightNow(String now) => _r('Bodyweight $now', 'Berat badan $now');

  // ── Volume ──
  String get volumePerDay => _r('Volume per day', 'Volume per hari');
  String get volumePerWeek => _r('Volume per week', 'Volume per minggu');

  // ── Progres beban & rep ──
  String get loadRepsTitle => _r('Load & reps', 'Progres beban & rep');
  String get vsPrevious => _r('vs previous', 'vs periode lalu');
  String firstTime(String set) => _r('First time · $set', 'Pertama kali · $set');
  String secondsShort(int s) => _r('$s s', '$s dtk');

  // ── Rekor ──
  String recordLine(String now, String before) =>
      _r('Estimated 1RM $now (was $before)', 'Perkiraan 1RM $now (sebelumnya $before)');

  // ── Otot ──
  String get setsPerMuscle => _r('Working sets per muscle', 'Set kerja per otot');
  String perWeekAvg(String v) => _r('≈ $v/week', '≈ $v/minggu');

  // ── Kosong ──
  String get recapEmptyThisWeek => _r('No sessions this week yet', 'Belum ada sesi minggu ini');
  String get recapEmptyThisMonth => _r('No sessions this month yet', 'Belum ada sesi bulan ini');
  String get recapEmptyPast => _r('No sessions in this period', 'Tidak ada sesi di periode ini');
  String get recapEmptyBody =>
      _r('Finish a session and its recap shows up here.', 'Selesaikan sesi dan recap-nya muncul di sini.');

  // ── Analisis AI ──
  String get aiTitle => _r('AI analysis', 'Analisis AI');
  String get aiIntro => _r(
        'Gemini reads your load, reps, and training time for this period, then gives critique and suggestions.',
        'Gemini membaca beban, rep, dan waktu latihanmu periode ini, lalu memberi kritik dan saran.',
      );
  String get aiDataNote => _r(
        'A summary of this period\'s numbers is sent to Google Gemini — no email or notes.',
        'Ringkasan angka latihan periode ini dikirim ke Google Gemini, tanpa email atau catatan.',
      );
  String get aiAnalyze => _r('Analyze now', 'Analisis sekarang');
  String get aiAnalyzing => _r('Analyzing your training…', 'Menganalisis latihanmu…');
  String get aiStrengths => _r('Going well', 'Sudah bagus');
  String get aiCritiques => _r('Critique', 'Kritik');
  String get aiSuggestions => _r('Suggestions', 'Saran');
  String get aiNextFocus => _r('Next focus', 'Fokus berikutnya');
  String aiAnalyzedAt(String when, String model) =>
      model.isEmpty ? _r('Analyzed $when', 'Dianalisis $when') : _r('Analyzed $when · $model', 'Dianalisis $when · $model');
  String get aiReanalyze => _r('Analyze again', 'Analisis ulang');
  String get aiStale =>
      _r('Your data changed since this analysis.', 'Datamu berubah sejak analisis ini.');
  String get aiDisclaimer => _r('AI can be wrong. Not medical advice.', 'AI bisa keliru. Bukan saran medis.');
  String get aiRetry => _r('Try again', 'Coba lagi');
  String get aiLocalOnly => _r(
        'AI analysis is available for accounts synced to the server.',
        'Analisis AI tersedia untuk akun yang tersinkron ke server.',
      );
  String get aiNotConnected => _r(
        'AI analysis needs an account connected to the server. Open Profile → Force sync.',
        'Analisis AI butuh akun yang tersambung ke server. Buka Profil → Paksa sinkron.',
      );
  String get aiOffline =>
      _r('No connection. Check your internet and try again.', 'Tidak ada koneksi. Periksa internet lalu coba lagi.');
  String get aiLimit =>
      _r('Daily AI limit reached. Try again tomorrow.', 'Batas analisis AI hari ini tercapai. Coba lagi besok.');
  String get aiBusy => _r('The AI is busy right now. Try again in a minute.', 'AI sedang sibuk. Coba lagi sebentar lagi.');
  String get aiUnavailable =>
      _r('AI analysis isn\'t available on this server yet.', 'Analisis AI belum tersedia di server ini.');
  String get aiEmpty => _r('There are no sessions to analyze.', 'Tidak ada sesi untuk dianalisis.');
  String get aiFailed => _r('The analysis failed. Try again.', 'Analisis gagal. Coba lagi.');

  // ── Pintu masuk ──
  String get recapThisWeekCard => _r('Recap this week', 'Recap minggu ini');
  String get recapLastWeekCard => _r('Recap last week', 'Recap minggu lalu');
  String get recapButton => _r('Recap', 'Recap');
  String sessionsShort(int n) => _r(n == 1 ? '1 session' : '$n sessions', '$n sesi');
  String volumeChange(String pct) => _r('volume $pct', 'volume $pct');
}
