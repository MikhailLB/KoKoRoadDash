import FirebaseMessaging
import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Strong reference — required so ARC does not deallocate the channel
  // and its handler after didInitializeImplicitFlutterEngine returns.
  private var wkStoreChannel: FlutterMethodChannel?

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
    let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "rdz_wkstore")
      .messenger()
    let ch = FlutterMethodChannel(name: "rdz/wkstore", binaryMessenger: messenger)
    ch.setMethodCallHandler { call, result in
      guard call.method == "purge" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let types = WKWebsiteDataStore.allWebsiteDataTypes()
      WKWebsiteDataStore.default().removeData(
        ofTypes: types,
        modifiedSince: Date(timeIntervalSince1970: 0)
      ) { result(nil) }
    }
    wkStoreChannel = ch
  }
}
