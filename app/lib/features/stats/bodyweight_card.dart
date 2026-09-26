/// Berat badan: catat, lihat trennya (FR-F4).
library;

import 'package:flutter/material.dart';
import '../../core/gym_icons.dart';
import '../../core/weights.dart';
import '../../domain/units.dart';
import 'package:flutter/services.dart';

import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/program.dart';

class BodyweightCard extends StatelessWidget {
  const BodyweightCard({super.key});

  Future<void> _log(BuildContext context) async {
    final store = WorkoutScope.read(context);
    final unit = store.settings.unit;
    final latest = store.latestBodyweight;
    final typed = await showDialog<double>(
      context: context,
      builder: (_) => _BodyweightDialog(initial: latest == null ? null : shown(latest, unit), unit: unit.label),
    );
    if (typed == null || typed <= 0) return;
    await store.logBodyweight(isoDate(DateTime.now()), toKg(typed, unit));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final log = context.workouts.bodyweightLog;
    final last = log.isEmpty ? null : log.last;
    final recent = log.length <= 12 ? log : log.sublist(log.length - 12);
    final low = recent.isEmpty ? 0.0 : recent.map((e) => e.kg).reduce((a, b) => a < b ? a : b);
    String? change;
    if (log.length >= 2) {
      final first = log.first;
      final d = kgTo(last!.kg - first.kg, context.unit);
      final days = (DateTime.tryParse(last.date) ?? DateTime.now())
          .difference(DateTime.tryParse(first.date) ?? DateTime.now())
          .inDays;
      change = t.bodyweightChange(
          '${d >= 0 ? '+' : ''}${formatDelta(double.parse(d.toStringAsFixed(1)))}', days, context.unitLabel);
    }
    return GymCard(
      radius: GymRadius.large,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(t.bodyweightTitle)),
              if (last != null)
                Text(context.wUnit(last.kg),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
            ],
          ),
          const SizedBox(height: 6),
          Text(change ?? (last == null ? t.bodyweightNone : last.date), style: TextStyle(fontSize: 12.5, color: c.text2)),
          if (recent.length >= 2) ...[
            const SizedBox(height: 12),
            BarSeries(
              // Batang dimulai sedikit di bawah berat terendah, supaya
              // selisih 0,5 kg tetap terlihat.
              values: [for (final e in recent) e.kg - low + 1],
              leftLabel: recent.first.date.substring(5),
              midLabel: '',
              rightLabel: recent.last.date.substring(5),
              height: 90,
            ),
          ],
          const SizedBox(height: 12),
          GymButton(
            label: t.logBodyweight,
            icon: GymIcons.scale,
            tone: GymButtonTone.neutral,
            height: 42,
            onPressed: () => _log(context),
          ),
        ],
      ),
    );
  }
}

class _BodyweightDialog extends StatefulWidget {
  const _BodyweightDialog({this.initial, this.unit = 'kg'});

  final double? initial;
  final String unit;

  @override
  State<_BodyweightDialog> createState() => _BodyweightDialogState();
}

class _BodyweightDialogState extends State<_BodyweightDialog> {
  late final _controller = TextEditingController(text: widget.initial == null ? '' : formatDelta(widget.initial!));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(double.tryParse(_controller.text.replaceAll(',', '.')));

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
      title: Text(t.logBodyweight, style: Theme.of(context).textTheme.titleLarge),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(suffixText: widget.unit),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
        ),
        GymButton(label: t.save, height: 42, expand: false, onPressed: _submit),
      ],
    );
  }
}
