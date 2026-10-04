/// Library gerakan — artboard `07 Exercise Library`.
///
/// Daftarnya dibaca dari aset asli, bukan contoh: 1.324 gerakan, jadi
/// listnya dibangun malas dengan [ListView.builder] dan pencarian berjalan
/// di setiap ketukan.
library;

import 'package:flutter/material.dart';
import '../../core/gym_icons.dart';
import '../../core/charts.dart';
import '../../core/motion.dart';

import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../session/exercise_history_sheet.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key, this.picking = false});

  /// Dibuka untuk memilih gerakan (tambah/ganti di sesi, isi rutinitas).
  /// Ketukan mengembalikan gerakannya. Kalau false, library dibuka untuk
  /// dijelajahi dan ketukan menampilkan detail gerakan.
  final bool picking;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _query = TextEditingController();
  late Future<ExerciseCatalog> _catalog;
  int _sort = 0;

  /// Saring ke alat yang ada di gym (setelan Profil). Menyala dengan sendirinya
  /// kalau alatnya pernah dipilih.
  bool? _onlyMine;

  /// Bagian tubuh yang dipilih, null = semua.
  String? _bodyPart;

  static const _bodyParts = [
    'chest', 'back', 'shoulders', 'upper arms', 'lower arms', 'upper legs', 'lower legs', 'waist', 'cardio',
  ];

  /// Kelompok otot ([MuscleGroup] index) yang disorot di glyph tiap kategori.
  /// Kardio kosong = seluruh tubuh.
  static List<int> _bodyPartGroups(String bp) => switch (bp) {
        'chest' => const [0],
        'back' => const [4, 5, 6],
        'shoulders' => const [3],
        'upper arms' => const [7, 8],
        'lower arms' => const [9],
        'upper legs' => const [10, 11, 12],
        'lower legs' => const [13],
        'waist' => const [1, 2],
        _ => const [],
      };

  @override
  void initState() {
    super.initState();
    _catalog = ExerciseCatalog.load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Exercise> _arrange(ExerciseCatalog catalog, WorkoutStore store) {
    final settings = store.settings;
    final onlyMine = _onlyMine ?? settings.equipment != null;
    final starred = settings.favorites.toSet();
    final list = [
      for (final e in catalog.search(_query.text))
        if ((!onlyMine || e.custom || settings.hasEquipment(e.equipment)) &&
            (_bodyPart == null || e.bodyPart == _bodyPart))
          e,
    ];
    switch (_sort) {
      case 1: // A–Z
        list.sort((a, b) => a.name.compareTo(b.name));
      case 2: // By muscle
        list.sort((a, b) => a.bodyPart == b.bodyPart ? a.name.compareTo(b.name) : a.bodyPart.compareTo(b.bodyPart));
      default:
        // Performed — favorit dulu, lalu yang paling sering dicatat, sisanya
        // urutan katalog. Dulu "Performed" tidak pernah melihat riwayat.
        final count = <String, int>{};
        for (final w in store.workouts) {
          for (final e in w.entries) {
            count[e.exerciseId] = (count[e.exerciseId] ?? 0) + 1;
          }
        }
        final order = {for (final (i, e) in list.indexed) e.id: i};
        list.sort((a, b) {
          final sa = starred.contains(a.id) ? 0 : 1;
          final sb = starred.contains(b.id) ? 0 : 1;
          if (sa != sb) return sa - sb;
          final ca = count[a.id] ?? 0;
          final cb = count[b.id] ?? 0;
          if (ca != cb) return cb - ca;
          return order[a.id]! - order[b.id]!;
        });
    }
    return list;
  }

  /// Buat gerakan custom (FR-C2), lalu pakai langsung. Di mode pemilih,
  /// gerakan barunya dikembalikan seolah dipilih dari daftar.
  Future<void> _createCustom(String name) async {
    final created = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.gym.bg,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet))),
      builder: (_) => CustomExerciseSheet(initialName: name),
    );
    if (created == null || !mounted) return;
    if (widget.picking) {
      Navigator.of(context).pop(created);
      return;
    }
    _query.clear();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.customSaved(created.name))));
  }

  void _showDetails(BuildContext context, Exercise e) {
    final c = context.gym;
    final t = context.t;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bg,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              _DetailLine(label: t.targetMuscle, value: t.muscle(_cap(e.target))),
              if (e.secondary.isNotEmpty)
                _DetailLine(label: t.secondaryMuscles, value: e.secondary.map(_cap).join(', ')),
              _DetailLine(label: t.equipmentLabel, value: _cap(e.equipment)),
              const SizedBox(height: 12),
              GymButton(
                label: t.exerciseHistory,
                // Glyph grafik, sama dengan menu "Riwayat gerakan" di layar sesi:
                // yang dibuka memang grafik perkembangan, bukan daftar waktu.
                icon: GymIcons.chart,
                tone: GymButtonTone.neutral,
                height: 44,
                onPressed: () => showExerciseHistory(context, exerciseId: e.id, name: e.name),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 10, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(GymIcons.arrowLeft, size: 22, color: c.text2),
                    tooltip: context.t.back,
                  ),
                  Expanded(
                    child: _SearchField(
                      controller: _query,
                      onChanged: (_) => setState(() {}),
                      // Saringan "Alat saya" duduk di ujung kolom cari,
                      // seperti ikon penyaring di layar Search referensi.
                      filterOn: context.workouts.settings.equipment != null && (_onlyMine ?? true),
                      onFilter: context.workouts.settings.equipment == null
                          ? null
                          : () => setState(() => _onlyMine = !(_onlyMine ?? true)),
                      filterTooltip: context.t.myEquipmentOnly,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _createCustom(''),
                    icon: Icon(GymIcons.plus, color: c.accent),
                    tooltip: context.t.customExercise,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilterChips(
                labels: [context.t.performed, context.t.alphabetical, context.t.byMuscle],
                index: _sort,
                onChanged: (i) => setState(() => _sort = i),
              ),
            ),
            const SizedBox(height: 12),
            // Bagian tubuh sebagai deretan cakram bulat berlabel — "Featured
            // categories" di referensi.
            SizedBox(
              height: 82,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _CategoryDisc(
                    label: context.t.allBodyParts,
                    icon: GymIcons.menu,
                    selected: _bodyPart == null,
                    onTap: () => setState(() => _bodyPart = null),
                  ),
                  for (final bp in _bodyParts)
                    _CategoryDisc(
                      label: context.t.bodyPart(bp),
                      groups: _bodyPartGroups(bp),
                      selected: _bodyPart == bp,
                      onTap: () => setState(() => _bodyPart = _bodyPart == bp ? null : bp),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: FutureBuilder<ExerciseCatalog>(
                future: _catalog,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('${context.t.catalogueUnreadable}\n${snap.error}',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.text2)),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return Center(child: CircularProgressIndicator(color: c.accent));
                  }

                  final store = context.workouts;
                  final list = _arrange(snap.data!, store);
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: c.bgNested,
                            borderRadius: BorderRadius.circular(GymRadius.small),
                          ),
                          child: Row(
                            children: [
                              Icon(GymIcons.filter, size: 15, color: c.text2),
                              const SizedBox(width: 8),
                              Expanded(
                                // Dulu tertulis "disaring untuk Gym A" padahal
                                // tidak ada yang disaring. Sekarang hanya
                                // mengatakan apa yang memang terjadi.
                                child: Text(widget.picking ? context.t.pickExercise : context.t.exerciseLibrary,
                                    style: TextStyle(fontSize: 12.5, color: c.text2)),
                              ),
                              Text(context.t.shownCount(formatCount(list.length)),
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.accent)),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: list.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(context.t.nothingMatches(_query.text.trim()),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 13.5, color: c.text2)),
                                      const SizedBox(height: 16),
                                      // Tidak ada di katalog bukan jalan buntu:
                                      // gerakan itu bisa dibuat sendiri dan
                                      // langsung dipakai.
                                      // Baris, bukan tombol: nama gerakan bisa
                                      // panjang, dan label tombol tidak bisa
                                      // terlipat — ia meluber keluar layar.
                                      _AddCustomTile(
                                        query: _query.text.trim(),
                                        onTap: () => _createCustom(_query.text.trim()),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                                // Satu baris tambahan di ujung daftar: hasil
                                // yang mirip belum tentu gerakan yang dicari.
                                itemCount: list.length + (_query.text.trim().isEmpty ? 0 : 1),
                                itemBuilder: (context, i) {
                                  if (i == list.length) {
                                    return _AddCustomTile(
                                      query: _query.text.trim(),
                                      onTap: () => _createCustom(_query.text.trim()),
                                    );
                                  }
                                  final e = list[i];
                                  return _ExerciseRow(
                                    exercise: e,
                                    starred: store.settings.favorites.contains(e.id),
                                    onStar: () => store.toggleFavorite(e.id),
                                    onTap: () => widget.picking
                                        ? Navigator.of(context).pop(e)
                                        : _showDetails(context, e),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    this.filterOn = false,
    this.onFilter,
    this.filterTooltip,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool filterOn;
  final VoidCallback? onFilter;
  final String? filterTooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    OutlineInputBorder border(Color colour) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colour),
        );

    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14.5, color: c.text),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.t.searchExercise,
          hintStyle: TextStyle(fontSize: 14.5, color: c.text3),
          prefixIcon: Icon(GymIcons.search, size: 20, color: c.text2),
          suffixIcon: onFilter == null
              ? null
              : IconButton(
                  onPressed: onFilter,
                  tooltip: filterTooltip,
                  icon: Icon(GymIcons.filter, size: 20, color: filterOn ? c.accent : c.text3),
                ),
          filled: true,
          fillColor: c.surface,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: border(c.border),
          enabledBorder: border(c.border),
          focusedBorder: border(c.accent),
        ),
      ),
    );
  }
}

