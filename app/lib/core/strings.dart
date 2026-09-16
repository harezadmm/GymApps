/// Teks yang dilihat pengguna, dalam dua bahasa.
///
/// Sengaja bukan `flutter_localizations` + ARB: aplikasi ini hanya punya dua
/// bahasa dan tidak butuh pluralisasi, format tanggal per-locale, atau arah
/// teks kanan-ke-kiri. Satu kelas dengan dua peta bisa dibaca, di-diff, dan
/// diuji tanpa langkah codegen.
///
/// Kalau nanti bahasa ketiga masuk atau butuh pluralisasi, ini titik yang
/// tepat untuk beralih ke ARB — antarmuka pemanggilnya (`context.t.xxx`)
/// tidak perlu berubah.
library;

import 'package:flutter/widgets.dart';

enum AppLanguage { english, indonesian }

const appLanguageLabel = <AppLanguage, String>{
  AppLanguage.english: 'English',
  AppLanguage.indonesian: 'Bahasa Indonesia',
};

/// Satu entri teks: bentuk Inggris dan Indonesia.
class Strings {
  const Strings(this.lang);

  final AppLanguage lang;

  String _(String en, String id) => lang == AppLanguage.indonesian ? id : en;

  // ── Login ────────────────────────────────────────────────────────────────
  String get tagline => _(
        "Open the app, it already knows today's session and the weight to lift.",
        'Buka aplikasinya, dia sudah tahu sesi hari ini dan beban yang harus diangkat.',
      );
  String get email => _('Email', 'Email');
  String get password => _('Password', 'Kata sandi');
  String get signIn => _('SIGN IN', 'MASUK');
  String get forgotPassword => _('Forgot password?', 'Lupa kata sandi?');

  // ── Daftar akun ─────────────────────────────────────────────────────
  String get createAccount => _('Create account', 'Buat akun');
  String get createAccountSub => _(
        'One account keeps your sessions on every device you train with.',
        'Satu akun menjaga sesimu ada di semua perangkat yang kamu pakai.',
      );
  String get confirmPassword => _('Confirm password', 'Ulangi kata sandi');
  String get signUp => _('CREATE ACCOUNT', 'BUAT AKUN');
  String get haveAccount => _('Already have an account? Sign in', 'Sudah punya akun? Masuk');
  String get noAccount => _("Don't have an account? Create one", 'Belum punya akun? Buat sekarang');
  String get emailRequired => _('Enter your email address.', 'Masukkan alamat emailmu.');
  String get emailInvalid => _(
        "That doesn't look like an email address.",
        'Itu sepertinya bukan alamat email.',
      );
  String passwordTooShort(int n) => _(
        'Password needs at least $n characters.',
        'Kata sandi minimal $n karakter.',
      );
  String get passwordMismatch => _(
        'The two passwords do not match.',
        'Kedua kata sandi tidak sama.',
      );
  String get emailTaken => _(
        'An account already exists on this device. Sign in instead.',
        'Sudah ada akun di perangkat ini. Masuk saja.',
      );
  String get noAccountYet => _(
        'No account on this device yet. Create one first.',
        'Belum ada akun di perangkat ini. Buat dulu.',
      );
  String get wrongEmail => _(
        'No account with that email on this device.',
        'Tidak ada akun dengan email itu di perangkat ini.',
      );
  String get wrongPassword => _('Wrong password.', 'Kata sandi salah.');
  // Empat kalimat berikut berpasangan: yang pertama dipakai kalau build ini
  // punya Supabase, yang kedua kalau tidak. Sebelumnya cuma ada satu versi
  // yang menyebut offline saja, dan setelah sinkron benar-benar jalan kalimat
  // itu membuat orang mengira datanya tidak pernah naik ke mana-mana.
  String get signUpSyncs => _(
        'Works without signal too. Your account reaches the cloud once you are online.',
        'Bisa tanpa sinyal juga. Akunmu sampai ke cloud begitu ada koneksi.',
      );
  String get signUpLocalOnly => _(
        'This account stays on this device. No server is configured.',
        'Akun ini tinggal di HP ini saja. Tidak ada server yang dipasang.',
      );
  String get offlineNoteSyncs => _(
        'Logging works without signal. Sessions go up as soon as you are online.',
        'Mencatat tetap jalan tanpa sinyal. Sesimu naik begitu ada koneksi.',
      );
  String get offlineNoteLocalOnly => _(
        'Everything stays on this device. No server is configured.',
        'Semuanya tinggal di HP ini. Tidak ada server yang dipasang.',
      );
  String get showPassword => _('Show password', 'Tampilkan kata sandi');
  String get hidePassword => _('Hide password', 'Sembunyikan kata sandi');

