import 'dart:io';

/// Minimal connectivity probe implemented with the Dart SDK only (no
/// `connectivity_plus` dependency). Performs a short DNS lookup.
class ConnectivityService {
  const ConnectivityService();

  Future<bool> isOnline() async {
    try {
      final List<InternetAddress> result = await InternetAddress.lookup(
        'apple.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
