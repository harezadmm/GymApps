import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Token desain GymApps v3 "Bevel glass" — kontraknya di `design/UI-V3.md`,
/// nilainya dari variabel dokumen Pen. Dua tema penuh (terang bawaan mockup,
/// gelap), kartu putih/abu dengan bayangan lembut, aksen violet, dan
/// permukaan kaca ([GlassTokens]) untuk tombol utama, chip terpilih, tab bar,
/// dan pil istirahat.
///
/// Dipisah dari [ThemeData] karena banyak warna tidak punya slot di Material.
/// Widget membaca lewat `context.gym` (lihat [GymColorsX]) supaya tidak ada
/// nilai hex yang tersebar di layar.
@immutable
class GymColors extends ThemeExtension<GymColors> {
  const GymColors({
    required this.bg,
    required this.bgNested,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accentFill,
    required this.accentInk,
    required this.accentSoft,
    required this.doneBg,
    required this.doneInk,
    required this.warn,
    required this.warnSoft,
    required this.warm,
    required this.danger,
    required this.selected,
    required this.chartIdle,
    required this.sparkTop,
    required this.sparkBottom,
    required this.silhouette,
    required this.heatRamp,
    required this.activityRamp,
    required this.ringTrack,
    required this.ringA,
    required this.ringB,
    required this.ringC,
    required this.segThumb,
    required this.washA,
    required this.washB,
    required this.cardShadow,
    required this.glass,
    required this.hues,
    required this.brightness,
    this.accentBase,
  });

  /// Latar layar: abu sangat muda / hampir hitam.
  final Color bg;

  /// Latar di dalam kartu — area peta otot, tabel set.
  final Color bgNested;

  /// Kartu. Tanpa garis tepi; yang memisahkannya dari latar bayangan lembut
  /// ([cardShadow]) dan selisih terang.
  final Color surface;

  /// Pil KG/REPS, lintasan tab segmented, tile ikon netral, chip mati.
  final Color surface2;

  /// Garis rambut: pemisah baris, grid grafik, stroke chip tak terpilih.
  final Color border;

  /// NFR-11 minta kontras teks ≥ 4,5:1. [text2] di atas [surface] ≥ 5:1.
  /// [text3] di bawah ambang itu — hanya untuk elemen dekoratif.
  final Color text;
  final Color text2;
  final Color text3;

  /// Aksen untuk ikon, teks, dan tanda. Di tema terang digelapkan sampai
  /// ≥ 4,5:1 di atas [bg].
  final Color accent;

  /// Satu-satunya latar pekat untuk teks putih: dasar gradien kaca, tombol
  /// stepper terpilih, lingkaran ikon pil status.
  final Color accentFill;
  final Color accentInk;

  /// Latar lembut aksen: tag HARI INI, avatar, banner preskripsi.
  final Color accentSoft;

  /// Baris set yang tercentang dan pil "+1 rep".
  final Color doneBg;
  final Color doneInk;

  /// Peringatan lembut: teks [warn] di atas [warnSoft].
  final Color warn;
  final Color warnSoft;

  /// Oranye hangat untuk lencana warm-up dan trofi rekor.
  final Color warm;

  final Color danger;

  /// Latar pilihan yang sedang aktif (= [accentSoft]).
  final Color selected;

  /// Batang grafik yang bukan sorotan.
  final Color chartIdle;

  /// Isian sparkline dan radar: dari [sparkTop] di garis ke [sparkBottom].
  final Color sparkTop;
  final Color sparkBottom;

  /// Siluet tubuh di belakang otot pada peta panas.
  final Color silhouette;

  /// Lima tingkat peta panas otot, rendah → tinggi. Diturunkan dari aksen.
  final List<Color> heatRamp;

  /// Lima tingkat kalender aktivitas, kosong → penuh.
  final List<Color> activityRamp;

  /// Cincin Beranda: lintasan dan tiga busur (sesi, set, volume).
  final Color ringTrack;
  final Color ringA;
  final Color ringB;
  final Color ringC;