  // ── Onboarding ───────────────────────────────────────────────────────────
  String get chooseProgram => _('Choose your program', 'Pilih programmu');
  String get chooseProgramSub => _(
        'You can edit every routine later. Nothing is locked.',
        'Semua rutinitas bisa diubah nanti. Tidak ada yang dikunci.',
      );
  String get buildMyOwn => _('BUILD MY OWN', 'SUSUN SENDIRI');
  String get whatsInYourGym => _("What's in your gym?", 'Ada apa saja di gym-mu?');
  String gymFilterNote(String gym) => _(
        '$gym · used to filter the exercise library. Change it any time.',
        '$gym · dipakai menyaring library gerakan. Bisa diubah kapan saja.',
      );
  String get freeWeights => _('Free weights', 'Beban bebas');
  String get machines => _('Machines', 'Mesin');
  String get other => _('Other', 'Lainnya');
  String addGroup(String group) => _('Add $group', 'Tambah ${group.toLowerCase()}');
  String get addEquipment => _('Add equipment', 'Tambah alat');
  String get equipmentHint => _('e.g. Trap bar', 'mis. Trap bar');
  String get skip => _('Skip', 'Lewati');
  String get back => _('Back', 'Kembali');
  String get cont => _('CONTINUE', 'LANJUT');

  // ── Umum ────────────────────────────────────────────────────────────────
  String get cancel => _('Cancel', 'Batal');
  String get save => _('SAVE', 'SIMPAN');
  String get add => _('ADD', 'TAMBAH');
  String get delete => _('DELETE', 'HAPUS');
  String get done => _('DONE', 'SELESAI');

  // ── Home ────────────────────────────────────────────────────────────────
  String get nextUp => _('Next up', 'Berikutnya');
  String get nextSession => _('Next session', 'Sesi berikutnya');
  String get dueToday => _('DUE TODAY', 'HARI INI');
  String get startSession => _('START SESSION', 'MULAI SESI');
  String get freestyle => _('Freestyle', 'Bebas');
  String get thisWeek => _('This week', 'Minggu ini');
  String plannedOf(int done, int total) =>
      _('$done of $total planned', '$done dari $total rencana');
  String get volume7d => _('Volume 7d', 'Volume 7 hari');
  String get e1rmUp => _('e1RM up', 'e1RM naik');
  String get sinceLast => _('Since last', 'Sejak terakhir');
  String moreItems(int n) => _('+$n more', '+$n lagi');
  String exerciseCount(int n) => _('$n exercises', '$n gerakan');

  // ── Workout ─────────────────────────────────────────────────────────────
  String get workout => _('Workout', 'Latihan');
  String get tracker => _('Tracker', 'Pencatat');
  String get myPlan => _('My Plan', 'Programku');
  String get exerciseLibrary => _('Exercise Library', 'Library Gerakan');
  String get newWorkout => _('New workout', 'Latihan baru');
  String get startEmpty => _('Start empty', 'Mulai kosong');
  String get freestyleLog => _('Freestyle log', 'Catat bebas');
  String get fromProgram => _('From program', 'Dari program');
  String isNext(String name) => _('$name is next', '$name berikutnya');
  String get routines => _('Routines', 'Rutinitas');
  String get editProgram => _('Edit program', 'Ubah program');
  String get newRoutine => _('NEW ROUTINE', 'RUTINITAS BARU');
  String get noRoutines => _(
        'No routines yet — add one to get started.',
        'Belum ada rutinitas — tambah satu untuk mulai.',
      );
  String get editExercises => _('Edit exercises', 'Ubah gerakan');
  String get rename => _('Rename', 'Ganti nama');
  String get duplicate => _('Duplicate', 'Gandakan');
  String get deleteWord => _('Delete', 'Hapus');
  String get renameRoutine => _('Rename routine', 'Ganti nama rutinitas');
  String get newRoutineTitle => _('New routine', 'Rutinitas baru');
  String get routineNameHint => _('e.g. Upper A', 'mis. Atas A');
  String deleteRoutineTitle(String name) => _('Delete $name?', 'Hapus $name?');
  String get deleteRoutineBody => _(
        'The routine and its exercise targets are removed. Sessions you already '
            'logged with it stay in your history.',
        'Rutinitas dan target gerakannya dihapus. Sesi yang sudah kamu catat '
            'dengan rutinitas ini tetap ada di riwayat.',
      );

