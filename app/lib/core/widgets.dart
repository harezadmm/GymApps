/// Potongan UI yang dipakai berulang di banyak layar, disamakan dengan artboard
/// Pen di `REFRENSI/`. Ditaruh di satu tempat supaya padding, radius, dan warna
/// tidak diketik ulang per layar lalu perlahan menyimpang.
library;

import 'package:flutter/material.dart';

export 'format.dart' show formatWeight;

import 'motion.dart';
import 'theme.dart';

/// Kartu standar: surface, border tipis, radius besar.
class GymCard extends StatelessWidget {
  const GymCard({super.key, required this.child, this.padding, this.color, this.radius});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius ?? GymRadius.card),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

/// Label kapital kecil di atas satu bagian — "THIS WEEK", "PRESETS", "SET".
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

/// Lencana bulat kecil — "DUE TODAY", "78.4 kg".
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
      borderRadius: BorderRadius.circular(GymRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor ?? c.text,
            ),
            child: IconTheme.merge(
              data: IconThemeData(size: 14, color: textColor ?? c.text),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol utama biru langit. Tinggi 52 supaya nyaman ditekan dengan tangan
/// berkeringat sambil berdiri (NFR-12: target sentuh ≥ 48 dp).
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

  /// Pen tidak membuat semua tombol jadi pil: CTA utama dan sekunder bersudut
  /// membulat (r14 / r12), pil hanya dipakai tombol kecil di header seperti
  /// SAVE dan FINISH.
  final GymButtonShape shape;

  double get _radius => switch (shape) {
        GymButtonShape.pill => GymRadius.pill,
        GymButtonShape.rounded => tone == GymButtonTone.primary ? GymRadius.card : GymRadius.control,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final (bg, fg) = switch (tone) {
      GymButtonTone.primary => (c.accent, c.accentInk),
      GymButtonTone.neutral => (c.surface2, c.text),
      GymButtonTone.danger => (c.danger.withValues(alpha: 0.16), c.danger),
    };

    final text = Text(
      label,
      maxLines: 1,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: fg,
      ),
    );

    return PressScale(
      enabled: onPressed != null,
      child: SizedBox(
        width: expand ? double.infinity : null,
        height: height,
        // AnimatedContainer, bukan Material berwarna: warna mati/hidupnya
        // berubah lembut saat form jadi valid, tidak melompat.
        child: AnimatedContainer(
          duration: GymMotion.of(context, GymMotion.quick),
          decoration: BoxDecoration(
            color: onPressed == null ? bg.withValues(alpha: 0.4) : bg,
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  if (tone == GymButtonTone.primary) GymHaptics.confirm();
                  onPressed!();
                },
          borderRadius: BorderRadius.circular(_radius),
          child: Padding(
            // Tanpa padding ini tombol yang tidak melebar menyusut persis
            // selebar teksnya dan hurufnya menyentuh tepi pil.
            padding: EdgeInsets.symmetric(horizontal: expand ? 0 : 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                // Label yang lebih panjang dari tombolnya mengecil, tidak
                // meluber keluar: tombol setengah lebar di HP 360 dp dan
                // terjemahan yang lebih panjang dari bahasa Inggrisnya.
                // Hanya untuk tombol yang melebar — tombol selebar isinya bisa
                // duduk di Row tanpa batas lebar, dan Flexible di sana error.
                if (expand)
                  Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: text))
                else
                  text,
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }
}

enum GymButtonTone { primary, neutral, danger }

enum GymButtonShape { rounded, pill }

/// Tab segmented bergaya pil — "Tracker / My Plan", "Balance / Fatigue / Strength".
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
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.control),
        border: Border.all(color: c.border),
      ),
      // Satu pil yang bergeser ke segmen terpilih. Mata mengikuti benda yang
      // pindah lebih mudah daripada dua kotak yang bertukar warna.
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
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(GymRadius.segment),
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
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: i == index ? c.accentInk : c.text2,
                            ),
                            child: Text(label),
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

/// Deretan chip filter yang bisa digulir — "All · Push · Pull · Legs".
class FilterChips extends StatelessWidget {
  const FilterChips({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = i == index;
          return AnimatedContainer(
            duration: GymMotion.of(context, GymMotion.quick),
            curve: GymMotion.curve,
            decoration: BoxDecoration(
              color: on ? c.accent : c.surface,
              borderRadius: BorderRadius.circular(GymRadius.pill),
              border: Border.all(color: on ? c.accent : c.border),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () {
                  if (on) return;
                  GymHaptics.tap();
                  onChanged(i);
                },
                borderRadius: BorderRadius.circular(GymRadius.pill),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AnimatedDefaultTextStyle(
                    duration: GymMotion.of(context, GymMotion.quick),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: on ? c.accentInk : c.text,
                    ),
                    child: Text(labels[i]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Satu baris pengaturan: ikon · label · nilai · chevron.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String? value;

  /// Menggantikan nilai + chevron — untuk switch atau titik warna.
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final ink = tone ?? c.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 19, color: tone ?? c.text2),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ink))),
            if (trailing != null)
              trailing!
            else ...[
              if (value != null) Text(value!, style: TextStyle(fontSize: 13.5, color: c.text2)),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 18, color: c.text3),
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
        borderRadius: BorderRadius.circular(GymRadius.card),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.border, indent: 48),
            child,
          ],
        ],
      ),
    );
  }
}

/// Baris yang bisa dipilih dengan lingkaran centang di kanan — dipakai
/// onboarding program dan daftar peralatan.
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
  });

  final String title;
  final String? subtitle;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  /// Kotak untuk pilihan ganda, lingkaran untuk pilihan tunggal — bedanya
  /// memberi tahu "boleh pilih banyak" tanpa satu kata pun.
  final bool square;

  /// Baris yang mati ditulis redup — daftar peralatan panjang, dan yang tidak
  /// kamu punya sebaiknya mundur ke belakang.
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: off ? c.text3 : c.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.accent)),
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
        color: selected ? c.accent : Colors.transparent,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(7) : null,
        border: Border.all(color: selected ? c.accent : c.text3, width: 1.5),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: GymMotion.of(context, GymMotion.quick),
        curve: GymMotion.curve,
        child: Icon(Icons.check, size: 17, color: c.accentInk),
      ),
    );
  }
}

/// Header layar tingkat atas: judul besar plus aksi di kanan.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineMedium)),
          for (final a in actions) Padding(padding: const EdgeInsets.only(left: 8), child: a),
        ],
      ),
    );
  }
}

/// Tombol ikon kotak di header.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, this.onPressed, this.tone});

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return PressScale(
      enabled: onPressed != null,
      scale: 0.92,
      child: Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(GymRadius.small),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(GymRadius.small),
        child: Container(
          // Kotak yang terlihat tetap 42 seperti artboard Pen, tapi area
          // sentuhnya 44 lewat padding di pembungkusnya (lihat di bawah) —
          // 42 di bawah ambang minimum, dan tangan berkeringat di gym adalah
          // kasus pakai yang sebenarnya, bukan teori.
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.small),
            border: Border.all(color: c.border),
          ),
          child: Icon(icon, size: 20, color: tone ?? c.text2),
        ),
      ),
      ),
    );
  }
}

/// Baris info bernada — kuning untuk peringatan lembut, biru untuk keterangan.
class NoteBanner extends StatelessWidget {
  const NoteBanner({super.key, required this.text, required this.icon, required this.tone});

  final String text;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(GymRadius.card),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tone)),
          ),
        ],
      ),
    );
  }
}
