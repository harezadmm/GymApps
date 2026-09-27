/// Tab History — artboard `11 History`.
///
/// Membaca riwayat asli dari [WorkoutStore]. Susunan dan tokennya tetap sama
/// dengan artboard; yang berubah cuma sumber angkanya. Ini juga layar tempat
/// orang memeriksa apakah sesinya benar-benar tersimpan, jadi ia tidak boleh
/// menunjukkan apa pun yang tidak ada di disk.
library;

import 'package:flutter/material.dart';
import '../../core/gym_icons.dart';
import '../../core/illustration.dart';
import '../../core/weights.dart';

import '../../core/charts.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../session/session_launcher.dart';
import 'workout_edit_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _filter = 0;

  /// Filter diambil dari nama rutinitas yang benar-benar ada di riwayat —
  /// dulu tertulis Push/Pull/Legs apa pun program orangnya.
  static List<String> _filtersFor(List<Workout> all) {
    final seen = <String>[];
    for (final w in all) {
      final r = w.routine;
      if (r != null && r.isNotEmpty && !seen.contains(r)) seen.add(r);
    }
    return ['All', ...seen.take(6)];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final store = context.workouts;
    final all = store.workouts;
    final filters = _filtersFor(all);
    if (_filter >= filters.length) _filter = 0;

    final sessions = _filter == 0
        ? all
        : all.where((w) => w.routine == filters[_filter]).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ScreenHeader(
          title: context.t.history,
          actions: [
            // Kalender bulanan belum ada — kotak aktivitas di bawah sudah
            // menjawab "kapan saja aku latihan". Tombol + mencatat sesi baru.
            SquareIconButton(
              icon: GymIcons.plus,
              tone: c.accent,
              onPressed: () => openFreestyleSession(context, context.t.freestyle),
            ),
          ],
        ),
        GymCard(
          radius: GymRadius.large,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: SectionLabel(context.t.activity)),
                  Text(context.t.sessionsThisYear(_thisYear(all)),
                      style: TextStyle(fontSize: 12, color: c.text2)),
                ],
              ),
              const SizedBox(height: 14),
              Builder(builder: (context) {
                final (levels, months) = _heatmap(all);
                return ActivityHeatmap(levels: levels, monthLabels: months);
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilterChips(
          labels: [context.t.all, ...filters.skip(1)],
          index: _filter,
          onChanged: (i) => setState(() => _filter = i),
        ),
        const SizedBox(height: 18),
        if (all.isNotEmpty) ...[
          SectionLabel(_monthLabel(all.first.date)),
          const SizedBox(height: 10),
        ],
        if (!store.loaded)
          // Riwayat masih dibaca dari disk. Jangan tulis "belum ada sesi" di
          // sini — itu kalimat yang paling menakutkan untuk dibaca keliru.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (all.isEmpty)
          _EmptyHistory()
        else if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(context.t.noSessionsOf(filters[_filter]),
                  style: TextStyle(fontSize: 13.5, color: c.text2)),
            ),
          )
        else
          for (final w in sessions) ...[
            _SessionRow(workout: w),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  static int _thisYear(List<Workout> all) {
    final year = DateTime.now().year.toString();
    return all.where((w) => w.date.startsWith(year)).length;
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _monthLabel(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    return d == null ? '' : '${_months[d.month - 1]} ${d.year}';
  }

  /// Level 0..4 per hari untuk 24 minggu terakhir, plus label bulannya.
  ///
  /// Kolom = minggu, dibaca kolom per kolom, sama seperti artboard. Petaknya
  /// selalu berakhir di hari ini supaya sel paling kanan-bawah adalah hari
  /// yang sedang dijalani, bukan hari acak di tengah minggu.
  static (List<int>, List<String>) _heatmap(List<Workout> all) {
    const weeks = 24;
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    // Mundur ke Senin minggu ini, lalu mundur 23 minggu lagi.
    final thisMonday = end.subtract(Duration(days: end.weekday - 1));
    final start = thisMonday.subtract(const Duration(days: 7 * (weeks - 1)));

    final setsPerDay = <String, int>{};
    for (final w in all) {
      final n = w.entries.fold(0, (a, e) => a + e.sets.where((s) => s.done && !s.isWarmup).length);
      setsPerDay[w.date] = (setsPerDay[w.date] ?? 0) + n;
    }

    final levels = <int>[];
    final months = <String>[];
    for (var week = 0; week < weeks; week++) {
      final monday = start.add(Duration(days: 7 * week));
      // Satu label per bulan, ditulis di minggu pertama yang menyentuhnya.
      if (week == 0 || monday.day <= 7) {
        months.add(_months[monday.month - 1].substring(0, 3));
      }
      for (var day = 0; day < 7; day++) {
        final d = monday.add(Duration(days: day));
        final key = '${d.year}-${_two(d.month)}-${_two(d.day)}';
        final sets = setsPerDay[key] ?? 0;
        levels.add(switch (sets) {
          0 => 0,
          <= 8 => 1,
          <= 15 => 2,
          <= 22 => 3,
          _ => 4,
        });
      }
    }
    return (levels, months);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) => EmptyState(
        art: GymArt.emptyHistory,
        title: context.t.noSessionsYet,
        body: context.t.noSessionsYetHint,
      );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.workout});

  final Workout workout;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Set kerja saja. Pemanasan tidak dihitung sebagai latihan di tempat lain
  /// juga, dan menghitungnya di sini akan membuat angkanya saling bertentangan.
  Iterable<SetRow> get _workingSets =>
      workout.entries.expand((e) => e.sets).where((s) => s.done && !s.isWarmup);

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final date = DateTime.tryParse(workout.date);
    final volume = _workingSets.fold(0.0, (a, s) => a + s.weight * s.reps);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(GymRadius.card),
      child: InkWell(
        onTap: () => _showDetail(context, workout),
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Column(
                  children: [
                    Text(date == null ? '--' : _HistoryScreenState._two(date.day),
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.text)),
                    const SizedBox(height: 1),
                    Text(date == null ? '' : _weekdays[date.weekday - 1].toUpperCase(),
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: c.text3)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workout.routine ?? context.t.freestyleSession,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (workout.durationSeconds != null) _clock(workout.durationSeconds!),
                        context.volume(volume),
                        context.t.setsSuffix(_workingSets.length),
                      ].join(' · '),
                      style: TextStyle(fontSize: 12.5, color: c.text2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: c.text3),
            ],
          ),
        ),
      ),
    );
  }

  static String _clock(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }
}


