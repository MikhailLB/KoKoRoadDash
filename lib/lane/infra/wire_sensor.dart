import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Two-step connectivity check.
///
/// `connectivity_plus` alone returns "online" on captive-portal Wi-Fi where
/// no DNS works — so we follow up with a short DNS lookup to one of the
/// big public hosts. Both must succeed for [isReachable] to return true.
class WireSensor {
  final Connectivity _backbone = Connectivity();

  /// Probe target rotated vs sibling apps (was cloudflare.com elsewhere).
  static const String _probeHost = 'one.one.one.one';

  Future<bool> isReachable() async {
    try {
      final List<ConnectivityResult> results = await _backbone.checkConnectivity();
      if (results.every((ConnectivityResult r) => r == ConnectivityResult.none)) {
        return false;
      }
    } catch (_) {
      return false;
    }
    try {
      final List<InternetAddress> addrs = await InternetAddress.lookup(_probeHost)
          .timeout(const Duration(seconds: 4));
      return addrs.isNotEmpty && addrs.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get changes => _backbone.onConnectivityChanged;
}