/// Satu kategori: cakram ikon bulat dengan label di bawahnya.
class _CategoryDisc extends StatelessWidget {
  const _CategoryDisc({required this.label, required this.selected, required this.onTap, this.icon, this.groups});

  final String label;
  final IconData? icon;

  /// Kelompok otot untuk glyph tubuh; dipakai kalau [icon] null.
  final List<int>? groups;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final disc = icon != null
        ? IconDisc(icon!, size: 50, iconSize: 23, filled: selected)
        : Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: selected ? c.accentFill : c.accentSoft, shape: BoxShape.circle),
            child: MuscleGlyph(
              groups: groups ?? const [],
              size: 36,
              color: selected ? c.accentInk : c.accent,
              base: selected ? c.accentInk.withValues(alpha: 0.30) : c.accent.withValues(alpha: 0.18),
            ),
          );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            GymHaptics.tap();
            onTap();
          },
          borderRadius: BorderRadius.circular(GymRadius.control),
          child: SizedBox(
            width: 74,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                disc,
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: selected ? c.text : c.text2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.starred,
    required this.onStar,
    required this.onTap,
  });

  final Exercise exercise;
  final bool starred;
  final VoidCallback onStar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GymRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          children: [
            IconDisc(exercise.icon, size: 44, iconSize: 23),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (exercise.custom) ...[
                        Pill(
                          color: c.accentSoft,
                          textColor: c.accent,
                          child: Text(context.t.customTag, style: const TextStyle(fontSize: 9.5, letterSpacing: 0.8)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(exercise.subtitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.text2)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onStar,
              // Bintang isi dan bintang garis dari paket Basic UI yang sama
              // (glyph dan line), jadi siluetnya persis sama saat berganti.
              icon: Icon(starred ? GymIcons.starFilled : GymIcons.star, size: 17, color: starred ? c.warn : c.text3),
              tooltip: starred ? 'Remove from favourites' : 'Add to favourites',
            ),
            Icon(GymIcons.chevronRight, size: 18, color: c.text3),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: TextStyle(fontSize: 13, color: c.text2))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text))),
        ],
      ),
    );
  }
}

