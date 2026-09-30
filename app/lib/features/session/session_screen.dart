/// Layar mencatat sesi latihan — artboard `08 Workout Session`.
///
/// Ini layar yang dipakai sambil berdiri di antara set, jadi aturannya berbeda
/// dari layar lain: angka besar, target sentuh lebar, dan tidak ada yang perlu
/// digulir untuk tahu set berikutnya berapa.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/weights.dart';
import '../../domain/units.dart';

import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/gym_icons.dart';
import '../../core/keep_awake.dart';
import '../../core/motion.dart';
import '../../core/rest_alert.dart';
import '../../core/strings.dart';
import '../../core/strings_assisted.dart';
import '../../core/strings_session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../../data/workout_store.dart';
import '../../domain/models.dart';
import '../../domain/program.dart';
import '../../domain/progression.dart';
import '../../domain/routine_sync.dart';
import '../../domain/session_plan.dart';
import '../profile/gym_profiles.dart';
import 'exercise_history_sheet.dart';
import 'finish_screen.dart';
import 'rest_screen.dart';
import 'rest_timer.dart';
import 'session_launcher.dart';

/// Satu gerakan di dalam sesi yang sedang berjalan.
class SessionExercise {
  SessionExercise({
    required this.name,
    required this.config,
    required List<SetRow> sets,
    required List<String> previous,
    required this.icon,
    this.prescription,
    Duration? restDuration,
    this.restEnabled = true,
    this.expanded = false,
    this.note,
    this.lastNote,
  }) : sets = List.of(sets),
       previous = List.of(previous),
       rowKeys = [for (var i = 0; i < sets.length; i++) UniqueKey()],
       rowIds = [for (var i = 0; i < sets.length; i++) UniqueKey()],
       restDuration = restDuration ?? const Duration(seconds: 90);

  final String name;

  /// Target yang dibekukan ke sesi. Bisa berubah di tengah sesi hanya untuk
  /// hal yang bukan penilaian — superset dinyalakan atau dimatikan.
  ExerciseConfig config;
  final List<SetRow> sets;

  /// Teks kolom PREV per baris — "70 × 8". Sengaja teks, bukan angka: kolom ini
  /// hanya untuk dibaca, dan sesi lama bisa punya jumlah set yang berbeda.
  final List<String> previous;

  /// Satu kunci per baris, bergerak bersama barisnya. Kotak input kg/rep
  /// memegang teksnya sendiri; tanpa kunci yang ikut pindah, menambah warm-up
  /// di depan membuat angka yang sedang diketik pindah ke baris lain.
  final List<Key> rowKeys;

  /// Identitas baris yang tidak pernah diganti selama barisnya hidup — untuk
  /// animasi kedatangan. [rowKeys] sengaja diganti saat beban diteruskan ke
  /// baris di bawahnya (supaya kotak inputnya dibangun ulang), dan kalau
  /// kunci itu juga yang dipegang animasi, baris-baris di bawah memudar
  /// hilang lalu muncul lagi setiap kali satu angka diketik.
  final List<Key> rowIds;

  final IconData icon;

  /// Alasan target (FR-E5), dihitung sekali saat sesi disusun.
  final Prescription? prescription;

  Duration restDuration;
  bool restEnabled;
  bool expanded;

  /// Catatan untuk gerakan ini di sesi ini.
  String? note;

  /// Catatan dari sesi terakhir gerakan yang sama — "kursi posisi 4".
  final String? lastNote;

  int get doneCount => sets.where((s) => s.done && s.isWork).length;
  int get workCount => sets.where((s) => s.isWork).length;

  /// Bentuk yang disimpan sebagai draft sesi. Ikon dan catalog dibaca ulang
  /// saat dipulihkan.
  Map<String, dynamic> toDraft() => {
    'name': name,
    'cfg': config.toJson(),
    'sets': [for (final s in sets) s.toJson()],
    'prev': previous,
    'rest': restDuration.inSeconds,
    if (!restEnabled) 'restOff': true,
    if (expanded) 'open': true,
    if (note != null && note!.isNotEmpty) 'note': note,
    if (lastNote != null) 'lastNote': lastNote,
    if (prescription != null) 'why': prescription!.why,
    if (prescription != null) 'kind': prescription!.kind.name,
    if (prescription != null) 'pol': prescription!.policy.name,
  };

  static SessionExercise fromDraft(Map<String, dynamic> j, IconData icon) {
    Prescription? p;
    if (j['why'] is String) {
      p = Prescription(
        policy: ProgressionPolicy.values.firstWhere((v) => v.name == j['pol'], orElse: () => ProgressionPolicy.off),
        kind: PrescriptionKind.values.firstWhere((v) => v.name == j['kind'], orElse: () => PrescriptionKind.hold),
        why: j['why'] as String,
      );
    }
    return SessionExercise(
      name: j['name'] as String? ?? '',
      config: ExerciseConfig.fromJson(Map<String, dynamic>.from(j['cfg'] as Map)),
      sets: [for (final s in (j['sets'] as List? ?? const [])) SetRow.fromJson(Map<String, dynamic>.from(s as Map))],
      previous: [for (final s in (j['prev'] as List? ?? const [])) '$s'],
      icon: icon,
      prescription: p,
      restDuration: Duration(seconds: (j['rest'] as num?)?.toInt() ?? 90),
      restEnabled: j['restOff'] != true,
      expanded: j['open'] == true,
      note: j['note'] as String?,
      lastNote: j['lastNote'] as String?,
    );
  }

  /// Pastikan jumlah teks PREV dan kunci baris selalu sejajar dengan set —
  /// draft lama atau baris yang disisipkan bisa membuatnya berselisih.
  void _align() {
    while (previous.length < sets.length) {
      previous.add('—');
    }
    while (rowKeys.length < sets.length) {
      rowKeys.add(UniqueKey());
    }
    while (rowIds.length < sets.length) {
      rowIds.add(UniqueKey());
    }
  }

  void addRow(SetRow row, {String previous = '—', bool atStart = false}) {
    _align();
    final at = atStart ? 0 : sets.length;
    sets.insert(at, row);
    this.previous.insert(at.clamp(0, this.previous.length), previous);
    rowKeys.insert(at, UniqueKey());
    rowIds.insert(at, UniqueKey());
  }

  void removeRowAt(int i) {
    sets.removeAt(i);
    if (i < previous.length) previous.removeAt(i);
    rowKeys.removeAt(i);
    if (i < rowIds.length) rowIds.removeAt(i);
  }
}

