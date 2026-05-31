import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'branded_agent.dart';
import 'lane_stash.dart';

const String _channelId    = 'krd_lane_pulse';
const String _channelLabel = 'Koko Road Dash alerts';
const String _channelDesc  = 'Time-sensitive in-game updates';
const String _iconRes      = '@drawable/ic_koko_notification';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage _) async {
  // FCM requires a registered background isolate handler even if we don't
  // need to do anything when the app is fully suspended. The Notification
  // Service Extension takes care of rich media; live data only matters
  // once the Dart isolate is alive.
}

/// Top-level callback for taps on locally-displayed notifications that
/// occur while the Dart isolate is not alive. Stashes any URL payload
/// so the next launch can navigate to it through the lane bridge.
@pragma('vm:entry-point')
Future<void> kokoTrayBgTapHandler(NotificationResponse response) async {
  final String? payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  try {
    final dynamic decoded = jsonDecode(payload);
    if (decoded is Map &&
        decoded['url'] is String &&
        (decoded['url'] as String).isNotEmpty) {
      await LaneStash().parkOneShotUrl(decoded['url'] as String);
    }
  } catch (_) {}
}

/// Firebase Messaging + flutter_local_notifications glue.
class PushPulse {
  PushPulse(this._stash);

  final LaneStash _stash;
  final FlutterLocalNotificationsPlugin _tray =
      FlutterLocalNotificationsPlugin();
  final Completer<void> _coldGate = Completer<void>();

  FirebaseMessaging? _fcm;
  String? _token;
  bool _ready = false;
  Future<void>? _bootFuture;
  Future<bool>? _consentInflight;

  void Function(String url)? onPushUrl;
  void Function(String token)? onTokenRefresh;

  String? get token => _token;
  bool get ready => _ready;

  /// Completes once the iOS cold-start `getInitialMessage` probe has run.
  Future<void> get coldGate => _coldGate.future;

