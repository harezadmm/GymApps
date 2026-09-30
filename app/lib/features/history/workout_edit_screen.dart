/// Edit satu sesi yang sudah tercatat, atau catat sesi yang sudah lewat
/// (FR-F1, FR-E2).
///
/// Log adalah fakta, tapi fakta yang salah ketik harus bisa dibetulkan:
/// 600 kg yang mestinya 60 dulu jadi "PR e1RM 800 kg" selamanya, dan target
/// sesi berikutnya ikut kacau. Karena target selalu dihitung ulang dari
/// riwayat, memperbaiki satu set di sini otomatis memperbaiki target berikutnya.
///
/// Dulu layar ini hanya bisa mengubah set di gerakan yang sudah ada. Sesi
/// yang salah dicatat — gerakan yang terlewat, gerakan salah pilih, rutinitas
/// salah nama — hanya bisa dihapus dan diketik ulang dari nol. Sekarang
/// gerakan bisa ditambah, dibuang, dan diurutkan, rutinitasnya bisa diganti,
/// dan layar yang sama dipakai untuk mencatat sesi yang dilakukan tanpa HP.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/gym_icons.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_history.dart';
import '../../core/theme.dart';
import '../../core/weights.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/program.dart';
import '../../domain/session_plan.dart';
import '../session/session_launcher.dart';

class WorkoutEditScreen extends StatefulWidget {
  const WorkoutEditScreen({super.key, required this.workout, required this.catalog, this.isNew = false});

  final Workout workout;
  final ExerciseCatalog catalog;

  /// Mencatat sesi baru (judul "Catat sesi"), bukan mengubah yang ada.
  /// Isinya sama; yang berbeda hanya judul dan siapa yang menerima hasilnya.
  final bool isNew;

  @override
  State<WorkoutEditScreen> createState() => _WorkoutEditScreenState();
}

/// Satu gerakan di dalam editor. Objek yang bisa berubah, bukan salinan dari
/// `widget.workout.entries`: gerakan ditambah dan dibuang selama layar
/// terbuka, dan daftar yang terikat ke widget tidak bisa mengikutinya.
class _EntryState {
  _EntryState({
    required this.exerciseId,
    required this.target,
    required List<SetRow> sets,
    this.excluded = false,
    String? note,
    this.fresh = false,
  })  : sets = List.of(sets),
        keys = [for (var i = 0; i < sets.length; i++) UniqueKey()],
        note = TextEditingController(text: note ?? '');

  final String exerciseId;

  /// Target yang berlaku saat sesi itu berjalan (kg). Dipertahankan apa
  /// adanya supaya penilaian progresi sesi lama tidak berubah karena disunting.
  final ExerciseConfig? target;
  final bool excluded;
  final List<SetRow> sets;

  /// Satu kunci per baris supaya kotak input tidak bertukar isi saat baris
  /// dihapus.
  final List<Key> keys;
  final TextEditingController note;

  /// Kunci kartu, ikut pindah saat gerakan diurutkan ulang: kotak catatan dan
  /// animasi kedatangan menempel ke gerakannya, bukan ke posisinya.
  final Key cardKey = UniqueKey();

  /// Ditambahkan selagi layar terbuka — kartunya muncul seketika, bukan
  /// menunggu giliran jeda bertingkat seperti kartu yang ada sejak awal.
  final bool fresh;

  bool get timed => (target?.mode ?? LogMode.reps) == LogMode.time;

  /// Set kerja = tercentang, bukan pemanasan, dan benar-benar berisi rep
  /// (atau detik untuk gerakan berwaktu). Centang saja tidak cukup: baris
  /// 0 × 0 yang tercentang bukan latihan, dan dulu itu yang membuat sesi
  /// kosong lolos dari penjaga "belum ada set kerja".
  bool get hasWorkingSet => sets.any((s) => s.done && !s.isWarmup && (timed ? s.seconds > 0 : s.reps > 0));

  int get doneCount => sets.where((s) => s.done).length;

  WorkoutEntry toEntry() {
    final n = note.text.trim();
    return WorkoutEntry(
      exerciseId: exerciseId,
      sets: List.of(sets),
      target: target,
      excluded: excluded,
      note: n.isEmpty ? null : n,
    );
  }

  void dispose() => note.dispose();
}

class _WorkoutEditScreenState extends State<WorkoutEditScreen> {
  late String _date = widget.workout.date;
  late String? _routine = widget.workout.routine;
  late final List<_EntryState> _entries = [
    for (final e in widget.workout.entries)
      _EntryState(exerciseId: e.exerciseId, target: e.target, sets: e.sets, excluded: e.excluded, note: e.note),
  ];
  late final _notes = TextEditingController(text: widget.workout.notes ?? '');

