/// Tab Home — artboard `04 Home`.
///
/// Satu pertanyaan yang dijawab layar ini: **hari ini latihan apa?** Semua yang
/// lain di bawahnya hanya konteks — dan semuanya dihitung dari program dan
/// riwayat yang tersimpan, bukan angka contoh.
///
/// Sejak v2.2 konteks itu bisa disentuh: blok statistik membuka tab yang
/// menjelaskannya, kotak hari membuka sesi hari itu, dan tarik ke bawah
/// menyinkronkan. Kartu-kartunya datang bertingkat saat tab terbuka — gerak
/// yang memberi tahu mata mana yang baru, bukan hiasan.
library;

import 'package:flutter/material.dart';
import '../../core/illustration.dart';
import '../../core/gym_icons.dart';
import '../library/library_screen.dart';
import '../stats/dashboard_screen.dart';
import '../../core/weights.dart';
import '../../domain/units.dart';

import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_home.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/onerm.dart';
import '../../domain/program.dart';
import '../../domain/session_plan.dart';
import '../onboarding/program_flow.dart';
import '../profile/gym_profiles.dart';
import '../session/session_launcher.dart';
import '../workout/routine_editor_screen.dart';

/// Ringkasan tujuh hari terakhir, dihitung dari riwayat.
class _Recent {
  _Recent(List<Workout> newestFirst, DateTime today) {
    final day = dateOnly(today);
    final weekAgo = isoDate(day.subtract(const Duration(days: 6)));
    final recent = newestFirst.where((w) => w.date.compareTo(weekAgo) >= 0).toList();
    final older = newestFirst.where((w) => w.date.compareTo(weekAgo) < 0).toList().reversed.toList();

    volume = 0;
    for (final w in recent) {
      volume += _volumeOf(w);
    }

    // Gerakan yang e1RM-nya minggu ini melewati semua sesi sebelumnya. Mesin
    // assisted tidak punya e1RM (#232), jadi tidak pernah masuk hitungan.
    final ids = {for (final w in recent) for (final e in w.entries) e.exerciseId};
    final all = newestFirst.reversed.toList();
    e1rmUp = ids.where((id) {
      final now = best1RM(all, id, isAssisted: ExerciseCatalog.assistedById);
      final before = best1RM(older, id, isAssisted: ExerciseCatalog.assistedById);
      return now != null && before != null && now.est > before.est;
    }).length;

    final last = lastTrainingDay(newestFirst);
    daysSince = last == null ? null : day.difference(last).inDays;
  }

