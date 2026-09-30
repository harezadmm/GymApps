/// Ukuran dekode (`cacheWidth`/`cacheHeight`) untuk gambar raster aplikasi.
library;

import 'package:flutter/foundation.dart';

/// Piksel dekode untuk gambar yang tampil [logical] dp, paling besar
/// [sourcePx] (ukuran berkasnya — lebih besar hanya memperbesar piksel yang
/// sama sambil memakan memori).
///
/// Di HP, mendekode seukuran tampilan menghemat memori: ikon 46 dp di layar
/// 3× cukup 138 px, bukan 384 px penuh.
///
/// Di web jawabannya selalu null. Flutter web (3.47) mengubah ukuran dengan
/// mendekode dua kali lalu menyalin lewat kanvas, dan di WebKit — mesin
/// Safari, satu-satunya mesin di iPhone — gambar itu tidak pernah selesai:
/// tanpa galat dan tanpa bingkai, jadi ilustrasi dan ikon 3D tidak pernah
/// muncul. Berkas kita paling besar 600 px, jadi dekode penuh di web murah.
int? decodePx(double logical, double devicePixelRatio, int sourcePx, {bool web = kIsWeb}) {
  if (web) return null;
  return (logical * devicePixelRatio).ceil().clamp(1, sourcePx);
}
