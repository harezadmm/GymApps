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
        'This email already has an account. Sign in instead.',
        'Email ini sudah punya akun. Masuk saja.',
      );
  String get invalidCredentials => _('Email or password is wrong.', 'Email atau kata sandi salah.');
  String get authOffline => _(
        "Couldn't reach the server. Check your connection and try again.",
        'Server tidak terjangkau. Periksa koneksi lalu coba lagi.',
      );
  String get signUpRejected => _(
        'The server declined this sign-up. Try a longer password.',
        'Server menolak pendaftaran ini. Coba kata sandi yang lebih panjang.',
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
  String get otherSession => _('Other session', 'Pilih sesi lain');
  String get otherSessionTitle => _('What are you training today?', 'Hari ini latihan apa?');
  String get otherSessionHint => _(
        'The rotation carries on from whichever session you train.',
        'Rotasi lanjut dari sesi yang kamu kerjakan.',
      );
  String get otherSessionHintWeekday => _(
        'Your weekly schedule stays the same — this only changes today.',
        'Jadwal mingguanmu tetap — ini hanya mengganti latihan hari ini.',
      );
  String get upNext => _('UP NEXT', 'BERIKUTNYA');
  String get notInProgram => _('Not in the rotation', 'Di luar rotasi');
  String get thisWeek => _('This week', 'Minggu ini');
  String plannedOf(int done, int total) =>
      _('$done of $total planned', '$done dari $total rencana');
  String get volume7d => _('Volume 7d', 'Volume 7 hari');
  String get e1rmUp => _('e1RM up', 'e1RM naik');
  String get sinceLast => _('Since last', 'Sejak terakhir');
  String moreItems(int n) => _('+$n more', '+$n lagi');
  String exerciseCount(int n) => _(n == 1 ? '1 exercise' : '$n exercises', '$n gerakan');

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
  String weightCol(String unit) => unit == 'lb' ? 'Lb' : 'Kg';
  String get repsCol => _('Reps', 'Rep');
  String targetLine(String weight, int reps, String policy, String unit) =>
      _('Target $weight $unit × $reps · $policy', 'Target $weight $unit × $reps · $policy');
  String setsTarget(int n, String weight, int reps, String unit) =>
      _('${n == 1 ? '1 set' : '$n sets'} · target $weight $unit × $reps', '$n set · target $weight $unit × $reps');
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
  String setsSuffix(int n) => _(n == 1 ? '1 set' : '$n sets', '$n set');
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
  String get syncNoSession => _('Not connected to the server — tap "Force sync now"',
      'Belum tersambung ke server — ketuk "Paksa sync sekarang"');
  String get connectTitle => _('Connect to the server', 'Sambungkan ke server');
  String get connectBody => _(
        'Enter your account password once to start syncing this account.',
        'Masukkan kata sandi akunmu sekali untuk mulai menyinkronkan akun ini.',
      );
  String get connecting => _('Connecting…', 'Menyambungkan…');
  String get serverRejected => _(
        'The server has a different password for this email. Enter the password you use on your other device.',
        'Server punya kata sandi lain untuk email ini. Masukkan kata sandi yang kamu pakai di HP lain.',
      );
  String get connect => _('Connect', 'Sambungkan');
  String get serverUnreachable => _(
        "Couldn't reach the server. Your data is safe on this phone — try again when you're online.",
        'Server tidak terjangkau. Data aman di HP ini — coba lagi saat online.',
      );
  String get syncOffHint => _(
        'This build has no server configured, so everything stays on this device.',
        'Build ini tidak punya server, jadi semua data hanya tersimpan di HP ini.',
      );
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
  String get themeTitle => _('Theme', 'Tema');
  String get seeAll => _('See all', 'Lihat semua');
  String get quickActions => _('Quick actions', 'Aksi cepat');
  String get openProfile => _('Open profile', 'Buka profil');
  String get allBodyParts => _('All', 'Semua');
  String get noStrengthYet => _('No lifts logged yet', 'Belum ada angkatan tercatat');
  String get restPushTitle => _('Rest alerts on lock screen', 'Tanda istirahat di layar terkunci');
  String get restPushOn => _('On', 'Nyala');
  String get restPushOff => _('Off', 'Mati');
  String get restPushBlocked => _('Blocked in settings', 'Diblokir di pengaturan');
  String get restPushNeedsHome => _('Add to Home Screen first', 'Pasang ke Home Screen dulu');
  String get restPushHowTo => _(
        'On iPhone, notifications only work from the Home Screen app: in Safari tap Share → Add to Home Screen, then open GymApps from its icon.',
        'Di iPhone, notifikasi hanya jalan dari aplikasi di Home Screen: di Safari ketuk Bagikan → Tambahkan ke Layar Utama, lalu buka GymApps dari ikonnya.');
  String get restPushBlockedHow => _(
        'Notifications are blocked. Allow them for GymApps in Settings → Notifications, then try again.',
        'Notifikasi diblokir. Izinkan untuk GymApps di Pengaturan → Notifikasi, lalu coba lagi.');
  String get restPushEnabled => _(
        'Done — your phone will ring when rest is over, even locked.',
        'Beres — HP akan berbunyi saat istirahat habis, walau terkunci.');
  String get themeDark => _('Dark', 'Gelap');
  String get themeLight => _('Light', 'Terang');
  String get themeSystem => _('Match system', 'Ikuti sistem');
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
  String routineMeta(int exercises, int sets) => _(
        '${exercises == 1 ? '1 exercise' : '$exercises exercises'} · ${sets == 1 ? '1 set' : '$sets sets'}',
        '$exercises gerakan · $sets set',
      );
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
    'No automatic progression': 'Tanpa progresi otomatis',
    'Linear progression': 'Progresi linear',
    'Double progression': 'Progresi ganda',
    'Add time': 'Tambah waktu',
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

  // ── Split buatan sendiri, rutinitas, dan sesi (perbaikan 2026-09) ────────
  String get customSplit => _('Build your split', 'Susun split-mu');
  String get customSplitSub => _(
        'Name each training day, then add its exercises. You can change all of it later.',
        'Beri nama setiap hari latihan, lalu isi gerakannya. Semuanya bisa diubah nanti.',
      );
  String get splitName => _('Split name', 'Nama split');
  String get splitNameHint => _('e.g. My PPL', 'mis. PPL-ku');
  String get mySplit => _('My split', 'Split-ku');
  String get scheduling => _('Scheduling', 'Penjadwalan');
  String get rotationMode => _('Rotation', 'Rotasi');
  String get weekdayMode => _('Fixed days', 'Hari tetap');
  String get rotationModeNote => _(
        'Sessions follow the order below. A missed day never shifts the plan.',
        'Sesi mengikuti urutan di bawah. Hari yang terlewat tidak menggeser rencana.',
      );
  String get weekdayModeNote => _(
        'Pick your training days. Routines are assigned to them in order.',
        'Pilih hari latihanmu. Rutinitas dibagikan ke hari-hari itu berurutan.',
      );
  String get restDaysBetween => _('Rest days after a session', 'Hari istirahat setelah sesi');
  String restDaysValue(int n) =>
      n == 0 ? _('None', 'Tidak ada') : _(n == 1 ? '1 day' : '$n days', '$n hari');
  String get trainingDays => _('Training days', 'Hari latihan');
  String get days => _('Days', 'Hari');
  String dayName(int i) => _('Day $i', 'Hari $i');
  String get addDay => _('ADD DAY', 'TAMBAH HARI');
  String get tapToAddExercises => _('Tap to add exercises', 'Ketuk untuk isi gerakan');
  String get needOneDay => _('Add at least one training day.', 'Tambahkan minimal satu hari latihan.');
  String get needOneWeekday => _('Pick at least one training day.', 'Pilih minimal satu hari latihan.');
  String get emptyDaysNote => _(
        'Days without exercises can be filled later from the Workout tab.',
        'Hari tanpa gerakan bisa diisi nanti dari tab Latihan.',
      );
  String get removeDay => _('Remove day', 'Hapus hari');
  String weekdayShort(int d) => _(
        const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1],
        const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][d - 1],
      );
  String weekdayLong(int d) => _(
        const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d - 1],
        const ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][d - 1],
      );
  String monthShort(int m) => _(
        const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1],
        const ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'][m - 1],
      );
  String get dueTomorrow => _('TOMORROW', 'BESOK');
  String dueOn(String day) => _('DUE $day', day.toUpperCase());
  String recoverUntil(String day) => _('Recover first — due $day', 'Pulih dulu — jatuh tempo $day');
  String nextTrainingDay(String day) => _('Next training day: $day', 'Hari latihan berikutnya: $day');
  String weekdayOf(String program) => _('$program · fixed days', '$program · hari tetap');
  String get noProgramYet => _('No program yet', 'Belum ada program');
  String get noProgramHint => _(
        'Pick a template or build your own split from the Workout tab.',
        'Pilih template atau susun split sendiri dari tab Latihan.',
      );
  String get emptyRoutineHint => _(
        'This routine has no exercises yet. Add some before starting.',
        'Rutinitas ini belum punya gerakan. Isi dulu sebelum mulai.',
      );
  String get choosePlan => _('CHOOSE PROGRAM', 'PILIH PROGRAM');
  String routineOverview(int exercises, int sets) => _(
        '${exercises == 1 ? '1 exercise' : '$exercises exercises'} · ${sets == 1 ? '1 working set' : '$sets working sets'}',
        '$exercises gerakan · $sets set kerja',
      );
  String get notTrainedYet => _('not trained yet', 'belum pernah dilatih');
  String lastTrained(int days) => days == 0
      ? _('last trained today', 'terakhir dilatih hari ini')
      : _('last trained $days days ago', 'terakhir dilatih $days hari lalu');
  String get skipped => _('Session skipped.', 'Sesi dilewati.');
  String get setAsNext => _('Make next', 'Jadikan berikutnya');
  String get changeProgram => _('Change program', 'Ganti program');
  String get changeProgramBody => _(
        'Your routines are replaced by the new program. Logged sessions stay in your history.',
        'Rutinitasmu diganti dengan program baru. Sesi yang sudah tercatat tetap ada di riwayat.',
      );
  String get replace => _('REPLACE', 'GANTI');
  String restRule(int n) => n == 0
      ? _('No minimum rest between sessions', 'Tanpa istirahat minimum antar sesi')
      : _(n == 1 ? 'At least 1 rest day between sessions' : 'At least $n rest days between sessions',
          'Minimal $n hari istirahat antar sesi');
  String get order => _('Order', 'Urutan');
  String get moveUp => _('Move up', 'Naikkan');
  String get moveDown => _('Move down', 'Turunkan');
  String get replaceExercise => _('Replace exercise', 'Ganti gerakan');
  String get removeExercise => _('Remove exercise', 'Hapus gerakan');
  String get addWarmup => _('Add warm-up set', 'Tambah set warm-up');
  String get removeLastSet => _('Remove last set', 'Hapus set terakhir');
  String get exerciseActions => _('Exercise actions', 'Aksi gerakan');
  String get pickExercise => _('Pick an exercise', 'Pilih gerakan');
  String get startingWeight => _('Starting weight', 'Beban awal');
  String get warmups => _('Warm-up sets', 'Set warm-up');
  String get repRange => _('Rep range', 'Rentang rep');
  String get noExercisesYet => _('No exercises yet.', 'Belum ada gerakan.');
  String get leaveSessionTitle => _('Leave this session?', 'Tinggalkan sesi ini?');
  String get leaveSessionBody => _(
        'Finish saves it to your history. Discard throws away everything logged in this session.',
        'Selesai menyimpannya ke riwayat. Buang menghapus semua yang tercatat di sesi ini.',
      );
  String get keepTraining => _('KEEP TRAINING', 'LANJUT LATIHAN');
  String get discard => _('DISCARD', 'BUANG');
  String get finishAndSave => _('FINISH & SAVE', 'SELESAI & SIMPAN');
  String get emptySessionHint => _(
        'No exercises yet — add the first one below.',
        'Belum ada gerakan — tambah yang pertama di bawah.',
      );
  String get exerciseDetails => _('Exercise details', 'Detail gerakan');
  String get targetMuscle => _('Target', 'Otot target');
  String get secondaryMuscles => _('Also works', 'Ikut terlatih');
  String get equipmentLabel => _('Equipment', 'Alat');
  String get comingSoonTitle => _('Not available yet', 'Belum tersedia');
  String get discardChangesTitle => _('Save your changes?', 'Simpan perubahanmu?');
  String sessionDiffers(String routine) =>
      _('This session differs from $routine', 'Sesi ini berbeda dari $routine');
  String libraryCount(String n) => _('$n exercises', '$n gerakan');
  String addAsCustom(String q) =>
      _('Add "$q" as custom exercise', 'Tambah "$q" sebagai gerakan sendiri');
  String get cantFindIt => _("Can't find it?", 'Tidak ketemu?');
  String get newCustomExercise => _('New custom exercise', 'Gerakan sendiri baru');
  String get exerciseNameLabel => _('Exercise name', 'Nama gerakan');
  String get exerciseNameHint => _('e.g. Single arm lat pulldown', 'mis. Single arm lat pulldown');
  String get mainMuscle => _('Main muscle', 'Otot utama');
  String get needExerciseName => _('Give the exercise a name.', 'Beri nama gerakannya.');
  String get needMuscle => _('Pick the main muscle.', 'Pilih otot utamanya.');
  String get customTag => _('CUSTOM', 'SENDIRI');
  String customSaved(String name) =>
      _('$name added to your exercises.', '$name masuk ke daftar gerakanmu.');
  String sessionsCount(int n) => n == 1 ? _('1 session', '1 sesi') : _('$n sessions', '$n sesi');

  String catalogue(String en) => _(en, _catalogueId[en] ?? en);

  /// Alasan di balik target sesi ([Prescription.why]). Kalimatnya dibentuk
  /// di lapisan domain dalam bahasa Inggris (angka sudah terisi), jadi di sini
  /// dicocokkan pola per pola. Kalimat yang tak dikenal dibiarkan apa adanya —
  /// lebih baik bahasa Inggris daripada kosong.
  String why(String en) {
    if (lang == AppLanguage.english) return en;
    for (final (pattern, build) in _whyId) {
      final m = pattern.firstMatch(en);
      if (m != null) return build(m);
    }
    return en;
  }


  // ── v1.7: sesi, riwayat, setelan, fitur baru ─────────────────────────────
  String policy(String en) => catalogue(en);
  String get restOverTitle => _('Rest over', 'Istirahat selesai');
  String restSavedFor(String name) =>
      _('Rest for $name saved as your default.', 'Istirahat $name disimpan sebagai bawaan.');
  String restOverBody(String next) => _(next.isEmpty ? 'Back to it.' : next, next.isEmpty ? 'Lanjut latihan.' : next);
  String nextExerciseLine(String name) => _('Next: $name', 'Berikutnya: $name');
  String get replaceConfirmTitle => _('Replace exercise?', 'Ganti gerakan?');
  String replaceConfirmBody(int n) => _(
        '$n logged set${n == 1 ? '' : 's'} of this exercise will be removed from the session.',
        '$n set yang sudah dicentang di gerakan ini akan dibuang dari sesi.',
      );
  String get removeSetConfirmTitle => _('Remove a logged set?', 'Hapus set yang sudah dicentang?');
  String get removeSetConfirmBody =>
      _('The last set is already ticked. It will be removed.', 'Set terakhir sudah dicentang. Set itu akan dihapus.');
  String get addDropSet => _('Add drop set', 'Tambah drop set');
  String get addRestPause => _('Add rest-pause', 'Tambah rest-pause');
  String get supersetWithNext => _('Superset with next', 'Superset dengan berikutnya');
  String get endSuperset => _('End superset', 'Akhiri superset');
  String get supersetBadge => _('SUPERSET', 'SUPERSET');
  String get exerciseNote => _('Note', 'Catatan');
  String get exerciseNoteHint => _('e.g. seat position 4, wide grip', 'mis. kursi posisi 4, grip lebar');
  String lastNote(String n) => _('Last time: $n', 'Terakhir: $n');
  String get exerciseHistory => _('History & records', 'Riwayat & rekor');
  String get rirPrompt => _('Reps in reserve', 'Sisa rep (RIR)');
  String get secCol => _('Sec', 'Detik');
  String get resumeTitle => _('Unfinished session', 'Sesi belum selesai');
  String resumeDetail(String name, int sets, int minutes) => _(
      '$name · $sets set${sets == 1 ? '' : 's'} logged · $minutes min', '$name · $sets set tercatat · $minutes menit');
  String get resume => _('RESUME', 'LANJUTKAN');
  String get discardDraft => _('Discard', 'Buang');
  String get discardDraftConfirm => _('Discard the unfinished session? Its logged sets will be lost.',
      'Buang sesi yang belum selesai? Set yang sudah dicentang akan hilang.');
  String get prHeaviest => _('Heaviest', 'Terberat');
  String get prBestE1rm => _('Best e1RM', 'e1RM terbaik');
  String get prBestVolume => _('Best session', 'Sesi terbaik');
  String get noExerciseHistory => _('No sessions logged for this exercise yet.', 'Belum ada sesi untuk gerakan ini.');
  String get editSession => _('Edit session', 'Edit sesi');
  String get edit => _('EDIT', 'EDIT');
  String get sessionUpdated => _('Session updated.', 'Sesi diperbarui.');
  String get notesLabel => _('Notes', 'Catatan');
  String get on => _('On', 'Nyala');
  String get unitsTitle => _('Weight unit', 'Satuan beban');
  String get unitsNote => _(
        'Everything you logged stays the same — only how it is shown changes. Plate jumps follow the unit (2.5/5 kg or 5/10 lb).',
        'Semua catatanmu tetap sama — yang berubah hanya cara tampilnya. Lompatan pelat ikut satuan (2,5/5 kg atau 5/10 lb).');
  String get logRir => _('Log reps in reserve (RIR)', 'Catat sisa rep (RIR)');
  String get myEquipment => _('Equipment at my gym', 'Alat di gym-ku');
  String get equipmentAll => _('All equipment', 'Semua alat');
  String equipmentCount(int n) => _('$n groups', '$n kelompok');
  String equipmentGroup(String key) => switch (key) {
        'barbell' => _('Barbell & plates', 'Barbel & pelat'),
        'dumbbell' => _('Dumbbells', 'Dumbel'),
        'kettlebell' => _('Kettlebells', 'Kettlebell'),
        'cable' => _('Cable station', 'Stasiun kabel'),
        'machine' => _('Machines (lever, Smith, sled)', 'Mesin (lever, Smith, sled)'),
        'band' => _('Resistance bands', 'Resistance band'),
        'balls' => _('Balls & rollers', 'Bola & roller'),
        'cardio' => _('Cardio machines', 'Mesin kardio'),
        _ => key,
      };
  String get equipmentNote => _('Bodyweight exercises are always shown.', 'Gerakan bodyweight selalu ditampilkan.');
  String exportSaved(String name) => _('Backup saved: $name', 'Cadangan disimpan: $name');
  String get exportFailed => _("Couldn't save the backup.", 'Cadangan gagal disimpan.');
  String importDone(int n) => _('Imported — $n new session${n == 1 ? '' : 's'}.', 'Diimpor — $n sesi baru.');
  String get importFailed => _('That file is not a GymApps backup.', 'File itu bukan cadangan GymApps.');
  String get importConfirmTitle => _('Import backup?', 'Impor cadangan?');
  String get importConfirmBody => _(
        'Sessions and custom exercises are merged into this account. Nothing here is deleted.',
        'Sesi dan gerakan custom digabung ke akun ini. Tidak ada yang dihapus.',
      );
  String get importAction => _('IMPORT', 'IMPOR');
  String get accentBlue => _('Sky blue', 'Biru langit');
  String get accentGreen => _('Green', 'Hijau');
  String get accentOrange => _('Orange', 'Oranye');
  String get accentPink => _('Pink', 'Merah muda');
  String get accentViolet => _('Violet', 'Ungu');
  String get aboutBody => _(
        'Personal gym logger. Targets are calculated from your own history; data is stored on this device first and synced to your account.',
        'Pencatat latihan pribadi. Target dihitung dari riwayatmu sendiri; data disimpan di perangkat dulu lalu disinkronkan ke akunmu.',
      );
  String get licences => _('Open-source licences', 'Lisensi open-source');
  String get myEquipmentOnly => _('My equipment', 'Alat saya');
  String get measuredBy => _('Measured by', 'Diukur dengan');
  String get modeReps => _('Reps', 'Rep');
  String get modeTime => _('Time', 'Waktu');
  String get targetSeconds => _('Target time', 'Target waktu');
  String get repCeiling => _('Rep ceiling, then add a set', 'Plafon rep, lalu tambah set');
  String bodyPart(String key) => switch (key) {
        'chest' => _('Chest', 'Dada'),
        'back' => _('Back', 'Punggung'),
        'shoulders' => _('Shoulders', 'Bahu'),
        'upper arms' => _('Upper arms', 'Lengan atas'),
        'lower arms' => _('Forearms', 'Lengan bawah'),
        'upper legs' => _('Upper legs', 'Paha'),
        'lower legs' => _('Calves', 'Betis'),
        'waist' => _('Core', 'Perut'),
        'cardio' => _('Cardio', 'Kardio'),
        _ => key,
      };
  String get allMuscles => _('All muscles', 'Semua otot');
  String get scheduleTitle => _('Schedule', 'Jadwal');
  String get bodyweightTitle => _('Bodyweight', 'Berat badan');
  String get logBodyweight => _('Log bodyweight', 'Catat berat badan');
  String get bodyweightNone => _('No entries yet — log one to track the trend.', 'Belum ada catatan — catat untuk melihat tren.');
  String bodyweightChange(String delta, int days, String unit) =>
      _('$delta $unit over $days days', '$delta $unit dalam $days hari');
  String get dashboard => _('Dashboard', 'Dashboard');
  String get openDashboard => _('Open dashboard', 'Buka dashboard');
  String get e1rmByWeek => _('e1RM by week — last 12 weeks', 'e1RM per minggu — 12 minggu terakhir');
  String get stalledLifts => _('Stalled for 3+ weeks', 'Stagnan 3+ minggu');
  String get noneStalled =>
      _('Nothing stalled — every lift moved in the last 3 weeks.', 'Tidak ada yang stagnan — semua gerakan naik dalam 3 minggu terakhir.');
  String get sessionsPerWeek => _('Sessions per week', 'Sesi per minggu');
  String stalledSince(String w, int weeks, String unit) =>
      _('best $w $unit, flat for $weeks weeks', 'terbaik $w $unit, datar $weeks minggu');
  String get forgotTitle => _('Reset password', 'Reset kata sandi');
  String get forgotBody => _(
        "We'll email you a link to set a new password. Open it, set the new password, then sign in here with it.",
        'Link untuk kata sandi baru akan dikirim ke email-mu. Buka link-nya, setel kata sandi baru, lalu masuk di sini dengannya.',
      );
  String get sendLink => _('SEND LINK', 'KIRIM LINK');
  String get forgotSent => _('If that email has an account, a reset link is on its way.',
      'Kalau email itu punya akun, link reset sedang dikirim.');
  String get forgotNoServer => _('Password reset needs the server, and this build has none.',
      'Reset kata sandi butuh server, dan build ini tidak punya.');
  String get newPasswordTitle => _('Set a new password', 'Setel kata sandi baru');
  String get passwordUpdated => _('Password updated — you are signed in.', 'Kata sandi diperbarui — kamu sudah masuk.');
  String get signUpConfirmEmail => _('Check your email to confirm the account, then sign in.',
      'Cek email untuk konfirmasi akun, lalu masuk.');

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