/// Detail satu sesi: gerakan dan setnya, plus hapus (FR-F1).
Future<void> _showDetail(BuildContext context, Workout workout) async {
  final store = WorkoutScope.read(context);
  final catalog = await ExerciseCatalog.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.gym.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.large))),
    builder: (sheetContext) {
      final c = sheetContext.gym;
      final t = sheetContext.t;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(workout.routine ?? t.freestyleSession, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              [
                workout.date,
                if (workout.durationSeconds != null) '${workout.durationSeconds! ~/ 60} min',
              ].join(' · '),
              style: TextStyle(fontSize: 13, color: c.text2),
            ),
            if (workout.notes != null) ...[
              const SizedBox(height: 10),
              Text(workout.notes!, style: TextStyle(fontSize: 13.5, height: 1.4, color: c.text)),
            ],
            const SizedBox(height: 16),
            for (final e in workout.entries) ...[
              Text(catalog.nameOf(e.exerciseId), style: Theme.of(context).textTheme.titleMedium),
              if (e.note != null) ...[
                const SizedBox(height: 2),
                Text(e.note!, style: TextStyle(fontSize: 12.5, color: c.warn)),
              ],
              const SizedBox(height: 6),
              for (final (i, s) in e.sets.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                            switch (s.phase) {
                              SetPhase.warmup => 'W',
                              SetPhase.drop => 'D',
                              SetPhase.restPause => 'RP',
                              SetPhase.work => '${e.sets.take(i + 1).where((x) => x.isWork).length}',
                            },
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800, color: s.isWork ? c.text2 : c.warn)),
                      ),
                      Expanded(
                        child: Text(
                            (e.target?.mode ?? LogMode.reps) == LogMode.time
                                ? '${s.seconds}s'
                                : '${context.wLabel(s.weight, bodyweight: e.target?.bodyweight ?? false)} ${context.unitLabel} × ${s.reps}'
                                    '${s.rir == null ? '' : '  @${s.rir}'}',
                            style: TextStyle(fontSize: 14, color: s.done ? c.text : c.text3)),
                      ),
                      Icon(s.done ? Icons.check_circle : Icons.circle_outlined,
                          size: 18, color: s.done ? c.doneInk : c.text3),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            GymButton(
              label: t.edit,
              icon: Icons.edit_outlined,
              tone: GymButtonTone.neutral,
              height: 44,
              onPressed: () async {
                final updated = await Navigator.of(sheetContext).push<Workout>(
                  MaterialPageRoute(builder: (_) => WorkoutEditScreen(workout: workout, catalog: catalog)),
                );
                if (updated == null) return;
                await store.replaceWorkout(workout, updated);
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.sessionUpdated)));
              },
            ),
            const SizedBox(height: 10),
            GymButton(
              label: t.delete,
              icon: Icons.delete_outline,
              tone: GymButtonTone.danger,
              height: 44,
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: sheetContext,
                  builder: (context) => AlertDialog(
                    backgroundColor: c.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
                    title: Text('${t.delete}?', style: Theme.of(context).textTheme.titleLarge),
                    content: Text('${workout.routine ?? t.freestyleSession} · ${workout.date}',
                        style: TextStyle(fontSize: 14, color: c.text2)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
                      ),
                      GymButton(
                        label: t.delete,
                        height: 42,
                        expand: false,
                        tone: GymButtonTone.danger,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                await store.removeWorkout(workout);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      );
    },
  );
}
