import Flutter
import UIKit
import UserNotifications

/// On scene-based apps, tapping a push notification while the app is killed
/// delivers the tap through `scene(_:willConnectTo:options:)` — NOT through
/// the AppDelegate launchOptions path that Firebase's swizzle reads.
/// `FirebaseMessaging.getInitialMessage()` therefore returns nil for those
/// taps and the URL would be silently lost.
///
/// We capture the URL here and stash it in UserDefaults under
/// `flutter.krd_lane_tap_url`. The `flutter.` prefix lets the Dart side
/// pick it up through `shared_preferences` (which namespaces every key
/// with `flutter.` on iOS) — no MethodChannel needed.
class SceneDelegate: FlutterSceneDelegate {
  static let tapUrlKey = "flutter.krd_lane_tap_url"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    if let response = connectionOptions.notificationResponse,
       let url = SceneDelegate.extractUrl(
         from: response.notification.request.content.userInfo
       )
    {
      SceneDelegate.persist(url: url)
    }
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    super.scene(scene, continue: userActivity)
  }

  /// Walks the FCM userInfo map looking for any key the backend might use
  /// for the destination URL. Priority order mirrors the Dart `_extractUrl`
  /// in `PushPulse` so killed-app and live-app paths resolve to the same
  /// target.
  static func extractUrl(from userInfo: [AnyHashable: Any]) -> String? {
    let keys = ["url", "link", "target", "deeplink", "deep_link"]

    func scan(_ map: [AnyHashable: Any]) -> String? {
      for key in keys {
        if let raw = map[key] as? String,
           !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
      }
      return nil
    }

    if let direct = scan(userInfo) { return direct }

    if let nested = userInfo["data"] as? [AnyHashable: Any],
       let url = scan(nested) {
      return url
    }

    if let nested = userInfo["payload"] as? [AnyHashable: Any],
       let url = scan(nested) {
      return url
    }

    return nil
  }

  static func persist(url: String) {
    let store = UserDefaults.standard
    store.set(url, forKey: tapUrlKey)
    store.synchronize()
  }
}
