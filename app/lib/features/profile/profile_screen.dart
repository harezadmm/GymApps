/// Tab Profile — artboard `12 Profile`.
///
/// Pengaturan yang mempengaruhi mesin progresi ada di grup Training paling
/// atas: satuan, rest default, faktor deload. Itu yang paling sering diubah,
/// jadi tidak dikubur di bawah.
library;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/workout_store.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.onSignOut,
    required this.email,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onSignOut;

  /// Email akun yang sedang masuk. null hanya selagi pemeriksaannya berjalan;
  /// sebelumnya di sini ada alamat contoh yang di-hardcode, dan itu berarti
  /// setiap orang melihat email orang lain di layar akunnya sendiri.
  final String? email;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _keepAwake = true;

  /// Versi dibaca dari bundle, bukan ditulis tangan. Nomor yang di-hardcode
  /// pasti basi pada rilis berikutnya, dan laporan bug yang menyebut versi
  /// salah lebih buruk daripada tidak menyebut versi sama sekali.
  late final Future<String> _version =
      PackageInfo.fromPlatform().then((i) => 'v${i.version}+${i.buildNumber}');

  /// Dua huruf pertama dari email, untuk avatar. Bukan nama — aplikasi ini
  /// tidak pernah menanyakannya, dan menebaknya dari alamat akan salah lebih
  /// sering daripada benar.
  static String _initials(String? email) {
    final local = (email ?? '').split('@').first;
    if (local.isEmpty) return '—';
    return local.substring(0, local.length >= 2 ? 2 : 1).toUpperCase();
  }

  void _todo(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t.notWired(what))),
    );
  }

  /// Sinkron sekarang, lalu katakan hasilnya dengan kata-kata — ikon kecil di
  /// kartu akun gampang terlewat, dan orang yang menekan tombol ini sedang
  /// menunggu jawaban.
  Future<void> _forceSync() async {
    final store = WorkoutScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    if (!store.hasBackend) {
      messenger.showSnackBar(SnackBar(content: Text(t.syncOffHint)));
      return;
    }
    await store.syncNow();
    final msg = switch (store.syncStatus) {
      SyncStatus.synced => t.syncedNow,
      SyncStatus.failed => t.syncFailed,
      SyncStatus.noSession => t.syncNoSession,
      SyncStatus.idle || SyncStatus.syncing => t.syncPending,
    };
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Pemilih bahasa: satu sheet, pilihan langsung berlaku.
  ///
  /// Tidak ada tombol "simpan" — menutup sheet setelah memilih sudah cukup,
  /// dan perubahannya terlihat seketika di belakang sheet.
  Future<void> _pickLanguage() async {
    final picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      backgroundColor: context.gym.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(sheet.t.language),
              const SizedBox(height: 10),
              for (final l in AppLanguage.values)
                SelectRow(
                  title: appLanguageLabel[l]!,
                  selected: l == widget.language,
                  onTap: () => Navigator.of(sheet).pop(l),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) widget.onLanguageChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ScreenHeader(title: t.profile),
        GymCard(
          radius: GymRadius.large,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Text(_initials(widget.email),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.accent)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.email ?? '…',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                    const SizedBox(height: 3),
                    // Status sinkron dibaca dari store, bukan dari konstanta
                    // build. Kredensial yang terpasang tidak sama dengan sinkron
                    // yang berhasil, dan bedanya baru ketahuan saat ganti HP —
                    // saat itu sudah terlambat.
                    Builder(builder: (context) {
                      final store = context.workouts;
                      final (label, tone, icon) = switch (store.syncStatus) {
                        _ when !store.hasBackend => (t.syncOff, c.text2, Icons.cloud_off_outlined),
                        SyncStatus.syncing => (t.syncing, c.text2, Icons.cloud_sync_outlined),
                        SyncStatus.synced => (t.syncedNow, c.doneInk, Icons.cloud_done_outlined),
                        SyncStatus.failed => (t.syncFailed, c.warn, Icons.cloud_off_outlined),
                        SyncStatus.idle => (t.syncPending, c.text2, Icons.cloud_queue),
                        SyncStatus.noSession => (t.syncNoSession, c.warn, Icons.cloud_off_outlined),
                      };
                      final syncing = store.hasBackend && store.syncStatus == SyncStatus.syncing;
                      return FadeSwap(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          key: ValueKey(label),
                          children: [
                            if (syncing)
                              SpinIcon(icon, size: 14, color: tone)
                            else
                              Icon(icon, size: 14, color: tone),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(label,
                                  style: TextStyle(
                                      fontSize: 12.5, fontWeight: FontWeight.w600, color: tone)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionLabel(t.training),
        const SizedBox(height: 8),
        SettingsGroup(
          children: [
            SettingsTile(icon: Icons.straighten, label: t.units, value: 'kg', onTap: () => _todo(t.units)),
            SettingsTile(
                icon: Icons.timer_outlined, label: t.defaultRest, value: '90 s', onTap: () => _todo(t.defaultRest)),
            SettingsTile(
                icon: Icons.replay, label: t.restPauseRest, value: '15 s', onTap: () => _todo(t.restPauseRest)),
            SettingsTile(
                icon: Icons.trending_down, label: t.deloadFactor, value: '90%', onTap: () => _todo(t.deloadFactor)),
            SettingsTile(
                icon: Icons.speed, label: t.effortScale, value: t.off, onTap: () => _todo(t.effortScale)),
            SettingsTile(
              icon: Icons.lightbulb_outline,
              label: t.keepScreenAwake,
              trailing: Switch(value: _keepAwake, onChanged: (v) => setState(() => _keepAwake = v)),
            ),
            SettingsTile(
                icon: Icons.calendar_view_week, label: t.weekStartsOn, value: t.monday, onTap: () => _todo(t.weekStartsOn)),
          ],
        ),
        const SizedBox(height: 18),
        SectionLabel(t.gyms),
        const SizedBox(height: 8),
        SettingsGroup(
          children: [
            SettingsTile(icon: Icons.place_outlined, label: 'Gym A', value: t.active, onTap: () => _todo('Gym A')),
            SettingsTile(icon: Icons.place_outlined, label: 'Gym B', onTap: () => _todo('Gym B')),
            SettingsTile(
                icon: Icons.add, label: t.addEquipmentProfile, onTap: () => _todo(t.addEquipmentProfile)),
          ],
        ),
        const SizedBox(height: 18),
        SectionLabel(t.data),
        const SizedBox(height: 8),
        SettingsGroup(
          children: [
            SettingsTile(
                icon: Icons.download_outlined, label: t.exportBackup, onTap: () => _todo(t.exportBackup)),
            SettingsTile(icon: Icons.upload_outlined, label: t.importBackup, onTap: () => _todo(t.importBackup)),
            SettingsTile(
              icon: Icons.sync,
              label: t.forceSync,
              onTap: _forceSync,
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionLabel(t.app),
        const SizedBox(height: 8),
        SettingsGroup(
          children: [
            SettingsTile(icon: Icons.dark_mode_outlined, label: t.theme, value: t.dark, onTap: () => _todo(t.theme)),
            SettingsTile(
              icon: Icons.palette_outlined,
              label: t.accentColour,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 18, height: 18, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 18, color: c.text3),
                ],
              ),
              onTap: () => _todo(t.accentColour),
            ),
            SettingsTile(
              icon: Icons.translate,
              label: t.language,
              value: appLanguageLabel[widget.language]!,
              onTap: _pickLanguage,
            ),
            SettingsTile(
                icon: Icons.info_outline,
                label: t.aboutApp,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<String>(
                      future: _version,
                      // Kosong selagi dibaca, bukan placeholder — angka versi
                      // yang salah sekejap tetap sempat terbaca dan dilaporkan.
                      builder: (context, snap) => Text(snap.data ?? '',
                          style: TextStyle(fontSize: 13.5, color: c.text2)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, size: 18, color: c.text3),
                  ],
                ),
                onTap: () => _todo(t.aboutApp)),
          ],
        ),
        const SizedBox(height: 20),
        Material(
          color: c.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(GymRadius.card),
          child: InkWell(
            onTap: widget.onSignOut,
            borderRadius: BorderRadius.circular(GymRadius.card),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GymRadius.card),
                border: Border.all(color: c.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout, size: 17, color: c.danger),
                  const SizedBox(width: 9),
                  Text(t.logOut,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: c.danger)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
