/// Setelan latihan milik satu akun — ikut tersinkron bersama riwayatnya.
///
/// Dulu semua baris di Profil ("Default rest 90 s", "Deload 90%", …) hanya
/// teks dengan snackbar "belum tersambung". Yang ada di sini benar-benar
/// dipakai: istirahat bawaan dan faktor deload masuk ke setiap sesi baru,
/// awal minggu dipakai strip minggu di Home, dan seterusnya.
///
/// Setelan perangkat (bahasa, layar menyala, warna aksen) sengaja tidak di
/// sini: itu soal HP yang dipakai, bukan orang yang masuk.
library;

import 'models.dart';
import 'units.dart';

export 'units.dart' show WeightUnit;

/// Kelompok alat di gym, dipetakan ke nilai `equipment` di katalog.
///
/// Katalog punya 28 nilai alat; orang berpikir dalam 8 kelompok. Gerakan
/// bodyweight selalu tersedia — tidak ada gym tanpa lantai.
const equipmentGroups = <String, List<String>>{
  'barbell': ['barbell', 'olympic barbell', 'ez barbell', 'trap bar'],
  'dumbbell': ['dumbbell'],
  'kettlebell': ['kettlebell'],
  'cable': ['cable', 'rope'],
  'machine': ['leverage machine', 'sled machine', 'smith machine', 'assisted'],
  'band': ['band', 'resistance band'],
  'balls': ['stability ball', 'medicine ball', 'bosu ball', 'roller', 'wheel roller'],
  'cardio': [
    'upper body ergometer', 'skierg machine', 'stationary bike', 'elliptical machine', 'stepmill machine',
  ],
};

/// Selalu dianggap tersedia, apa pun pilihan alatnya.
const alwaysAvailableEquipment = {'body weight', 'weighted', 'hammer', 'tire'};

/// Satu catatan berat badan.
class BodyweightEntry {
  const BodyweightEntry({required this.date, required this.kg});

  /// `YYYY-MM-DD`. Satu catatan per hari; yang baru menimpa yang lama.
  final String date;
  final double kg;

  Map<String, dynamic> toJson() => {'date': date, 'kg': kg};

  factory BodyweightEntry.fromJson(Map<String, dynamic> j) =>
      BodyweightEntry(date: j['date'] as String? ?? '', kg: (j['kg'] as num?)?.toDouble() ?? 0);
}

class TrainingSettings {
  const TrainingSettings({
    this.defaultRestSeconds = 90,
    this.deloadFactor = 0.9,
    this.weekStartsOn = DateTime.monday,
    this.logRir = false,
    this.equipment,
    this.favorites = const [],
    this.restByExercise = const {},
    this.unit = WeightUnit.kg,
  });

  /// Satuan tampilan beban. Data tetap disimpan dalam kg (lihat units.dart).
  final WeightUnit unit;

  /// Istirahat untuk gerakan yang tidak punya istirahat sendiri di rutinitas.
  final int defaultRestSeconds;

  /// Faktor deload untuk gerakan yang tidak menentukannya sendiri.
  final double deloadFactor;

  /// 1 = Senin, 7 = Minggu.
  final int weekStartsOn;

  /// Tampilkan pilihan RIR (sisa rep sebelum gagal) setelah set dicentang.
  final bool logRir;

  /// Kelompok alat yang ada di gym (kunci [equipmentGroups]). null = belum
  /// pernah dipilih, library tidak disaring.
  final List<String>? equipment;

  /// Id gerakan yang dibintangi di library.
  final List<String> favorites;

  /// Istirahat yang disimpan dari sesi bebas ("simpan sebagai bawaan untuk
  /// Deadlift"), per id gerakan.
  final Map<String, int> restByExercise;

  TrainingSettings copyWith({
    int? defaultRestSeconds,
    double? deloadFactor,
    int? weekStartsOn,
    bool? logRir,
    List<String>? equipment,
    bool clearEquipment = false,
    List<String>? favorites,
    Map<String, int>? restByExercise,
    WeightUnit? unit,
  }) =>
      TrainingSettings(
        defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
        deloadFactor: deloadFactor ?? this.deloadFactor,
        weekStartsOn: weekStartsOn ?? this.weekStartsOn,
        logRir: logRir ?? this.logRir,
        equipment: clearEquipment ? null : (equipment ?? this.equipment),
        favorites: favorites ?? this.favorites,
        restByExercise: restByExercise ?? this.restByExercise,
        unit: unit ?? this.unit,
      );

  /// Apakah satu nilai alat katalog tersedia menurut pilihan ini.
  bool hasEquipment(String catalogEquipment) {
    final groups = equipment;
    if (groups == null) return true;
    if (alwaysAvailableEquipment.contains(catalogEquipment) || catalogEquipment.isEmpty) return true;
    for (final g in groups) {
      if (equipmentGroups[g]?.contains(catalogEquipment) ?? false) return true;
    }
    return false;
  }

  /// Istirahat untuk satu gerakan: rutinitas, lalu yang disimpan dari sesi
  /// bebas, lalu bawaan.
  int restFor(ExerciseConfig cfg) =>
      cfg.restSeconds ?? restByExercise[cfg.exerciseId] ?? defaultRestSeconds;

  Map<String, dynamic> toJson() => {
        if (defaultRestSeconds != 90) 'rest': defaultRestSeconds,
        if (deloadFactor != 0.9) 'dl': deloadFactor,
        if (weekStartsOn != DateTime.monday) 'week': weekStartsOn,
        if (logRir) 'rir': true,
        if (equipment != null) 'eq': equipment,
        if (favorites.isNotEmpty) 'fav': favorites,
        if (restByExercise.isNotEmpty) 'restEx': restByExercise,
        if (unit != WeightUnit.kg) 'unit': unit.name,
      };

  factory TrainingSettings.fromJson(Map<String, dynamic> j) => TrainingSettings(
        defaultRestSeconds: (j['rest'] as num?)?.toInt() ?? 90,
        deloadFactor: (j['dl'] as num?)?.toDouble() ?? 0.9,
        weekStartsOn: ((j['week'] as num?)?.toInt() ?? DateTime.monday).clamp(1, 7),
        logRir: j['rir'] == true,
        equipment: (j['eq'] as List?)?.cast<String>(),
        favorites: (j['fav'] as List?)?.cast<String>() ?? const [],
        restByExercise: {
          for (final e in ((j['restEx'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt(),
        },
        unit: WeightUnit.parse(j['unit']),
      );
}