/// Baris terakhir daftar hasil: tambah kueri ini sebagai gerakan custom.
class _AddCustomTile extends StatelessWidget {
  const _AddCustomTile({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.card),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Icon(GymIcons.plus, size: 18, color: c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t.cantFindIt, style: TextStyle(fontSize: 12, color: c.text2)),
                    const SizedBox(height: 2),
                    Text(context.t.addAsCustom(query),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.accent)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Otot utama untuk gerakan custom: label, istilah otot katalog (`tg`), dan
/// bagian tubuh (`bp`). Keduanya dipakai peta otot dan kelipatan beban bawaan,
/// jadi gerakan custom ikut terhitung di Stats seperti gerakan lain.
const _muscleOptions = <(String, String, String)>[
  ('Chest', 'pectorals', 'chest'),
  ('Back', 'lats', 'back'),
  ('Traps', 'traps', 'back'),
  ('Shoulders', 'delts', 'shoulders'),
  ('Biceps', 'biceps', 'upper arms'),
  ('Triceps', 'triceps', 'upper arms'),
  ('Forearms', 'forearms', 'lower arms'),
  ('Quads', 'quads', 'upper legs'),
  ('Hamstrings', 'hamstrings', 'upper legs'),
  ('Glutes', 'glutes', 'upper legs'),
  ('Calves', 'calves', 'lower legs'),
  ('Abs', 'abs', 'waist'),
];

const _equipmentOptions = <String>[
  'barbell',
  'dumbbell',
  'cable',
  'leverage machine',
  'smith machine',
  'body weight',
  'band',
  'kettlebell',
];

/// Lembar isian gerakan custom. Menyimpan ke store lalu mengembalikan
/// gerakan barunya lewat `pop`.
class CustomExerciseSheet extends StatefulWidget {
  const CustomExerciseSheet({super.key, this.initialName = ''});

  final String initialName;

  @override
  State<CustomExerciseSheet> createState() => _CustomExerciseSheetState();
}

class _CustomExerciseSheetState extends State<CustomExerciseSheet> {
  late final _name = TextEditingController(text: _capitalise(widget.initialName));
  int? _muscle;
  String? _equipment;
  bool _saving = false;

  static String _capitalise(String s) {
    final t = s.trim();
    return t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
  }

  @override
  void initState() {
    super.initState();
    _guess(widget.initialName);
  }

  /// Tebak otot dan alat dari nama yang diketik — "single arm lat pulldown"
  /// hampir pasti punggung dan cable. Tebakan tetap bisa diganti.
  void _guess(String name) {
    final n = name.toLowerCase();
    const muscleWords = <String, String>{
      'pulldown': 'Back', 'row': 'Back', 'lat': 'Back', 'pull up': 'Back', 'pullup': 'Back', 'chin': 'Back',
      'shrug': 'Traps', 'bench': 'Chest', 'chest': 'Chest', 'fly': 'Chest', 'pec': 'Chest', 'push up': 'Chest',
      'press': 'Shoulders', 'lateral': 'Shoulders', 'delt': 'Shoulders', 'raise': 'Shoulders',
      'curl': 'Biceps', 'pushdown': 'Triceps', 'tricep': 'Triceps', 'extension': 'Triceps', 'dip': 'Triceps',
      'squat': 'Quads', 'leg press': 'Quads', 'lunge': 'Quads', 'deadlift': 'Hamstrings', 'rdl': 'Hamstrings',
      'bench press': 'Chest', 'chest press': 'Chest', 'shoulder press': 'Shoulders',
      'overhead press': 'Shoulders', 'military press': 'Shoulders', 'hip thrust': 'Glutes', 'glute': 'Glutes', 'calf': 'Calves', 'crunch': 'Abs', 'plank': 'Abs', 'ab ': 'Abs',
    };
    const gearWords = <String, String>{
      'cable': 'cable', 'pulldown': 'cable', 'barbell': 'barbell', 'bb ': 'barbell', 'dumbbell': 'dumbbell',
      'db ': 'dumbbell', 'machine': 'leverage machine', 'smith': 'smith machine', 'band': 'band',
      'kettlebell': 'kettlebell', 'push up': 'body weight', 'pull up': 'body weight', 'dip': 'body weight',
    };
    // Frasa yang lebih panjang dicek lebih dulu: "leg press" harus menang dari
    // "press", dan "tricep extension" dari "extension".
    String? pick(Map<String, String> words) {
      final keys = words.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
      for (final k in keys) {
        if ('$n '.contains(k)) return words[k];
      }
      return null;
    }

    final m = pick(muscleWords);
    if (m != null) _muscle = _muscleOptions.indexWhere((o) => o.$1 == m);
    _equipment = pick(gearWords);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = context.t;
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    final problem = name.isEmpty ? t.needExerciseName : (_muscle == null ? t.needMuscle : null);
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _saving = true);
    final m = _muscleOptions[_muscle!];
    final ex = await WorkoutScope.read(context).addCustomExercise(
      name: name,
      target: m.$2,
      bodyPart: m.$3,
      equipment: _equipment ?? '',
    );
    if (mounted) Navigator.of(context).pop(ex);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    OutlineInputBorder border(Color colour) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.control),
          borderSide: BorderSide(color: colour),
        );

