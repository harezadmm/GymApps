/// Pelat per sisi di layar sesi (FR-D16): baris ringkas di kartu gerakan
/// berpelat, dan lembar yang memecah tiap set kerja menjadi pelat.
///
/// Semua angka di sini sudah dalam satuan tampilan: layar sesi memegang set
/// dalam satuan itu (lihat `units.dart`), dan bar serta pelat dibaca dari
/// setelan lewat [TrainingSettings.barWeightIn] / [TrainingSettings.platesIn].
library;

import 'package:flutter/material.dart';

import '../../core/gym_icons.dart';
import '../../core/strings.dart';
import '../../core/strings_plates.dart';
import '../../core/theme.dart';
import '../../core/weights.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/plates.dart';
import '../../domain/settings.dart';
import 'session_screen.dart';

/// Bar dan pelat yang berlaku untuk satu gerakan, dalam satuan tampilan.
///
/// Store dibaca kalau ada, tapi tidak dituntut: layar sesi juga dipasang
/// sendirian di test tanpa WorkoutScope, dan bawaan satuannya sudah cukup.
({double bar, List<double> plates}) plateSetupFor(BuildContext context, SessionExercise exercise) {
  final unit = context.unit;
  final s = context.dependOnInheritedWidgetOfExactType<WorkoutScope>()?.notifier?.settings ??
      const TrainingSettings();
  return (
    bar: effectiveBar(equipment: exercise.equipment, override: exercise.config.barWeight, globalBar: s.barWeightIn(unit)),
    plates: s.platesIn(unit),
  );
}

/// Baris "per sisi: 20 + 5 + 2,5" di kartu gerakan, untuk set kerja pertama
/// yang berbeban. Mengetuknya membuka [showPlatesSheet] dengan semua set.
///
/// Baris, bukan tombol ikon di judul kartu: judul sudah memuat chevron dan
/// ⋯, dan tombol ketiga di HP 360 dp menyisakan 120 dp untuk nama gerakan.
/// Di sini jawabannya langsung terbaca tanpa membuka apa pun — itu inti
/// FR-D16 — dan kotak sentuhnya ≥ 44 dp (NFR-11).
class PlatesRow extends StatelessWidget {
  const PlatesRow({super.key, required this.exercise});

  final SessionExercise exercise;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final unit = context.unit;
    final setup = plateSetupFor(context, exercise);
    final first = exercise.sets.firstWhere((s) => s.isWork && s.weight > 0, orElse: () => const SetRow());
    String text;
    var warn = false;
    if (first.weight <= 0) {
      text = t.plates;
    } else {
      final load = plateLoad(total: first.weight, bar: setup.bar, available: setup.plates);
      warn = !load.exact;
      text = load.barTooHeavy
          ? t.lighterThanBar(t.weightUnit(setup.bar, unit.label))
          : load.perSide.isEmpty
              ? t.emptyBar
              : t.perSide(t.plateList(load.perSide));
    }
    return Semantics(
      button: true,
      child: Tooltip(
        message: t.showPlates,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => showPlatesSheet(context, exercise: exercise, unit: unit, bar: setup.bar, plates: setup.plates),
            borderRadius: BorderRadius.circular(GymRadius.small),
            // Ink, bukan Container: dekorasinya jatuh di kanvas Material di
            // bawah riak, jadi riaknya tetap terlihat — pola yang sama dengan
            // FilterChips.
            child: Ink(
              decoration: BoxDecoration(
                color: c.bgNested,
                borderRadius: BorderRadius.circular(GymRadius.small),
                border: Border.all(color: c.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(plateIcon, size: 17, color: c.text2),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text),
                        ),
                      ),
                      if (warn) ...[
                        const SizedBox(width: 6),
                        Icon(GymIcons.info, size: 16, color: c.warn),
                      ],
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18, color: c.text3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lembar pelat per set kerja. [bar] dan [plates] dalam satuan [unit].
Future<void> showPlatesSheet(
  BuildContext context, {
  required SessionExercise exercise,
  required WeightUnit unit,
  required double bar,
  required List<double> plates,
}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.gym.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet)),
      ),
      builder: (_) => PlatesSheet(exercise: exercise, unit: unit, bar: bar, plates: plates),
    );

