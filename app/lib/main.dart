import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'core/gym_icons.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/layout.dart';
import 'core/motion.dart';
import 'core/rest_alert.dart';
import 'core/safe_area_stub.dart' if (dart.library.js_interop) 'core/safe_area_web.dart';
import 'core/strings.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'data/account_store.dart';
import 'data/backend.dart';
import 'data/password_reset.dart';
import 'data/synced_account_store.dart';
import 'data/web_account_store.dart';
import 'data/workout_store.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screens.dart';
import 'features/onboarding/program_flow.dart';
import 'features/profile/profile_screen.dart';
import 'features/session/session_launcher.dart';
import 'features/stats/stats_screen.dart';
import 'features/workout/workout_screen.dart';

/// Diisi saat build:
///   flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…
///
/// Publishable (anon) key aman berada di klien — RLS yang menjaga data (NFR-6). Service key
/// tidak pernah masuk ke sini.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get supabaseConfigured => _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

/// Halaman dibuka dari link reset kata sandi. Dibaca sebelum Supabase
/// memproses (dan membersihkan) alamatnya.
bool _pendingPasswordRecovery = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Aplikasi harus tetap jalan tanpa kredensial: seluruh logging bersifat
  // offline-first (FR-A3), dan sebuah build tanpa Supabase masih berguna untuk
  // meninjau UI. Yang hilang hanya sinkronnya.
  if (kIsWeb) {
    final u = Uri.base;
    _pendingPasswordRecovery = u.fragment.contains('type=recovery') || u.queryParameters['type'] == 'recovery';
  }
  if (supabaseConfigured) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    // Server alarm istirahat (web) hanya melayani akun yang sedang masuk.
    RestAlert.webAccessToken = () async {
      final auth = Supabase.instance.client.auth;
      final session = auth.currentSession;
      if (session == null) return null;
      if (!session.isExpired) return session.accessToken;
      try {
        return (await auth.refreshSession()).session?.accessToken;
      } catch (e) {
        debugPrint('refresh sesi untuk alarm: $e');
        return null;
      }
    };
  }

  // Setelan perangkat dibaca sebelum bingkai pertama, supaya aplikasi tidak
  // sempat tampil dalam bahasa Inggris lalu berkedip ke bahasa Indonesia.
  final prefs = await SharedPreferences.getInstance();
  final lang = prefs.getString(_kLang) == 'id' ? AppLanguage.indonesian : AppLanguage.english;
  final accent = prefs.getInt(_kAccent);
  final themeMode = parseThemeMode(prefs.getString(_kTheme));
  await RestAlert.init();

  runApp(GymApp(
    initialLanguage: lang,
    initialAccent: accent == null ? null : Color(accent),
    initialThemeMode: themeMode,
  ));
}

const _kLang = 'settings.lang';
const _kAccent = 'settings.accent';
const _kTheme = 'settings.theme';

/// Gelap tetap bawaan: aplikasi ini dirancang gelap dulu, dan orang yang sudah
/// memakainya tidak boleh tiba-tiba mendapat layar putih setelah update.
ThemeMode parseThemeMode(String? v) => switch (v) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

class GymApp extends StatefulWidget {
  const GymApp({
    super.key,
    this.initialLanguage = AppLanguage.english,
    this.initialAccent,
    this.initialThemeMode = ThemeMode.dark,
  });

  final AppLanguage initialLanguage;
  final Color? initialAccent;
  final ThemeMode initialThemeMode;

  @override
  State<GymApp> createState() => _GymAppState();
}

class _GymAppState extends State<GymApp> with WidgetsBindingObserver {
  /// Bahasa dipegang di akar supaya satu setState memperbarui seluruh aplikasi,
  /// dan disimpan sebagai setelan perangkat — dulu kembali ke Inggris setiap
  /// kali aplikasi dibuka.
  late AppLanguage _lang = widget.initialLanguage;
  late Color? _accent = widget.initialAccent;
  late ThemeMode _themeMode = widget.initialThemeMode;

