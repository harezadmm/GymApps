/// Profil gym di Profil, Home, dan pembuka sesi (FR-C3, FR-C4).
///
/// Satu tempat untuk semua yang menyentuh daftar gym: bagian "Gym" di Profil
/// (aktifkan, tambah, ganti nama, hapus, alat), sheet ringkas memilih gym
/// saat sesi dibuka, dan chip kecil bertuliskan gym aktif. Chip dan sheet
/// hanya ada kalau gym-nya lebih dari satu — akun satu gym tidak melihat satu
/// pun dari ini, karena tidak ada yang perlu dibedakan.
library;

import 'package:flutter/material.dart';

import '../../core/gym_icons.dart';
import '../../core/strings.dart';
import '../../core/strings_gym.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import '../../domain/settings.dart';
import 'equipment_picker.dart';

/// Ikon profil gym. Font GymIcons tidak punya glyph "tempat", jadi Material
/// varian outlined yang dipakai — aturan yang sama dengan ikon lain di luar
/// font.
const gymIcon = Icons.place_outlined;

String _equipmentSummary(Strings t, GymProfile g) =>
    g.equipment == null ? t.equipmentAll : t.equipmentCount(g.equipment!.length);

/// Chip kecil bertuliskan nama gym. Kosong kalau gym-nya cuma satu, atau
/// [gymId] menunjuk gym yang sudah tidak ada.
///
/// [gymId] null = gym aktif. Dengan [onTap], chip bisa diketuk (ganti gym di
/// Home) dan area sentuhnya 44 dp walau kapsulnya lebih kecil (NFR-11);
/// tanpa [onTap] ia sekadar penanda, dan [dense] membuatnya lebih pendek
/// supaya bilah atas sesi tidak bertambah tinggi.
class GymChip extends StatelessWidget {
  const GymChip({super.key, this.gymId, this.onTap, this.dense = false});