  // ── Routine editor ──────────────────────────────────────────────────────
  String get editRoutine => _('Edit routine', 'Ubah rutinitas');
  String get routineName => _('Routine name', 'Nama rutinitas');
  String get defaultPolicy => _('Default policy', 'Policy bawaan');
  String get defaultRest => _('Default rest', 'Istirahat bawaan');
  String exercisesCount(int n) => _('Exercises · $n', 'Gerakan · $n');
  String get sets => _('Sets', 'Set');
  String get reps => _('Reps', 'Rep');
  String get increment => _('Increment', 'Kelipatan');
  String get rest => _('Rest', 'Istirahat');
  String get progressionPolicy => _('Progression policy', 'Policy progresi');
  String get intensifiers => _('Intensifiers', 'Penambah intensitas');
  String get addExercise => _('ADD EXERCISE', 'TAMBAH GERAKAN');
  String get deleteRoutine => _('DELETE ROUTINE', 'HAPUS RUTINITAS');
  String get keptInMemory => _(
        'Routine changes are kept in memory until sync is on.',
        'Perubahan rutinitas hanya disimpan di memori sampai sync aktif.',
      );

  // ── Sesi ────────────────────────────────────────────────────────────────
  String get sessionNotes => _('Session notes...', 'Catatan sesi...');
  String get finish => _('FINISH', 'SELESAI');
  String get restTimer => _('Rest timer', 'Timer istirahat');
  String get start => _('START', 'MULAI');
  String get addSet => _('ADD SET', 'TAMBAH SET');
  String get setCol => _('Set', 'Set');
  String get prevCol => _('Prev', 'Sblm');
  String get kgCol => _('Kg', 'Kg');
  String get repsCol => _('Reps', 'Rep');
  String targetLine(String weight, int reps, String policy) =>
      _('Target $weight kg × $reps · $policy', 'Target $weight kg × $reps · $policy');
  String setsTarget(int n, String weight, int reps) =>
      _('$n sets · target $weight kg × $reps', '$n set · target $weight kg × $reps');
  String get warmupLabel => _('warm-up', 'pemanasan');
  String setLabel(int n) => _('set $n', 'set $n');
  String nextUpLine(String what, String weight, int reps) =>
      _('Next: $what · $weight × $reps', 'Berikutnya: $what · $weight × $reps');
  String get lastSetDone => _('Last set done', 'Set terakhir selesai');
  String get minimise => _('Minimise', 'Perkecil');
  String get collapse => _('Collapse', 'Tutup');
  String get expand => _('Expand', 'Buka');
  String markSetDone(String label) => _('Mark set $label done', 'Tandai set $label selesai');

  // ── Istirahat ───────────────────────────────────────────────────────────
  String get resting => _('Resting', 'Istirahat');
  String ofDuration(String d) => _('of $d', 'dari $d');
  String get changeDuration => _('Change duration', 'Ubah durasi');
  String get skipRest => _('SKIP REST', 'LEWATI ISTIRAHAT');
  String get backToSession => _('Back to session', 'Kembali ke sesi');
  String get restDuration => _('Rest duration', 'Durasi istirahat');
  String get minutes => _('Minutes', 'Menit');
  String get seconds => _('Seconds', 'Detik');
  String get presets => _('Presets', 'Preset');
  String saveDefaultFor(String name) =>
      _('Save as default for $name', 'Jadikan bawaan untuk $name');
  String get sessionOnly => _(
        'Otherwise it applies to this session only',
        'Kalau tidak, hanya berlaku untuk sesi ini',
      );
  String globalDefault(int s) => _(
        'Global default stays $s s (Profile → Default rest).',
        'Bawaan global tetap $s detik (Profil → Istirahat bawaan).',
      );
  String setDuration(String d) => _('SET $d', 'PAKAI $d');
  String get close => _('Close', 'Tutup');
  String decrease(String what) => _('decrease $what', 'kurangi $what');
  String increase(String what) => _('increase $what', 'tambah $what');

