import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/lane_config.dart';
import '../config/lane_vault.dart';
import 'branded_agent.dart';

/// AppsFlyer SDK wrapper. Surfaces install-conversion data, deep-link
/// payloads and the AppsFlyer UID for inclusion in the lane payload.
class AttributionWire {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _conversion;
  Map<String, dynamic>? _deepLink;
  Map<String, dynamic>? _reopen;

  final Completer<Map<String, dynamic>> _conversionDone =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkDone = Completer<void>();

  bool _primed = false;
  Future<void>? _primeFuture;

  bool get primed => _primed;

  Future<void> prime() => _primeFuture ??= _runPrime();

  // ── Debug override ──────────────────────────────────────────
  // Set to true to force Non-organic on every boot (simulator / local dev).
  // MUST be false in release builds — this flag bypasses AppsFlyer entirely.
  static const bool _kForceNonOrganic = kDebugMode;
  // ────────────────────────────────────────────────────────────

  Future<void> _runPrime() async {
    if (_primed) return;

    if (_kForceNonOrganic) {
      _primed = true;
      final Map<String, dynamic> mock = <String, dynamic>{
        'af_status': 'Non-organic',
        'media_source': 'debug_mock',
        'campaign': 'simulator_test',
        'af_id': 'mock-af-id-0000',
        'is_first_launch': true,
      };
      _conversion = mock; // ← must set field, not only complete the future
      // ignore: avoid_print
      print('[DBG][AW] MOCK active → af_status=Non-organic, _conversion set');
      if (!_conversionDone.isCompleted) _conversionDone.complete(mock);
      if (!_deepLinkDone.isCompleted) _deepLinkDone.complete();
      return;
    }

    final String devKey = LaneConfig.installKey;
    if (devKey.isEmpty) {
      _primed = true;
      if (!_conversionDone.isCompleted) {
        _conversionDone.complete(<String, dynamic>{});
      }
      if (!_deepLinkDone.isCompleted) _deepLinkDone.complete();
      return;
    }
    _primed = true;
    try {
      if (Platform.isIOS) await _maybeRequestAtt();
      final AppsFlyerOptions opts = AppsFlyerOptions(
        afDevKey: devKey,
        appId: LaneConfig.analyticsAppId,
        showDebug: kDebugMode,
        timeToWaitForATTUserAuthorization: 5,
      );
      _sdk = AppsflyerSdk(opts);
      _sdk!.onInstallConversionData(_onConversion);
      _sdk!.onAppOpenAttribution(_onReopen);
      _sdk!.onDeepLinking(_onDeepLink);
      await _sdk!.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      if (!_conversionDone.isCompleted) {
        _conversionDone.complete(<String, dynamic>{});
      }
      if (!_deepLinkDone.isCompleted) _deepLinkDone.complete();
    }
  }

  Future<void> _maybeRequestAtt() async {
    try {
      final TrackingStatus current =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (current != TrackingStatus.notDetermined) return;
      // The dialog can only appear once the app is foreground-active.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 320));
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (_) {}
  }

  Map<String, dynamic> _flatten(dynamic raw) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(raw as Map);
    final dynamic inner = m['payload'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return m;
  }

  void _onConversion(dynamic raw) async {
    final Map<String, dynamic> data = _flatten(raw);
    if (data['af_status'] == 'Organic') {
      await Future<void>.delayed(
          Duration(seconds: LaneConfig.organicRetrySeconds));
      final Map<String, dynamic>? retry = await _gcdFallback();
      _conversion = retry ?? data;
    } else {
      _conversion = data;
    }
    if (!_conversionDone.isCompleted) _conversionDone.complete(_conversion);
  }

  void _onReopen(dynamic raw) => _reopen = _flatten(raw);

  void _onDeepLink(DeepLinkResult r) {
    if (r.deepLink != null) _deepLink = r.deepLink!.clickEvent;
    if (!_deepLinkDone.isCompleted) _deepLinkDone.complete();
  }

  Future<Map<String, dynamic>?> _gcdFallback() async {
    try {
      final String? uid = await deviceUid();
      if (uid == null) return null;
      final String appId =
          Platform.isIOS ? LaneConfig.analyticsAppId : LaneConfig.bundleId;
      final String url = gcdProbeUrl(appId, uid);
      if (url.isEmpty) return null;
      final response = await brandedAgent.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${LaneConfig.installKey}',
        },
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> awaitConversion({
    Duration timeout = const Duration(seconds: 7),
  }) {
    return _conversionDone.future
        .timeout(timeout, onTimeout: () => <String, dynamic>{});
  }

  Future<void> awaitDeepLink({
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _deepLinkDone.future.timeout(timeout, onTimeout: () {});
  }

  Future<String?> deviceUid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> assemblePayload({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (_conversion != null) body.addAll(_conversion!);
    if (_deepLink != null) {
      _deepLink!.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    }
    if (_reopen != null) {
      _reopen!.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    }

    final String? uid = await deviceUid();
    if (uid != null && uid.isNotEmpty) {
      body['af_id'] = uid;
    } else {
      body.putIfAbsent('af_id', () => '');
    }

    if (Platform.isIOS) {
      try {
        final TrackingStatus status =
            await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.authorized) {
          final String idfa =
              await AppTrackingTransparency.getAdvertisingIdentifier();
          if (idfa.isNotEmpty && !idfa.startsWith('00000000-')) {
            body.putIfAbsent('sub_id_10', () => idfa);
          }
        }
      } catch (_) {}
    }

    body['bundle_id'] = LaneConfig.bundleId;
    body['store_id']  = LaneConfig.storeIdForPlatform;
    body['os']        = Platform.isAndroid ? 'Android' : 'iOS';
    body['locale']    = locale;
    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    if (LaneConfig.firebaseNumber.isNotEmpty) {
      body['firebase_project_id'] = LaneConfig.firebaseNumber;
    }

    return body;
  }
}
