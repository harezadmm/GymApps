/// Ikon alat gym dari IconScout (paket "Gym", Bharat Design), dibungkus jadi
/// font `GymIcons` supaya tetap berupa [IconData]: ukurannya, warnanya, dan
/// tree-shaking-nya sama dengan ikon Material, dan warnanya ikut tema.
///
/// Kode glyph mengikuti `design/iconscout/GymIcons.json`. Sumber dan cara
/// membangun ulang fontnya ada di `design/iconscout/SOURCES.md`.
library;

import 'package:flutter/widgets.dart';

abstract final class GymIcons {
  static const _family = 'GymIcons';

  static const ball = IconData(0xe900, fontFamily: _family);
  static const band = IconData(0xe901, fontFamily: _family);
  static const barbell = IconData(0xe902, fontFamily: _family);
  static const bodyweight = IconData(0xe903, fontFamily: _family);
  static const cable = IconData(0xe904, fontFamily: _family);
  static const cardio = IconData(0xe905, fontFamily: _family);
  static const dumbbell = IconData(0xe906, fontFamily: _family);
  static const kettlebell = IconData(0xe907, fontFamily: _family);
  static const machine = IconData(0xe908, fontFamily: _family);
  static const scale = IconData(0xe909, fontFamily: _family);

  /// Ikon untuk kunci kelompok alat di `equipmentGroups`.
  static IconData forGroup(String group) => switch (group) {
        'barbell' => barbell,
        'dumbbell' => dumbbell,
        'kettlebell' => kettlebell,
        'cable' => cable,
        'machine' => machine,
        'band' => band,
        'balls' => ball,
        'cardio' => cardio,
        _ => bodyweight,
      };
}
