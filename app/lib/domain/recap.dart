/// Recap mingguan/bulanan (spec `design/RECAP-AI.md` §2).
///
/// Semua angka dihitung dari set yang benar-benar tercatat: set kerja =
/// tercentang dan bukan pemanasan, sama dengan ringkasan sesi, Beranda, dan
/// Statistik. Beban disimpan dalam kg; layar dan payload AI yang mengubahnya
/// ke satuan tampilan.
library;

import '../data/exercise_catalog.dart';
import 'models.dart';
import 'muscle_volume.dart';
import 'onerm.dart';
import 'program.dart';
import 'settings.dart';

enum RecapPeriod { week, month }

/// Rentang tanggal `[start, end)` — keduanya tengah malam waktu lokal.
class RecapRange {
  const RecapRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  /// Jumlah hari. Dihitung lewat UTC supaya pergantian jam musim panas di
  /// zona lain tidak membuat minggu jadi enam hari.
  int get days =>
      DateTime.utc(end.year, end.month, end.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

  bool contains(DateTime day) {
    final d = dateOnly(day);
    return !d.isBefore(start) && d.isBefore(end);
  }

  @override
  bool operator ==(Object other) => other is RecapRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'RecapRange(${isoDate(start)} – ${isoDate(end)})';
}

/// Periode yang memuat [day]. Minggu mulai pada [weekStartsOn]
/// (`DateTime.monday`..`DateTime.sunday`, mengikuti setelan), bulan = bulan
/// kalender.
RecapRange recapRangeFor(RecapPeriod period, DateTime day, {int weekStartsOn = DateTime.monday}) {
  final d = dateOnly(day);
  switch (period) {
    case RecapPeriod.week:
      final back = (d.weekday - weekStartsOn) % 7;
      final start = DateTime(d.year, d.month, d.day - back);
      return RecapRange(start, DateTime(start.year, start.month, start.day + 7));
    case RecapPeriod.month:
      return RecapRange(DateTime(d.year, d.month), DateTime(d.year, d.month + 1));
  }
}

/// Periode [delta] langkah dari [range] (−1 = sebelumnya).
RecapRange shiftRecapRange(RecapPeriod period, RecapRange range, int delta) {
  final s = range.start;
  switch (period) {
    case RecapPeriod.week:
      final start = DateTime(s.year, s.month, s.day + 7 * delta);
      return RecapRange(start, DateTime(start.year, start.month, start.day + 7));
    case RecapPeriod.month:
      return RecapRange(DateTime(s.year, s.month + delta), DateTime(s.year, s.month + delta + 1));
  }
}

/// Jumlah satu periode.
class RecapTotals {
  const RecapTotals({
    this.sessions = 0,
    this.workingSets = 0,
    this.volume = 0,
    this.reps = 0,
    this.seconds = 0,
    this.timedSessions = 0,
  });

  final int sessions;
  final int workingSets;

  /// kg·rep dari set kerja berbeban. Set bodyweight tidak menyumbang — sama
  /// dengan KPI Statistik.
  final double volume;
  final int reps;

  /// Total durasi sesi yang mencatat durasi.
  final int seconds;

  /// Sesi yang punya durasi — pembagi rata-rata menit per sesi.
  final int timedSessions;

  int get minutes => (seconds / 60).round();
}

/// Satu gerakan dalam periode.
class ExerciseRecap {
  const ExerciseRecap({
    required this.exerciseId,
    required this.sessions,
    required this.workingSets,
    required this.volume,
    required this.reps,
    required this.mode,
    required this.bodyweight,
    this.topSet,
    this.topSetBefore,
    this.e1rm,
    this.e1rmBefore,
    this.bestBeforeRange,
    this.repRange,
    this.lastSets = const [],
    this.seenBefore = false,
  });

  final String exerciseId;
  final int sessions;
  final int workingSets;
  final double volume;
  final int reps;
  final LogMode mode;
  final bool bodyweight;

  /// Set kerja terberat periode ini (beban dulu, lalu rep; gerakan waktu:
  /// detik terlama).
  final SetRow? topSet;

  /// Set terberat periode sebelumnya, null kalau tidak dilatih saat itu.
  final SetRow? topSetBefore;

  /// e1RM terbaik periode ini dan periode sebelumnya.
  final double? e1rm;
  final double? e1rmBefore;

  /// e1RM terbaik sepanjang masa sebelum periode ini — penentu rekor.
  final double? bestBeforeRange;

  /// "6-10" dari target sesi terakhir, atau "8" kalau tanpa rentang.
  final String? repRange;

  /// Set kerja sesi terakhir periode ini, berurutan — bahan "8, 8, 7".
  final List<SetRow> lastSets;

  /// Pernah dicatat sebelum periode ini.
  final bool seenBefore;

  bool get isNew => !seenBefore;

  bool get isRecord => e1rm != null && bestBeforeRange != null && e1rm! > bestBeforeRange! + 1e-9;