  late double volume;
  late int e1rmUp;
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
/// ("960 kg"), di atasnya diringkas ("1.2 t"). Satu fungsi supaya blok
/// statistik dan sheet per hari menulis angka yang sama untuk sesi yang sama.
String _volumeLabel(BuildContext context, double shownVolume) => shownVolume >= 1000
    ? volumeText(shownVolume, context.unit)
    : '${formatDelta(shownVolume.roundToDouble())} ${context.unitLabel}';

/// Lebar mulai dari mana tata letaknya berubah: kisi jalan pintas jadi satu
/// baris empat kolom. Sama dengan ambang "phone width" di `main.dart`.
const _wideBreakpoint = 600.0;

/// Kolom statistik selebar ini baru muat teks "ketuk untuk statistik" tanpa
/// terpotong; di bawahnya, chevron di blok yang jadi petunjuknya.
// Blok statistik punya padding 14 di kiri-kanan, dan "Ketuk untuk statistik"
// selebar ±125 dp di Inter 11. Di bawah ini hint terpotong jadi "Ketuk untuk
// stati…", yang lebih buruk daripada tidak ada hint.
const _hintMinColumn = 165.0;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.email, this.onOpenProfile, this.onOpenTab});

  /// Email akun, untuk inisial avatar di pojok header (seperti referensi).
  final String? email;

  /// Avatar diketuk → tab Profil.
  final VoidCallback? onOpenProfile;

  /// Pindah tab: 0 Workout · 1 Home · 2 Stats · 3 History · 4 Profile.
  /// Blok statistik dan sheet hari memakainya supaya angka yang dilihat di
  /// sini bisa langsung ditelusuri, bukan cuma dibaca.
  final ValueChanged<int>? onOpenTab;

  /// Tarik ke bawah = sinkron sekarang, lalu satu kalimat hasilnya. Tanpa
  /// server pun tarikannya tetap "berhasil" — yang dikatakan cuma bahwa
  /// tidak ada server, bukan error.
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

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final now = DateTime.now();
    final recent = _Recent(store.workouts, now);
    final hasProgram = store.program != null;
    final program = store.program;
    final next = store.nextSessionOn(now);

    // Kisi 2×2 seperti "My Fitness Profile / My Nutrition Goals": jalan
    // pintas ke hal yang dulu tersembunyi di dalam kartu atau tab lain.
    final tiles = <Widget>[
      _QuickTile(
        label: t.otherSession,
        icon: GymIcons.dataTransfer,
        hue: c.hues.cyan,
        onTap: !hasProgram || next == null
            ? null
            : () async {
                final picked = await pickOtherRoutine(context, program: store.program!, current: next.routine);
                if (picked != null && context.mounted) await openRoutineSession(context, picked);
              },
      ),
      _QuickTile(
        label: t.freestyle,
        icon: GymIcons.edit,
        hue: c.hues.pink,
        onTap: () => openFreestyleSession(context, t.freestyle),
      ),
      _QuickTile(
        label: t.exerciseLibrary,
        icon: GymIcons.dumbbell,
        hue: c.hues.violet,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen())),
      ),
      _QuickTile(
        label: t.dashboard,
        icon: GymIcons.chart,
        hue: c.hues.orange,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardScreen())),
      ),
    ];

    // Pembilang dan penyebut harus menghitung hal yang sama: sesi dari
    // program. Sesi bebas tetap tercatat di strip hari, tapi bukan bagian
    // "rencana minggu ini" — tanpa ini labelnya bisa berbunyi "4 dari 3".
    final programNames = program == null
        ? const <String>{}
        : {for (final r in programRoutines(program, store.routines)) r.name};
    final weekDone = program == null
        ? _thisWeek(store.workouts, now, store.settings.weekStartsOn)
        : _thisWeek([for (final w in store.workouts) if (programNames.contains(w.routine)) w], now,
            store.settings.weekStartsOn);
    // Rencana seminggu: hari tetap = jumlah hari latihannya; rotasi = satu
    // putaran penuh. Minimal satu supaya bilahnya tidak membagi dengan nol.
    final weekPlanned = program == null
        ? 0
        : (program.mode == ProgramMode.weekday ? program.days.length : program.order.length).clamp(1, 99);

    final shownVolume = kgTo(recent.volume, context.unit);

    return RefreshIndicator(
      color: c.accent,
      backgroundColor: c.surface,
      onRefresh: () => _refresh(context),
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= _wideBreakpoint;
        // Lebar satu blok statistik: lebar layar dikurangi padding tepi dan
        // dua celah, dibagi tiga.
        final statColumn = (box.maxWidth - 32 - 20) / 3;
        final showHint = statColumn >= _hintMinColumn;
        final statHeight = showHint ? 148.0 : 138.0;

        return ListView(
          // Selalu bisa ditarik, walau isinya lebih pendek dari layar —
          // tanpa ini tarik-untuk-sinkron mati di HP yang layarnya tinggi.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ScreenHeader(
              subtitle: '${t.weekdayLong(now.weekday)} · ${now.day} ${t.monthShort(now.month)}',
              title: t.nextUp,
              actions: [
                // Gym aktif (FR-C3), hanya kalau ada yang perlu dibedakan:
                // akun satu gym tidak melihat chip ini sama sekali.
                if (store.settings.gyms.length > 1) GymChip(onTap: () => pickGym(context)),
                if (email != null)
                  AvatarCircle(text: initialsOf(email!), tooltip: t.openProfile, onTap: onOpenProfile),
              ],
            ),
            if (store.loaded && store.draft != null) ...[
              Reveal(scale: true, child: _ResumeCard(draft: store.draft!)),
              const SizedBox(height: 12),
            ],
            if (!store.loaded)
              const SizedBox(height: 200)
            else if (program == null || next == null)
              Reveal(child: _NoProgramCard(hasProgram: hasProgram))
            else
              Reveal(child: _NextSessionCard(next: next, program: program)),
            const SizedBox(height: 18),
            if (wide)
              // Layar lebar: keempat jalan pintas muat satu baris, dan dua
              // baris ubin gemuk di tablet hanya membuang tinggi.
              Row(children: [
                for (final (i, tile) in tiles.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: Reveal(index: i + 1, child: tile)),
                ],
              ])
            else ...[
              Row(children: [
                Expanded(child: Reveal(index: 1, child: tiles[0])),
                const SizedBox(width: 10),
                Expanded(child: Reveal(index: 2, child: tiles[1])),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Reveal(index: 3, child: tiles[2])),
                const SizedBox(width: 10),
                Expanded(child: Reveal(index: 4, child: tiles[3])),
              ]),
            ],
            const SizedBox(height: 22),
            Reveal(
              index: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(t.thisWeek, style: Theme.of(context).textTheme.titleLarge)),
                      // Dengan program, angkanya dibanding rencana ("2 dari 3
                      // sesi"); tanpa program cuma jumlahnya. Satu angka di
                      // kanan judul, bukan dua yang menyebut hal yang sama.
                      Text(
                        program == null ? t.sessionsCount(weekDone) : t.weekProgress(weekDone, weekPlanned),
                        style: TextStyle(
                            fontSize: 12.5, color: c.text2, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                  if (program != null) ...[
                    const SizedBox(height: 10),
                    _WeekBar(done: weekDone, planned: weekPlanned),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _WeekStrip(
              history: store.workouts,
              today: now,
              program: program,
              routines: store.routines,
              weekStartsOn: store.settings.weekStartsOn,
              onViewHistory: onOpenTab == null ? null : () => onOpenTab!(3),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Reveal(
                    index: 6,
                    child: StatBlock(
                      height: statHeight,
                      label: t.volume7d,
                      icon: GymIcons.scale,
                      color: c.hues.orange,
                      hint: showHint ? t.tapForStats : null,
                      value: _volumeLabel(context, shownVolume),
                      valueWidget: CountUp(
                        shownVolume,
                        delay: GymMotion.stagger * 6,
                        style: StatBlock.valueStyle(context),
                        format: (v) => _volumeLabel(context, v),
                      ),
                      onTap: onOpenTab == null ? null : () => onOpenTab!(2),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Reveal(
                    index: 7,
                    child: StatBlock(
                      height: statHeight,
                      label: t.e1rmUp,
                      icon: GymIcons.chart,
                      color: c.hues.violet,
                      hint: showHint ? t.tapForStats : null,
                      value: recent.e1rmUp > 0 ? '+${recent.e1rmUp}' : '0',
                      valueWidget: CountUp(
                        recent.e1rmUp.toDouble(),
                        delay: GymMotion.stagger * 7,
                        prefix: recent.e1rmUp > 0 ? '+' : '',
                        style: StatBlock.valueStyle(context),
                      ),
                      onTap: onOpenTab == null ? null : () => onOpenTab!(2),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Reveal(
                    index: 8,
                    child: StatBlock(
                      height: statHeight,
                      label: t.sinceLast,
                      icon: GymIcons.clock,
                      color: c.hues.cyan,
                      hint: showHint ? t.tapForHistory : null,
                      value: recent.daysSince == null ? '—' : t.daysShort(recent.daysSince!),
                      onTap: onOpenTab == null ? null : () => onOpenTab!(3),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  /// Sesi yang tercatat sejak awal minggu ini (setelan "Minggu mulai").
  static int _thisWeek(List<Workout> history, DateTime today, int weekStartsOn) {
    final from = isoDate(weekStart(today, weekStartsOn));
    return history.where((w) => w.date.compareTo(from) >= 0).length;
  }
}

/// Hari pertama minggu yang memuat [day], menurut [weekStartsOn] (1 = Senin).
DateTime weekStart(DateTime day, int weekStartsOn) {
  final d = dateOnly(day);
  final back = (d.weekday - weekStartsOn + 7) % 7;
  return d.subtract(Duration(days: back));
}

/// Bilah tipis "sekian dari sekian sesi minggu ini". Isinya bergerak ke
/// posisinya saat pertama tampil dan saat sesi baru tercatat — itulah momen
/// angkanya berubah, dan gerak menandai perubahan itu.
class _WeekBar extends StatelessWidget {
  const _WeekBar({required this.done, required this.planned});

  final int done;
  final int planned;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final frac = planned <= 0 ? 0.0 : (done / planned).clamp(0.0, 1.0);
    return Semantics(
      label: context.t.weekProgress(done, planned),
      child: Container(
        height: 6,
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(GymRadius.pill)),
        child: AnimatedValue(
          value: frac,
          // Sejalan dengan Reveal judul "Minggu ini" (indeks 5).
          delay: GymMotion.stagger * 5,
          builder: (context, v) => FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: c.accentFill, borderRadius: BorderRadius.circular(GymRadius.pill)),
            ),
          ),
        ),
      ),
    );
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
      radius: GymRadius.large,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(GymIcons.play, size: 18, color: c.warn),
            const SizedBox(width: 8),
            Expanded(child: SectionLabel(t.resumeTitle)),
          ]),
          const SizedBox(height: 8),
          Text(t.resumeDetail(draft['name'] as String? ?? '', logged, minutes),
              style: TextStyle(fontSize: 13.5, color: c.text)),
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
      radius: GymRadius.hero,
      padding: const EdgeInsets.all(18),
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

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({required this.next, required this.program});

  final NextSession next;
  final Program program;

  Future<void> _start(BuildContext context, [Routine? pick]) async {
    final routine = pick ?? next.routine;
    if (routine.exercises.isNotEmpty) {
      await openRoutineSession(context, routine);
      return;
    }
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
    final routine = next.routine;
    final history = store.chronological;

    final dueLabel = switch (next.daysAway) {
      0 => t.dueToday,
      1 => t.dueTomorrow,
      _ => t.dueOn(t.weekdayShort(next.due.weekday).toUpperCase()),
    };
    final dayName = t.weekdayLong(next.due.weekday);

    // Kapan rutinitas ini terakhir dilatih — dicocokkan lewat nama, karena
    // itulah yang tersimpan di setiap sesi.
    final lastOfRoutine = lastTrainingDay([for (final w in store.workouts) if (w.routine == routine.name) w]);
    final sinceText = lastOfRoutine == null
        ? t.notTrainedYet
        : t.lastTrained(dateOnly(DateTime.now()).difference(lastOfRoutine).inDays);

    const shown = 3;
    final preview = routine.exercises.take(shown).toList();
    final hidden = routine.exercises.length - preview.length;

    return GymCard(
      radius: GymRadius.hero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tata letak kartu "Body yoga" di referensi: teks dan angka-angka
          // kecil di kiri, figur yang dipotong tepi kartu di kanan.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Pill(
                        color: next.early ? c.surface2 : c.accentSoft,
                        textColor: next.early ? c.text2 : c.accent,
                        child: Text(dueLabel, style: const TextStyle(fontSize: 10, letterSpacing: 0.8)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text(routine.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 4),
                    Text(
                      program.mode == ProgramMode.weekday ? t.weekdayOf(program.name) : t.rotationOf(program.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.text2),
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final parts = t.routineOverview(routine.exercises.length, routine.setCount).split(' · ');
                      return Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _MiniStat(icon: GymIcons.dumbbell, text: parts.first, hue: c.hues.orange),
                          if (parts.length > 1) _MiniStat(icon: GymIcons.menu, text: parts[1], hue: c.hues.pink),
                          _MiniStat(icon: GymIcons.clock, text: sinceText, hue: c.hues.cyan),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const _HeroFigure(),
            ],
          ),
          if (next.early) ...[
            const SizedBox(height: 10),
            NoteBanner(
              text: program.mode == ProgramMode.weekday ? t.nextTrainingDay(dayName) : t.recoverUntil(dayName),
              icon: Icons.bedtime_outlined,
              tone: c.warn,
            ),
          ],
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 14),
            FutureBuilder<ExerciseCatalog>(
              future: ExerciseCatalog.load(),
              builder: (context, snap) {
                final catalog = snap.data;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.bgNested,
                    borderRadius: BorderRadius.circular(GymRadius.control),
                  ),
                  child: Column(
                    children: [
                      for (final cfg in preview)
                        Builder(builder: (context) {
                          // Target yang sama persis dengan yang akan terbuka
                          // di layar sesi — dihitung dengan fungsi yang sama.
                          final unit = context.unit;
                          // Arah beban mesin assisted (#232) diresolusi seperti
                          // saat sesi dibuka; sebelum katalog termuat namanya
                          // pun masih "…", jadi angkanya boleh menyusul.
                          final shownCfg = configIn(cfg, unit);
                          // Memori beban gym aktif (FR-C4) — gym yang
                          // terpilih lebih dulu di pemilih saat sesi dibuka.
                          final plan = planExercise(catalog?.withAssisted(shownCfg) ?? shownCfg, historyIn(history, unit),
                              routineDefault: routine.policy,
                              unit: unit.label,
                              routines: store.routines,
                              gymId: store.settings.activeGymId);
                          final work = plan.sets.firstWhere((s) => !s.isWarmup, orElse: () => const SetRow());
                          final target = work.weight > 0
                              ? '${formatWeight(work.weight)} ${context.unitLabel} × ${work.reps}'
                              : '${plan.sets.where((s) => !s.isWarmup).length} × ${work.reps}';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(catalog?.nameOf(cfg.exerciseId) ?? '…',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyLarge),
                                ),
                                const SizedBox(width: 8),
                                Text(target,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: c.text2,
                                        fontFeatures: const [FontFeature.tabularFigures()])),
                              ],
                            ),
                          );
                        }),
                      if (hidden > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(t.moreItems(hidden), style: TextStyle(fontSize: 12, color: c.text3)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          // "Pilih sesi lain" dan "Bebas" ada di kisi aksi cepat di bawah
          // kartu; di sini tinggal mulai dan lewati, seperti tombol "Play"
          // tunggal di kartu referensi. GymButton utama sudah mengecil saat
          // ditekan dan bergetar (GymHaptics.confirm) — tidak perlu dibungkus
          // lagi.
          Row(
            children: [
              Expanded(
                flex: 3,
                child: GymButton(label: t.startSession, icon: GymIcons.play, onPressed: () => _start(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GymButton(
                  label: t.skip,
                  icon: Icons.skip_next_rounded,
                  tone: GymButtonTone.neutral,
                  shape: GymButtonShape.pill,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final msg = t.skipped;
                    await store.skipNext(DateTime.now());
                    messenger.showSnackBar(SnackBar(content: Text(msg)));
                  },
                ),
              ),
            ],
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
    backgroundColor: context.gym.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet)),
    ),
    builder: (sheet) {
      final c = sheet.gym;
      final t = sheet.t;
      Widget tile(Routine r, {String? note}) {
        final isNext = r.id == current.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isNext ? c.accentSoft : c.bgNested,
            borderRadius: BorderRadius.circular(GymRadius.control),
            child: InkWell(
              borderRadius: BorderRadius.circular(GymRadius.control),
              onTap: () => Navigator.of(sheet).pop(r),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(sheet).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            [t.routineOverview(r.exercises.length, r.setCount), ?note].join(' · '),
                            style: TextStyle(fontSize: 12.5, color: c.text2),
                          ),
                        ],
                      ),
                    ),
                    if (isNext)
                      Pill(
                        color: c.accentFill,
                        textColor: c.accentInk,
                        child: Text(t.upNext, style: const TextStyle(fontSize: 10, letterSpacing: 0.8)),
                      )
                    else
                      Icon(Icons.play_arrow, color: c.text2),
                  ],
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              SectionLabel(t.otherSessionTitle),
              const SizedBox(height: 4),
              Text(program.mode == ProgramMode.weekday ? t.otherSessionHintWeekday : t.otherSessionHint,
                  style: TextStyle(fontSize: 13, color: c.text2)),
              const SizedBox(height: 14),
              for (final r in inProgram) tile(r),
              for (final r in others) tile(r, note: t.notInProgram),
            ],
          ),
        ),
      );
    },
  );
}

