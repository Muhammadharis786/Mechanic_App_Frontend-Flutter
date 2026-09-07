# ============================================================================
# Runs the app against the LOCAL backend:  http://localhost:8080
#
# Usage:
#   .\run_local.ps1                    (Flutter asks which device to use)
#   .\run_local.ps1 -d chrome          (run on Chrome)
#   .\run_local.ps1 -d emulator-5554   (run on a specific Android emulator)
#
# Notes:
# - The Google Maps API key is read from the gitignored `.env` file and
#   passed to Flutter via --dart-define, so it never needs to be in git.
# - On the Android emulator, `localhost` is automatically remapped to
#   10.0.2.2 (your PC) inside the app, so the same command works.
# - For a real physical phone, pass your PC's Wi-Fi IP instead:
#   .\run_local.ps1 -BaseUrl http://192.168.1.5:8080
# ============================================================================
param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

# --- Read the Google Maps API key from the gitignored .env file ------------
$mapsKey = ""
if (Test-Path ".env") {
    $line = Get-Content ".env" |
        Where-Object { $_ -match '^\s*GOOGLE_MAPS_API_KEY\s*=' } |
        Select-Object -First 1
    if ($line) {
        $mapsKey = ($line -replace '^\s*GOOGLE_MAPS_API_KEY\s*=\s*', '').Trim().Trim('"').Trim("'")
    }
}

if (-not $mapsKey -or $mapsKey -like "PASTE_*") {
    Write-Warning "GOOGLE_MAPS_API_KEY not set in .env - map features will not work."
    Write-Warning "Copy .env.example to .env and paste your key."
    $mapsKey = ""
}

# --- Keep web/env.js in sync (used by web/index.html on the web build) -----
if ($mapsKey) {
    $envJs = "window.MAPS_API_KEY = '$mapsKey';"
    [System.IO.File]::WriteAllText((Join-Path $root "web\env.js"), $envJs)
}

Write-Host ""
Write-Host ">>> Backend: LOCAL ($BaseUrl)" -ForegroundColor Cyan
Write-Host ">>> Maps key: $(if ($mapsKey) { 'loaded from .env' } else { 'MISSING' })" -ForegroundColor $(if ($mapsKey) { 'Green' } else { 'Yellow' })
Write-Host ""

flutter run --dart-define=BASE_URL=$BaseUrl --dart-define=GOOGLE_MAPS_API_KEY=$mapsKey @args
