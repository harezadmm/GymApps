/// Tab History — artboard `11 History`.
///
/// Membaca riwayat asli dari [WorkoutStore]. Susunan dan tokennya tetap sama
/// dengan artboard; yang berubah cuma sumber angkanya. Ini juga layar tempat
/// orang memeriksa apakah sesinya benar-benar tersimpan, jadi ia tidak boleh
/// menunjukkan apa pun yang tidak ada di disk.
library;

import 'package:flutter/material.dart';

import '../../core/charts.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _filter = 0;

  static const _filters = ['All', 'Push', 'Pull', 'Legs'];

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final store = context.workouts;
    final all = store.workouts;

    final sessions = _filter == 0
        ? all
        : all.where((w) => w.routine == _filters[_filter]).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ScreenHeader(
          title: context.t.history,
          actions: [
            SquareIconButton(icon: Icons.calendar_month_outlined, onPressed: () {}),
            SquareIconButton(icon: Icons.add, tone: c.accent, onPressed: () {}),
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
          labels: [context.t.all, ..._filters.skip(1)],
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
              child: Text(context.t.noSessionsOf(_filters[_filter]),
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
  Widget build(BuildContext context) {
    final c = context.gym;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(
        children: [
          Icon(Icons.history, size: 30, color: c.text3),
          const SizedBox(height: 12),
          Text(context.t.noSessionsYet, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            context.t.noSessionsYetHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: c.text2),
          ),
        ],
      ),
    );
  }
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
        onTap: () {},
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.card),
            border: Border.all(color: c.border),
          ),
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
                        '${(volume / 1000).toStringAsFixed(1)} t',
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
