/// Pemilih kelompok alat di gym — menyaring library gerakan (FR-C3, FR-C4).
///
/// Dulu onboarding menanyakan alat lalu membuang jawabannya, dan Profil
/// menampilkan "Gym A · aktif / Gym B" yang tidak pernah ada. Sekarang satu
/// daftar kelompok yang dipetakan ke alat di katalog, disimpan di setelan
/// akun, dan dipakai library.
library;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/settings.dart';

/// Daftar kelompok alat dengan kotak centang.
class EquipmentGroupsList extends StatelessWidget {
  const EquipmentGroupsList({super.key, required this.selected, required this.onChanged});

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return SettingsGroup(
      children: [
        for (final key in equipmentGroups.keys)
          SelectRow(
            title: t.equipmentGroup(key),
            selected: selected.contains(key),
            square: true,
            dimWhenOff: true,
            onTap: () {
              final next = {...selected};
              next.contains(key) ? next.remove(key) : next.add(key);
              onChanged(next);
            },
          ),
      ],
    );
  }
}

/// Buka lembar pemilih alat dari Profil. Perubahan langsung disimpan.
Future<void> editEquipment(BuildContext context) {
  final store = WorkoutScope.read(context);
  var selected = {...(store.settings.equipment ?? equipmentGroups.keys)};
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.gym.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet))),
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setState) {
        final c = sheet.gym;
        final t = sheet.t;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          builder: (_, scroll) => SafeArea(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(t.myEquipment, style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(t.equipmentNote, style: TextStyle(fontSize: 13, color: c.text2)),
                const SizedBox(height: 12),
                EquipmentGroupsList(
                  selected: selected,
                  onChanged: (next) {
                    setState(() => selected = next);
                    store.updateSettings(store.settings.copyWith(equipment: next.toList()));
                  },
                ),
                const SizedBox(height: 12),
                GymButton(
                  label: t.equipmentAll,
                  tone: GymButtonTone.neutral,
                  height: 44,
                  onPressed: () {
                    setState(() => selected = {...equipmentGroups.keys});
                    store.updateSettings(store.settings.copyWith(clearEquipment: true));
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
