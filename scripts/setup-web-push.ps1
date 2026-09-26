# Isi env Vercel untuk fungsi alarm istirahat (web-api/api/rest-alarm.js).
#
# Dibaca dari .secrets/supabase.json dan .secrets/vapid.json (keduanya
# gitignored). Nilai tidak pernah dicetak. Aman dijalankan ulang: variabel
# lama dihapus dulu, lalu diisi lagi.
#
# Membuat kunci VAPID baru membuat semua langganan lama tidak berlaku: orang
# harus menyalakan ulang notifikasi di Profil. Jadi jangan buat ulang
# .secrets/vapid.json kecuali kunci privatnya bocor.
#
# Pakai: pwsh scripts/setup-web-push.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$supa = Get-Content (Join-Path $root '.secrets\supabase.json') -Raw | ConvertFrom-Json
$vapid = Get-Content (Join-Path $root '.secrets\vapid.json') -Raw | ConvertFrom-Json

$env:VERCEL_ORG_ID = 'team_UX8bS9Ox2sShcGlmYygJ69fY'
$env:VERCEL_PROJECT_ID = 'prj_kxhHMOYx3TjRlsnVbX68hvLl0rtB'

$vars = [ordered]@{
  SUPABASE_URL      = $supa.SUPABASE_URL
  SUPABASE_ANON_KEY = $supa.SUPABASE_ANON_KEY
  VAPID_PUBLIC_KEY  = $vapid.VAPID_PUBLIC_KEY
  VAPID_PRIVATE_KEY = $vapid.VAPID_PRIVATE_KEY
  REST_ALARM_SECRET = $vapid.REST_ALARM_SECRET
  # Identitas pengirim untuk layanan push (Apple, Google). URL aplikasi,
  # bukan email pribadi.
  VAPID_SUBJECT     = 'https://gymapps-hariz.vercel.app'
}

$ErrorActionPreference = 'Continue'
foreach ($name in $vars.Keys) {
  vercel env rm $name production --yes *> $null
  $vars[$name] | vercel env add $name production --sensitive *> $null
  if ($LASTEXITCODE -ne 0) { throw "vercel env add $name gagal ($LASTEXITCODE)" }
  Write-Host "ok $name"
}
