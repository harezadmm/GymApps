/// Teks tab Statistik dan Dashboard (v2.2: grafik interaktif, KPI periode).
///
/// Dipisah dari `strings.dart` supaya beberapa orang bisa menambah teks di
/// area masing-masing tanpa saling menimpa satu file raksasa.
library;

import 'strings.dart';

extension StatsStrings on Strings {
  bool get _id => lang == AppLanguage.indonesian;

  /// Chip rentang: "7 days" / "7 hari". Pendek, karena tiga chip harus muat
  /// sebaris di HP 360 dp bersama ruang gulirnya.
  String rangeChip(int days) => _id ? '$days hari' : '$days days';

  /// Chip periode dashboard: "12 wk" / "12 mgg".
  String weeksChip(int weeks) => _id ? '$weeks mgg' : '$weeks wk';

  String get sessionsKpi => _id ? 'Sesi' : 'Sessions';
  String get workingSetsKpi => _id ? 'Set kerja' : 'Working sets';
  String get volumeKpi => 'Volume';

  String get tapMuscleHint => _id ? 'Ketuk otot untuk melihat porsinya' : 'Tap a muscle to see its share';

  /// "Dada · 23 % volume · 12 set". Persennya terhadap total volume periode,
  /// bukan terhadap otot tertinggi seperti warna peta — orang membaca "23 %"
  /// sebagai bagian dari keseluruhan.
  String muscleDetail(String muscle, int pct, int sets) => _id
      ? '$muscle · $pct % volume · $sets set'
      : '$muscle · $pct % volume · ${sets == 1 ? '1 set' : '$sets sets'}';

  /// Label gelembung grafik mingguan: "-3w" / "-3 mgg".
  String weeksAgoShort(int n) => _id ? '-$n mgg' : '-${n}w';

  /// Satu minggu, [n] minggu lalu; minggu ini "now" / "sekarang".
  String weekAgo(int n) => n == 0 ? catalogue('now') : weeksAgoShort(n);

  /// Label per batang grafik mingguan, terlama dulu: "-11w … -1w, now".
  ///
  /// Sumbu kiri grafik memakai `weekAgo(weeks - 1)` — fungsi yang sama —
  /// supaya sumbu dan gelembung batang paling kiri menyebut minggu yang sama.
  /// Dulu sumbunya "12 wk ago" sementara gelembungnya "-11w".
  List<String> weekLabels(int weeks) => [for (var i = weeks - 1; i >= 0; i--) weekAgo(i)];

  /// Rentang minggu untuk batang yang meringkas beberapa minggu:
  /// "-51w – -48w", "-3w – now". Rentang satu minggu = label mingguan biasa.
  String weekSpan(int from, int to) => from == to ? weekAgo(to) : '${weekAgo(from)} – ${weekAgo(to)}';

  /// Judul grafik sesi saat setahun diringkas per beberapa minggu.
  String sessionsPerNWeeks(int n) => _id ? 'Sesi per $n minggu' : 'Sessions per $n weeks';

  String e1rmByWeekN(int weeks) =>
      _id ? 'e1RM per minggu — $weeks minggu terakhir' : 'e1RM by week — last $weeks weeks';

  String get thisPeriod => _id ? 'Periode ini' : 'This period';
  String get perWeek => _id ? 'per minggu' : 'per week';
  String get trend => _id ? 'Tren' : 'Trend';
  String weeksSinceRecord(int n) => _id ? '$n mgg sejak rekor' : '$n wk since record';
  String get last12Weeks => _id ? '12 mgg terakhir' : 'last 12 wk';
}
