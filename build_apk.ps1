# ============================================================================
# Builds a RELEASE APK that talks to the CLOUD backend:
#   https://mechanicapp-service-621632382478.asia-south1.run.app
#
# Usage:
#   .\build_apk.ps1                    (normal fat APK -> app-release.apk)
#   .\build_apk.ps1 --split-per-abi    (smaller per-ABI APKs)
#   .\build_apk.ps1 -BaseUrl http://192.168.1.5:8080
#        (ONLY for testing on a REAL phone while your local backend is
#         reachable over Wi-Fi - plain localhost will NOT work on a phone,
#         because localhost on the phone means the phone itself)
#
# Notes:
# - The URL is baked into the APK at BUILD time (String.fromEnvironment),
#   so whatever you pass here is permanent for that APK file.
# - The Google Maps API key is read from the gitignored `.env` file and
#   passed via --dart-define, so it never goes to git. Android also
#   injects the same key into AndroidManifest.xml via gradle automatically.
# ============================================================================

param(
    [string]$BaseUrl = "https://mechanicapp-service-621632382478.asia-south1.run.app"
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

Write-Host ""
Write-Host ">>> Building RELEASE APK" -ForegroundColor Cyan
Write-Host ">>> Backend baked into this APK: $BaseUrl" -ForegroundColor Cyan
Write-Host ">>> Maps key: $(if ($mapsKey) { 'loaded from .env' } else { 'MISSING' })" -ForegroundColor $(if ($mapsKey) { 'Green' } else { 'Yellow' })
Write-Host ""

flutter build apk --release --dart-define=BASE_URL=$BaseUrl --dart-define=GOOGLE_MAPS_API_KEY=$mapsKey @args

Write-Host ""
Write-Host ">>> Done. APK output folder:" -ForegroundColor Green
Write-Host "    build\app\outputs\flutter-apk\"