  Future<void> _setLanguage(AppLanguage l) async {
    setState(() => _lang = l);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, l == AppLanguage.indonesian ? 'id' : 'en');
  }

  Future<void> _setAccent(Color c) async {
    setState(() => _accent = c);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccent, c.toARGB32());
  }

  Future<void> _setThemeMode(ThemeMode m) async {
    setState(() => _themeMode = m);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, m.name);
  }

  /// Satu store untuk seluruh aplikasi, dibuat di akar supaya riwayatnya tidak
  /// ikut dibuang saat tab berpindah atau layar sesi ditutup.
  ///
  /// Backend dipasang hanya kalau kredensialnya ada saat build. Tanpa itu store
  /// tetap bekerja penuh secara lokal — yang hilang cuma sinkron antar perangkat.
  late final WorkoutStore _store =
      WorkoutStore(supabaseConfigured ? SupabaseBackend(Supabase.instance.client) : null);

  // Store tidak dimuat di sini. Dokumennya milik satu akun, dan akun mana
  // yang masuk baru diketahui AppFlow — lihat `_enter`.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Kembali ke aplikasi = sinkron. Sesi yang dicatat di HP lain sementara
  /// aplikasi ini di belakang ikut tertarik, dan dorongan yang gagal karena
  /// sinyal hilang dicoba lagi tanpa menunggu latihan berikutnya.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _store.syncNow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WorkoutScope(
      store: _store,
      child: AppStrings(
        strings: Strings(_lang),
        child: MaterialApp(
          title: 'GymApps',
          debugShowCheckedModeBanner: false,
          theme: buildGymTheme(accent: _accent, brightness: Brightness.light),
          darkTheme: buildGymTheme(accent: _accent),
          themeMode: _themeMode,
          builder: _appChrome,
          // Teks bawaan Flutter (tombol dialog, tooltip Kembali, pemilih
          // tanggal) ikut bahasa yang dipilih, bukan selalu bahasa Inggris.
          locale: _lang == AppLanguage.indonesian ? const Locale('id') : const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('id')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: AppFlow(
            language: _lang,
            onLanguageChanged: _setLanguage,
            accent: _accent,
            onAccentChanged: _setAccent,
            themeMode: _themeMode,
            onThemeModeChanged: _setThemeMode,
          ),
        ),
      ),
    );
  }
}

/// Bilah status mengikuti tema: ikon gelap di tema terang. Tanpa ini jam dan
/// baterai tergambar putih di atas latar putih.
Widget _appChrome(BuildContext context, Widget? child) {
  final c = context.gym;
  setBrowserChrome(background: c.bg, light: c.isLight);
  final style = (c.isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light).copyWith(
    statusBarColor: const Color(0x00000000),
    systemNavigationBarColor: c.surface,
    systemNavigationBarIconBrightness: c.isLight ? Brightness.dark : Brightness.light,
  );
  var body = _phoneWidthOnWeb(context, child);
  if (kIsWeb && c.isLight) {
    // Aplikasi web di Home Screen iPhone memakai bilah status
    // black-translucent: teksnya selalu putih, dan pengaturannya hanya dibaca
    // saat dipasang. Di tema terang, pita di balik bilah status digelapkan
    // supaya jam tetap terbaca.
    final top = MediaQuery.paddingOf(context).top;
    final inset = top > 0 ? top : readCssSafeArea().top;
    if (inset > 0) {
      body = Stack(children: [
        body,
        Positioned(top: 0, left: 0, right: 0, height: inset, child: ColoredBox(color: c.text)),
      ]);
    }
  }
  return AnnotatedRegion<SystemUiOverlayStyle>(value: style, child: body);
}

