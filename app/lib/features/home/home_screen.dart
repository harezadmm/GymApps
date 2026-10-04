/// Tab Beranda — UI v3 (`design/UI-V3.md` §7.1).
///
/// Satu pertanyaan yang dijawab layar ini: **hari ini latihan apa?** Semua yang
/// lain hanya konteks — dan semuanya dihitung dari program dan riwayat yang
/// tersimpan, bukan angka contoh: pil status, tiga cincin minggu ini dengan
/// satu kalimat insight, kartu sesi berikutnya, strip minggu, dan tiga
/// gerakan dengan progres kekuatan terbesar.
library;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/gym_icons.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_history.dart';
import '../../core/strings_home.dart';
import '../../core/strings_v3.dart';
import '../../core/theme.dart';
import '../../core/weights.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/program.dart';
import '../../domain/progression.dart';
import '../../domain/session_plan.dart';
import '../../domain/stats.dart';
import '../../domain/units.dart';
import '../onboarding/program_flow.dart';
import '../session/exercise_history_sheet.dart';
import '../session/session_launcher.dart';
import '../stats/dashboard_screen.dart' show carried, weeklyBest;
import '../workout/routine_editor_screen.dart';
import 'home_cards.dart';
import 'home_insight.dart';

/// Ringkasan tujuh hari terakhir (dan tujuh hari sebelumnya), dihitung dari
/// riwayat.
class _Recent {
  _Recent(List<Workout> newestFirst, DateTime today) {
    final day = dateOnly(today);
    final weekAgo = isoDate(day.subtract(const Duration(days: 6)));
    final twoWeeksAgo = isoDate(day.subtract(const Duration(days: 13)));
    volume = 0;
    volumeBefore = 0;
    for (final w in newestFirst) {
      if (w.date.compareTo(weekAgo) >= 0) {
        volume += _volumeOf(w);
      } else if (w.date.compareTo(twoWeeksAgo) >= 0) {
        volumeBefore += _volumeOf(w);
      }
    }
    final last = lastTrainingDay(newestFirst);
    daysSince = last == null ? null : day.difference(last).inDays;
  }

  late double volume;
  late double volumeBefore;
  late int? daysSince;
}

/// Volume satu sesi (kg × rep) dari set kerja yang dicentang.
double _volumeOf(Workout w) {
  var v = 0.0;
  for (final e in w.entries) {
    for (final s in e.sets) {
      if (s.done && !s.isWarmup) v += s.weight * s.reps;
    }
  }
  return v;
}

/// Set kerja yang dicentang di satu sesi.
int _workingSetsOf(Workout w) {
  var n = 0;
  for (final e in w.entries) {
    n += e.sets.where((s) => s.done && !s.isWarmup).length;
  }
  return n;
}

/// Volume dalam satuan tampilan sebagai teks: di bawah 1000 ditulis utuh
/// ("960 kg"), di atasnya diringkas ("1.2 t"). Satu fungsi supaya sheet per
/// hari dan kartu lain menulis angka yang sama untuk sesi yang sama.
String _volumeLabel(BuildContext context, double shownVolume) => shownVolume >= 1000
    ? volumeText(shownVolume, context.unit)
    : '${formatDelta(shownVolume.roundToDouble())} ${context.unitLabel}';

/// Hari pertama minggu yang memuat [day], menurut [weekStartsOn] (1 = Senin).
DateTime weekStart(DateTime day, int weekStartsOn) {
  final d = dateOnly(day);
  final back = (d.weekday - weekStartsOn + 7) % 7;
  return d.subtract(Duration(days: back));
}

