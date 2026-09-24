/// Padanan [readCssSafeArea] untuk platform selain web: sistem operasi sudah
/// memberi insetnya lewat MediaQuery, tidak ada yang perlu dibaca.
library;

import 'package:flutter/widgets.dart';

EdgeInsets readCssSafeArea() => EdgeInsets.zero;
