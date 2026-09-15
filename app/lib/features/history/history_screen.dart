/// Tab History — artboard `11 History`.
library;

import 'package:flutter/material.dart';

import '../../core/charts.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/demo.dart';

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
    final sessions = _filter == 0
        ? demoSessions
        : demoSessions.where((s) => s.routine == _filters[_filter]).toList();

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
                  Text(context.t.sessionsThisYear(demoSessionsThisYear),
                      style: TextStyle(fontSize: 12, color: c.text2)),
                ],
              ),
              const SizedBox(height: 14),
              ActivityHeatmap(
                levels: demoActivityLevels,
                monthLabels: const ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilterChips(labels: [context.t.all, ..._filters.skip(1)], index: _filter, onChanged: (i) => setState(() => _filter = i)),
        const SizedBox(height: 18),
        SectionLabel(context.t.catalogue('September 2026')),
        const SizedBox(height: 10),
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(context.t.noSessionsOf(_filter == 0 ? context.t.all : _filters[_filter]),
                  style: TextStyle(fontSize: 13.5, color: c.text2)),
            ),
          )
        else
          for (final s in sessions) ...[
            _SessionRow(session: s),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final DemoSession session;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
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
                    Text(session.day,
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.text)),
                    const SizedBox(height: 1),
                    Text(session.weekday.toUpperCase(),
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.text3)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(session.routine, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
                        if (session.hasPr) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.warn.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(GymRadius.pill),
                            ),
                            child: Text('PR',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.warn)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('${session.duration} · ${session.volume} · ${context.t.setsSuffix(session.sets)}',
                        style: TextStyle(fontSize: 12.5, color: c.text2)),
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
}
