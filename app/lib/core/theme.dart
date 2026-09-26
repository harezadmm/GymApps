import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Token desain GymApps, diambil dari artboard Pen di `REFRENSI/export/`.
///
/// Dipisah dari [ThemeData] karena beberapa warna tidak punya slot di Material:
/// hijau baris set selesai, latar bersarang di dalam kartu, dan tiga tingkat
/// teks. Widget membaca lewat `context.gym` (lihat [GymColorsX]) supaya tidak
/// ada nilai hex yang tersebar di layar.
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
    required this.brightness,
    this.accentBase,
  });

  /// Latar pilihan yang sedang aktif: kartu template terpilih, panel istirahat.
  final Color selected;

  /// Batang grafik yang bukan batang terakhir.
  final Color chartIdle;

  /// Siluet tubuh di belakang otot pada peta panas.
  final Color silhouette;

  /// Lima tingkat peta panas otot, rendah → tinggi.
  final List<Color> heatRamp;

  /// Lima tingkat kalender aktivitas, kosong → penuh.
  final List<Color> activityRamp;

  final Brightness brightness;

  /// Aksen seperti yang dipilih di Profil, sebelum digelapkan untuk tema
  /// terang. Dipakai untuk menandai pilihan yang aktif.
  final Color? accentBase;

  bool get isLight => brightness == Brightness.light;

  /// Latar layar. Navy sangat gelap, bukan hitam murni: kartu tetap terbaca
  /// sebagai kartu di gym yang terang, dan layar OLED tetap hemat.
  final Color bg;

  /// Latar di dalam kartu — tabel set, preview gerakan.
  final Color bgNested;

  final Color surface;
  final Color surface2;
  final Color border;

  /// NFR-11 minta kontras teks ≥ 4,5:1. [text2] (#8C95A8 di atas surface)
  /// ≈ 6,4:1. [text3] di bawah ambang itu — hanya untuk elemen dekoratif yang
  /// tidak membawa informasi.
  final Color text;
  final Color text2;
  final Color text3;

  /// Biru langit Liftoff (PRD §14). Terlalu terang untuk label putih, jadi teks
  /// di atasnya memakai [accentInk].
  final Color accent;
  final Color accentInk;
  final Color accentSoft;

  /// Baris set yang tercentang (FR-D3): latar hijau gelap, angka tetap putih —
  /// membaca beban saat latihan lebih penting daripada penandaan.
  final Color doneBg;
  final Color doneInk;

  final Color warn;
  final Color danger;

  static const dark = GymColors(
    bg: Color(0xFF080B12),
    bgNested: Color(0xFF0E1220),
    surface: Color(0xFF141925),
    surface2: Color(0xFF1C2231),
    border: Color(0xFF252C3D),
    text: Color(0xFFF2F5FA),
    text2: Color(0xFF8C95A8),
    text3: Color(0xFF7A8192),
    accent: Color(0xFF5AC8FA),
    accentInk: Color(0xFF04121C),
    accentSoft: Color(0x1F5AC8FA),
    doneBg: Color(0xFF16321C),
    doneInk: Color(0xFF4ADE80),
    warn: Color(0xFFF5A623),
    danger: Color(0xFFF0554E),
    selected: Color(0xFF10263A),
    chartIdle: Color(0xFF25405A),
    silhouette: Color(0xFF19212E),
    heatRamp: [Color(0xFF1B2536), Color(0xFF1E4258), Color(0xFF2A7FA8), Color(0xFF3FA8DC), Color(0xFF5AC8FA)],
    activityRamp: [Color(0xFF161C29), Color(0xFF173042), Color(0xFF1E5878), Color(0xFF2E93C6), Color(0xFF5AC8FA)],
    brightness: Brightness.dark,
  );

  /// Tema terang: kartu putih di atas abu-abu sangat muda. Teks sekunder
  /// #566074 ≈ 6,3:1 di atas putih (NFR-11 minta ≥ 4,5:1). Aksen digelapkan
  /// (lihat [lightAccent]) karena biru langit di atas putih hanya ≈ 1,9:1.
  static const light = GymColors(
    bg: Color(0xFFF3F5F9),
    bgNested: Color(0xFFF0F3F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEDF1F6),
    border: Color(0xFFDFE4EC),
    text: Color(0xFF0F1522),
    text2: Color(0xFF566074),
    text3: Color(0xFF6A7284),
    accent: Color(0xFF0877B0),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0x1F0877B0),
    doneBg: Color(0xFFE2F6E8),
    doneInk: Color(0xFF166534),
    warn: Color(0xFFB45309),
    danger: Color(0xFFD02A24),
    selected: Color(0xFFE3F1FA),
    chartIdle: Color(0xFFC8D6E4),
    silhouette: Color(0xFFE3E8EF),
    heatRamp: [Color(0xFFE6EBF2), Color(0xFFC3E0F2), Color(0xFF86C5E8), Color(0xFF3E9FD3), Color(0xFF0877B0)],
    activityRamp: [Color(0xFFE6EBF2), Color(0xFFC3E0F2), Color(0xFF86C5E8), Color(0xFF3E9FD3), Color(0xFF0877B0)],
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
    Color? accentInk,
    Color? accentSoft,
    Color? doneBg,
    Color? doneInk,
    Color? warn,
    Color? danger,
    Color? selected,
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
      accentInk: accentInk ?? this.accentInk,
      accentSoft: accentSoft ?? this.accentSoft,
      doneBg: doneBg ?? this.doneBg,
      doneInk: doneInk ?? this.doneInk,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
      selected: selected ?? this.selected,
      chartIdle: chartIdle,
      silhouette: silhouette,
      heatRamp: heatRamp,
      activityRamp: activityRamp,
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
      brightness: t < 0.5 ? brightness : other.brightness,
      accentBase: t < 0.5 ? accentBase : other.accentBase,
    );
  }
}

