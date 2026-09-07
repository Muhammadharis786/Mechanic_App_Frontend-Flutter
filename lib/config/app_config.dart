import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Central configuration for backend URLs and the Google Maps API key.
///
/// ─────────────────────────────────────────────────────────────────────────
/// HOW TO SWITCH BETWEEN LOCAL AND CLOUD BACKEND
/// ─────────────────────────────────────────────────────────────────────────
///
/// **Cloud (default — no extra flags needed):**
/// ```
/// flutter run
/// ```
/// or use the helper script:
/// ```
/// .\run_cloud.ps1
/// ```
///
/// **Local backend (http://localhost:8080):**
/// ```
/// flutter run --dart-define=BASE_URL=http://localhost:8080
/// ```
/// or use the helper script:
/// ```
/// .\run_local.ps1
/// ```
///
/// Note for the Android emulator: `localhost` inside the emulator cannot
/// reach your PC, so [baseUrl] automatically remaps `localhost` /
/// `127.0.0.1` to `10.0.2.2` (the emulator's alias for the host machine).
/// For a real physical phone on the same Wi-Fi, pass your PC's LAN IP
/// instead, e.g. `--dart-define=BASE_URL=http://192.168.1.5:8080`.
///
/// ─────────────────────────────────────────────────────────────────────────
/// GOOGLE MAPS API KEY (secret — never commit it to git)
/// ─────────────────────────────────────────────────────────────────────────
///
/// The key is injected at build time via `--dart-define`:
/// ```
/// flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...
/// ```
/// The helper scripts (`run_local.ps1` / `run_cloud.ps1`) read it from the
/// gitignored `.env` file at the project root, so you never have to type it.
///
/// Platform-side keys are injected from the same `.env` file:
///  - Android: `android/app/build.gradle.kts` reads `.env` and injects the
///    value into `AndroidManifest.xml` via a manifest placeholder.
///  - Web: `web/index.html` loads the key from the gitignored `web/env.js`.
///  - iOS: `ios/Runner/Secrets.plist` (gitignored, see Secrets.plist.example).
class AppConfig {
  AppConfig._();

  /// Production backend deployed on Cloud Run.
  static const String cloudBaseUrl =
      'https://mechanicapp-service-621632382478.asia-south1.run.app';

  /// Local backend used while developing.
  static const String localBaseUrl = 'http://localhost:8080';

  /// Raw value passed via `--dart-define=BASE_URL=...`.
  /// Falls back to the cloud URL when nothing is passed.
  static const String _rawBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: cloudBaseUrl,
  );

  /// Whether the app currently points at the local development backend.
  static bool get isLocalBackend =>
      _rawBaseUrl.startsWith('http://localhost') ||
      _rawBaseUrl.startsWith('http://127.0.0.1');

  /// Base URL used by every HTTP call in the app.
  static String get baseUrl {
    // The Android emulator's `localhost` is the emulator itself — 10.0.2.2
    // is the alias for the host machine's loopback interface.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        isLocalBackend) {
      return _rawBaseUrl
          .replaceFirst('localhost', '10.0.2.2')
          .replaceFirst('127.0.0.1', '10.0.2.2');
    }
    return _rawBaseUrl;
  }

  /// STOMP over WebSocket endpoint used for real-time notifications.
  /// The scheme is upgraded to `wss://` / `ws://` automatically.
  static String get webSocketUrl =>
      '${baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://')}'
      '/ws-notifications/websocket';

  /// Google Maps API key, injected via
  /// `--dart-define=GOOGLE_MAPS_API_KEY=...` (see the class docs).
  /// Empty when not provided — never hardcode a real key here.
  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY');
}
