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

import 'dart:convert';

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

/// Satu profil gym (FR-C3): nama dan kelompok alat yang ada di sana.
///
/// Orang yang berlatih di dua tempat — gym dekat rumah dan gym dekat kantor —
/// tidak punya satu daftar alat, dan chest press yang "sama" di dua gym tidak
/// sama beratnya. Setiap sesi membawa id profilnya ([Workout.gymId]) supaya
/// memori beban bisa dipisah per gym (FR-C4).
class GymProfile {
  const GymProfile({required this.id, required this.name, this.equipment});

  /// Lihat [defaultGymId].
  static const defaultId = defaultGymId;

  /// Gym bawaan tanpa batasan alat. Namanya kosong: setelan akun tidak tahu
  /// bahasa HP mana yang sedang membacanya, jadi nama bawaan dua bahasa
  /// ("My gym" / "Gym saya") diberikan oleh UI, bukan disimpan.
  static const fallback = GymProfile(id: defaultId, name: '');

  final String id;

  /// Nama yang diketik orangnya. Kosong = tampilkan nama bawaan.
  final String name;

  /// Kelompok alat di gym ini (kunci [equipmentGroups]). null = semua alat;
  /// library tidak disaring.
  final List<String>? equipment;

  GymProfile copyWith({String? name, List<String>? equipment, bool clearEquipment = false}) => GymProfile(
        id: id,
        name: name ?? this.name,
        equipment: clearEquipment ? null : (equipment ?? this.equipment),
      );

  /// Apakah satu nilai alat katalog tersedia di gym ini.
  bool hasEquipment(String catalogEquipment) {
    final groups = equipment;
    if (groups == null) return true;
    if (alwaysAvailableEquipment.contains(catalogEquipment) || catalogEquipment.isEmpty) return true;
    for (final g in groups) {
      if (equipmentGroups[g]?.contains(catalogEquipment) ?? false) return true;
    }
    return false;
  }

  /// Kunci `eq` sama dengan kunci daftar alat lama di setelan, supaya bentuk
  /// per gym dan bentuk lamanya saling terbaca.
  Map<String, dynamic> toJson() => {
        'id': id,
        if (name.isNotEmpty) 'name': name,
        if (equipment != null) 'eq': equipment,
      };

