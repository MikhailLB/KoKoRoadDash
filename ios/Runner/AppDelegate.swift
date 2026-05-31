import FirebaseMessaging
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Eagerly register plugins so the Firebase Messaging swizzle installs
    // its UNUserNotificationCenter delegate BEFORE any push tap is routed.
    GeneratedPluginRegistrant.register(with: self)

    // Re-arm APNs registration on every launch — refreshes the FCM ↔ APNs
    // mapping even when permission was already granted in a previous run.
    // Without this a stale mapping can quietly stop push delivery.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
