/// Ringkasan setelah sesi selesai — artboard `09 Finish Summary`.
///
/// Angka di sini dihitung dari set yang benar-benar tercatat, bukan dari
/// rencana: volume, jumlah set, rekor, dan target sesi berikutnya semuanya
/// turunan dari [SessionScreen] yang baru ditutup.
library;

import 'package:flutter/material.dart';

import '../../core/weights.dart';
import '../../domain/units.dart';

import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/gym_icons.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_assisted.dart';
import '../../core/strings_session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/assisted.dart';
import '../../domain/models.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/muscle_volume.dart';
import '../../domain/onerm.dart';
import '../../domain/progression.dart';
import '../../domain/routine_sync.dart';
import '../../domain/session_plan.dart';
import 'session_screen.dart';

class FinishScreen extends StatefulWidget {
  const FinishScreen({
    super.key,
    required this.routineName,
    required this.exercises,
    required this.history,
    required this.elapsed,
    required this.dateLabel,
    this.originalRoutine,
    this.diff,
    this.routineUpdated = false,
  });

  final String routineName;
  final List<SessionExercise> exercises;
  final List<Workout> history;
  final Duration elapsed;
  final String dateLabel;

  /// Rutinitas asal **sebelum** sesi ini menulisinya, bersama selisihnya.
  /// Keduanya diisi hanya kalau sesi menyimpang dari rutinitas (FR-B9);
  /// dengan rutinitas aslinya di tangan, "batalkan" tinggal menyimpan
  /// kembali — tidak perlu menebak apa yang tadi berubah.
  final Routine? originalRoutine;
  final RoutineDiff? diff;

