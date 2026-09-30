/// Animasi Lottie IconScout untuk saat-saat yang memang layak bergerak:
/// sesi selesai, rekor baru, dan istirahat yang sedang berjalan. Sumber,
/// lisensi, dan cara berkasnya dibersihkan ada di `design/iconscout/SOURCES.md`.
///
/// Ketiganya dari satu kontributor (Prosymbols) dengan gaya garis satu tinta,
/// supaya terasa satu keluarga dengan ikon garis aplikasi — bukan maskot
/// berwajah yang bertabrakan dengan figur tanpa wajah di ilustrasi.
///
/// Berkasnya sudah diwarnai dengan palet IconScout "GymApps" (nilai tema
/// gelap). Di sini warna palet itu dipetakan lagi ke token tema yang aktif,
/// jadi tema terang dan aksen pilihan pengguna ikut berlaku tanpa berkas
/// kedua.
///
/// Aturan geraknya sama dengan `motion.dart`: perayaan diputar sekali lalu
/// diam di bingkai terakhirnya, yang berulang hanya penanda "sedang berjalan",
/// dan kalau sistem meminta gerak dikurangi yang tampil satu bingkai diam.
library;

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'theme.dart';

enum GymLottie {
  /// Popper yang meletus — ringkasan sesi baru saja tercatat.
  ///
  /// Berhenti di puncak letusan, bukan di bingkai terakhir berkasnya: di
  /// akhir animasi confetti sudah habis dan yang tersisa kerucut kosong yang
  /// kembali tegak — terbaca seperti tornado, bukan perayaan.
  sessionDone('session_done', still: 0.55, end: 0.55),

  /// Piala berbintang — rekor e1RM baru di kartu rekor.
  newRecord('new_record'),

  /// Jam pasir yang berbalik — istirahat sedang berjalan.
  ///
  /// Diperlambat: ia duduk di sebelah hitung mundur besar dan tidak boleh
  /// lebih menarik mata daripada angkanya. Diamnya di awal putaran, saat jam
  /// pasir berdiri tegak; bingkai terakhirnya setengah terbalik.
  resting('resting', still: 0, speed: 0.6);

  const GymLottie(this.file, {this.still = 1, this.speed = 1, this.end = 1});

  final String file;

  /// Titik (0..1) tempat perayaan berhenti dan diam. 1 = bingkai terakhir.
  final double end;

  /// Titik (0..1) yang tampil kalau gerak dikurangi. Untuk perayaan ini
  /// bingkai terakhir — persis yang dilihat semua orang setelah animasinya
  /// selesai, jadi dua mode itu berakhir di gambar yang sama.
  final double still;

  /// Pengali kecepatan terhadap durasi asli berkas.
  final double speed;

  /// Semua berkas digambar di kanvas 256 × 256 (dicek di test). Dipakai untuk
  /// mengubah tebal garis minimum dari dp ke satuan Lottie.
  static const canvas = 256.0;

  String get asset => 'assets/lottie/$file.json';
}

/// Satu animasi [GymLottie] dalam kotak [size] × [size].
///
/// Controller-nya dipegang sendiri, bukan diserahkan ke `Lottie`: hanya dengan
/// begitu "sekali saja", kecepatan, dan bingkai diam saat gerak dikurangi bisa
/// diatur di satu tempat. Dibangun ulang (mis. tiap detik di layar istirahat)
/// tidak memutar ulang apa pun.
class GymLottieView extends StatefulWidget {
  const GymLottieView(
    this.art, {
    super.key,
    required this.size,
    this.repeat = false,
    this.semanticLabel,
    this.minStroke = 1.3,
  });

  final GymLottie art;
  final double size;

  /// Berulang selama tampil. Hanya untuk penanda "sedang berjalan", seperti
  /// pemintal — perayaan tidak pernah berulang.
  final bool repeat;

  /// null = hiasan dan disembunyikan dari pembaca layar; teks di sebelahnya
  /// sudah menyebut hal yang sama.
  final String? semanticLabel;

  /// Tebal garis minimum dalam dp. Garis Prosymbols digambar untuk 256 px;
  /// diperkecil ke 40 dp jadi rambut ±0,7 dp yang hilang di kartu gelap.
  /// Garis yang lebih tipis dari ini ditebalkan, yang sudah cukup dibiarkan.
  final double minStroke;

  @override
  State<GymLottieView> createState() => _GymLottieViewState();
}

