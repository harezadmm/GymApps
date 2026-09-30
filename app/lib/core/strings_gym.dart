/// Teks profil gym (FR-C3, FR-C4): bagian Gym di Profil, pemilih gym saat
/// membuka sesi, dan chip gym aktif di Home dan layar sesi.
///
/// Dipisah dari `strings.dart` dengan alasan yang sama seperti
/// `strings_home.dart`: satu extension per area, supaya pekerjaan rilis ini
/// tidak saling menimpa di satu file. Pemanggilnya tetap `context.t.xxx`.
library;

import '../domain/settings.dart';
import 'strings.dart';

extension GymStrings on Strings {
  String _g(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  /// Nama gym bawaan — gym hasil migrasi dari daftar alat lama, atau gym
  /// pertama akun baru. Disimpan kosong dan diberi nama di sini, dalam bahasa
  /// HP yang membacanya; setelan akun tidak tahu bahasa itu.
  String get defaultGymName => _g('My gym', 'Gym saya');

  /// Nama yang ditampilkan untuk satu profil: yang diketik, atau bawaan.
  String gymName(GymProfile g) => g.name.trim().isEmpty ? defaultGymName : g.name;

  // ── Bagian Gym di Profil ──
  /// Penanda di bawah nama gym yang sedang dipakai.
  String get currentlyActive => _g('Active', 'Aktif');
  String get gymSectionNote => _g(
        'Each gym keeps its own equipment list and weight memory: targets and PREV follow what you lifted there.',
        'Tiap gym punya daftar alat dan memori bebannya sendiri: target dan PREV mengikuti yang kamu angkat di sana.',
      );
  String get addGym => _g('Add gym', 'Tambah gym');
  String get newGymTitle => _g('New gym', 'Gym baru');
  String get renameGym => _g('Rename gym', 'Ganti nama gym');
  String get gymNameHint => _g('e.g. Gym near work', 'mis. Gym dekat kantor');
  String get equipmentAtThisGym => _g('Equipment at this gym', 'Alat di gym ini');
  String equipmentAt(String gym) => _g('Equipment at $gym', 'Alat di $gym');
  String get deleteGym => _g('Delete gym', 'Hapus gym');
  String deleteGymTitle(String gym) => _g('Delete $gym?', 'Hapus $gym?');
  String get deleteGymBody => _g(
        'Sessions logged there stay in your history. Its equipment list and weight memory are no longer used.',
        'Sesi yang dicatat di sana tetap ada di riwayat. Daftar alat dan memori bebannya tidak dipakai lagi.',
      );

  /// Tooltip tombol ⋯ di baris gym — tombol ikon tanpa teks (NFR-11).
  String get gymOptions => _g('Gym options', 'Opsi gym');

  // ── Pemilih gym saat membuka sesi, dan chip di Home ──
  String get chooseGymTitle => _g('Training where today?', 'Latihan di mana hari ini?');
  String get chooseGymNote => _g(
        'Targets and PREV follow the weights you logged at that gym.',
        'Target dan PREV mengikuti beban yang kamu catat di gym itu.',
      );
  String get switchGym => _g('Switch gym', 'Ganti gym');

  /// Label pembaca layar untuk chip gym, yang secara visual hanya nama.
  String activeGymLabel(String gym) => _g('Active gym: $gym', 'Gym aktif: $gym');
  String gymLabel(String gym) => _g('Gym: $gym', 'Gym: $gym');
}
