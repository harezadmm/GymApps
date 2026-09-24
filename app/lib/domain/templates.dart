/// Template program bawaan (spec §5, FR-B1, FR-B6, FR-B7).
///
/// Setiap template menghasilkan rutinitas sungguhan yang bisa diedit, bukan
/// sekadar nama. Id gerakan adalah id katalog (`assets/data/exercises.json`),
/// supaya peta otot, radar, dan riwayat per gerakan langsung bekerja.
///
/// Beban awal sengaja 0: sesi pertama adalah titik awal, dan orang mengetik
/// beban yang memang dia angkat. Menebak beban untuk orang yang belum pernah
/// dilihat hanya menghasilkan angka yang harus dihapus.
library;

import 'models.dart';

/// Program beserta rutinitasnya, siap disimpan.
class ProgramBundle {
  const ProgramBundle(this.program, this.routines);
  final Program program;
  final List<Routine> routines;
}

const templateIds = ['ppl', 'upper-lower', 'bro-split', 'heavy-duty', 'full-body', 'five-by-five'];

ExerciseConfig _ex(
  String id, {
  int sets = 3,
  required int lo,
  required int hi,
  bool heavy = false,
  ProgressionPolicy? policy,
  int warmups = 0,
  bool bodyweight = false,
  int rest = 90,
}) =>
    ExerciseConfig(
      exerciseId: id,
      policy: policy,
      sets: sets,
      reps: hi,
      repsMin: lo == hi ? null : lo,
      heavyBodyPart: heavy,
      warmupSets: warmups,
      bodyweight: bodyweight,
      restSeconds: rest,
    );

// Gerakan yang sering dipakai ulang, supaya template di bawah terbaca sebagai
// program, bukan deretan angka.
const _bench = '0025', _inclineDb = '0314', _ohp = '0091', _lateral = '0334', _pushdown = '0201';
const _fly = '0308', _chestPress = '0577', _skull = '0061', _dip = '0814';
const _row = '0027', _pulldown = '2330', _seatedRow = '0861', _rearDelt = '0076', _dbRow = '0292', _shrug = '0095';
const _curl = '0031', _hammer = '0313', _dbCurl = '0294';
const _squat = '0043', _rdl = '0085', _deadlift = '0032', _legExt = '0585', _legCurl = '0586', _calf = '1372';

Routine _r(String tpl, int i, String name, List<ExerciseConfig> ex, {ProgressionPolicy? policy}) =>
    Routine(id: '$tpl-$i', name: name, exercises: ex, policy: policy);

