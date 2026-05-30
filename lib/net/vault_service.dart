import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/run_mode.dart';

/// Persistent storage for gray flow state.
/// Uses SharedPreferences for non-sensitive values and FlutterSecureStorage
/// for URLs and push tokens (encrypted on device).
class VaultService {
  static const _kMode = 'run_mode';
  static const _kUrl = 'sv_url';
  static const _kExpires = 'url_exp';
  static const _kSkipUntil = 'nf_skip';
  static const _kGranted = 'nf_ok';
  static const _kOsDenied = 'nf_denied';
  static const _kPushUrl = 'psh_url';

  late SharedPreferences _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // -- Run Mode --

  RunMode getRunMode() => RunMode.fromString(_prefs.getString(_kMode));

  Future<void> setRunMode(RunMode mode) async {
    await _prefs.setString(_kMode, mode.toKey());
  }

  // -- Saved URL (encrypted) --

  Future<String?> getSavedUrl() => _secure.read(key: _kUrl);

  Future<void> setSavedUrl(String url) => _secure.write(key: _kUrl, value: url);

  // -- URL Expiry --

  int? getUrlExpires() => _prefs.getInt(_kExpires);

  Future<void> setUrlExpires(int ts) => _prefs.setInt(_kExpires, ts);

  bool isUrlExpired() {
    final ts = getUrlExpires();
    if (ts == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= ts;
  }

  // -- Notification Permission --

  bool isNotificationGranted() => _prefs.getBool(_kGranted) ?? false;

  Future<void> setNotificationGranted(bool v) =>
      _prefs.setBool(_kGranted, v);

  bool isNotificationOsDenied() => _prefs.getBool(_kOsDenied) ?? false;

  Future<void> setNotificationOsDenied() => _prefs.setBool(_kOsDenied, true);

  int? getNotificationSkipUntil() => _prefs.getInt(_kSkipUntil);

  Future<void> setNotificationSkipUntil(int ts) =>
      _prefs.setInt(_kSkipUntil, ts);

  bool shouldShowNotificationScreen() {
    if (isNotificationGranted()) return false;
    if (isNotificationOsDenied()) return false;
    final skip = getNotificationSkipUntil();
    if (skip == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= skip;
  }

  // -- One-time Push URL (encrypted) --

  Future<String?> getPushUrl() => _secure.read(key: _kPushUrl);

  Future<void> setPushUrl(String? url) async {
    if (url == null) {
      await _secure.delete(key: _kPushUrl);
    } else {
      await _secure.write(key: _kPushUrl, value: url);
    }
  }

  Future<String?> consumePushUrl() async {
    final url = await getPushUrl();
    if (url != null) await _secure.delete(key: _kPushUrl);
    return url;
  }
}
