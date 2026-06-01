import FirebaseMessaging
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register plugins eagerly so Firebase Messaging installs its
    // UNUserNotificationCenterDelegate swizzle before any push tap arrives.
    GeneratedPluginRegistrant.register(with: self)
    // Re-arm APNs registration on every launch so the FCM ↔ APNs token
    // mapping stays fresh even when permission was granted in a prior run.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
