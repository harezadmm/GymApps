/// Potongan UI yang dipakai berulang di banyak layar — UI v3 "Bevel glass"
/// (`design/UI-V3.md` §6). Ditaruh di satu tempat supaya padding, radius, dan
/// warna tidak diketik ulang per layar lalu perlahan menyimpang.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

export 'format.dart' show formatWeight;
export 'glass.dart' show GlassIconButton, GlassSurface, GlassTone, glassInk;

import 'glass.dart';
import 'gym_icons.dart';
import 'motion.dart';
import 'theme.dart';

/// Kartu standar: putih/abu di atas latar, sudut 22, bayangan lembut.
class GymCard extends StatelessWidget {
  const GymCard({super.key, required this.child, this.padding, this.color, this.radius, this.shadow = true});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double? radius;

  /// Bayangan kartu. Kartu berwarna (bukan surface) tidak diberi bayangan —
  /// warnanya sudah memisahkannya dari latar.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius ?? GymRadius.card),
        boxShadow: shadow && color == null ? [c.cardShadow] : null,
      ),
      child: child,
    );
  }
}

/// Label kapital kecil di atas satu grup — "RUTINITAS PROGRAM", "LATIHAN".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    );
  }
}

/// Judul seksi — "Sesi berikutnya · Pilih lain": judul 17/700 di kiri,
/// tautan 13/600 aksen di kanan.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        if (action != null)
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(GymRadius.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(action!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pil kecil berisi teks — "+1 rep", "Berikutnya", "tahan". Warnanya dari
/// pemanggil: doneBg/doneInk untuk kenaikan, warnSoft/warn untuk deload,
/// surface2/text2 untuk netral.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.child, this.color, this.textColor, this.onTap});

  final Widget child;
  final Color? color;
  final Color? textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Material(
      color: color ?? c.surface2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: textColor ?? c.text2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            child: IconTheme.merge(
              data: IconThemeData(size: 12, color: textColor ?? c.text2),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tag kapital kecil di atas latar aksen lembut — "HARI INI", "BESOK".
class TagPill extends StatelessWidget {
  const TagPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.accent),
      ),
    );
  }
}

/// Tile ikon berwarna: latar hue lembut, ikon hue pekat. 44/14 untuk baris
/// rutinitas dan sesi, 36/12 untuk statistik ringkasan, 30/10 untuk KPI.
class HueTile extends StatelessWidget {
  const HueTile({super.key, required this.icon, required this.hue, this.size = 44, this.radius = 14, this.iconSize});

  final IconData icon;
  final Color hue;
  final double size;
  final double radius;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.hues.soft(hue, c), borderRadius: BorderRadius.circular(radius)),
      child: Icon(icon, size: iconSize ?? (size * 0.45).roundToDouble(), color: hue),
    );
  }
}

/// Ikon di dalam cakram bulat berwarna — kategori Library, baris pilihan.
/// [color] mewarnai ikon; latarnya pasangan lembutnya.
class IconDisc extends StatelessWidget {
  const IconDisc(this.icon, {super.key, this.color, this.size = 44, this.iconSize, this.filled = false});

  final IconData icon;
  final Color? color;
  final double size;
  final double? iconSize;

  /// Cakram penuh warna dengan ikon putih — untuk keadaan terpilih.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final hue = color ?? c.accent;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: filled ? c.accentFill : c.hues.soft(hue, c), shape: BoxShape.circle),
      child: Icon(icon, size: iconSize ?? size * 0.5, color: filled ? c.accentInk : hue),
    );
  }
}

/// Avatar bulat berisi inisial — pojok kanan header Beranda, kartu akun.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.text, this.onTap, this.size = 36, this.tooltip});

  final String text;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final body = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
      child: Text(text, style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: c.accent)),
    );
    if (onTap == null) return body;
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: body),
        ),
      ),
    );
  }
}

/// Tombol kaca. Utama = kaca berwarna dengan label putih; netral = kaca
/// bening; bahaya = kaca bening dengan tinta merah. Tinggi 52 supaya nyaman
/// ditekan dengan tangan berkeringat sambil berdiri (NFR-12: target ≥ 48 dp).
///
/// Labelnya kalimat biasa — tidak ada lagi KAPITAL berspasi lebar.
class GymButton extends StatelessWidget {
  const GymButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tone = GymButtonTone.primary,
    this.height = 52,
    this.expand = true,
    this.shape = GymButtonShape.rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GymButtonTone tone;
  final double height;
  final bool expand;