String _g(Match m, int i) => m.group(i)!;

final List<(RegExp, String Function(Match))> _whyId = [
  (RegExp(r'^Automatic progression is off for this exercise\.$'),
      (_) => 'Progresi otomatis dimatikan untuk gerakan ini.'),
  (RegExp(r'^Nothing logged yet — this session is the starting point\.$'),
      (_) => 'Belum ada catatan — sesi ini jadi titik awal.'),
  (RegExp(r'^Full hold on every set — target up (\S+)s\.$'),
      (m) => 'Tahan penuh di semua set — target naik ${_g(m, 1)} dtk.'),
  (RegExp(r'^Short (\d+) sessions running — back to (\S+)s, then build again\.$'),
      (m) => 'Kurang ${_g(m, 1)} sesi beruntun — kembali ke ${_g(m, 2)} dtk, lalu naik lagi.'),
  (RegExp(r'^Came up short last time — same target again\.$'), (_) => 'Kemarin kurang — target sama lagi.'),
  (RegExp(r'^Bodyweight — same target until every set is clean\.$'),
      (_) => 'Bodyweight — target sama sampai semua set bersih.'),
  (RegExp(r'^(\d+) reps on every set — add a set, reps back to (\d+)\.$'),
      (m) => '${_g(m, 1)} rep di semua set — tambah satu set, rep kembali ke ${_g(m, 2)}.'),
  (RegExp(r'^(\d+) × (\d+) — time for added load or a harder variation\.$'),
      (m) => '${_g(m, 1)} × ${_g(m, 2)} — saatnya tambah beban atau variasi yang lebih berat.'),
  (RegExp(r'^Bodyweight — all reps hit, go for (\d+) this time\.$'),
      (m) => 'Bodyweight — semua rep tercapai, kejar ${_g(m, 1)} kali ini.'),
  (RegExp(r'^Top of the rep range on every set — \+([\d.]+) (\w+), reps back to (\d+)\.$'),
      (m) => 'Batas atas rentang rep di semua set — +${_g(m, 1)} ${_g(m, 2)}, rep kembali ke ${_g(m, 3)}.'),
  (RegExp(r'^Stalled (\d+) sessions — deload to ([\d.]+) (\w+)\.$'),
      (m) => 'Mandek ${_g(m, 1)} sesi — deload ke ${_g(m, 2)} ${_g(m, 3)}.'),
  (RegExp(r'^Same weight — go for (\d+) reps this time\.$'),
      (m) => 'Beban sama — kejar ${_g(m, 1)} rep kali ini.'),
  (RegExp(r'^Last set (\d+) reps — double the target, so a double jump of \+([\d.]+) (\w+)\.$'),
      (m) => 'Set terakhir ${_g(m, 1)} rep — dua kali target, jadi lompat ganda +${_g(m, 2)} ${_g(m, 3)}.'),
  (RegExp(r'^\+([\d.]+) (\w+) — all reps hit last session\.$'),
      (m) => '+${_g(m, 1)} ${_g(m, 2)} — semua rep tercapai di sesi lalu.'),
  (RegExp(r'^Reps short (\d+) sessions running — reset to ([\d.]+) (\w+) and climb again\.$'),
      (m) => 'Rep kurang ${_g(m, 1)} sesi beruntun — reset ke ${_g(m, 2)} ${_g(m, 3)} lalu naik lagi.'),
  (RegExp(r'^Reps short — reset to ([\d.]+) (\w+) and climb again\.$'),
      (m) => 'Rep kurang — reset ke ${_g(m, 1)} ${_g(m, 2)} lalu naik lagi.'),
  (RegExp(r'^Reps short last session — same weight again \((\d+) of (\d+) to go\)\.$'),
      (m) => 'Rep kurang di sesi lalu — beban sama lagi (sisa ${_g(m, 1)} dari ${_g(m, 2)}).'),
  (RegExp(r'^(\d+) reps on bodyweight — past the top of the range\. Add load \(belt, vest\) or a harder variation\.$'),
      (m) => '${_g(m, 1)} rep bodyweight — lewat batas atas rentang. Tambah beban (sabuk, rompi) atau variasi yang lebih berat.'),
  (RegExp(r'^(\d+) reps on bodyweight — go for (\d+)\.$'),
      (m) => '${_g(m, 1)} rep bodyweight — kejar ${_g(m, 2)}.'),
  (RegExp(r'^(\d+) reps, under (\d+) — same target\. Consider an extra rest day\.$'),
      (m) => '${_g(m, 1)} rep, di bawah ${_g(m, 2)} — target sama. Pertimbangkan tambah hari istirahat.'),
  (RegExp(r'^(\d+) reps — past the top of the range, \+([\d.]+) (\w+) and reps back to (\d+)\.$'),
      (m) => '${_g(m, 1)} rep — lewat batas atas rentang, +${_g(m, 2)} ${_g(m, 3)} dan rep kembali ke ${_g(m, 4)}.'),
  (RegExp(r'^(\d+) reps — still inside the range, same weight, go for (\d+)\.$'),
      (m) => '${_g(m, 1)} rep — masih dalam rentang, beban sama, kejar ${_g(m, 2)}.'),
  (RegExp(r'^Two sessions running under (\d+) reps — deload to ([\d.]+) (\w+)\. Consider adding a rest day\.$'),
      (m) => 'Dua sesi beruntun di bawah ${_g(m, 1)} rep — deload ke ${_g(m, 2)} ${_g(m, 3)}. Pertimbangkan tambah hari istirahat.'),
  (RegExp(r'^(\d+) reps, under (\d+) — same weight again before deciding to deload\.$'),
      (m) => '${_g(m, 1)} rep, di bawah ${_g(m, 2)} — beban sama lagi sebelum memutuskan deload.'),
];
