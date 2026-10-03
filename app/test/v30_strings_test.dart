/// Teks baru UI v3 (`strings_v3.dart`): ada di dua bahasa, dan pembantu
/// kalimat (angka jadi kata, penggabung "dan") berperilaku seperti spec §8.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymapps/core/strings.dart';
import 'package:gymapps/core/strings_v3.dart';

void main() {
  const id = Strings(AppLanguage.indonesian);
  const en = Strings(AppLanguage.english);

  List<String> all(Strings t) => [
        t.homeTab, t.historyTab, t.programTab, t.statsTab, t.startTab,
        t.pickOther, t.strengthProgress, t.seeAll, t.ringSessions, t.ringSets, t.ringVolume,
        t.syncedPill, t.syncNotYet, t.syncNoServerPill, t.minutesAgo(2), t.justNow, t.hoursAgo(3), t.daysAgoShort(5),
        t.rotationCount(3), t.weekdayCount('Sen, Rab'), t.pickProgramPill, t.moreExercises(2),
        t.startSheetTitle, t.startSheetNextRotation('Push'), t.startSheetNextToday('Push'), t.startSheetNoProgram,
        t.freestyleRow, t.freestyleRowSub, t.programRoutinesLabel, t.otherRoutinesLabel, t.logPastRow,
        t.exerciseHistoryBtn, t.supersetBtn, t.endSupersetBtn, t.restWord,
        t.totalReps, t.targetsUp, t.newRecordsTitle, t.heaviestSet, t.holdTag, t.newTag, t.deloadTag,
        t.undoLink, t.saveLink, t.saveAgainLink, t.sessionsThisYearV3(23), t.minutesShort(48),
        t.libraryButton, t.activeProgramKicker, t.skipSessionBtn, t.reorder, t.addRoutineCard, t.programRules,
        t.modeLabel, t.minRestBetween, t.daysValue(0), t.routineMetaComma(4, 12),
        t.profileNav, t.groupTraining, t.groupAppearance, t.groupDataAccount, t.weightUnitRow, t.logRirRow,
        t.restPushRow, t.weekStartsRow, t.forceSyncRow, t.aboutRow, t.logOutRow,
        t.strengthNoData, t.oneRmShort('109 kg'), t.setsPerWeekSub(8), t.avgSets(44), t.pctOverWeeks('+18,5 %', 12),
        t.bwDelta('−0,6 kg', 30), t.logShort,
        t.insightNoProgram, t.insightNoProgramBody, t.insightRecovery, t.insightRecoveryBody('Push', 'Rabu', 'x'),
        t.insightRestDay, t.insightRestDayBody('Rabu', 'Push'), t.insightUp('Push', 2), t.insightUpBody('x', 'A dan B'),
        t.insightHold('Push'), t.insightHoldBody('x'), t.insightDeload('Push'), t.insightDeloadBody('A'),
        t.neverTrained, t.lastTrainedSentence(5),
      ];

  test('semua teks v3 terisi di dua bahasa', () {
    for (final t in [id, en]) {
      for (final s in all(t)) {
        expect(s.trim(), isNotEmpty);
      }
    }
    expect(id.pickOther, isNot(en.pickOther));
    expect(id.groupTraining, isNot(en.groupTraining));
    expect(id.ringSessions, isNot(en.ringSessions));
  });

  test('teks yang tampil di mockup sama persis', () {
    expect(id.pickOther, 'Pilih lain');
    expect(id.strengthProgress, 'Progres kekuatan');
    expect(id.ringSessions, 'Sesi minggu ini');
    expect(id.ringVolume, 'Volume vs lalu');
    expect(id.programRoutinesLabel, 'RUTINITAS PROGRAM');
    expect(id.logPastRow, 'Catat sesi yang sudah lewat');
    expect(id.activeProgramKicker, 'PROGRAM AKTIF');
    expect(id.minRestBetween, 'Istirahat minimum antar sesi');
    expect(id.groupDataAccount, 'DATA & AKUN');
    expect(id.rotationCount(3), 'Rotasi · 3 rutinitas');
    expect(id.routineMetaComma(4, 12), '4 gerakan, 12 set');
    expect(id.minutesAgo(2), '2 menit lalu');
    expect(id.sessionsThisYearV3(23), '23 sesi tahun ini');
    expect(id.minutesShort(48), '48 mnt');
    expect(id.avgSets(44), 'rata-rata 44 set');
  });

  test('angka jadi kata dan penggabung "dan"', () {
    expect(id.insightUp('Push', 2), 'Push hari ini, dua gerakan siap naik');
    expect(en.insightUp('Push', 1), 'Push today, one exercise ready to go up');
    expect(id.lastTrainedSentence(5), 'Terakhir dilatih 5 hari lalu.');
    expect(id.numberWord(2), 'dua');
    expect(en.numberWord(2), 'two');
    expect(id.numberWord(12), '12');
    expect(id.andJoin(['A', 'B']), 'A dan B');
    expect(en.andJoin(['A', 'B']), 'A and B');
    expect(id.andJoin(['A', 'B', 'C']), 'A, B, dan C');
    expect(en.andJoin(['A', 'B', 'C']), 'A, B, and C');
    expect(id.andJoin(['A']), 'A');
  });
}
