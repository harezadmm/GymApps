/// Menghitung porsi volume per otot dari sesi yang benar-benar tercatat.
///
/// Ini yang membuat peta otot dan radar di layar Stats bergerak mengikuti
/// latihan, bukan menampilkan angka bawaan desain.
///
/// **Yang dihitung dan yang tidak:**
///
/// * Hanya set kerja **tercentang** yang masuk. Set warm-up dan set yang
///   belum dicentang tidak menghasilkan volume — sama seperti aturan yang
///   dipakai mesin progresi (FR-D6, FR-E3).
/// * Volume satu set = beban × rep. Set bodyweight (beban 0) dihitung
///   **rep-nya saja**, bukan nol: push-up tetap melatih dada, dan peta yang
///   membiarkannya hilang akan bohong.
/// * Otot utama (`tg`) berbobot penuh; otot pendukung (`sm`) berbobot
///   [secondaryWeight]. Tanpa ini bench press hanya akan menyalakan dada,
///   padahal trisep dan bahu ikut bekerja.
library;

import 'dart:math' as math;

import '../data/exercise_catalog.dart';
import 'models.dart';

/// Kelompok otot yang bisa diwarnai di peta tubuh.
///
/// Urutannya **harus sama** dengan tabel di `bodyHeatmapGroups`, karena peta
/// itu menyimpan indeks ke enum ini.
enum MuscleGroup {
  chest,
  abs,
  obliques,
  shoulders,
  traps,
  lats,
  lowerBack,
  biceps,
  triceps,
  forearms,
  glutes,
  quads,
  hamstrings,
  calves,
}

const secondaryWeight = 0.35;

const muscleGroupLabel = <MuscleGroup, String>{
  MuscleGroup.chest: 'Chest',
  MuscleGroup.abs: 'Abs',
  MuscleGroup.obliques: 'Obliques',
  MuscleGroup.shoulders: 'Shoulders',
  MuscleGroup.traps: 'Traps',
  MuscleGroup.lats: 'Lats',
  MuscleGroup.lowerBack: 'Lower back',
  MuscleGroup.biceps: 'Biceps',
  MuscleGroup.triceps: 'Triceps',
  MuscleGroup.forearms: 'Forearms',
  MuscleGroup.glutes: 'Glutes',
  MuscleGroup.quads: 'Quads',
  MuscleGroup.hamstrings: 'Hamstrings',
  MuscleGroup.calves: 'Calves',
};

/// Nama otot di aset → kelompok.
///
/// Dua kosakata digabung di sini: `tg` memakai istilah anatomi ("pectorals",
/// "delts"), `sm` memakai istilah sehari-hari ("chest", "shoulders"). Keduanya
/// menunjuk otot yang sama, jadi keduanya dipetakan.
MuscleGroup? muscleGroupFor(String raw) {
  return switch (raw.toLowerCase().trim()) {
    'pectorals' || 'chest' || 'upper chest' => MuscleGroup.chest,
    'abs' || 'abdominals' || 'core' || 'lower abs' => MuscleGroup.abs,
    'obliques' || 'serratus anterior' => MuscleGroup.obliques,
    'delts' || 'deltoids' || 'shoulders' || 'rear deltoids' || 'rotator cuff' => MuscleGroup.shoulders,
    'traps' || 'trapezius' || 'levator scapulae' || 'rhomboids' => MuscleGroup.traps,
    'lats' || 'latissimus dorsi' || 'upper back' || 'back' => MuscleGroup.lats,
    'spine' || 'lower back' => MuscleGroup.lowerBack,
    'biceps' || 'brachialis' => MuscleGroup.biceps,
    'triceps' => MuscleGroup.triceps,
    'forearms' || 'wrists' || 'wrist flexors' || 'wrist extensors' || 'grip muscles' || 'hands' =>
      MuscleGroup.forearms,
    'glutes' || 'abductors' || 'adductors' || 'hip flexors' || 'groin' || 'inner thighs' => MuscleGroup.glutes,
    'quads' || 'quadriceps' => MuscleGroup.quads,
    'hamstrings' => MuscleGroup.hamstrings,
    'calves' || 'soleus' || 'ankles' || 'ankle stabilizers' || 'shins' || 'feet' => MuscleGroup.calves,
    _ => null,
  };
}

