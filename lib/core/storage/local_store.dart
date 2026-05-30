import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin, typed wrapper around [SharedPreferences].
///
/// All persistence flows through here so the rest of the app never touches the
/// plugin directly. Values are cached in-memory after the initial load for
/// synchronous reads from widgets.
class LocalStore {
  LocalStore._(this._prefs);

  final SharedPreferences _prefs;

  static LocalStore? _instance;
  static LocalStore get instance {
    final LocalStore? i = _instance;
    if (i == null) {
      throw StateError('LocalStore.init() must be awaited before use.');
    }
    return i;
  }

  static Future<LocalStore> init() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return _instance ??= LocalStore._(prefs);
  }

  int getInt(String key, {int fallback = 0}) =>
      _prefs.getInt(key) ?? fallback;

  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;

  Future<void> setBool(String key, bool value) =>
      _prefs.setBool(key, value);

  String getString(String key, {String fallback = ''}) =>
      _prefs.getString(key) ?? fallback;

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  List<String> getStringList(String key) =>
      _prefs.getStringList(key) ?? const <String>[];

  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  Map<String, dynamic> getJson(String key) {
    final String raw = _prefs.getString(key) ?? '';
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));
}