extension GymColorsX on BuildContext {
  GymColors get gym => Theme.of(this).extension<GymColors>()!;
}

/// Radius sudut, diambil dari nilai yang benar-benar dipakai artboard Pen.
///
/// Skalanya sengaja tidak dirapikan jadi kelipatan yang enak. Pen memang
/// memakai 7, 9, dan 11 di tempat-tempat tertentu, dan membulatkannya ke skala
/// "bersih" membuat kotak centang dan tombol stepper terlihat berbeda dari
/// desain — persis hal yang diminta supaya cocok.
abstract final class GymRadius {
  /// Sel kalender aktivitas.
  static const cell = 2.0;

  /// Batang grafik.
  static const bar = 4.0;

  /// Kotak centang peralatan.
  static const check = 7.0;

  /// Kotak input kg/rep di tabel set.
  static const input = 8.0;

  /// Segmen terpilih di dalam tab segmented, kotak konfigurasi editor.
  static const segment = 9.0;

  /// Kotak ikon, thumbnail, tombol aksi kecil, "Add set".
  static const small = 10.0;

  /// Tombol stepper, preset istirahat, kotak tanggal.
  static const stepper = 11.0;

  /// Field, baris daftar, tombol sekunder, "Add exercise".
  static const control = 12.0;

  /// Kartu standar dan tombol utama.
  static const card = 14.0;

  /// Kartu besar — panel istirahat, kartu gerakan, kartu Stats.
  static const large = 16.0;

  /// Satu-satunya radius 18 di desain: kartu "Next session" di Home.
  static const hero = 18.0;

  /// Sheet durasi istirahat, hanya sudut atas.
  static const sheet = 24.0;

  static const pill = 999.0;
}

/// Pilihan warna aksen di Profil. Semuanya cukup terang untuk teks gelap
/// [GymColors.accentInk] di atasnya.
const accentChoices = <Color>[
  Color(0xFF5AC8FA),
  Color(0xFF4ADE80),
  Color(0xFFFF9F43),
  Color(0xFFFF7AB6),
  Color(0xFFA78BFA),
];

/// Aksen versi tema terang: pilihan Profil dirancang untuk latar gelap dan
/// terlalu pucat di atas putih. Lima pilihan bawaan punya padanan yang sudah
/// dicek kontrasnya dengan teks putih (≥ 4,5:1); warna lain digelapkan lewat
/// HSL.
Color lightAccent(Color accent) {
  const pairs = {
    0xFF5AC8FA: 0xFF0877B0,
    0xFF4ADE80: 0xFF15803D,
    0xFFFF9F43: 0xFFB9520B,
    0xFFFF7AB6: 0xFFBE2468,
    0xFFA78BFA: 0xFF6D28D9,
  };
  final known = pairs[accent.toARGB32()];
  var hsl = HSLColor.fromColor(known == null ? accent : Color(known));
  // Gelapkan sampai benar-benar lolos 4,5:1 terhadap putih. Kuning perlu
  // jauh lebih gelap daripada biru untuk kontras yang sama, jadi batas
  // lightness tetap tidak cukup.
  double contrast(Color c) => 1.05 / (c.computeLuminance() + 0.05);
  while (contrast(hsl.toColor()) < 4.6 && hsl.lightness > 0.05) {
    hsl = hsl.withLightness(hsl.lightness - 0.02);
  }
  return hsl.toColor();
}

ThemeData buildGymTheme({Color? accent, Brightness brightness = Brightness.dark}) {
  final base = brightness == Brightness.light ? GymColors.light : GymColors.dark;
  final pick = accent ?? GymColors.dark.accent;
  final shownAccent = brightness == Brightness.light ? lightAccent(pick) : pick;
  final c = accent == null
      ? base.copyWith(accentBase: pick)
      : base.copyWith(
          accent: shownAccent,
          accentSoft: shownAccent.withValues(alpha: 0.12),
          accentBase: pick,
          selected: brightness == Brightness.light ? Color.alphaBlend(shownAccent.withValues(alpha: 0.10), base.surface) : null,
        );
  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: brightness,
  ).copyWith(
    primary: c.accent,
    onPrimary: c.accentInk,
    surface: c.surface,
    onSurface: c.text,
    error: c.danger,
  );

  // Inter di-bundle, sama seperti artboard Pen. Lima berat yang benar-benar
  // dipakai saja (400–800) — 1,6 MB, masih jauh di bawah NFR-3 (≤ 25 MB) — dan
  // di-bundle, bukan diambil saat runtime, supaya janji offline-first tidak
  // bergantung pada unduhan font.
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
      displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: c.text),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.text),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
      bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text2),
      labelSmall: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: c.text2),
    ),
    // Dialog, sheet, dan snackbar dari Material ikut palet, bukan warna
    // turunan seed yang di tema terang jadi ungu muda.
    dialogTheme: DialogThemeData(backgroundColor: c.surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.surface, modalBackgroundColor: c.surface),
    popupMenuTheme: PopupMenuThemeData(color: c.surface),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      // Pil redup di belakang ikon aktif: Material menganimasikannya sendiri
      // saat tab berpindah, jadi perpindahan tab punya "benda" yang bergerak.
      indicatorColor: c.accentSoft,
      indicatorShape: const StadiumBorder(),
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? c.accent : c.text3,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? c.accent : c.text3,
          )),
    ),
  );
}
