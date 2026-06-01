import 'dart:io';

import 'lane_vault.dart';

/// ════════════════════════════════════════════════════════════
/// Static configuration surface for the lane bridge.
///
/// Identity-related fields (bundle id, store id, display name) are
/// hard-coded here. Secrets (keys, URLs) are pulled from the masked
/// constants in `endpoint_locker`, `attribution_keys`, `legal_links`.
/// ════════════════════════════════════════════════════════════
abstract final class LaneConfig {
  // ── iOS App Store numeric ID ─────────────────────────────────
  // Replace once Apple Developer creates the listing.
  static const String iosStoreId = '6772138451';

  // ── Bundle / package id ──────────────────────────────────────
  // Must match applicationId / PRODUCT_BUNDLE_IDENTIFIER everywhere.
  static const String bundleId = 'com.kokogames.koko';

  // ── Human-readable label (UI / store metadata) ──────────────
  static const String appTitle = 'Koko Road Dash';

  // ── Timings ──────────────────────────────────────────────────
  /// Seconds before the notify consent prompt is offered again
  /// after the user taps "Maybe later".
  static const int notifyCooldownSeconds = 3 * 24 * 3600;

  /// Pause before retrying GCD when AppsFlyer reports an organic
  /// install — gives the SDK time to resolve real attribution.
  static const int organicRetrySeconds = 5;

  /// Hard ceiling for the boot pipeline. Anything over this and we
  /// fall through to the arcade rather than freezing the splash.
  static const int bootBudgetSeconds = 22;

  // ── Derived getters ─────────────────────────────────────────
  static String get attributionEndpoint => laneEndpointUrl();
  static String get installKey          => appsflyerDevKey();
  static String get firebaseNumber      => firebaseProjectNumber();
  static String get privacyUrl          => privacyPageUrl;
  static String get supportUrl          => supportPageUrl;

  static String get storeIdForPlatform =>
      Platform.isIOS ? 'id$iosStoreId' : bundleId;

  static String get analyticsAppId =>
      Platform.isIOS ? iosStoreId : bundleId;
}
