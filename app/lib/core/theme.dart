import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Token desain GymApps v2, mengikuti referensi `REFRENSI/NEW REFRENSI/`
/// (UI kit "Diet Adviser"): latar hampir hitam, kartu abu gelap tanpa garis
/// tepi, aksen ungu-violet, ikon di dalam cakram bulat berwarna, dan blok
/// statistik berwarna penuh.
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
    required this.danger,
    required this.selected,
    required this.chartIdle,
    required this.silhouette,
    required this.heatRamp,
    required this.activityRamp,
    required this.hues,
    required this.brightness,
    this.accentBase,
  });

  /// Latar layar. Hampir hitam, bukan hitam murni, supaya kartu abu gelap di
  /// atasnya masih terbaca sebagai kartu.
  final Color bg;

  /// Latar di dalam kartu — tabel set, preview gerakan.
  final Color bgNested;

  /// Kartu. Referensi tidak memberi kartu garis tepi; yang memisahkannya dari
  /// latar hanya selisih terang.
  final Color surface;

  /// Chip, tombol netral, dan kotak input di atas kartu.
  final Color surface2;

  /// Garis pemisah tipis. Hampir tak terlihat, dan memang begitu maksudnya:
  /// dipakai untuk pembatas baris, bukan bingkai kartu.
  final Color border;

  /// NFR-11 minta kontras teks ≥ 4,5:1. [text2] di atas [surface] ≈ 6,6:1.
  /// [text3] di bawah ambang itu — hanya untuk elemen dekoratif yang tidak
  /// membawa informasi.
  final Color text;
  final Color text2;
  final Color text3;

  /// Aksen untuk ikon, teks, dan tanda di atas latar gelap. Di tema gelap ini
  /// lavender terang, terlalu pucat untuk latar tombol berteks putih — untuk
  /// itu ada [accentFill].
  final Color accent;

  /// Latar tombol utama, tab terpilih, chip terpilih: versi aksen yang cukup
  /// gelap supaya [accentInk] (putih) di atasnya ≥ 4,5:1.
  final Color accentFill;
  final Color accentInk;
  final Color accentSoft;

  /// Baris set yang tercentang (FR-D3): latar hijau gelap, angka tetap putih —
  /// membaca beban saat latihan lebih penting daripada penandaan.
  final Color doneBg;
  final Color doneInk;

  final Color warn;
  final Color danger;

  /// Latar pilihan yang sedang aktif: kartu template terpilih, panel istirahat.
  final Color selected;

  /// Batang grafik yang bukan batang terakhir.
  final Color chartIdle;

  /// Siluet tubuh di belakang otot pada peta panas.
  final Color silhouette;

  /// Lima tingkat peta panas otot, rendah → tinggi. Diturunkan dari aksen.
  final List<Color> heatRamp;

  /// Lima tingkat kalender aktivitas, kosong → penuh. Diturunkan dari aksen.
  final List<Color> activityRamp;

  /// Warna-warna pembeda dari referensi: cakram ikon, blok statistik, legenda.
  final GymHues hues;

  final Brightness brightness;

  /// Aksen seperti yang dipilih di Profil, sebelum disesuaikan untuk tema.
  /// Dipakai untuk menandai pilihan yang aktif.
  final Color? accentBase;

  bool get isLight => brightness == Brightness.light;

  /// Latar cakram ikon atau blok berwarna: [hue] tipis di atas kartu, cukup
  /// pekat untuk terlihat berwarna tapi tidak menelan ikonnya.
  Color tint(Color hue) => Color.alphaBlend(hue.withValues(alpha: isLight ? 0.14 : 0.20), surface);

  /// Latar blok statistik: lebih pekat dari [tint], seperti kartu "Weight" dan
  /// "Calories" di referensi.
  Color block(Color hue) => Color.alphaBlend(hue.withValues(alpha: isLight ? 0.18 : 0.30), surface);

  static const dark = GymColors(
    bg: Color(0xFF0C0C0F),
    bgNested: Color(0xFF141417),
    surface: Color(0xFF1B1B1F),
    surface2: Color(0xFF26262C),
    border: Color(0xFF232328),
    text: Color(0xFFF4F4F6),
    text2: Color(0xFFA0A0AA),
    text3: Color(0xFF6F6F7A),
    accent: Color(0xFF8F7FFF),
    accentFill: Color(0xFF6A5AE6),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0x2E8F7FFF),
    doneBg: Color(0xFF163126),
    doneInk: Color(0xFF4ADE80),
    warn: Color(0xFFFFA94D),
    danger: Color(0xFFFF5C5C),
    selected: Color(0xFF1F1B36),
    chartIdle: Color(0xFF34333F),
    silhouette: Color(0xFF232328),
    heatRamp: [Color(0xFF26262C), Color(0xFF3C3660), Color(0xFF574C9E), Color(0xFF7466D2), Color(0xFF8F7FFF)],
    activityRamp: [Color(0xFF212126), Color(0xFF3C3660), Color(0xFF574C9E), Color(0xFF7466D2), Color(0xFF8F7FFF)],
    hues: GymHues.dark,
    brightness: Brightness.dark,
  );

  /// Tema terang: kartu putih di atas abu-abu sangat muda. Teks sekunder
  /// #5B5B68 ≈ 6,9:1 di atas putih (NFR-11 minta ≥ 4,5:1). Aksen digelapkan
  /// (lihat [lightAccent]) karena lavender di atas putih hanya ≈ 2,6:1.
  static const light = GymColors(
    bg: Color(0xFFF4F4F7),
    bgNested: Color(0xFFEEEEF3),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFECECF2),
    border: Color(0xFFE3E3EA),
    text: Color(0xFF111118),
    text2: Color(0xFF5B5B68),
    text3: Color(0xFF7A7A88),
    accent: Color(0xFF5B4BD6),
    accentFill: Color(0xFF5B4BD6),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0x1F5B4BD6),
    doneBg: Color(0xFFE2F6E8),
    doneInk: Color(0xFF166534),
    warn: Color(0xFFB45309),
    danger: Color(0xFFD02A24),
    selected: Color(0xFFEDEAFF),
    chartIdle: Color(0xFFD6D6E4),
    silhouette: Color(0xFFE3E3EA),
    heatRamp: [Color(0xFFE6E6EF), Color(0xFFC9C3F3), Color(0xFFA79DEA), Color(0xFF8072E0), Color(0xFF5B4BD6)],
    activityRamp: [Color(0xFFE6E6EF), Color(0xFFC9C3F3), Color(0xFFA79DEA), Color(0xFF8072E0), Color(0xFF5B4BD6)],
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
    Color? danger,
    Color? selected,
    Color? chartIdle,
    List<Color>? heatRamp,
    List<Color>? activityRamp,
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
      danger: danger ?? this.danger,
      selected: selected ?? this.selected,
      chartIdle: chartIdle ?? this.chartIdle,
      silhouette: silhouette,
      heatRamp: heatRamp ?? this.heatRamp,
      activityRamp: activityRamp ?? this.activityRamp,
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
      danger: m(danger, other.danger),
      selected: m(selected, other.selected),
      chartIdle: m(chartIdle, other.chartIdle),
      silhouette: m(silhouette, other.silhouette),
      heatRamp: [for (var i = 0; i < heatRamp.length; i++) m(heatRamp[i], other.heatRamp[i])],
      activityRamp: [for (var i = 0; i < activityRamp.length; i++) m(activityRamp[i], other.activityRamp[i])],
      hues: t < 0.5 ? hues : other.hues,
      brightness: t < 0.5 ? brightness : other.brightness,
      accentBase: t < 0.5 ? accentBase : other.accentBase,
    );
  }
}

