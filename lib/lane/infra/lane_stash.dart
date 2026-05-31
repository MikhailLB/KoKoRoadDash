import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lane_types.dart';

/// Two-tier persistence used by the lane bridge.
///
/// Sensitive material (URLs, push pre-stash) goes through
/// `flutter_secure_storage` (AES on Android, Keychain on iOS). Plain flags
/// (mode, cooldown timestamps, consent boolean) live in SharedPreferences
/// to keep reads cheap and synchronous.
///
/// All keys are namespaced `krd.lane.*` so they cannot collide with any
/// other module nor with any sibling project's secure store.
class LaneStash {
  static const String _kMode      = 'krd.lane.mode';
  static const String _kCooldown  = 'krd.lane.notify.cooldown';
  static const String _kConsent   = 'krd.lane.notify.consent';
  static const String _kUrlSafe   = 'krd.lane.shell.url';
  static const String _kUrlTtl    = 'krd.lane.shell.url.ttl';
  static const String _kOneShot   = 'krd.lane.push.oneshot';

  LaneStash();

  late SharedPreferences _prefs;
  final FlutterSecureStorage _vault = const FlutterSecureStorage();

  Future<void> open() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Mode ────────────────────────────────────────────────
  LaneMode readMode() => LaneMode.decode(_prefs.getString(_kMode));

  Future<void> writeMode(LaneMode mode) async {
    await _prefs.setString(_kMode, mode.encode());
  }

  // ── Cached shell URL ────────────────────────────────────
  Future<String?> readShellUrl() async {
    try {
      return await _vault.read(key: _kUrlSafe);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeShellUrl(String url) async {
    try {
      await _vault.write(key: _kUrlSafe, value: url);
    } catch (_) {}
  }

  Future<void> writeShellTtl(int epochSeconds) async {
    await _prefs.setInt(_kUrlTtl, epochSeconds);
  }

  bool shellUrlExpired() {
    final int? ttl = _prefs.getInt(_kUrlTtl);
    if (ttl == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= ttl;
  }

  // ── Notification consent flags ──────────────────────────
  bool readConsentGranted() => _prefs.getBool(_kConsent) ?? false;

  Future<void> writeConsentGranted(bool ok) async {
    await _prefs.setBool(_kConsent, ok);
  }

  int? readConsentCooldown() => _prefs.getInt(_kCooldown);

  Future<void> writeConsentCooldown(int epochSeconds) async {
    await _prefs.setInt(_kCooldown, epochSeconds);
  }

  /// Should we offer the consent prompt to the user right now?
  bool needsConsentPrompt() {
    if (readConsentGranted()) return false;
    final int? until = readConsentCooldown();
    if (until == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= until;
  }

  // ── One-shot URL stash (push tap from background/killed) ─
  Future<void> parkOneShotUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await _vault.write(key: _kOneShot, value: url);
    } catch (_) {}
  }

  Future<String?> drainOneShotUrl() async {
    try {
      final String? v = await _vault.read(key: _kOneShot);
      if (v != null) await _vault.delete(key: _kOneShot);
      return v;
    } catch (_) {
      return null;
    }
  }
}
