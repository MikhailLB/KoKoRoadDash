import 'network_env.dart';
import 'analytics_env.dart';
import 'road_endpoints.dart';

// ============================================================
// ROAD SETTINGS — Central config facade for KokoRoadDash
// ============================================================

class RoadSettings {
  static const String bundleId = 'com.kokogames.kokoroaddash';
  static const String storeId = 'com.kokogames.kokoroaddash';
  static const String appName = 'Koko Road Dash';

  // iOS only — App Store numeric ID
  static const String analyticsAppId = '6772138451';

  /// Full config endpoint URL — decoded from network_env.dart
  static String get apiEndpoint => resolveConfigEndpoint();

  /// AppsFlyer Dev Key — decoded from analytics_env.dart
  static String get analyticsKey => resolveAFKey();

  /// Firebase project number — decoded from analytics_env.dart
  static String get messagingProjectId => resolveFBProject();

  static String get privacyPolicyUrl => kPrivacyUrl;
  static String get supportUrl => kSupportUrl;
  static String get siteUrl => kSiteUrl;

  /// If user taps "Skip" on permission screen, re-show after 3 days.
  static const int notificationRetryDelaySeconds = 259200;

  /// GCD retry delay when AppsFlyer returns Organic on first callback.
  static const int syncRetrySeconds = 5;
}
