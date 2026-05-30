import 'package:flutter/services.dart';

/// Helpers to pin the device orientation per screen.
///
/// The whole game is portrait-only except the loading screen, which is allowed
/// to follow the device (the asset set ships both a vertical and a horizontal
/// loading video).
class OrientationLock {
  OrientationLock._();

  static Future<void> portrait() {
    return SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }

  static Future<void> all() {
    return SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}
