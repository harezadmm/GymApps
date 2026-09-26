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
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/muscle_volume.dart';
import '../../domain/onerm.dart';
import '../../domain/progression.dart';
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
    this.addedSetTo,
    this.routineId,
    this.drifted = false,
  });

  /// Susunan sesi berbeda dari rutinitasnya — memunculkan pertanyaan
  /// "perbarui rutinitas?" meski tidak ada set yang ditambah.
  final bool drifted;

  final String routineName;

  /// Rutinitas yang bisa diperbarui dari sesi ini. Diisi hanya kalau sesinya
  /// menyimpang dari rutinitas itu (FR-B9).
  final String? routineId;
  final List<SessionExercise> exercises;
  final List<Workout> history;
  final Duration elapsed;
  final String dateLabel;

  /// Nama gerakan yang setnya ditambah di tengah sesi, kalau ada — memicu
  /// pertanyaan "perbarui rutinitasnya?" di bawah (FR-D10).
  final String? addedSetTo;

  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> {
  late final Future<ExerciseCatalog> _catalog = ExerciseCatalog.load();

  /// Volume per otot dari sesi ini saja — bukan seluruh riwayat. Ini ringkasan
  /// satu sesi, jadi petanya harus menjawab "tadi saya melatih apa".
  List<Workout> get _thisSession => [
        Workout(date: widget.dateLabel, entries: [
          for (final ex in widget.exercises)
            WorkoutEntry(exerciseId: ex.config.exerciseId, target: ex.config, sets: ex.sets),
        ]),
      ];

  /// null = belum dijawab. Pertanyaannya tidak boleh punya jawaban default:
  /// menebak "update all" akan menulis ulang rutinitas diam-diam.
  String? _routineAnswer;

  /// Rutinitas persis seperti sebelum ringkasan ini dibuka. Jawaban bisa
  /// diganti — "Update all" lalu "Keep" harus mengembalikan yang asli, bukan
  /// menumpuk perubahan di atas perubahan.
  Routine? _original;

  @override
  void initState() {
    super.initState();
    final id = widget.routineId;
    if (id != null) {
      // Dibaca setelah frame pertama: store datang dari InheritedWidget, dan
      // context belum boleh dipakai untuk itu di initState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _original = WorkoutScope.read(context).routineById(id);
      });
    }
  }

  /// Terapkan jawaban ke rutinitas (FR-B9).
  ///
  /// * `Sets only` — jumlah set tiap gerakan disamakan dengan sesi ini.
  /// * `Update all` — susunan gerakan ikut sesi ini: yang ditambah masuk,
  ///   yang dibuang keluar, urutannya mengikuti.
  /// * `Keep` — rutinitas kembali seperti semula.
  Future<void> _answer(String option) async {
    setState(() => _routineAnswer = option);
    final original = _original;
    if (original == null) return;
    final store = WorkoutScope.read(context);
    final unit = store.settings.unit;
    final counts = {for (final e in widget.exercises) e.config.exerciseId: e.workCount};
    final Routine next;
    switch (option) {
      case 'Sets only':
        next = original.copyWith(exercises: [
          for (final cfg in original.exercises) cfg.copyWith(sets: counts[cfg.exerciseId] ?? cfg.sets),
        ]);
      case 'Update all':
        final byId = {for (final cfg in original.exercises) cfg.exerciseId: cfg};
        next = original.copyWith(exercises: [
          for (final e in widget.exercises)
            // Gerakan baru dari sesi ini: konfigurasinya dalam satuan
            // tampilan, rutinitas menyimpan kg.
            (byId[e.config.exerciseId] ?? configToKg(e.config, unit)).copyWith(sets: e.workCount),
        ]);
      default:
        next = original;
    }
    await store.saveRoutine(next);
  }

  Iterable<SetRow> get _workingSets =>
      widget.exercises.expand((e) => e.sets).where((s) => s.done && !s.isWarmup);

  double get _volume => _workingSets.fold(0.0, (a, s) => a + s.weight * s.reps);

  /// Rekor dibawa bersama nama gerakannya, bukan dicocokkan lewat indeks
  /// belakangan: begitu ada dua gerakan yang sama-sama memecahkan rekor,
  /// pencocokan lewat posisi akan menempelkan nama yang salah ke angka yang
  /// benar — kesalahan yang terlihat meyakinkan.
  List<(String, OneRmRecord)> get _records {
    final out = <(String, OneRmRecord)>[];
    for (final ex in widget.exercises) {
      final entry = WorkoutEntry(exerciseId: ex.config.exerciseId, target: ex.config, sets: ex.sets);
      final rec = is1RMRecord(widget.history, ex.config.exerciseId, entry);
      if (rec != null) out.add((ex.name, rec));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final records = _records;
    final setsDone = _workingSets.length;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  Row(
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          icon: Icons.timer_outlined,
                          value: _clock(widget.elapsed),
                          label: context.t.duration,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          icon: Icons.inventory_2_outlined,
                          value: volumeText(_volume, context.unit),
                          label: context.t.volume,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(icon: Icons.done_all, value: '$setsDone', label: context.t.setsDone),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          icon: Icons.emoji_events_outlined,
                          value: '${records.length}',
                          label: context.t.newPRs,
                          tone: records.isEmpty ? null : c.warn,
                        ),
                      ),
                    ],
                  ),
                  if (records.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _RecordsCard(records: records),
                  ],
                  const SizedBox(height: 14),
                  GymCard(
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
                              share: snap.hasData
                                  ? muscleShare(volumeByMuscle(_thisSession, snap.data!))
                                  : null,
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
                              return Text(context.t.noWorkingSets,
                                  style: TextStyle(fontSize: 12.5, color: c.text2));
                            }
                            // Empat otot teratas sesi ini, persentasenya dari
                            // total volume sesi — bukan dari maksimum, karena di
                            // sini pertanyaannya "porsinya berapa", bukan
                            // "seberapa dekat ke yang tertinggi".
                            final top = v.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value));
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
                  const SizedBox(height: 14),
                  // Target berikutnya dihitung dengan sesi ini ikut di riwayat.
                  // Tanpa sesi ini, "target berikutnya" hanya mengulang target
                  // yang baru saja dikerjakan.
                  _NextTargetsCard(exercises: widget.exercises, history: [...widget.history, ..._thisSession]),
                  if (widget.drifted && widget.routineId != null) ...[
                    const SizedBox(height: 14),
                    _RoutineDriftCard(
                      title: widget.addedSetTo != null
                          ? context.t.addedSetTo(widget.addedSetTo!)
                          : context.t.sessionDiffers(widget.routineName),
                      routineName: widget.routineName,
                      answer: _routineAnswer,
                      onAnswer: _answer,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: GymButton(label: context.t.done, onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label, this.tone});

  final IconData icon;
  final String value;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return GymCard(
      radius: GymRadius.card,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: c.text2),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: tone ?? c.text)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: c.text2)),
        ],
      ),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.records});

  final List<(String, OneRmRecord)> records;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
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
                Expanded(child: Text(entry.$1, style: Theme.of(context).textTheme.bodyLarge)),
                Text(
                  // Rekor pertama tidak punya pembanding — jangan tulis
                  // "(was 0)" yang terbaca seperti pernah mengangkat nol.
                  entry.$2.previous == null
                      ? 'e1RM ${formatDelta(entry.$2.now.est)} ${context.unitLabel}'
                      : 'e1RM ${formatDelta(entry.$2.now.est)} ${context.unitLabel} (was ${formatDelta(entry.$2.previous!)})',
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
      decoration: BoxDecoration(
        color: c.bgNested,
        borderRadius: BorderRadius.circular(GymRadius.small),
      ),
      child: Column(
        children: [
          Text(pct, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.accent)),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(fontSize: 10.5, color: c.text2)),
        ],
      ),
    );
  }
}

