/// Tata letak yang boleh melebar di layar besar.
///
/// Aplikasi di web dikurung selebar ponsel (480 px) di tengah layar laptop —
/// satu kolom kartu tidak jadi lebih enak dibaca kalau direntang. Dashboard
/// pengecualiannya: tabel e1RM per minggu justru butuh lebar. Layar itu
/// menyalakan penanda ini selama terbuka, dan pembungkus lebar di
/// `main.dart` mengikutinya.
library;

import 'package:flutter/foundation.dart';

final wideLayout = ValueNotifier<bool>(false);