  /// Susunan sesi sudah ditulis ke rutinitas oleh layar sesi (switch di lembar
  /// konfirmasi nyala). Kartu status di bawah menawarkan kebalikannya.
  final bool routineUpdated;

  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> {
  late final Future<ExerciseCatalog> _catalog = ExerciseCatalog.load();

  /// Volume per otot dari sesi ini saja — bukan seluruh riwayat. Ini ringkasan
  /// satu sesi, jadi petanya harus menjawab "tadi saya melatih apa".
  List<Workout> get _thisSession => [
    Workout(
      date: widget.dateLabel,
      // Nama rutinitas ikut, sama seperti yang tersimpan di riwayat: dari
      // sinilah sesi deload dikenali saat target berikutnya dihitung (FR-B10).
      routine: widget.routineName,
      entries: [
        for (final ex in widget.exercises)
          WorkoutEntry(exerciseId: ex.config.exerciseId, target: ex.config, sets: ex.sets),
      ],
    ),
  ];

  Iterable<SetRow> get _workingSets => widget.exercises.expand((e) => e.sets).where((s) => s.done && !s.isWarmup);

  double get _volume => _workingSets.fold(0.0, (a, s) => a + s.weight * s.reps);

  /// Rekor dibawa bersama nama gerakannya, bukan dicocokkan lewat indeks
  /// belakangan: begitu ada dua gerakan yang sama-sama memecahkan rekor,
  /// pencocokan lewat posisi akan menempelkan nama yang salah ke angka yang
  /// benar — kesalahan yang terlihat meyakinkan.
  ///
  /// Mesin assisted tidak punya e1RM (#232); rekornya adalah bantuan paling
  /// sedikit, dan [isLoadRecord] membandingkannya ke arah yang benar.
  List<_PersonalRecord> get _records {
    final out = <_PersonalRecord>[];
    for (final ex in widget.exercises) {
      final id = ex.config.exerciseId;
      final entry = WorkoutEntry(exerciseId: id, target: ex.config, sets: ex.sets);
      if (entryIsAssisted(entry, ExerciseCatalog.assistedById)) {
        final rec = isLoadRecord(widget.history, id, entry, isAssisted: ExerciseCatalog.assistedById);
        if (rec != null) out.add(_PersonalRecord(name: ex.name, help: true, now: rec.now, previous: rec.previous));
      } else {
        final rec = is1RMRecord(widget.history, id, entry, isAssisted: ExerciseCatalog.assistedById);
        if (rec != null) out.add(_PersonalRecord(name: ex.name, help: false, now: rec.now.est, previous: rec.previous));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final records = _records;
    final setsDone = _workingSets.length;
    final original = widget.originalRoutine;
    final diff = widget.diff;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // SingleChildScrollView, bukan ListView: ListView membuang kartu
            // yang tergulir keluar layar, dan kartu status rutinitas di bawah
            // lupa sudah "dibatalkan" begitu digulir lagi — plus semua Reveal
            // dan CountUp diputar ulang. Ringkasan ini pendek; tidak ada yang
            // perlu dibangun malas.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Kartu-kartu datang berurutan dari atas: ini layar yang
                    // dibuka sekali per sesi, dan urutan kedatangannya memandu
                    // mata dari "selesai" ke angka lalu ke target berikutnya.
                    Reveal(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SectionLabel(context.t.sessionComplete, color: c.doneInk),
                                const SizedBox(height: 4),
                                Text(widget.routineName, style: Theme.of(context).textTheme.headlineMedium),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(widget.dateLabel, style: TextStyle(fontSize: 12.5, color: c.text2)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Reveal(
                      index: 1,
                      child: Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              icon: GymIcons.clock,
                              value: _clock(widget.elapsed),
                              label: context.t.duration,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Metric(
                              icon: GymIcons.barbell,
                              count: _volume,
                              format: (v) => volumeText(v, context.unit),
                              label: context.t.volume,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Reveal(
                      index: 2,
                      child: Row(
                        children: [
                          Expanded(
                            child: _Metric(icon: Icons.done_all, count: setsDone.toDouble(), label: context.t.setsDone),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Metric(
                              icon: Icons.emoji_events_outlined,
                              count: records.length.toDouble(),
                              label: context.t.newPRs,
                              tone: records.isEmpty ? null : c.warn,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (records.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      // Rekor membesar sedikit saat datang — satu-satunya kartu
                      // yang boleh sedikit merayakan.
                      Reveal(index: 3, scale: true, child: _RecordsCard(records: records)),
                    ],
                    const SizedBox(height: 14),
                    Reveal(
                      index: 4,
                      child: GymCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionLabel(context.t.musclesWorked),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: c.bgNested,
                                borderRadius: BorderRadius.circular(GymRadius.card),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: FutureBuilder<ExerciseCatalog>(
                                future: _catalog,
                                builder: (context, snap) => MuscleMap(
                                  height: 210,
                                  share: snap.hasData ? muscleShare(volumeByMuscle(_thisSession, snap.data!)) : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<ExerciseCatalog>(
                              future: _catalog,
                              builder: (context, snap) {
                                if (!snap.hasData) return const SizedBox(height: 44);
                                final v = volumeByMuscle(_thisSession, snap.data!);
                                final total = v.values.fold(0.0, (a, b) => a + b);
                                if (total <= 0) {
                                  return Text(
                                    context.t.noWorkingSets,
                                    style: TextStyle(fontSize: 12.5, color: c.text2),
                                  );
                                }
                                // Empat otot teratas sesi ini, persentasenya dari
                                // total volume sesi — bukan dari maksimum, karena di
                                // sini pertanyaannya "porsinya berapa", bukan
                                // "seberapa dekat ke yang tertinggi".
                                final top = v.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                                return Row(
                                  children: [
                                    for (final e in top.take(4)) ...[
                                      Expanded(
                                        child: _SharePill(
                                          label: context.t.muscle(muscleGroupLabel[e.key]!),
                                          pct: '${(e.value / total * 100).round()}%',
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Target berikutnya dihitung dengan sesi ini ikut di riwayat.
                    // Tanpa sesi ini, "target berikutnya" hanya mengulang target
                    // yang baru saja dikerjakan.
                    Reveal(
                      index: 5,
                      child: _NextTargetsCard(
                        exercises: widget.exercises,
                        history: [...widget.history, ..._thisSession],
                        // Tanpa store (test yang memasang layar ini sendirian)
                        // tidak ada rutinitas yang dikecualikan.
                        routines: context.getInheritedWidgetOfExactType<WorkoutScope>()?.notifier?.routines ?? const [],
                      ),
                    ),
                    if (original != null && diff != null) ...[
                      const SizedBox(height: 14),
                      Reveal(
                        index: 6,
                        child: FutureBuilder<ExerciseCatalog>(
                          future: _catalog,
                          builder: (context, snap) => _RoutineSyncCard(
                            original: original,
                            diff: diff,
                            initiallySynced: widget.routineUpdated,
                            exercises: widget.exercises,
                            nameOf: (id) {
                              for (final ex in widget.exercises) {
                                if (ex.config.exerciseId == id) return ex.name;
                              }
                              return snap.data?.nameOf(id) ?? '…';
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              // GymButton sudah mengecil saat ditekan (PressScale di dalamnya).
              child: GymButton(label: context.t.done, onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// Kotak angka besar. Angka yang bisa dihitung ([count]) menghitung naik ke
/// nilainya; yang bukan angka ([value], mis. durasi `42:10`) ditulis apa
/// adanya — menghitung durasi dari nol terlihat seperti stopwatch, bukan
/// ringkasan.
class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, this.value, this.count, this.format, this.tone})
    : assert(value != null || count != null, 'butuh value atau count');

  final IconData icon;
  final String label;
  final String? value;
  final double? count;

  /// Pembentuk teks untuk [count]; null = bilangan bulat.
  final String Function(double)? format;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final style = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: tone ?? c.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return GymCard(
      radius: GymRadius.card,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: c.text2),
          const SizedBox(height: 12),
          if (count != null)
            CountUp(count!, style: style, format: format, maxLines: 1)
          else
            Text(value!, style: style, maxLines: 1),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: c.text2)),
        ],
      ),
    );
  }
}

/// Satu rekor pribadi yang baru pecah: e1RM untuk gerakan biasa, bantuan
/// paling sedikit ([help]) untuk mesin assisted (#232).
class _PersonalRecord {
  const _PersonalRecord({required this.name, required this.help, required this.now, required this.previous});

  final String name;
  final bool help;
  final double now;
  final double? previous;
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.records});

  final List<_PersonalRecord> records;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final unit = context.unitLabel;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: c.warn.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(GymRadius.card),
        border: Border.all(color: c.warn.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: 15, color: c.warn),
              const SizedBox(width: 8),
              SectionLabel(context.t.newPersonalRecords, color: c.warn),
            ],
          ),
          const SizedBox(height: 10),
          for (final (i, entry) in records.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(entry.name, style: Theme.of(context).textTheme.bodyLarge)),
                Text(
                  // Rekor pertama tidak punya pembanding — jangan tulis
                  // "(was 0)" yang terbaca seperti pernah mengangkat nol.
                  switch ((entry.help, entry.previous)) {
                    (true, final prev) => context.t.helpRecordLine(
                        formatDelta(entry.now), unit, prev == null ? null : formatDelta(prev)),
                    (false, null) => 'e1RM ${formatDelta(entry.now)} $unit',
                    (false, final prev) => 'e1RM ${formatDelta(entry.now)} $unit (was ${formatDelta(prev!)})',
                  },
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.text2),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SharePill extends StatelessWidget {
  const _SharePill({required this.label, required this.pct});

  final String label;
  final String pct;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: c.bgNested, borderRadius: BorderRadius.circular(GymRadius.small)),
      child: Column(
        children: [
          Text(
            pct,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.accent),
          ),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(fontSize: 10.5, color: c.text2)),
        ],
      ),
    );
  }
}

class _NextTargetsCard extends StatelessWidget {
  const _NextTargetsCard({required this.exercises, required this.history, required this.routines});

  final List<SessionExercise> exercises;
  final List<Workout> history;

  /// Untuk mengenali rutinitas deload (FR-B10) — lihat `progressionHistory`.
  final List<Routine> routines;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(context.t.nextSessionTargets),
          const SizedBox(height: 12),
          for (final (i, ex) in exercises.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            Builder(
              builder: (context) {
                // Fungsi yang sama dengan yang menyusun sesi berikutnya, supaya
                // angka di sini persis angka yang akan terbuka nanti.
                final plan = planExercise(ex.config, history, unit: context.unitLabel, routines: routines);
                final p = plan.prescription;
                final work = plan.sets.firstWhere((s) => !s.isWarmup, orElse: () => const SetRow());
                final weight = work.weight;
                final reps = work.reps;
                return Row(
                  children: [
                    Expanded(child: Text(ex.name, style: Theme.of(context).textTheme.bodyLarge)),
                    Text(
                      '${weightLabel(weight, bodyweight: ex.config.bodyweight)} ${context.unitLabel} × $reps',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text),
                    ),
                    const SizedBox(width: 8),
                    _DeltaTag(prescription: p, current: ex.config.weight),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Lencana "+2.5" / "hold" / "−5" di sebelah target berikutnya.
class _DeltaTag extends StatelessWidget {
  const _DeltaTag({required this.prescription, required this.current});

  final Prescription prescription;
  final double current;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final next = prescription.weight;
    // Tanda mengikuti selisihnya, bukan jenisnya: di mesin assisted (#232)
    // "naik" adalah bantuan yang berkurang, dan "+-2.5" bukan angka.
    String delta() => next! >= current ? '+${formatDelta(next - current)}' : formatDelta(next - current);
    final (text, tone) = switch (prescription.kind) {
      PrescriptionKind.up when next != null => (delta(), c.accent),
      PrescriptionKind.deload when next != null => (delta(), c.warn),
      PrescriptionKind.hold => ('hold', c.text2),
      _ => ('new', c.text2),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(GymRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tone),
      ),
    );
  }
}

enum _SyncState { synced, unsaved, reverted }

/// Status rutinitas setelah sesi yang menyimpang (FR-B9).
///
/// Bukan pertanyaan tiga pilihan seperti dulu — keputusannya sudah diambil di
/// lembar konfirmasi (dengan jawaban bawaan "simpan"). Kartu ini hanya
/// memberi tahu apa yang terjadi dan menawarkan kebalikannya: yang tersimpan
/// bisa dibatalkan, yang tidak tersimpan bisa disimpan.
class _RoutineSyncCard extends StatefulWidget {
  const _RoutineSyncCard({
    required this.original,
    required this.diff,
    required this.initiallySynced,
    required this.exercises,
    required this.nameOf,
  });

  final Routine original;
  final RoutineDiff diff;
  final bool initiallySynced;
  final List<SessionExercise> exercises;
  final String Function(String exerciseId) nameOf;

  @override
  State<_RoutineSyncCard> createState() => _RoutineSyncCardState();
}

class _RoutineSyncCardState extends State<_RoutineSyncCard> {
  late _SyncState _state = widget.initiallySynced ? _SyncState.synced : _SyncState.unsaved;
  bool _busy = false;

  Future<void> _apply(bool sync) async {
    if (_busy) return;
    setState(() => _busy = true);
    final store = WorkoutScope.read(context);
    // Gerakan baru dari sesi ini: konfigurasinya dalam satuan tampilan,
    // rutinitas menyimpan kg.
    final unit = store.settings.unit;
    final next = sync
        ? syncRoutineWithSession(widget.original, [
            for (final e in widget.exercises) (configToKg(e.config, unit), e.workCount),
          ])
        : widget.original;
    await store.saveRoutine(next);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _state = sync ? _SyncState.synced : _SyncState.reverted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final name = widget.original.name;
    final (title, hue) = switch (_state) {
      _SyncState.synced => (t.routineUpdatedTitle(name), c.accent),
      _SyncState.unsaved => (t.layoutNotSaved, c.text2),
      _SyncState.reverted => (t.routineRevertedTitle(name), c.text2),
    };

    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconDisc(GymIcons.sync, color: hue, size: 36, iconSize: 18),
              const SizedBox(width: 12),
              Expanded(
                child: FadeSwap(
                  alignment: Alignment.topLeft,
                  child: Column(
                    key: ValueKey(_state),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(
                        t.routineDiffSummary(widget.diff, widget.nameOf),
                        style: TextStyle(fontSize: 12.5, height: 1.35, color: c.text2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_state == _SyncState.synced)
            GymButton(
              label: t.revertUpper,
              height: 42,
              tone: GymButtonTone.neutral,
              onPressed: _busy ? null : () => _apply(false),
            )
          else
            GymButton(
              label: t.saveToRoutine,
              height: 42,
              tone: GymButtonTone.neutral,
              icon: GymIcons.sync,
              onPressed: _busy ? null : () => _apply(true),
            ),
        ],
      ),
    );
  }
}
