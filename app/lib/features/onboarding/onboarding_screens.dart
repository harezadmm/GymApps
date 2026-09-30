/// Dua langkah onboarding — artboard `02 Onboarding · Program` dan
/// `03 Onboarding · Equipment`.
///
/// Urutannya: pilih program (template atau susun sendiri) → daftar peralatan →
/// Home. Dua pertanyaan ini yang harus dijawab sebelum aplikasi bisa menyusun
/// sesi pertama, dan keduanya bisa diubah lagi belakangan.
library;

import 'package:flutter/material.dart';
import '../../core/art3d.dart';
import '../../core/gym_icons.dart';
import '../../core/illustration.dart';
import '../../core/motion.dart';

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
            icon: Icon(GymIcons.arrowLeft, size: 22, color: onBack == null ? c.text3 : c.text2),
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
    required this.art,
  });

  final String id;
  final String name;

  /// "3 routines · rotation" — berapa rutinitas dan bagaimana urutannya maju.
  final String rhythm;
  final String detail;

  /// Ikon 3D di kiri kartu. Enam nama template mirip satu sama lain bagi
  /// pemula ("Upper / Lower" vs "Full Body"); benda yang berbeda per kartu
  /// memberi mata jangkar untuk membedakan dan mengingat pilihannya.
  final Gym3d art;
}

/// Template bawaan sesuai tabel spec §5.
const programTemplates = <ProgramTemplate>[
  ProgramTemplate(
    id: 'ppl',
    name: 'Push / Pull / Legs',
    rhythm: '3 routines · rotation',
    detail: 'Balanced volume, 3–6 sessions a week',
    // Split binaraga klasik: dumbel, alat paling umum di ketiga harinya.
    art: Gym3d.dumbbell,
  ),
  ProgramTemplate(
    id: 'upper-lower',
    name: 'Upper / Lower',
    rhythm: '2 routines · rotation',
    detail: 'Simple alternation, good for 4 days',
    // Dua gagang yang bergantian ditekan — dua separuh badan yang bergantian.
    art: Gym3d.grippers,
  ),
  ProgramTemplate(
    id: 'bro-split',
    name: 'Bro split',
    rhythm: '5 routines · Mon–Fri',
    detail: 'One muscle group per day',
    // Satu-satunya template berhari tetap (Senin–Jumat): kalender.
    art: Gym3d.calendar,
  ),
  ProgramTemplate(
    id: 'heavy-duty',
    name: 'Heavy Duty',
    rhythm: '4 routines · rotation',
    detail: '1 working set to failure, 3 rest days',
    // Satu set, seberat mungkin: kettlebell bertulisan KG.
    art: Gym3d.kettlebell,
  ),
  ProgramTemplate(
    id: 'full-body',
    name: 'Full Body',
    rhythm: '1 routine · rotation',
    detail: 'Everything every session',
    // Bola latihan: alat yang melibatkan seluruh badan sekaligus.
    art: Gym3d.exerciseBall,
  ),
  ProgramTemplate(
    id: 'five-by-five',
    name: '5 × 5',
    rhythm: '2 routines · rotation',
    detail: 'Strength focus, linear progression',
    // Progresi linear = menambah piringan tiap sesi.
    art: Gym3d.weightPlates,
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
                  _OutlinedAction(icon: GymIcons.add, label: context.t.buildMyOwn, onTap: widget.onBuildOwn),
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
        // Ketukan di kolom ikon jatuh ke sini, bukan ke SelectRow; getarnya
        // disamakan supaya seluruh kartu terasa satu tombol.
        onTap: () {
          GymHaptics.tap();
          onTap();
        },
        borderRadius: BorderRadius.circular(GymRadius.card),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GymRadius.card),
            border: Border.all(color: selected ? c.accent : c.border),
          ),
          // SelectRow hanya menerima IconData untuk cakram ikonnya, jadi ikon
          // 3D berdiri di kolomnya sendiri; padding kiri 14 sama dengan
          // padding SelectRow, sehingga jarak ikon–judul tetap seimbang.
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Gym3dIcon(template.art, size: 46),
              ),
              Expanded(
                child: SelectRow(
                  title: template.name,
                  subtitle: context.t.catalogue(template.rhythm),
                  detail: context.t.catalogue(template.detail),
                  selected: selected,
                  onTap: onTap,
                ),
              ),
            ],
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
