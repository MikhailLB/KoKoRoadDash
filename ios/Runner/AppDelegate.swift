import FirebaseMessaging
import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Re-arm APNs registration on every launch so the FCM ↔ APNs token
    // mapping stays fresh even when permission was granted in a prior run.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "rdz/wkstore",
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "rdz_wkstore").messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "purge" {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(
          ofTypes: types,
          modifiedSince: Date(timeIntervalSince1970: 0)
        ) { result(nil) }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