/// Penyesuaian tampilan khusus web, dipasang lewat `MaterialApp.builder`.
///
/// * Inset aman iPhone: mesin Flutter web tidak mengisi `MediaQuery.padding`,
///   jadi nilainya dibaca dari CSS (lihat `safe_area_web.dart`) dan
///   disuntikkan di sini. Tanpa ini, `SafeArea` di semua layar tidak berbuat
///   apa-apa dan tombol FINISH tergambar di balik jam iPhone.
/// * Layar lebar (laptop): aplikasi tampil selebar ponsel di tengah. Tata
///   letaknya memang satu kolom; kartu yang direntang ke 1400 px hanya membuat
///   angka-angkanya berjauhan. MediaQuery ikut dipersempit supaya widget yang
///   membaca lebar layar melihat lebar yang sama dengan yang digambar.
Widget _phoneWidthOnWeb(BuildContext context, Widget? child) {
  if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();
  var mq = MediaQuery.of(context);
  final css = readCssSafeArea();
  if (css != EdgeInsets.zero && mq.padding == EdgeInsets.zero) {
    mq = mq.copyWith(padding: css, viewPadding: css);
  }
  if (mq.size.width <= 600) return MediaQuery(data: mq, child: child);
  final data = mq;
  return ValueListenableBuilder<bool>(
    valueListenable: wideLayout,
    builder: (context, wide, _) {
      // Dashboard boleh melebar sampai 1100 px; layar lain tetap selebar ponsel.
      final width = (wide ? 1100.0 : 480.0).clamp(0.0, data.size.width);
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: SizedBox(
            width: width,
            child: MediaQuery(
              data: data.copyWith(size: Size(width, data.size.height)),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// Urutan layar dari login sampai akhir.
/// `booting` ada karena memeriksa akun tersimpan itu asinkron. Tanpa tahap
/// ini, layar masuk berkedip sesaat sebelum diganti Home untuk orang yang
/// sebenarnya sudah masuk.
enum AppStage { booting, login, register, program, equipment, home, unconfigured }

/// Mengatur perpindahan antar tahap.
///
/// Sengaja satu enum di satu tempat, bukan rantai `Navigator.push`: onboarding
/// hanya jalan sekali, dan tombol kembali dari Home tidak boleh mendarat lagi di
/// layar pilih program.
class AppFlow extends StatefulWidget {
  const AppFlow({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    this.accent,
    this.onAccentChanged,
    this.themeMode = ThemeMode.dark,
    this.onThemeModeChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final Color? accent;
  final ValueChanged<Color>? onAccentChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<AppFlow> {
  AppStage _stage = AppStage.booting;

  /// Akun yang sedang masuk. Dipegang di sini supaya layar Profil menampilkan
  /// email yang sebenarnya, bukan alamat contoh.
  Account? _account;

  /// Akun selalu punya sisi lokal. Kalau Supabase dikonfigurasi, sisi itu
  /// dibungkus supaya masuk dan mendaftar juga menghasilkan sesi server —
  /// tanpa sesi itu, `SupabaseBackend` menolak setiap dorongan dan sinkronnya
  /// diam tanpa pernah mengeluh.
  ///
  /// Di web tidak ada sisi lokal: browser tidak punya Keystore, dan server
  /// yang memeriksa kata sandi. Lihat [WebAccountStore].
  late final AccountStore _accounts = switch ((kIsWeb, supabaseConfigured)) {
    (true, true) => WebAccountStore(Supabase.instance.client.auth, onSignedIn: _syncAfterSignIn),
    (_, true) => SyncedAccountStore(
        local: LocalAccountStore(),
        auth: Supabase.instance.client.auth,
        onSignedIn: _syncAfterSignIn,
      ),
    _ => LocalAccountStore(),
  };

  /// Riwayat yang sudah tercatat offline harus naik begitu sesi ada, bukan
  /// menunggu latihan berikutnya selesai.
  void _syncAfterSignIn() {
    if (mounted) WorkoutScope.read(context).syncNow();
  }

  /// Sesi server yang dicabut selagi aplikasi terbuka (token dicabut, akun
  /// dihapus, refresh ditolak). Di web akunnya *adalah* sesi itu, jadi tanpa
  /// ini orangnya tetap di Home dengan sinkron yang diam-diam mati selamanya.
  StreamSubscription<AuthState>? _authEvents;

  @override
  void initState() {
    super.initState();
    if (_accounts is WebAccountStore) {
      _authEvents = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
        // Keluar yang kita mulai sendiri sudah mengosongkan _account lebih
        // dulu; yang ditangani di sini hanya keluar yang datang dari server.
        if (s.event == AuthChangeEvent.signedOut && _account != null && mounted) _signOut();
      }, onError: (Object e) => debugPrint('auth event: $e'));
    }
    _restore();
  }

  /// Orang yang sudah masuk tidak perlu masuk lagi tiap membuka aplikasi.
  Future<void> _restore() async {
    // Versi web tanpa server tidak punya arti: tidak ada Keystore untuk akun
    // lokal, dan tidak ada yang bisa disinkronkan. Lebih baik bilang.
    if (kIsWeb && !supabaseConfigured) {
      setState(() => _stage = AppStage.unconfigured);
      return;
    }
    final account = await _accounts.signedIn();
    if (!mounted) return;
    if (account == null) {
      setState(() => _stage = AppStage.login);
      return;
    }
    await _enter();
  }

  bool _entering = false;

  /// Onboarding sedang tampil karena program belum diketahui — bukan karena
  /// orangnya memang belum punya. Kalau rencana dari server tiba selagi layar
  /// pilih program terbuka, aplikasi langsung lanjut ke Home.
  bool _awaitingPlan = false;
  WorkoutStore? _watched;

  void _onStoreChanged() {
    final store = _watched;
    if (store == null || !mounted) return;
    if (_awaitingPlan && _stage == AppStage.program && store.hasProgram) {
      _awaitingPlan = false;
      setState(() => _stage = AppStage.home);
    }
  }

  @override
  void dispose() {
    _authEvents?.cancel();
    _watched?.removeListener(_onStoreChanged);
    super.dispose();
  }

  /// Dipanggil setelah masuk atau mendaftar berhasil, dan saat aplikasi
  /// dibuka oleh orang yang masih masuk.
  ///
  /// Dokumen akun inilah yang dibuka — bukan dokumen bersama satu HP. Lalu
  /// onboarding hanya dijalankan kalau program memang belum pernah dipilih.
  Future<void> _enter() async {
    // Layar masuk langsung diganti layar tunggu: menunggu server bisa makan
    // beberapa detik, dan tombol "masuk" yang bisa diketuk lagi selama itu
    // membuka akun dua kali.
    if (_entering) return;
    _entering = true;
    setState(() => _stage = AppStage.booting);
    try {
      final store = WorkoutScope.read(context);
      if (!identical(_watched, store)) {
        _watched?.removeListener(_onStoreChanged);
        _watched = store..addListener(_onStoreChanged);
      }
      final account = await _accounts.signedIn();
      if (!mounted) return;
      if (account == null) {
        setState(() => _stage = AppStage.login);
        return;
      }
      await store.load(account.email);
      // Program orang ini mungkin sudah ada di server (HP baru, pasang ulang).
      // Tarikan pertama ditunggu sebentar sebelum memutuskan onboarding.
      // Kalau batas waktunya habis, onboarding tetap jalan — tapi rencana
      // server yang datang belakangan masih menang (lihat _onStoreChanged
      // dan planBeforeServer di store).
      if (!store.hasProgram && store.hasBackend && !store.serverChecked) {
        await store.initialSync.timeout(const Duration(seconds: 8), onTimeout: () {});
      }
      if (!mounted) return;
      setState(() {
        _account = account;
        _awaitingPlan = !store.hasProgram;
        _stage = store.hasProgram ? AppStage.home : AppStage.program;
      });
      if (_pendingPasswordRecovery) {
        _pendingPasswordRecovery = false;
        WidgetsBinding.instance.addPostFrameCallback((_) => _askNewPassword());
      }
    } finally {
      _entering = false;
    }
  }

  /// Dibuka dari link reset: sesinya sudah ada (token di link), tinggal
  /// menyetel kata sandi baru.
  Future<void> _askNewPassword() async {
    if (!mounted || !supabaseConfigured) return;
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _NewPasswordDialog(),
    );
    if (password == null || password.length < 8 || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: password));
      messenger.showSnackBar(SnackBar(content: Text(t.passwordUpdated)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.authOffline)));
    }
  }

  /// Keluar. Store ditutup dan layar di atas Home dibuang lebih dulu, baru
  /// sesi server dilepas: logout ke server bisa lambat, dan sesi latihan yang
  /// dibuka selama menunggu akan tercatat ke store yang sudah tertutup.
  Future<void> _signOut() async {
    final store = WorkoutScope.read(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    store.close();
    setState(() {
      _account = null;
      _awaitingPlan = false;
      _stage = AppStage.booting;
    });
    await _accounts.signOut();
    if (mounted) setState(() => _stage = AppStage.login);
  }

  Future<void> _pickTemplate(ProgramTemplate t) async {
    _awaitingPlan = false;
    await WorkoutScope.read(context).applyTemplate(t.id);
    if (mounted) setState(() => _stage = AppStage.equipment);
  }

  Future<void> _buildOwn() async {
    final store = WorkoutScope.read(context);
    final built = await buildOwnSplit(context);
    if (built == null || !mounted) return;
    _awaitingPlan = false;
    await store.setProgram(built.program, built.routines);
    if (mounted) setState(() => _stage = AppStage.equipment);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      // Latar polos dulu: membuka akun biasanya selesai dalam hitungan
      // milidetik, dan spinner yang berkelip lebih mengganggu daripada jeda.
      // Spinner baru muncul kalau ternyata menunggu server.
      AppStage.booting => Scaffold(
          backgroundColor: context.gym.bg,
          body: FutureBuilder<void>(
            future: Future<void>.delayed(const Duration(milliseconds: 600)),
            builder: (context, snap) => snap.connectionState == ConnectionState.done
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : const SizedBox.shrink(),
          ),
        ),
      AppStage.login => LoginScreen(
          store: _accounts,
          onSignedIn: _enter,
          onCreateAccount: () => setState(() => _stage = AppStage.register),
          onForgotPassword: supabaseConfigured
              ? (email) => requestPasswordReset(supabaseUrl: _supabaseUrl, anonKey: _supabaseAnonKey, email: email)
              : null,
        ),
      // Akun baru selalu lewat onboarding; akun lama juga, sampai lapisan
      // penyimpanan bisa menjawab "program orang ini sudah dipilih belum".
      AppStage.register => RegisterScreen(
          store: _accounts,
          onRegistered: _enter,
          onSignInInstead: () => setState(() => _stage = AppStage.login),
        ),
      // Kembali dari sini berarti keluar: akunnya sudah masuk, dan layar masuk
      // di atas akun yang masih terbuka membuat masuk berikutnya bertabrakan.
      AppStage.program => ProgramPickerScreen(
          onBack: _signOut,
          onContinue: _pickTemplate,
          onBuildOwn: _buildOwn,
        ),
      AppStage.equipment => EquipmentScreen(
          onBack: () => setState(() => _stage = AppStage.program),
          onSkip: () => setState(() => _stage = AppStage.home),
          onContinue: () => setState(() => _stage = AppStage.home),
        ),
      AppStage.unconfigured => Scaffold(
          backgroundColor: context.gym.bg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.t.syncOffHint, textAlign: TextAlign.center),
            ),
          ),
        ),
      AppStage.home => HomeShell(
          language: widget.language,
          onLanguageChanged: widget.onLanguageChanged,
          onAccentChanged: widget.onAccentChanged,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          email: _account?.email,
          onSignOut: _signOut,
          onConnect: switch (_accounts) {
            final SyncedAccountStore synced => synced.connect,
            _ => null,
          },
        ),
    };
  }
}

