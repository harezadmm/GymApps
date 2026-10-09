# Isi env Vercel untuk analisis AI recap (GEMINI_API_KEY) dari
# .secrets/gemini.json (di-gitignore). Kunci ini hanya hidup di server: fungsi
# /api/recap-analyze memakainya, APK dan bundel web tidak pernah memegangnya.
#
# Jalankan sekali, dan setiap kali kuncinya diganti:
#   powershell -ExecutionPolicy Bypass -File scripts/setup-gemini.ps1
# Lalu deploy ulang (scripts/deploy-web.ps1) supaya fungsinya memakai nilai baru.
#
# Isi .secrets/gemini.json:  { "GEMINI_API_KEY": "<kunci dari Google AI Studio>" }
# Opsional di Vercel (tidak diisi skrip ini): GEMINI_MODELS (daftar model,
# dipisah koma) dan AI_DAILY_LIMIT (bawaan 20 analisis per akun per hari).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$file = Join-Path $root '.secrets\gemini.json'
if (-not (Test-Path $file)) {
  throw "Tidak ada $file. Buat dengan isi { ""GEMINI_API_KEY"": ""..."" }."
}
$cfg = Get-Content $file -Raw | ConvertFrom-Json
if (-not $cfg.GEMINI_API_KEY) { throw "$file harus berisi GEMINI_API_KEY." }
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
  throw 'Vercel CLI tidak ditemukan. Pasang: npm i -g vercel, lalu vercel login.'
}
$env:VERCEL_ORG_ID = 'team_UX8bS9Ox2sShcGlmYygJ69fY'
$env:VERCEL_PROJECT_ID = 'prj_kxhHMOYx3TjRlsnVbX68hvLl0rtB'
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
$ErrorActionPreference = 'Continue'
vercel env rm GEMINI_API_KEY production --yes *> $null
$cfg.GEMINI_API_KEY | vercel env add GEMINI_API_KEY production --sensitive *> $null
if ($LASTEXITCODE -ne 0) { throw "vercel env add GEMINI_API_KEY gagal ($LASTEXITCODE)" }
Write-Host 'ok GEMINI_API_KEY (production)'