/// Warna pembeda dari referensi. Bukan untuk makna tetap (merah = bahaya
/// tetap [GymColors.danger]); ini untuk membedakan satu blok dari blok di
/// sebelahnya, seperti kartu "Water / Weight / Calories / BPM".
@immutable
class GymHues {
  const GymHues({
    required this.violet,
    required this.pink,
    required this.cyan,
    required this.orange,
    required this.lime,
    required this.green,
  });

  final Color violet;
  final Color pink;
  final Color cyan;
  final Color orange;
  final Color lime;
  final Color green;

  /// Urutan bergilir untuk daftar (ikon setelan, kategori).
  List<Color> get cycle => [violet, pink, cyan, orange, green, lime];

  /// Warna ke-[i] dari giliran, berputar.
  Color at(int i) => cycle[i % cycle.length];

  static const dark = GymHues(
    violet: Color(0xFF8F7FFF),
    pink: Color(0xFFFF5FB0),
    cyan: Color(0xFF22D3EE),
    orange: Color(0xFFFFA94D),
    lime: Color(0xFFD9FF5C),
    green: Color(0xFF34D399),
  );

  /// Versi terang: cukup gelap untuk dipakai sebagai warna ikon dan angka di
  /// atas kartu putih.
  static const light = GymHues(
    violet: Color(0xFF5B4BD6),
    pink: Color(0xFFC81E78),
    cyan: Color(0xFF0E7C8C),
    orange: Color(0xFFB9520B),
    lime: Color(0xFF4D7C0F),
    green: Color(0xFF15803D),
  );
}

