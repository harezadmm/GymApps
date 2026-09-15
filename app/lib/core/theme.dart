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
  });

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
    text3: Color(0xFF5A6275),
    accent: Color(0xFF5AC8FA),
    accentInk: Color(0xFF04121C),
    accentSoft: Color(0x1F5AC8FA),
    doneBg: Color(0xFF16321C),
    doneInk: Color(0xFF4ADE80),
    warn: Color(0xFFF5A623),
    danger: Color(0xFFF0554E),
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

ThemeData buildGymTheme() {
  const c = GymColors.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: Brightness.dark,
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
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    splashFactory: InkSparkle.splashFactory,
    extensions: const [c],
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Color(0xFFF2F5FA)),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFFF2F5FA)),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFF2F5FA)),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFF2F5FA)),
      bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFF2F5FA)),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8C95A8)),
      labelSmall: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xFF8C95A8)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: Colors.transparent,
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