  // ── Ringkasan selesai ───────────────────────────────────────────────────
  String get sessionComplete => _('Session complete', 'Sesi selesai');
  String get duration => _('Duration', 'Durasi');
  String get volume => _('Volume', 'Volume');
  String get setsDone => _('Sets done', 'Set selesai');
  String get newPRs => _('New PRs', 'Rekor baru');
  String get newPersonalRecords => _('New personal records', 'Rekor pribadi baru');
  String get musclesWorked => _('Muscles worked', 'Otot yang dilatih');
  String get nextSessionTargets => _('Next session targets', 'Target sesi berikutnya');
  String get noWorkingSets => _('No working sets logged.', 'Belum ada set kerja tercatat.');
  String addedSetTo(String name) => _('You added 1 set to $name', 'Kamu menambah 1 set di $name');
  String updateRoutine(String name) =>
      _('Update the $name routine to match?', 'Perbarui rutinitas $name supaya cocok?');
  String get setsOnly => _('Sets only', 'Set saja');
  String get updateAll => _('Update all', 'Perbarui semua');
  String get keep => _('Keep', 'Biarkan');

  // ── Stats ───────────────────────────────────────────────────────────────
  String get stats => _('Stats', 'Statistik');
  String get balance => _('Balance', 'Keseimbangan');
  String get fatigue => _('Fatigue', 'Kelelahan');
  String get strength => _('Strength', 'Kekuatan');
  String get muscleHeatmap => _('Muscle heatmap', 'Peta panas otot');
  String get volumeShare => _('volume share', 'porsi volume');
  String get low => _('Low', 'Rendah');
  String get high => _('High', 'Tinggi');
  String get bodyRegionsWorked => _('Body regions worked', 'Region tubuh yang dilatih');
  String get previousPeriod => _('Previous period', 'Periode sebelumnya');
  String get readingSessions => _('Reading your sessions…', 'Membaca sesimu…');
  String get noSetsInRange => _(
        'No sets logged in this range yet — the map stays dark until you train.',
        'Belum ada set tercatat di rentang ini — petanya gelap sampai kamu latihan.',
      );
  String leastVolume(String muscle) => _(
        '$muscle saw the least volume in this range',
        '$muscle paling sedikit kebagian volume di rentang ini',
      );
  String get estimated1RM => _('Estimated 1RM', 'Perkiraan 1RM');
  String get strengthByMovement => _('Strength by movement', 'Kekuatan per gerakan');
  String get bodyweight => _('Bodyweight', 'Berat badan');
  String targetWeight(String w) => _('target $w kg', 'target $w kg');
  String get weeklySetVolume => _('Weekly set volume', 'Volume set mingguan');
  String get daysSinceWorked => _('Days since last worked', 'Hari sejak terakhir dilatih');
  String get fatigueNote => _(
        'Fatigue scoring from RIR is not implemented yet — these are plain counts from the log.',
        'Skor kelelahan dari RIR belum dibuat — ini hitungan mentah dari catatan.',
      );
  String lastDays(int n) => _('Last $n days', '$n hari terakhir');

  // ── History ─────────────────────────────────────────────────────────────
  String get history => _('History', 'Riwayat');
  String get activity => _('Activity', 'Aktivitas');
  // Jamaknya baru terlihat setelah angkanya nyata: sesi pertama seseorang
  // tidak boleh disambut dengan "1 sessions".
  String sessionsThisYear(int n) =>
      _('$n session${n == 1 ? '' : 's'} this year', '$n sesi tahun ini');
  String get all => _('All', 'Semua');
  String noSessionsOf(String filter) =>
      _('No $filter sessions logged yet', 'Belum ada sesi $filter tercatat');
  String setsSuffix(int n) => _('$n sets', '$n set');
  // Kosong karena belum pernah latihan itu keadaan yang berbeda dari kosong
  // karena filternya terlalu sempit — dan jawabannya juga berbeda.
  String get noSessionsYet =>
      _('No sessions saved yet', 'Belum ada sesi tersimpan');
  String get noSessionsYetHint => _(
        'Finish a workout and it shows up here.',
        'Selesaikan satu latihan, dan hasilnya muncul di sini.',
      );
  String get freestyleSession => _('Freestyle', 'Bebas');