/// Lima tab datar sesuai `REFRENSI/04 Home.png`: Workout · Home · Stats ·
/// History · Profile, dengan Home sebagai tab default (PRD §10).
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.onSignOut,
    required this.email,
    this.onConnect,
    this.onAccentChanged,
    this.themeMode = ThemeMode.dark,
    this.onThemeModeChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onSignOut;
  final String? email;
  final Future<ConnectResult> Function(String password)? onConnect;
  final ValueChanged<Color>? onAccentChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeUnfinished();
      unawaited(_announceAligned());
    });
  }

  /// Rencana lama yang baru saja mengikuti sesi terakhir tiap rutinitasnya
  /// (sesudah sinkron pertama) disebut sekali di sini.
  Future<void> _announceAligned() async {
    if (!mounted) return;
    final store = WorkoutScope.read(context);
    await store.initialSync;
    if (!mounted) return;
    announceAlignedRoutines(ScaffoldMessenger.maybeOf(context), context.t, store);
  }

  /// Sesi yang tertinggal karena aplikasi dimatikan (sistem mematikannya di
  /// latar belakang, HP mati, atau aplikasi ditutup di loker) langsung dibuka
  /// lagi — seperti aplikasi latihan lain, sesi yang sedang berjalan adalah
  /// tempat orang kembali. Dulu sesinya hanya menunggu di kartu kecil di Home,
  /// dan menekan "Mulai sesi" di atasnya menimpanya tanpa bertanya.
  void _resumeUnfinished() {
    if (!mounted) return;
    final draft = WorkoutScope.read(context).draft;
    if (draft != null && draftIsRecent(draft)) resumeDraftSession(context, restored: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    // Setiap tab punya pasangan garis/isi: yang aktif "terisi", sisanya
    // garis. Stats pakai grafik, bukan monitor jantung — ini beban dan
    // e1RM, bukan detak. Labelnya tidak digambar (referensi memakai nav pil
    // berisi ikon saja) tapi tetap ada untuk pembaca layar dan tooltip.
    final tabs = <(IconData, IconData, String)>[
      (GymIcons.dumbbell, GymIcons.dumbbell, t.workout),
      (GymIcons.home, GymIcons.home, t.home),
      (GymIcons.chart, GymIcons.chart, t.stats),
      (GymIcons.clock, GymIcons.clock, t.history),
      // Referensi memakai roda gigi untuk tab terakhir; tab Profil di sini
      // memang berisi setelan.
      (GymIcons.settings, GymIcons.settings, t.profile),
    ];
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        // IndexedStack, bukan mengganti anaknya: posisi gulir dan tab terpilih
        // di dalam tiap layar bertahan saat berpindah-pindah.
        child: FadeIndexedStack(
          index: _tab,
          // Tab selain Home baru dibangun saat pertama kali dibuka
          // (_LazyTab): IndexedStack menata semua anaknya sejak awal, jadi
          // tanpa ini animasi kedatangan kartu di tab Workout/Profil habis
          // berjalan diam-diam saat aplikasi dibuka, dan yang dilihat orang
          // saat pindah tab hanya layar yang sudah diam. Sekali dibangun,
          // tab tetap hidup seperti sebelumnya.
          children: [
            _LazyTab(active: _tab == 0, child: const WorkoutScreen()),
            HomeScreen(
              email: widget.email,
              onOpenProfile: () => setState(() => _tab = 4),
              // Blok statistik dan sheet hari di Home membuka tab lain —
              // angka yang dilihat di sana bisa langsung ditelusuri.
              onOpenTab: (i) => setState(() => _tab = i),
            ),
            _LazyTab(active: _tab == 2, child: const StatsScreen()),
            _LazyTab(active: _tab == 3, child: const HistoryScreen()),
            _LazyTab(
              active: _tab == 4,
              child: ProfileScreen(
                language: widget.language,
                onLanguageChanged: widget.onLanguageChanged,
                onSignOut: widget.onSignOut,
                email: widget.email,
                onConnect: widget.onConnect,
                onAccentChanged: widget.onAccentChanged,
                themeMode: widget.themeMode,
                onThemeModeChanged: widget.onThemeModeChanged,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _FloatingNav(
        tabs: tabs,
        index: _tab,
        onChanged: (i) {
          if (i == _tab) return;
          GymHaptics.tap();
          setState(() => _tab = i);
        },
      ),
    );
  }
}

/// Anak IndexedStack yang kosong sampai tab-nya pertama kali dipilih, lalu
/// tetap hidup selamanya. Posisi gulir dan pilihan di dalam tab tidak hilang
/// saat berpindah — yang berubah cuma kapan layar itu lahir.
class _LazyTab extends StatefulWidget {
  const _LazyTab({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<_LazyTab> {
  bool _built = false;

  @override
  Widget build(BuildContext context) {
    _built = _built || widget.active;
    return _built ? widget.child : const SizedBox.shrink();
  }
}

/// Nav bawah bergaya referensi: pil abu gelap yang melayang di atas latar,
/// berisi ikon saja; yang aktif berwarna aksen.
class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.tabs, required this.index, required this.onChanged});

  final List<(IconData, IconData, String)> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(GymRadius.nav),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: c.isLight ? 0.10 : 0.45), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              for (final (i, (icon, activeIcon, label)) in tabs.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: label,
                    child: Tooltip(
                      message: label,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: () => onChanged(i),
                          borderRadius: BorderRadius.circular(GymRadius.nav),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Ikon tab aktif membesar sedikit dengan
                              // sedikit pantulan: ibu jari yang baru
                              // memindah tab langsung melihat jawabannya.
                              AnimatedScale(
                                scale: i == index ? 1.12 : 1,
                                duration: GymMotion.of(context, GymMotion.quick),
                                curve: GymMotion.pop,
                                child: AnimatedSwitcher(
                                  duration: GymMotion.of(context, GymMotion.quick),
                                  child: Icon(
                                    i == index ? activeIcon : icon,
                                    key: ValueKey(i == index),
                                    size: 26,
                                    color: i == index ? c.accent : c.text2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              // Paket ikonnya garis saja, tanpa versi terisi;
                              // tab aktif ditandai warna dan titik kecil.
                              AnimatedContainer(
                                duration: GymMotion.of(context, GymMotion.quick),
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: i == index ? c.accent : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog();

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.length < 8) {
      setState(() => _error = context.t.passwordTooShort(8));
      return;
    }
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text(t.newPasswordTitle, style: Theme.of(context).textTheme.titleLarge),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: t.password, errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel, style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
        ),
        GymButton(label: t.save, height: 42, expand: false, onPressed: _submit),
      ],
    );
  }
}