/// Bangun template. null kalau id-nya tidak dikenal.
ProgramBundle? buildTemplate(String id) {
  const dbl = ProgressionPolicy.double_;
  const lin = ProgressionPolicy.linear;
  const hit = ProgressionPolicy.hit;

  ExerciseConfig compound(String x, {int sets = 3, bool heavy = false}) =>
      _ex(x, sets: sets, lo: 6, hi: 10, heavy: heavy, rest: 150);
  ExerciseConfig accessory(String x, {int sets = 3, bool heavy = false}) =>
      _ex(x, sets: sets, lo: 8, hi: 12, heavy: heavy);
  ExerciseConfig iso(String x, {int sets = 3, bool heavy = false}) =>
      _ex(x, sets: sets, lo: 12, hi: 15, heavy: heavy, rest: 75);

  switch (id) {
    case 'ppl':
      final r = [
        _r(id, 0, 'Push', [compound(_bench), compound(_ohp), accessory(_inclineDb), iso(_lateral), iso(_pushdown)],
            policy: dbl),
        _r(id, 1, 'Pull',
            [compound(_row, heavy: true), accessory(_pulldown, heavy: true), accessory(_seatedRow, heavy: true),
             iso(_rearDelt), accessory(_curl), iso(_hammer)],
            policy: dbl),
        _r(id, 2, 'Legs',
            [compound(_squat, heavy: true), accessory(_rdl, heavy: true), iso(_legExt, heavy: true),
             iso(_legCurl, heavy: true), iso(_calf, heavy: true)],
            policy: dbl),
      ];
      return ProgramBundle(Program(name: 'Push / Pull / Legs', templateId: id, order: [for (final x in r) x.id]), r);

    case 'upper-lower':
      final r = [
        _r(id, 0, 'Upper',
            [compound(_bench), compound(_row, heavy: true), compound(_ohp), accessory(_pulldown, heavy: true),
             accessory(_curl), iso(_pushdown)],
            policy: dbl),
        _r(id, 1, 'Lower',
            [compound(_squat, heavy: true), accessory(_rdl, heavy: true), iso(_legExt, heavy: true),
             iso(_legCurl, heavy: true), iso(_calf, heavy: true)],
            policy: dbl),
      ];
      return ProgramBundle(Program(name: 'Upper / Lower', templateId: id, order: [for (final x in r) x.id]), r);

    case 'bro-split':
      // FR-B6: 5 rutinitas, 4–5 gerakan, 3–4 set, 8–12 rep, double, Senin–Jumat.
      final r = [
        _r(id, 0, 'Chest',
            [accessory(_bench, sets: 4), accessory(_inclineDb), accessory(_fly), accessory(_chestPress)],
            policy: dbl),
        _r(id, 1, 'Back',
            [accessory(_row, sets: 4, heavy: true), accessory(_pulldown, heavy: true),
             accessory(_seatedRow, heavy: true), accessory(_dbRow, heavy: true)],
            policy: dbl),
        _r(id, 2, 'Shoulders',
            [accessory(_ohp, sets: 4), accessory(_lateral), accessory(_rearDelt), accessory(_shrug, heavy: true)],
            policy: dbl),
        _r(id, 3, 'Legs',
            [accessory(_squat, sets: 4, heavy: true), accessory(_rdl, heavy: true), accessory(_legExt, heavy: true),
             accessory(_legCurl, heavy: true), accessory(_calf, heavy: true)],
            policy: dbl),
        _r(id, 4, 'Arms',
            [accessory(_curl), accessory(_hammer), accessory(_pushdown), accessory(_skull), accessory(_dbCurl)],
            policy: dbl),
      ];
      return ProgramBundle(
        Program(
          name: 'Bro split',
          templateId: id,
          mode: ProgramMode.weekday,
          days: const [1, 2, 3, 4, 5],
          order: [for (final x in r) x.id],
        ),
        r,
      );

    case 'heavy-duty':
      // FR-B7: 4 rutinitas rotasi, 1–2 warm-up + 1 working set, 6–10 rep,
      // policy hit, minimal 3 hari istirahat.
      ExerciseConfig h(String x, {int warmups = 1, bool heavy = false, bool bw = false}) =>
          _ex(x, sets: 1, lo: 6, hi: 10, heavy: heavy, warmups: warmups, bodyweight: bw, rest: 180);
      final r = [
        _r(id, 0, 'Chest + Back',
            [h(_fly, warmups: 2), h(_bench), h(_pulldown, warmups: 2, heavy: true), h(_row, heavy: true)],
            policy: hit),
        _r(id, 1, 'Legs A', [h(_legExt, warmups: 2, heavy: true), h(_squat, heavy: true), h(_legCurl, heavy: true)],
            policy: hit),
        _r(id, 2, 'Delts + Arms',
            [h(_lateral, warmups: 2), h(_ohp), h(_curl), h(_dip, warmups: 0, bw: true)],
            policy: hit),
        _r(id, 3, 'Legs B', [h(_rdl, warmups: 2, heavy: true), h(_legExt, heavy: true), h(_calf, heavy: true)],
            policy: hit),
      ];
      return ProgramBundle(
        Program(name: 'Heavy Duty', templateId: id, minRestDays: 3, order: [for (final x in r) x.id]),
        r,
      );

    case 'full-body':
      ExerciseConfig fb(String x, {bool heavy = false}) =>
          _ex(x, sets: 3, lo: 8, hi: 8, heavy: heavy, rest: 120);
      final r = [
        _r(id, 0, 'Full Body',
            [fb(_squat, heavy: true), fb(_bench), fb(_row, heavy: true), fb(_ohp), fb(_rdl, heavy: true)],
            policy: lin),
      ];
      return ProgramBundle(
        Program(name: 'Full Body', templateId: id, minRestDays: 1, order: [for (final x in r) x.id]),
        r,
      );

    case 'five-by-five':
      ExerciseConfig five(String x, {int sets = 5, bool heavy = false}) =>
          _ex(x, sets: sets, lo: 5, hi: 5, heavy: heavy, rest: 180);
      final r = [
        _r(id, 0, 'Workout A', [five(_squat, heavy: true), five(_bench), five(_row, heavy: true)], policy: lin),
        _r(id, 1, 'Workout B', [five(_squat, heavy: true), five(_ohp), five(_deadlift, sets: 1, heavy: true)],
            policy: lin),
      ];
      return ProgramBundle(
        Program(name: '5 × 5', templateId: id, minRestDays: 1, order: [for (final x in r) x.id]),
        r,
      );
  }
  return null;
}
