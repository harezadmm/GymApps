/// Kartu Analisis AI di layar Recap (spec `design/RECAP-AI.md` §3).
///
/// Keadaan: siap → memuat → hasil, atau galat dengan kalimat yang bisa
/// ditindaklanjuti. Hasil disimpan per akun + periode bersama sidik jari
/// payload: membuka recap yang sama tidak memanggil AI lagi, dan kalau datanya
/// berubah, hasil lama tetap tampil dengan tanda.
library;

import 'package:flutter/material.dart';

import '../../core/gym_icons.dart';
import '../../core/strings.dart';
import '../../core/strings_recap.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/recap_ai.dart';
import '../../domain/recap.dart';

enum _Phase { idle, loading, done, error }

class RecapAiCard extends StatefulWidget {
  const RecapAiCard({
    super.key,
    required this.available,
    required this.payload,
    required this.account,
    required this.period,
    required this.start,
    required this.analyzer,
    this.cache,
  });

  /// Akun tersambung ke server. Akun lokal tidak bisa memakai AI.
  final bool available;

  /// Null selagi katalog gerakan dibaca — nama gerakan belum ada.
  final Map<String, dynamic>? payload;
  final String account;
  final RecapPeriod period;
  final DateTime start;
  final RecapAnalyzer analyzer;
  final RecapAiCache? cache;

  @override
  State<RecapAiCard> createState() => _RecapAiCardState();
}

class _RecapAiCardState extends State<RecapAiCard> {
  late final RecapAiCache _cache = widget.cache ?? RecapAiCache();
  _Phase _phase = _Phase.idle;
  RecapAnalysis? _result;
  String? _resultFingerprint;
  RecapAiFailure? _error;

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  Future<void> _loadCached() async {
    final hit = await _cache.load(widget.account, widget.period, widget.start);
    if (!mounted || hit == null || _phase != _Phase.idle) return;
    setState(() {
      _result = hit.analysis;
      _resultFingerprint = hit.fingerprint;
      _phase = _Phase.done;
    });
  }

