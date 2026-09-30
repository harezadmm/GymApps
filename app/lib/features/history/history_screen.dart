/// Tab History — artboard `11 History`.
///
/// Membaca riwayat asli dari [WorkoutStore]. Susunan dan tokennya tetap sama
/// dengan artboard; yang berubah cuma sumber angkanya. Ini juga layar tempat
/// orang memeriksa apakah sesinya benar-benar tersimpan, jadi ia tidak boleh
/// menunjukkan apa pun yang tidak ada di disk.
///
/// Riwayat bisa disunting penuh dari sini: sesi dibuka lagi kalau terlanjur
/// diselesaikan (menekan "selesai" saat yang dimaksud cuma menutup timer),
/// diubah, dihapus dengan urungkan, dan sesi yang dilakukan tanpa HP dicatat
/// belakangan.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/charts.dart';
import '../../core/gym_icons.dart';
import '../../core/illustration.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_history.dart';
import '../../core/theme.dart';
import '../../core/weights.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../session/session_launcher.dart';
import 'workout_edit_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// Rutinitas yang sedang dipilih di chip filter, null = semua. Disimpan
  /// sebagai nama, bukan indeks chip: dulu menghapus sesi terakhir sebuah
  /// rutinitas menggeser daftar chip, dan indeks yang sama diam-diam menunjuk
  /// rutinitas berikutnya.
  String? _routine;

  /// Sesi yang dihapus tapi masih bisa diurungkan. Disembunyikan seketika —
  /// dari daftar, kotak aktivitas, label bulan, dan chip — sementara store
  /// belum disentuh sama sekali; [WorkoutStore.removeWorkout] baru dipanggil
  /// saat SnackBar-nya tertutup tanpa URUNGKAN (lihat [_deleteWithUndo]).
  final _hidden = <Workout>{};

  /// Nama rutinitas yang benar-benar ada di riwayat — dulu tertulis
  /// Push/Pull/Legs apa pun program orangnya.
  static List<String> _routinesIn(List<Workout> all) {
    final seen = <String>[];
    for (final w in all) {
      final r = w.routine;
      if (r != null && r.isNotEmpty && !seen.contains(r)) seen.add(r);
    }
    return seen.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final all = [for (final w in store.workouts) if (!_hidden.contains(w)) w];
    final routines = _routinesIn(all);
    final selected = _routine;
    // Chip yang sedang dipilih tetap ada walau sesinya habis (sesi terakhir
    // rutinitas itu baru dihapus): layar tetap di filter yang sama dan
    // menulis "belum ada sesi", bukan melompat ke filter lain.
    if (selected != null && !routines.contains(selected)) routines.add(selected);

    final sessions = [
      for (final w in all)
        if (selected == null || w.routine == selected) w,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Reveal(
          child: ScreenHeader(
            title: t.history,
            actions: [
              // Kalender bulanan belum ada — kotak aktivitas di bawah sudah
              // menjawab "kapan saja aku latihan". Tombol + menawarkan sesi
              // baru: dijalankan sekarang, atau dicatat dari yang sudah lewat.
              SquareIconButton(
                icon: GymIcons.plus,
                tone: c.accent,
                tooltip: t.newSessionTitle,
                onPressed: _showAddSheet,
              ),
            ],
          ),
        ),
        Reveal(
          index: 1,
          child: GymCard(
            radius: GymRadius.large,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: SectionLabel(t.activity)),
                    Text(t.sessionsThisYear(_thisYear(all)), style: TextStyle(fontSize: 12, color: c.text2)),
                  ],
                ),
                const SizedBox(height: 14),
                Builder(builder: (context) {
                  final (levels, months) = _heatmap(all);
                  return ActivityHeatmap(levels: levels, monthLabels: months);
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          index: 2,
          child: FilterChips(
            labels: [t.all, ...routines],
            index: selected == null ? 0 : routines.indexOf(selected) + 1,
            onChanged: (i) => setState(() => _routine = i == 0 ? null : routines[i - 1]),
          ),
        ),
        const SizedBox(height: 18),
        if (!store.loaded)
          // Riwayat masih dibaca dari disk. Jangan tulis "belum ada sesi" di
          // sini — itu kalimat yang paling menakutkan untuk dibaca keliru.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (all.isEmpty)
          Reveal(index: 3, child: _EmptyHistory())
        else
          // Ganti filter memudarkan daftar lama dan memunculkan yang baru —
          // tanpa itu baris-barisnya bertukar isi di tempat dan mata kehilangan
          // jejak mana yang baru.
          //
          // Kuncinya filter saja, dan teks "belum ada sesi" ada di dalam anak
          // yang sama. Dulu daftar dan teks kosong punya kunci berbeda:
          // menggeser baris terakhir di satu filter mengganti kunci, dan
          // AnimatedSwitcher menahan daftar lama — beserta Dismissible yang
          // sudah tergeser — selama memudar, yang dilarang Flutter.
          FadeSwap(
            child: Column(
              key: ValueKey<String?>(selected),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sessions.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text(t.noSessionsOf(selected ?? t.all),
                              style: TextStyle(fontSize: 13.5, color: c.text2)),
                        ),
                      ),
                    ]
                  : _rows(sessions),
            ),
          ),
      ],
    );
  }

  /// Baris sesi dengan label bulan di setiap pergantian bulan — dulu hanya
  /// bulan pertama yang diberi label, dan daftar setahun terbaca sebagai satu
  /// bulan panjang.
  ///
  /// Setiap [Reveal] berkunci — sesi lewat identitas objeknya, label lewat
  /// bulannya. Tanpa kunci, baris yang kembali karena URUNGKAN dicocokkan
  /// menurut posisi: animasi kedatangannya jatuh ke baris lain yang kebetulan
  /// menempati posisi itu, dan baris yang kembali muncul tanpa animasi.
  List<Widget> _rows(List<Workout> sessions) {
    final out = <Widget>[];
    String? month;
    var i = 0;
    for (final w in sessions) {
      final m = w.date.length >= 7 ? w.date.substring(0, 7) : w.date;
      if (m != month) {
        month = m;
        if (out.isNotEmpty) out.add(SizedBox(key: ValueKey('gap-$m'), height: 8));
        out.add(Reveal(
          key: ValueKey('month-$m'),
          index: i++,
          child: Padding(padding: const EdgeInsets.only(bottom: 10), child: SectionLabel(_monthLabel(w.date))),
        ));
      }
      out.add(Reveal(
        key: ObjectKey(w),
        index: i++,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SessionRow(
            workout: w,
            onTap: () => _showDetail(w),
            confirmDelete: () => _confirmDelete(w),
            onDismissed: () => _deleteWithUndo(w),
          ),
        ),
      ));
    }
    return out;
  }

  /// Tombol +: sesi bebas yang dijalankan sekarang, atau sesi lampau yang
  /// dicatat lewat editor. Dulu + langsung membuka sesi bebas, dan tidak ada
  /// cara mencatat latihan kemarin yang HP-nya tertinggal.
  Future<void> _showAddSheet() async {
    final c = context.gym;
    final t = context.t;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.newSessionTitle, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 12),
              SettingsGroup(children: [
                SettingsTile(
                  icon: GymIcons.play,
                  hue: c.hues.green,
                  label: t.startFreestyleNow,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    openFreestyleSession(context, t.freestyle);
                  },
                ),
                SettingsTile(
                  icon: GymIcons.calendar,
                  hue: c.hues.cyan,
                  label: t.logPastSession,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    openManualEntry(context);
                  },
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// Satu dialog untuk semua jalur hapus — dari sheet detail maupun geser.
  Future<bool> _confirmDelete(Workout workout) async {
    final c = context.gym;
    final t = context.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
        title: Text(t.deleteSessionTitle, style: Theme.of(context).textTheme.titleLarge),
        content: Text('${workout.routine ?? t.freestyleSession} · ${workout.date}',
            style: TextStyle(fontSize: 14, color: c.text2)),
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
    return ok == true;
  }

  /// Hapus dengan urungkan. Dulu hapus langsung permanen, dan satu ketukan
  /// meleset membuang latihan yang tidak bisa diketik ulang dari ingatan.
  ///
  /// Hapusnya *ditunda*, bukan dihapus lalu dikembalikan: baris disembunyikan
  /// seketika, dan [WorkoutStore.removeWorkout] baru dipanggil saat SnackBar
  /// tertutup dengan alasan apa pun selain URUNGKAN (habis waktu, digeser,
  /// diganti SnackBar lain). Hapus-lalu-kembalikan sempat mendorong tombstone
  /// ke server selama SnackBar tampil; HP lain yang sinkron di jeda itu
  /// menyimpannya, dan karena tombstone hanya bertambah saat digabung, sesi
  /// yang sudah diurungkan terhapus lagi di sinkron berikutnya.
  ///
  /// Penyelesaiannya hanya memegang store, bukan layar ini: store hidup lebih
  /// lama dari tab Riwayat, jadi pindah layar selagi SnackBar tampil tetap
  /// menghapus. Store yang sudah ditutup (keluar akun) tidak menemukan objek
  /// yang sama dan tidak menghapus apa pun.
  void _deleteWithUndo(Workout workout) {
    final store = WorkoutScope.read(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final c = context.gym;
    final t = context.t;
    setState(() => _hidden.add(workout));

    Future<void> commit() async {
      await store.removeWorkout(workout);
      if (mounted) setState(() => _hidden.remove(workout));
    }

    if (messenger == null) {
      // Tanpa tempat menampilkan URUNGKAN, tidak ada yang perlu ditunggu.
      unawaited(commit());
      return;
    }
    // Satu URUNGKAN dalam satu waktu. SnackBar hapus sebelumnya ditutup dulu
    // (dan hapusnya dijalankan), bukan diantrekan: antrean membuat sesi kedua
    // tersembunyi-tapi-belum-terhapus sampai SnackBar pertama habis waktu.
    messenger.hideCurrentSnackBar();
    final bar = messenger.showSnackBar(SnackBar(
      content: Text(t.sessionDeleted),
      // SnackBar dengan tombol bawaannya menetap sampai ditutup tangan, dan
      // hapus yang tertunda ikut menggantung selama itu. Pembaca layar diberi
      // waktu lebih lama untuk mencapai tombolnya.
      persist: false,
      duration: MediaQuery.accessibleNavigationOf(context) ? const Duration(seconds: 10) : const Duration(seconds: 5),
      action: SnackBarAction(
        label: t.undo,
        textColor: c.accent,
        onPressed: () {
          if (mounted) setState(() => _hidden.remove(workout));
        },
      ),
    ));
    unawaited(bar.closed.then((reason) async {
      if (reason != SnackBarClosedReason.action) await commit();
    }));
  }

  /// Detail satu sesi: gerakan dan setnya, lanjutkan, edit, hapus (FR-F1).
  Future<void> _showDetail(Workout workout) async {
    final store = WorkoutScope.read(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final catalog = await ExerciseCatalog.load();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.gym.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet))),
      builder: (sheetContext) {
        final c = sheetContext.gym;
        final t = sheetContext.t;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(workout.routine ?? t.freestyleSession, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                [
                  workout.date,
                  if (workout.durationSeconds != null) '${workout.durationSeconds! ~/ 60} min',
                ].join(' · '),
                style: TextStyle(fontSize: 13, color: c.text2),
              ),
              if (workout.notes != null) ...[
                const SizedBox(height: 10),
                Text(workout.notes!, style: TextStyle(fontSize: 13.5, height: 1.4, color: c.text)),
              ],
              const SizedBox(height: 16),
              for (final e in workout.entries) ...[
                Text(catalog.nameOf(e.exerciseId), style: Theme.of(context).textTheme.titleMedium),
                if (e.note != null) ...[
                  const SizedBox(height: 2),
                  Text(e.note!, style: TextStyle(fontSize: 12.5, color: c.warn)),
                ],
                const SizedBox(height: 6),
                for (final (i, s) in e.sets.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: Text(
                              switch (s.phase) {
                                SetPhase.warmup => 'W',
                                SetPhase.drop => 'D',
                                SetPhase.restPause => 'RP',
                                SetPhase.work => '${e.sets.take(i + 1).where((x) => x.isWork).length}',
                              },
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800, color: s.isWork ? c.text2 : c.warn)),
                        ),
                        Expanded(
                          child: Text(
                              (e.target?.mode ?? LogMode.reps) == LogMode.time
                                  ? '${s.seconds}s'
                                  : '${context.wLabel(s.weight, bodyweight: e.target?.bodyweight ?? false)} ${context.unitLabel} × ${s.reps}'
                                      '${s.rir == null ? '' : '  @${s.rir}'}',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: s.done ? c.text : c.text3,
                                  fontFeatures: const [FontFeature.tabularFigures()])),
                        ),
                        Icon(s.done ? GymIcons.checkCircle : GymIcons.circle,
                            size: 16, color: s.done ? c.doneInk : c.text3),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              // Lanjutkan: untuk sesi yang terlanjur diselesaikan. Dikonfirmasi
              // dulu karena ia mengeluarkan sesi dari riwayat dan memutar
              // rotasi program — bukan sekadar membuka layar.
              GymButton(
                label: t.resumeSession,
                icon: GymIcons.play,
                height: 48,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: sheetContext,
                    builder: (context) => AlertDialog(
                      backgroundColor: c.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
                      title: Text(t.resumeSessionTitle, style: Theme.of(context).textTheme.titleLarge),
                      content: Text(t.resumeSessionHint, style: TextStyle(fontSize: 14, height: 1.4, color: c.text2)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
                        ),
                        GymButton(
                          label: t.resume,
                          height: 42,
                          expand: false,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    ),
                  );
                  if (ok != true || !sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  if (!mounted) return;
                  await reopenWorkoutSession(this.context, workout);
                },
              ),
              const SizedBox(height: 6),
              Text(t.resumeSessionHint,
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, height: 1.35, color: c.text2)),
              const SizedBox(height: 14),
              GymButton(
                label: t.edit,
                icon: GymIcons.edit,
                tone: GymButtonTone.neutral,
                height: 44,
                onPressed: () async {
                  final updated = await Navigator.of(sheetContext).push<Workout>(
                    MaterialPageRoute(builder: (_) => WorkoutEditScreen(workout: workout, catalog: catalog)),
                  );
                  if (updated == null) return;
                  await store.replaceWorkout(workout, updated);
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  messenger?.showSnackBar(SnackBar(content: Text(t.sessionUpdated)));
                },
              ),
              const SizedBox(height: 10),
              GymButton(
                label: t.delete,
                icon: GymIcons.trash,
                tone: GymButtonTone.danger,
                height: 44,
                onPressed: () async {
                  final ok = await _confirmDelete(workout);
                  if (!ok || !sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  if (!mounted) return;
                  _deleteWithUndo(workout);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static int _thisYear(List<Workout> all) {
    final year = DateTime.now().year.toString();
    return all.where((w) => w.date.startsWith(year)).length;
  }

  String _monthLabel(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    return d == null ? '' : '${context.t.monthLong(d.month)} ${d.year}';
  }

  /// Level 0..4 per hari untuk 24 minggu terakhir, plus label bulannya.
  ///
  /// Kolom = minggu, dibaca kolom per kolom, sama seperti artboard. Petaknya
  /// selalu berakhir di hari ini supaya sel paling kanan-bawah adalah hari
  /// yang sedang dijalani, bukan hari acak di tengah minggu.
  (List<int>, List<String>) _heatmap(List<Workout> all) {
    const weeks = 24;
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    // Mundur ke Senin minggu ini, lalu mundur 23 minggu lagi.
    final thisMonday = end.subtract(Duration(days: end.weekday - 1));
    final start = thisMonday.subtract(const Duration(days: 7 * (weeks - 1)));

    final setsPerDay = <String, int>{};
    for (final w in all) {
      final n = w.entries.fold(0, (a, e) => a + e.sets.where((s) => s.done && !s.isWarmup).length);
      setsPerDay[w.date] = (setsPerDay[w.date] ?? 0) + n;
    }

    final levels = <int>[];
    final months = <String>[];
    for (var week = 0; week < weeks; week++) {
      final monday = start.add(Duration(days: 7 * week));
      // Satu label per bulan, ditulis di minggu pertama yang menyentuhnya.
      if (week == 0 || monday.day <= 7) {
        months.add(context.t.monthShort(monday.month));
      }
      for (var day = 0; day < 7; day++) {
        final d = monday.add(Duration(days: day));
        final key = '${d.year}-${_two(d.month)}-${_two(d.day)}';
        final sets = setsPerDay[key] ?? 0;
        levels.add(switch (sets) {
          0 => 0,
          <= 8 => 1,
          <= 15 => 2,
          <= 22 => 3,
          _ => 4,
        });
      }
    }
    return (levels, months);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) => EmptyState(
        art: GymArt.emptyHistory,
        title: context.t.noSessionsYet,
        body: context.t.noSessionsYetHint,
      );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.workout,
    required this.onTap,
    required this.confirmDelete,
    required this.onDismissed,
  });

  final Workout workout;
  final VoidCallback onTap;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDismissed;

  /// Set kerja saja. Pemanasan tidak dihitung sebagai latihan di tempat lain
  /// juga, dan menghitungnya di sini akan membuat angkanya saling bertentangan.
  Iterable<SetRow> get _workingSets =>
      workout.entries.expand((e) => e.sets).where((s) => s.done && !s.isWarmup);

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final date = DateTime.tryParse(workout.date);
    final volume = _workingSets.fold(0.0, (a, s) => a + s.weight * s.reps);

    // Warna identitas per rutinitas (dari namanya), sebagai garis di tepi
    // kiri — seperti kartu "Water / Breakfast" di referensi. Pemindai cepat
    // membedakan Push dari Pull tanpa membaca.
    final hue = c.hues.at((workout.routine ?? '').hashCode.abs());
    return Dismissible(
      // Identitas objek, bukan sidik jari isi: menghitung sha1 tiap baris
      // setiap build terlalu mahal untuk daftar setahun, dan objek sesi tetap
      // sama selama tidak disunting.
      key: ObjectKey(workout),
      direction: DismissDirection.endToStart,
      // Lewat GymMotion supaya "kurangi gerak" di sistem ikut mematikan
      // geser-lepas dan penyusutan barisnya, seperti animasi lain.
      movementDuration: GymMotion.of(context, GymMotion.normal),
      resizeDuration: GymMotion.of(context, GymMotion.normal),
      confirmDismiss: (_) => confirmDelete(),
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(GymRadius.card)),
        child: Icon(GymIcons.trash, size: 22, color: c.accentInk),
      ),
      child: PressScale(
        child: Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(GymRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(GymRadius.card),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: hue, width: 4))),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Column(
                      children: [
                        Text(date == null ? '--' : _HistoryScreenState._two(date.day),
                            style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: c.text,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                        const SizedBox(height: 1),
                        Text(date == null ? '' : t.weekdayShort(date.weekday).toUpperCase(),
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: c.text3)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(workout.routine ?? t.freestyleSession,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (workout.durationSeconds != null) _clock(workout.durationSeconds!),
                            context.volume(volume),
                            t.setsSuffix(_workingSets.length),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5, color: c.text2, fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ],
                    ),
                  ),
                  // Tidak ada glyph chevron di paket ikon; yang Material dipakai
                  // karena bentuknya netral dan sudah dipakai SettingsTile.
                  Icon(GymIcons.chevronRight, size: 18, color: c.text3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _clock(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }
}