  double? get e1rmDelta => e1rm == null || e1rmBefore == null ? null : e1rm! - e1rmBefore!;
}

class Recap {
  const Recap({
    required this.period,
    required this.range,
    required this.previous,
    required this.now,
    required this.before,
    required this.trainedDays,
    required this.longestRestDays,
    required this.volumeBuckets,
    required this.bucketStarts,
    required this.exercises,
    required this.muscleSets,
    this.bodyweightStart,
    this.bodyweightEnd,
  });

  final RecapPeriod period;
  final RecapRange range;
  final RecapRange previous;
  final RecapTotals now;
  final RecapTotals before;

  /// Tanggal ISO hari yang berisi sesi, urut.
  final List<String> trainedDays;

  /// Hari tanpa latihan terpanjang di antara dua hari latihan dalam periode.
  final int longestRestDays;

  /// Volume per hari (minggu) atau per tujuh hari (bulan: 1–7, 8–14, …).
  final List<double> volumeBuckets;
  final List<DateTime> bucketStarts;

  /// Sesi terbanyak dulu, lalu volume terbesar.
  final List<ExerciseRecap> exercises;

  /// Set kerja per otot utama gerakan. Kosong kalau katalog tidak tersedia.
  final Map<MuscleGroup, int> muscleSets;

  /// Berat badan awal (catatan terakhir sebelum periode, atau catatan
  /// pertama di dalamnya) dan terakhir di dalam periode — kg.
  final double? bodyweightStart;
  final double? bodyweightEnd;

  bool get isEmpty => now.sessions == 0;

  int? get avgSessionMinutes => now.timedSessions == 0 ? null : (now.seconds / now.timedSessions / 60).round();

  List<ExerciseRecap> get records => [for (final e in exercises) if (e.isRecord) e];
}

bool _isWorking(SetRow s) => s.done && !s.isWarmup;

DateTime? _dateOf(Workout w) {
  final d = DateTime.tryParse(w.date);
  return d == null ? null : dateOnly(d);
}

RecapTotals _totals(Iterable<Workout> workouts) {
  var sessions = 0, sets = 0, reps = 0, seconds = 0, timed = 0;
  var volume = 0.0;
  for (final w in workouts) {
    sessions++;
    final dur = w.durationSeconds;
    if (dur != null && dur > 0) {
      seconds += dur;
      timed++;
    }
    for (final e in w.entries) {
      for (final s in e.sets) {
        if (!_isWorking(s)) continue;
        sets++;
        reps += s.reps;
        if (s.weight > 0 && s.reps > 0) volume += s.weight * s.reps;
      }
    }
  }
  return RecapTotals(
    sessions: sessions,
    workingSets: sets,
    volume: volume,
    reps: reps,
    seconds: seconds,
    timedSessions: timed,
  );
}

double _volumeOf(Workout w) {
  var v = 0.0;
  for (final e in w.entries) {
    for (final s in e.sets) {
      if (_isWorking(s) && s.weight > 0 && s.reps > 0) v += s.weight * s.reps;
    }
  }
  return v;
}

/// Set yang "lebih berat": beban dulu, lalu rep; gerakan waktu memakai detik.
bool _heavier(SetRow a, SetRow? b, LogMode mode) {
  if (b == null) return true;
  if (mode != LogMode.reps) return a.seconds > b.seconds;
  if (a.weight != b.weight) return a.weight > b.weight;
  return a.reps > b.reps;
}

String? _repRangeOf(ExerciseConfig? t) {
  if (t == null || t.mode != LogMode.reps) return null;
  final lo = t.repsMin;
  return lo != null && lo < t.reps ? '$lo-${t.reps}' : '${t.reps}';
}

Recap buildRecap({
  required List<Workout> history,
  required RecapPeriod period,
  required RecapRange range,
  ExerciseCatalog? catalog,
  List<BodyweightEntry> bodyweight = const [],
}) {
  final previous = shiftRecapRange(period, range, -1);
  // Kronologis (terlama dulu) apa pun urutan masukannya, supaya "sesi
  // terakhir" dan rentang rep terakhir benar.
  final dated = [
    for (final w in history)
      if (_dateOf(w) != null) (w, _dateOf(w)!),
  ]..sort((a, b) => a.$2.compareTo(b.$2));

  final inRange = [for (final (w, d) in dated) if (range.contains(d)) w];
  final inPrev = [for (final (w, d) in dated) if (previous.contains(d)) w];
  final beforeRange = [for (final (w, d) in dated) if (d.isBefore(range.start)) w];

  // Hari latihan dan istirahat terpanjang.
  final days = <String>{for (final w in inRange) isoDate(_dateOf(w)!)}.toList()..sort();
  var longestRest = 0;
  for (var i = 1; i < days.length; i++) {
    final a = DateTime.parse(days[i - 1]), b = DateTime.parse(days[i]);
    final rest = DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays - 1;
    if (rest > longestRest) longestRest = rest;
  }

  // Ember volume: per hari untuk minggu, per tujuh hari untuk bulan.
  final step = period == RecapPeriod.week ? 1 : 7;
  final starts = <DateTime>[];
  for (var s = range.start; s.isBefore(range.end); s = DateTime(s.year, s.month, s.day + step)) {
    starts.add(s);
  }
  final buckets = List<double>.filled(starts.length, 0);
  for (final w in inRange) {
    final d = _dateOf(w)!;
    final offset = DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(range.start.year, range.start.month, range.start.day))
        .inDays;
    final i = (offset ~/ step).clamp(0, buckets.length - 1);
    buckets[i] += _volumeOf(w);
  }