  factory GymProfile.fromJson(Map<String, dynamic> j) => GymProfile(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        equipment: (j['eq'] as List?)?.cast<String>(),
      );
}

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
    this.gyms = const [GymProfile.fallback],
    this.activeGymId = GymProfile.defaultId,
    this.favorites = const [],
    this.restByExercise = const {},
    this.unit = WeightUnit.kg,
    this.barWeight,
    this.plates,
    this.showExerciseMedia = true,
  });

  /// Satuan tampilan beban. Data tetap disimpan dalam kg (lihat units.dart).
  final WeightUnit unit;

  /// Berat bar kosong untuk hitung pelat (FR-D16), dalam **kg** seperti
  /// beban lain. null = bawaan satuan tampilan ([defaultBarWeight]); 0 =
  /// tanpa bar (semua beban dihitung dari nol). Disimpan hanya kalau diatur,
  /// supaya pemakai yang tidak pernah menyentuhnya mendapat 20 kg di kg dan
  /// 45 lb di lb — bukan 44,09 lb hasil konversi.
  final double? barWeight;

  /// Ukuran pelat yang ada di rak, dalam kg. null = bawaan satuan
  /// ([defaultPlates]). Urutannya tidak penting; [platesIn] mengurutkannya.
  final List<double>? plates;

  /// Bar dalam satuan tampilan: yang diatur, atau bawaan satuan itu.
  double barWeightIn(WeightUnit u) {
    final bar = barWeight;
    return bar == null ? defaultBarWeight(u) : plateShown(bar, u);
  }

  /// Pelat yang ada dalam satuan tampilan, terberat dulu, tanpa duplikat.
  List<double> platesIn(WeightUnit u) {
    final stored = plates;
    if (stored == null) return defaultPlates(u);
    return [
      for (final p in {for (final kg in stored) plateShown(kg, u)})
        if (p > 0) p,
    ]..sort((a, b) => b.compareTo(a));
  }

  /// Istirahat untuk gerakan yang tidak punya istirahat sendiri di rutinitas.
  final int defaultRestSeconds;

  /// Faktor deload untuk gerakan yang tidak menentukannya sendiri.
  final double deloadFactor;

  /// 1 = Senin, 7 = Minggu.
  final int weekStartsOn;

  /// Tampilkan pilihan RIR (sisa rep sebelum gagal) setelah set dicentang.
  final bool logRir;

  /// Gambar dan animasi gerakan dari CDN dataset (FR-C1) di library, kartu
  /// sesi, dan lembar riwayat. Mati = tidak ada satu pun permintaan gambar,
  /// bukan gambar yang diunduh lalu disembunyikan — untuk kuota data yang
  /// ketat. Setelan akun, bukan HP: yang mematikannya karena kuota ingin
  /// mati di semua HP-nya.
  final bool showExerciseMedia;

  /// Profil gym (FR-C3), urut seperti dibuat. Tidak pernah kosong setelah
  /// [TrainingSettings.fromJson]: setiap sesi butuh gym untuk dicatat dan
  /// library butuh daftar alat untuk dibaca, jadi selalu ada gym bawaan.
  final List<GymProfile> gyms;

  /// Id gym yang sedang dipakai — menyaring library dan memilih memori beban.
  final String activeGymId;

  /// Id gerakan yang dibintangi di library.
  final List<String> favorites;

  /// Istirahat yang disimpan dari sesi bebas ("simpan sebagai bawaan untuk
  /// Deadlift"), per id gerakan.
  final Map<String, int> restByExercise;

  /// Gym aktif. Id yang tidak dikenal (gym dihapus di HP lain selagi id-nya
  /// masih tersimpan di sini) jatuh ke gym pertama, bukan melempar.
  GymProfile get activeGym {
    for (final g in gyms) {
      if (g.id == activeGymId) return g;
    }
    return gyms.isEmpty ? GymProfile.fallback : gyms.first;
  }

  GymProfile? gymById(String id) {
    for (final g in gyms) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Alat di gym aktif — nama lama yang masih dipakai library dan Profil.
  /// null = tidak disaring.
  List<String>? get equipment => activeGym.equipment;

  /// Apakah satu nilai alat katalog tersedia di gym aktif.
  bool hasEquipment(String catalogEquipment) => activeGym.hasEquipment(catalogEquipment);

  /// Jadikan [id] gym aktif. Id yang tidak dikenal tidak mengubah apa pun.
  TrainingSettings withActiveGym(String id) => gymById(id) == null ? this : copyWith(activeGymId: id);

  /// Tambah gym baru, atau ganti gym yang id-nya sama (nama atau alatnya).
  TrainingSettings withGym(GymProfile gym) {
    final i = gyms.indexWhere((g) => g.id == gym.id);
    return copyWith(gyms: i < 0 ? [...gyms, gym] : ([...gyms]..[i] = gym));
  }

  /// Ganti daftar alat satu gym. null = semua alat.
  TrainingSettings withGymEquipment(String id, List<String>? equipment) {
    final g = gymById(id);
    if (g == null) return this;
    return withGym(equipment == null ? g.copyWith(clearEquipment: true) : g.copyWith(equipment: equipment));
  }

  /// Hapus satu gym. Gym terakhir tidak pernah dihapus — daftar kosong tidak
  /// punya arti — dan menghapus gym aktif memindahkan "aktif" ke gym pertama
  /// yang tersisa, supaya tidak ada keadaan tanpa gym aktif.
  TrainingSettings withoutGym(String id) {
    if (gyms.length <= 1 || gymById(id) == null) return this;
    final rest = [for (final g in gyms) if (g.id != id) g];
    return copyWith(gyms: rest, activeGymId: activeGymId == id ? rest.first.id : activeGymId);
  }

  TrainingSettings copyWith({
    int? defaultRestSeconds,
    double? deloadFactor,
    int? weekStartsOn,
    bool? logRir,
    List<GymProfile>? gyms,
    String? activeGymId,
    List<String>? favorites,
    Map<String, int>? restByExercise,
    WeightUnit? unit,
    double? barWeight,
    bool clearBarWeight = false,
    List<double>? plates,
    bool clearPlates = false,
    bool? showExerciseMedia,
  }) =>
      TrainingSettings(
        defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
        deloadFactor: deloadFactor ?? this.deloadFactor,
        weekStartsOn: weekStartsOn ?? this.weekStartsOn,
        logRir: logRir ?? this.logRir,
        gyms: gyms ?? this.gyms,
        activeGymId: activeGymId ?? this.activeGymId,
        favorites: favorites ?? this.favorites,
        restByExercise: restByExercise ?? this.restByExercise,
        unit: unit ?? this.unit,
        // null lewat parameter biasa berarti "jangan ubah"; kembali ke bawaan
        // satuan lewat `clear…`, seperti tri-state assisted di ExerciseConfig.
        barWeight: clearBarWeight ? null : (barWeight ?? this.barWeight),
        plates: clearPlates ? null : (plates ?? this.plates),
        showExerciseMedia: showExerciseMedia ?? this.showExerciseMedia,
      );

  /// Istirahat untuk satu gerakan: rutinitas, lalu yang disimpan dari sesi
  /// bebas, lalu bawaan.
  int restFor(ExerciseConfig cfg) =>
      cfg.restSeconds ?? restByExercise[cfg.exerciseId] ?? defaultRestSeconds;

  /// Hanya gym bawaan yang belum disentuh: satu gym, id bawaan, tanpa nama.
  /// Bentuk itu persis yang dibangun ulang [fromJson] dari kunci `eq` lama,
  /// jadi daftarnya tidak perlu ditulis — dokumen akun satu gym tetap
  /// sependek dulu, dan build lama di HP lain membacanya utuh.
  bool get _gymsAreDefault =>
      gyms.length == 1 && gyms.first.id == GymProfile.defaultId && gyms.first.name.isEmpty;

  Map<String, dynamic> toJson() => {
        if (defaultRestSeconds != 90) 'rest': defaultRestSeconds,
        if (deloadFactor != 0.9) 'dl': deloadFactor,
        if (weekStartsOn != DateTime.monday) 'week': weekStartsOn,
        if (logRir) 'rir': true,
        // Hanya ditulis saat mati, seperti `rir` hanya saat nyala: dokumen
        // akun yang tidak menyentuhnya tetap sependek dulu, dan digabung per
        // kolom seperti `rest` atau `unit` di mergeSettings.
        if (!showExerciseMedia) 'media': false,
        // `eq` lama tetap ditulis sebagai cermin gym aktif: build lama di HP
        // lain hanya mengenal kunci ini, dan library-nya harus tetap tersaring
        // dengan benar.
        if (activeGym.equipment != null) 'eq': activeGym.equipment,
        if (!_gymsAreDefault) 'gyms': [for (final g in gyms) g.toJson()],
        // Selalu ditulis, juga untuk akun satu gym bawaan. Ini penanda bahwa
        // dokumen ini ditulis build yang mengenal profil gym: tanpa `gyms`
        // berarti benar-benar tinggal satu gym bawaan (semua gym lain sengaja
        // dihapus), bukan build lama yang membuang kolom yang tidak
        // dikenalnya — dua keadaan yang di [mergeGymSettings] harus
        // diperlakukan berlawanan.
        'activeGymId': activeGym.id,
        if (favorites.isNotEmpty) 'fav': favorites,
        if (restByExercise.isNotEmpty) 'restEx': restByExercise,
        if (unit != WeightUnit.kg) 'unit': unit.name,
        // Bar dan pelat (FR-D16) dalam kg. Hanya yang diatur yang ditulis:
        // dokumen tanpa keduanya berarti "bawaan satuan", dan kolomnya
        // digabung per kolom seperti `rest` atau `unit` di mergeSettings.
        if (barWeight != null) 'bar': barWeight,
        if (plates != null) 'plates': plates,
      };

  /// Dokumen dari build yang belum mengenal profil gym — atau akun yang belum
  /// pernah menyentuhnya — hanya punya `eq`. Daftar alat lamanya, kalau ada,
  /// menjadi satu gym bawaan; dokumen tanpa keduanya mendapat gym bawaan
  /// tanpa batasan alat. Tidak ada jalur yang menghasilkan nol gym.
  factory TrainingSettings.fromJson(Map<String, dynamic> j) {
    var gyms = _gymProfilesIn(j['gyms']) ?? const <GymProfile>[];
    if (gyms.isEmpty) {
      gyms = [GymProfile(id: GymProfile.defaultId, name: '', equipment: (j['eq'] as List?)?.cast<String>())];
    }
    final active = j['activeGymId'];
    // Bar negatif atau bukan angka, dan daftar pelat yang bukan daftar,
    // dibaca sebagai "belum diatur" — bukan melempar, bukan bar minus.
    final rawBar = j['bar'];
    final rawPlates = j['plates'];
    return TrainingSettings(
      barWeight: rawBar is num && rawBar >= 0 ? rawBar.toDouble() : null,
      plates: rawPlates is List ? [for (final p in rawPlates) if (p is num && p > 0) p.toDouble()] : null,
      defaultRestSeconds: (j['rest'] as num?)?.toInt() ?? 90,
      deloadFactor: (j['dl'] as num?)?.toDouble() ?? 0.9,
      weekStartsOn: ((j['week'] as num?)?.toInt() ?? DateTime.monday).clamp(1, 7),
      logRir: j['rir'] == true,
      // Hanya `false` yang mematikan; nilai lain dari dokumen versi lain
      // dibaca sebagai bawaan (nyala).
      showExerciseMedia: j['media'] != false,
      gyms: gyms,
      activeGymId: active is String && gyms.any((g) => g.id == active) ? active : gyms.first.id,
      favorites: (j['fav'] as List?)?.cast<String>() ?? const [],
      restByExercise: {
        for (final e in ((j['restEx'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt(),
      },
      unit: WeightUnit.parse(j['unit']),
    );
  }
}

/// Daftar profil dari kolom `gyms` sebuah dokumen setelan. null kalau kolomnya
/// tidak ada atau tidak berisi satu pun profil yang sah — dokumen dari build
/// lama, atau akun satu gym yang sengaja tidak menulisnya (lihat
/// [TrainingSettings.toJson]).
List<GymProfile>? _gymProfilesIn(Object? raw) {
  if (raw is! List) return null;
  final out = [
    for (final g in raw)
      if (g is Map) GymProfile.fromJson(Map<String, dynamic>.from(g)),
  ]..removeWhere((g) => g.id.isEmpty);
  return out.isEmpty ? null : out;
}

/// Gabung daftar gym dua perangkat per id (FR-C3).
///
/// Aturannya sama dengan kolom setelan lain: gym yang diubah di perangkat ini
/// sejak [base] memakai versi sini, selebihnya versi server. Bedanya, daftar
/// ini tidak diperlakukan sebagai satu kolom — kalau begitu, gym yang ditambah
/// di tablet hilang begitu HP mengganti nama gymnya sendiri. Gym yang hanya
/// ada di satu sisi ikut, kecuali jelas dihapus di sisi lain dan tidak
/// disentuh di sisi ini; perubahan menang atas penghapusan, karena isinya
/// tidak bisa dibuat ulang sedangkan menghapus tinggal diulang.
List<GymProfile> mergeGymProfiles({
  required List<GymProfile> base,
  required List<GymProfile> mine,
  required List<GymProfile> theirs,
}) {
  String key(GymProfile g) => jsonEncode(g.toJson());
  final baseById = {for (final g in base) g.id: key(g)};
  final theirsById = {for (final g in theirs) g.id: g};
  final mineIds = {for (final g in mine) g.id};
  final out = <GymProfile>[];
  for (final g in mine) {
    final b = baseById[g.id];
    final t = theirsById[g.id];
    final changedHere = b == null || b != key(g);
    if (t != null) {
      out.add(changedHere ? g : t);
    } else if (changedHere) {
      // Ditambah atau diubah di sini; server belum tahu.
      out.add(g);
    }
    // Sisanya: dihapus di HP lain dan tidak disentuh di sini — ikut terhapus.
  }
  for (final g in theirs) {
    if (mineIds.contains(g.id)) continue;
    final b = baseById[g.id];
    // Baru di server, atau diubah di sana setelah dihapus di sini.
    if (b == null || b != key(g)) out.add(g);
  }
  return out;
}

/// Kolom gym hasil penggabungan tiga arah — daftar gym dan gym aktif — dari
/// tiga dokumen setelan mentah (bentuk [TrainingSettings.toJson]).
///
/// Ketiga sisi dibaca lewat [TrainingSettings.fromJson], jadi dokumen tanpa
/// `gyms` (akun satu gym bawaan) menjadi satu gym bawaan dengan daftar alat
/// `eq`-nya — dan penggabungan per id menanganinya seperti daftar biasa:
/// gym yang dihapus di HP lain sampai tinggal gym bawaan ikut terhapus di
/// sini, selama di sini tidak disentuh.
///
/// Satu pengecualian: server tanpa penanda `activeGymId` adalah build lama di
/// HP lain, yang hanya membaca dan menulis `eq` dan membuang kolom yang tidak
/// dikenalnya. Kalau itu dibaca apa adanya, setiap gym di luar gym bawaan
/// tampak "dihapus di sana" dan hilang pada setiap sinkron. Sisi seperti itu
/// dibaca sebagai daftar [base] yang hanya cermin `eq`-nya berubah —
/// perubahan alat dari build lama mendarat di gym yang aktif menurut [base],
/// dan gym lainnya tetap.
({List<GymProfile> gyms, String activeGymId}) mergeGymSettings({
  required Map<String, dynamic> base,
  required Map<String, dynamic> mine,
  required Map<String, dynamic> theirs,
}) {
  final b = TrainingSettings.fromJson(base);
  final m = TrainingSettings.fromJson(mine);
  final t = theirs['activeGymId'] is String
      ? TrainingSettings.fromJson(theirs)
      : b.withGymEquipment(b.activeGymId, (theirs['eq'] as List?)?.cast<String>());
  var gyms = mergeGymProfiles(base: b.gyms, mine: m.gyms, theirs: t.gyms);
  // Dua HP saling menghapus satu-satunya gym milik yang lain: hasilnya kosong,
  // dan tidak ada gym sama sekali bukan keadaan yang boleh ada. Daftar HP ini
  // yang dipakai — [m.gyms] tidak pernah kosong.
  if (gyms.isEmpty) gyms = m.gyms;
  final active = m.activeGymId != b.activeGymId ? m.activeGymId : t.activeGymId;
  return (gyms: gyms, activeGymId: gyms.any((g) => g.id == active) ? active : gyms.first.id);
}
