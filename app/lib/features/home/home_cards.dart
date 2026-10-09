/// Kartu-kartu Beranda v3 (spec UI-V3 §7.1): pil status, kartu cincin dengan
/// insight, kartu sesi berikutnya, dan kartu progres kekuatan. Datanya
/// disiapkan `home_screen.dart`; di sini hanya bentuknya.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/charts.dart';
import '../../core/gym_icons.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_v3.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Pil status di bawah header: lingkaran ikon pekat, judul, keterangan,
/// chevron. Dua pil berjajar: program aktif dan keadaan sinkron.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    this.subtitle,
    this.onTap,
    this.spinning = false,
  });

  final IconData icon;
  /// Tinta ikon; latarnya pasangan lembut tinta itu, bukan cakram pekat
  /// berikon putih — text3/warn/doneInk pekat hanya 1,8–2,4:1 dengan putih.
  final Color tone;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Ikon berputar — hanya selagi sinkron berjalan.
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: c.border)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 7, 12, 7),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.hues.soft(tone, c), shape: BoxShape.circle),
                child: spinning ? SpinIcon(icon, size: 17, color: tone) : Icon(icon, size: 17, color: tone),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.text2)),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(GymIcons.chevronDown, size: 16, color: c.text2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiga cincin minggu ini plus satu kalimat insight di bawahnya.
class RingsCard extends StatelessWidget {
  const RingsCard({
    super.key,
    required this.sessionsDone,
    required this.sessionsPlanned,
    required this.setsDone,
    required this.setsPlanned,
    required this.volumeNow,
    required this.volumeBefore,
    required this.insightTitle,
    required this.insightBody,
    this.insightIcon = GymIcons.arrowUpRight,
  });

  final int sessionsDone;
  final int sessionsPlanned;
  final int setsDone;
  final int setsPlanned;

  /// Volume 7 hari terakhir dan 7 hari sebelumnya (satuan apa pun, hanya
  /// rasionya yang dipakai).
  final double volumeNow;
  final double volumeBefore;
  final String insightTitle;
  final String insightBody;
  final IconData insightIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final volFraction = volumeBefore <= 0 ? (volumeNow > 0 ? 1.0 : 0.0) : (volumeNow / volumeBefore).clamp(0.0, 1.0);
    final String volText;
    if (volumeBefore <= 0) {
      volText = '—';
    } else {
      final pct = ((volumeNow - volumeBefore) / volumeBefore * 100).round();
      volText = '${pct >= 0 ? '+' : ''}$pct%';
    }
    return GymCard(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: RingGauge(
                  fraction: sessionsPlanned <= 0 ? 0 : sessionsDone / sessionsPlanned,
                  color: c.ringA,
                  value: '$sessionsDone/${math.max(sessionsPlanned, 0)}',
                  label: t.ringSessions,
                ),
              ),
              Expanded(
                child: RingGauge(
                  fraction: setsPlanned <= 0 ? 0 : setsDone / setsPlanned,
                  color: c.ringB,
                  value: '$setsDone/$setsPlanned',
                  label: t.ringSets,
                  delay: GymMotion.stagger * 2,
                ),
              ),
              Expanded(
                child: RingGauge(
                  fraction: volFraction,
                  color: c.ringC,
                  value: volText,
                  label: t.ringVolume,
                  delay: GymMotion.stagger * 4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: c.border),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 1), child: Icon(insightIcon, size: 16, color: c.accent)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(insightTitle,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.25, color: c.text)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(insightBody, style: TextStyle(fontSize: 13, height: 1.4, color: c.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu baris gerakan di kartu sesi berikutnya.
class NextRow {
  const NextRow({required this.name, required this.target, this.change, this.tone = ChangeTone.up});

  final String name;
  final String target;

  /// "+1 rep", "+2,5 kg", "deload" — null kalau targetnya tetap.
  final String? change;
  final ChangeTone tone;
}

class NextSessionCard extends StatelessWidget {
  const NextSessionCard({
    super.key,
    required this.routineName,
    required this.meta,
    required this.tag,
    required this.rows,
    required this.hiddenCount,
    required this.onStart,
    required this.onSkip,
    this.note,
    this.hue,
  });

  final String routineName;
  final String meta;

  /// "HARI INI" / "BESOK" / nama hari.
  final String tag;
  final List<NextRow> rows;
  final int hiddenCount;
  final VoidCallback onStart;
  final VoidCallback onSkip;

  /// Banner pemulihan/hari latihan kalau sesinya belum waktunya.
  final Widget? note;
  final Color? hue;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final tone = hue ?? c.accent;
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HueTile(icon: GymIcons.dumbbell, hue: tone, size: 52, radius: 16, iconSize: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(routineName,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 3),
                      Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.text2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(top: 14), child: TagPill(tag)),
            ],
          ),
          if (note != null) ...[const SizedBox(height: 12), note!],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final (i, r) in rows.indexed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: i < rows.length - 1 || hiddenCount > 0
                    ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border)))
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(r.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
                    ),
                    if (r.change != null) ...[
                      const SizedBox(width: 8),
                      ChangePill(r.change!, tone: r.tone),
                    ],
                    const SizedBox(width: 8),
                    Text(r.target,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ],
                ),
              ),
            if (hiddenCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(t.moreExercises(hiddenCount), style: TextStyle(fontSize: 12, color: c.text3)),
              ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: GymButton(label: t.startSession, icon: GymIcons.play, onPressed: onStart),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GymButton(label: t.skip, tone: GymButtonTone.neutral, onPressed: onSkip),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu pintu masuk Recap: "Recap minggu ini · 3 sesi · 2 j 25 mnt · volume +8%".
class RecapEntryCard extends StatelessWidget {
  const RecapEntryCard({super.key, required this.title, required this.subtitle, required this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.tile),
        boxShadow: [c.cardShadow],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GymRadius.tile),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                HueTile(icon: GymIcons.calendar, hue: c.hues.violet, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: c.text2)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(GymIcons.chevronRight, size: 18, color: c.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu baris di kartu progres kekuatan.
class StrengthRow {
  const StrengthRow({
    required this.name,
    required this.meta,
    required this.values,
    required this.delta,
    required this.tone,
    this.onTap,
  });

  final String name;
  final String meta;
  final List<double> values;
  final String delta;
  final ChangeTone tone;
  final VoidCallback? onTap;
}

class StrengthCard extends StatelessWidget {
  const StrengthCard({super.key, required this.rows});

  final List<StrengthRow> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    if (rows.isEmpty) {
      return GymCard(
        child: Text(t.strengthNoData, style: TextStyle(fontSize: 13, color: c.text2)),
      );
    }
    return GymCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (final (i, r) in rows.indexed)
            InkWell(
              onTap: r.onTap,
              borderRadius: BorderRadius.circular(GymRadius.small),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: i < rows.length - 1 ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border))) : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                          const SizedBox(height: 2),
                          Text(r.meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.text2)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Sparkline(values: r.values),
                    const SizedBox(width: 12),
                    ChangePill(r.delta, tone: r.tone),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