/// Satu angka kecil berikon di kartu hero — "280 Burn" di referensi.
class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.text, required this.hue});

  final IconData icon;
  final String text;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: hue),
        const SizedBox(width: 6),
        // "belum pernah dilatih" di kolom sempit sebelah figur: potong, jangan
        // meluber.
        Flexible(
          child: Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.text)),
        ),
      ],
    );
  }
}

/// Figur di sisi kanan kartu hero: ilustrasi di atas lingkaran aksen,
/// dipotong tepi kartu seperti figur "Body yoga" di referensi.
class _HeroFigure extends StatelessWidget {
  const _HeroFigure();

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return SizedBox(
      width: 124,
      height: 160,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -30,
              top: 14,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(color: c.tint(c.accent), shape: BoxShape.circle),
              ),
            ),
            const Positioned(
              right: 0,
              bottom: 2,
              child: GymIllustration(GymArt.heroLift, height: 150),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tujuh kotak hari minggu ini. Tiap kotak bisa diketuk: sheet kecil berisi
/// sesi hari itu (atau rencananya), dengan jalan ke tab Riwayat.
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
      backgroundColor: context.gym.surface,
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel('${t.weekdayLong(d.weekday)} · ${d.day} ${t.monthShort(d.month)}'),
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
    final day = dateOnly(today);
    final monday = weekStart(day, weekStartsOn);
    final trained = {for (final w in history) w.date};
    final planned = program?.mode == ProgramMode.weekday ? program!.days.toSet() : const <int>{};

    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Builder(builder: (context) {
            final d = monday.add(Duration(days: i));
            final iso = isoDate(d);
            final done = trained.contains(iso);
            final isToday = d == day;
            final plannedDay = planned.contains(d.weekday) && !done;
            // Warna dan bingkai lewat AnimatedContainer: begitu sesi hari ini
            // tersimpan, kotaknya berganti warna dengan lembut, tidak
            // melompat — itulah perubahan keadaan yang layak digerakkan.
            final cell = AnimatedContainer(
              key: ValueKey('home-day-$iso'),
              duration: GymMotion.of(context, GymMotion.normal),
              curve: GymMotion.curve,
              height: 62,
              decoration: BoxDecoration(
                color: done ? c.accentFill : c.surface,
                borderRadius: BorderRadius.circular(GymRadius.control),
                border: Border.all(
                  color: isToday && !done ? c.accent : Colors.transparent,
                  width: 1.5,
                ),
              ),
              // Material transparan di *dalam* kotak berwarna: riaknya
              // tergambar di atas warna kotak, bukan tertutup olehnya.
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => _showDay(context, d),
                  borderRadius: BorderRadius.circular(GymRadius.control),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.t.weekdayShort(d.weekday).substring(0, 1),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: done ? c.accentInk : c.text2),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: done ? c.accentInk : c.text,
                            fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                      // Titik kecil untuk hari latihan yang direncanakan di mode
                      // hari tetap — supaya "hari ini libur" terlihat tanpa teks.
                      if (plannedDay)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
              ),
            );
            // Hari yang sudah dilatih "muncul" membesar sedikit — hari
            // kosong cukup ada; yang terisi yang layak diperkenalkan.
            return Expanded(
              child: PressScale(
                scale: 0.94,
                // Selalu dibungkus Reveal supaya pohonnya tetap sama saat
                // hari berubah jadi "selesai" (sinkron menarik sesi baru):
                // AnimatedContainer yang sama lalu menganimasikan warnanya,
                // bukan kotak baru yang lenyap lalu muncul lagi.
                child: Reveal(
                  index: done ? i : 0,
                  delay: done ? null : Duration.zero,
                  // Tetap true: mengubahnya menyisipkan ScaleTransition
                  // dan membangun ulang kotaknya dari nol.
                  scale: true,
                  child: cell,
                ),
              ),
            );
          }),
        ],
      ],
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
      decoration: BoxDecoration(color: c.bgNested, borderRadius: BorderRadius.circular(GymRadius.control)),
      child: Row(
        children: [
          IconDisc(GymIcons.dumbbell, size: 36, iconSize: 18),
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

/// Ubin jalan pintas — "My Fitness Profile" di referensi: label di kiri,
/// cakram ikon berwarna di kanan.
class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.label, required this.icon, required this.hue, this.onTap});

  final String label;
  final IconData icon;
  final Color hue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return PressScale(
      enabled: onTap != null,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GymRadius.card),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, height: 1.2, color: onTap == null ? c.text3 : c.text)),
                ),
                const SizedBox(width: 8),
                Opacity(opacity: onTap == null ? 0.45 : 1, child: IconDisc(icon, color: hue, size: 42, iconSize: 21)),
              ],
            ),
          ),
        ),
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