  final String? gymId;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    // Ikut berlangganan store kalau ada, tapi tidak menuntutnya: layar sesi
    // dan ringkasan juga dipasang sendirian di test, tanpa WorkoutScope.
    final s = context.dependOnInheritedWidgetOfExactType<WorkoutScope>()?.notifier?.settings;
    if (s == null || s.gyms.length < 2) return const SizedBox.shrink();
    final g = gymId == null ? s.activeGym : s.gymById(gymId!);
    if (g == null) return const SizedBox.shrink();
    final c = context.gym;
    final t = context.t;
    final name = t.gymName(g);
    // Aksen di atas accentSoft: pasangan yang sama dengan kapsul istirahat di
    // bilah sesi dan pil "hari ini" di Home.
    final capsule = Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: dense ? 2 : 6),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(GymRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(gymIcon, size: dense ? 12 : 14, color: c.accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: dense ? 11.5 : 12, fontWeight: FontWeight.w700, color: c.accent),
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) {
      return Semantics(
        label: t.gymLabel(name),
        excludeSemantics: true,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 170), child: capsule),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 170),
      child: Semantics(
        button: true,
        label: t.activeGymLabel(name),
        hint: t.switchGym,
        excludeSemantics: true,
        child: Tooltip(
          message: t.switchGym,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: tap,
              borderRadius: BorderRadius.circular(GymRadius.pill),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(widthFactor: 1, child: capsule),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet ringkas memilih gym. Pilihannya langsung jadi gym aktif — dipakai
/// pembuka sesi (sesi dicatat di gym itu) dan chip di Home. Mengembalikan
/// gym yang dipilih; null kalau sheet ditutup tanpa memilih.
Future<GymProfile?> pickGym(BuildContext context) async {
  final store = WorkoutScope.read(context);
  final s = store.settings;
  final picked = await showModalBottomSheet<GymProfile>(
    context: context,
    backgroundColor: context.gym.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet)),
    ),
    builder: (sheet) {
      final c = sheet.gym;
      final t = sheet.t;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.chooseGymTitle, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(t.chooseGymNote, style: TextStyle(fontSize: 13, height: 1.4, color: c.text2)),
              const SizedBox(height: 10),
              SettingsGroup(
                children: [
                  for (final g in s.gyms)
                    SelectRow(
                      title: t.gymName(g),
                      icon: gymIcon,
                      detail: _equipmentSummary(t, g),
                      selected: g.id == s.activeGymId,
                      onTap: () => Navigator.of(sheet).pop(g),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  if (picked == null) return null;
  if (picked.id != store.settings.activeGymId) {
    await store.updateSettings(store.settings.withActiveGym(picked.id));
  }
  return picked;
}

/// Gym tempat sesi yang akan dibuka dicatat. Satu gym: langsung, tanpa
/// bertanya — akun satu gym tidak boleh mendapat satu langkah tambahan
/// setiap kali mulai latihan. Lebih dari satu: [pickGym]; null berarti sheet
/// ditutup, dan sesinya tidak jadi dibuka.
Future<GymProfile?> gymForNewSession(BuildContext context) {
  final s = WorkoutScope.read(context).settings;
  if (s.gyms.length < 2) return Future.value(s.activeGym);
  return pickGym(context);
}

enum _GymAction { equipment, rename, delete }

/// Bagian "Gym" di Profil: daftar profil dengan yang aktif ditandai.
///
/// Ketuk baris = jadikan aktif. Tombol ⋯ membuka aksi lainnya — alat di gym
/// itu, ganti nama, hapus — di sheet yang bentuknya sama dengan pemilih lain
/// di Profil. Hapus tidak ditawarkan untuk gym terakhir: daftar kosong tidak
/// punya arti, dan setelan sendiri menolaknya ([TrainingSettings.withoutGym]).
class GymSection extends StatelessWidget {
  const GymSection({super.key});

  Future<void> _options(BuildContext context, GymProfile g) async {
    final store = WorkoutScope.read(context);
    final canDelete = store.settings.gyms.length > 1;
    final action = await showModalBottomSheet<_GymAction>(
      context: context,
      backgroundColor: context.gym.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet)),
      ),
      builder: (sheet) {
        final c = sheet.gym;
        final t = sheet.t;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel(t.gymName(g)),
                const SizedBox(height: 10),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: GymIcons.dumbbell,
                      hue: c.hues.cyan,
                      label: t.equipmentAtThisGym,
                      value: _equipmentSummary(t, g),
                      onTap: () => Navigator.of(sheet).pop(_GymAction.equipment),
                    ),
                    SettingsTile(
                      icon: GymIcons.edit,
                      hue: c.hues.violet,
                      label: t.renameGym,
                      onTap: () => Navigator.of(sheet).pop(_GymAction.rename),
                    ),
                    if (canDelete)
                      SettingsTile(
                        icon: GymIcons.trash,
                        tone: c.danger,
                        label: t.deleteGym,
                        onTap: () => Navigator.of(sheet).pop(_GymAction.delete),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _GymAction.equipment:
        await editEquipment(context, gymId: g.id);
      case _GymAction.rename:
        await _rename(context, g);
      case _GymAction.delete:
        await _delete(context, g);
    }
  }

  Future<void> _add(BuildContext context) async {
    final store = WorkoutScope.read(context);
    final title = context.t.newGymTitle;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _GymNameDialog(title: title, initial: ''),
    );
    final clean = name?.trim() ?? '';
    if (clean.isEmpty) return;
    // Gym baru mulai tanpa batasan alat, dan tidak langsung jadi aktif:
    // yang menambah "Gym B" dari sofa belum tentu sedang di sana.
    await store.updateSettings(store.settings.withGym(GymProfile(id: WorkoutStore.newGymId(), name: clean)));
  }

  Future<void> _rename(BuildContext context, GymProfile g) async {
    final store = WorkoutScope.read(context);
    final t = context.t;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _GymNameDialog(title: t.renameGym, initial: t.gymName(g)),
    );
    final clean = name?.trim() ?? '';
    if (clean.isEmpty) return;
    // Nama bawaan yang disimpan apa adanya berhenti jadi dua bahasa; kalau
    // memang tidak diganti, biarkan tetap kosong.
    if (g.name.isEmpty && clean == t.defaultGymName) return;
    // Dibaca ulang dari store: sinkron bisa mengganti profilnya selagi dialog
    // terbuka, dan nama baru tidak boleh menimpa daftar alat yang baru datang.
    final fresh = store.settings.gymById(g.id);
    if (fresh == null) return;
    await store.updateSettings(store.settings.withGym(fresh.copyWith(name: clean)));
  }

  Future<void> _delete(BuildContext context, GymProfile g) async {
    final store = WorkoutScope.read(context);
    final t = context.t;
    final c = context.gym;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
        title: Text(t.deleteGymTitle(t.gymName(g)), style: Theme.of(dialog).textTheme.titleLarge),
        // Katakan apa yang hilang dan apa yang tidak — sesi yang sudah
        // tercatat adalah fakta, seperti dialog hapus rutinitas.
        content: Text(t.deleteGymBody, style: TextStyle(fontSize: 13.5, height: 1.45, color: c.text2)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
          ),
          GymButton(
            label: t.delete,
            tone: GymButtonTone.danger,
            height: 42,
            expand: false,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.updateSettings(store.settings.withoutGym(g.id));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.workouts;
    final s = store.settings;
    final c = context.gym;
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroup(
          children: [
            for (final g in s.gyms)
              SelectRow(
                title: t.gymName(g),
                icon: gymIcon,
                selected: g.id == s.activeGymId,
                subtitle: g.id == s.activeGymId ? t.currentlyActive : null,
                detail: _equipmentSummary(t, g),
                trailing: IconButton(
                  onPressed: () => _options(context, g),
                  icon: Icon(GymIcons.moreVertical, size: 20, color: c.text2),
                  tooltip: t.gymOptions,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                onTap: () {
                  if (g.id != s.activeGymId) store.updateSettings(s.withActiveGym(g.id));
                },
              ),
            SettingsTile(icon: GymIcons.plus, hue: c.hues.green, label: t.addGym, onTap: () => _add(context)),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(t.gymSectionNote, style: TextStyle(fontSize: 12.5, height: 1.4, color: c.text2)),
        ),
      ],
    );
  }
}

/// Dialog nama gym — bentuk yang sama dengan dialog nama rutinitas di tab
/// Workout. Widget sendiri karena controller-nya harus hidup sampai dialog
/// benar-benar hilang (lihat `_PasswordDialog` di Profil).
class _GymNameDialog extends StatefulWidget {
  const _GymNameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_GymNameDialog> createState() => _GymNameDialogState();
}

class _GymNameDialogState extends State<_GymNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    OutlineInputBorder border(Color colour) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(GymRadius.control),
          borderSide: BorderSide(color: colour),
        );

    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
      title: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        style: TextStyle(fontSize: 15, color: c.text),
        decoration: InputDecoration(
          hintText: context.t.gymNameHint,
          hintStyle: TextStyle(fontSize: 15, color: c.text2),
          filled: true,
          fillColor: c.bgNested,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: border(c.border),
          enabledBorder: border(c.border),
          focusedBorder: border(c.accent),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
        ),
        GymButton(label: context.t.save, height: 42, expand: false, onPressed: _submit),
      ],
    );
  }
}
