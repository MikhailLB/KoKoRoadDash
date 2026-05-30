import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'road_net_client.dart';
import 'vault_service.dart';

// ============================================================
// PUSH HANDLER — Firebase Messaging + local notification display
// ============================================================
// Push URL behavior (critical):
//   COLD START: app killed, user taps notification
//     → getInitialMessage() fires at boot → SAVE url to vault
//   WARM (background/foreground tap):
//     → onMessageOpenedApp / local notification tap
//     → CALL onNotificationUrl callback, do NOT save
// ============================================================

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {
  // Background messages handled by OS; tap handled via onMessageOpenedApp
  // or getInitialMessage() on cold start.
}

class PushHandler {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final VaultService _vault;
  FirebaseMessaging? _fcm;
  String? _token;
  bool _initialized = false;

  /// Called when user taps a push while app is warm (not saved to storage).
  Function(String url)? onNotificationUrl;

  /// Called when FCM token rotates — re-POST to config endpoint.
  Function(String token)? onTokenRefresh;

  PushHandler(this._vault);

  String? get token => _token;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      _fcm = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);

      await _setupLocalNotifications();

      _token = await _fcm!.getToken();

      _fcm!.onTokenRefresh.listen((t) {
        _token = t;
        onTokenRefresh?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final initial = await _fcm!.getInitialMessage();
      if (initial != null) _onColdTap(initial);

      _initialized = true;
    } catch (_) {
      // Firebase not configured — push disabled, app continues normally
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null) return;
        try {
          final data = jsonDecode(response.payload!) as Map<String, dynamic>;
          final url = data['url'] as String?;
          if (url != null && url.isNotEmpty) onNotificationUrl?.call(url);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final plugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'Koko Road Dash push notifications',
          importance: Importance.high,
        ),
      );
    }
  }

  Future<bool> requestPermission() async {
    if (_fcm == null) return false;
    final settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    await _vault.setNotificationGranted(granted);

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      await _vault.setNotificationOsDenied();
    }

    return granted;
  }

  void _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || !Platform.isAndroid) return;

    final imgUrl = message.notification?.android?.imageUrl;
    AndroidNotificationDetails? details;

    if (imgUrl != null && imgUrl.isNotEmpty) {
      final bytes = await _downloadBytes(imgUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );

    final payload = message.data.isNotEmpty ? jsonEncode(message.data) : null;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: details),
      payload: payload,
    );
  }

  void _onColdTap(RemoteMessage message) {
    final url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) _vault.setPushUrl(url);
  }

  void _onWarmTap(RemoteMessage message) {
    final url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) onNotificationUrl?.call(url);
  }

  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final res = await roadNetClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }
}
