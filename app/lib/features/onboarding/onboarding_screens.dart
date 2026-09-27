/// Dua langkah onboarding — artboard `02 Onboarding · Program` dan
/// `03 Onboarding · Equipment`.
///
/// Urutannya: pilih program (template atau susun sendiri) → daftar peralatan →
/// Home. Dua pertanyaan ini yang harus dijawab sebelum aplikasi bisa menyusun
/// sesi pertama, dan keduanya bisa diubah lagi belakangan.
library;

import 'package:flutter/material.dart';
import '../../core/illustration.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/settings.dart';
import '../profile/equipment_picker.dart';

/// Bar progres dua langkah di puncak layar onboarding.
class _OnboardingTop extends StatelessWidget {
  const _OnboardingTop({required this.progress, required this.onBack, this.onSkip});

  final double progress;
  final VoidCallback? onBack;

  /// Lewati langkah ini. Jawabannya bisa diubah kapan saja lewat Profile, jadi
  /// menahan orang di sini tidak memberi apa-apa selain gesekan.
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 18),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back, color: onBack == null ? c.text3 : c.text2),
            tooltip: context.t.back,
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(GymRadius.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: c.surface2,
                valueColor: AlwaysStoppedAnimation(c.accent),
              ),
            ),
          ),
          if (onSkip != null)
            TextButton(
              onPressed: onSkip,
              child: Text(context.t.skip,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.text2)),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Satu template program bawaan.
class ProgramTemplate {
  const ProgramTemplate({
    required this.id,
    required this.name,
    required this.rhythm,
    required this.detail,
  });

  final String id;
  final String name;

  /// "3 routines · rotation" — berapa rutinitas dan bagaimana urutannya maju.
  final String rhythm;
  final String detail;
}

/// Template bawaan sesuai tabel spec §5.
const programTemplates = <ProgramTemplate>[
  ProgramTemplate(
    id: 'ppl',
    name: 'Push / Pull / Legs',
    rhythm: '3 routines · rotation',
    detail: 'Balanced volume, 3–6 sessions a week',
  ),
  ProgramTemplate(
    id: 'upper-lower',
    name: 'Upper / Lower',
    rhythm: '2 routines · rotation',
    detail: 'Simple alternation, good for 4 days',
  ),
  ProgramTemplate(
    id: 'bro-split',
    name: 'Bro split',
    rhythm: '5 routines · Mon–Fri',
    detail: 'One muscle group per day',
  ),
  ProgramTemplate(
    id: 'heavy-duty',
    name: 'Heavy Duty',
    rhythm: '4 routines · rotation',
    detail: '1 working set to failure, 3 rest days',
  ),
  ProgramTemplate(
    id: 'full-body',
    name: 'Full Body',
    rhythm: '1 routine · rotation',
    detail: 'Everything every session',
  ),
  ProgramTemplate(
    id: 'five-by-five',
    name: '5 × 5',
    rhythm: '2 routines · rotation',
    detail: 'Strength focus, linear progression',
  ),
];

class ProgramPickerScreen extends StatefulWidget {
  const ProgramPickerScreen({super.key, required this.onContinue, required this.onBuildOwn, this.onBack});

  final ValueChanged<ProgramTemplate> onContinue;

  /// "Build my own": susun split sendiri alih-alih memakai template.
  final VoidCallback onBuildOwn;

  final VoidCallback? onBack;

  @override
  State<ProgramPickerScreen> createState() => _ProgramPickerScreenState();
}

class _ProgramPickerScreenState extends State<ProgramPickerScreen> {
  int _picked = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingTop(progress: 0.5, onBack: widget.onBack),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  const Center(child: GymIllustration(GymArt.planWorkout, height: 140, blob: true)),
                  const SizedBox(height: 14),
                  Text(context.t.chooseProgram, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(context.t.chooseProgramSub,
                      style: TextStyle(fontSize: 13.5, color: c.text2)),
                  const SizedBox(height: 18),
                  for (final (i, t) in programTemplates.indexed) ...[
                    _ProgramCard(
                      template: t,
                      selected: i == _picked,
                      onTap: () => setState(() => _picked = i),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 4),
                  _OutlinedAction(icon: Icons.add, label: context.t.buildMyOwn, onTap: widget.onBuildOwn),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: GymButton(
                label: context.t.cont,
                onPressed: () => widget.onContinue(programTemplates[_picked]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.template, required this.selected, required this.onTap});

  final ProgramTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Material(
      color: selected ? c.selected : c.surface,
      borderRadius: BorderRadius.circular(GymRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.card),
            border: Border.all(color: selected ? c.accent : c.border),
          ),
          child: SelectRow(
            title: template.name,
            subtitle: context.t.catalogue(template.rhythm),
            detail: context.t.catalogue(template.detail),
            selected: selected,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

/// Profil gym (FR-C3): kelompok alat yang ada, dipakai menyaring library.
class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key, required this.onContinue, this.onBack, this.onSkip, this.gymName = 'Gym A'});

  final VoidCallback onContinue;
  final VoidCallback? onBack;

  /// Lewati tanpa memilih apa pun. Library tidak akan tersaring, dan itu bukan
  /// keadaan yang rusak — hanya belum dipersempit.
  final VoidCallback? onSkip;

  final String gymName;

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  /// Mesin kardio dan bola tidak dicentang dari awal: kebanyakan gym beban
  /// punya, tapi jarang dipakai untuk latihan kekuatan.
  var _selected = {for (final k in equipmentGroups.keys) if (k != 'cardio' && k != 'balls') k};

  Future<void> _continue() async {
    final store = WorkoutScope.read(context);
    await store.updateSettings(store.settings.copyWith(equipment: _selected.toList()));
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingTop(progress: 1, onBack: widget.onBack, onSkip: widget.onSkip),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(context.t.whatsInYourGym, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(context.t.equipmentNote, style: TextStyle(fontSize: 13.5, height: 1.4, color: c.text2)),
                  const SizedBox(height: 18),
                  EquipmentGroupsList(selected: _selected, onChanged: (s) => setState(() => _selected = s)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: GymButton(label: context.t.cont, onPressed: _continue),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(GymRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.card),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: c.text2),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: c.text2)),
            ],
          ),
        ),
      ),
    );
  }
}