extension GymColorsX on BuildContext {
  GymColors get gym => Theme.of(this).extension<GymColors>()!;
}

/// Radius sudut. Referensi memakai sudut yang lebih bulat dari desain lama:
/// kartu ±20, tombol utama pil penuh, nav bawah pil melayang.
abstract final class GymRadius {
  /// Sel kalender aktivitas.
  static const cell = 3.0;

  /// Batang grafik.
  static const bar = 6.0;

  /// Kotak centang peralatan.
  static const check = 8.0;

  /// Kotak input kg/rep di tabel set.
  static const input = 10.0;

  /// Segmen terpilih di dalam tab segmented, kotak konfigurasi editor.
  static const segment = 12.0;

  /// Kotak ikon, thumbnail, tombol aksi kecil, "Add set".
  static const small = 12.0;

  /// Tombol stepper, preset istirahat, kotak tanggal.
  static const stepper = 12.0;

  /// Field, baris daftar, tombol sekunder, "Add exercise".
  static const control = 14.0;

  /// Kartu standar.
  static const card = 20.0;

  /// Kartu besar — panel istirahat, kartu gerakan, kartu Stats.
  static const large = 22.0;

  /// Kartu "Next session" di Home.
  static const hero = 24.0;

  /// Sheet durasi istirahat, hanya sudut atas.
  static const sheet = 28.0;

  /// Nav bawah yang melayang.
  static const nav = 26.0;

  static const pill = 999.0;
}

/// Pilihan warna aksen di Profil. Violet dulu — itu aksen referensi.
const accentChoices = <Color>[
  Color(0xFF8F7FFF),
  Color(0xFF5AC8FA),
  Color(0xFF4ADE80),
  Color(0xFFFF9F43),
  Color(0xFFFF7AB6),
];

double _contrastOnWhite(Color c) => 1.05 / (c.computeLuminance() + 0.05);

/// Gelapkan [accent] sampai teks putih di atasnya ≥ 4,5:1. Lima pilihan
/// bawaan punya padanan yang sudah ditentukan supaya warnanya tetap enak,
/// bukan sekadar lolos angka; warna lain digelapkan lewat HSL.
Color _fillFor(Color accent) {
  const pairs = {
    0xFF8F7FFF: 0xFF6A5AE6,
    0xFF5AC8FA: 0xFF0877B0,
    0xFF4ADE80: 0xFF15803D,
    0xFFFF9F43: 0xFFB9520B,
    0xFFFF7AB6: 0xFFBE2468,
  };
  final known = pairs[accent.toARGB32()];
  var hsl = HSLColor.fromColor(known == null ? accent : Color(known));
  while (_contrastOnWhite(hsl.toColor()) < 4.6 && hsl.lightness > 0.05) {
    hsl = hsl.withLightness(hsl.lightness - 0.02);
  }
  return hsl.toColor();
}