/// Set kerja yang direncanakan program dalam seminggu: rotasi = satu putaran
/// penuh, hari tetap = jumlah set rutinitas tiap hari latihannya.
int _plannedSets(Program program, List<Routine> routines) {
  final list = programRoutines(program, routines);
  if (list.isEmpty) return 0;
  if (program.mode == ProgramMode.weekday) {
    final days = [...program.days]..sort();
    var n = 0;
    for (var i = 0; i < days.length; i++) {
      n += list[i % list.length].setCount;
    }
    return n;
  }
  return list.fold(0, (a, r) => a + r.setCount);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.email, this.onOpenProfile, this.onOpenTab});

  /// Email akun, untuk inisial avatar di pojok header.
  final String? email;

  /// Avatar diketuk → halaman Profil.
  final VoidCallback? onOpenProfile;

  /// Pindah tab: 1 Riwayat · 2 Program · 3 Statistik. Tautan seksi dan sheet
  /// hari memakainya supaya angka yang dilihat di sini bisa ditelusuri.
  final ValueChanged<int>? onOpenTab;

  /// Tarik ke bawah (atau ketuk pil sinkron) = sinkron sekarang, lalu satu
  /// kalimat hasilnya. Tanpa server pun tarikannya tetap "berhasil" — yang
  /// dikatakan cuma bahwa tidak ada server, bukan error.
  Future<void> _refresh(BuildContext context) async {
    final store = WorkoutScope.read(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final t = context.t;
    await store.syncNow();
    final msg = !store.hasBackend
        ? t.noServer
        : switch (store.syncStatus) {
            SyncStatus.synced => t.syncedShort,
            SyncStatus.failed => t.syncFailed,
            SyncStatus.noSession => t.syncNoSession,
            SyncStatus.idle || SyncStatus.syncing => t.syncPending,
          };
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  /// "2 menit lalu" dari waktu sinkron terakhir; kosong kalau belum pernah.
  static String _ago(Strings t, DateTime? at) {
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return t.justNow;
    if (d.inHours < 1) return t.minutesAgo(d.inMinutes);
    if (d.inDays < 1) return t.hoursAgo(d.inHours);
    return t.daysAgoShort(d.inDays);
  }

  Future<void> _start(BuildContext context, Routine routine) async {
    if (routine.exercises.isNotEmpty) {
      await openRoutineSession(context, routine);
      return;
    }
    // Rutinitas kosong tidak bisa dimulai — buka editornya dulu.
    final store = context.workouts;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.emptyRoutineHint)));
    final result = await Navigator.of(context).push<RoutineEditorResult>(
      MaterialPageRoute(builder: (_) => RoutineEditorScreen(routine: routine)),
    );
    switch (result) {
      case RoutineSaved(:final routine):
        await store.saveRoutine(routine);
      case RoutineDeleted():
        await store.deleteRoutine(routine.id);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final now = DateTime.now();
    final recent = _Recent(store.workouts, now);
    final program = store.program;
    final next = store.nextSessionOn(now);
    final unit = context.unit;

    // Pembilang dan penyebut harus menghitung hal yang sama: sesi dari
    // program. Sesi bebas tetap tercatat di strip hari, tapi bukan bagian
    // "rencana minggu ini" — tanpa ini labelnya bisa berbunyi "4 dari 3".
    final programNames = program == null
        ? const <String>{}
        : {for (final r in programRoutines(program, store.routines)) r.name};
    final thisWeek = _thisWeek(store.workouts, now, store.settings.weekStartsOn);
    final weekDone = program == null ? thisWeek.length : thisWeek.where((w) => programNames.contains(w.routine)).length;
    // Rencana seminggu: hari tetap = jumlah hari latihannya; rotasi = satu
    // putaran penuh. Minimal satu supaya cincinnya tidak membagi dengan nol.
    final weekPlanned = program == null
        ? 0
        : (program.mode == ProgramMode.weekday ? program.days.length : program.order.length).clamp(1, 99);
    // Pembilang dan penyebut dari himpunan yang sama: sesi program minggu ini.
    // Sesi bebas tidak ada di rencana, jadi tidak boleh membuat "48/36".
    final setsDone = (program == null ? thisWeek : thisWeek.where((w) => programNames.contains(w.routine)))
        .fold(0, (a, w) => a + _workingSetsOf(w));
    final setsPlanned = program == null ? 0 : _plannedSets(program, store.routines);

    return RefreshIndicator(
      color: c.accent,
      backgroundColor: c.surface,
      onRefresh: () => _refresh(context),
      child: FutureBuilder<ExerciseCatalog>(
        future: ExerciseCatalog.load(),
        builder: (context, snap) {
          final catalog = snap.data;
          // Rencana sesi berikutnya dihitung sekali per build dan dipakai
          // insight maupun kartu — dulu dua kali, dengan historyIn tiga kali.
          final plans = next == null ? const <(ExerciseConfig, PlannedExercise)>[] : _plans(context, next.routine, unit);
          final insight = _insight(context, catalog, next, program, plans);
          return Stack(
            children: [
              // Dua wash radial di balik isi — hangat di kiri atas, violet di
              // kanan atas — supaya latar tidak sekadar abu rata.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.7, -1),
                        radius: 1.1,
                        colors: [c.washA, c.washA.withValues(alpha: 0)],
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.95, -0.95),
                          radius: 0.9,
                          colors: [c.washB, c.washB.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ListView(
                // Selalu bisa ditarik, walau isinya lebih pendek dari layar —
                // tanpa ini tarik-untuk-sinkron mati di HP yang layarnya tinggi.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _header(context, now),
                  const SizedBox(height: 18),
                  Reveal(child: _statusPills(context, program, next)),
                  const SizedBox(height: 20),
                  if (store.loaded && store.draft != null) ...[
                    Reveal(index: 1, scale: true, child: _ResumeCard(draft: store.draft!)),
                    const SizedBox(height: 20),
                  ],
                  if (!store.loaded)
                    const SizedBox(height: 200)
                  else
                    Reveal(
                      index: 1,
                      child: RingsCard(
                        sessionsDone: weekDone,
                        sessionsPlanned: weekPlanned,
                        setsDone: setsDone,
                        setsPlanned: setsPlanned,
                        volumeNow: recent.volume,
                        volumeBefore: recent.volumeBefore,
                        insightTitle: insight.title,
                        insightBody: insight.body,
                        insightIcon: next == null
                            ? GymIcons.flag
                            : next.early
                                ? GymIcons.moon
                                : GymIcons.arrowUpRight,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Reveal(
                    index: 2,
                    child: SectionTitle(
                      t.nextSessionTitle,
                      action: program == null || next == null ? null : t.pickOther,
                      onAction: program == null || next == null
                          ? null
                          : () async {
                              final picked = await pickOtherRoutine(context, program: program, current: next.routine);
                              if (picked != null && context.mounted) await _start(context, picked);
                            },
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!store.loaded)
                    const SizedBox.shrink()
                  else if (program == null || next == null)
                    Reveal(index: 3, child: _NoProgramCard(hasProgram: program != null))
                  else
                    Reveal(index: 3, child: _nextSession(context, catalog, next, program, unit, plans)),
                  const SizedBox(height: 20),
                  Reveal(
                    index: 4,
                    child: SectionTitle(
                      t.thisWeek,
                      // Dengan program, angkanya dibanding rencana ("2 dari 3
                      // sesi"); tanpa program cuma jumlahnya. Ketuk → Riwayat.
                      action: program == null ? t.sessionsCount(weekDone) : t.weekProgress(weekDone, weekPlanned),
                      onAction: onOpenTab == null ? null : () => onOpenTab!(1),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Reveal(
                    index: 5,
                    child: _WeekStrip(
                      history: store.workouts,
                      today: now,
                      program: program,
                      routines: store.routines,
                      weekStartsOn: store.settings.weekStartsOn,
                      onViewHistory: onOpenTab == null ? null : () => onOpenTab!(1),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Reveal(
                    index: 6,
                    child: SectionTitle(
                      t.strengthProgress,
                      action: t.seeAllShort,
                      onAction: onOpenTab == null ? null : () => onOpenTab!(3),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Reveal(index: 7, child: _strength(context, catalog, unit)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, DateTime now) {
    final c = context.gym;
    final t = context.t;
    return Row(
      children: [
        Expanded(
          child: Text(
            '${t.weekdayLong(now.weekday)}, ${now.day} ${t.monthLong(now.month)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.text),
          ),
        ),
        // Satu-satunya pintu ke Profil, jadi tampil selama ada tujuannya —
        // email yang belum terbaca cuma mengosongkan inisialnya.
        if (onOpenProfile != null)
          AvatarCircle(text: initialsOf(email ?? ''), tooltip: t.openProfile, onTap: onOpenProfile),
      ],
    );
  }

  Widget _statusPills(BuildContext context, Program? program, NextSession? next) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final String programSub;
    if (program == null) {
      programSub = '';
    } else if (program.mode == ProgramMode.weekday) {
      programSub = t.weekdayCount([for (final d in [...program.days]..sort()) t.weekdayShort(d)].join(', '));
    } else {
      programSub = t.rotationCount(programRoutines(program, store.routines).length);
    }
    final (syncTitle, syncSub, syncIcon, syncTone) = !store.hasBackend
        ? (t.syncNoServerPill, '', GymIcons.cloudOff, c.text3)
        : switch (store.syncStatus) {
            SyncStatus.synced => (t.syncedPill, _ago(t, store.lastSyncedAt), GymIcons.cloudCheck, c.doneInk),
            SyncStatus.syncing => (t.syncing, '', GymIcons.sync, c.accent),
            SyncStatus.failed => (t.syncNotYet, t.syncFailed, GymIcons.cloudOff, c.warn),
            SyncStatus.noSession => (t.syncNotYet, t.syncNoSession, GymIcons.cloudOff, c.warn),
            SyncStatus.idle => (t.syncNotYet, _ago(t, store.lastSyncedAt), GymIcons.cloud, c.text3),
          };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: StatusPill(
            icon: GymIcons.swap,
            tone: c.accent,
            title: program?.name ?? t.pickProgramPill,
            subtitle: programSub,
            onTap: program == null ? () => chooseProgram(context) : () => onOpenTab?.call(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: StatusPill(
            icon: syncIcon,
            tone: syncTone,
            title: syncTitle,
            subtitle: syncSub,
            spinning: store.hasBackend && store.syncStatus == SyncStatus.syncing,
            onTap: store.hasBackend ? () => _refresh(context) : null,
          ),
        ),
      ],
    );
  }

  /// Target tiap gerakan sesi berikutnya — fungsi yang sama dengan yang
  /// menyusun sesi, supaya angka di sini persis yang akan terbuka nanti.
  List<(ExerciseConfig cfgIn, PlannedExercise plan)> _plans(BuildContext context, Routine routine, WeightUnit unit) {
    final history = historyIn(context.workouts.chronological, unit);
    return [
      for (final cfg in routine.exercises)
        (configIn(cfg, unit), planExercise(configIn(cfg, unit), history, routineDefault: routine.policy, unit: unit.label)),
    ];
  }

  HomeInsight _insight(BuildContext context, ExerciseCatalog? catalog, NextSession? next, Program? program,
      List<(ExerciseConfig, PlannedExercise)> plans) {
    final t = context.t;
    final store = context.workouts;
    if (next == null) return homeInsight(t: t, next: null, weekdayMode: false, targets: const [], daysSince: null);
    final targets = [
      for (final (cfg, plan) in plans)
        (catalog?.nameOf(cfg.exerciseId) ?? '…', plan.prescription.kind),
    ];
    final last = lastTrainingDay([for (final w in store.workouts) if (w.routine == next.routine.name) w]);
    return homeInsight(
      t: t,
      next: next,
      weekdayMode: program?.mode == ProgramMode.weekday,
      targets: targets,
      daysSince: last == null ? null : dateOnly(DateTime.now()).difference(last).inDays,
    );
  }

  Widget _nextSession(BuildContext context, ExerciseCatalog? catalog, NextSession next, Program program, WeightUnit unit,
      List<(ExerciseConfig, PlannedExercise)> plans) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final routine = next.routine;
    final unitLabel = context.unitLabel;
    final last = lastTrainingDay([for (final w in store.workouts) if (w.routine == routine.name) w]);
    final sinceText = last == null ? t.notTrainedYet : t.sinceShort(dateOnly(DateTime.now()).difference(last).inDays);
    final tag = switch (next.daysAway) {
      0 => t.dueToday,
      1 => t.dueTomorrow,
      _ => t.weekdayShort(next.due.weekday),
    };
    const shown = 4;
    final rows = <NextRow>[];
    for (final (cfg, plan) in plans.take(shown)) {
      final work = plan.sets.firstWhere((s) => !s.isWarmup, orElse: () => const SetRow());
      final target = work.weight > 0
          ? '${formatWeight(work.weight)} $unitLabel × ${work.reps}'
          : '${plan.sets.where((s) => !s.isWarmup).length} × ${work.reps}';
      String? change;
      var tone = ChangeTone.up;
      switch (plan.prescription.kind) {
        case PrescriptionKind.up:
          if (work.weight > cfg.weight) {
            change = '+${formatDelta(double.parse((work.weight - cfg.weight).toStringAsFixed(2)))} $unitLabel';
          } else if (work.reps > cfg.reps) {
            change = '+${work.reps - cfg.reps} rep';
          }
        case PrescriptionKind.deload:
          change = t.deloadTag;
          tone = ChangeTone.down;
        case PrescriptionKind.first || PrescriptionKind.hold || PrescriptionKind.off:
          break;
      }
      rows.add(NextRow(name: catalog?.nameOf(cfg.exerciseId) ?? '…', target: target, change: change, tone: tone));
    }
    final dayName = t.weekdayLong(next.due.weekday);
    return NextSessionCard(
      routineName: routine.name,
      meta: '${t.routineOverview(routine.exercises.length, routine.setCount)} · $sinceText',
      tag: tag,
      rows: rows,
      hiddenCount: routine.exercises.length - rows.length,
      hue: c.hues.at(programRoutines(program, store.routines).indexWhere((r) => r.id == routine.id).clamp(0, 99)),
      note: next.early
          ? NoteBanner(
              text: program.mode == ProgramMode.weekday ? t.nextTrainingDay(dayName) : t.recoverUntil(dayName),
              icon: GymIcons.moon,
              tone: c.warn,
            )
          : null,
      onStart: () => _start(context, routine),
      onSkip: () async {
        final messenger = ScaffoldMessenger.of(context);
        final msg = t.skipped;
        await store.skipNext(DateTime.now());
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      },
    );
  }

  Widget _strength(BuildContext context, ExerciseCatalog? catalog, WeightUnit unit) {
    final t = context.t;
    final now = DateTime.now();
    final history = historyIn(context.workouts.workouts, unit);
    final unitLabel = context.unitLabel;
    final rows = <StrengthRow>[];
    for (final m in strengthByMovement(history, now, count: 3)) {
      final ex = catalog?.byId(m.exerciseId);
      final name = catalog?.nameOf(m.exerciseId) ?? '…';
      final equipment = ex == null ? null : _capitalise(t.catalogue(ex.equipment));
      final delta = double.parse(m.delta.toStringAsFixed(1));
      rows.add(StrengthRow(
        name: name,
        meta: [?equipment, 'e1RM ${formatDelta(double.parse(m.best.toStringAsFixed(1)))} $unitLabel'].join(' · '),
        values: carried(weeklyBest(history, m.exerciseId, now)),
        delta: delta > 0
            ? '+${formatDelta(delta)} $unitLabel'
            : delta < 0
                ? '${formatDelta(delta)} $unitLabel'
                : t.holdTag,
        tone: delta > 0
            ? ChangeTone.up
            : delta < 0
                ? ChangeTone.down
                : ChangeTone.neutral,
        onTap: () => showExerciseHistory(context, exerciseId: m.exerciseId, name: name),
      ));
    }
    return StrengthCard(rows: rows);
  }

  static String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Sesi yang tercatat sejak awal minggu ini (setelan "Minggu mulai").
  static List<Workout> _thisWeek(List<Workout> history, DateTime today, int weekStartsOn) {
    final from = isoDate(weekStart(today, weekStartsOn));
    return [for (final w in history) if (w.date.compareTo(from) >= 0) w];
  }
}

/// Sesi yang ditinggal di tengah jalan — aplikasi dimatikan, HP mati.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.draft});

  final Map<String, dynamic> draft;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    var logged = 0;
    for (final e in (draft['ex'] as List? ?? const [])) {
      for (final s in ((e as Map)['sets'] as List? ?? const [])) {
        final m = s as Map;
        if (m['done'] == true && m['phase'] != 'warmup') logged++;
      }
    }
    final minutes = (((draft['elapsed'] as num?)?.toInt() ?? 0) / 60).round();
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(GymIcons.play, size: 18, color: c.warn),
            const SizedBox(width: 8),
            Expanded(child: Text(t.resumeTitle, style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 6),
          Text(t.resumeDetail(draft['name'] as String? ?? '', logged, minutes),
              style: TextStyle(fontSize: 13.5, height: 1.35, color: c.text2)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GymButton(
                label: t.discardDraft,
                tone: GymButtonTone.neutral,
                height: 42,
                onPressed: () async {
                  final store = WorkoutScope.read(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: c.surface,
                      content: Text(t.discardDraftConfirm),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.cancel)),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(t.discardDraft, style: TextStyle(color: c.danger)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await store.clearDraft();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GymButton(label: t.resume, height: 42, onPressed: () => resumeDraftSession(context)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _NoProgramCard extends StatelessWidget {
  const _NoProgramCard({required this.hasProgram});

  final bool hasProgram;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.noProgramYet, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(t.noProgramHint, style: TextStyle(fontSize: 13, height: 1.4, color: c.text2)),
          const SizedBox(height: 16),
          GymButton(label: t.choosePlan, onPressed: () => chooseProgram(context)),
          const SizedBox(height: 10),
          GymButton(
            label: t.freestyle,
            icon: GymIcons.edit,
            tone: GymButtonTone.neutral,
            height: 44,
            onPressed: () => openFreestyleSession(context, t.freestyle),
          ),
        ],
      ),
    );
  }
}

/// Sheet "hari ini latihan apa?": semua rutinitas, urutan rotasi dulu.
/// null kalau ditutup tanpa memilih.
Future<Routine?> pickOtherRoutine(BuildContext context, {required Program program, required Routine current}) {
  final store = WorkoutScope.read(context);
  final inProgram = programRoutines(program, store.routines);
  final ids = {for (final r in inProgram) r.id};
  final others = [for (final r in store.routines) if (!ids.contains(r.id)) r];
  return showModalBottomSheet<Routine>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.gym.bg,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet)),
    ),
    builder: (sheet) {
      final c = sheet.gym;
      final t = sheet.t;
      Widget tile(Routine r, int hueIndex, {String? note}) {
        final isNext = r.id == current.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(GymRadius.tile),
              border: isNext ? Border.all(color: c.accent, width: 1.5) : null,
              boxShadow: [c.cardShadow],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(GymRadius.tile),
                onTap: () => Navigator.of(sheet).pop(r),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      HueTile(icon: GymIcons.dumbbell, hue: c.hues.at(hueIndex), iconSize: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(r.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(sheet).textTheme.titleMedium),
                              ),
                              if (isNext) ...[
                                const SizedBox(width: 8),
                                Pill(color: c.accentSoft, textColor: c.accent, child: Text(t.next)),
                              ],
                            ]),
                            const SizedBox(height: 2),
                            Text(
                              [t.routineOverview(r.exercises.length, r.setCount), ?note].join(' · '),
                              style: TextStyle(fontSize: 12.5, color: c.text2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(GymIcons.play, size: 20, color: isNext ? c.accent : c.text2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scroll) => SafeArea(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(t.otherSessionTitle, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(program.mode == ProgramMode.weekday ? t.otherSessionHintWeekday : t.otherSessionHint,
                  style: TextStyle(fontSize: 13, color: c.text2)),
              const SizedBox(height: 14),
              for (final (i, r) in inProgram.indexed) tile(r, i),
              for (final (i, r) in others.indexed) tile(r, inProgram.length + i, note: t.notInProgram),
            ],
          ),
        ),
      );
    },
  );
}

/// Kartu minggu ini: tujuh kolom hari. Tiap titik bisa diketuk: sheet kecil
/// berisi sesi hari itu (atau rencananya), dengan jalan ke tab Riwayat.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.history,
    required this.today,
    required this.program,
    this.routines = const [],
    this.weekStartsOn = 1,
    this.onViewHistory,
  });

  final List<Workout> history;
  final DateTime today;
  final Program? program;

  /// Untuk menamai rencana hari tetap ("Rencana: Push") — program hanya
  /// memegang id rutinitas.
  final List<Routine> routines;
  final int weekStartsOn;
  final VoidCallback? onViewHistory;

  /// Nama rutinitas yang dijadwalkan pada [weekday] di mode hari tetap;
  /// null di mode rotasi atau hari libur. Pemetaannya sama dengan
  /// [nextSession]: hari ke-i (urut) memegang rutinitas ke-i.
  String? _plannedName(int weekday) {
    final p = program;
    if (p == null || p.mode != ProgramMode.weekday || p.days.isEmpty) return null;
    final list = programRoutines(p, routines);
    if (list.isEmpty) return null;
    final days = [...p.days]..sort();
    final slot = days.indexOf(weekday);
    return slot < 0 ? null : list[slot % list.length].name;
  }

  Future<void> _showDay(BuildContext context, DateTime d) {
    final iso = isoDate(d);
    final sessions = [for (final w in history) if (w.date == iso) w];
    final planned = _plannedName(d.weekday);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.gym.bg,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet)),
      ),
      builder: (sheet) {
        final c = sheet.gym;
        final t = sheet.t;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${t.weekdayLong(d.weekday)} · ${d.day} ${t.monthShort(d.month)}',
                    style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (sessions.isEmpty)
                  Text(t.noSessionsThatDay, style: TextStyle(fontSize: 13.5, color: c.text2))
                else
                  for (final (i, w) in sessions.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Reveal(index: i, child: _DayRow(workout: w)),
                  ],
                if (planned != null) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(GymIcons.calendar, size: 15, color: c.accent),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(t.plannedRoutine(planned),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent)),
                    ),
                  ]),
                ],
                if (onViewHistory != null) ...[
                  const SizedBox(height: 16),
                  GymButton(
                    label: t.viewHistory,
                    icon: GymIcons.clock,
                    height: 46,
                    tone: GymButtonTone.neutral,
                    onPressed: () {
                      Navigator.of(sheet).pop();
                      onViewHistory!();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final day = dateOnly(today);
    final first = weekStart(day, weekStartsOn);
    final trained = {for (final w in history) w.date};
    final plannedDays = program?.mode == ProgramMode.weekday ? program!.days.toSet() : const <int>{};

    return GymCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Builder(builder: (context) {
                final d = first.add(Duration(days: i));
                final iso = isoDate(d);
                final done = trained.contains(iso);
                final isToday = d == day;
                final planned = plannedDays.contains(d.weekday) && !done;
                final Widget dot;
                if (done) {
                  // Hari yang sudah dilatih: titik kaca berwarna dengan centang.
                  dot = GlassSurface(
                    tone: GlassTone.tinted,
                    radius: 18,
                    width: 36,
                    height: 36,
                    shadow: false,
                    child: const Center(child: Icon(GymIcons.check, size: 16, color: Colors.white)),
                  );
                } else {
                  dot = AnimatedContainer(
                    duration: GymMotion.of(context, GymMotion.normal),
                    curve: GymMotion.curve,
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? c.accentSoft : c.surface2,
                      shape: BoxShape.circle,
                      border: isToday ? Border.all(color: c.accent, width: 1.5) : null,
                    ),
                    child: Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isToday ? c.accent : c.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  );
                }
                return Semantics(
                  button: true,
                  label: '${t.weekdayLong(d.weekday)} ${d.day}',
                  child: InkWell(
                    key: ValueKey('home-day-$iso'),
                    onTap: () => _showDay(context, d),
                    borderRadius: BorderRadius.circular(GymRadius.control),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t.weekdayShort(d.weekday).substring(0, 1),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.text2)),
                          const SizedBox(height: 6),
                          dot,
                          // Titik kecil untuk hari latihan yang direncanakan di
                          // mode hari tetap — "hari ini libur" terlihat tanpa teks.
                          SizedBox(
                            height: 8,
                            child: planned
                                ? Center(
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu sesi di sheet hari: nama rutinitas · set kerja · volume.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final sets = _workingSetsOf(workout);
    final volume = _volumeLabel(context, kgTo(_volumeOf(workout), context.unit));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(GymRadius.control)),
      child: Row(
        children: [
          HueTile(icon: GymIcons.dumbbell, hue: c.accent, size: 36, radius: GymRadius.small, iconSize: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workout.routine ?? t.freestyleSession,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('${t.setsSuffix(sets)} · $volume',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5, color: c.text2, fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dua huruf pertama dari email, untuk avatar. Bukan nama — aplikasi ini
/// tidak pernah menanyakannya.
String initialsOf(String email) {
  final local = email.split('@').first;
  final letters = local.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  return letters.isEmpty ? '?' : letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
}
