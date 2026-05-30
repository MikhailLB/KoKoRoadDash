import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../core/cipher/xkey.dart';

// ============================================================
// ROAD NET CLIENT — Real device User-Agent injection
// ============================================================
// Builds a UA string matching Chrome (Android) or Safari (iOS)
// from actual device info. All outgoing HTTP requests use this UA.
//
// Chrome/WebKit version fragments are XOR-encoded.
// TODO: Re-encode after changing the codec seed.
// ============================================================

String get _chromeFrag => xd(const <int>[48, 149, 215, 186, 13, 28, 181, 55, 11, 77, 241, 29, 197, 184]);

String get _webkitFrag => xd(const <int>[52, 149, 208, 186, 14, 4]);

class RoadNetClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  String? _ua;

  Future<void> init() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final cv = _chromeFrag.isNotEmpty ? _chromeFrag : '130.0.0.0';
        _ua = 'Mozilla/5.0 (Linux; Android ${a.version.sdkInt}; '
            '${a.brand} ${a.model} Build/${a.display.isNotEmpty ? a.display : a.id}) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/$cv Mobile Safari/537.36';
      } else {
        final i = await info.iosInfo;
        final ver = i.systemVersion.replaceAll('.', '_');
        final sv = _webkitFrag.isNotEmpty ? _webkitFrag : '537.36';
        _ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS $ver like Mac OS X) '
            'AppleWebKit/$sv (KHTML, like Gecko) '
            'Version/${i.systemVersion} Mobile/15E148 Safari/$sv';
      }
    } catch (_) {
      final cv = _chromeFrag.isNotEmpty ? _chromeFrag : '130.0.0.0';
      final sv = _webkitFrag.isNotEmpty ? _webkitFrag : '537.36';
      _ua = Platform.isAndroid
          ? 'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/$cv Mobile Safari/537.36'
          : 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
              'AppleWebKit/$sv (KHTML, like Gecko) '
              'Version/17.0 Mobile/15E148 Safari/$sv';
    }
  }

  String get userAgent => _ua ?? 'Mozilla/5.0';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Global singleton HTTP client used by all gray-flow services.
final roadNetClient = RoadNetClient();