  // Per gerakan.
  final order = <String>[];
  final sessions = <String, int>{};
  final sets = <String, int>{};
  final volume = <String, double>{};
  final reps = <String, int>{};
  final top = <String, SetRow>{};
  final best = <String, double>{};
  final last = <String, List<SetRow>>{};
  final target = <String, ExerciseConfig?>{};
  final mode = <String, LogMode>{};
  for (final w in inRange) {
    for (final e in w.entries) {
      final working = [for (final s in e.sets) if (_isWorking(s)) s];
      if (working.isEmpty) continue;
      final id = e.exerciseId;
      if (!sessions.containsKey(id)) order.add(id);
      final m = e.target?.mode ?? mode[id] ?? LogMode.reps;
      mode[id] = m;
      sessions[id] = (sessions[id] ?? 0) + 1;
      sets[id] = (sets[id] ?? 0) + working.length;
      reps[id] = (reps[id] ?? 0) + working.fold(0, (a, s) => a + s.reps);
      volume[id] = (volume[id] ?? 0) +
          working.fold(0.0, (a, s) => a + (s.weight > 0 && s.reps > 0 ? s.weight * s.reps : 0));
      for (final s in working) {
        if (_heavier(s, top[id], m)) top[id] = s;
      }
      final b = bestSetOf(e)?.est;
      if (b != null && (best[id] == null || b > best[id]!)) best[id] = b;
      last[id] = working;
      if (e.target != null) target[id] = e.target;
    }
  }

  SetRow? topIn(List<Workout> ws, String id, LogMode m) {
    SetRow? t;
    for (final w in ws) {
      for (final e in w.entries) {
        if (e.exerciseId != id) continue;
        for (final s in e.sets) {
          if (_isWorking(s) && _heavier(s, t, m)) t = s;
        }
      }
    }
    return t;
  }

  double? bestIn(List<Workout> ws, String id) {
    double? b;
    for (final w in ws) {
      for (final e in w.entries) {
        if (e.exerciseId != id) continue;
        final est = bestSetOf(e)?.est;
        if (est != null && (b == null || est > b)) b = est;
      }
    }
    return b;
  }

  bool seen(String id) =>
      beforeRange.any((w) => w.entries.any((e) => e.exerciseId == id && e.sets.any(_isWorking)));

  final exercises = [
    for (final id in order)
      ExerciseRecap(
        exerciseId: id,
        sessions: sessions[id]!,
        workingSets: sets[id]!,
        volume: volume[id]!,
        reps: reps[id]!,
        mode: mode[id]!,
        bodyweight: target[id]?.bodyweight ?? false,
        topSet: top[id],
        topSetBefore: topIn(inPrev, id, mode[id]!),
        e1rm: best[id],
        e1rmBefore: bestIn(inPrev, id),
        bestBeforeRange: bestIn(beforeRange, id),
        repRange: _repRangeOf(target[id]),
        lastSets: last[id] ?? const [],
        seenBefore: seen(id),
      ),
  ]..sort((a, b) {
      final s = b.sessions.compareTo(a.sessions);
      return s != 0 ? s : b.volume.compareTo(a.volume);
    });

  // Set kerja per otot utama.
  final muscles = <MuscleGroup, int>{};
  if (catalog != null) {
    for (final w in inRange) {
      for (final e in w.entries) {
        final ex = catalog.byId(e.exerciseId);
        final g = ex == null ? null : muscleGroupFor(ex.target);
        if (g == null) continue;
        final n = e.sets.where(_isWorking).length;
        if (n > 0) muscles[g] = (muscles[g] ?? 0) + n;
      }
    }
  }

  // Berat badan.
  final bw = [
    for (final b in bodyweight)
      if (DateTime.tryParse(b.date) != null) (b, dateOnly(DateTime.parse(b.date))),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  final bwIn = [for (final (b, d) in bw) if (range.contains(d)) b];
  final bwBefore = [for (final (b, d) in bw) if (d.isBefore(range.start)) b];
  final double? bwEnd = bwIn.isEmpty ? null : bwIn.last.kg;
  final double? bwStart = bwEnd == null
      ? null
      : bwBefore.isNotEmpty
          ? bwBefore.last.kg
          : (bwIn.length >= 2 ? bwIn.first.kg : null);

  return Recap(
    period: period,
    range: range,
    previous: previous,
    now: _totals(inRange),
    before: _totals(inPrev),
    trainedDays: days,
    longestRestDays: longestRest,
    volumeBuckets: buckets,
    bucketStarts: starts,
    exercises: exercises,
    muscleSets: muscles,
    bodyweightStart: bwStart,
    bodyweightEnd: bwEnd,
  );
}
