import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/motion.dart';
import 'core/strings.dart';
import 'core/theme.dart';
import 'data/account_store.dart';
import 'data/backend.dart';
import 'data/synced_account_store.dart';
import 'data/workout_store.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screens.dart';
import 'features/onboarding/program_flow.dart';
import 'features/profile/profile_screen.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Aplikasi harus tetap jalan tanpa kredensial: seluruh logging bersifat
  // offline-first (FR-A3), dan sebuah build tanpa Supabase masih berguna untuk
  // meninjau UI. Yang hilang hanya sinkronnya.
  if (supabaseConfigured) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  runApp(const GymApp());
}

class GymApp extends StatefulWidget {
  const GymApp({super.key});

  @override
  State<GymApp> createState() => _GymAppState();
}

class _GymAppState extends State<GymApp> with WidgetsBindingObserver {
  /// Bahasa dipegang di akar supaya satu setState memperbarui seluruh aplikasi.
  /// Belum disimpan ke disk — pilihannya kembali ke bawaan setelah app ditutup,
  /// dan itu ikut store Supabase nanti bersama setelan lain.
  AppLanguage _lang = AppLanguage.english;

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
          theme: buildGymTheme(),
          home: AppFlow(
            language: _lang,
            onLanguageChanged: (l) => setState(() => _lang = l),
          ),
        ),
      ),
    );
  }
}

/// Urutan layar dari login sampai akhir.
/// `booting` ada karena memeriksa akun tersimpan itu asinkron. Tanpa tahap
/// ini, layar masuk berkedip sesaat sebelum diganti Home untuk orang yang
/// sebenarnya sudah masuk.
enum AppStage { booting, login, register, program, equipment, home }

/// Mengatur perpindahan antar tahap.
///
/// Sengaja satu enum di satu tempat, bukan rantai `Navigator.push`: onboarding
/// hanya jalan sekali, dan tombol kembali dari Home tidak boleh mendarat lagi di
/// layar pilih program.
class AppFlow extends StatefulWidget {
  const AppFlow({super.key, required this.language, required this.onLanguageChanged});

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

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
  late final AccountStore _accounts = supabaseConfigured
      ? SyncedAccountStore(
          local: LocalAccountStore(),
          auth: Supabase.instance.client.auth,
          // Riwayat yang sudah tercatat offline harus naik begitu sesi ada,
          // bukan menunggu latihan berikutnya selesai.
          onSignedIn: () {
            if (mounted) WorkoutScope.read(context).syncNow();
          },
        )
      : LocalAccountStore();

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Orang yang sudah masuk tidak perlu masuk lagi tiap membuka aplikasi.
  Future<void> _restore() async {
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
    } finally {
      _entering = false;
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
      AppStage.home => HomeShell(
          language: widget.language,
          onLanguageChanged: widget.onLanguageChanged,
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
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onSignOut;
  final String? email;
  final Future<ConnectResult> Function(String password)? onConnect;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 1;

  @override
  Widget build(BuildContext context) {
    final c = context.gym;
    final t = context.t;
    final destinations = <NavigationDestination>[
      // Setiap tab punya pasangan garis/isi: yang aktif "terisi", sisanya
      // garis. Stats pakai grafik, bukan monitor jantung — ini beban dan
      // e1RM, bukan detak.
      NavigationDestination(icon: const Icon(Icons.fitness_center_outlined), selectedIcon: const Icon(Icons.fitness_center), label: t.workout),
      NavigationDestination(
          icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t.home),
      NavigationDestination(icon: const Icon(Icons.insights_outlined), selectedIcon: const Icon(Icons.insights), label: t.stats),
      NavigationDestination(icon: const Icon(Icons.history_outlined), selectedIcon: const Icon(Icons.history), label: t.history),
      NavigationDestination(
          icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: t.profile),
    ];
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        // IndexedStack, bukan mengganti anaknya: posisi gulir dan tab terpilih
        // di dalam tiap layar bertahan saat berpindah-pindah.
        child: FadeIndexedStack(
          index: _tab,
          children: [
            const WorkoutScreen(),
            const HomeScreen(),
            const StatsScreen(),
            const HistoryScreen(),
            ProfileScreen(
              language: widget.language,
              onLanguageChanged: widget.onLanguageChanged,
              onSignOut: widget.onSignOut,
              email: widget.email,
              onConnect: widget.onConnect,
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            if (i == _tab) return;
            GymHaptics.tap();
            setState(() => _tab = i);
          },
          destinations: destinations,
        ),
      ),
    );
  }
}