  /// Thumb tab segmented dan tombol stepper — harus lebih terang dari
  /// [surface2] di kedua tema.
  final Color segThumb;

  /// Dua wash radial di latar Beranda (kiri atas hangat, kanan atas violet).
  final Color washA;
  final Color washB;

  /// Bayangan semua kartu.
  final BoxShadow cardShadow;

  /// Token permukaan kaca, mengikuti aksen.
  final GlassTokens glass;

  /// Warna pembeda: tile ikon, lencana, legenda.
  final GymHues hues;

  final Brightness brightness;

  /// Aksen seperti yang dipilih di Profil, sebelum disesuaikan untuk tema.
  final Color? accentBase;

  bool get isLight => brightness == Brightness.light;

  /// Latar tile untuk hue tanpa pasangan soft eksplisit: [hue] tipis di atas
  /// kartu.
  Color tint(Color hue) => Color.alphaBlend(hue.withValues(alpha: isLight ? 0.12 : 0.22), surface);

  static const dark = GymColors(
    bg: Color(0xFF0D0D10),
    bgNested: Color(0xFF141417),
    surface: Color(0xFF1C1C20),
    surface2: Color(0xFF26262B),
    border: Color(0xFF2F2F35),
    text: Color(0xFFF4F4F6),
    text2: Color(0xFFA1A1AA),
    text3: Color(0xFF6B6B74),
    accent: Color(0xFF8F7FFF),
    accentFill: Color(0xFF6C5CEB),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0xFF2A2546),
    doneBg: Color(0xFF15291C),
    doneInk: Color(0xFF4ADE80),
    warn: Color(0xFFFFAD5C),
    warnSoft: Color(0xFF3A2A17),
    warm: Color(0xFFFF8A3D),
    danger: Color(0xFFFF6B6B),
    selected: Color(0xFF2A2546),
    chartIdle: Color(0x338F7FFF),
    sparkTop: Color(0x558F7FFF),
    sparkBottom: Color(0x008F7FFF),
    silhouette: Color(0xFF2B2B32),
    heatRamp: [Color(0xFF2F2A4A), Color(0xFF4A4386), Color(0xFF6A61BA), Color(0xFF8A80E8), Color(0xFF8F7FFF)],
    activityRamp: [Color(0xFF26262B), Color(0xFF4A4386), Color(0xFF6A61BA), Color(0xFF8A80E8), Color(0xFF8F7FFF)],
    ringTrack: Color(0xFF2A2A30),
    ringA: Color(0xFFFFB020),
    ringB: Color(0xFF2FCB7E),
    ringC: Color(0xFF7C6CFF),
    segThumb: Color(0xFF3B3B44),
    washA: Color(0x663A214A),
    washB: Color(0x661E2A4A),
    cardShadow: BoxShadow(color: Color(0x0F14142B), offset: Offset(0, 4), blurRadius: 18),
    glass: GlassTokens.darkBase,
    hues: GymHues.dark,
    brightness: Brightness.dark,
  );

  /// Tema terang — tema utama mockup: kartu putih di atas `#F2F2F6`.
  static const light = GymColors(
    bg: Color(0xFFF2F2F6),
    bgNested: Color(0xFFF4F4F7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF4F4F7),
    border: Color(0xFFE7E7EC),
    text: Color(0xFF111114),
    text2: Color(0xFF6D6D76),
    text3: Color(0xFFA7A7B0),
    accent: Color(0xFF5B4BD6),
    accentFill: Color(0xFF5546D6),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFEEEBFD),
    doneBg: Color(0xFFE8F7EE),
    doneInk: Color(0xFF137544),
    warn: Color(0xFFA8560A),
    warnSoft: Color(0xFFFFF1E3),
    warm: Color(0xFFFF8A3D),
    danger: Color(0xFFD93A40),
    selected: Color(0xFFEEEBFD),
    chartIdle: Color(0x295B4BD6),
    sparkTop: Color(0x475B4BD6),
    sparkBottom: Color(0x005B4BD6),
    silhouette: Color(0xFFE1E1E8),
    heatRamp: [Color(0xFFD6D1F5), Color(0xFFBBB1F2), Color(0xFF9A8DEE), Color(0xFF7C6CE9), Color(0xFF5B4BD6)],
    activityRamp: [Color(0xFFF4F4F7), Color(0xFFBBB1F2), Color(0xFF9A8DEE), Color(0xFF7C6CE9), Color(0xFF5B4BD6)],
    ringTrack: Color(0xFFEFEFF3),
    ringA: Color(0xFFFFB020),
    ringB: Color(0xFF2FCB7E),
    ringC: Color(0xFF7C6CFF),
    segThumb: Color(0xFFFFFFFF),
    washA: Color(0xAAFFE3D1),
    washB: Color(0xAAE7E2FF),
    cardShadow: BoxShadow(color: Color(0x0F14142B), offset: Offset(0, 4), blurRadius: 18),
    glass: GlassTokens.lightBase,
    hues: GymHues.light,
    brightness: Brightness.light,
  );

  @override
  GymColors copyWith({
    Color? bg,
    Color? bgNested,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? text,
    Color? text2,
    Color? text3,
    Color? accent,
    Color? accentFill,
    Color? accentInk,
    Color? accentSoft,
    Color? doneBg,
    Color? doneInk,
    Color? warn,
    Color? warnSoft,
    Color? warm,
    Color? danger,
    Color? selected,
    Color? chartIdle,
    Color? sparkTop,
    Color? sparkBottom,
    List<Color>? heatRamp,
    List<Color>? activityRamp,
    Color? ringTrack,
    Color? segThumb,
    GlassTokens? glass,
    GymHues? hues,
    Color? accentBase,
  }) {
    return GymColors(
      bg: bg ?? this.bg,
      bgNested: bgNested ?? this.bgNested,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      accent: accent ?? this.accent,
      accentFill: accentFill ?? this.accentFill,
      accentInk: accentInk ?? this.accentInk,
      accentSoft: accentSoft ?? this.accentSoft,
      doneBg: doneBg ?? this.doneBg,
      doneInk: doneInk ?? this.doneInk,
      warn: warn ?? this.warn,
      warnSoft: warnSoft ?? this.warnSoft,
      warm: warm ?? this.warm,
      danger: danger ?? this.danger,
      selected: selected ?? this.selected,
      chartIdle: chartIdle ?? this.chartIdle,
      sparkTop: sparkTop ?? this.sparkTop,
      sparkBottom: sparkBottom ?? this.sparkBottom,
      silhouette: silhouette,
      heatRamp: heatRamp ?? this.heatRamp,
      activityRamp: activityRamp ?? this.activityRamp,
      ringTrack: ringTrack ?? this.ringTrack,
      ringA: ringA,
      ringB: ringB,
      ringC: ringC,
      segThumb: segThumb ?? this.segThumb,
      washA: washA,
      washB: washB,
      cardShadow: cardShadow,
      glass: glass ?? this.glass,
      hues: hues ?? this.hues,
      brightness: brightness,
      accentBase: accentBase ?? this.accentBase,
    );
  }

  @override
  GymColors lerp(ThemeExtension<GymColors>? other, double t) {
    if (other is! GymColors) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return GymColors(
      bg: m(bg, other.bg),
      bgNested: m(bgNested, other.bgNested),
      surface: m(surface, other.surface),
      surface2: m(surface2, other.surface2),
      border: m(border, other.border),
      text: m(text, other.text),
      text2: m(text2, other.text2),
      text3: m(text3, other.text3),
      accent: m(accent, other.accent),
      accentFill: m(accentFill, other.accentFill),
      accentInk: m(accentInk, other.accentInk),
      accentSoft: m(accentSoft, other.accentSoft),
      doneBg: m(doneBg, other.doneBg),
      doneInk: m(doneInk, other.doneInk),
      warn: m(warn, other.warn),
      warnSoft: m(warnSoft, other.warnSoft),
      warm: m(warm, other.warm),
      danger: m(danger, other.danger),
      selected: m(selected, other.selected),
      chartIdle: m(chartIdle, other.chartIdle),
      sparkTop: m(sparkTop, other.sparkTop),
      sparkBottom: m(sparkBottom, other.sparkBottom),
      silhouette: m(silhouette, other.silhouette),
      heatRamp: [for (var i = 0; i < heatRamp.length; i++) m(heatRamp[i], other.heatRamp[i])],
      activityRamp: [for (var i = 0; i < activityRamp.length; i++) m(activityRamp[i], other.activityRamp[i])],
      ringTrack: m(ringTrack, other.ringTrack),
      ringA: m(ringA, other.ringA),
      ringB: m(ringB, other.ringB),
      ringC: m(ringC, other.ringC),
      segThumb: m(segThumb, other.segThumb),
      washA: m(washA, other.washA),
      washB: m(washB, other.washB),
      cardShadow: BoxShadow.lerp(cardShadow, other.cardShadow, t)!,
      glass: glass.lerp(other.glass, t),
      hues: t < 0.5 ? hues : other.hues,
      brightness: t < 0.5 ? brightness : other.brightness,
      accentBase: t < 0.5 ? accentBase : other.accentBase,
    );
  }
}

