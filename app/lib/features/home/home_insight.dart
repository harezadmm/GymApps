/// Satu kalimat insight di kartu cincin Beranda (spec UI-V3 §8): sesi apa
/// berikutnya, berapa gerakan yang targetnya naik, kapan terakhir dilatih.
///
/// Fungsi murni supaya kalimatnya bisa diuji tanpa widget — ini teks yang
/// dibaca orang tiap membuka aplikasi, jadi tiap cabangnya harus benar.
library;

import '../../core/strings.dart';
import '../../core/strings_v3.dart';
import '../../domain/program.dart';
import '../../domain/progression.dart';

typedef HomeInsight = ({String title, String body});

HomeInsight homeInsight({
  required Strings t,
  required NextSession? next,
  required bool weekdayMode,
  required List<(String, PrescriptionKind)> targets,
  required int? daysSince,
}) {
  if (next == null) return (title: t.insightNoProgram, body: t.insightNoProgramBody);
  final routine = next.routine.name;
  final since = daysSince == null ? t.neverTrained : t.lastTrainedSentence(daysSince);
  if (next.early) {
    final day = t.weekdayLong(next.due.weekday);
    return weekdayMode
        ? (title: t.insightRestDay, body: t.insightRestDayBody(day, routine))
        : (title: t.insightRecovery, body: t.insightRecoveryBody(routine, day, since));
  }
  final ups = [for (final (name, kind) in targets) if (kind == PrescriptionKind.up) name];
  if (ups.isNotEmpty) {
    return (title: t.insightUp(routine, ups.length), body: t.insightUpBody(since, t.andJoin(ups.take(3).toList())));
  }
  final deload = [for (final (name, kind) in targets) if (kind == PrescriptionKind.deload) name];
  if (deload.isNotEmpty) return (title: t.insightDeload(routine), body: t.insightDeloadBody(deload.first));
  return (title: t.insightHold(routine), body: t.insightHoldBody(since));
}
