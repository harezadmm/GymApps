"""Bangkitkan app/lib/core/gym_icons.dart dari design/iconscout/GymIcons.json.

Dijalankan setelah scripts/build-gym-icons.js. Nama konstanta = nama berkas
SVG tanpa awalan `ui_`, kebab-case → camelCase.
"""
import json
import os
import re

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
m = json.load(open(os.path.join(root, 'design', 'iconscout', 'GymIcons.json')))


def camel(n):
    n = n[3:] if n.startswith('ui_') else n
    parts = re.split(r'[-_]', n)
    return parts[0] + ''.join(p.capitalize() for p in parts[1:])


consts = '\n'.join(
    f"  static const {camel(k)} = IconData(0x{v:x}, fontFamily: _family);"
    for k, v in sorted(m.items(), key=lambda kv: kv[1]))
src = f'''/// Ikon dari IconScout, dibungkus jadi font `GymIcons` supaya tetap berupa
/// [IconData]: ukurannya, warnanya, dan tree-shaking-nya sama dengan ikon
/// Material, dan warnanya ikut tema.
///
/// **Dibangkitkan** dari `design/iconscout/GymIcons.json` oleh
/// `scripts/gen-gym-icons-dart.py` — jangan disunting tangan. Sumber tiap
/// ikon dan cara membangun ulang fontnya ada di `design/iconscout/SOURCES.md`.
///
/// Dua paket: alat gym ("Gym", Bharat Design, 24 px) dan ikon antarmuka
/// ("Basic UI", Barudak Lier, 32 px). Keduanya garis membulat satu warna.
library;

import 'package:flutter/widgets.dart';

abstract final class GymIcons {{
  static const _family = 'GymIcons';

{consts}

  /// Ikon untuk kunci kelompok alat di `equipmentGroups`.
  static IconData forGroup(String group) => switch (group) {{
        'barbell' => barbell,
        'dumbbell' => dumbbell,
        'kettlebell' => kettlebell,
        'cable' => cable,
        'machine' => machine,
        'band' => band,
        'balls' => ball,
        'cardio' => cardio,
        _ => bodyweight,
      }};
}}
'''
out = os.path.join(root, 'app', 'lib', 'core', 'gym_icons.dart')
open(out, 'w', encoding='utf-8', newline='\n').write(src)
print(len(m), 'glyph:', ', '.join(camel(k) for k in sorted(m, key=m.get)))