/// Token permukaan kaca (spec §1). Untuk aksen violet bawaan nilainya persis
/// dari Pen; aksen lain diturunkan di [fromAccent].
@immutable
class GlassTokens {
  const GlassTokens({
    required this.tintA,
    required this.tintB,
    required this.glow,
    required this.clear,
    required this.bar,
    required this.edgeTop,
    required this.edgeLow,
  });

  /// Gradien isian kaca berwarna: atas → bawah.
  final Color tintA;
  final Color tintB;

  /// Bayangan berwarna di bawah kaca berwarna.
  final Color glow;

  /// Isian kaca bening (tombol sekunder, chip, tombol ikon).
  final Color clear;

  /// Isian bilah yang mengapung (tab bar, pil istirahat).
  final Color bar;

  /// Tepi 1 px: terang di atas dan bawah, redup di tengah.
  final Color edgeTop;
  final Color edgeLow;

  /// Kilau di separuh atas setiap permukaan kaca.
  static const sheenTop = Color(0x5CFFFFFF);

  static const lightBase = GlassTokens(
    tintA: Color(0xF27A6AF2),
    tintB: Color(0xEB5546D6),
    glow: Color(0x4D5546D6),
    clear: Color(0xCCECECF3),
    bar: Color(0xBFFFFFFF),
    edgeTop: Color(0xE6FFFFFF),
    edgeLow: Color(0x33FFFFFF),
  );

