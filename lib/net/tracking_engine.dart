import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import '../setup/road_settings.dart';
import '../setup/analytics_env.dart';
import 'road_net_client.dart';

// ============================================================
// TRACKING ENGINE — AppsFlyer attribution + deep link handling
// ============================================================
// Initializes the AppsFlyer SDK and builds the POST body for the
// config endpoint. The backend uses this to route users to either
// the WebView (paid installs) or the native game (organic).
//
// ORGANIC FALSE-POSITIVE FIX:
//   If af_status=="Organic" on first callback, wait 5s and retry
//   via the GCD API — AppsFlyer sometimes mis-reports on first run.
// ============================================================

class TrackingEngine {
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _attributionData;
  Map<String, dynamic>? _deepLinkData;
  Map<String, dynamic>? _appOpenData;

  final Completer<Map<String, dynamic>> _attrCompleter = Completer();
  final Completer<void> _dlCompleter = Completer();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (RoadSettings.analyticsKey.isEmpty) return;

    final options = AppsFlyerOptions(
      afDevKey: RoadSettings.analyticsKey,
      appId: RoadSettings.analyticsAppId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    _sdk = AppsflyerSdk(options);

    _sdk!.onInstallConversionData((data) async {
      try {
        final payload = (data['payload'] as Map?)?.cast<String, dynamic>() ??
            (data as Map).cast<String, dynamic>();

        if (payload['af_status'] == 'Organic') {
          await Future.delayed(
              Duration(seconds: RoadSettings.syncRetrySeconds));
          final retry = await _refreshAttribution();
          _attributionData = retry ?? payload;
        } else {
          _attributionData = payload;
        }
      } catch (_) {
        _attributionData = {};
      }

      if (!_attrCompleter.isCompleted) {
        _attrCompleter.complete(_attributionData ?? {});
      }
    });

    _sdk!.onAppOpenAttribution((data) {
      try {
        _appOpenData =
            (data['payload'] as Map?)?.cast<String, dynamic>() ??
                (data as Map).cast<String, dynamic>();
      } catch (_) {}
    });

    _sdk!.onDeepLinking((result) {
      try {
        if (result.deepLink != null) {
          _deepLinkData = result.deepLink!.clickEvent.cast<String, dynamic>();
        }
      } catch (_) {}
      if (!_dlCompleter.isCompleted) _dlCompleter.complete();
    });

    await _sdk!.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );
  }

  Future<Map<String, dynamic>?> _refreshAttribution() async {
    final uid = await getAnalyticsUID();
    if (uid == null) return null;

    final appId = Platform.isIOS
        ? RoadSettings.analyticsAppId
        : RoadSettings.bundleId;

    final url = resolveGcdUrl(appId, uid);
    if (url.isEmpty) return null;

    try {
      final response = await roadNetClient.get(
        Uri.parse(url),
        headers: {'authorization': 'Bearer ${RoadSettings.analyticsKey}'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> waitForAttribution() {
    return _attrCompleter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => <String, dynamic>{},
    );
  }

  Future<void> waitForDeepLink() {
    return _dlCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }

  Future<String?> getAnalyticsUID() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> buildRequestBody({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};

    body.addAll(_attributionData ?? {});
    _deepLinkData?.forEach((k, v) => body.putIfAbsent(k, () => v));
    _appOpenData?.forEach((k, v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await getAnalyticsUID() ?? '';
    body['bundle_id'] = RoadSettings.bundleId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = RoadSettings.storeId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    if (RoadSettings.messagingProjectId.isNotEmpty) {
      body['firebase_project_id'] = RoadSettings.messagingProjectId;
    }

    if (kDebugMode) {
      debugPrint('[TrackingEngine] Request body: ${jsonEncode(body)}');
    }

    return body;
  }
}