  Future<void> _analyze() async {
    final payload = widget.payload;
    if (payload == null || _phase == _Phase.loading) return;
    final fingerprint = payloadFingerprint(payload);
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final a = await widget.analyzer.analyze(payload);
      await _cache.save(widget.account, widget.period, widget.start, fingerprint, a);
      if (!mounted) return;
      setState(() {
        _result = a;
        _resultFingerprint = fingerprint;
        _phase = _Phase.done;
      });
    } on RecapAiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.kind;
        _phase = _Phase.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = RecapAiFailure.failed;
        _phase = _Phase.error;
      });
    }
  }

  String _message(Strings t, RecapAiFailure kind) => switch (kind) {
        RecapAiFailure.notConnected => t.aiNotConnected,
        RecapAiFailure.offline => t.aiOffline,
        RecapAiFailure.limit => t.aiLimit,
        RecapAiFailure.busy => t.aiBusy,
        RecapAiFailure.unavailable => t.aiUnavailable,
        RecapAiFailure.empty => t.aiEmpty,
        RecapAiFailure.failed => t.aiFailed,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final payload = widget.payload;
    final stale = _result != null && payload != null && payloadFingerprint(payload) != _resultFingerprint;
    return GymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HueTile(icon: GymIcons.starFilled, hue: c.accent, size: 36, radius: 12, iconSize: 17),
              const SizedBox(width: 12),
              Expanded(child: Text(t.aiTitle, style: Theme.of(context).textTheme.titleMedium)),
              Pill(color: c.surface2, textColor: c.text2, child: const Text('Gemini')),
            ],
          ),
          const SizedBox(height: 12),
          if (!widget.available)
            Text(t.aiLocalOnly, style: TextStyle(fontSize: 13, height: 1.45, color: c.text2))
          else ...switch (_phase) {
            _Phase.idle => [
                Text(t.aiIntro, style: TextStyle(fontSize: 13.5, height: 1.45, color: c.text2)),
                const SizedBox(height: 14),
                GymButton(
                  key: const ValueKey('recap-ai-analyze'),
                  label: t.aiAnalyze,
                  icon: GymIcons.starFilled,
                  height: 48,
                  onPressed: payload == null ? null : _analyze,
                ),
                const SizedBox(height: 8),
                Text(t.aiDataNote, style: TextStyle(fontSize: 11.5, height: 1.4, color: c.text3)),
              ],
            _Phase.loading => [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(t.aiAnalyzing, style: TextStyle(fontSize: 13.5, color: c.text2)),
                      ),
                    ],
                  ),
                ),
                if (_result != null) ...[const SizedBox(height: 8), _ResultView(analysis: _result!)],
              ],
            _Phase.error => [
                NoteBanner(
                  key: const ValueKey('recap-ai-error'),
                  text: _message(t, _error ?? RecapAiFailure.failed),
                  icon: GymIcons.alert,
                  tone: c.warn,
                ),
                const SizedBox(height: 12),
                GymButton(label: t.aiRetry, tone: GymButtonTone.neutral, height: 44, onPressed: _analyze),
                if (_result != null) ...[const SizedBox(height: 16), _ResultView(analysis: _result!)],
              ],
            _Phase.done => [
                if (stale) ...[
                  NoteBanner(text: t.aiStale, icon: GymIcons.info, tone: c.accent),
                  const SizedBox(height: 12),
                ],
                _ResultView(key: const ValueKey('recap-ai-result'), analysis: _result!),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.aiAnalyzedAt(_when(t, _result!.createdAt), _result!.model),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: c.text3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Flexible + FittedBox: pada huruf 1,5× di HP 360 dp tautannya
                    // mengecil, tidak mendorong baris keluar kartu.
                    Flexible(
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: payload == null ? null : _analyze,
                          borderRadius: BorderRadius.circular(GymRadius.pill),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(t.aiReanalyze,
                                      maxLines: 1,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(t.aiDisclaimer, style: TextStyle(fontSize: 11, color: c.text3)),
              ],
          },
        ],
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  String _when(Strings t, DateTime at) {
    final sep = t.lang == AppLanguage.indonesian ? '.' : ':';
    return '${t.weekdayShort(at.weekday)} ${at.day} ${t.monthShort(at.month)}, ${_two(at.hour)}$sep${_two(at.minute)}';
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({super.key, required this.analysis});

  final RecapAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final a = analysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(a.headline, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3, color: c.text)),
        const SizedBox(height: 6),
        Text(a.summary, style: TextStyle(fontSize: 13.5, height: 1.45, color: c.text2)),
        if (a.strengths.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(icon: GymIcons.checkCircle, tone: c.doneInk, title: t.aiStrengths, items: a.strengths),
        ],
        if (a.critiques.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Section(icon: GymIcons.alert, tone: c.warn, title: t.aiCritiques, items: a.critiques),
        ],
        if (a.suggestions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionTitle(icon: GymIcons.arrowUpRight, tone: c.accent, title: t.aiSuggestions),
          const SizedBox(height: 8),
          for (final (i, s) in a.suggestions.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(GymRadius.control)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.text)),
                  const SizedBox(height: 3),
                  Text(s.detail, style: TextStyle(fontSize: 13, height: 1.4, color: c.text2)),
                ],
              ),
            ),
          ],
        ],
        if (a.nextFocus.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionTitle(icon: GymIcons.flag, tone: c.accent, title: t.aiNextFocus),
          const SizedBox(height: 8),
          NoteBanner(text: a.nextFocus, icon: GymIcons.arrowUpRight, tone: c.accent),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.tone, required this.title});

  final IconData icon;
  final Color tone;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Row(
      children: [
        Icon(icon, size: 15, color: tone),
        const SizedBox(width: 7),
        Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text))),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.tone, required this.title, required this.items});

  final IconData icon;
  final Color tone;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: icon, tone: tone, title: title),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, left: 4),
                  child: Container(width: 5, height: 5, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(item, style: TextStyle(fontSize: 13.5, height: 1.4, color: c.text))),
              ],
            ),
          ),
      ],
    );
  }
}