  Future<void> kick() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    try {
      _fcm = FirebaseMessaging.instance;
      // ⚠️ Order matters — capture cold-start BEFORE attaching listeners,
      // otherwise an early foreground delivery can race the read.
      await _captureColdStart();
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      await _wireTray();
      try {
        await _fcm!.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}
      _fcm!.onTokenRefresh.listen((String fresh) {
        _token = fresh;
        onTokenRefresh?.call(fresh);
      });
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onBgTap);
      if (Platform.isIOS) {
        try {
          final NotificationSettings settings =
              await _fcm!.getNotificationSettings();
          if (settings.authorizationStatus ==
              AuthorizationStatus.notDetermined) {
            await _fcm!.requestPermission(
              alert: false,
              badge: false,
              sound: false,
              provisional: true,
            );
          }
        } catch (_) {}
        await _pollApns();
      }
      _token = await _fcm!.getToken();
      _ready = true;
    } catch (_) {
    } finally {
      if (!_coldGate.isCompleted) _coldGate.complete();
    }
  }

  Future<void> _captureColdStart() async {
    try {
      final RemoteMessage? message = await _fcm!.getInitialMessage().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      if (message != null) {
        final String? url = _extractUrl(message);
        if (url != null) {
          await _stash.parkOneShotUrl(url);
        }
      }
    } catch (_) {} finally {
      if (!_coldGate.isCompleted) _coldGate.complete();
    }
  }

  String? _extractUrl(RemoteMessage message) {
    const List<String> keys = <String>[
      'url', 'link', 'target', 'deeplink', 'deep_link',
    ];
    for (final String key in keys) {
      final dynamic value = message.data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    final dynamic nested = message.data['payload'];
    if (nested is Map) {
      for (final String key in keys) {
        final dynamic value = nested[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return null;
  }

  Future<void> _pollApns({int rounds = 5}) async {
    for (int i = 0; i < rounds; i++) {
      try {
        final String? apns = await _fcm!.getAPNSToken();
        if (apns != null && apns.isNotEmpty) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 480));
    }
  }

  Future<void> _wireTray() async {
    await _tray.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings(_iconRes),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload == null) return;
        try {
          final dynamic decoded = jsonDecode(payload);
          if (decoded is Map && decoded['url'] is String) {
            _dispatch(decoded['url'] as String);
          }
        } catch (_) {}
      },
      onDidReceiveBackgroundNotificationResponse: kokoTrayBgTapHandler,
    );
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android = _tray
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelLabel,
        description: _channelDesc,
        importance: Importance.high,
      ));
    }
  }

  Future<bool> consentOnOffer() async {
    final FirebaseMessaging? fcm = _fcm;
    if (fcm == null) return false;
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android = _tray
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (android == null) return true;
        final bool? enabled = await android.areNotificationsEnabled();
        return enabled != true;
      }
      final NotificationSettings settings = await fcm.getNotificationSettings();
      final AuthorizationStatus status = settings.authorizationStatus;
      if (status == AuthorizationStatus.denied) {
        await _stash.writeConsentCooldown(
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 365 * 24 * 3600,
        );
        await _stash.writeConsentGranted(false);
      }
      return status == AuthorizationStatus.notDetermined ||
          status == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  Future<bool> askConsent() async {
    if (_fcm == null) return false;
    final Future<bool>? pending = _consentInflight;
    if (pending != null) return pending;
    final Future<bool> flow = _runAskConsent();
    _consentInflight = flow;
    try {
      return await flow;
    } finally {
      _consentInflight = null;
    }
  }

  Future<bool> _runAskConsent() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android = _tray
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (android != null) {
          final bool? already = await android.areNotificationsEnabled();
          if (already == true) {
            await _stash.writeConsentGranted(true);
            return true;
          }
          final bool ok =
              (await android.requestNotificationsPermission()) ?? false;
          await _stash.writeConsentGranted(ok);
          return ok;
        }
      }
      final NotificationSettings preCheck =
          await _fcm!.getNotificationSettings();
      final AuthorizationStatus current = preCheck.authorizationStatus;
      if (current == AuthorizationStatus.denied) {
        await _stash.writeConsentCooldown(
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 365 * 24 * 3600,
        );
        await _stash.writeConsentGranted(false);
        return false;
      }
      if (current == AuthorizationStatus.authorized) {
        await _stash.writeConsentGranted(true);
        return true;
      }
      final NotificationSettings result = await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final bool ok = result.authorizationStatus ==
              AuthorizationStatus.authorized ||
          result.authorizationStatus == AuthorizationStatus.provisional;
      if (!ok && result.authorizationStatus == AuthorizationStatus.denied) {
        await _stash.writeConsentCooldown(
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 365 * 24 * 3600,
        );
      }
      await _stash.writeConsentGranted(ok);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<String?> refreshTokenPostConsent() async {
    final FirebaseMessaging? fcm = _fcm;
    if (fcm == null) return null;
    try {
      // The APNs registration takes noticeably longer just after a user
      // grants permission — extend the polling envelope.
      if (Platform.isIOS) await _pollApns(rounds: 14);
      _token = await fcm.getToken().timeout(const Duration(seconds: 10));
      final String? next = _token;
      if (next != null && next.isNotEmpty) onTokenRefresh?.call(next);
      return next;
    } catch (_) {
      return null;
    }
  }

  void _onForeground(RemoteMessage message) async {
    // iOS shows the banner itself via setForegroundNotificationPresentationOptions —
    // don't duplicate via the local tray.
    if (Platform.isIOS) return;
    final RemoteNotification? remote = message.notification;
    if (remote == null) {
      final String? url = _extractUrl(message);
      if (url != null) _dispatch(url);
      return;
    }
    final String? imageUrl = remote.android?.imageUrl;
    AndroidNotificationDetails? android;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _downloadImage(imageUrl);
      if (bytes != null) {
        android = AndroidNotificationDetails(
          _channelId,
          _channelLabel,
          importance: Importance.high,
          priority: Priority.high,
          icon: _iconRes,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }
    android ??= const AndroidNotificationDetails(
      _channelId,
      _channelLabel,
      importance: Importance.high,
      priority: Priority.high,
      icon: _iconRes,
    );
    await _tray.show(
      remote.hashCode,
      remote.title,
      remote.body,
      NotificationDetails(
        android: android,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onBgTap(RemoteMessage message) {
    final String? url = _extractUrl(message);
    if (url != null) _dispatch(url);
  }

  void _dispatch(String url) {
    final void Function(String url)? cb = onPushUrl;
    if (cb != null) {
      cb(url);
    } else {
      _stash.parkOneShotUrl(url);
    }
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final r = await brandedAgent
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }
}