/// Volume mentah per kelompok otot, dalam kg·rep.
Map<MuscleGroup, double> volumeByMuscle(
  List<Workout> workouts,
  ExerciseCatalog catalog, {
  DateTime? since,
  DateTime? until,
}) {
  final byId = {for (final e in catalog.all) e.id: e};
  final out = <MuscleGroup, double>{};

  void add(MuscleGroup? g, double v) {
    if (g == null || v <= 0) return;
    out[g] = (out[g] ?? 0) + v;
  }

  for (final w in workouts) {
    final date = DateTime.tryParse(w.date);
    if (date != null) {
      if (since != null && date.isBefore(since)) continue;
      if (until != null && !date.isBefore(until)) continue;
    }
    for (final entry in w.entries) {
      final ex = byId[entry.exerciseId];
      if (ex == null) continue;
      var volume = 0.0;
      for (final s in entry.sets) {
        if (!s.done || s.isWarmup || s.reps <= 0) continue;
        volume += (s.weight > 0 ? s.weight : 1) * s.reps;
      }
      if (volume <= 0) continue;
      add(muscleGroupFor(ex.target), volume);
      for (final m in ex.secondary) {
        add(muscleGroupFor(m), volume * secondaryWeight);
      }
    }
  }
  return out;
}

/// Volume dinormalkan ke 0..1 terhadap otot dengan volume tertinggi.
///
/// Dinormalkan ke maksimum, bukan ke total: yang ingin dilihat adalah "mana
/// yang tertinggal dibanding yang paling banyak", dan pembagian terhadap total
/// membuat semua batang mengecil begitu jumlah gerakannya bertambah.
Map<MuscleGroup, double> muscleShare(Map<MuscleGroup, double> volume) {
  if (volume.isEmpty) return const {};
  final top = volume.values.reduce(math.max);
  if (top <= 0) return const {};
  return {for (final e in volume.entries) e.key: e.value / top};
}

/// Porsi 0..1 → lima tingkat panas yang dipakai peta (0..4).
///
/// Otot tanpa volume sama sekali mendapat tingkat 0 (paling gelap), bukan
/// dihapus — bagian tubuh yang tidak dilatih justru informasi yang dicari.
int heatLevelFor(double share) {
  if (share <= 0) return 0;
  if (share < 0.25) return 1;
  if (share < 0.5) return 2;
  if (share < 0.75) return 3;
  return 4;
}

/// Otot dengan volume paling sedikit di antara yang punya bentuk di peta.
///
/// Dipakai banner "X saw the least volume in this range". Mengembalikan null
/// kalau belum ada data — lebih baik tidak menampilkan banner daripada menuduh
/// satu otot terlantar padahal belum ada sesi sama sekali.
MuscleGroup? leastWorked(Map<MuscleGroup, double> volume, {Set<MuscleGroup> among = const {}}) {
  final pool = among.isEmpty ? MuscleGroup.values.toSet() : among;
  if (volume.isEmpty) return null;
  MuscleGroup? worst;
  var worstValue = double.infinity;
  for (final g in pool) {
    final v = volume[g] ?? 0;
    if (v < worstValue) {
      worstValue = v;
      worst = g;
    }
  }
  return worst;
}

/// Enam sumbu radar "body regions worked".
const regionMuscles = <String, List<MuscleGroup>>{
  'Chest': [MuscleGroup.chest],
  'Core': [MuscleGroup.abs, MuscleGroup.obliques, MuscleGroup.lowerBack],
  'Arms': [MuscleGroup.biceps, MuscleGroup.triceps, MuscleGroup.forearms],
  'Legs': [MuscleGroup.quads, MuscleGroup.hamstrings, MuscleGroup.glutes, MuscleGroup.calves],
  'Shoulders': [MuscleGroup.shoulders],
  'Back': [MuscleGroup.lats, MuscleGroup.traps],
};

/// Volume per region, dinormalkan bersama antara dua periode.
///
/// Keduanya dibagi oleh **maksimum gabungan**, bukan masing-masing: kalau
/// tiap periode dinormalkan sendiri-sendiri, dua bulan dengan volume sangat
/// berbeda akan menggambar poligon yang sama besar dan perbandingannya hilang.
({Map<String, double> current, Map<String, double> previous}) regionShare(
  Map<MuscleGroup, double> now,
  Map<MuscleGroup, double> before,
) {
  double sum(Map<MuscleGroup, double> v, List<MuscleGroup> gs) =>
      gs.fold(0.0, (a, g) => a + (v[g] ?? 0));

  final rawNow = {for (final e in regionMuscles.entries) e.key: sum(now, e.value)};
  final rawBefore = {for (final e in regionMuscles.entries) e.key: sum(before, e.value)};

  final top = [...rawNow.values, ...rawBefore.values].fold(0.0, math.max);
  if (top <= 0) {
    return (
      current: {for (final k in regionMuscles.keys) k: 0.0},
      previous: {for (final k in regionMuscles.keys) k: 0.0},
    );
  }
  return (
    current: {for (final e in rawNow.entries) e.key: e.value / top},
    previous: {for (final e in rawBefore.entries) e.key: e.value / top},
  );
}