  /// Dipertahankan untuk pemanggil lama; di v3 semua tombol berbentuk pil.
  final GymButtonShape shape;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final glass = tone == GymButtonTone.primary ? GlassTone.tinted : GlassTone.clear;
    final fg = switch (tone) {
      GymButtonTone.primary => Colors.white,
      GymButtonTone.danger => c.danger,
      GymButtonTone.neutral => c.text,
    };
    final big = height >= 48;
    final radius = height / 2;
    final text = Text(
      label,
      maxLines: 1,
      style: TextStyle(
        fontSize: big ? 15 : 13.5,
        fontWeight: big ? FontWeight.w700 : FontWeight.w600,
        color: fg,
      ),
    );

    return PressScale(
      enabled: onPressed != null,
      child: AnimatedOpacity(
        duration: GymMotion.of(context, GymMotion.quick),
        opacity: onPressed == null ? 0.45 : 1,
        child: SizedBox(
          width: expand ? double.infinity : null,
          height: height,
          child: GlassSurface(
            tone: glass,
            radius: radius,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                if (tone == GymButtonTone.danger)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      color: c.danger.withValues(alpha: 0.12),
                    ),
                  ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onPressed == null
                        ? null
                        : () {
                            if (tone == GymButtonTone.primary) GymHaptics.confirm();
                            onPressed!();
                          },
                    borderRadius: BorderRadius.circular(radius),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: expand ? 12 : 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[Icon(icon, size: big ? 17 : 15, color: fg), const SizedBox(width: 8)],
                          // Label yang lebih panjang dari tombolnya mengecil,
                          // tidak meluber: tombol setengah lebar di HP 360 dp.
                          if (expand) Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: text)) else text,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum GymButtonTone { primary, neutral, danger }

enum GymButtonShape { rounded, pill }

/// Tab segmented: lintasan surface2 dengan thumb putih/abu yang bergeser —
/// "Keseimbangan / Kelelahan / Kekuatan".
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(GymRadius.segTrack),
      ),
      // Satu thumb yang bergeser ke segmen terpilih. Mata mengikuti benda
      // yang pindah lebih mudah daripada dua kotak yang bertukar warna.
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / labels.length;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: GymMotion.of(context, GymMotion.normal),
              curve: GymMotion.curve,
              left: index * w,
              top: 0,
              bottom: 0,
              width: w,
              child: DecoratedBox(
                key: const ValueKey('seg-thumb'),
                decoration: BoxDecoration(
                  color: c.segThumb,
                  borderRadius: BorderRadius.circular(GymRadius.segment),
                  boxShadow: const [BoxShadow(color: Color(0x1A14142B), offset: Offset(0, 2), blurRadius: 8)],
                ),
              ),
            ),
            Row(
              children: [
                for (final (i, label) in labels.indexed)
                  Expanded(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () {
                          if (i == index) return;
                          GymHaptics.tap();
                          onChanged(i);
                        },
                        borderRadius: BorderRadius.circular(GymRadius.segment),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: GymMotion.of(context, GymMotion.normal),
                            curve: GymMotion.curve,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: i == index ? FontWeight.w700 : FontWeight.w600,
                              color: i == index ? c.text : c.text2,
                            ),
                            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

/// Deretan chip filter yang bisa digulir — "Semua · Push · Pull · Legs".
/// Yang terpilih kaca berwarna; yang lain putih bergaris rambut.
class FilterChips extends StatelessWidget {
  const FilterChips({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = i == index;
          final label = Text(
            labels[i],
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : c.text),
          );
          void tap() {
            if (on) return;
            GymHaptics.tap();
            onChanged(i);
          }

          if (on) {
            return GlassSurface(
              tone: GlassTone.tinted,
              radius: GymRadius.chip,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: tap,
                  borderRadius: BorderRadius.circular(GymRadius.chip),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(child: label),
                  ),
                ),
              ),
            );
          }
          return Material(
            color: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GymRadius.chip),
              side: BorderSide(color: c.border),
            ),
            child: InkWell(
              onTap: tap,
              borderRadius: BorderRadius.circular(GymRadius.chip),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(child: label),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Satu baris pengaturan: ikon garis · label · nilai · chevron. Tanpa cakram
/// berwarna — daftar panjang lebih tenang dibaca.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.tone,
    this.hue,
  });

  final IconData icon;
  final String label;
  final String? value;

  /// Menggantikan nilai + chevron — untuk switch atau titik warna.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Warna ikon dan label, untuk baris berbahaya (keluar akun).
  final Color? tone;

  /// Dipertahankan untuk pemanggil lama; v3 tidak mewarnai ikon per baris.
  final Color? hue;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: tone ?? c.text2),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: tone ?? c.text)),
            ),
            if (trailing != null)
              trailing!
            else ...[
              if (value != null)
                Flexible(
                  child: Text(value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 13.5, color: c.text2)),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 10),
                Icon(GymIcons.chevronRight, size: 16, color: c.text3),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Kartu berisi beberapa [SettingsTile] dengan garis pemisah tipis.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.group),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.border, indent: 46),
            child,
          ],
        ],
      ),
    );
  }
}

