/// Berat badan: catat, lihat trennya (FR-F4). Bentuk v3 (spec UI-V3 §7.6):
/// label kecil, angka 24/800, selisih "−0,6 kg / 30 hari", tombol Catat
/// tinted 34, dan sparkline selebar kartu dari 12 catatan terakhir.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/gym_icons.dart';
import '../../core/strings.dart';
import '../../core/strings_v3.dart';
import '../../core/theme.dart';
import '../../core/weights.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/program.dart';
import '../../domain/units.dart';

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
    String? change;
    if (log.length >= 2) {
      final first = log.first;
      final d = kgTo(last!.kg - first.kg, context.unit);
      final days = (DateTime.tryParse(last.date) ?? DateTime.now())
          .difference(DateTime.tryParse(first.date) ?? DateTime.now())
          .inDays;
      change = t.bwDelta(
        '${d >= 0 ? '+' : ''}${formatDelta(double.parse(d.toStringAsFixed(1)))} ${context.unitLabel}',
        days,
      );
    }
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.bodyweightTitle, style: TextStyle(fontSize: 12.5, color: c.text2)),
                    const SizedBox(height: 2),
                    Text(
                      last == null ? '—' : context.wUnit(last.kg),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.15,
                        color: c.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(change ?? (last == null ? t.bodyweightNone : last.date),
                        style: TextStyle(fontSize: 12, height: 1.35, color: c.text2)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GymButton(
                label: t.logShort,
                icon: GymIcons.plus,
                height: 34,
                expand: false,
                onPressed: () => _log(context),
              ),
            ],
          ),
          if (recent.length >= 2) ...[
            const SizedBox(height: 14),
            // Garis, bukan batang: berat badan bergerak sepersepuluh kilo, dan
            // batang yang digeser dari berat terendah hanya menyamarkan arahnya.
            LayoutBuilder(
              builder: (context, box) => Sparkline(
                values: [for (final e in recent) e.kg],
                width: box.maxWidth,
                height: 36,
                color: c.hues.pink,
              ),
            ),
          ],
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
