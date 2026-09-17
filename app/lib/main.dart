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

class _GymAppState extends State<GymApp> {
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

  @override
  void initState() {
    super.initState();
    // Tidak di-await: store memberi tahu sendiri lewat notifier begitu
    // riwayatnya selesai dibaca, dan layar sudah tahu cara menunggu.
    _store.load();
  }

  @override
  void dispose() {
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
  ProgramTemplate? _program;

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
    setState(() {
      _account = account;
      _stage = account == null ? AppStage.login : AppStage.home;
    });
  }

  /// Dipanggil setelah masuk atau mendaftar berhasil — store-nya sudah tahu
  /// siapa yang masuk, tinggal dibaca ulang.
  Future<void> _enter(AppStage next) async {
    final account = await _accounts.signedIn();
    if (!mounted) return;
    setState(() {
      _account = account;
      _stage = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      // Latar polos, bukan spinner: pemeriksaannya selesai dalam hitungan
      // milidetik, dan spinner yang berkelip lebih mengganggu daripada jeda.
      AppStage.booting => Scaffold(backgroundColor: context.gym.bg),
      AppStage.login => LoginScreen(
          store: _accounts,
          onSignedIn: () => _enter(AppStage.program),
          onCreateAccount: () => setState(() => _stage = AppStage.register),
        ),
      // Akun baru selalu lewat onboarding; akun lama juga, sampai lapisan
      // penyimpanan bisa menjawab "program orang ini sudah dipilih belum".
      AppStage.register => RegisterScreen(
          store: _accounts,
          onRegistered: () => _enter(AppStage.program),
          onSignInInstead: () => setState(() => _stage = AppStage.login),
        ),
      AppStage.program => ProgramPickerScreen(
          onBack: () => setState(() => _stage = AppStage.login),
          onContinue: (t) => setState(() {
            _program = t;
            _stage = AppStage.equipment;
          }),
        ),
      AppStage.equipment => EquipmentScreen(
          onBack: () => setState(() => _stage = AppStage.program),
          onSkip: () => setState(() => _stage = AppStage.home),
          onContinue: () => setState(() => _stage = AppStage.home),
        ),
      AppStage.home => HomeShell(
          programName: _program?.name ?? 'Push / Pull / Legs',
          language: widget.language,
          onLanguageChanged: widget.onLanguageChanged,
          email: _account?.email,
          onSignOut: () async {
            await _accounts.signOut();
            if (mounted) {
              setState(() {
                _account = null;
                _stage = AppStage.login;
              });
            }
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
    required this.programName,
    required this.language,
    required this.onLanguageChanged,
    required this.onSignOut,
    required this.email,
  });

  final String programName;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onSignOut;
  final String? email;

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
            HomeScreen(programName: widget.programName),
            const StatsScreen(),
            const HistoryScreen(),
            ProfileScreen(
              language: widget.language,
              onLanguageChanged: widget.onLanguageChanged,
              onSignOut: widget.onSignOut,
              email: widget.email,
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
