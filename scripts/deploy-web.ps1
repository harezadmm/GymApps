# Build versi web GymApps lalu unggah ke Vercel.
#
# Kredensial Supabase dibaca dari .secrets/supabase.json (lihat
# build-android.ps1). Versi web tidak punya mode lokal: tanpa server, orang
# tidak bisa masuk sama sekali, jadi build tanpa kredensial ditolak.
#
# Tautan proyek Vercel lewat env, bukan folder .vercel/ di build/web yang
# hilang setiap `flutter clean`. Kedua id ini bukan rahasia.
#
# Pakai:
#   pwsh scripts/deploy-web.ps1            # build + deploy produksi
#   pwsh scripts/deploy-web.ps1 -Preview   # build + deploy pratinjau (URL sekali pakai)
#   pwsh scripts/deploy-web.ps1 -BuildOnly # hanya build ke app/build/web
param(
  [switch]$Preview,
  [switch]$BuildOnly
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$secrets = Join-Path $root '.secrets\supabase.json'

if (-not (Test-Path $secrets)) {
  throw "Tidak ada $secrets. Versi web wajib punya server Supabase."
}
$cfg = Get-Content $secrets -Raw | ConvertFrom-Json
if (-not $cfg.SUPABASE_URL -or -not $cfg.SUPABASE_ANON_KEY) {
  throw "$secrets harus berisi SUPABASE_URL dan SUPABASE_ANON_KEY."
}
if ($cfg.SUPABASE_ANON_KEY -like 'sb_secret_*') {
  throw 'Itu secret key, bukan publishable key. Secret key tidak boleh masuk ke web.'
}
Write-Host "Sinkron: $($cfg.SUPABASE_URL)"

# flutter dan vercel menulis ke stderr untuk hal yang bukan kegagalan;
# kode keluarnya yang diperiksa.
$ErrorActionPreference = 'Continue'

# Kunci publik VAPID untuk notifikasi istirahat (Web Push). Hanya kunci
# publik yang masuk ke build; kunci privatnya disimpan di env Vercel
# (scripts/setup-web-push.ps1).
$vapidFile = Join-Path $root '.secrets\vapid.json'
$defines = @("--dart-define-from-file=$secrets")
if (Test-Path $vapidFile) {
  $vapid = Get-Content $vapidFile -Raw | ConvertFrom-Json
  $defines += "--dart-define=VAPID_PUBLIC_KEY=$($vapid.VAPID_PUBLIC_KEY)"
} else {
  Write-Host 'Tanpa .secrets/vapid.json: notifikasi istirahat web dimatikan di build ini.'
}

Push-Location (Join-Path $root 'app')
try {
  flutter build web --release @defines
  if ($LASTEXITCODE -ne 0) { throw "flutter build web gagal ($LASTEXITCODE)" }
} finally {
  Pop-Location
}

if ($BuildOnly) { exit 0 }

# Perintah yang tidak ditemukan tidak mengubah $LASTEXITCODE, jadi tanpa cek
# ini skrip berakhir "sukses" tanpa mengunggah apa pun.
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
  throw 'Vercel CLI tidak ditemukan. Pasang: npm i -g vercel, lalu vercel login.'
}

$env:VERCEL_ORG_ID = 'team_UX8bS9Ox2sShcGlmYygJ69fY'
$env:VERCEL_PROJECT_ID = 'prj_kxhHMOYx3TjRlsnVbX68hvLl0rtB'
$out = Join-Path $root 'app\build\web'
# Fungsi server (alarm istirahat) ikut diunggah di samping build Flutter.
Copy-Item -Recurse -Force (Join-Path $root 'web-api\api') $out
Copy-Item -Force (Join-Path $root 'web-api\package.json') $out
Copy-Item -Force (Join-Path $root 'web-api\vercel.json') $out
if ($Preview) {
  vercel deploy $out --yes
} else {
  vercel deploy $out --prod --yes
}
if ($LASTEXITCODE -ne 0) { throw "vercel deploy gagal ($LASTEXITCODE)" }