class _NextTargetsCard extends StatelessWidget {
  const _NextTargetsCard({required this.exercises, required this.history});

  final List<SessionExercise> exercises;
  final List<Workout> history;

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
            Builder(builder: (context) {
              // Fungsi yang sama dengan yang menyusun sesi berikutnya, supaya
              // angka di sini persis angka yang akan terbuka nanti.
              final plan = planExercise(ex.config, history, unit: context.unitLabel);
              final p = plan.prescription;
              final work = plan.sets.firstWhere((s) => !s.isWarmup, orElse: () => const SetRow());
              final weight = work.weight;
              final reps = work.reps;
              return Row(
                children: [
                  Expanded(child: Text(ex.name, style: Theme.of(context).textTheme.bodyLarge)),
                  Text('${weightLabel(weight, bodyweight: ex.config.bodyweight)} ${context.unitLabel} × $reps',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
                  const SizedBox(width: 8),
                  _DeltaTag(prescription: p, current: ex.config.weight),
                ],
              );
            }),
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
    final (text, tone) = switch (prescription.kind) {
      PrescriptionKind.up when next != null => ('+${formatDelta(next - current)}', c.accent),
      PrescriptionKind.deload when next != null => (formatDelta(next - current), c.warn),
      PrescriptionKind.hold => ('hold', c.text2),
      _ => ('new', c.text2),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(GymRadius.pill),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tone)),
    );
  }
}

/// Sesi menyimpang dari rutinitas — tanya sekali, jangan menyimpan diam-diam.
class _RoutineDriftCard extends StatelessWidget {
  const _RoutineDriftCard({
    required this.title,
    required this.routineName,
    required this.answer,
    required this.onAnswer,
  });

  final String title;
  final String routineName;
  final String? answer;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(context.t.updateRoutine(routineName), style: TextStyle(fontSize: 12.5, color: c.text2)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final option in ['Sets only', 'Update all', 'Keep']) ...[
                Expanded(
                  child: _DriftOption(
                    label: context.t.catalogue(option),
                    selected: answer == option,
                    onTap: () => onAnswer(option),
                  ),
                ),
                if (option != 'Keep') const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DriftOption extends StatelessWidget {
  const _DriftOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Material(
      color: selected ? c.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(GymRadius.small),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.small),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.small),
            border: Border.all(color: selected ? Colors.transparent : c.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? c.accentInk : c.text,
            ),
          ),
        ),
      ),
    );
  }
}
