/// Potongan UI yang dipakai berulang di banyak layar, mengikuti referensi
/// `REFRENSI/NEW REFRENSI/`. Ditaruh di satu tempat supaya padding, radius,
/// dan warna tidak diketik ulang per layar lalu perlahan menyimpang.
library;

import 'package:flutter/material.dart';

export 'format.dart' show formatWeight;

import 'motion.dart';
import 'theme.dart';

/// Kartu standar: abu gelap di atas latar hampir hitam, tanpa garis tepi.
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

/// Judul bagian bergaya referensi — "Popular exercises · See all": judul di
/// kiri, aksi kecil di kanan.
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
                child: Text(action!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text2)),
              ),
            ),
          ),
      ],
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

/// Ikon di dalam cakram bulat berwarna — "My Fitness Profile", kategori,
/// baris setelan. [color] mewarnai ikon; latarnya [color] yang ditipiskan.
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
      decoration: BoxDecoration(color: filled ? c.accentFill : c.tint(hue), shape: BoxShape.circle),
      child: Icon(icon, size: iconSize ?? size * 0.5, color: filled ? c.accentInk : hue),
    );
  }
}

/// Avatar bulat berisi inisial — di pojok kanan header, seperti referensi.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.text, this.onTap, this.size = 40, this.tooltip});

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
      decoration: BoxDecoration(color: c.tint(c.accent), shape: BoxShape.circle),
      child: Text(text, style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w800, color: c.accent)),
    );
    if (onTap == null) return body;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: body),
      ),
    );
  }
}

/// Blok statistik berwarna penuh — kartu "Weight / Calories / BPM" di
/// referensi: judul kecil di atas, angka besar di bawah, keterangan di bawahnya.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.hint,
    this.icon,
    this.onTap,
    this.height,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final body = Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(color: c.block(color), borderRadius: BorderRadius.circular(GymRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: color), const SizedBox(height: 8)],
          // Dua baris: "Volume 7 hari" di ubin sepertiga lebar HP 360 dp tidak
          // muat satu baris, dan "Volum…" bukan label.
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2, color: c.text)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontFamily: 'Manrope', fontSize: 28, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -0.6, color: c.text)),
          ),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.text2)),
          ],
        ],
      ),
    );
    if (onTap == null) return body;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(GymRadius.card), child: body),
    );
  }
}

/// Tombol utama violet berbentuk pil. Tinggi 52 supaya nyaman ditekan dengan
/// tangan berkeringat sambil berdiri (NFR-12: target sentuh ≥ 48 dp).
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

  /// Referensi memakai pil untuk tombol utama ("Next", "Play") dan sudut
  /// membulat untuk tombol sekunder di dalam kartu.
  final GymButtonShape shape;

  double get _radius => switch (shape) {
        GymButtonShape.pill => GymRadius.pill,
        GymButtonShape.rounded => tone == GymButtonTone.primary ? GymRadius.pill : GymRadius.control,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final (bg, fg) = switch (tone) {
      GymButtonTone.primary => (c.accentFill, c.accentInk),
      GymButtonTone.neutral => (c.surface2, c.text),
      GymButtonTone.danger => (c.danger.withValues(alpha: 0.16), c.danger),
    };

    final text = Text(
      label,
      maxLines: 1,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
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
                padding: EdgeInsets.symmetric(horizontal: expand ? 0 : 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                    // Label yang lebih panjang dari tombolnya mengecil, tidak
                    // meluber keluar: tombol setengah lebar di HP 360 dp dan
                    // terjemahan yang lebih panjang dari bahasa Inggrisnya.
                    // Hanya untuk tombol yang melebar — tombol selebar isinya
                    // bisa duduk di Row tanpa batas lebar, dan Flexible di sana
                    // error.
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
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(GymRadius.pill),
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
                  color: c.accentFill,
                  borderRadius: BorderRadius.circular(GymRadius.pill),
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
                        borderRadius: BorderRadius.circular(GymRadius.pill),
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
              color: on ? c.accentFill : c.surface2,
              borderRadius: BorderRadius.circular(GymRadius.pill),
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

/// Satu baris pengaturan: cakram ikon · label · nilai · chevron.
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

  /// Warna label, untuk baris berbahaya (keluar akun).
  final Color? tone;

  /// Warna cakram ikon. Referensi memberi tiap baris warnanya sendiri supaya
  /// daftar panjang mudah dipindai; null = aksen.
  final Color? hue;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final ink = tone ?? c.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            IconDisc(icon, color: tone ?? hue, size: 38, iconSize: 19),
            const SizedBox(width: 13),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ink))),
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
              const SizedBox(width: 6),
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
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.border, indent: 65),
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
    this.icon,
  });

  final String title;
  final String? subtitle;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  /// Ikon di kiri judul, misalnya gambar alat di pemilih alat gym.
  final IconData? icon;

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              off
                  ? Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.bgNested, shape: BoxShape.circle),
                      child: Icon(icon, size: 22, color: c.text3),
                    )
                  : IconDisc(icon!, size: 42, iconSize: 22),
              const SizedBox(width: 12),
            ],
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
        color: selected ? c.accentFill : Colors.transparent,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(GymRadius.check) : null,
        border: Border.all(color: selected ? c.accentFill : c.text3, width: 1.5),
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

/// Header layar tingkat atas: judul plus aksi bulat di kanan, seperti
/// "Diet Adviser · 🔔 · avatar" di referensi.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;

  /// Baris kecil di atas judul — tanggal di Home.
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
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

/// Tombol ikon bulat di header — dulu kotak, referensi memakai lingkaran.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, this.onPressed, this.tone, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? tone;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final button = PressScale(
      enabled: onPressed != null,
      scale: 0.92,
      child: Material(
        color: c.surface,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            // Lingkaran yang terlihat 42; area sentuhnya 44 lewat padding di
            // pembungkusnya — tangan berkeringat di gym adalah kasus pakai yang
            // sebenarnya, bukan teori.
            width: 42,
            height: 42,
            child: Icon(icon, size: 20, color: tone ?? c.text),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Baris info bernada — oranye untuk peringatan lembut, aksen untuk keterangan.
class NoteBanner extends StatelessWidget {
  const NoteBanner({super.key, required this.text, required this.icon, required this.tone});

  final String text;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.tint(tone),
        borderRadius: BorderRadius.circular(GymRadius.control),
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