class _GymLottieViewState extends State<GymLottieView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _loaded = false;
  bool _still = false;

  /// Delegasi warna dan garis, disimpan bersama kuncinya. `LottieDelegates`
  /// dibandingkan per identitas daftar, jadi membuat yang baru tiap build
  /// berarti semua jalur kunci diselesaikan ulang tiap detik di layar istirahat.
  (Object, LottieDelegates)? _delegates;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(GymLottieView old) {
    super.didUpdateWidget(old);
    // Penanda "sedang berjalan" yang dimatikan berhenti di tempat, tidak
    // melompat ke awal.
    if (old.repeat && !widget.repeat) _controller.stop();
    if (old.repeat != widget.repeat) _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition) {
    _loaded = true;
    _controller.duration = composition.duration * (1 / widget.art.speed);
    _sync(justLoaded: true);
  }

  void _sync({bool justLoaded = false}) {
    if (_still) {
      _controller.stop();
      _controller.value = widget.art.still;
      return;
    }
    if (!_loaded) return;
    if (widget.repeat) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (justLoaded) {
      // Sekali, saat isinya datang, sampai titik akhirnya. Kalau gerak
      // dikurangi lalu dinyalakan lagi, perayaan yang sudah lewat tidak
      // diputar ulang.
      _controller.value = 0;
      _controller.animateTo(widget.art.end);
    }
  }

  LottieDelegates _delegatesFor(GymColors c) {
    final key = (c.accent, c.accentFill, c.doneInk, c.warn, c.hues.pink, c.surface2, widget.size, widget.minStroke);
    final cached = _delegates;
    if (cached != null && cached.$1 == key) return cached.$2;

    // Palet "GymApps" di IconScout = token tema gelap. Setiap warna berkas
    // dipetakan ke tokennya di tema yang aktif; di tema gelap hasilnya sama
    // persis, di tema terang jadi versi yang cukup pekat di atas putih.
    final palette = <int, Color>{
      0x8F7FFF: c.accent,
      0x6A5AE6: c.accentFill,
      0x4ADE80: c.doneInk,
      0xFFA94D: c.warn,
      0xFF5FB0: c.hues.pink,
      0x26262C: c.surface2,
    };
    Color themed(Color v) {
      for (final MapEntry(key: rgb, value: target) in palette.entries) {
        final close =
            ((v.r * 255).round() - (rgb >> 16 & 0xFF)).abs() <= 2 &&
            ((v.g * 255).round() - (rgb >> 8 & 0xFF)).abs() <= 2 &&
            ((v.b * 255).round() - (rgb & 0xFF)).abs() <= 2;
        if (close) return target.withValues(alpha: v.a);
      }
      return v;
    }

    // Warna yang berpindah antar-keyframe tetap berpindah, hanya ujung-ujungnya
    // yang dipetakan.
    Color color(Color? start, Color? end, double t) {
      if (start == null) return c.accent;
      final a = themed(start);
      if (end == null) return a;
      return Color.lerp(a, themed(end), t.clamp(0.0, 1.0))!;
    }

    final minWidth = widget.minStroke * GymLottie.canvas / widget.size;
    double stroke(double? start, double? end, double t) {
      final s = start ?? 0;
      return math.max(lerpDouble(s, end ?? s, t.clamp(0.0, 1.0))!, minWidth);
    }

    final delegates = LottieDelegates(
      values: [
        ValueDelegate.color(
          const ['**'],
          callback: (f) => color(f.startValue, f.endValue, f.interpolatedKeyframeProgress),
        ),
        ValueDelegate.strokeColor(
          const ['**'],
          callback: (f) => color(f.startValue, f.endValue, f.interpolatedKeyframeProgress),
        ),
        ValueDelegate.strokeWidth(
          const ['**'],
          callback: (f) => stroke(f.startValue, f.endValue, f.interpolatedKeyframeProgress),
        ),
      ],
    );
    _delegates = (key, delegates);
    return delegates;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final view = SizedBox.square(
      dimension: size,
      child: Lottie.asset(
        widget.art.asset,
        controller: _controller,
        onLoaded: _onLoaded,
        delegates: _delegatesFor(context.gym),
        width: size,
        height: size,
        fit: BoxFit.contain,
        // Berkas hilang atau rusak: ruangnya tetap kosong seukuran aslinya,
        // tata letak di sekitarnya tidak meloncat.
        errorBuilder: (context, error, stack) => SizedBox.square(dimension: size),
      ),
    );
    final label = widget.semanticLabel;
    if (label == null) return ExcludeSemantics(child: view);
    return Semantics(image: true, label: label, child: ExcludeSemantics(child: view));
  }
}
