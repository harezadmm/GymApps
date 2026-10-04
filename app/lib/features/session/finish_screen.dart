/// Ringkasan setelah sesi selesai — UI v3 (`design/UI-V3.md` §7.4).
///
/// Angka di sini dihitung dari set yang benar-benar tercatat, bukan dari
/// rencana: volume, jumlah set, rekor, dan target sesi berikutnya semuanya
/// turunan dari [SessionScreen] yang baru ditutup.
library;

import 'package:flutter/material.dart';

import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/gym_icons.dart';
import '../../core/lottie_art.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_session.dart';
import '../../core/strings_v3.dart';
import '../../core/theme.dart';
import '../../core/weights.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/muscle_volume.dart';
import '../../domain/onerm.dart';
import '../../domain/progression.dart';
import '../../domain/routine_sync.dart';
import '../../domain/session_plan.dart';
import '../../domain/units.dart';
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
  /// konfirmasi nyala). Banner di bawah menawarkan kebalikannya.
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
      entries: [
        for (final ex in widget.exercises)
          WorkoutEntry(exerciseId: ex.config.exerciseId, target: ex.config, sets: ex.sets),
      ],
    ),
  ];

  Iterable<SetRow> get _workingSets => widget.exercises.expand((e) => e.sets).where((s) => s.done && !s.isWarmup);

  double get _volume => _workingSets.fold(0.0, (a, s) => a + s.weight * s.reps);

  /// Rekor dibawa bersama gerakannya, bukan dicocokkan lewat indeks
  /// belakangan: begitu ada dua gerakan yang sama-sama memecahkan rekor,
  /// pencocokan lewat posisi akan menempelkan nama yang salah ke angka yang
  /// benar — kesalahan yang terlihat meyakinkan.
  List<(SessionExercise, OneRmRecord)> get _records {
    final out = <(SessionExercise, OneRmRecord)>[];
    for (final ex in widget.exercises) {
      final entry = WorkoutEntry(exerciseId: ex.config.exerciseId, target: ex.config, sets: ex.sets);
      final rec = is1RMRecord(widget.history, ex.config.exerciseId, entry);
      if (rec != null) out.add((ex, rec));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final records = _records;
    final working = _workingSets.toList();
    final totalReps = working.fold(0, (a, s) => a + s.reps);
    final original = widget.originalRoutine;
    final diff = widget.diff;
    // Target berikutnya dihitung dengan sesi ini ikut di riwayat. Tanpa sesi
    // ini, "target berikutnya" hanya mengulang target yang baru saja dikerjakan.
    final history = [...widget.history, ..._thisSession];
    final plans = [
      for (final ex in widget.exercises) (ex, planExercise(ex.config, history, unit: context.unitLabel)),
    ];
    final targetsUp = plans.where((p) => p.$2.prescription.kind == PrescriptionKind.up).length;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // Wash violet tipis di kanan atas, seperti Beranda.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.9, -1),
                    radius: 0.9,
                    colors: [c.washB, c.washB.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // SingleChildScrollView, bukan ListView: ListView membuang kartu
                // yang tergulir keluar layar, dan banner rutinitas di bawah lupa
                // sudah "dibatalkan" begitu digulir lagi — plus semua Reveal
                // diputar ulang. Ringkasan ini pendek; tidak ada yang perlu
                // dibangun malas.
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Kartu-kartu datang berurutan dari atas: ini layar yang
                        // dibuka sekali per sesi, dan urutan kedatangannya memandu
                        // mata dari "selesai" ke angka lalu ke target berikutnya.
                        Reveal(child: _Hero(routineName: widget.routineName, dateLabel: widget.dateLabel)),
                        const SizedBox(height: 16),
                        Reveal(
                          index: 1,
                          child: _BigStats(
                            duration: _clock(widget.elapsed),
                            volume: volumeText(_volume, context.unit),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Reveal(
                          index: 2,
                          child: Row(
                            children: [
                              Expanded(child: _StatTile(icon: GymIcons.dumbbell, value: '${working.length}', label: t.ringSets)),
                              const SizedBox(width: 10),
                              Expanded(child: _StatTile(icon: GymIcons.swap, value: '$totalReps', label: t.totalReps)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Reveal(
                          index: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  icon: GymIcons.trophy,
                                  value: '${records.length}',
                                  label: t.newRecordsTitle,
                                  tone: records.isEmpty ? null : c.warm,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: _StatTile(icon: GymIcons.arrowUpRight, value: '$targetsUp', label: t.targetsUp)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Reveal(index: 4, child: _MusclesCard(session: _thisSession, catalog: _catalog)),
                        if (records.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          // Rekor membesar sedikit saat datang — satu-satunya kartu
                          // yang boleh sedikit merayakan.
                          Reveal(index: 5, scale: true, child: _RecordsCard(records: records)),
                        ],
                        const SizedBox(height: 16),
                        Reveal(index: 6, child: _NextTargetsCard(plans: plans)),
                        if (original != null && diff != null) ...[
                          const SizedBox(height: 16),
                          Reveal(
                            index: 7,
                            child: FutureBuilder<ExerciseCatalog>(
                              future: _catalog,
                              builder: (context, snap) => _RoutineSyncBanner(
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
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: GymButton(label: t.done, height: 54, onPressed: () => Navigator.of(context).pop()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// Popper di lingkaran aksen lembut, judul, lalu rutinitas · tanggal.
class _Hero extends StatelessWidget {
  const _Hero({required this.routineName, required this.dateLabel});

  final String routineName;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Column(
      children: [
        // Satu-satunya perayaan di layar ini: popper yang meletus sekali saat
        // ringkasan terbuka — jawaban atas "sesi tercatat", lalu diam.
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
          child: const GymLottieView(GymLottie.sessionDone, size: 44),
        ),
        const SizedBox(height: 10),
        Text(context.t.sessionComplete, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.text)),
        const SizedBox(height: 4),
        Text('$routineName · $dateLabel', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.text2)),
      ],
    );
  }
}

/// Durasi | Volume — dua angka 30/800 dengan pemisah tipis.
class _BigStats extends StatelessWidget {
  const _BigStats({required this.duration, required this.volume});

  final String duration;
  final String volume;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12.5, color: c.text2)),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          stat(duration, t.duration),
          Container(width: 1, height: 48, color: c.border),
          stat(volume, t.volume),
        ],
      ),
    );
  }
}

/// Ubin kecil kisi 2×2: tile ikon · angka 19/800 · label.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label, this.tone});

  final IconData icon;
  final String value;
  final String label;

  /// Warna ikon dan angka untuk ubin yang layak disorot (ada rekor).
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return GymCard(
      radius: GymRadius.tile,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(GymRadius.small)),
            child: Icon(icon, size: 17, color: tone ?? c.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: tone ?? c.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: c.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Otot yang dilatih sesi ini: peta di area nested dan empat porsi teratas.
class _MusclesCard extends StatelessWidget {
  const _MusclesCard({required this.session, required this.catalog});

  final List<Workout> session;
  final Future<ExerciseCatalog> catalog;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.musclesWorked, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: c.bgNested, borderRadius: BorderRadius.circular(GymRadius.tile)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: FutureBuilder<ExerciseCatalog>(
              future: catalog,
              builder: (context, snap) => MuscleMap(
                height: 200,
                share: snap.hasData ? muscleShare(volumeByMuscle(session, snap.data!)) : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<ExerciseCatalog>(
            future: catalog,
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox(height: 44);
              final v = volumeByMuscle(session, snap.data!);
              final total = v.values.fold(0.0, (a, b) => a + b);
              if (total <= 0) {
                return Text(t.noWorkingSets, style: TextStyle(fontSize: 12.5, color: c.text2));
              }
              // Empat otot teratas sesi ini, persentasenya dari total volume
              // sesi — di sini pertanyaannya "porsinya berapa".
              final top = v.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              return Row(
                children: [
                  for (final (i, e) in top.take(4).toList().indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _SharePill(
                        label: t.muscle(muscleGroupLabel[e.key]!),
                        pct: '${(e.value / total * 100).round()}%',
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
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
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(GymRadius.small)),
      child: Column(
        children: [
          Text(pct, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.accent)),
          const SizedBox(height: 1),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: c.text2)),
        ],
      ),
    );
  }
}

/// Rekor baru: trofi hangat, lalu baris nama · e1RM · set terberat.
class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.records});

  final List<(SessionExercise, OneRmRecord)> records;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final unit = context.unitLabel;
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Piala Lottie v2.3 yang berkilau sekali saat kartu ini datang —
              // kartunya hanya tampil kalau ada rekor, jadi geraknya selalu
              // menjawab sesuatu yang baru terjadi. Kanvasnya sudah punya ruang
              // kosong di sisi, jadi jaraknya 4, bukan 8.
              const GymLottieView(GymLottie.newRecord, size: 28),
              const SizedBox(width: 4),
              Text(t.newRecordsTitle, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          for (final (i, (ex, rec)) in records.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            Builder(builder: (context) {
              // Set terberat yang dicentang — angka yang orang ingat dari sesi.
              final done = ex.sets.where((s) => s.done && !s.isWarmup).toList();
              SetRow? best;
              for (final s in done) {
                if (best == null || s.weight > best.weight || (s.weight == best.weight && s.reps > best.reps)) best = s;
              }
              final sub = rec.previous == null
                  ? 'e1RM ${formatDelta(rec.now.est)} $unit'
                  : 'e1RM ${formatDelta(rec.now.est)} $unit · ${t.lang == AppLanguage.indonesian ? 'sebelumnya' : 'was'} ${formatDelta(rec.previous!)}';
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ex.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                        const SizedBox(height: 1),
                        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.text2)),
                      ],
                    ),
                  ),
                  if (best != null) ...[
                    const SizedBox(width: 8),
                    Text('${formatWeight(best.weight)} $unit × ${best.reps}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ],
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Target sesi berikutnya per gerakan, dengan pil perubahan.
class _NextTargetsCard extends StatelessWidget {
  const _NextTargetsCard({required this.plans});

  final List<(SessionExercise, PlannedExercise)> plans;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final unit = context.unitLabel;
    return GymCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.nextSessionTargets, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final (i, (ex, plan)) in plans.indexed)
            Builder(builder: (context) {
              final p = plan.prescription;
              final work = plan.sets.firstWhere((s) => !s.isWarmup, orElse: () => const SetRow());
              final (String change, ChangeTone tone) = switch (p.kind) {
                PrescriptionKind.up when work.weight > ex.config.weight => (
                    '+${formatDelta(double.parse((work.weight - ex.config.weight).toStringAsFixed(2)))} $unit',
                    ChangeTone.up
                  ),
                PrescriptionKind.up => ('+${(work.reps - ex.config.reps).clamp(1, 99)} rep', ChangeTone.up),
                PrescriptionKind.deload => (
                    '${formatDelta(double.parse((work.weight - ex.config.weight).toStringAsFixed(2)))} $unit',
                    ChangeTone.down
                  ),
                PrescriptionKind.hold => (t.holdTag, ChangeTone.neutral),
                _ => (t.newTag, ChangeTone.neutral),
              };
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: i < plans.length - 1 ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border))) : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(ex.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
                    ),
                    const SizedBox(width: 8),
                    ChangePill(change, tone: tone),
                    const SizedBox(width: 8),
                    Text(
                      '${weightLabel(work.weight, bodyweight: ex.config.bodyweight)} $unit × ${work.reps}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

enum _SyncState { synced, unsaved, reverted }

/// Banner status rutinitas setelah sesi yang menyimpang (FR-B9).
///
/// Bukan pertanyaan tiga pilihan seperti dulu — keputusannya sudah diambil di
/// lembar konfirmasi (dengan jawaban bawaan "simpan"). Banner ini hanya memberi
/// tahu apa yang terjadi dan menawarkan kebalikannya lewat satu tautan: yang
/// tersimpan bisa dibatalkan, yang tidak tersimpan bisa disimpan.
class _RoutineSyncBanner extends StatefulWidget {
  const _RoutineSyncBanner({
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
  State<_RoutineSyncBanner> createState() => _RoutineSyncBannerState();
}

class _RoutineSyncBannerState extends State<_RoutineSyncBanner> {
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
    final (title, link, icon, synced) = switch (_state) {
      _SyncState.synced => (t.routineUpdatedTitle(name), t.undoLink, GymIcons.check, true),
      _SyncState.unsaved => (t.layoutNotSaved, t.saveLink, GymIcons.sync, false),
      _SyncState.reverted => (t.routineRevertedTitle(name), t.saveAgainLink, GymIcons.sync, false),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(GymRadius.tile)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: synced ? c.accentFill : c.surface, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: synced ? Colors.white : c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FadeSwap(
              alignment: Alignment.centerLeft,
              child: Column(
                key: ValueKey(_state),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                  const SizedBox(height: 2),
                  Text(
                    t.routineDiffSummary(widget.diff, widget.nameOf),
                    style: TextStyle(fontSize: 12, height: 1.35, color: c.text2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: _busy ? null : () => _apply(!synced),
              borderRadius: BorderRadius.circular(GymRadius.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text(link, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
