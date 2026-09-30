# Build APK rilis GymApps - dengan sinkron Supabase dan kunci rilis.
#
# Kenapa skrip ini ada: v1.5.0 dan v1.5.1 dibuild tanpa --dart-define, jadi
# aplikasinya jalan tapi Profil menulis "Sync off - local only" dan tidak ada
# satu sesi pun yang pernah naik ke server. Skrip ini menolak build rilis tanpa
# kredensial, kecuali memang diminta dengan -NoSync.
#
# Kredensial dibaca dari .secrets/supabase.json (gitignored):
#   {
#     "SUPABASE_URL": "https://<project-ref>.supabase.co",
#     "SUPABASE_ANON_KEY": "sb_publishable_... atau anon key JWT"
#   }
# Publishable/anon key aman berada di APK - RLS di tabel user_state yang menjaga
# data tiap akun (NFR-6). Service role key TIDAK PERNAH boleh masuk ke sini.
#
# Kunci rilis dibaca Gradle dari app/android/key.properties (gitignored; cara
# membuatnya di docs/RELEASE.md). Tanpa berkas itu Gradle memakai debug key,
# dan APK-nya tidak bisa memperbarui APK yang ditandatangani kunci asli - orang
# harus uninstall dan kehilangan data lokal. Jadi build rilis tanpa
# key.properties DITOLAK, kecuali diminta dengan -DebugSign (untuk uji di HP
# sendiri; jangan dibagikan). Build -Emulator selalu debug key.
#
# Pakai:
#   pwsh scripts/build-android.ps1            # 3 APK rilis per ABI, dengan sync
#   pwsh scripts/build-android.ps1 -Emulator  # APK debug x86_64 untuk emulator
#   pwsh scripts/build-android.ps1 -NoSync    # sengaja tanpa server
#   pwsh scripts/build-android.ps1 -DebugSign # rilis dengan debug key, hanya uji
param(
  [switch]$Emulator,
  [switch]$NoSync,
  [switch]$DebugSign
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$secrets = Join-Path $root '.secrets\supabase.json'
$keyProperties = Join-Path $root 'app\android\key.properties'

$defines = @()
if (-not $NoSync) {
  if (-not (Test-Path $secrets)) {
    throw "Tidak ada $secrets. Build tanpa file ini = aplikasi tanpa sinkron. Buat filenya, atau jalankan dengan -NoSync kalau memang disengaja."
  }
  $cfg = Get-Content $secrets -Raw | ConvertFrom-Json
  if (-not $cfg.SUPABASE_URL -or -not $cfg.SUPABASE_ANON_KEY) {
    throw "$secrets harus berisi SUPABASE_URL dan SUPABASE_ANON_KEY."
  }
  if ($cfg.SUPABASE_ANON_KEY -like 'sb_secret_*') {
    throw 'Itu secret key, bukan publishable key. Secret key tidak boleh masuk APK.'
  }
  $defines = @("--dart-define-from-file=$secrets")
  Write-Host "Sinkron: $($cfg.SUPABASE_URL)"
} else {
  Write-Warning 'Build TANPA sinkron Supabase - data hanya tersimpan di HP.'
}

if (-not $Emulator) {
  if (Test-Path $keyProperties) {
    Write-Host "Kunci rilis: $keyProperties"
  } elseif ($DebugSign) {
    Write-Warning 'Build rilis ditandatangani DEBUG KEY - hanya untuk uji, jangan dibagikan (docs/RELEASE.md).'
  } else {
    throw "Tidak ada $keyProperties. APK rilis tanpa kunci asli tidak bisa memperbarui yang sudah terpasang. Buat kuncinya (docs/RELEASE.md), atau jalankan dengan -DebugSign kalau hanya untuk uji."
  }
}

# flutter menulis peringatan ke stderr; di PowerShell 5.1 itu jadi ErrorRecord
# dan 'Stop' akan membatalkan build yang sebenarnya berhasil. Kode keluarnya
# yang diperiksa.
$ErrorActionPreference = 'Continue'

Push-Location (Join-Path $root 'app')
try {
  if ($Emulator) {
    flutter build apk --debug --target-platform android-x64 @defines
  } else {
    flutter build apk --release --split-per-abi @defines
  }
  if ($LASTEXITCODE -ne 0) { throw "flutter build gagal ($LASTEXITCODE)" }
} finally {
  Pop-Location
}
