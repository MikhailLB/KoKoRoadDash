import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Checks real internet connectivity via DNS lookup.
/// The connectivity_plus stream only detects network interface changes,
/// not actual internet access — the DNS probe confirms it.
class NetProbe {
  final Connectivity _c = Connectivity();

  Future<bool> hasInternet() async {
    final results = await _c.checkConnectivity();
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (!hasNetwork) return false;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get onChange => _c.onConnectivityChanged;
}
