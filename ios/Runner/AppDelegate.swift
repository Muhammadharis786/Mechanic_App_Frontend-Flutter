import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps API key lives in ios/Runner/Secrets.plist (gitignored).
    // Create it once from Secrets.plist.example and paste your key there.
    if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
       let secrets = NSDictionary(contentsOfFile: path),
       let mapsKey = secrets["MAPS_API_KEY"] as? String,
       !mapsKey.isEmpty {
      GMSServices.provideAPIKey(mapsKey)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
