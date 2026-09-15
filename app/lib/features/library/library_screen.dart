/// Library gerakan — artboard `07 Exercise Library`.
///
/// Daftarnya dibaca dari aset asli, bukan contoh: 1.324 gerakan, jadi
/// listnya dibangun malas dengan [ListView.builder] dan pencarian berjalan
/// di setiap ketukan.
library;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _query = TextEditingController();
  late Future<ExerciseCatalog> _catalog;
  int _sort = 0;

  /// Gerakan yang ditandai bintang. Belum tersimpan di mana pun — hilang saat
  /// layar ditutup, dan itu disebutkan di banner filter.
  final _starred = <String>{};

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

  List<Exercise> _arrange(ExerciseCatalog catalog) {
    final found = catalog.search(_query.text);
    final list = [...found];
    switch (_sort) {
      case 1: // A–Z
        list.sort((a, b) => a.name.compareTo(b.name));
      case 2: // By muscle
        list.sort((a, b) => a.bodyPart == b.bodyPart ? a.name.compareTo(b.name) : a.bodyPart.compareTo(b.bodyPart));
      default: // Performed — favorit dulu, sisanya urutan katalog
        list.sort((a, b) {
          final sa = _starred.contains(a.id) ? 0 : 1;
          final sb = _starred.contains(b.id) ? 0 : 1;
          return sa == sb ? 0 : sa - sb;
        });
    }
    return list;
  }

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
                    icon: Icon(Icons.arrow_back, color: c.text2),
                    tooltip: context.t.back,
                  ),
                  Expanded(child: _SearchField(controller: _query, onChanged: (_) => setState(() {}))),
                  IconButton(onPressed: () {}, icon: Icon(Icons.tune, color: c.text2), tooltip: context.t.filters),
                  IconButton(onPressed: () {}, icon: Icon(Icons.add, color: c.accent), tooltip: context.t.customExercise),
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

                  final list = _arrange(snap.data!);
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
                              Icon(Icons.filter_alt_outlined, size: 15, color: c.text2),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(context.t.equipmentProfile('Gym A'),
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
                                child: Text(context.t.nothingMatches(_query.text),
                                    style: TextStyle(fontSize: 13.5, color: c.text2)),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                                itemCount: list.length,
                                itemBuilder: (context, i) {
                                  final e = list[i];
                                  return _ExerciseRow(
                                    exercise: e,
                                    starred: _starred.contains(e.id),
                                    onStar: () => setState(() =>
                                        _starred.contains(e.id) ? _starred.remove(e.id) : _starred.add(e.id)),
                                    onTap: () => Navigator.of(context).pop(e),
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
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    OutlineInputBorder border(Color colour) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.pill),
          borderSide: BorderSide(color: colour),
        );

    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14.5, color: c.text),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.t.searchExercise,
          hintStyle: TextStyle(fontSize: 14.5, color: c.text2),
          prefixIcon: Icon(Icons.search, size: 19, color: c.text2),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(GymRadius.small),
                border: Border.all(color: c.border),
              ),
              child: Icon(exercise.icon, size: 20, color: c.text2),
            ),
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
                  Text(exercise.subtitle, style: TextStyle(fontSize: 12.5, color: c.text2)),
                ],
              ),
            ),
            IconButton(
              onPressed: onStar,
              icon: Icon(starred ? Icons.star : Icons.star_border, size: 19, color: starred ? c.warn : c.text3),
              tooltip: starred ? 'Remove from favourites' : 'Add to favourites',
            ),
            Icon(Icons.chevron_right, size: 18, color: c.text3),
          ],
        ),
      ),
    );
  }
}
