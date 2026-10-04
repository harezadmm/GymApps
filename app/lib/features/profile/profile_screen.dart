/// Tab Profile — artboard `12 Profile`.
///
/// Pengaturan yang mempengaruhi mesin progresi ada di grup Training paling
/// atas: satuan, rest default, faktor deload. Itu yang paling sering diubah,
/// jadi tidak dikubur di bawah.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/gym_icons.dart';
import '../../domain/units.dart';

import '../../core/keep_awake.dart';
import '../../core/rest_alert.dart';
import '../../core/motion.dart';
import '../../core/strings.dart';
import '../../core/strings_v3.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/synced_account_store.dart';
import '../../data/workout_store.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../../domain/program.dart';
import 'equipment_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.onSignOut,
    required this.email,
    this.onConnect,
    this.onAccentChanged,
    this.themeMode = ThemeMode.dark,
    this.onThemeModeChanged,
    this.asPage = false,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onSignOut;

  /// Dibuka sebagai halaman dorong dari avatar Beranda (UI v3): membawa
  /// Scaffold sendiri dengan tombol kembali, dan Keluar menutup halamannya
  /// lebih dulu supaya tidak ada rute mati di atas layar masuk.
  final bool asPage;

  /// Sambungkan akun ini ke server dengan kata sandinya. null kalau build ini
  /// tidak punya server.
  final Future<ConnectResult> Function(String password)? onConnect;

  final ValueChanged<Color>? onAccentChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  /// Email akun yang sedang masuk. null hanya selagi pemeriksaannya berjalan;
  /// sebelumnya di sini ada alamat contoh yang di-hardcode, dan itu berarti
  /// setiap orang melihat email orang lain di layar akunnya sendiri.
  final String? email;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _keepAwake = true;
  WebRestPush _restPush = WebRestPush.unavailable;

  /// Tema yang sedang dipilih. Dipegang lokal karena sebagai halaman dorong
  /// widget ini tidak dibangun ulang saat akar aplikasi berganti tema.
  late ThemeMode _themeMode = widget.themeMode;

  void _signOut() {
    if (widget.asPage) Navigator.of(context).pop();
    widget.onSignOut();
  }

  @override
  void initState() {
    super.initState();
    KeepAwake.enabled.then((v) {
      if (mounted) setState(() => _keepAwake = v);
    });
    if (kIsWeb) {
      RestAlert.webState().then((v) {
        if (mounted) setState(() => _restPush = v);
      });
    }
  }

  /// Dipanggil langsung dari ketukan: iPhone hanya mau menampilkan dialog izin
  /// selama ketukan itu masih berlangsung, jadi tidak ada `await` sebelum
  /// [RestAlert.enableWeb].
  void _toggleRestPush() {
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    switch (_restPush) {
      case WebRestPush.needsHomeScreen:
        messenger.showSnackBar(SnackBar(content: Text(t.restPushHowTo), duration: const Duration(seconds: 8)));
      case WebRestPush.blocked:
        messenger.showSnackBar(SnackBar(content: Text(t.restPushBlockedHow), duration: const Duration(seconds: 6)));
      case WebRestPush.on:
        RestAlert.disableWeb().then((v) {
          if (mounted) setState(() => _restPush = v);
        });
      case WebRestPush.off:
        RestAlert.enableWeb().then((v) {
          if (!mounted) return;
          setState(() => _restPush = v);
          if (v == WebRestPush.on) messenger.showSnackBar(SnackBar(content: Text(t.restPushEnabled)));
          if (v == WebRestPush.blocked) messenger.showSnackBar(SnackBar(content: Text(t.restPushBlockedHow)));
        });
      case WebRestPush.unavailable:
        break;
    }
  }

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

  /// Pemilih satu nilai dari daftar, dalam sheet. null kalau ditutup.
  Future<T?> _pick<T>(String title, List<(T, String)> options, T current) => showModalBottomSheet<T>(
        context: context,
        backgroundColor: context.gym.bg,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet)),
        ),
        builder: (sheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 10),
                for (final (v, label) in options)
                  SelectRow(title: label, selected: v == current, onTap: () => Navigator.of(sheet).pop(v)),
              ],
            ),
          ),
        ),
      );

  Future<void> _pickDefaultRest() async {
    final store = WorkoutScope.read(context);
    final s = store.settings;
    final v = await _pick(context.t.defaultRest, [
      for (final sec in [45, 60, 90, 120, 150, 180, 240, 300]) (sec, _restText(sec)),
    ], s.defaultRestSeconds);
    if (v != null) await store.updateSettings(s.copyWith(defaultRestSeconds: v));
  }

  Future<void> _pickDeload() async {
    final store = WorkoutScope.read(context);
    final s = store.settings;
    final v = await _pick(context.t.deloadFactor, [
      for (final f in [0.8, 0.85, 0.9, 0.95]) (f, '${(f * 100).round()}%'),
    ], s.deloadFactor);
    if (v != null) await store.updateSettings(s.copyWith(deloadFactor: v));
  }

  Future<void> _pickWeekStart() async {
    final store = WorkoutScope.read(context);
    final s = store.settings;
    final t = context.t;
    final v = await _pick(t.weekStartsOn, [
      for (final d in [DateTime.monday, DateTime.saturday, DateTime.sunday]) (d, t.weekdayLong(d)),
    ], s.weekStartsOn);
    if (v != null) await store.updateSettings(s.copyWith(weekStartsOn: v));
  }

  Future<void> _pickUnit() async {
    final store = WorkoutScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    final s = store.settings;
    final v = await _pick(t.unitsTitle, [(WeightUnit.kg, 'kg'), (WeightUnit.lb, 'lb')], s.unit);
    if (v == null || v == s.unit) return;
    await store.updateSettings(s.copyWith(unit: v));
    messenger.showSnackBar(SnackBar(content: Text(t.unitsNote)));
  }

  Future<void> _pickTheme() async {
    final onChanged = widget.onThemeModeChanged;
    if (onChanged == null) return;
    final t = context.t;
    final v = await _pick(t.themeTitle, [
      (ThemeMode.dark, t.themeDark),
      (ThemeMode.light, t.themeLight),
      (ThemeMode.system, t.themeSystem),
    ], _themeMode);
    if (v == null) return;
    setState(() => _themeMode = v);
    onChanged(v);
  }

  Future<void> _pickAccent() async {
    final onChanged = widget.onAccentChanged;
    if (onChanged == null) return;
    final t = context.t;
    // Urutannya harus sama dengan accentChoices: violet dulu.
    final names = [t.accentViolet, t.accentBlue, t.accentGreen, t.accentOrange, t.accentPink];
    // Di tema terang aksen yang tampil sudah digelapkan; yang dicocokkan
    // pilihan aslinya.
    final current = context.gym.accentBase ?? context.gym.accent;
    final v = await _pick(t.accentColour, [
      for (final (i, color) in accentChoices.indexed) (color, names[i]),
    ], accentChoices.firstWhere((a) => a.toARGB32() == current.toARGB32(), orElse: () => accentChoices.first));
    if (v != null) onChanged(v);
  }

  static String _restText(int sec) => sec % 60 == 0 ? '${sec ~/ 60} min' : '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

  /// Ekspor seluruh data akun sebagai JSON — bentuk yang sama dengan dokumen
  /// yang disinkronkan, jadi bisa diimpor lagi di akun mana pun.
  Future<void> _export() async {
    final store = WorkoutScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    final doc = {...store.toDocument(), 'exportedAt': DateTime.now().toIso8601String()};
    final bytes = utf8.encode(const JsonEncoder.withIndent(' ').convert(doc));
    final name = 'gymapps-backup-${isoDate(DateTime.now())}.json';
    // Dialog "simpan ke" milik sistem, bukan lembar bagikan: bagikan butuh
    // aplikasi lain yang mau menerima JSON, dan di HP tanpa aplikasi itu
    // ekspornya buntu. Di web ini jadi unduhan biasa.
    try {
      final saved = await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: 'application/json');
      if (saved != null || kIsWeb) messenger.showSnackBar(SnackBar(content: Text(t.exportSaved(name))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.exportFailed)));
    }
  }

  Future<void> _import() async {
    final store = WorkoutScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
    if (files.isEmpty || !mounted) return;
    Map<String, dynamic> doc;
    try {
      final raw = utf8.decode(await files.first.readAsBytes());
      doc = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (doc['workouts'] is! List) throw const FormatException('bukan cadangan');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.importFailed)));
      return;
    }
    if (!mounted) return;
    final c = context.gym;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(t.importConfirmTitle),
        content: Text(t.importConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.cancel)),
          GymButton(label: t.importAction, height: 42, expand: false, onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (ok != true) return;
    final added = await store.importDocument(doc);
    messenger.showSnackBar(SnackBar(content: Text(t.importDone(added))));
  }

  Future<void> _about() async {
    final version = await _version;
    if (!mounted) return;
    final t = context.t;
    showAboutDialog(
      context: context,
      applicationName: 'GymApps',
      applicationVersion: version,
      children: [Text(t.aboutBody)],
    );
  }

  /// Sinkron sekarang, lalu katakan hasilnya dengan kata-kata — ikon kecil di
  /// kartu akun gampang terlewat, dan orang yang menekan tombol ini sedang
  /// menunggu jawaban.
  bool _forceSyncing = false;

  Future<void> _forceSync() async {
    // Satu saja sekaligus. Ketukan kedua selagi menyambung dulu membuka dialog
    // kata sandi kedua dan menyambung dua kali.
    if (_forceSyncing) return;
    _forceSyncing = true;
    try {
      await _runForceSync();
    } finally {
      _forceSyncing = false;
    }
  }

  /// Jalankan [work] di balik dialog tunggu yang tidak bisa ditutup. Selama
  /// menyambung, tombol keluar dan Force sync tidak boleh bisa diketuk.
  Future<T> _withProgress<T>(Future<T> Function() work) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final label = context.t.connecting;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: context.gym.surface,
          content: Row(
            children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 16),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    ));
    try {
      return await work();
    } finally {
      navigator.pop();
    }
  }

  Future<void> _runForceSync() async {
    final store = WorkoutScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    if (!store.hasBackend) {
      messenger.showSnackBar(SnackBar(content: Text(t.syncOffHint)));
      return;
    }
    await store.syncNow();
    if (!mounted) return;
    // Belum ada sesi server: minta kata sandi sekali, sambungkan, lalu coba
    // lagi. Ini jalan yang ditempuh HP yang masuk sebelum build ini punya
    // server — tanpa ini orangnya harus keluar lalu masuk lagi.
    final onConnect = widget.onConnect;
    if (store.syncStatus == SyncStatus.noSession && onConnect != null && mounted) {
      final password = await _askPassword();
      if (password == null || !mounted) return;
      // Hanya menyambung yang ditunggu di balik dialog — waktunya dibatasi.
      // Sinkron sesudahnya berjalan dengan penanda biasa di kartu akun.
      final result = await _withProgress(() => onConnect(password));
      if (!mounted) return;
      switch (result) {
        case ConnectResult.wrongPassword:
          messenger.showSnackBar(SnackBar(content: Text(t.wrongPassword)));
          return;
        case ConnectResult.rejected:
          messenger.showSnackBar(SnackBar(content: Text(t.serverRejected)));
          return;
        case ConnectResult.unreachable:
          messenger.showSnackBar(SnackBar(content: Text(t.serverUnreachable)));
          return;
        case ConnectResult.connected:
          await store.syncNow();
          if (!mounted) return;
      }
    }
    final msg = switch (store.syncStatus) {
      SyncStatus.synced => t.syncedNow,
      SyncStatus.failed => t.syncFailed,
      SyncStatus.noSession => t.syncNoSession,
      SyncStatus.idle || SyncStatus.syncing => t.syncPending,
    };
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> _askPassword() async {
    final password = await showDialog<String>(context: context, builder: (_) => const _PasswordDialog());
    return password == null || password.isEmpty ? null : password;
  }

  /// Pemilih bahasa: satu sheet, pilihan langsung berlaku.
  ///
  /// Tidak ada tombol "simpan" — menutup sheet setelah memilih sudah cukup,
  /// dan perubahannya terlihat seketika di belakang sheet.
  Future<void> _pickLanguage() async {
    final picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      backgroundColor: context.gym.bg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GymRadius.sheet)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(sheet.t.language, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 10),
              for (final l in AppLanguage.values)
                SelectRow(
                  title: appLanguageLabel[l]!,
                  // Dari strings yang aktif, bukan widget.language: sebagai
                  // halaman dorong, nilai yang dibawa tidak ikut berganti.
                  selected: l == sheet.t.lang,
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
    final store = context.workouts;
    final settings = store.settings;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (widget.asPage)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
            child: Row(
              children: [
                GlassIconButton(icon: GymIcons.arrowLeft, tooltip: t.back, onPressed: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: Text(t.profileNav,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                ),
                const SizedBox(width: 44),
              ],
            ),
          )
        else
          ScreenHeader(title: t.profile),
        // Kartu akun dulu, lalu tiap grup setelan menyusul bertingkat —
        // urutan yang sama dengan urutan bacanya.
        Reveal(child: _AccountCard(email: widget.email, initials: _initials(widget.email))),
        const SizedBox(height: 18),
        SectionLabel(t.groupTraining),
        const SizedBox(height: 8),
        Reveal(
          index: 1,
          child: SettingsGroup(
            children: [
              SettingsTile(icon: GymIcons.scale, label: t.weightUnitRow, value: settings.unit.label, onTap: _pickUnit),
              SettingsTile(
                icon: GymIcons.alarm,
                label: t.defaultRest,
                value: _restText(settings.defaultRestSeconds),
                onTap: _pickDefaultRest,
              ),
              SettingsTile(
                icon: GymIcons.arrowDownRight,
                label: t.deloadFactor,
                value: '${(settings.deloadFactor * 100).round()}%',
                onTap: _pickDeload,
              ),
              SettingsTile(
                icon: GymIcons.menu,
                label: t.logRirRow,
                trailing: Switch(
                  value: settings.logRir,
                  onChanged: (v) => store.updateSettings(settings.copyWith(logRir: v)),
                ),
              ),
              SettingsTile(
                icon: GymIcons.eye,
                label: t.keepScreenAwake,
                trailing: Switch(
                  value: _keepAwake,
                  onChanged: (v) {
                    setState(() => _keepAwake = v);
                    KeepAwake.set(v);
                  },
                ),
              ),
              if (kIsWeb && _restPush != WebRestPush.unavailable)
                SettingsTile(
                  icon: GymIcons.bell,
                  label: t.restPushRow,
                  value: switch (_restPush) {
                    WebRestPush.on => t.restPushOn,
                    WebRestPush.blocked => t.restPushBlocked,
                    WebRestPush.needsHomeScreen => t.restPushNeedsHome,
                    _ => t.restPushOff,
                  },
                  onTap: _toggleRestPush,
                ),
              SettingsTile(
                icon: GymIcons.calendar,
                label: t.weekStartsRow,
                value: t.weekdayLong(settings.weekStartsOn),
                onTap: _pickWeekStart,
              ),
              SettingsTile(
                icon: GymIcons.dumbbell,
                label: t.myEquipmentOnly,
                value: settings.equipment == null ? t.equipmentAll : t.equipmentCount(settings.equipment!.length),
                onTap: () => editEquipment(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionLabel(t.groupAppearance),
        const SizedBox(height: 8),
        Reveal(
          index: 2,
          child: SettingsGroup(
            children: [
              if (widget.onThemeModeChanged != null)
                SettingsTile(
                  icon: GymIcons.moon,
                  label: t.themeTitle,
                  value: switch (_themeMode) {
                    ThemeMode.light => t.themeLight,
                    ThemeMode.system => t.themeSystem,
                    ThemeMode.dark => t.themeDark,
                  },
                  onTap: _pickTheme,
                ),
              SettingsTile(
                icon: GymIcons.settings,
                label: t.accentColour,
                // Lima titik langsung di baris: ketuk titik = pilih. Ketuk
                // barisnya membuka lembar bernama — untuk pembaca layar dan
                // untuk yang ingin tahu nama warnanya.
                trailing: _AccentDots(onPick: widget.onAccentChanged),
                onTap: widget.onAccentChanged == null ? null : _pickAccent,
              ),
              SettingsTile(
                icon: GymIcons.globe,
                label: t.language,
                value: appLanguageLabel[t.lang]!,
                onTap: _pickLanguage,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionLabel(t.groupDataAccount),
        const SizedBox(height: 8),
        Reveal(
          index: 3,
          child: SettingsGroup(
            children: [
              SettingsTile(icon: GymIcons.sync, label: t.forceSyncRow, onTap: _forceSync),
              SettingsTile(icon: GymIcons.download, label: t.exportBackup, onTap: _export),
              SettingsTile(icon: GymIcons.dataTransfer, label: t.importBackup, onTap: _import),
              SettingsTile(
                icon: GymIcons.info,
                label: t.aboutRow,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<String>(
                      future: _version,
                      // Kosong selagi dibaca, bukan placeholder — angka versi
                      // yang salah sekejap tetap sempat terbaca dan dilaporkan.
                      builder: (context, snap) => Text(snap.data ?? '', style: TextStyle(fontSize: 13.5, color: c.text2)),
                    ),
                    const SizedBox(width: 10),
                    Icon(GymIcons.chevronRight, size: 16, color: c.text3),
                  ],
                ),
                onTap: _about,
              ),
              // Keluar jadi baris terakhir grup ini, bukan tombol besar: ia
              // tindakan akun seperti yang lain, hanya berwarna peringatan.
              SettingsTile(
                icon: GymIcons.logout,
                label: t.logOutRow,
                tone: c.danger,
                trailing: const SizedBox.shrink(),
                onTap: _signOut,
              ),
            ],
          ),
        ),
      ],
    );
    if (!widget.asPage) return list;
    return Scaffold(backgroundColor: c.bg, body: SafeArea(child: list));
  }
}

/// Kartu akun: avatar inisial, email, dan satu baris status sinkron dengan
/// titik warna — dibaca dari store, bukan dari konstanta build. Kredensial
/// yang terpasang tidak sama dengan sinkron yang berhasil, dan bedanya baru
/// ketahuan saat ganti HP — saat itu sudah terlambat.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.email, required this.initials});

  final String? email;
  final String initials;

  /// "2 menit lalu" dari waktu sinkron terakhir; kosong kalau belum pernah.
  static String _ago(Strings t, DateTime? at) {
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return t.justNow;
    if (d.inHours < 1) return t.minutesAgo(d.inMinutes);
    if (d.inDays < 1) return t.hoursAgo(d.inHours);
    return t.daysAgoShort(d.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final store = context.workouts;
    final (title, sub, dot) = switch (store.syncStatus) {
      _ when !store.hasBackend => (t.syncNoServerPill, '', c.text3),
      SyncStatus.syncing => (t.syncing, '', c.text3),
      SyncStatus.synced => (t.syncedPill, _ago(t, store.lastSyncedAt), c.doneInk),
      SyncStatus.failed => (t.syncNotYet, t.syncFailed, c.warn),
      SyncStatus.noSession => (t.syncNotYet, t.syncNoSession, c.warn),
      SyncStatus.idle => (t.syncNotYet, _ago(t, store.lastSyncedAt), c.text3),
    };
    final line = sub.isEmpty ? title : '$title · $sub';
    return GymCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Reveal(scale: true, slide: false, child: AvatarCircle(text: initials, size: 52)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email ?? '…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 4),
                FadeSwap(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    key: ValueKey(line),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(line,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, height: 1.35, color: c.text2)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lima titik warna aksen 18 dp; yang terpilih bergaris `text` 2 dp. Sasaran
/// ketuknya 32×44 dp per titik — titiknya sendiri terlalu kecil untuk jari.
class _AccentDots extends StatelessWidget {
  const _AccentDots({required this.onPick});

  final ValueChanged<Color>? onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    // Di tema terang aksen yang tampil sudah digelapkan; yang dicocokkan
    // pilihan aslinya.
    final current = (c.accentBase ?? c.accent).toARGB32();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, color) in accentChoices.indexed) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPick == null ? null : () => onPick!(color),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
              child: Container(
                key: ValueKey('accent-dot-$i'),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: color.toARGB32() == current ? Border.all(color: c.text, width: 2) : null,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}


/// Dialog kata sandi untuk menyambung ke server.
///
/// Widget sendiri karena controller-nya harus hidup sampai dialog benar-benar
/// hilang. Dibuang tepat setelah `showDialog` kembali, TextField di animasi
/// tutupnya masih memakainya — layar merah di build debug.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GymRadius.large)),
      title: Text(t.connectTitle, style: Theme.of(context).textTheme.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.connectBody, style: TextStyle(fontSize: 13.5, height: 1.45, color: c.text2)),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: t.password),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
        ),
        GymButton(label: t.connect, height: 42, expand: false, onPressed: _submit),
      ],
    );
  }
}