/// Baris yang bisa dipilih dengan lingkaran centang di kanan — dipakai
/// onboarding program, pemilih di Profil, dan daftar peralatan.
class SelectRow extends StatelessWidget {
  const SelectRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.detail,
    this.square = false,
    this.dimWhenOff = false,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  /// Ikon di kiri judul, misalnya gambar alat di pemilih alat gym.
  final IconData? icon;

  /// Kotak untuk pilihan ganda, lingkaran untuk pilihan tunggal.
  final bool square;

  /// Baris yang mati ditulis redup — daftar peralatan panjang.
  final bool dimWhenOff;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final off = dimWhenOff && !selected;
    return InkWell(
      onTap: () {
        GymHaptics.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(GymRadius.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              off
                  ? Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(GymRadius.control)),
                      child: Icon(icon, size: 22, color: c.text3),
                    )
                  : HueTile(icon: icon!, hue: c.accent, size: 42, radius: GymRadius.control, iconSize: 22),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: off ? c.text3 : c.text),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.accent)),
                  ],
                  if (detail != null) ...[
                    const SizedBox(height: 3),
                    Text(detail!, style: TextStyle(fontSize: 12.5, color: c.text2)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Tick(selected: selected, square: square),
          ],
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.selected, required this.square});

  final bool selected;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return AnimatedContainer(
      duration: GymMotion.of(context, GymMotion.quick),
      curve: GymMotion.curve,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? c.accentFill : Colors.transparent,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(GymRadius.check) : null,
        border: Border.all(color: selected ? c.accentFill : c.text3, width: 1.5),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: GymMotion.of(context, GymMotion.quick),
        curve: GymMotion.curve,
        child: Icon(GymIcons.check, size: 13, color: c.accentInk),
      ),
    );
  }
}

/// Header layar tab: judul 28/800 di kiri, aksi kaca di kanan.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;

  /// Baris kecil di atas judul.
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) ...[SectionLabel(subtitle!), const SizedBox(height: 3)],
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
          for (final a in actions) Padding(padding: const EdgeInsets.only(left: 10), child: a),
        ],
      ),
    );
  }
}

/// Tombol ikon bulat di header — kaca bening 38 dp.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, this.onPressed, this.tone, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? tone;
  final String? tooltip;

  @override
  Widget build(BuildContext context) =>
      GlassIconButton(icon: icon, onPressed: onPressed, tooltip: tooltip, color: tone);
}

/// Baris info bernada: peringatan (warnSoft/warn), keterangan aksen
/// (accentSoft/accent), atau netral (surface2/text2).
class NoteBanner extends StatelessWidget {
  const NoteBanner({super.key, required this.text, required this.icon, required this.tone});

  final String text;
  final IconData icon;

  /// Warna tinta yang diminta: [GymColors.warn], [GymColors.accent],
  /// [GymColors.doneInk], atau warna teks biasa.
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final (bg, ink) = tone == c.warn
        ? (c.warnSoft, c.warn)
        : tone == c.accent
            ? (c.accentSoft, c.accent)
            : tone == c.doneInk
                ? (c.doneBg, c.doneInk)
                : (c.surface2, c.text2);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(GymRadius.control)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 16, color: ink)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3, color: ink)),
          ),
        ],
      ),
    );
  }
}

/// Angka ber-digit dalam kotak kecil — volume rencana di kartu rutinitas.
class Odometer extends StatelessWidget {
  const Odometer({super.key, required this.value, required this.unit});

  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final digits = value.round().toString();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, d) in digits.split('').indexed) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            width: 18,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(6)),
            child: Text(d,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
        ],
        const SizedBox(width: 5),
        Text(unit, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text2)),
      ],
    );
  }
}

/// Cincin ukuran dengan angka di tengah dan label di bawah — tiga cincin di
/// kartu Beranda. Busurnya tumbuh ke nilainya saat pertama tampil.
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.fraction,
    required this.color,
    required this.value,
    required this.label,
    this.delay = Duration.zero,
    this.size = 86,
  });

  final double fraction;
  final Color color;
  final String value;
  final String label;
  final Duration delay;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: AnimatedValue(
            value: fraction.clamp(0.0, 1.0),
            delay: delay,
            builder: (context, v) => CustomPaint(
              painter: _RingPainter(fraction: v, track: c.ringTrack, ink: color),
              child: Center(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: value.length > 4 ? 17 : 19,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.text2),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.track, required this.ink});

  final double fraction;
  final Color track;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final r = size.width / 2 - stroke / 2;
    final centre = size.center(Offset.zero);
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: r),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = ink,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.track != track || old.ink != ink;
}
