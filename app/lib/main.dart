import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return AppStrings(
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
    );
  }
}

/// Urutan layar dari login sampai akhir.
enum AppStage { login, program, equipment, home }

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
  AppStage _stage = AppStage.login;
  ProgramTemplate? _program;

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      AppStage.login => LoginScreen(onSignedIn: () => setState(() => _stage = AppStage.program)),
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
          onSignOut: () => setState(() => _stage = AppStage.login),
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
  });

  final String programName;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onSignOut;

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
      NavigationDestination(icon: const Icon(Icons.fitness_center), label: t.workout),
      NavigationDestination(
          icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t.home),
      NavigationDestination(icon: const Icon(Icons.monitor_heart_outlined), label: t.stats),
      NavigationDestination(icon: const Icon(Icons.history), label: t.history),
      NavigationDestination(
          icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: t.profile),
    ];
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        // IndexedStack, bukan mengganti anaknya: posisi gulir dan tab terpilih
        // di dalam tiap layar bertahan saat berpindah-pindah.
        child: IndexedStack(
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: destinations,
        ),
      ),
    );
  }
}