  /// Sidik jari isi editor saat dibuka. Diambil dari [_result], bukan dari
  /// `widget.workout`, supaya perapian yang sama (catatan dipangkas, catatan
  /// kosong jadi null) tidak terbaca sebagai perubahan.
  late final String _initial;

  @override
  void initState() {
    super.initState();
    _initial = workoutKey(_result);
  }

  /// Isinya berbeda dari saat layar dibuka. Dihitung saat ditanya, bukan
  /// dilacak: mengetik di kotak angka sengaja tidak memanggil setState.
  bool get _dirty => workoutKey(_result) != _initial;

  @override
  void dispose() {
    _notes.dispose();
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  /// Dibangun lewat konstruktor, bukan `copyWith`: rutinitasnya bisa diganti
  /// di sini, dan `Workout.copyWith` tidak punya slot untuk itu.
  Workout get _result {
    final notes = _notes.text.trim();
    return Workout(
      date: _date,
      routine: _routine,
      durationSeconds: widget.workout.durationSeconds,
      notes: notes.isEmpty ? null : notes,
      entries: [for (final e in _entries) e.toEntry()],
    );
  }

  /// Sesi tanpa satu set kerja pun bukan latihan — aturan yang sama dengan
  /// tombol selesai di sesi berjalan. Menyimpannya mengotori riwayat dengan
  /// sesi kosong yang ikut dihitung "sesi tahun ini".
  void _save() {
    if (!_entries.any((e) => e.hasWorkingSet)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.noWorkingSets)));
      return;
    }
    GymHaptics.confirm();
    Navigator.of(context).pop(_result);
  }

  /// Tombol tutup dan gestur kembali. Dulu keduanya membuang sesi yang sudah
  /// diketik tanpa bertanya — satu usapan tepi layar yang meleset menghapus
  /// sepuluh menit mengetik ulang latihan kemarin. Kalau belum ada yang
  /// berubah, langsung keluar.
  Future<void> _leave() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final c = context.gym;
    final t = context.t;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
        title: Text(widget.isNew ? t.discardLogTitle : t.discardEditsTitle,
            style: Theme.of(context).textTheme.titleLarge),
        content: Text(t.discardEditsBody, style: TextStyle(fontSize: 14, height: 1.4, color: c.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.keepEditing, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
          ),
          GymButton(
            label: t.discard,
            height: 42,
            expand: false,
            tone: GymButtonTone.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(2015);
    final parsed = DateTime.tryParse(_date) ?? now;
    // Dijepit ke rentang pemilih: sesi bertanggal "besok" (dicatat di HP
    // dengan zona waktu lain) membuat showDatePicker gagal terbuka.
    final current = parsed.isAfter(now) ? now : (parsed.isBefore(first) ? first : parsed);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: first,
      lastDate: now,
    );
    if (picked != null) setState(() => _date = isoDate(picked));
  }

  /// Pilih nama rutinitas dari yang tersimpan, atau "Bebas". Nama, bukan id:
  /// sesi hanya menyimpan nama rutinitasnya, dan filter di riwayat memilah
  /// lewat nama itu.
  Future<void> _pickRoutine() async {
    final store = WorkoutScope.read(context);
    final names = <String?>[null, for (final r in store.routines) r.name];
    final picked = await showModalBottomSheet<(String?,)>(
      context: context,
      backgroundColor: context.gym.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet))),
      builder: (sheet) {
        final c = sheet.gym;
        final t = sheet.t;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.routineLabel, style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 12),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(color: c.bgNested, borderRadius: BorderRadius.circular(GymRadius.card)),
                    clipBehavior: Clip.antiAlias,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final name in names)
                          SelectRow(
                            title: name ?? t.freestyleSession,
                            selected: name == _routine,
                            onTap: () => Navigator.of(sheet).pop((name,)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    // Record satu-slot membedakan "ditutup tanpa memilih" (null) dari
    // "memilih Bebas" (record berisi null).
    if (picked != null) setState(() => _routine = picked.$1);
  }

  /// Tambah gerakan dari library. Baris set pertamanya diisi set kerja terakhir
  /// gerakan itu dari riwayat, sudah tercentang — mencatat sesi kemarin
  /// biasanya berarti "sama seperti biasanya", dan mengetik ulang angka yang
  /// sudah diketahui aplikasi hanya membuang waktu.
  ///
  /// Gerakan yang belum pernah dicatat mendapat baris kosong yang *belum*
  /// tercentang: tidak ada angka yang bisa diklaim sudah dilakukan.
  Future<void> _addExercise() async {
    final store = WorkoutScope.read(context);
    final ex = await pickExercise(context);
    if (ex == null || !mounted) return;
    final history = store.chronological;
    final target = configForAdded(ex.id, history);
    SetRow? lastWork;
    final last = lastEntryFor(history, ex.id);
    if (last != null) {
      for (final s in last.sets.reversed) {
        if (s.done && s.isWork) {
          lastWork = s;
          break;
        }
      }
    }
    final timed = target.mode == LogMode.time;
    setState(() {
      _entries.add(_EntryState(
        exerciseId: ex.id,
        target: target,
        fresh: true,
        sets: [
          SetRow(
            weight: lastWork?.weight ?? 0,
            reps: timed ? 0 : (lastWork?.reps ?? 0),
            seconds: timed ? (lastWork?.seconds ?? 0) : 0,
            done: lastWork != null,
          ),
        ],
      ));
    });
  }

  /// Buang gerakan. Set yang sudah tercentang adalah data yang hilang kalau
  /// salah ketuk, jadi itu saja yang dikonfirmasi; kartu kosong dibuang diam.
  Future<void> _removeEntry(int i) async {
    final e = _entries[i];
    if (e.doneCount > 0) {
      final c = context.gym;
      final t = context.t;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
          title: Text(t.removeExerciseTitle, style: Theme.of(context).textTheme.titleLarge),
          content: Text(t.removeExerciseBody(e.doneCount), style: TextStyle(fontSize: 14, color: c.text2)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
            ),
            GymButton(
              label: t.delete,
              height: 42,
              expand: false,
              tone: GymButtonTone.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _entries.removeAt(i).dispose());
  }

  void _move(int from, int to) {
    if (to < 0 || to >= _entries.length) return;
    GymHaptics.tap();
    setState(() => _entries.insert(to, _entries.removeAt(from)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    // Selalu ditahan lalu diputuskan di [_leave], bukan `canPop: !_dirty`:
    // mengetik angka tidak memanggil setState, jadi nilai yang dihitung saat
    // build tidak tahu isinya sudah berubah. SAVE memakai `pop` langsung, yang
    // tidak melewati penahan ini.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      // Silang Barudak Lier memenuhi kotak glyph; 18 setara
                      // silang Material 24 yang dulu di sini.
                      icon: Icon(GymIcons.close, size: 18, color: c.text2),
                      tooltip: t.cancel,
                    ),
                    Expanded(
                      child: Text(widget.isNew ? t.logSession : t.editSession,
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    GymButton(
                      label: t.save,
                      height: 38,
                      expand: false,
                      shape: GymButtonShape.pill,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    Reveal(
                      child: SettingsGroup(children: [
                        SettingsTile(icon: GymIcons.calendar, label: t.dateLabel, value: _date, onTap: _pickDate),
                        SettingsTile(
                          icon: GymIcons.menu,
                          hue: c.hues.cyan,
                          label: t.routineLabel,
                          value: _routine ?? t.freestyleSession,
                          onTap: _pickRoutine,
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Reveal(
                      index: 1,
                      child: TextField(
                        controller: _notes,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(labelText: t.notesLabel),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final (i, e) in _entries.indexed) ...[
                      Reveal(
                        key: e.cardKey,
                        index: i + 2,
                        delay: e.fresh ? Duration.zero : null,
                        child: _EntryCard(
                          entry: e,
                          name: widget.catalog.nameOf(e.exerciseId),
                          first: i == 0,
                          last: i == _entries.length - 1,
                          onChanged: () => setState(() {}),
                          onMoveUp: () => _move(i, i - 1),
                          onMoveDown: () => _move(i, i + 1),
                          onRemove: () => _removeEntry(i),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Reveal(
                      index: _entries.length + 2,
                      child: GymButton(
                        label: t.addExercise,
                        icon: GymIcons.plus,
                        tone: GymButtonTone.neutral,
                        height: 48,
                        onPressed: _addExercise,
                      ),
                    ),
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

/// Kartu satu gerakan: nama, aksi (hapus, urutkan), baris set, catatan.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.name,
    required this.first,
    required this.last,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final _EntryState entry;
  final String name;
  final bool first;
  final bool last;
  final VoidCallback onChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return GymCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: t.removeExercise,
                visualDensity: VisualDensity.compact,
                icon: Icon(GymIcons.trash, size: 19, color: c.text2),
              ),
              PopupMenuButton<int>(
                tooltip: t.exerciseActions,
                icon: Icon(GymIcons.moreVertical, size: 20, color: c.text2),
                color: c.surface2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.control)),
                onSelected: (v) => v == 0 ? onMoveUp() : onMoveDown(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 0, enabled: !first, child: Text(t.moveUp)),
                  PopupMenuItem(value: 1, enabled: !last, child: Text(t.moveDown)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              children: [
                for (var j = 0; j < entry.sets.length; j++)
                  _EditRow(
                    key: entry.keys[j],
                    set: entry.sets[j],
                    timed: entry.timed,
                    // Baca-ubah-tulis dari daftar, bukan dari `set` yang
                    // ditangkap saat build: lihat [_EditRow.onEdit].
                    onEdit: (edit) => entry.sets[j] = edit(entry.sets[j]),
                    onToggle: () {
                      GymHaptics.tap();
                      entry.sets[j] = entry.sets[j].copyWith(done: !entry.sets[j].done);
                      onChanged();
                    },
                    onDelete: () {
                      entry.sets.removeAt(j);
                      entry.keys.removeAt(j);
                      onChanged();
                    },
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              final lastWork = entry.sets.lastWhere((s) => s.isWork, orElse: () => const SetRow());
              entry.sets.add(SetRow(weight: lastWork.weight, reps: lastWork.reps, seconds: lastWork.seconds, done: true));
              entry.keys.add(UniqueKey());
              onChanged();
            },
            icon: Icon(GymIcons.plus, size: 16, color: c.accent),
            label: Text(t.addSet, style: TextStyle(color: c.accent, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextField(
              controller: entry.note,
              decoration: InputDecoration(hintText: t.exerciseNoteHint, isDense: true),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    super.key,
    required this.set,
    required this.timed,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  /// Nilai saat baris dibangun — hanya untuk isi awal kotak dan tampilan.
  final SetRow set;
  final bool timed;

  /// Menerima *perubahan* (fungsi atas set terkini), bukan set jadi. Mengetik
  /// sengaja tidak memanggil setState, jadi [set] di sini basi begitu satu
  /// kotak diketik: dulu "70" di kotak beban lalu "9" di kotak rep menyimpan
  /// 60 × 9, karena rep ditulis di atas salinan lama yang bebannya masih 60.
  final ValueChanged<SetRow Function(SetRow)> onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final label = switch (set.phase) {
      SetPhase.warmup => 'W',
      SetPhase.drop => 'D',
      SetPhase.restPause => 'RP',
      SetPhase.work => '•',
    };
    InputDecoration deco(String hint) => InputDecoration(
          isDense: true,
          hintText: hint,
          filled: true,
          fillColor: c.surface2,
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(GymRadius.input), borderSide: BorderSide.none),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: set.isWork ? c.text2 : c.warn)),
          ),
          Expanded(
            child: TextFormField(
              initialValue: set.weight == 0 ? '' : context.wDelta(set.weight),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              textAlign: TextAlign.center,
              decoration: deco(context.unitLabel),
              onChanged: (v) {
                final kg = context.typedToKg(double.tryParse(v.replaceAll(',', '.')) ?? 0);
                onEdit((s) => s.copyWith(weight: kg));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: timed ? (set.seconds == 0 ? '' : '${set.seconds}') : (set.reps == 0 ? '' : '${set.reps}'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: deco(timed ? 's' : 'reps'),
              onChanged: (v) {
                final n = int.tryParse(v) ?? 0;
                onEdit((s) => timed ? s.copyWith(seconds: n) : s.copyWith(reps: n));
              },
            ),
          ),
          IconButton(
            onPressed: onToggle,
            visualDensity: VisualDensity.compact,
            // Centang yang membesar sedikit lalu kembali: perubahan keadaan
            // yang paling sering ditekan di layar ini, dan mata harus
            // menangkapnya tanpa membaca ulang barisnya.
            icon: AnimatedScale(
              scale: set.done ? 1 : 0.9,
              duration: GymMotion.of(context, GymMotion.quick),
              curve: GymMotion.pop,
              child: Icon(set.done ? GymIcons.checkCircle : GymIcons.circle,
                  color: set.done ? c.doneInk : c.text3, size: 20),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            icon: Icon(GymIcons.close, color: c.text3, size: 14),
          ),
        ],
      ),
    );
  }
}
