import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps API anahtarı plugin kaydından ÖNCE verilmeli,
    // aksi halde GMSServices nil olur → EXC_BAD_ACCESS crash.
    GMSServices.provideAPIKey("AIzaSyBpgppKBVULdvG8yHq8F57TljP9PpXTvCM")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