  // ── Library ─────────────────────────────────────────────────────────────
  String get searchExercise => _('Search exercise', 'Cari gerakan');
  String get performed => _('Performed', 'Pernah dipakai');
  String get alphabetical => _('A–Z', 'A–Z');
  String get byMuscle => _('By muscle', 'Per otot');
  String equipmentProfile(String gym) =>
      _('$gym equipment profile', 'Profil alat $gym');
  String shownCount(String n) => _('$n shown', '$n tampil');
  String nothingMatches(String q) => _('Nothing matches "$q"', 'Tidak ada yang cocok dengan "$q"');
  String get catalogueError => _(
        'Could not read the exercise catalogue.',
        'Tidak bisa membaca katalog gerakan.',
      );
  String get filters => _('Filters', 'Filter');
  String get customExercise => _('Custom exercise', 'Gerakan sendiri');
  String get addToFavourites => _('Add to favourites', 'Tambah ke favorit');
  String get removeFromFavourites => _('Remove from favourites', 'Hapus dari favorit');

  // ── Profil ──────────────────────────────────────────────────────────────
  String get profile => _('Profile', 'Profil');
  String get syncedNow => _('Synced just now', 'Baru saja tersinkron');
  String get syncOff => _('Sync off — local only', 'Sync mati — lokal saja');
  String get syncing => _('Syncing…', 'Menyinkronkan…');
  // Kegagalan sinkron disebut apa adanya, dan disertai kalimat yang menjawab
  // pertanyaan pertama orang: "latihan saya hilang tidak?"
  String get syncFailed =>
      _('Sync failed — saved on this device', 'Sync gagal — tersimpan di HP ini');
  String get syncPending => _('Not synced yet', 'Belum tersinkron');
  String get training => _('Training', 'Latihan');
  String get units => _('Units', 'Satuan');
  String get restPauseRest => _('Rest-pause rest', 'Istirahat rest-pause');
  String get deloadFactor => _('Deload factor', 'Faktor deload');
  String get effortScale => _('Effort scale', 'Skala usaha');
  String get keepScreenAwake => _('Keep screen awake', 'Layar tetap menyala');
  String get weekStartsOn => _('Week starts on', 'Minggu mulai');
  String get monday => _('Monday', 'Senin');
  String get off => _('Off', 'Mati');
  String get gyms => _('Gyms', 'Gym');
  String get active => _('active', 'aktif');
  String get addEquipmentProfile => _('Add equipment profile', 'Tambah profil alat');
  String get data => _('Data', 'Data');
  String get exportBackup => _('Export backup (JSON)', 'Ekspor cadangan (JSON)');
  String get importBackup => _('Import backup', 'Impor cadangan');
  String get forceSync => _('Force sync now', 'Paksa sync sekarang');
  String get app => _('App', 'Aplikasi');
  String get theme => _('Theme', 'Tema');
  String get dark => _('Dark', 'Gelap');
  String get accentColour => _('Accent colour', 'Warna aksen');
  String get language => _('Language', 'Bahasa');
  String get aboutApp => _('About GymApps', 'Tentang GymApps');
  String get logOut => _('LOG OUT', 'KELUAR');
  String notWired(String what) =>
      _('$what is not wired up yet.', '$what belum tersambung.');
  String get home => _('Home', 'Beranda');

  // ── Nama otot dan region ─────────────────────────────────────────────
  // Dipakai banner "least volume" dan sumbu radar. Nama otot dalam bahasa
  // Indonesia pakai istilah yang lazim dipakai di gym, bukan terjemahan
  // anatomi harfiah: orang menyebut "punggung bawah", bukan "lumbal".
  static const _muscleId = <String, String>{
    'Chest': 'Dada',
    'Abs': 'Perut',
    'Obliques': 'Perut samping',
    'Shoulders': 'Bahu',
    'Traps': 'Trapezius',
    'Lats': 'Punggung sayap',
    'Lower back': 'Punggung bawah',
    'Biceps': 'Bisep',
    'Triceps': 'Trisep',
    'Forearms': 'Lengan bawah',
    'Glutes': 'Bokong',
    'Quads': 'Paha depan',
    'Hamstrings': 'Paha belakang',
    'Calves': 'Betis',
  };

  static const _regionId = <String, String>{
    'Chest': 'Dada',
    'Core': 'Inti',
    'Arms': 'Lengan',
    'Legs': 'Kaki',
    'Shoulders': 'Bahu',
    'Back': 'Punggung',
  };