/// Aksi di menu ⋯ satu gerakan (FR-D8).
enum _ExerciseAction {
  moveUp,
  moveDown,
  replace,
  addWarmup,
  addDropSet,
  addRestPause,
  superset,
  note,
  history,
  removeLastSet,
  remove,
}

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.routineName,
    required this.exercises,
    this.routineId,
    this.history = const [],
    this.initialElapsed = Duration.zero,
    this.initialNotes,
    this.planned,
    this.initialDate,
    this.replacesKey,
    this.initialRest,
    this.restored = false,
    this.gymId,
  });

  final String routineName;

  /// Id profil gym tempat sesi ini dicatat (FR-C3, FR-C4). Ditetapkan saat
  /// sesi dibuka — bukan saat selesai — supaya gym yang diganti di Home selagi
  /// sesi diminimalkan tidak memindahkan sesi yang sedang berjalan. null untuk
  /// draft dan sesi lama yang belum mengenal gym.
  final String? gymId;

  /// Tanggal sesi (`YYYY-MM-DD`). null = hari ini. Diisi untuk sesi yang
  /// dilanjutkan dari draft atau dibuka ulang dari Riwayat: sesi yang dimulai
  /// Senin malam tetap tercatat Senin, meski diselesaikan Selasa.
  final String? initialDate;

  /// Sidik jari sesi di Riwayat yang digantikan sesi ini saat selesai — sesi
  /// yang dibuka ulang. null = sesi baru.
  final String? replacesKey;

  /// Istirahat yang sedang berjalan saat draft terakhir ditulis.
  final ({DateTime deadline, Duration total, int? exercise, String? next})? initialRest;

  /// Sesi ini dipulihkan otomatis dari draft saat aplikasi dibuka lagi —
  /// layar memberi tahu dengan satu baris supaya tidak mengira sesi baru.
  final bool restored;

  /// Waktu yang sudah berjalan sebelum layar ini dibuka — sesi yang
  /// dipulihkan dari draft.
  final Duration initialElapsed;

  final String? initialNotes;

  /// Susunan rencana dari draft; null = dihitung dari [exercises].
  final List<(String, int)>? planned;

  /// Rutinitas asal sesi ini. null untuk sesi bebas — dan sesi bebas tidak
  /// menggeser cursor program (FR-B3).
  final String? routineId;

  final List<SessionExercise> exercises;

  /// Riwayat untuk menghitung target, **terlama dulu**. Kosong berarti sesi ini
  /// jadi titik awal.
  final List<Workout> history;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> with WidgetsBindingObserver {
  final _rest = RestTimer();

  /// Satuan angka di layar ini. Kalau satuan diganti di Profil selagi sesi
  /// terbuka, semua angka sesi dikonversi (lihat [didChangeDependencies]) —
  /// tanpa itu angka kg akan disimpan dengan faktor lb.
  WeightUnit _unit = WeightUnit.kg;
  bool _unitKnown = false;
  late List<Workout> _history = widget.history;

  final _elapsed = Stopwatch()..start();
  late final List<SessionExercise> _exercises = List.of(widget.exercises);

  /// Susunan gerakan saat sesi dibuka, untuk mengenali sesi yang menyimpang
  /// dari rutinitasnya (FR-B9).
  late final List<(String, int)> _planned =
      widget.planned ?? [for (final e in widget.exercises) (e.config.exerciseId, e.workCount)];

  late final _notes = TextEditingController(text: widget.initialNotes ?? '')..addListener(_scheduleDraft);

  /// Tanggal sesi, ditetapkan saat sesi dimulai (lihat [SessionScreen.initialDate]).
  late final String _date = widget.initialDate ?? isoDate(DateTime.now());

  /// Penulisan draft yang ditunda sebentar setelah perubahan — lihat
  /// [_scheduleDraft].
  Timer? _draftSoon;

  /// Waktu sesi, termasuk yang berjalan sebelum draft dipulihkan.
  Duration get _elapsedTotal => widget.initialElapsed + _elapsed.elapsed;

  WorkoutStore? _store;
  Timer? _draftTimer;
  String? _lastDraft;

  /// Sesi sudah disimpan atau dibuang — draft tidak boleh ditulis lagi.
  bool _closed = false;

  bool _foreground = true;

  /// Baris yang baru dicentang dan sedang menunggu pilihan RIR.
  (SessionExercise, int)? _rirFor;

  String? _nextLabel;

  bool _saving = false;

  /// Gerakan yang istirahatnya sedang berjalan. Kartu istirahat dan layar
  /// penuhnya harus menunjuk ke gerakan yang sama, bukan ke "yang kebetulan
  /// sedang terbuka".
  SessionExercise? _restingOn;

  SessionExercise? get _restingExercise =>
      _restingOn ??
      (_exercises.isEmpty ? null : _exercises.firstWhere((e) => e.expanded, orElse: () => _exercises.first));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    KeepAwake.holdIfEnabled();
    _rest.onFinished = _restFinished;
    _rest.onDeadlineChanged = _restDeadlineChanged;
    // Draft ditulis berkala, sesaat setelah setiap perubahan, dan seketika
    // saat aplikasi ke latar belakang — Android boleh mematikan aplikasi kapan
    // saja setelah itu, dan HP yang ditinggal lama di loker hampir pasti
    // mematikannya.
    _draftTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveDraft());
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstFrame());
  }

  /// Istirahat yang tertinggal di draft dilanjutkan, dan sesi yang dipulihkan
  /// otomatis diberi tahu. Setelah frame pertama, bukan di initState:
  /// menjadwalkan notifikasi istirahat butuh teks yang dibaca dari context.
  void _afterFirstFrame() {
    if (!mounted) return;
    final r = widget.initialRest;
    if (r != null && r.deadline.isAfter(DateTime.now())) {
      setState(() {
        final i = r.exercise;
        _restingOn = i != null && i >= 0 && i < _exercises.length ? _exercises[i] : null;
        _nextLabel = r.next;
      });
      _rest.resumeUntil(r.deadline, r.total);
    }
    if (widget.restored) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.t.draftRestored)));
    }
  }

  /// Semua perubahan layar ini lewat setState, jadi di sinilah draft
  /// dijadwalkan — tidak ada aksi baru yang bisa lupa menyimpannya.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleDraft();
  }

  /// Tulis draft sebentar lagi. Ketikan beruntun (60 → 62,5) cukup ditulis
  /// sekali, tapi tidak perlu menunggu timer lima detik: aplikasi yang
  /// dimatikan tepat setelah set dicentang tetap membawa set itu.
  void _scheduleDraft() {
    if (_closed || _saving) return;
    _draftSoon?.cancel();
    _draftSoon = Timer(const Duration(milliseconds: 600), () => _saveDraft());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store ??= WorkoutScope.read(context);
    final unit = context.unit;
    if (!_unitKnown) {
      _unit = unit;
      _unitKnown = true;
    } else if (unit != _unit) {
      final from = _unit;
      for (final ex in _exercises) {
        ex.config = configBetween(ex.config, from, unit);
        for (var i = 0; i < ex.sets.length; i++) {
          ex.sets[i] = setBetween(ex.sets[i], from, unit);
        }
      }
      _history = historyBetween(_history, from, unit);
      _unit = unit;
    }
  }

  /// Browser melepas wake lock setiap kali halaman disembunyikan (pindah
  /// aplikasi, layar dikunci), dan tidak memintanya lagi. Dipegang ulang
  /// setiap kembali ke depan; di Android/iOS pemanggilan ulangnya tidak
  /// berefek apa-apa.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed && mounted) KeepAwake.holdIfEnabled();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      _saveDraft(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _draftSoon?.cancel();
    KeepAwake.release();
    RestAlert.cancel();
    _rest.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ── draft ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _draftJson() => {
    'v': 1,
    'name': widget.routineName,
    if (widget.routineId != null) 'rid': widget.routineId,
    if (widget.gymId != null) 'gym': widget.gymId,
    'date': _date,
    if (widget.replacesKey != null) 'replaces': widget.replacesKey,
    'unit': _unit.name,
    'elapsed': _elapsedTotal.inSeconds,
    'saved': DateTime.now().millisecondsSinceEpoch,
    if (_notes.text.trim().isNotEmpty) 'notes': _notes.text,
    'planned': [
      for (final (id, n) in _planned) [id, n],
    ],
    'ex': [for (final e in _exercises) e.toDraft()],
    if (_rest.isRunning && _rest.deadline != null)
      'rest': {
        'end': _rest.deadline!.millisecondsSinceEpoch,
        'total': _rest.total.inSeconds,
        if (_restingOn != null && _exercises.contains(_restingOn)) 'on': _exercises.indexOf(_restingOn!),
        if (_nextLabel != null) 'next': _nextLabel,
      },
  };

  /// Simpan sesi yang sedang berjalan supaya tidak hilang kalau aplikasi
  /// dimatikan. Tidak menulis apa pun kalau isinya tidak berubah.
  Future<void> _saveDraft({bool force = false}) async {
    final store = _store;
    // Selagi sesi disimpan, draft tidak boleh ditulis lagi: ia akan dibuang
    // sesaat lagi, dan draft yang lolos sesudahnya membuka sesi yang sama
    // untuk kedua kalinya saat aplikasi dibuka.
    if (_closed || _saving || store == null) return;
    if (_exercises.isEmpty && _notes.text.trim().isEmpty) return;
    final json = _draftJson();
    // Waktu ikut kunci pembanding per setengah menit: cukup supaya durasi sesi
    // yang dipulihkan tidak mulai dari nol, tanpa menulis tiap 5 detik.
    final key = jsonEncode({...json, 'elapsed': (json['elapsed'] as int) ~/ 30, 'saved': 0});
    if (!force && key == _lastDraft) return;
    _lastDraft = key;
    await store.saveDraft(json);
  }

  Future<void> _dropDraft() async {
    _closed = true;
    _draftTimer?.cancel();
    await _store?.clearDraft();
  }

  // ── istirahat ────────────────────────────────────────────────────────

  void _restFinished() {
    if (_foreground) RestAlert.ringNow();
  }

  void _restDeadlineChanged(Duration? remaining) {
    if (!mounted) return;
    if (remaining == null) {
      RestAlert.cancel();
      return;
    }
    final t = context.t;
    RestAlert.schedule(remaining, title: t.restOverTitle, body: t.restOverBody(_nextLabel ?? ''));
  }

  String _rowLabel(SessionExercise ex, int index, Strings t) {
    final s = ex.sets[index];
    return switch (s.phase) {
      SetPhase.warmup => t.warmupLabel,
      SetPhase.drop => 'drop set',
      SetPhase.restPause => 'rest-pause',
      SetPhase.work => t.setLabel(ex.sets.take(index + 1).where((r) => r.isWork).length),
    };
  }

  String _rowTarget(SessionExercise ex, int index, Strings t) {
    final s = ex.sets[index];
    final label = _rowLabel(ex, index, t);
    final amount = ex.config.mode == LogMode.time ? s.seconds : s.reps;
    return t.nextUpLine(label, weightLabel(s.weight, bodyweight: ex.config.bodyweight), amount);
  }

  /// Dipanggil saat satu set dicentang.
  ///
  /// Mencentang set terakhir tidak memulai istirahat: tidak ada set berikutnya
  /// untuk diistirahatkan, dan menghitung mundur ke ruang kosong hanya membuat
  /// orang menunggu tanpa alasan.
  void _onSetToggled(SessionExercise ex, int index, bool done) {
    final logRir = _store?.settings.logRir ?? false;
    setState(() {
      ex.sets[index] = ex.sets[index].copyWith(done: done);
      if (done && logRir && !ex.sets[index].isWarmup) {
        _rirFor = (ex, index);
      } else if (_rirFor?.$1 == ex && _rirFor?.$2 == index) {
        _rirFor = null;
      }
    });
    _saveDraft();
    if (!done) return;

    final t = context.t;
    final i = _exercises.indexOf(ex);

    // Superset: set gerakan pasangannya dulu, istirahat sesudahnya.
    if (ex.config.superset && i >= 0 && i + 1 < _exercises.length) {
      final partner = _exercises[i + 1];
      if (partner.sets.any((s) => !s.done && !s.isWarmup)) {
        setState(() {
          for (final e in _exercises) {
            e.expanded = e == partner || e == ex;
          }
        });
        return;
      }
    }
    if (!ex.restEnabled) return;

    // Set berikutnya di gerakan ini; kalau ini set terakhirnya, gerakan
    // berikutnya yang masih punya set. Dulu set terakhir tiap gerakan tidak
    // memulai istirahat sama sekali — padahal istirahat sebelum gerakan
    // berikutnya sama pentingnya.
    final next = ex.sets.indexWhere((s) => !s.done, index + 1);
    String label;
    if (next >= 0) {
      label = _rowTarget(ex, next, t);
    } else {
      SessionExercise? following;
      for (final e in _exercises.skip(i + 1)) {
        if (e.sets.any((s) => !s.done && !s.isWarmup)) {
          following = e;
          break;
        }
      }
      if (following == null) return;
      label = t.nextExerciseLine(following.name);
    }
    setState(() {
      _nextLabel = label;
      _restingOn = ex;
    });
    _rest.start(ex.restDuration);
    _openRestScreen(ex);
  }

  void _onRir(SessionExercise ex, int index, int rir) {
    setState(() {
      ex.sets[index] = ex.sets[index].copyWith(rir: rir);
      _rirFor = null;
    });
    _saveDraft();
  }

  /// Angka yang diketik di tabel. Disimpan seketika ke baris — sebelumnya
  /// kotak input hanya memegang teksnya sendiri, dan beban yang diketik
  /// hilang begitu set dicentang.
  ///
  /// Beban yang diubah di satu set kerja ikut diteruskan ke set kerja di
  /// bawahnya yang belum dicentang dan masih memegang beban lama — perilaku
  /// openGym. Mengetik "60" tiga kali untuk tiga set yang sama itu kerja sia-sia.
  void _onEdited(SessionExercise ex, int index, {double? weight, int? reps, int? seconds, bool refresh = false}) {
    final old = ex.sets[index];
    ex.sets[index] = old.copyWith(weight: weight, reps: reps, seconds: seconds);
    _scheduleDraft();
    if (refresh) setState(() {});
    if (weight == null || !old.isWork) return;
    var cascaded = false;
    for (var j = index + 1; j < ex.sets.length; j++) {
      final s = ex.sets[j];
      if (!s.isWork || s.done || s.weight != old.weight) continue;
      ex.sets[j] = s.copyWith(weight: weight);
      // Kunci baru supaya kotak input baris itu dibangun ulang dengan angka
      // barunya. Baris yang sedang diketik tidak disentuh, jadi fokus dan
      // kursornya tetap di tempat.
      ex.rowKeys[j] = UniqueKey();
      cascaded = true;
    }
    if (cascaded) setState(() {});
  }

  bool get _anythingLogged => _exercises.any((e) => e.sets.any((s) => s.done && !s.isWarmup));

  /// Susunan sesi berbeda dari rutinitasnya: gerakan ditambah, dibuang,
  /// diganti, diurutkan ulang, atau jumlah setnya berubah.
  bool get _drifted {
    if (widget.routineId == null) return false;
    final now = [for (final e in _exercises) (e.config.exerciseId, e.workCount)];
    if (now.length != _planned.length) return true;
    for (var i = 0; i < now.length; i++) {
      if (now[i] != _planned[i]) return true;
    }
    return false;
  }

  /// Susunan (id gerakan, set kerja) sesi ini, untuk dibandingkan dengan
  /// rutinitasnya.
  List<(String, int)> get _layout => [for (final e in _exercises) (e.config.exerciseId, e.workCount)];

  /// Rutinitas asal sesi ini, seperti tersimpan sekarang. null untuk sesi
  /// bebas atau kalau rutinitasnya sudah dihapus selagi sesi berjalan.
  Routine? get _routine =>
      widget.routineId == null ? null : (_store ?? context.workouts).routineById(widget.routineId!);

  /// Selisih sesi ini terhadap rutinitasnya, atau null kalau tidak ada yang
  /// perlu diselaraskan. [_drifted] membandingkan dengan *rencana saat sesi
  /// dibuka*; yang dibandingkan di sini rutinitasnya sendiri — kalau sesi
  /// menyimpang dari rencana tapi kebetulan cocok dengan rutinitas (set yang
  /// disarankan progresi lalu dihapus lagi), tidak ada yang perlu disimpan.
  RoutineDiff? _pendingDiff(Routine? routine) {
    if (routine == null || !_drifted) return null;
    final diff = diffRoutine(routine, _layout);
    return diff.isEmpty ? null : diff;
  }

  /// Tombol FINISH: tanyakan dulu, baru simpan.
  ///
  /// Dulu tombol ini langsung menutup sesi, dan orang yang ingin "menyelesaikan
  /// timer" menekannya lalu kehilangan sesinya di tengah latihan. Lembar ini
  /// menunjukkan apa yang akan terjadi — set yang belum dicentang, istirahat
  /// yang masih jalan, dan perubahan rutinitas yang ikut disimpan — sebelum
  /// ada yang tidak bisa dibatalkan.
  Future<void> _confirmFinish() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_anythingLogged) {
      // Sesi tanpa satu set pun bukan latihan. Menyimpannya mengotori riwayat
      // dan menggeser rotasi seolah sesi itu dilakukan.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.noWorkingSets)));
      return;
    }
    final c = context.gym;
    final routine = _routine;
    final diff = _pendingDiff(routine);
    // Dihitung sama dengan ringkasan sesudahnya (drop set dan rest-pause ikut),
    // supaya lembar ini dan ringkasan satu detik kemudian tidak menyebut
    // angka yang berbeda.
    final total = _exercises.fold(0, (a, e) => a + e.sets.where((s) => !s.isWarmup).length);
    final done = _exercises.fold(0, (a, e) => a + e.sets.where((s) => s.done && !s.isWarmup).length);
    final volume = _exercises
        .expand((e) => e.sets)
        .where((s) => s.done && !s.isWarmup)
        .fold(0.0, (a, s) => a + s.weight * s.reps);
    final save = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet))),
      builder: (_) => _FinishSheet(
        routineName: widget.routineName,
        elapsed: _elapsedTotal,
        setsDone: done,
        setsTotal: total,
        // Volume dihitung dalam satuan tampilan; [WeightTextX.volume] minta kg.
        volumeKg: toKg(volume, _unit),
        restRunning: _rest.isRunning,
        routine: routine,
        diff: diff,
        sessionNames: {for (final e in _exercises) e.config.exerciseId: e.name},
        // Sesi lama yang dibuka ulang dari Riwayat untuk membetulkan salah
        // ketik tidak boleh menimpa rutinitas yang sudah diubah sejak itu —
        // pilihannya tetap ada, tapi mati secara bawaan.
        saveByDefault: widget.replacesKey == null,
      ),
    );
    if (save == null || !mounted) return;
    await _finish(saveRoutine: save);
  }

  /// Selesai: simpan, tunjukkan ringkasannya, baru tutup sesinya. Menutup
  /// begitu saja akan membuang satu-satunya kesempatan menampilkan rekor dan
  /// target berikutnya selagi orangnya masih memperhatikan.
  ///
  /// Simpan lebih dulu, sebelum ringkasan dibuka: kalau aplikasi mati saat
  /// ringkasan terbuka, yang hilang cuma tampilan, bukan latihannya.
  ///
  /// [saveRoutine] dari lembar konfirmasi: susunan sesi ditulis ke rutinitas
  /// asalnya, sesudah sesi tersimpan dan sebelum ringkasan dibuka — ringkasan
  /// lalu bisa membatalkannya dengan rutinitas asli yang dibawa serta.
  Future<void> _finish({required bool saveRoutine}) async {
    if (_saving) return;
    if (!_anythingLogged) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.noWorkingSets)));
      return;
    }
    _saving = true;
    _draftSoon?.cancel();
    _rest.skip();
    _elapsed.stop();

    final store = context.workouts;
    final notes = _notes.text.trim();
    // Sesi dicatat dalam satuan tampilan; yang disimpan selalu kg.
    final workout = workoutToKg(
      Workout(
        date: _date,
        routine: widget.routineName,
        durationSeconds: _elapsedTotal.inSeconds,
        notes: notes.isEmpty ? null : notes,
        gymId: widget.gymId,
        entries: [
          for (final ex in _exercises)
            WorkoutEntry(
              exerciseId: ex.config.exerciseId,
              target: ex.config,
              sets: List.of(ex.sets),
              note: (ex.note ?? '').trim().isEmpty ? null : ex.note!.trim(),
            ),
        ],
      ),
      _unit,
    );
    final original = _routine;
    final diff = _pendingDiff(original);
    final replaces = widget.replacesKey;
    if (replaces != null) {
      // Sesi yang dibuka ulang dari Riwayat menggantikan catatan lamanya di
      // tempat, tanpa menggeser rotasi lagi.
      await store.replaceWorkoutByKey(replaces, workout);
    } else {
      await store.addWorkout(workout, routineId: widget.routineId);
    }
    // Sesinya sudah tersimpan: draft dibuang sekarang, sebelum pekerjaan lain
    // yang bisa gagal. Draft yang tertinggal di sini membuka sesi yang sama
    // lagi saat aplikasi dibuka, dan menyelesaikannya mencatat sesi dua kali.
    await _dropDraft();
    var routineUpdated = false;
    if (saveRoutine && original != null && diff != null) {
      try {
        await store.saveRoutine(
          syncRoutineWithSession(original, [for (final e in _exercises) (_routineConfigFor(e, original), e.workCount)]),
        );
        routineUpdated = true;
      } catch (e) {
        debugPrint('rutinitas tidak tersimpan: $e');
      }
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FinishScreen(
          routineName: widget.routineName,
          gymId: widget.gymId,
          exercises: _exercises,
          history: _history,
          elapsed: _elapsedTotal,
          dateLabel: _dateLabel(context),
          originalRoutine: diff == null ? null : original,
          diff: diff,
          routineUpdated: routineUpdated,
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// Konfigurasi gerakan ini untuk ditulis ke rutinitas, dalam kg.
  ///
  /// Gerakan baru membawa konfigurasi sesi, yang berisi hal yang tidak pernah
  /// dipilih orangnya: policy rutinitas dan faktor deload Profil yang sudah
  /// "dibekukan" ke target sesi. Kalau ikut tertulis, keduanya jadi
  /// pengaturan khusus gerakan itu — mengganti policy rutinitas atau deload di
  /// Profil nanti tidak lagi berlaku untuknya. Istirahat yang diubah di tengah
  /// sesi justru pilihan orangnya, jadi itu yang ditulis.
  ExerciseConfig _routineConfigFor(SessionExercise e, Routine original) {
    final kg = configToKg(e.config, _unit);
    if (original.exercises.any((c) => c.exerciseId == kg.exerciseId)) return kg;
    final json = kg.toJson();
    if (json['pol'] == original.policy?.name) json.remove('pol');
    if (kg.deloadFactor != null && kg.deloadFactor == _store?.settings.deloadFactor) json.remove('dl');
    json['rest'] = e.restDuration.inSeconds;
    return ExerciseConfig.fromJson(json);
  }

  /// Keluar dari sesi selalu ditanyakan. Tombol panah di kiri atas dulu
  /// langsung menyimpan sesi — keliru dari sisi mana pun: yang ingin
  /// menyimpan menekan Finish, yang menekan panah belum tentu selesai.
  Future<void> _confirmLeave() async {
    // Tombol kembali di tengah penyimpanan: sesinya sedang ditulis, dan
    // "buang" dari dialog ini akan melewatkan ringkasannya.
    if (_saving) return;
    if (!_anythingLogged) {
      await _dropDraft();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        final c = context.gym;
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
          title: Text(context.t.leaveSessionTitle, style: Theme.of(context).textTheme.titleLarge),
          content: Text(context.t.leaveSessionBody, style: TextStyle(fontSize: 13.5, height: 1.45, color: c.text2)),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actionsOverflowDirection: VerticalDirection.up,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: Text(
                context.t.discard,
                style: TextStyle(fontWeight: FontWeight.w700, color: c.danger),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.t.keepTraining,
                style: TextStyle(fontWeight: FontWeight.w700, color: c.text2),
              ),
            ),
            GymButton(
              label: context.t.finishAndSave,
              height: 42,
              expand: false,
              onPressed: () => Navigator.of(context).pop('finish'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    switch (choice) {
      case 'discard':
        _rest.skip();
        await _dropDraft();
        if (mounted) Navigator.of(context).pop();
      case 'finish':
        await _confirmFinish();
    }
  }

  static String _dateLabel(BuildContext context) {
    final t = context.t;
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '${t.weekdayShort(now.weekday)} ${now.day} ${t.monthShort(now.month)} · $hh:$mm';
  }

  /// Mulai istirahat untuk satu gerakan dan tampilkan layar hitung mundurnya.
  Future<void> _startRest(SessionExercise ex) async {
    final next = ex.sets.indexWhere((s) => !s.done && !s.isWarmup);
    final t = context.t;
    setState(() {
      _restingOn = ex;
      _nextLabel = next < 0 ? t.lastSetDone : _rowTarget(ex, next, t);
    });
    _rest.start(ex.restDuration);
    await _openRestScreen(ex);
  }

  Future<void> _openRestScreen(SessionExercise ex) => showRestScreen(
    context,
    timer: _rest,
    exerciseName: ex.name,
    nextLabel: _nextLabel ?? '',
    onEditDuration: () => _editRest(ex),
  );

  Future<void> _editRest(SessionExercise ex) async {
    final picked = await showRestDurationSheet(
      context,
      current: ex.restDuration,
      exerciseName: ex.name,
      routineName: widget.routineName,
    );
    if (picked == null || !mounted) return;
    setState(() => ex.restDuration = picked.duration);
    if (_rest.isRunning) _rest.retarget(picked.duration);

    if (picked.saveAsDefault) await _saveRestAsDefault(ex, picked.duration);
  }

  /// "Simpan sebagai bawaan" menulis ke rutinitas asal sesi ini. Sesi bebas
  /// tidak punya rutinitas untuk ditulisi, dan itu dikatakan apa adanya.
  Future<void> _saveRestAsDefault(SessionExercise ex, Duration d) async {
    final store = context.workouts;
    final id = widget.routineId;
    final routine = id == null ? null : store.routineById(id);
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    if (routine == null) {
      // Sesi bebas: disimpan per gerakan di setelan, dipakai setiap kali
      // gerakan ini muncul tanpa istirahat dari rutinitas.
      final s = store.settings;
      await store.updateSettings(s.copyWith(restByExercise: {...s.restByExercise, ex.config.exerciseId: d.inSeconds}));
      messenger.showSnackBar(SnackBar(content: Text(t.restSavedFor(ex.name))));
      return;
    }
    final updated = [
      for (final cfg in routine.exercises)
        cfg.exerciseId == ex.config.exerciseId ? cfg.copyWith(restSeconds: d.inSeconds) : cfg,
    ];
    await store.saveRoutine(routine.copyWith(exercises: updated));
  }

  /// Policy bawaan rutinitas asal sesi ini; null untuk sesi bebas.
  ProgressionPolicy? get _routineDefault => _routine?.policy;

  /// Konfigurasi untuk gerakan yang ditambah atau diganti di tengah sesi.
  ///
  /// Gerakan yang belum pernah dicatat mengikuti policy rutinitasnya, bukan
  /// double progression bawaan [configForAdded]: aturan rutinitas berlaku
  /// untuk semua gerakan di dalamnya, jadi Cable Fly yang ditambah ke Push
  /// (linear) ikut naik bebannya tiap sesi sukses — sama seperti Bench Press
  /// di sebelahnya. Gerakan yang pernah dicatat mempertahankan target
  /// terakhirnya, termasuk policy-nya.
  ExerciseConfig _configForNew(String exerciseId) {
    var cfg = configForAdded(exerciseId, _history);
    final def = _routineDefault;
    if (def != null &&
        lastEntryFor(_history, exerciseId) == null &&
        (policiesFor[cfg.mode] ?? const <ProgressionPolicy>[]).contains(def)) {
      cfg = cfg.copyWith(policy: def);
    }
    return cfg;
  }

  SessionExercise _buildNew(ExerciseCatalog catalog, String exerciseId) => buildSessionExercise(
    catalog,
    _configForNew(exerciseId),
    _history,
    routineDefault: _routineDefault,
    settings: _store?.settings,
    // Aturan rutinitas deload (FR-B10) berlaku juga untuk gerakan yang
    // ditambah di tengah sesi — targetnya dihitung lewat jalur yang sama,
    // termasuk memori beban gym sesi ini (FR-C4).
    routines: _store?.routines ?? const [],
    gymId: widget.gymId,
    expanded: true,
  );

  Future<void> _addExercise() async {
    final picked = await pickExercise(context);
    if (picked == null || !mounted) return;
    final catalog = await ExerciseCatalog.load();
    if (!mounted) return;
    setState(() {
      for (final e in _exercises) {
        e.expanded = false;
      }
      _exercises.add(_buildNew(catalog, picked.id));
    });
  }

  Future<void> _onExerciseAction(SessionExercise ex, _ExerciseAction action) async {
    final i = _exercises.indexOf(ex);
    if (i < 0) return;
    switch (action) {
      case _ExerciseAction.moveUp when i > 0:
        setState(() => _exercises.insert(i - 1, _exercises.removeAt(i)));
      case _ExerciseAction.moveDown when i < _exercises.length - 1:
        setState(() => _exercises.insert(i + 1, _exercises.removeAt(i)));
      case _ExerciseAction.replace:
        final logged = ex.sets.where((s) => s.done).length;
        if (logged > 0) {
          final ok = await _confirm(
            context.t.replaceConfirmTitle,
            context.t.replaceConfirmBody(logged),
            context.t.replace,
          );
          if (ok != true || !mounted) return;
        }
        final picked = await pickExercise(context);
        if (picked == null || !mounted) return;
        final catalog = await ExerciseCatalog.load();
        if (!mounted) return;
        setState(() => _exercises[_exercises.indexOf(ex)] = _buildNew(catalog, picked.id));
      case _ExerciseAction.addWarmup:
        final firstWork = ex.sets.firstWhere((s) => !s.isWarmup, orElse: () => const SetRow());
        final inc = weightIncrement(ex.config, _unit.label);
        // Mesin assisted (#232): warm-up berarti *lebih banyak* bantuan.
        final assisted = ex.config.assisted == true;
        setState(() {
          ex.addRow(
            SetRow(
              phase: SetPhase.warmup,
              weight: firstWork.weight <= 0 ? 0 : snapWeight(firstWork.weight * (assisted ? 1.5 : 0.5), inc),
              reps: 8,
            ),
            atStart: true,
          );
          ex.expanded = true;
        });
      case _ExerciseAction.addDropSet || _ExerciseAction.addRestPause:
        final base = ex.sets.lastWhere((s) => !s.isWarmup, orElse: () => const SetRow());
        final inc = weightIncrement(ex.config, _unit.label);
        final drop = action == _ExerciseAction.addDropSet;
        // Drop set di mesin assisted (#232) = bantuan ditambah, bukan dikurangi.
        final assisted = ex.config.assisted == true;
        setState(() {
          ex.addRow(
            SetRow(
              phase: drop ? SetPhase.drop : SetPhase.restPause,
              // Drop set: turun sekitar 20 %. Rest-pause: beban sama, rep jauh
              // lebih sedikit — beberapa rep lagi setelah jeda 15 detik.
              weight: base.weight <= 0
                  ? 0
                  : (drop ? snapWeight(base.weight * (assisted ? 1.25 : 0.8), inc) : base.weight),
              reps: drop ? base.reps : math.max(1, (base.reps / 3).round()),
              seconds: base.seconds,
            ),
          );
          ex.expanded = true;
        });
      case _ExerciseAction.superset:
        setState(() => ex.config = ex.config.copyWith(superset: !ex.config.superset));
      case _ExerciseAction.note:
        final text = await _editNote(ex);
        if (text == null || !mounted) return;
        setState(() => ex.note = text.trim().isEmpty ? null : text.trim());
      case _ExerciseAction.history:
        await showExerciseHistory(context, exerciseId: ex.config.exerciseId, name: ex.name);
      case _ExerciseAction.removeLastSet when ex.sets.length > 1:
        if (ex.sets.last.done) {
          final ok = await _confirm(context.t.removeSetConfirmTitle, context.t.removeSetConfirmBody, context.t.delete);
          if (ok != true || !mounted) return;
        }
        setState(() => ex.removeRowAt(ex.sets.length - 1));
      case _ExerciseAction.remove:
        final ok = await _confirmRemove(ex);
        if (ok != true || !mounted) return;
        setState(() {
          _exercises.remove(ex);
          if (_restingOn == ex) _restingOn = null;
        });
      default:
        break;
    }
  }

  Future<bool?> _confirm(String title, String body, String action) => showDialog<bool>(
    context: context,
    builder: (context) {
      final c = context.gym;
      return AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        content: Text(body, style: TextStyle(fontSize: 14, height: 1.4, color: c.text2)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              context.t.cancel,
              style: TextStyle(fontWeight: FontWeight.w700, color: c.text2),
            ),
          ),
          GymButton(
            label: action,
            height: 42,
            expand: false,
            tone: GymButtonTone.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    },
  );

  Future<String?> _editNote(SessionExercise ex) => showDialog<String>(
    context: context,
    builder: (_) => _NoteDialog(title: ex.name, initial: ex.note ?? ''),
  );

  Future<bool?> _confirmRemove(SessionExercise ex) {
    // Menghapus gerakan yang belum disentuh tidak perlu ditanyakan. Yang
    // sudah punya set tercentang ditanyakan, karena itu data latihan.
    if (!ex.sets.any((s) => s.done)) return Future.value(true);
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final c = context.gym;
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
          title: Text('${context.t.removeExercise}?', style: Theme.of(context).textTheme.titleLarge),
          content: Text(ex.name, style: TextStyle(fontSize: 14, color: c.text2)),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                context.t.cancel,
                style: TextStyle(fontWeight: FontWeight.w700, color: c.text2),
              ),
            ),
            GymButton(
              label: context.t.delete,
              height: 42,
              expand: false,
              tone: GymButtonTone.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final total = _exercises.fold(0, (a, e) => a + e.workCount);
    final done = _exercises.fold(0, (a, e) => a + e.doneCount);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                routineName: widget.routineName,
                gymId: widget.gymId,
                // Termasuk waktu sebelum draft dipulihkan; stopwatch sendiri
                // mulai dari nol setiap layar ini dibuka.
                elapsed: () => _elapsedTotal,
                rest: _rest,
                onLeave: _confirmLeave,
                onFinish: _confirmFinish,
              ),
              // Bilah progres bergerak ke nilai barunya, bukan melompat: satu
              // set dicentang → bilahnya terlihat "bertambah".
              AnimatedValue(
                value: total == 0 ? 0 : done / total,
                duration: GymMotion.normal,
                builder: (context, v) => LinearProgressIndicator(
                  value: v,
                  minHeight: 3,
                  backgroundColor: c.surface2,
                  valueColor: AlwaysStoppedAnimation(c.accent),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    // Kartu istirahat memudar masuk, dan saat pergi ia
                    // menyusut sambil memudar supaya daftar di bawahnya naik
                    // pelan — bukan melompat 150 dp begitu istirahat dilewati.
                    // Tingginya penuh sejak frame pertama: kartu ini selalu
                    // muncul di frame yang sama dengan layar istirahat penuh
                    // yang menutupinya, jadi tinggi yang tumbuh dari nol tidak
                    // pernah terlihat — hanya membuat kartu belum ada satu
                    // frame saat sesi kembali di depan.
                    AnimatedBuilder(
                      animation: _rest,
                      builder: (context, _) {
                        final resting = _restingExercise;
                        final show = _rest.isRunning && resting != null;
                        return _ExitCollapse(
                          show: show,
                          child: !show
                              ? const SizedBox.shrink()
                              : Reveal(
                                  slide: false,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: RestTimerCard(
                                      timer: _rest,
                                      nextLabel: _nextLabel ?? '',
                                      onEditDuration: () => _editRest(resting),
                                      onOpen: () => _openRestScreen(resting),
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                    _NotesField(controller: _notes),
                    const SizedBox(height: 12),
                    if (_exercises.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          context.t.emptySessionHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: c.text2),
                        ),
                      ),
                    for (final (i, ex) in _exercises.indexed) ...[
                      _ExerciseCard(
                        key: ObjectKey(ex),
                        exercise: ex,
                        isFirst: i == 0,
                        isLast: i == _exercises.length - 1,
                        rirRow: _rirFor?.$1 == ex ? _rirFor!.$2 : null,
                        onRir: (row, v) => _onRir(ex, row, v),
                        onToggleExpand: () => setState(() => ex.expanded = !ex.expanded),
                        onSetToggled: (i, v) => _onSetToggled(ex, i, v),
                        onEdited: (i, {weight, reps, seconds, refresh = false}) =>
                            _onEdited(ex, i, weight: weight, reps: reps, seconds: seconds, refresh: refresh),
                        onEditRest: () => _editRest(ex),
                        onToggleRest: (v) => setState(() => ex.restEnabled = v),
                        onStartRest: () => _startRest(ex),
                        onAction: (a) => _onExerciseAction(ex, a),
                        onAddSet: () => setState(() {
                          final last = ex.sets.lastWhere((s) => s.isWork, orElse: () => const SetRow());
                          ex.addRow(SetRow(weight: last.weight, reps: last.reps, seconds: last.seconds));
                        }),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _DashedAction(icon: GymIcons.plus, label: context.t.addExercise, onTap: _addExercise),
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.routineName,
    required this.elapsed,
    required this.rest,
    required this.onLeave,
    required this.onFinish,
    this.gymId,
  });

  final String routineName;

  /// Gym sesi ini (FR-C3); chip-nya hanya tampil kalau gym-nya lebih dari satu.
  final String? gymId;

  final Duration Function() elapsed;
  final RestTimer rest;
  final VoidCallback onLeave;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    // Seluruh bilah dibangun ulang mengikuti timer: kapsul istirahat hanya
    // menjadi anak Row yang lentur selagi tampil. Flexible yang kosong tetap
    // memakan jatah ruang dan mempersempit judul tanpa alasan.
    return AnimatedBuilder(
      animation: rest,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 14, 10),
        child: Row(
          children: [
            IconButton(
              onPressed: onLeave,
              icon: Icon(Icons.keyboard_arrow_down, color: c.text2),
              tooltip: context.t.minimise,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routineName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  // Waktu berjalan dan chip gym berdampingan. Wrap, bukan Row:
                  // di HP sempit dengan huruf besar dan kapsul istirahat yang
                  // sedang tampil, chip-nya turun ke baris berikutnya alih-alih
                  // meluber keluar bilah.
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Waktu berjalan berdetak sendiri tiap detik. Dulu angkanya
                      // hanya berubah saat layar kebetulan digambar ulang.
                      StreamBuilder<int>(
                        stream: _secondTicks,
                        builder: (context, _) => Text(
                          context.t.elapsedOf(_formatElapsed(elapsed())),
                          style: TextStyle(fontSize: 12, color: c.text2),
                        ),
                      ),
                      if (gymId != null) GymChip(gymId: gymId, dense: true),
                    ],
                  ),
                ],
              ),
            ),
            // Kapsul timer adalah tombol "lewati istirahat" — dengan ✕ yang
            // terlihat. Dulu kapsul ini hanya angka di sebelah FINISH, dan orang
            // yang ingin menghentikan timer menekan tombol di sebelahnya.
            // Flexible: berbagi sisa lebar dengan judul, bukan mendorong
            // tombol SELESAI keluar layar.
            if (rest.isRunning)
              Flexible(
                child: Builder(
                  builder: (context) {
                    // Target sentuh setinggi 44 dp: kapsul ini bersebelahan dengan
                    // SELESAI, dan salah ketuk di sini yang dulu menutup sesi.
                    // FittedBox mengecilkan isinya di HP 360 dp dengan huruf besar,
                    // bukan meluber keluar bilah.
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Semantics(
                        button: true,
                        label: context.t.skipRest,
                        child: Tooltip(
                          message: context.t.skipRest,
                          child: Material(
                            color: c.accentSoft,
                            borderRadius: BorderRadius.circular(GymRadius.pill),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(GymRadius.pill),
                              onTap: () {
                                GymHaptics.tap();
                                rest.skip();
                              },
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 44),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Center(
                                    widthFactor: 1,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(GymIcons.alarm, size: 15, color: c.accent),
                                          const SizedBox(width: 6),
                                          Text(
                                            formatRestWide(rest.remaining),
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: c.accent,
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(Icons.close, size: 15, color: c.accent),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            GymButton(
              label: context.t.finish,
              height: 38,
              expand: false,
              shape: GymButtonShape.pill,
              onPressed: onFinish,
            ),
          ],
        ),
      ),
    );
  }
}

/// Detak satu detik untuk waktu sesi, satu aliran untuk semua pembangun.
/// Membuat `Stream.periodic` baru di dalam build membuat StreamBuilder
/// berlangganan ulang setiap kali bilahnya dibangun ulang — dan bilah ini
/// dibangun ulang lima kali sedetik selama istirahat, jadi detaknya tidak
/// pernah sempat datang. Dijeda saat tidak ada yang mendengarkan.
final Stream<int> _secondTicks = Stream<int>.periodic(
  const Duration(seconds: 1),
  (i) => i,
).asBroadcastStream(onListen: (sub) => sub.resume(), onCancel: (sub) => sub.pause());

/// [AnimatedSize] yang hormat "kurangi gerak".
///
/// [AnimatedSize] tidak boleh diberi durasi nol: controller-nya selesai
/// seketika di tengah `performLayout` dan menandai dirinya perlu layout lagi
/// — assertion di mode debug. Jadi saat gerak dimatikan, ukuran baru
/// diterapkan langsung tanpa [AnimatedSize].
class _SizeChange extends StatelessWidget {
  const _SizeChange({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = GymMotion.of(context, GymMotion.normal);
    if (d == Duration.zero) return child;
    return AnimatedSize(duration: d, curve: GymMotion.curve, alignment: Alignment.topCenter, child: child);
  }
}

/// Anak yang tampil seketika saat [show] menyala, dan saat padam pergi dengan
/// menyusut tingginya sambil memudar — supaya isi di bawahnya naik pelan.
///
/// Bukan [AnimatedSize]: ia mulai dari tinggi nol saat anak pertama kali
/// muncul (dan di dalam ListView, anak setinggi nol dianggap tidak ada
/// selama satu frame), dan ia tidak menerima durasi nol saat gerak
/// dikurangi. Saat gerak dikurangi, anak langsung hilang.
class _ExitCollapse extends StatefulWidget {
  const _ExitCollapse({required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  State<_ExitCollapse> createState() => _ExitCollapseState();
}

class _ExitCollapseState extends State<_ExitCollapse> {
  /// Anak terakhir yang tampil, dipegang selama animasi keluar.
  Widget? _leaving;

  @override
  void didUpdateWidget(_ExitCollapse old) {
    super.didUpdateWidget(old);
    if (old.show && !widget.show) {
      _leaving = old.child;
    } else if (widget.show) {
      _leaving = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = GymMotion.of(context, GymMotion.normal);
    final child = widget.show ? widget.child : _leaving;
    if (child == null || (!widget.show && d == Duration.zero)) return const SizedBox(width: double.infinity);
    // Satu susunan untuk dua keadaan. Kalau saat tampil anaknya dipasang
    // langsung dan baru dibungkus ClipRect/Align/Opacity saat pergi, elemen
    // anaknya dibuang dan dibuat ulang — Reveal di dalamnya mulai lagi dari
    // opacity nol, dan yang terlihat hanya kotak kosong yang menyusut.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: widget.show ? 1 : 0),
      // Masuk seketika (lihat dokumentasi kelas), pergi beranimasi.
      duration: widget.show ? Duration.zero : d,
      curve: GymMotion.curve,
      onEnd: () {
        if (mounted && !widget.show) setState(() => _leaving = null);
      },
      child: child,
      builder: (context, v, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: v,
          child: Opacity(opacity: v, child: child),
        ),
      ),
    );
  }
}

/// `42:10`, atau `1:02:10` lewat satu jam.
String _formatElapsed(Duration e) => e.inHours > 0
    ? '${e.inHours}:${(e.inMinutes % 60).toString().padLeft(2, '0')}:${(e.inSeconds % 60).toString().padLeft(2, '0')}'
    : '${e.inMinutes}:${(e.inSeconds % 60).toString().padLeft(2, '0')}';

/// Lembar konfirmasi selesai. Mengembalikan `true`/`false` = selesai dengan/
/// tanpa menyimpan susunan ke rutinitas, `null` = kembali ke sesi.
class _FinishSheet extends StatefulWidget {
  const _FinishSheet({
    required this.routineName,
    required this.elapsed,
    required this.setsDone,
    required this.setsTotal,
    required this.volumeKg,
    required this.restRunning,
    required this.routine,
    required this.diff,
    required this.sessionNames,
    this.saveByDefault = true,
  });

  final bool saveByDefault;

  final String routineName;
  final Duration elapsed;
  final int setsDone;
  final int setsTotal;
  final double volumeKg;
  final bool restRunning;

  /// Rutinitas asal dan selisihnya; keduanya null kalau tidak ada yang perlu
  /// diselaraskan (sesi bebas, atau susunannya sama).
  final Routine? routine;
  final RoutineDiff? diff;

  /// Nama gerakan yang ada di sesi. Gerakan yang dibuang dicari di katalog.
  final Map<String, String> sessionNames;

  @override
  State<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<_FinishSheet> {
  /// Nyala secara bawaan. Ini jawaban atas keluhan "gerakan yang kutambah
  /// hilang lagi": orang yang menyusun sesinya sendiri hampir selalu ingin
  /// susunan itu kembali, dan yang tidak ingin tinggal mematikan satu switch —
  /// atau membatalkannya di ringkasan.
  late bool _saveRoutine = widget.saveByDefault;

  bool get _canSync => widget.routine != null && widget.diff != null;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final unfinished = widget.setsTotal - widget.setsDone;
    final numStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: c.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget stat(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(color: c.bgNested, borderRadius: BorderRadius.circular(GymRadius.small)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: numStyle),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: c.text2),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewPadding.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.finishConfirmTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              '${widget.routineName} · ${_formatElapsed(widget.elapsed)}',
              style: TextStyle(fontSize: 13, color: c.text2),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                stat(t.workingSetsLabel, '${widget.setsDone}/${widget.setsTotal}'),
                const SizedBox(width: 8),
                stat(t.volume, context.volume(widget.volumeKg)),
                const SizedBox(width: 8),
                stat(t.duration, _formatElapsed(widget.elapsed)),
              ],
            ),
            if (unfinished > 0) ...[
              const SizedBox(height: 10),
              NoteBanner(text: t.unfinishedSetsNote(unfinished), icon: GymIcons.info, tone: c.warn),
            ],
            if (widget.restRunning) ...[
              const SizedBox(height: 10),
              NoteBanner(text: t.finishRestNote, icon: GymIcons.alarm, tone: c.text2),
            ],
            if (_canSync) ...[
              const SizedBox(height: 10),
              GymCard(
                color: c.surface2,
                radius: GymRadius.card,
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.saveLayoutTo(widget.routine!.name), style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 3),
                          // Nama gerakan yang dibuang tidak ada di sesi lagi —
                          // diambil dari katalog begitu terbaca; sampai saat
                          // itu barisnya tetap tampil dengan yang sudah ada.
                          FutureBuilder<ExerciseCatalog>(
                            future: ExerciseCatalog.load(),
                            builder: (context, snap) => Text(
                              t.routineDiffSummary(
                                widget.diff!,
                                (id) => widget.sessionNames[id] ?? snap.data?.nameOf(id) ?? '…',
                              ),
                              style: TextStyle(fontSize: 12.5, height: 1.35, color: c.text2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _saveRoutine,
                      onChanged: (v) {
                        GymHaptics.tap();
                        setState(() => _saveRoutine = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            GymButton(label: t.finishAndSave, onPressed: () => Navigator.of(context).pop(_canSync && _saveRoutine)),
            const SizedBox(height: 8),
            GymButton(
              label: t.backToSessionUpper,
              tone: GymButtonTone.neutral,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: 14, color: c.text),
      decoration: InputDecoration(
        hintText: context.t.sessionNotes,
        hintStyle: TextStyle(fontSize: 14, color: c.text2),
        prefixIcon: Icon(Icons.notes, size: 18, color: c.text2),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.card),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.card),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.card),
          borderSide: BorderSide(color: c.accent),
        ),
      ),
    );
  }
}

typedef _EditCallback = void Function(int index, {double? weight, int? reps, int? seconds, bool refresh});

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.isFirst,
    required this.isLast,
    required this.onToggleExpand,
    required this.onSetToggled,
    required this.onEdited,
    required this.onEditRest,
    required this.onToggleRest,
    required this.onStartRest,
    required this.onAddSet,
    required this.onAction,
    this.rirRow,
    this.onRir,
  });

  final SessionExercise exercise;
  final bool isFirst;
  final bool isLast;

  /// Baris yang sedang menunggu pilihan RIR, null kalau tidak ada.
  final int? rirRow;
  final void Function(int row, int rir)? onRir;
  final VoidCallback onToggleExpand;
  final void Function(int index, bool done) onSetToggled;
  final _EditCallback onEdited;
  final VoidCallback onEditRest;
  final ValueChanged<bool> onToggleRest;
  final VoidCallback onStartRest;
  final VoidCallback onAddSet;
  final ValueChanged<_ExerciseAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final ex = exercise;
    final p = ex.prescription;
    final policy = policyFor(ex.config);
    final firstWork = ex.sets.firstWhere((s) => !s.isWarmup, orElse: () => const SetRow());
    final t = context.t;
    final w = weightLabel(firstWork.weight, bodyweight: ex.config.bodyweight);

    PopupMenuItem<_ExerciseAction> item(
      _ExerciseAction a,
      IconData icon,
      String label, {
      bool enabled = true,
      Color? tone,
    }) => PopupMenuItem(
      value: a,
      enabled: enabled,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 17, color: enabled ? (tone ?? c.text2) : c.text3),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: enabled ? (tone ?? c.text) : c.text3),
            ),
          ),
        ],
      ),
    );

    return GymCard(
      radius: GymRadius.large,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(GymRadius.small)),
                child: Icon(ex.icon, size: 24, color: c.text2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: onToggleExpand,
                  borderRadius: BorderRadius.circular(GymRadius.small),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 1),
                      Text(
                        ex.expanded
                            ? t.targetLine(
                                w,
                                firstWork.reps,
                                t.policy(policyName[policy]!).toLowerCase(),
                                context.unitLabel,
                              )
                            : t.setsTarget(ex.workCount, w, firstWork.reps, context.unitLabel),
                        style: TextStyle(fontSize: 12, color: c.text2),
                      ),
                      if (ex.config.superset) ...[
                        const SizedBox(height: 4),
                        Pill(
                          color: c.accentSoft,
                          textColor: c.accent,
                          child: Text(t.supersetBadge, style: const TextStyle(fontSize: 9.5, letterSpacing: 0.8)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleExpand,
                // Satu chevron yang berputar, bukan dua ikon yang bertukar:
                // mata mengikuti benda yang bergerak, dan arahnya bilang
                // "ini akan menutup" sebelum kartunya bergerak.
                icon: AnimatedRotation(
                  turns: ex.expanded ? 0.5 : 0,
                  duration: GymMotion.of(context, GymMotion.normal),
                  curve: GymMotion.curve,
                  child: Icon(Icons.keyboard_arrow_down, color: c.text2),
                ),
                tooltip: ex.expanded ? t.collapse : t.expand,
              ),
              PopupMenuButton<_ExerciseAction>(
                icon: Icon(GymIcons.moreVertical, size: 20, color: c.text2),
                tooltip: t.exerciseActions,
                color: c.surface2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.control)),
                onSelected: onAction,
                itemBuilder: (context) => [
                  item(_ExerciseAction.moveUp, Icons.arrow_upward, t.moveUp, enabled: !isFirst),
                  item(_ExerciseAction.moveDown, Icons.arrow_downward, t.moveDown, enabled: !isLast),
                  item(_ExerciseAction.replace, Icons.swap_horiz, t.replaceExercise),
                  item(_ExerciseAction.addWarmup, Icons.whatshot_outlined, t.addWarmup),
                  item(_ExerciseAction.addDropSet, Icons.south_east, t.addDropSet),
                  item(_ExerciseAction.addRestPause, Icons.pause_circle_outline, t.addRestPause),
                  item(
                    _ExerciseAction.superset,
                    Icons.link,
                    ex.config.superset ? t.endSuperset : t.supersetWithNext,
                    enabled: ex.config.superset || !isLast,
                  ),
                  item(_ExerciseAction.note, Icons.sticky_note_2_outlined, t.exerciseNote),
                  item(_ExerciseAction.history, GymIcons.chart, t.exerciseHistory),
                  item(
                    _ExerciseAction.removeLastSet,
                    Icons.remove_circle_outline,
                    t.removeLastSet,
                    enabled: ex.sets.length > 1,
                  ),
                  item(_ExerciseAction.remove, GymIcons.trash, t.removeExercise, tone: c.danger),
                ],
              ),
            ],
          ),
          if (ex.note != null || ex.lastNote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(50, 6, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: 14, color: c.warn),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ex.note ?? t.lastNote(ex.lastNote!),
                      style: TextStyle(fontSize: 12.5, height: 1.35, color: ex.note != null ? c.text : c.text2),
                    ),
                  ),
                ],
              ),
            ),
          // Kartu membuka dan menutup dengan tinggi yang bergerak, supaya
          // kartu-kartu di bawahnya ikut turun — bukan melompat ke posisi
          // barunya. Saat tertutup anaknya kotak setinggi nol; isinya tidak
          // dibangun, jadi kartu yang tertutup tetap murah.
          _SizeChange(
            child: !ex.expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _RestRow(exercise: ex, onEdit: onEditRest, onToggle: onToggleRest, onStart: onStartRest),
                        if (p != null) ...[const SizedBox(height: 10), _WhyBanner(text: t.why(p.why), kind: p.kind)],
                        // Mesin assisted (#232): pengingat kecil bahwa angka
                        // di kolom KG adalah bantuan, sebelum orangnya
                        // mengetik "lebih berat" ke arah yang salah.
                        if (ex.config.assisted == true) ...[
                          const SizedBox(height: 10),
                          NoteBanner(text: t.assistedNote, icon: GymIcons.info, tone: c.text2),
                        ],
                        const SizedBox(height: 12),
                        _SetTable(
                          exercise: ex,
                          onToggled: onSetToggled,
                          onEdited: onEdited,
                          rirRow: rirRow,
                          onRir: onRir,
                        ),
                        const SizedBox(height: 10),
                        _DashedAction(icon: GymIcons.plus, label: t.addSet, onTap: onAddSet, compact: true),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Baris pengatur istirahat satu gerakan.
///
/// Semua isinya harus muat di HP 360 dp. Versi sebelumnya menaruh label,
/// durasi, tombol START berlabel, dan Switch berukuran penuh berjajar tanpa
/// batas, sehingga Switch terdorong keluar kartu dan tidak bisa disentuh.
class _RestRow extends StatelessWidget {
  const _RestRow({required this.exercise, required this.onEdit, required this.onToggle, required this.onStart});

  final SessionExercise exercise;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final d = exercise.restDuration;
    final text = d.inSeconds % 60 == 0 ? '${d.inMinutes}m' : '${d.inMinutes}m ${d.inSeconds % 60}s';
    final on = exercise.restEnabled;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: c.bgNested,
        borderRadius: BorderRadius.circular(GymRadius.small),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(GymIcons.alarm, size: 17, color: on ? c.text2 : c.text3),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    context.t.restTimer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: on ? c.text : c.text3),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(GymRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          text,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? c.accent : c.text3),
                        ),
                        const SizedBox(width: 4),
                        Icon(GymIcons.edit, size: 14, color: c.text2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Mulai istirahat tanpa harus mencentang set dulu — kadang orang
          // istirahat di tengah, atau baru ingat menekan setelah mulai.
          if (on)
            IconButton(
              onPressed: onStart,
              tooltip: context.t.start,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: c.accentSoft),
              icon: Icon(GymIcons.play, size: 18, color: c.accent),
            ),
          Switch(value: on, onChanged: onToggle, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ],
      ),
    );
  }
}

