import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/lane_vault.dart';

/// HTTP client that injects a real-device-derived User-Agent into every
/// outbound request. UA fragments depend on the actual device model + OS
/// version reported by `device_info_plus`, so two installs on different
/// hardware produce different headers.
class UaClient extends http.BaseClient {
  UaClient();

  final http.Client _inner = http.Client();
  String _ua = '';

  Future<void> primeUa() async {
    try {
      final DeviceInfoPlugin probe = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo info = await probe.androidInfo;
        final String tag = info.display.isNotEmpty ? info.display : info.id;
        _ua = _buildAndroidUa(
          sdk: info.version.sdkInt,
          brand: info.brand,
          model: info.model,
          build: tag,
        );
      } else if (Platform.isIOS) {
        final IosDeviceInfo info = await probe.iosInfo;
        _ua = _buildIosUa(info.systemVersion);
      } else {
        _ua = _fallbackUa();
      }
    } catch (_) {
      _ua = _fallbackUa();
    }
  }

  String get userAgent => _ua.isNotEmpty ? _ua : _fallbackUa();

  String _buildAndroidUa({
    required int sdk,
    required String brand,
    required String model,
    required String build,
  }) {
    return 'Mozilla/5.0 (Linux; Android $sdk; $brand $model Build/$build) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/${uaChromeRev()} Mobile Safari/537.36';
  }

  String _buildIosUa(String version) {
    final String dotless = version.replaceAll('.', '_');
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS $dotless like Mac OS X) '
        'AppleWebKit/${uaSafariRev()} (KHTML, like Gecko) '
        'Version/$version Mobile/15E148 Safari/${uaSafariRev()}';
  }

  String _fallbackUa() {
    if (Platform.isAndroid) {
      return _buildAndroidUa(
        sdk: 14,
        brand: 'Google',
        model: 'Pixel 9',
        build: 'AP3A.241105.007',
      );
    }
    return _buildIosUa('17.5');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!request.headers.containsKey('User-Agent') &&
        !request.headers.containsKey('user-agent')) {
      request.headers['User-Agent'] = userAgent;
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Process-wide singleton used by the lane bridge HTTP and WebView code.
final UaClient uaClient = UaClient();