  // ── Tambahan dari sapuan kedua ───────────────────────────────────────
  String rotationOf(String program) => _('$program · rotation', '$program · rotasi');
  String routineSummary(int exercises, int minutes, int daysAgo) => _(
        '$exercises exercises · ~$minutes min · last done $daysAgo days ago',
        '$exercises gerakan · ~$minutes mnt · terakhir $daysAgo hari lalu',
      );
  String routineMeta(int exercises, int sets) =>
      _('$exercises exercises · $sets sets', '$exercises gerakan · $sets set');
  String libraryFiltered(String count, String gym) => _(
        '$count exercises · filtered by $gym',
        '$count gerakan · disaring untuk $gym',
      );
  String get next => _('NEXT', 'BERIKUT');
  String get activeProgram => _('Active program', 'Program aktif');
  String get rotationNote => _(
        'Rotation · min 1 rest day between the same routine',
        'Rotasi · minimal 1 hari istirahat antar rutinitas yang sama',
      );
  String get routineActions => _('Routine actions', 'Aksi rutinitas');
  String elapsedOf(String time) => _('$time elapsed', '$time berjalan');
  String get cancelUpper => _('CANCEL', 'BATAL');
  String daysShort(int n) => _('${n}d', '${n}h');
  String get catalogueUnreadable => _(
        'Could not read the exercise catalogue.',
        'Katalog gerakan tidak bisa dibaca.',
      );
  String defaultSavedOnSync(String name) => _(
        'Default for $name will be saved once sync is on.',
        'Bawaan untuk $name tersimpan setelah sync aktif.',
      );
  String get fewer => _('Fewer', 'Kurangi');
  String get more => _('More', 'Tambah');

  // Teks yang hidup di dalam data contoh (template program, grup peralatan).
  // Disimpan sebagai peta terpisah supaya datanya tetap satu bahasa di kode dan
  // penerjemahan terjadi hanya saat digambar — kalau nanti template datang dari
  // Supabase, cukup peta ini yang menyusul.
  static const _catalogueId = <String, String>{
    '3 routines · rotation': '3 rutinitas · rotasi',
    '2 routines · rotation': '2 rutinitas · rotasi',
    '4 routines · rotation': '4 rutinitas · rotasi',
    '1 routine · rotation': '1 rutinitas · rotasi',
    '5 routines · Mon–Fri': '5 rutinitas · Sen–Jum',
    'Balanced volume, 3–6 sessions a week': 'Volume seimbang, 3–6 sesi seminggu',
    'Simple alternation, good for 4 days': 'Selang-seling sederhana, cocok 4 hari',
    'One muscle group per day': 'Satu kelompok otot per hari',
    '1 working set to failure, 3 rest days': '1 set kerja sampai gagal, 3 hari istirahat',
    'Everything every session': 'Semuanya tiap sesi',
    'Strength focus, linear progression': 'Fokus kekuatan, progresi linear',
    'Tuesday · 16 Sep': 'Selasa · 16 Sep',
    'September 2026': 'September 2026',
    '12 wk ago': '12 mgg lalu',
    '6 wk': '6 mgg',
    'now': 'sekarang',
    '90 d': '90 hr',
    '45 d': '45 hr',
    'Sets only': 'Set saja',
    'Update all': 'Perbarui semua',
    'Keep': 'Biarkan',
    'Free weights': 'Beban bebas',
    'Machines': 'Mesin',
    'Other': 'Lainnya',
  };

  String catalogue(String en) => _(en, _catalogueId[en] ?? en);

  String muscle(String en) => _(en, _muscleId[en] ?? en);
  String region(String en) => _(en, _regionId[en] ?? en);
}

/// Membawa bahasa terpilih ke seluruh pohon widget.
class AppStrings extends InheritedWidget {
  const AppStrings({super.key, required this.strings, required super.child});

  final Strings strings;

  static Strings of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<AppStrings>();
    // Tanpa pembungkus, jatuh ke bahasa Inggris. Lebih baik teks Inggris
    // daripada layar yang gagal dibangun karena setelan bahasa belum ada.
    return w?.strings ?? const Strings(AppLanguage.english);
  }

  @override
  bool updateShouldNotify(AppStrings old) => old.strings.lang != strings.lang;
}

extension StringsX on BuildContext {
  Strings get t => AppStrings.of(this);
}