  static const darkBase = GlassTokens(
    tintA: Color(0xE6A396FF),
    tintB: Color(0xD96C5CEB),
    glow: Color(0x596C5CEB),
    clear: Color(0x1AFFFFFF),
    bar: Color(0xBF1E1E24),
    edgeTop: Color(0x59FFFFFF),
    edgeLow: Color(0x0DFFFFFF),
  );

  /// Gradien dari aksen pilihan: atas sedikit lebih terang dari [fill],
  /// bawah = [fill]. [fill] yang sama dengan nilai Pen memakai token Pen apa
  /// adanya.
  static GlassTokens fromAccent(Color fill, Color accent, {required bool light}) {
    final base = light ? lightBase : darkBase;
    if (fill.toARGB32() == (light ? 0xFF5546D6 : 0xFF6C5CEB)) return base;
    final hsl = HSLColor.fromColor(fill);
    final top = light ? hsl.withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0)).toColor() : accent;
    return GlassTokens(
      tintA: top.withValues(alpha: light ? 0.95 : 0.90),
      // Di tema terang isiannya lebih pekat: 8 % latar terang yang menembus
      // sudah cukup menurunkan kontras teks putih di bawah 4,5:1.
      tintB: fill.withValues(alpha: light ? 0.96 : 0.85),
      glow: fill.withValues(alpha: light ? 0.30 : 0.35),
      clear: base.clear,
      bar: base.bar,
      edgeTop: base.edgeTop,
      edgeLow: base.edgeLow,
    );
  }

  GlassTokens lerp(GlassTokens o, double t) => GlassTokens(
        tintA: Color.lerp(tintA, o.tintA, t)!,
        tintB: Color.lerp(tintB, o.tintB, t)!,
        glow: Color.lerp(glow, o.glow, t)!,
        clear: Color.lerp(clear, o.clear, t)!,
        bar: Color.lerp(bar, o.bar, t)!,
        edgeTop: Color.lerp(edgeTop, o.edgeTop, t)!,
        edgeLow: Color.lerp(edgeLow, o.edgeLow, t)!,
      );
}

