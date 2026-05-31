import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads — and clears — the cold-start push URL that `SceneDelegate.swift`
/// wrote to `UserDefaults` before Dart code came up.
///
/// On iOS scene-based apps, tapping a notification while the app is killed
/// routes the tap through SceneDelegate, NOT through Firebase's swizzled
/// AppDelegate handler. `FirebaseMessaging.getInitialMessage()` therefore
/// returns null in that case. SceneDelegate stores the URL under
/// `flutter.krd_lane_tap_url`; the `flutter.` prefix means we can read it
/// straight through `shared_preferences` without writing a MethodChannel.
class ColdTapReader {
  static const String _bareKey = 'krd_lane_tap_url';

  /// Returns and removes the stashed URL, or null on non-iOS / nothing stored.
  static Future<String?> claim() async {
    if (!Platform.isIOS) return null;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_bareKey);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      await prefs.remove(_bareKey);
      return raw.trim();
    } catch (_) {
      return null;
    }
  }
}
