/// Ikon dari IconScout, dibungkus jadi font `GymIcons` supaya tetap berupa
/// [IconData]: ukurannya, warnanya, dan tree-shaking-nya sama dengan ikon
/// Material, dan warnanya ikut tema.
///
/// **Dibangkitkan** dari `design/iconscout/GymIcons.json` oleh
/// `scripts/gen-gym-icons-dart.py` — jangan disunting tangan. Sumber tiap
/// ikon dan cara membangun ulang fontnya ada di `design/iconscout/SOURCES.md`.
///
/// Dua kontributor: alat gym ("Gym", Bharat Design, 24 px) dan ikon antarmuka
/// Barudak Lier ("Basic UI" dan paket kembarannya, 32 px). Glyph antarmuka
/// yang tidak ada di paketnya — chevron, panah, minus — dirakit dari ikon
/// paket itu oleh `scripts/derive-gym-icons.py`. Semuanya garis membulat satu
/// warna. Silang dan centang memenuhi kotak glyph, jadi pakai sekitar ¾
/// ukuran ikon Material yang setara.
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
  static const add = IconData(0xe90a, fontFamily: _family);
  static const alarm = IconData(0xe90b, fontFamily: _family);
  static const alert = IconData(0xe90c, fontFamily: _family);
  static const arrowDownRight = IconData(0xe90d, fontFamily: _family);
  static const arrowDown = IconData(0xe90e, fontFamily: _family);
  static const arrowLeft = IconData(0xe90f, fontFamily: _family);
  static const arrowRight = IconData(0xe910, fontFamily: _family);
  static const arrowUpRight = IconData(0xe911, fontFamily: _family);
  static const arrowUp = IconData(0xe912, fontFamily: _family);
  static const bell = IconData(0xe913, fontFamily: _family);
  static const calendar = IconData(0xe914, fontFamily: _family);
  static const chart = IconData(0xe915, fontFamily: _family);
  static const checkCircle = IconData(0xe916, fontFamily: _family);
  static const checkDouble = IconData(0xe917, fontFamily: _family);
  static const check = IconData(0xe918, fontFamily: _family);
  static const chevronDown = IconData(0xe919, fontFamily: _family);
  static const chevronRight = IconData(0xe91a, fontFamily: _family);
  static const chevronUp = IconData(0xe91b, fontFamily: _family);
  static const circle = IconData(0xe91c, fontFamily: _family);
  static const clock = IconData(0xe91d, fontFamily: _family);
  static const close = IconData(0xe91e, fontFamily: _family);
  static const cloudCheck = IconData(0xe91f, fontFamily: _family);
  static const cloudOff = IconData(0xe920, fontFamily: _family);
  static const cloud = IconData(0xe921, fontFamily: _family);
  static const copy = IconData(0xe922, fontFamily: _family);
  static const dataTransfer = IconData(0xe923, fontFamily: _family);
  static const download = IconData(0xe924, fontFamily: _family);
  static const edit = IconData(0xe925, fontFamily: _family);
  static const eyeOff = IconData(0xe926, fontFamily: _family);
  static const eye = IconData(0xe927, fontFamily: _family);
  static const filter = IconData(0xe928, fontFamily: _family);
  static const fire = IconData(0xe929, fontFamily: _family);
  static const flag = IconData(0xe92a, fontFamily: _family);
  static const globe = IconData(0xe92b, fontFamily: _family);
  static const home = IconData(0xe92c, fontFamily: _family);
  static const info = IconData(0xe92d, fontFamily: _family);
  static const link = IconData(0xe92e, fontFamily: _family);
  static const lock = IconData(0xe92f, fontFamily: _family);
  static const logout = IconData(0xe930, fontFamily: _family);
  static const mail = IconData(0xe931, fontFamily: _family);
  static const menu = IconData(0xe932, fontFamily: _family);
  static const minusCircle = IconData(0xe933, fontFamily: _family);
  static const minus = IconData(0xe934, fontFamily: _family);
  static const moon = IconData(0xe935, fontFamily: _family);
  static const moreVertical = IconData(0xe936, fontFamily: _family);
  static const note = IconData(0xe937, fontFamily: _family);
  static const pause = IconData(0xe938, fontFamily: _family);
  static const play = IconData(0xe939, fontFamily: _family);
  static const plus = IconData(0xe93a, fontFamily: _family);
  static const search = IconData(0xe93b, fontFamily: _family);
  static const settings = IconData(0xe93c, fontFamily: _family);
  static const skip = IconData(0xe93d, fontFamily: _family);
  static const sliders = IconData(0xe93e, fontFamily: _family);
  static const starFilled = IconData(0xe93f, fontFamily: _family);
  static const star = IconData(0xe940, fontFamily: _family);
  static const swap = IconData(0xe941, fontFamily: _family);
  static const sync = IconData(0xe942, fontFamily: _family);
  static const trash = IconData(0xe943, fontFamily: _family);
  static const trophy = IconData(0xe944, fontFamily: _family);
  static const user = IconData(0xe945, fontFamily: _family);

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