    Widget chip(String label, bool on, VoidCallback onTap) => Material(
          color: on ? c.accentSoft : c.surface2,
          borderRadius: BorderRadius.circular(GymRadius.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(GymRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GymRadius.pill),
                border: Border.all(color: on ? c.accent : c.border),
              ),
              child: Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? c.accent : c.text2)),
            ),
          ),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.newCustomExercise, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              SectionLabel(t.exerciseNameLabel),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                autofocus: widget.initialName.isEmpty,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (v) {
                  if (_muscle == null || _equipment == null) setState(() => _guess(v));
                },
                style: TextStyle(fontSize: 15, color: c.text),
                decoration: InputDecoration(
                  hintText: t.exerciseNameHint,
                  hintStyle: TextStyle(fontSize: 15, color: c.text3),
                  filled: true,
                  fillColor: c.bgNested,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: border(c.border),
                  enabledBorder: border(c.border),
                  focusedBorder: border(c.accent),
                ),
              ),
              const SizedBox(height: 16),
              SectionLabel(t.mainMuscle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, m) in _muscleOptions.indexed)
                    chip(t.muscle(m.$1), _muscle == i, () => setState(() => _muscle = i)),
                ],
              ),
              const SizedBox(height: 16),
              SectionLabel(t.equipmentLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _equipmentOptions)
                    chip(_capitalise(e), _equipment == e,
                        () => setState(() => _equipment = _equipment == e ? null : e)),
                ],
              ),
              const SizedBox(height: 22),
              GymButton(label: t.save, onPressed: _saving ? null : _save),
            ],
          ),
        ),
      ),
    );
  }
}
