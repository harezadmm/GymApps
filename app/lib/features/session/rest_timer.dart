/// Timer istirahat antar set (FR-D8), mengikuti artboard `08 Workout Session`
/// dan `08b Rest Duration`.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Batas durasi istirahat yang masuk akal. 5 detik ke bawah bukan istirahat,
/// dan di atas 30 menit orang sudah pulang.
const minRest = Duration(seconds: 5);
const maxRest = Duration(minutes: 30);

String formatRest(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Versi dua digit menit untuk angka besar di kartu: `01:29`.
String formatRestWide(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
}

Duration clampRest(Duration d) => d < minRest ? minRest : (d > maxRest ? maxRest : d);

/// Hitung mundur istirahat.
///
/// Sisa waktu dihitung dari **tenggat jam dinding**, bukan dengan mengurangi
/// counter tiap tick. Timer Flutter bisa terlambat dipanggil saat UI sibuk, dan
/// pendekatan counter menumpuk keterlambatan itu — untuk istirahat 90 detik yang
/// ditonton orang sambil menunggu, selisihnya terlihat.
///
/// Waktunya dibaca lewat `clock.now()` dari package:clock, bukan
/// `DateTime.now()`, supaya perilakunya bisa diuji tanpa benar-benar menunggu
/// 90 detik per kasus uji.
class RestTimer extends ChangeNotifier {
  Duration _total = const Duration(seconds: 90);
  DateTime? _deadline;
  Timer? _tick;

  /// Durasi penuh istirahat ini — penyebut cincin progres.
  Duration get total => _total;

  bool get isRunning => _deadline != null;

  Duration get remaining {
    final end = _deadline;
    if (end == null) return Duration.zero;
    final left = end.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// 0 di awal, 1 saat habis. Dipakai cincin progres.
  double get progress {
    if (_total.inMilliseconds <= 0) return 1;
    final done = _total.inMilliseconds - remaining.inMilliseconds;
    return (done / _total.inMilliseconds).clamp(0.0, 1.0);
  }

  void start([Duration? d]) {
    _total = clampRest(d ?? _total);
    _deadline = clock.now().add(_total);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (remaining == Duration.zero) {
        skip();
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  /// Tombol −15s / +15s.
  ///
  /// Total ikut bergeser, bukan hanya sisanya: kalau hanya sisanya yang
  /// ditambah, cincin akan melompat mundur dan menampilkan progres yang bohong.
  void adjust(Duration delta) {
    final end = _deadline;
    if (end == null) return;
    final left = remaining + delta;
    if (left <= Duration.zero) {
      skip();
      return;
    }
    _total = clampRest(_total + delta);
    _deadline = clock.now().add(left > _total ? _total : left);
    notifyListeners();
  }

  /// Ganti durasi di tengah istirahat yang sedang berjalan — dari sheet durasi.
  /// Waktu yang sudah lewat tetap dihitung, jadi mengubah 1:30 ke 2:00 pada
  /// detik ke-30 menyisakan 1:30, bukan mengulang dari awal.
  void retarget(Duration next) {
    final end = _deadline;
    final target = clampRest(next);
    if (end == null) {
      _total = target;
      notifyListeners();
      return;
    }
    final elapsed = _total - remaining;
    _total = target;
    final left = target - elapsed;
    if (left <= Duration.zero) {
      skip();
      return;
    }
    _deadline = clock.now().add(left);
    notifyListeners();
  }

  void skip() {
    _tick?.cancel();
    _tick = null;
    _deadline = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

/// Kartu istirahat biru di atas daftar gerakan.
class RestTimerCard extends StatelessWidget {
  const RestTimerCard({
    super.key,
    required this.timer,
    required this.nextLabel,
    required this.onEditDuration,
    this.onOpen,
  });

  final RestTimer timer;

  /// "Next: set 3 · 72.5 kg × 8" — supaya tidak perlu menggulir saat menunggu.
  final String nextLabel;
  final VoidCallback onEditDuration;

  /// Ketuk kartunya untuk membuka hitung mundur satu layar penuh.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return AnimatedBuilder(
      animation: timer,
      builder: (context, _) {
        final card = GymCard(
          radius: GymRadius.large,
          color: const Color(0xFF10263A),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: timer.progress,
                          strokeWidth: 3,
                          backgroundColor: c.accent.withValues(alpha: 0.18),
                          valueColor: AlwaysStoppedAnimation(c.accent),
                        ),
                        Text(
                          'REST',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: c.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatRestWide(timer.remaining),
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                color: c.text,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text('/ ${formatRest(timer.total)}',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text2)),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: InkWell(
                                onTap: onEditDuration,
                                borderRadius: BorderRadius.circular(GymRadius.pill),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.edit_outlined, size: 15, color: c.text2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(nextLabel, style: TextStyle(fontSize: 12, color: c.text2)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GymButton(
                      label: '−15s',
                      height: 46,
                      shape: GymButtonShape.rounded,
                      tone: GymButtonTone.neutral,
                      onPressed: () => timer.adjust(const Duration(seconds: -15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GymButton(
                      label: '+15s',
                      height: 46,
                      tone: GymButtonTone.neutral,
                      onPressed: () => timer.adjust(const Duration(seconds: 15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: GymButton(label: context.t.skip.toUpperCase(), height: 46, onPressed: timer.skip)),
                ],
              ),
            ],
          ),
        );

        if (onOpen == null) return card;
        return InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(GymRadius.large),
          child: card,
        );
      },
    );
  }
}

/// Hasil dari sheet durasi: berapa lama, dan apakah dijadikan default gerakan.
class RestChoice {
  const RestChoice({required this.duration, required this.saveAsDefault});
  final Duration duration;
  final bool saveAsDefault;
}

/// Sheet "Rest duration" — artboard `08b`.
Future<RestChoice?> showRestDurationSheet(
  BuildContext context, {
  required Duration current,
  required String exerciseName,
  required String routineName,
  Duration globalDefault = const Duration(seconds: 90),
}) {
  return showModalBottomSheet<RestChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RestDurationSheet(
      current: current,
      exerciseName: exerciseName,
      routineName: routineName,
      globalDefault: globalDefault,
    ),
  );
}

class _RestDurationSheet extends StatefulWidget {
  const _RestDurationSheet({
    required this.current,
    required this.exerciseName,
    required this.routineName,
    required this.globalDefault,
  });

  final Duration current;
  final String exerciseName;
  final String routineName;
  final Duration globalDefault;

  @override
  State<_RestDurationSheet> createState() => _RestDurationSheetState();
}

class _RestDurationSheetState extends State<_RestDurationSheet> {
  late Duration _value = clampRest(widget.current);
  bool _saveDefault = false;

  static const _presets = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(seconds: 90),
    Duration(minutes: 2),
    Duration(minutes: 3),
    Duration(minutes: 5),
  ];

  /// Detik naik-turun per 5. Memilih 47 detik lewat tombol butuh sembilan
  /// ketukan dan tidak ada yang mengistirahatkan diri seteliti itu.
  static const _secondStep = 5;

  void _bump(Duration delta) {
    setState(() => _value = clampRest(_value + delta));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(GymRadius.sheet)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewPadding.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(GymRadius.pill)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t.restDuration, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text('${widget.exerciseName} · ${widget.routineName}',
                          style: TextStyle(fontSize: 13, color: c.text2)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: c.text2),
                  tooltip: context.t.close,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Stepper(
                    label: context.t.minutes,
                    value: _value.inMinutes,
                    onMinus: () => _bump(const Duration(minutes: -1)),
                    onPlus: () => _bump(const Duration(minutes: 1)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stepper(
                    label: context.t.seconds,
                    value: _value.inSeconds % 60,
                    onMinus: () => _bump(const Duration(seconds: -_secondStep)),
                    onPlus: () => _bump(const Duration(seconds: _secondStep)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SectionLabel(context.t.presets),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, box) {
                const gap = 10.0;
                final w = (box.maxWidth - gap * 2) / 3;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final p in _presets)
                      SizedBox(
                        width: w,
                        child: _PresetChip(
                          label: formatRest(p),
                          selected: p == _value,
                          onTap: () => setState(() => _value = p),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            GymCard(
              color: c.surface2,
              radius: GymRadius.card,
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.t.saveDefaultFor(widget.exerciseName),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(context.t.sessionOnly,
                            style: TextStyle(fontSize: 12, color: c.text2)),
                      ],
                    ),
                  ),
                  Switch(value: _saveDefault, onChanged: (v) => setState(() => _saveDefault = v)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: c.text2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Global default stays ${widget.globalDefault.inSeconds} s (Profile → Default rest).',
                    style: TextStyle(fontSize: 12, color: c.text2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GymButton(
                    label: context.t.cancelUpper,
                    tone: GymButtonTone.neutral,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: GymButton(
                    label: context.t.setDuration(formatRest(_value)),
                    onPressed: () => Navigator.of(context).pop(
                      RestChoice(duration: _value, saveAsDefault: _saveDefault),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onMinus, required this.onPlus});

  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: c.bgNested,
            borderRadius: BorderRadius.circular(GymRadius.card),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _StepButton(icon: Icons.remove, onTap: onMinus, semantic: 'decrease $label'),
              Expanded(
                child: Center(
                  child: Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              _StepButton(icon: Icons.add, onTap: onPlus, semantic: 'increase $label'),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap, required this.semantic});

  final IconData icon;
  final VoidCallback onTap;
  final String semantic;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Semantics(
      button: true,
      label: semantic,
      child: Material(
        color: c.bgNested,
        borderRadius: BorderRadius.circular(GymRadius.stepper),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GymRadius.stepper),
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 20, color: c.accent)),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Material(
      color: selected ? c.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(GymRadius.stepper),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.stepper),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.stepper),
            border: Border.all(color: selected ? Colors.transparent : c.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? c.accentInk : c.text,
            ),
          ),
        ),
      ),
    );
  }
}