/// Aksen versi tema terang: pilihan Profil dirancang untuk latar gelap dan
/// terlalu pucat di atas putih. Di tema terang aksen ikon/teks dan latar
/// tombol sama-sama memakai versi gelap ini.
Color lightAccent(Color accent) {
  const pairs = {
    0xFF8F7FFF: 0xFF5B4BD6,
    0xFF5AC8FA: 0xFF0877B0,
    0xFF4ADE80: 0xFF15803D,
    0xFFFF9F43: 0xFFB9520B,
    0xFFFF7AB6: 0xFFBE2468,
  };
  final known = pairs[accent.toARGB32()];
  var hsl = HSLColor.fromColor(known == null ? accent : Color(known));
  while (_contrastOnWhite(hsl.toColor()) < 4.6 && hsl.lightness > 0.05) {
    hsl = hsl.withLightness(hsl.lightness - 0.02);
  }
  return hsl.toColor();
}

/// Lima tingkat dari [from] ke [to]; untuk ramp peta panas dan kalender.
List<Color> _ramp(Color from, Color to) =>
    [for (final t in const [0.0, 0.28, 0.52, 0.76, 1.0]) Color.lerp(from, to, t)!];

ThemeData buildGymTheme({Color? accent, Brightness brightness = Brightness.dark}) {
  final base = brightness == Brightness.light ? GymColors.light : GymColors.dark;
  final pick = accent ?? GymColors.dark.accent;
  final light = brightness == Brightness.light;
  final shownAccent = light ? lightAccent(pick) : pick;
  final fill = light ? shownAccent : _fillFor(pick);
  final c = base.copyWith(
    accent: shownAccent,
    accentFill: fill,
    accentSoft: shownAccent.withValues(alpha: light ? 0.12 : 0.18),
    accentBase: pick,
    selected: Color.alphaBlend(shownAccent.withValues(alpha: light ? 0.10 : 0.16), base.surface),
    chartIdle: Color.lerp(base.surface2, shownAccent, light ? 0.18 : 0.22),
    // Ramp mengikuti aksen pilihan: peta panas hijau untuk yang memilih
    // aksen hijau, bukan tetap ungu.
    heatRamp: _ramp(base.surface2, shownAccent),
    activityRamp: _ramp(light ? base.bgNested : const Color(0xFF212126), shownAccent),
    hues: light ? base.hues : GymHues(
      violet: pick,
      pink: base.hues.pink,
      cyan: base.hues.cyan,
      orange: base.hues.orange,
      lime: base.hues.lime,
      green: base.hues.green,
    ),
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

  // Inter di-bundle, sama seperti sebelumnya. Lima berat yang benar-benar
  // dipakai saja (400–800) — 1,6 MB, masih jauh di bawah NFR-3 (≤ 25 MB) —
  // dan di-bundle, bukan diambil saat runtime, supaya janji offline-first
  // tidak bergantung pada unduhan font.
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
    // Judul dan angka besar memakai Barlow Condensed — condensed tebal khas
    // aplikasi olahraga, dan pembeda dari Inter yang dipakai semua orang.
    // Teks isi tetap Inter supaya angka beban dan nama gerakan mudah dibaca.
    textTheme: TextTheme(
      displaySmall: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 44, fontWeight: FontWeight.w800, height: 1.0, color: c.text),
      headlineMedium: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 32, fontWeight: FontWeight.w700, height: 1.05, color: c.text),
      titleLarge: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 24, fontWeight: FontWeight.w700, height: 1.1, color: c.text),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
      bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text2),
      labelSmall: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: c.text2),
    ),
    // Dialog, sheet, snackbar, dan chip dari Material ikut palet, bukan warna
    // turunan seed.
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.surface, modalBackgroundColor: c.surface),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.control)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface2,
      selectedColor: c.accentFill,
      disabledColor: c.surface2,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text),
      secondaryLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accentInk),
      iconTheme: IconThemeData(size: 16, color: c.text2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accentInk : c.text2),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accentFill : c.surface2),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surface2,
      contentTextStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.control)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