/// Warna pembeda. Bukan untuk makna tetap (merah = bahaya tetap
/// [GymColors.danger]); ini untuk membedakan satu tile dari tile di
/// sebelahnya: rutinitas Push/Pull/Legs, KPI Sesi/Set/Volume.
///
/// Tiap hue punya **ink** (ikon/teks) dan **soft** (latar tile). Violet
/// mengikuti aksen pilihan pengguna.
@immutable
class GymHues {
  const GymHues({
    required this.violet,
    required this.pink,
    required this.cyan,
    required this.orange,
    required this.lime,
    required this.green,
    required this.pinkSoft,
    required this.cyanSoft,
    required this.orangeSoft,
  });

  final Color violet;
  final Color pink;
  final Color cyan;
  final Color orange;
  final Color lime;
  final Color green;

  final Color pinkSoft;
  final Color cyanSoft;
  final Color orangeSoft;

  /// Urutan bergilir untuk daftar (rutinitas, kategori).
  List<Color> get cycle => [violet, pink, cyan, orange, green, lime];

  /// Warna ke-[i] dari giliran, berputar.
  Color at(int i) => cycle[i % cycle.length];

  /// Latar tile untuk [ink]: pasangan soft kalau ada, kalau tidak tint.
  Color soft(Color ink, GymColors c) {
    if (ink == violet) return c.accentSoft;
    if (ink == pink) return pinkSoft;
    if (ink == cyan) return cyanSoft;
    if (ink == orange) return orangeSoft;
    return c.tint(ink);
  }

  GymHues copyWith({Color? violet}) => GymHues(
        violet: violet ?? this.violet,
        pink: pink,
        cyan: cyan,
        orange: orange,
        lime: lime,
        green: green,
        pinkSoft: pinkSoft,
        cyanSoft: cyanSoft,
        orangeSoft: orangeSoft,
      );

  static const dark = GymHues(
    violet: Color(0xFF8F7FFF),
    pink: Color(0xFFFF7FC0),
    cyan: Color(0xFF5ED3EE),
    orange: Color(0xFFFFAD5C),
    lime: Color(0xFFD9FF5C),
    green: Color(0xFF34D399),
    pinkSoft: Color(0xFF3A1F2E),
    cyanSoft: Color(0xFF14303A),
    orangeSoft: Color(0xFF3A2A17),
  );

  /// Versi terang: ink cukup gelap untuk ikon dan angka di atas kartu putih.
  static const light = GymHues(
    violet: Color(0xFF5B4BD6),
    pink: Color(0xFFC42F7D),
    cyan: Color(0xFF0F7F9A),
    orange: Color(0xFFB85C08),
    lime: Color(0xFF4D7C0F),
    green: Color(0xFF15803D),
    pinkSoft: Color(0xFFFFE6F2),
    cyanSoft: Color(0xFFE1F6FB),
    orangeSoft: Color(0xFFFFF0E1),
  );
}

extension GymColorsX on BuildContext {
  GymColors get gym => Theme.of(this).extension<GymColors>()!;
}

