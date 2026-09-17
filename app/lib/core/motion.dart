/// Gerak yang dipakai bersama.
///
/// Aturannya satu: animasi di sini menjawab sentuhan atau perubahan keadaan.
/// Tidak ada yang bergerak sendiri untuk menghias — di gym orang melihat layar
/// sekilas di antara set, dan yang bergerak tanpa sebab hanya menghabiskan
/// perhatian itu.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class GymMotion {
  /// Umpan balik tekan dan pergantian warna chip: harus terasa instan.
  static const quick = Duration(milliseconds: 140);

  /// Indikator segment bergeser, isi tab memudar.
  static const normal = Duration(milliseconds: 220);

  static const curve = Curves.easeOutCubic;

  /// Nol kalau sistem meminta gerak dikurangi. Semua animasi di aplikasi
  /// lewat sini supaya satu setelan aksesibilitas benar-benar mematikan semua.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// Getar kecil. Dua tingkat saja: `tap` untuk berpindah pilihan, `confirm`
/// untuk sesuatu yang tercatat — set selesai, tombol utama.
abstract final class GymHaptics {
  static void tap() => HapticFeedback.selectionClick();
  static void confirm() => HapticFeedback.lightImpact();
}

/// Mengecil sedikit selama jari menempel. Dipasang di luar [InkWell], bukan
/// menggantikannya: riak tetap jalan, dan [Listener] tidak merebut sentuhan.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true, this.scale = 0.97});

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (!widget.enabled || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: GymMotion.of(context, GymMotion.quick),
        curve: GymMotion.curve,
        child: widget.child,
      ),
    );
  }
}

/// [IndexedStack] yang memudar saat indeksnya berubah. Anak-anaknya tetap
/// hidup — posisi gulir dan field yang sedang diisi tidak hilang saat pindah
/// tab — hanya tampilannya yang dilembutkan.
class FadeIndexedStack extends StatefulWidget {
  const FadeIndexedStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: GymMotion.normal, value: 1);
  late final _fade = CurvedAnimation(parent: _controller, curve: GymMotion.curve);
  late final _slide = Tween(begin: const Offset(0, 0.008), end: Offset.zero).animate(_fade);

  @override
  void didUpdateWidget(FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _controller.duration = GymMotion.of(context, GymMotion.normal);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: IndexedStack(index: widget.index, children: widget.children),
      ),
    );
  }
}

/// Pergantian isi yang memudar sambil naik sedikit — untuk konten yang
/// berganti di tempat yang sama (isi tab segmented, label status).
class FadeSwap extends StatelessWidget {
  const FadeSwap({super.key, required this.child, this.alignment = Alignment.topCenter});

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: GymMotion.of(context, GymMotion.normal),
      switchInCurve: GymMotion.curve,
      switchOutCurve: GymMotion.curve,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}

/// Ikon yang berputar pelan selama ditampilkan — hanya untuk "sedang
/// dikerjakan", karena berputar adalah janji bahwa sesuatu sedang terjadi.
class SpinIcon extends StatefulWidget {
  const SpinIcon(this.icon, {super.key, this.size, this.color});

  final IconData icon;
  final double? size;
  final Color? color;

  @override
  State<SpinIcon> createState() => _SpinIconState();
}

class _SpinIconState extends State<SpinIcon> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, size: widget.size, color: widget.color);
    if (MediaQuery.disableAnimationsOf(context)) return icon;
    return RotationTransition(turns: _controller, child: icon);
  }
}
