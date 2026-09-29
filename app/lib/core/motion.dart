/// Gerak yang dipakai bersama.
///
/// Aturannya satu: animasi di sini menjawab sentuhan, perubahan keadaan, atau
/// kedatangan isi baru (layar terbuka, angka selesai dihitung).
/// Tidak ada yang bergerak sendiri untuk menghias — di gym orang melihat layar
/// sekilas di antara set, dan yang bergerak tanpa sebab hanya menghabiskan
/// perhatian itu.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class GymMotion {
  /// Umpan balik tekan dan pergantian warna chip: harus terasa instan.
  static const quick = Duration(milliseconds: 140);

  /// Indikator segment bergeser, isi tab memudar.
  static const normal = Duration(milliseconds: 220);

  static const curve = Curves.easeOutCubic;

  /// Kedatangan kartu dan daftar.
  static const slow = Duration(milliseconds: 360);

  /// Angka yang menghitung naik ke nilainya.
  static const count = Duration(milliseconds: 700);

  /// Jeda antar anak dalam satu daftar, dikali indeksnya. Dibatasi delapan
  /// langkah: daftar panjang tidak boleh membuat baris ke-30 datang sedetik
  /// setelah layar terbuka.
  static const stagger = Duration(milliseconds: 45);
  static const staggerCap = 8;

  /// Sedikit melewati target lalu kembali — untuk centang dan lencana rekor.
  static const pop = Curves.easeOutBack;

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

// ── Kedatangan isi ─────────────────────────────────────────────────────────
//
// Tiga widget di bawah ini untuk isi yang *baru datang*: layar yang baru
// terbuka, angka yang baru dihitung, grafik yang baru digambar. Itu perubahan
// keadaan juga — dari "belum ada" ke "ada" — dan gerak singkat memberi tahu
// mata di mana yang baru itu. Semuanya sekali jalan, tidak berulang, dan
// hilang total kalau sistem meminta gerak dikurangi.

/// Memudar masuk sambil naik sedikit (atau membesar sedikit) saat pertama kali
/// dibangun. [index] memberi jeda bertingkat untuk anak-anak satu daftar.
///
/// Hanya sekali: kalau widget dibangun ulang karena state, tidak ada yang
/// bergerak lagi. Kartu yang berkedip setiap setState adalah gangguan, bukan
/// animasi.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.delay, this.slide = true, this.scale = false});

  final Widget child;
  final int index;

  /// Jeda sebelum mulai. null = [GymMotion.stagger] × [index].
  final Duration? delay;
  final bool slide;
  final bool scale;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: GymMotion.slow);
  late final _anim = CurvedAnimation(parent: _controller, curve: GymMotion.curve);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    final steps = widget.index.clamp(0, GymMotion.staggerCap);
    final delay = widget.delay ?? GymMotion.stagger * steps;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = FadeTransition(opacity: _anim, child: widget.child);
    if (widget.slide) {
      child = SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(_anim),
        child: child,
      );
    }
    if (widget.scale) {
      child = ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(_anim), child: child);
    }
    return child;
  }
}

/// Angka yang menghitung naik ke nilainya, dan menghitung lagi ke nilai baru
/// kalau berubah. Untuk angka besar di kartu statistik — volume minggu ini,
/// e1RM — supaya mata sempat menangkap bahwa angkanya baru dihitung.
class CountUp extends StatefulWidget {
  const CountUp(
    this.value, {
    super.key,
    this.style,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.format,
    this.textAlign,
    this.maxLines,
    this.delay = Duration.zero,
  });

  final double value;
  final TextStyle? style;
  final int decimals;
  final String prefix;
  final String suffix;

  /// Pembentuk teks kustom; kalau diisi, [decimals] diabaikan.
  final String Function(double value)? format;
  final TextAlign? textAlign;
  final int? maxLines;

  /// Tahan di nol selama ini sebelum mulai menghitung — samakan dengan jeda
  /// [Reveal] di sekitarnya, supaya hitungannya terjadi saat angkanya sudah
  /// terlihat, bukan di balik opacity nol.
  final Duration delay;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> {
  late bool _armed = widget.delay == Duration.zero;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_armed || _timer != null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _armed = true;
      return;
    }
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _armed = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _armed ? w.value : 0),
      duration: GymMotion.of(context, GymMotion.count),
      curve: GymMotion.curve,
      builder: (context, v, _) => Text(
        '${w.prefix}${w.format?.call(v) ?? v.toStringAsFixed(w.decimals)}${w.suffix}',
        style: w.style,
        textAlign: w.textAlign,
        maxLines: w.maxLines,
        overflow: w.maxLines == null ? null : TextOverflow.ellipsis,
      ),
    );
  }
}

/// Nilai 0..1 (atau apa pun) yang bergerak mulus ke targetnya, untuk
/// pembangun yang menggambar dari satu angka — tinggi batang grafik, isi
/// bilah progres, sudut cincin. Mulai dari [begin] saat pertama dibangun.
class AnimatedValue extends StatefulWidget {
  const AnimatedValue({
    super.key,
    required this.value,
    required this.builder,
    this.begin = 0,
    this.duration,
    this.curve,
    this.delay = Duration.zero,
  });

  final double value;
  final double begin;
  final Duration? duration;
  final Curve? curve;

  /// Tahan di [begin] selama ini sebelum bergerak (lihat [CountUp.delay]).
  final Duration delay;
  final Widget Function(BuildContext context, double value) builder;

  @override
  State<AnimatedValue> createState() => _AnimatedValueState();
}

class _AnimatedValueState extends State<AnimatedValue> {
  late bool _armed = widget.delay == Duration.zero;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_armed || _timer != null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _armed = true;
      return;
    }
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _armed = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: w.begin, end: _armed ? w.value : w.begin),
      duration: GymMotion.of(context, w.duration ?? GymMotion.slow),
      curve: w.curve ?? GymMotion.curve,
      builder: (context, v, _) => w.builder(context, v),
    );
  }
}