/// Radius sudut (spec §3).
abstract final class GymRadius {
  /// Sel kalender aktivitas.
  static const cell = 2.5;

  /// Batang grafik (atas).
  static const bar = 6.0;

  /// Kotak centang peralatan.
  static const check = 8.0;

  /// Pil KG/REPS di tabel set, kotak input.
  static const input = 12.0;

  /// Thumb tab segmented.
  static const segment = 12.0;

  /// Lintasan tab segmented, chip.
  static const segTrack = 16.0;
  static const chip = 16.0;

  /// Tile ikon kecil, tombol aksi kecil.
  static const small = 12.0;

  /// Tombol stepper, kotak tanggal.
  static const stepper = 12.0;

  /// Field, baris daftar, tile ikon 44.
  static const control = 14.0;

  /// Kartu kecil: baris sesi, KPI, baris rutinitas di lembar.
  static const tile = 18.0;

  /// Grup setelan, kartu rutinitas di kisi Program.
  static const group = 20.0;

  /// Kartu standar.
  static const card = 22.0;

  /// Kartu besar — sama dengan kartu standar di v3.
  static const large = 22.0;

  /// Kartu "Sesi berikutnya" di Beranda.
  static const hero = 22.0;

  /// Tombol utama setinggi 52.
  static const button = 26.0;

  /// Sheet, hanya sudut atas.
  static const sheet = 28.0;

  /// Tab bar yang mengapung.
  static const nav = 33.0;

  static const pill = 999.0;
}

/// Pilihan warna aksen di Profil. Violet dulu — itu aksen mockup.
const accentChoices = <Color>[
  Color(0xFF8F7FFF),
  Color(0xFF5AC8FA),
  Color(0xFF4ADE80),
  Color(0xFFFF9F43),
  Color(0xFFFF7AB6),
];

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Gelapkan [c] sampai kontrasnya terhadap [against] ≥ [target].
Color _darkenUntil(Color c, Color against, double target) {
  var hsl = HSLColor.fromColor(c);
  while (_contrast(hsl.toColor(), against) < target && hsl.lightness > 0.05) {
    hsl = hsl.withLightness(hsl.lightness - 0.02);
  }
  return hsl.toColor();
}

/// Latar tombol/kaca dari aksen: cukup gelap supaya teks putih ≥ 4,5:1 (di
/// tema terang ≥ 5:1, karena kaca menembuskan sedikit latar terang). Lima
/// pilihan bawaan punya padanan yang sudah ditentukan supaya warnanya tetap
/// enak, bukan sekadar lolos angka.
Color _fillFor(Color accent, {required bool light}) {
  final pairs = light
      ? const {
          0xFF8F7FFF: 0xFF5546D6,
          0xFF5AC8FA: 0xFF0877B0,
          0xFF4ADE80: 0xFF15803D,
          0xFFFF9F43: 0xFFB9520B,
          0xFFFF7AB6: 0xFFBE2468,
        }
      : const {
          0xFF8F7FFF: 0xFF6C5CEB,
          0xFF5AC8FA: 0xFF0877B0,
          0xFF4ADE80: 0xFF15803D,
          0xFFFF9F43: 0xFFB9520B,
          0xFFFF7AB6: 0xFFBE2468,
        };
  final known = pairs[accent.toARGB32()];
  return _darkenUntil(known == null ? accent : Color(known), Colors.white, light ? 5.0 : 4.6);
}

/// Aksen versi tema terang: pilihan Profil dirancang untuk latar gelap dan
/// terlalu pucat di atas putih. Digelapkan sampai ≥ 4,6:1 di atas latar
/// terang — bukan di atas putih, karena di Beranda aksen dipakai sebagai
/// teks tautan langsung di atas [GymColors.bg].
Color lightAccent(Color accent) {
  const pairs = {
    0xFF8F7FFF: 0xFF5B4BD6,
    0xFF5AC8FA: 0xFF0877B0,
    0xFF4ADE80: 0xFF15803D,
    0xFFFF9F43: 0xFFB9520B,
    0xFFFF7AB6: 0xFFBE2468,
  };
  final known = pairs[accent.toARGB32()];
  return _darkenUntil(known == null ? accent : Color(known), GymColors.light.bg, 4.6);
}

