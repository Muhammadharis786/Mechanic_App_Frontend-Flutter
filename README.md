# 🔧 ONFIX — Your Roadside Mechanic, On Demand

<div align="center">

**Connecting drivers with nearby mechanics — instantly.**

A two-sided Flutter marketplace that connects vehicle owners with verified nearby mechanics in real time, built for the **Alibaba AI Hackathon**.

`Flutter` · `Spring Boot (Cloud Run)` · `WebSocket (STOMP)` · `Google Maps` · `Firebase FCM`

</div>

---

## 📖 Table of Contents

1. [About ONFIX](#-about-onfix)
2. [Key Features](#-key-features)
3. [Tech Stack & Architecture](#-tech-stack--architecture)
4. [Quick Start (TL;DR)](#-quick-start-tldr)
5. [Prerequisites](#-prerequisites)
6. [Installation](#-installation)
7. [API Key Setup (Google Maps)](#-api-key-setup-google-maps)
8. [Running the App](#-running-the-app)
9. [Building a Release APK](#-building-a-release-apk)
10. [Project Structure](#-project-structure)
11. [Configuration Reference](#-configuration-reference)
12. [CI/CD](#-cicd)
13. [Security Notes](#-security-notes)
14. [Troubleshooting](#-troubleshooting)

---

## 🚗 About ONFIX

Every driver's nightmare: a vehicle breakdown with no fast, reliable way to find help nearby. ONFIX solves this with a real-time, two-sided marketplace:

- **For Users:** Find nearby mechanics on a live map, send service requests (emergency broadcast or pick a specific mechanic), track the mechanic's GPS location en route, book appointments, and rate the service.
- **For Mechanics:** Go online/offline with a single toggle, receive instant request alerts, navigate to the customer via live map, manage subscriptions, and track earnings.

The full request lifecycle — from tapping "Request" to the mechanic arriving — runs over **real-time WebSocket communication** with **live GPS tracking**.

---

## ✨ Key Features

### User App
| Feature | Description |
|---|---|
| 🗺️ **Nearby Mechanic Map** | Live Google Map with real-time mechanic locations, distance & ratings |
| ⚡ **Emergency Request** | Broadcasts your request to *all* nearby mechanics at once |
| 🎯 **Direct Request** | Pick one specific mechanic and send a targeted request |
| 📍 **Live GPS Tracking** | Watch the mechanic travel to you on the map (WebSocket) |
| 📅 **Appointments** | Book a mechanic in advance |
| 🔔 **Push Notifications** | Firebase Cloud Messaging for every request status change |
| 📜 **Request History** | Full history, cancellation & rating/review flow |

### Mechanic App
| Feature | Description |
|---|---|
| 🔴 **Online/Offline Toggle** | Availability switch with a native Android foreground service that keeps the presence alive |
| 🔔 **Instant Alerts** | Incoming request alerts with sound + vibration |
| 🧭 **Live Navigation** | Turn-by-direction view to the user's location |
| 💰 **Earnings Dashboard** | Daily & monthly earnings overview |
| 📦 **Subscription Plans** | 3-tier visibility plans (Free / Premium / Ultra Premium) |

---

## 🛠 Tech Stack & Architecture

```
┌─────────────────────┐          ┌──────────────────────────────┐
│   ONFIX Flutter App │  HTTPS   │   Spring Boot Backend        │
│  (Android / iOS /   │─────────▶│   (Google Cloud Run)         │
│       Web)          │          │                              │
│                     │  WSS     │  REST APIs  +  WebSocket     │
│  • AppConfig        │◀────────▶│  (STOMP endpoint:            │
│    (dart-define)    │          │   /ws-notifications)         │
└─────────┬───────────┘          └──────────────────────────────┘
          │
          ├── Google Maps SDK (Android/iOS/Web) — maps, geocoding, directions, places
          ├── Firebase Cloud Messaging — push notifications
          └── Native Android foreground service (Kotlin) — mechanic presence & offline detection
```

| Layer | Technology |
|---|---|
| Frontend | **Flutter** (Dart) — single codebase for Android, iOS & Web |
| Backend | **Spring Boot** deployed on **Google Cloud Run** (`asia-south1`) |
| Real-time | **WebSocket (STOMP)** via `stomp_dart_client` |
| Maps & Geo | **Google Maps API** (Maps SDK, Geocoding, Directions, Places) |
| Notifications | **Firebase Cloud Messaging (FCM)** |
| State & Storage | `SharedPreferences`, provider-style services |
| Localization | In-app string abstraction (`lib/l10n`) |

### Backend Endpoints

| Environment | Base URL |
|---|---|
| ☁️ **Cloud (default)** | `https://mechanicapp-service-621632382478.asia-south1.run.app` |
| 🏠 **Local development** | `http://localhost:8080` |

All URLs are wired through a **single config class** — see [Configuration Reference](#-configuration-reference).

---

## ⚡ Quick Start (TL;DR)

```powershell
# 1. Install dependencies
flutter pub get

# 2. Add your Google Maps API key (one-time)
Copy-Item .env.example .env
notepad .env          # paste your key into GOOGLE_MAPS_API_KEY=

# 3. Run against the CLOUD backend — zero extra setup
.\run_cloud.ps1
```

That's it. The app launches connected to the live cloud backend with maps fully working.

---

## 📋 Prerequisites

| Tool | Version | Install |
|---|---|---|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | ≥ 3.32 (Dart ^3.8) | `flutter doctor` must pass |
| Android Studio / VS Code | latest | with Flutter & Dart plugins |
| Android SDK | API 34+ | for Android emulator / device builds |
| Chrome | any | for web builds |
| PowerShell 5+ | any | Windows (for the provided `.ps1` scripts) |
| Google Maps API key | — | see [next section](#-api-key-setup-google-maps) |

Verify your setup first:

```powershell
flutter doctor
```

---

## 🔧 Installation

```bash
git clone https://github.com/Muhammadharis786/Mechanic_App_Frontend-Flutter.git
cd Mechanic_App_Frontend-Flutter
flutter pub get
```

---

## 🔑 API Key Setup (Google Maps)

The app uses **one secret API key**: the **Google Maps API key** (used by 7 Dart screens for geocoding/directions/places, the Android manifest, the iOS AppDelegate, and the web index page). The key is **never committed to git** — it is injected at build time from local files.

### Step 1 — Get a key from Google Cloud Console

1. Go to [Google Cloud Console → APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials)
2. Create a project (or reuse an existing one) and **Create Credentials → API key**
3. Enable these APIs for the key (Library → search → Enable):
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
   - **Maps JavaScript API** (for the web build)
   - **Geocoding API**
   - **Directions API**
   - **Places API**
4. *(Recommended)* Restrict the key: Application restrictions → Android app / iOS bundle / HTTP referrers

### Step 2 — Place the key (per platform)

| Platform | File to create | How |
|---|---|---|
| **All builds (main)** | `.env` in project root | `Copy-Item .env.example .env`, then set `GOOGLE_MAPS_API_KEY=...` |
| **Web** | `web/env.js` | Auto-generated by `run_*.ps1` scripts, **or** copy `web/env.example.js` → `web/env.js` and paste the key |
| **iOS** | `ios/Runner/Secrets.plist` | `Copy-Item ios/Runner/Secrets.plist.example ios/Runner/Secrets.plist`, then replace `PASTE_YOUR_KEY_HERE` |

**`.env` example:**

```env
GOOGLE_MAPS_API_KEY=AIzaSy...your...key
```

> All three files above are **gitignored** — `.example` templates are committed so teammates know what to fill in.
> For 99% of workflows you only need the root `.env`; the run/build scripts propagate it everywhere automatically.

### Step 3 — Verify

```powershell
.\run_cloud.ps1
```

If the console prints `>>> Maps key: loaded from .env` — you're done. ✅

---

## ▶️ Running the App

The app can run against **either backend** with one command. All scripts read the Maps key from `.env` and inject it via `--dart-define`.

### Run against the CLOUD backend (default)

```powershell
.\run_cloud.ps1                  # Flutter asks which device to use
.\run_cloud.ps1 -d chrome        # run on Chrome
.\run_cloud.ps1 -d emulator-5554 # run on a specific Android emulator
```

### Run against a LOCAL backend

Start your local Spring Boot server on port `8080` first, then:

```powershell
.\run_local.ps1                  # uses http://localhost:8080
.\run_local.ps1 -d chrome
```

> **Android emulator:** `localhost` is automatically remapped to `10.0.2.2` (the host machine) inside `AppConfig`, so local testing works out of the box.
>
> **Real physical phone:** plain `localhost` won't work (it means the phone itself). Use your PC's Wi-Fi IP instead — phone and PC must be on the same network:
> ```powershell
> .\run_local.ps1 -BaseUrl http://192.168.1.5:8080
> ```

### Manual commands (macOS/Linux)

The PowerShell scripts are a convenience wrapper. The equivalent commands are:

```bash
# Cloud
flutter run --dart-define=BASE_URL=https://mechanicapp-service-621632382478.asia-south1.run.app \
            --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY

# Local (Android emulator)
flutter run --dart-define=BASE_URL=http://10.0.2.2:8080 \
            --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

> ⚠️ **Always prefer the scripts** — plain `flutter run`/`flutter build` without `--dart-define=GOOGLE_MAPS_API_KEY=...` will launch with an **empty Maps key**, breaking geocoding, directions and places features (the native map widget still renders via gradle injection on Android).

---

## 📱 Building a Release APK

```powershell
.\build_apk.ps1                  # release APK pointing to the CLOUD backend
.\build_apk.ps1 --split-per-abi   # smaller per-ABI APKs
```

Output:

```
build\app\outputs\flutter-apk\app-release.apk
```

The backend URL is **baked in at build time** (`String.fromEnvironment`), so a normally-built APK permanently talks to the cloud backend — ideal for distribution/demo. To test a local backend on a real phone via Wi-Fi:

```powershell
.\build_apk.ps1 -BaseUrl http://192.168.1.5:8080
```

---

## 📁 Project Structure

```
lib/
├── config/
│   └── app_config.dart        # ⭐ Single source of truth: BASE_URL, WS URL, Maps key
├── main.dart                  # Entry point; persists base_url/ws_url to SharedPreferences
├── l10n/                      # String abstraction
├── screens/
│   ├── authentication/        # Login, register, OTP (phone auth), forgot password
│   ├── user/                  # Maps, service requests, tracking, appointments, history
│   └── mechanic/              # Presence toggle, request alerts, navigation, earnings, KYC
├── services/                  # WebSocket (STOMP), FCM, presence guard, live location,
│                              #   emergency alerts, connectivity controller
├── utils/                     # Helpers
└── widgets/                   # Shared UI components

android/app/src/main/kotlin/   # Native Kotlin: foreground service keeping mechanic
└── .../                        #   presence alive + offline detection (reads the same
                               #   base URL from SharedPreferences)
```

---

## ⚙️ Configuration Reference

Everything is centralized in **`lib/config/app_config.dart`**:

| Value | Source | Default |
|---|---|---|
| `AppConfig.baseUrl` | `--dart-define=BASE_URL=...` | Cloud URL |
| `AppConfig.webSocketUrl` | Derived from `baseUrl` (`https→wss` / `http→ws`) + `/ws-notifications/websocket` | — |
| `AppConfig.googleMapsApiKey` | `--dart-define=GOOGLE_MAPS_API_KEY=...` | *(empty — must be provided)* |

Extra behaviors handled for you:

- **Android emulator remap:** `localhost`/`127.0.0.1` → `10.0.2.2` (only on non-web Android builds)
- **Native service sync:** `main.dart` persists the active URLs so the Kotlin foreground service (mechanic presence / offline detection) always talks to the *same* backend as the Dart code
- **Cleartext HTTP:** enabled in `AndroidManifest.xml` for local-backend testing

| Script | Purpose |
|---|---|
| `run_cloud.ps1` | `flutter run` against cloud + Maps key from `.env` |
| `run_local.ps1` | `flutter run` against `http://localhost:8080` (+`-BaseUrl` override) |
| `build_apk.ps1` | Release APK (cloud by default, `-BaseUrl` override) |

---

## 🚀 CI/CD

`.github/workflows/firebase-hosting-merge.yml` builds and deploys the **web** version to **Firebase Hosting** on every push to `master`.

It pulls the Maps key from the **GitHub Actions secret** `GOOGLE_MAPS_API_KEY`:

> Repo → **Settings → Secrets and variables → Actions → New repository secret**
> Name: `GOOGLE_MAPS_API_KEY` · Value: *your key*

---

## 🔒 Security Notes

- **Google Maps API key** — stored only in gitignored files (`.env`, `web/env.js`, `ios/Runner/Secrets.plist`) and injected at build time via `--dart-define`, Gradle manifest placeholders, plist lookup and `env.js` respectively. `git grep` confirms zero copies in tracked source.
- **Firebase API keys** (`firebase_options.dart`, `google-services.json`) — intentionally committed. These are **public app identifiers**, not secrets; Firebase security comes from Security Rules and authorized domains (per [Google's own guidance](https://firebase.google.com/docs/projects/api-keys)).
- **Commit templates only** — `.env.example`, `web/env.example.js`, `ios/Runner/Secrets.plist.example` show the expected shape without real keys.

---

## 🩺 Troubleshooting

| Problem | Fix |
|---|---|
| `running scripts is disabled on this system` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, then re-run the script (or one-off: `powershell -ExecutionPolicy Bypass -File .\run_cloud.ps1`) |
| Map is blank / geocoding fails | `GOOGLE_MAPS_API_KEY` missing in `.env` — see [API Key Setup](#-api-key-setup-google-maps). Also verify the required Maps APIs are **enabled** in Google Cloud Console |
| Local run: API calls fail on Android emulator | Make sure the local backend is actually running on port `8080`; the emulator remap to `10.0.2.2` is automatic |
| Local run on a real phone fails | Use `-BaseUrl http://<your-PC-WiFi-IP>:8080` and keep phone & PC on the same network |
| `flutter doctor` errors | Resolve platform toolchain issues before running |

---

## 👥 Team

Built for the **Alibaba AI Hackathon**.

- **Muhammad Haris** — Founder & Lead Developer (Flutter + Spring Boot)

**Contact:** *(add your email / links here)*

---

<div align="center">

**ONFIX — Fix It. Fast.** 🔧

</div>
