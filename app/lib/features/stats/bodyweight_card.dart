/// Berat badan: catat, lihat trennya, dan garis target (FR-F4).
///
/// Target disimpan di setelan akun dalam kg ([TrainingSettings.bodyweightTarget])
/// dan tampil di grafik sebagai garis putus-putus. Batang terakhir dan
/// keterangan "x kg to go" diwarnai menurut arahnya — mendekat hijau,
/// menjauh oranye, sudah di target aksen — kriteria penerimaan PRD "titik
/// diwarnai sesuai arah ke target" secara harfiah.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/gym_icons.dart';
import '../../core/strings.dart';
import '../../core/strings_bodyweight.dart';
import '../../core/theme.dart';
import '../../core/weights.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/program.dart';
import '../../domain/settings.dart';
import '../../domain/stats.dart';
import '../../domain/units.dart';

/// Ikon target. Font GymIcons tidak punya glyph bendera atau sasaran; `flag`
/// varian outlined mengikuti aturan ikon lain di luar font.
const bodyweightTargetIcon = Icons.flag_outlined;

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

  /// Target berat badan (FR-F4): dialog angka dalam satuan tampilan, seperti
  /// dialog berat bar di Profil. Disimpan dalam kg seperti catatan berat
  /// badan; "hapus target" mengosongkan nilainya, bukan menulis nol.
  Future<void> _target(BuildContext context) async {
    final store = WorkoutScope.read(context);
    final unit = store.settings.unit;
    final current = store.settings.bodyweightTarget;
    final r = await showDialog<_TargetResult>(
      context: context,
      builder: (_) => _TargetDialog(initial: current == null ? null : shown(current, unit), unit: unit),
    );
    if (r == null) return;
    // Dibaca ulang dari store: sinkron bisa mengganti setelan selagi dialog
    // terbuka, dan target baru tidak boleh menimpa setelan yang baru datang.
    final s = store.settings;
    final v = r.value;
    await store.updateSettings(
        v == null ? s.copyWith(clearBodyweightTarget: true) : s.copyWith(bodyweightTarget: toKg(v, unit)));
  }

  /// Warna arah (FR-F4): sudah di target = aksen, mendekat = hijau "selesai",
  /// menjauh = peringatan. Belum jelas (satu catatan, atau tidak bergerak) =
  /// null, kartu memakai warnanya sendiri seperti tanpa target.
  static Color? _toneFor(GymColors c, TargetGap? gap) {
    if (gap == null) return null;
    if (gap.onTarget) return c.accent;
    return switch (gap.heading) {
      TargetHeading.toward => c.doneInk,
      TargetHeading.away => c.warn,
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final log = store.bodyweightLog;
    final last = log.isEmpty ? null : log.last;
    final targetKg = store.settings.bodyweightTarget;
    final gap = targetKg == null ? null : bodyweightGap(log, targetKg, context.unit);
    final tone = _toneFor(c, gap);
    final recent = log.length <= 12 ? log : log.sublist(log.length - 12);
    final lowest = recent.isEmpty ? 0.0 : recent.map((e) => e.kg).reduce(math.min);
    // Dasar batang ditarik ke bawah target juga: batang mulai 1 di atas yang
    // terendah dari keduanya, jadi garis target yang di bawah semua catatan
    // tetap jatuh di dalam grafik, bukan di bawah dasarnya.
    final low = targetKg == null ? lowest : math.min(lowest, targetKg);
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
      color: c.block(c.hues.pink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconDisc(GymIcons.scale, color: c.hues.pink, size: 34, iconSize: 18),
              const SizedBox(width: 10),
              Expanded(child: SectionLabel(t.bodyweightTitle)),
              if (last != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(context.wUnit(last.kg),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                    // Sisanya tepat di bawah angkanya, supaya keduanya terbaca
                    // sebagai satu pasangan: berat sekarang, dan kurang berapa.
                    if (gap != null) ...[const SizedBox(height: 4), _GapPill(gap: gap, tone: tone)],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(change ?? (last == null ? t.bodyweightNone : last.date), style: TextStyle(fontSize: 12.5, color: c.text2)),
          if (recent.length >= 2) ...[
            const SizedBox(height: 12),
            BarSeries(
              // Batang terakhir berwarna arah ke target (FR-F4); tanpa target,
              // atau arahnya belum jelas, tetap warna kartu.
              highlightColor: tone ?? c.hues.pink,
              // Batang dimulai sedikit di bawah berat terendah, supaya
              // selisih 0,5 kg tetap terlihat.
              values: [for (final e in recent) e.kg - low + 1],
              // Gelembung menampilkan berat sesungguhnya, bukan tinggi batang
              // yang sudah digeser — angka itulah yang ditanyakan.
              labels: [for (final e in recent) e.date.substring(5)],
              valueFormat: (v) => context.wUnit(v + low - 1),
              // Garis target dalam skala geseran yang sama dengan batangnya.
              reference: targetKg == null
                  ? null
                  : ChartReference(value: targetKg - low + 1, label: t.targetLineLabel(context.wUnit(targetKg))),
              leftLabel: recent.first.date.substring(5),
              midLabel: '',
              rightLabel: recent.last.date.substring(5),
              height: 90,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GymButton(
                  label: t.logBodyweight,
                  icon: GymIcons.scale,
                  tone: GymButtonTone.neutral,
                  height: 44,
                  onPressed: () => _log(context),
                ),
              ),
              const SizedBox(width: 8),
              // Target di sebelah tombol catat, bukan di Profil: yang mengatur
              // target sedang melihat grafiknya. Labelnya menyebut targetnya,
              // jadi angkanya terbaca tanpa membuka dialog.
              Expanded(
                child: GymButton(
                  label: targetKg == null ? t.setBodyweightTarget : t.targetButton(context.wUnit(targetKg)),
                  icon: bodyweightTargetIcon,
                  tone: GymButtonTone.neutral,
                  height: 44,
                  onPressed: () => _target(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "3.4 kg to go" (atau "On target") di bawah angka berat badan, berwarna
/// arah. Teksnya duduk di chip [GymColors.surface], bukan langsung di kartu
/// merah muda: aksen di tema gelap dan oranye peringatan di tema terang hanya
/// ≈ 3,3–3,8:1 di atas kartu berwarna itu, tapi ≥ 4,5:1 di atas surface
/// (NFR-11). Panah naik/turun menemani warnanya, supaya arah geraknya tidak
/// disampaikan lewat warna saja.
class _GapPill extends StatelessWidget {
  const _GapPill({required this.gap, required this.tone});

  final TargetGap gap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final ink = tone ?? c.text2;
    final delta = gap.delta ?? 0;
    // Tanpa panah saat sudah di target atau belum bergerak: panah datar hanya
    // mengulang apa yang sudah dikatakan teksnya.
    final arrow =
        gap.onTarget || delta == 0 ? null : (delta > 0 ? Icons.trending_up_outlined : Icons.trending_down_outlined);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(GymRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (arrow != null) ...[Icon(arrow, size: 14, color: ink), const SizedBox(width: 4)],
          Text(
            gap.onTarget ? t.onTarget : t.toGo('${formatDelta(gap.toGo)} ${context.unitLabel}'),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
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
        GymButton(label: t.save, height: 44, expand: false, onPressed: _submit),
      ],
    );
  }
}

/// Hasil dialog target: [value] dalam satuan tampilan; null = hapus target.
/// Dialog yang ditutup begitu saja mengembalikan null tanpa pembungkus ini,
/// jadi "batal" dan "hapus" tidak tertukar — pola yang sama dengan dialog
/// berat bar di Profil.
class _TargetResult {
  const _TargetResult(this.value);

  final double? value;
}

/// Dialog target berat badan (FR-F4): angka dalam satuan tampilan, plus
/// tombol hapus kalau targetnya sudah ada. Widget sendiri karena
/// controller-nya harus hidup sampai dialog benar-benar hilang (lihat
/// [_BodyweightDialog]).
class _TargetDialog extends StatefulWidget {
  const _TargetDialog({this.initial, required this.unit});

  /// Target sekarang dalam satuan tampilan; null = belum ada.
  final double? initial;
  final WeightUnit unit;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late final _controller = TextEditingController(text: widget.initial == null ? '' : formatDelta(widget.initial!));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Angka positif yang diketik, atau null: nol bukan target.
  double? _typed() {
    final v = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    return v == null || v <= 0 ? null : v;
  }

  void _submit() {
    final v = _typed();
    if (v != null) Navigator.of(context).pop(_TargetResult(v));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
      title: Text(t.bodyweightTargetTitle, style: Theme.of(context).textTheme.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.bodyweightTargetHint, style: TextStyle(fontSize: 13.5, height: 1.45, color: c.text2)),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(suffixText: widget.unit.label),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        // Hanya kalau ada yang bisa dihapus: tombol hapus untuk target yang
        // tidak ada adalah kontrol mati.
        if (widget.initial != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(const _TargetResult(null)),
            child: Text(t.clearBodyweightTarget, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
        ),
        // Mati selagi isinya bukan angka positif: tombol simpan yang tidak
        // melakukan apa-apa adalah tombol mati.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, _, _) =>
              GymButton(label: t.save, height: 44, expand: false, onPressed: _typed() == null ? null : _submit),
        ),
      ],
    );
  }
}