/// Lima tingkat dari [from] ke [to]; untuk ramp peta panas dan kalender.
List<Color> _ramp(Color from, Color to) => [for (final t in const [0.0, 0.25, 0.5, 0.75, 1.0]) Color.lerp(from, to, t)!];

ThemeData buildGymTheme({Color? accent, Brightness brightness = Brightness.dark}) {
  final base = brightness == Brightness.light ? GymColors.light : GymColors.dark;
  final pick = accent ?? accentChoices.first;
  final light = brightness == Brightness.light;
  final isDefault = pick.toARGB32() == accentChoices.first.toARGB32();
  final shownAccent = light ? lightAccent(pick) : pick;
  final fill = _fillFor(pick, light: light);
  final heat0 = Color.alphaBlend(shownAccent.withValues(alpha: light ? 0.25 : 0.18), base.surface);
  final heat = isDefault ? base.heatRamp : _ramp(heat0, shownAccent);
  final soft = isDefault ? base.accentSoft : Color.alphaBlend(shownAccent.withValues(alpha: light ? 0.12 : 0.22), base.surface);
  final c = base.copyWith(
    accent: shownAccent,
    accentFill: fill,
    accentSoft: soft,
    accentBase: pick,
    selected: soft,
    chartIdle: shownAccent.withValues(alpha: light ? 0.16 : 0.20),
    sparkTop: shownAccent.withValues(alpha: light ? 0.28 : 0.33),
    sparkBottom: shownAccent.withValues(alpha: 0),
    // Ramp mengikuti aksen pilihan: peta panas hijau untuk yang memilih
    // aksen hijau, bukan tetap ungu.
    heatRamp: heat,
    activityRamp: [base.surface2, heat[1], heat[2], heat[3], shownAccent],
    glass: GlassTokens.fromAccent(fill, shownAccent, light: light),
    hues: base.hues.copyWith(violet: shownAccent),
  );
  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: brightness,
  ).copyWith(
    primary: c.accentFill,
    onPrimary: c.accentInk,
    secondary: c.accent,
    surface: c.surface,
    onSurface: c.text,
    error: c.danger,
  );

  // Inter di-bundle (lima berat, 400–800) dan dipakai untuk semuanya — judul,
  // angka, isi — seperti mockup. Satu keluarga, offline-first.
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    splashFactory: InkSparkle.splashFactory,
    extensions: [c],
    // iOS memakai geser bawaannya (ibu jari sudah hafal gerak kembali dari
    // tepi). Android memakai fade-forward Material 3, yang ikut predictive back.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
    textTheme: TextTheme(
      displaySmall: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -0.6, color: c.text),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.6, color: c.text),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.3, color: c.text),
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2, color: c.text),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
      bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: c.text2),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.text2),
    ),
    // Dialog, sheet, snackbar, dan chip dari Material ikut palet, bukan warna
    // turunan seed.
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.card)),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.bg, modalBackgroundColor: c.bg),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      shadowColor: const Color(0x3314142B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.control)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.accentFill,
      disabledColor: c.surface2,
      side: BorderSide(color: c.border),
      shape: const StadiumBorder(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text),
      secondaryLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accentInk),
      iconTheme: IconThemeData(size: 16, color: c.text2),
    ),
    switchTheme: SwitchThemeData(
      // OFF memakai text2: thumb putih di lintasan surface2 di atas kartu putih
      // nyaris tak terlihat di tema terang (≈1,1:1).
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : c.text2),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.doneInk : c.surface2),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: light ? const Color(0xFF26262B) : c.surface2,
      contentTextStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFFF4F4F6)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.control)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