/// Isi lembar pelat. Publik supaya test bisa memasangnya sendiri.
class PlatesSheet extends StatelessWidget {
  const PlatesSheet({
    super.key,
    required this.exercise,
    required this.unit,
    required this.bar,
    required this.plates,
  });

  final SessionExercise exercise;
  final WeightUnit unit;
  final double bar;
  final List<double> plates;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    // Hanya set kerja (FR-D16): warm-up dan drop set mengikuti set kerjanya,
    // dan mencantumkannya hanya membuat lembar ini dua kali lebih panjang.
    final work = [for (final s in exercise.sets) if (s.isWork) s];
    final setupLine = [
      bar > 0 ? t.barLine(t.weightUnit(bar, unit.label)) : t.noBarLine,
      t.platesLine([for (final p in plates) t.plateNum(p)].join(', ')),
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewPadding.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(setupLine, style: TextStyle(fontSize: 13, height: 1.4, color: c.text2)),
            const SizedBox(height: 14),
            if (work.isEmpty)
              Text(t.noWorkSetsForPlates, style: TextStyle(fontSize: 13.5, color: c.text2)),
            for (final (i, s) in work.indexed) ...[
              _SetPlates(index: i + 1, set: s, unit: unit, bar: bar, plates: plates),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            Text(t.platesSheetHint, style: TextStyle(fontSize: 12.5, height: 1.4, color: c.text2)),
          ],
        ),
      ),
    );
  }
}

/// Satu set kerja: judul, cakram, bentuk teks, dan peringatan kalau bebannya
/// tidak bisa dibangun persis.
class _SetPlates extends StatelessWidget {
  const _SetPlates({
    required this.index,
    required this.set,
    required this.unit,
    required this.bar,
    required this.plates,
  });

  final int index;
  final SetRow set;
  final WeightUnit unit;
  final double bar;
  final List<double> plates;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final u = unit.label;
    final title = Theme.of(context).textTheme.titleMedium;
    if (set.weight <= 0) {
      return _box(c, [
        Text(t.setLabel(index), style: title),
        const SizedBox(height: 2),
        Text(t.noWeightYet, style: TextStyle(fontSize: 12.5, color: c.text2)),
      ]);
    }
    final load = plateLoad(total: set.weight, bar: bar, available: plates);
    if (load.barTooHeavy) {
      return _box(c, [
        Text('${t.setLabel(index)} · ${t.weightUnit(set.weight, u)}', style: title),
        const SizedBox(height: 8),
        NoteBanner(text: t.lighterThanBar(t.weightUnit(bar, u)), icon: GymIcons.info, tone: c.warn),
      ]);
    }
    // "60 kg → 20 kg per sisi": jawaban FR-D16 dalam satu baris, lalu
    // pecahannya di bawah.
    final perSideTotal = (set.weight - bar) / 2;
    return _box(c, [
      Text(
        '${t.setLabel(index)} · ${t.weightUnit(set.weight, u)} → ${t.perSideTotal(t.weightUnit(perSideTotal, u))}',
        style: title,
      ),
      const SizedBox(height: 8),
      if (load.perSide.isEmpty)
        Text(t.emptyBar, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text))
      else ...[
        PlateDiscs(perSide: load.perSide, available: plates, label: t.plateNum),
        const SizedBox(height: 8),
        Text(
          t.perSide(t.plateList(load.perSide)),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text),
        ),
      ],
      if (load.remainder > 0) ...[
        const SizedBox(height: 8),
        NoteBanner(
          text: t.notExact(t.weightUnit(load.loaded, u), t.weightUnit(load.remainder, u)),
          icon: GymIcons.info,
          tone: c.warn,
        ),
      ],
    ]);
  }

  Widget _box(GymColors c, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.bgNested, borderRadius: BorderRadius.circular(GymRadius.small)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}
