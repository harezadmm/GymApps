/// Padanan [readCssSafeArea] untuk platform selain web: sistem operasi sudah
/// memberi insetnya lewat MediaQuery, tidak ada yang perlu dibaca.
library;

import 'package:flutter/widgets.dart';

EdgeInsets readCssSafeArea() => EdgeInsets.zero;

/// Padanan web mewarnai bilah browser; di platform lain tidak ada.
void setBrowserChrome({required Color background, required bool light}) {}