/// Kenapa angka targetnya segitu (FR-E5). Selalu ada isinya, jadi tidak perlu
/// kondisi "kalau ada alasan".
class _WhyBanner extends StatelessWidget {
  const _WhyBanner({required this.text, required this.kind});

  final String text;
  final PrescriptionKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final (icon, tint) = switch (kind) {
      PrescriptionKind.up => (Icons.trending_up, c.accent),
      PrescriptionKind.deload => (Icons.trending_down, c.warn),
      PrescriptionKind.hold => (Icons.trending_flat, c.text2),
      _ => (Icons.flag_outlined, c.text2),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(GymRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tint),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetTable extends StatelessWidget {
  const _SetTable({required this.exercise, required this.onToggled, required this.onEdited, this.rirRow, this.onRir});

  final SessionExercise exercise;
  final void Function(int index, bool done) onToggled;
  final _EditCallback onEdited;
  final int? rirRow;
  final void Function(int row, int rir)? onRir;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    var workIndex = 0;
    final timed = exercise.config.mode == LogMode.time;
    final inc = weightIncrement(exercise.config, context.unitLabel);
    exercise._align();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              SizedBox(width: 34, child: SectionLabel(context.t.setCol)),
              SizedBox(width: 62, child: SectionLabel(context.t.prevCol)),
              Expanded(child: Center(child: SectionLabel(context.t.weightCol(context.unitLabel)))),
              Expanded(child: Center(child: SectionLabel(timed ? context.t.secCol : context.t.repsCol))),
              const SizedBox(width: 38),
            ],
          ),
        ),
        for (var i = 0; i < exercise.sets.length; i++)
          Builder(
            builder: (context) {
              final s = exercise.sets[i];
              if (s.isWork) workIndex++;
              final (label, tone) = switch (s.phase) {
                SetPhase.warmup => ('W', c.warn),
                SetPhase.drop => ('D', c.accent),
                SetPhase.restPause => ('RP', c.accent),
                SetPhase.work => ('$workIndex', c.doneInk),
              };
              // Identitas baris dipegang [Reveal], elemen terluar baris: baris
              // lama tidak beranimasi ulang saat warm-up disisipkan di depan —
              // hanya baris yang benar-benar baru yang muncul dengan memudar.
              // Kunci penyegar input ([SessionExercise.rowKeys]) ada di
              // dalamnya, jadi menggantinya membangun ulang kotak input tanpa
              // menyentuh animasinya.
              return Reveal(
                key: exercise.rowIds[i],
                index: i,
                child: Padding(
                  key: exercise.rowKeys[i],
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    children: [
                      _SetRowTile(
                        label: label,
                        labelColor: tone,
                        previous: i < exercise.previous.length ? exercise.previous[i] : '—',
                        set: s,
                        bodyweight: exercise.config.bodyweight,
                        timed: timed,
                        step: inc,
                        onToggled: (v) => onToggled(i, v),
                        onWeight: (w, {refresh = false}) => onEdited(i, weight: w, refresh: refresh),
                        onReps: (r) => timed ? onEdited(i, seconds: r) : onEdited(i, reps: r),
                      ),
                      if (rirRow == i && onRir != null) _RirChips(selected: s.rir, onPick: (v) => onRir!(i, v)),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _SetRowTile extends StatelessWidget {
  const _SetRowTile({
    required this.label,
    required this.labelColor,
    required this.previous,
    required this.set,
    required this.bodyweight,
    required this.onToggled,
    required this.onWeight,
    required this.onReps,
    this.timed = false,
    this.step = 2.5,
  });

  final String label;
  final Color labelColor;
  final String previous;
  final SetRow set;
  final bool bodyweight;
  final bool timed;
  final double step;
  final ValueChanged<bool> onToggled;
  final void Function(double weight, {bool refresh}) onWeight;
  final ValueChanged<int> onReps;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final done = set.done;

    return AnimatedContainer(
      duration: GymMotion.of(context, GymMotion.quick),
      curve: GymMotion.curve,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        // Baris selesai jadi hijau gelap, tapi angkanya tetap putih penuh:
        // membaca beban dari jarak satu lengan lebih penting daripada
        // menegaskan bahwa baris itu sudah lewat (FR-D3).
        color: done ? c.doneBg : c.bgNested,
        borderRadius: BorderRadius.circular(GymRadius.small),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: label.length > 1 && label != '${int.tryParse(label)}' ? 11 : 13,
                fontWeight: FontWeight.w800,
                color: done || !set.isWork ? labelColor : c.text2,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              previous,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(fontSize: 12, color: c.text2),
            ),
          ),
          Expanded(
            flex: 5,
            child: _Cell(
              text: set.weight == 0 ? '' : formatDelta(set.weight),
              doneText: formatWeight(set.weight),
              hint: bodyweight ? 'BW' : context.unitLabel,
              done: done,
              decimal: true,
              onChanged: (v) => onWeight(double.tryParse(v.replaceAll(',', '.')) ?? 0),
              // Tombol −/+ selangkah increment: tangan berkapur tidak perlu
              // membuka keyboard untuk 60 → 62,5.
              onStep: step <= 0 ? null : (dir) => onWeight(stepWeight(set.weight, step, dir), refresh: true),
            ),
          ),
          Expanded(
            flex: 3,
            child: _Cell(
              text: timed ? (set.seconds == 0 ? '' : '${set.seconds}') : (set.reps == 0 ? '' : '${set.reps}'),
              doneText: timed ? '${set.seconds}s' : (set.rir == null ? '${set.reps}' : '${set.reps} @${set.rir}'),
              hint: '0',
              done: done,
              decimal: false,
              onChanged: (v) => onReps(int.tryParse(v) ?? 0),
            ),
          ),
          SizedBox(
            width: 38,
            child: Semantics(
              button: true,
              checked: done,
              label: context.t.markSetDone(label),
              child: InkWell(
                onTap: () {
                  // Getar hanya saat menandai selesai — itu momen "tercatat".
                  // Membatalkan centang tidak perlu dirayakan.
                  if (!done) GymHaptics.confirm();
                  FocusScope.of(context).unfocus();
                  onToggled(!done);
                },
                borderRadius: BorderRadius.circular(GymRadius.pill),
                child: AnimatedSwitcher(
                  duration: GymMotion.of(context, GymMotion.quick),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    done ? Icons.check_circle : Icons.circle_outlined,
                    key: ValueKey(done),
                    size: 24,
                    color: done ? c.doneInk : c.text3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sel angka. Baris yang belum dicentang tampil sebagai kotak input — itu yang
/// membedakan "sudah tercatat" dari "silakan isi" tanpa teks tambahan.
///
/// Memegang controller-nya sendiri supaya nilai yang berubah dari luar (tombol
/// −/+, beban yang diteruskan dari set di atasnya) langsung terlihat, tanpa
/// menimpa apa yang sedang diketik ("62." tetap "62.", bukan dipotong jadi "62").
class _Cell extends StatefulWidget {
  const _Cell({
    required this.text,
    required this.doneText,
    required this.hint,
    required this.done,
    required this.decimal,
    required this.onChanged,
    this.onStep,
  });

  final String text;
  final String doneText;
  final String hint;
  final bool done;
  final bool decimal;
  final ValueChanged<String> onChanged;

  /// −1 atau +1. null = tanpa tombol langkah.
  final ValueChanged<int>? onStep;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  late final _controller = TextEditingController(text: widget.text);

  double? _num(String s) => double.tryParse(s.replaceAll(',', '.'));

  @override
  void didUpdateWidget(covariant _Cell old) {
    super.didUpdateWidget(old);
    if (widget.text != old.text && _num(_controller.text) != _num(widget.text)) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final style = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: c.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    if (widget.done) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(widget.doneText, style: style),
        ),
      );
    }

    Widget stepButton(int dir) => InkWell(
      onTap: () {
        GymHaptics.tap();
        widget.onStep!(dir);
      },
      borderRadius: BorderRadius.circular(GymRadius.input),
      child: SizedBox(width: 24, height: 36, child: Icon(dir < 0 ? Icons.remove : Icons.add, size: 16, color: c.text2)),
    );

    final field = TextField(
      controller: _controller,
      textAlign: TextAlign.center,
      style: style,
      onChanged: widget.onChanged,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.allow(widget.decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]')),
        LengthLimitingTextInputFormatter(widget.decimal ? 6 : 3),
      ],
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: c.surface2,
        hintText: widget.hint,
        hintStyle: style.copyWith(color: c.text3, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.input),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.input),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.input),
          borderSide: BorderSide(color: c.accent),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: widget.onStep == null
          ? field
          : Row(
              children: [
                stepButton(-1),
                Expanded(child: field),
                stepButton(1),
              ],
            ),
    );
  }
}

/// Pilihan RIR (sisa rep sebelum gagal) setelah set dicentang.
class _RirChips extends StatelessWidget {
  const _RirChips({required this.selected, required this.onPick});

  final int? selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 6, 4, 2),
      // Wrap, bukan Row: label dan lima pilihan tidak selalu muat satu baris
      // di HP 360 dp dengan huruf besar.
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(context.t.rirPrompt, style: TextStyle(fontSize: 11.5, color: c.text2)),
          ),
          for (var v = 0; v <= 4; v++)
            Padding(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => onPick(v),
                borderRadius: BorderRadius.circular(GymRadius.pill),
                child: Container(
                  width: 30,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == v ? c.accentFill : c.surface2,
                    borderRadius: BorderRadius.circular(GymRadius.pill),
                  ),
                  child: Text(
                    v == 4 ? '4+' : '$v',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected == v ? c.accentInk : c.text,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dialog catatan satu gerakan. Widget sendiri supaya controller-nya hidup
/// sampai dialognya benar-benar hilang.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
      title: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: t.exerciseNoteHint),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t.cancel,
            style: TextStyle(fontWeight: FontWeight.w700, color: c.text2),
          ),
        ),
        GymButton(
          label: t.save,
          height: 42,
          expand: false,
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}

class _DashedAction extends StatelessWidget {
  const _DashedAction({required this.icon, required this.label, required this.onTap, this.compact = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(compact ? GymRadius.small : GymRadius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: Container(
          height: compact ? 36 : 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? GymRadius.small : GymRadius.control),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: compact ? c.text2 : c.accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: compact ? c.text2 : c.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
