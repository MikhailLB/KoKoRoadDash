import 'package:flutter/foundation.dart';

import '../../core/storage/local_store.dart';
import '../models/skin.dart';

/// Single source of truth for player progression, currency, cosmetics and
/// settings. Persists through [LocalStore] and notifies listeners on change.
class ProgressRepository extends ChangeNotifier {
  ProgressRepository(this._store) {
    _load();
  }

  final LocalStore _store;

  // Keys --------------------------------------------------------------------
  static const String _kHighest = 'highest_level';
  static const String _kCurrent = 'current_level';
  static const String _kCoins = 'coins';
  static const String _kUnlocked = 'unlocked_skins';
  static const String _kSelected = 'selected_skin';
  static const String _kStars = 'stars_by_level';
  static const String _kHaptics = 'haptics_enabled';
  static const String _kSound = 'sound_enabled';
  static const String _kSeenOnboarding = 'seen_onboarding';
  static const String _kHints = 'hints';

  /// Hints handed out to a brand-new player.
  static const int startingHints = 3;

  int _highestLevel = 1;
  int _currentLevel = 1;
  int _coins = 0;
  List<String> _unlocked = <String>['default'];
  String _selectedSkin = 'default';
  Map<String, int> _stars = <String, int>{};
  bool _haptics = true;
  bool _sound = true;
  bool _seenOnboarding = false;
  int _hints = startingHints;

  int get highestLevel => _highestLevel;
  int get currentLevel => _currentLevel;
  int get coins => _coins;
  List<String> get unlockedSkins => List<String>.unmodifiable(_unlocked);
  String get selectedSkin => _selectedSkin;
  bool get hapticsEnabled => _haptics;
  bool get soundEnabled => _sound;
  bool get seenOnboarding => _seenOnboarding;
  int get hints => _hints;

  int starsFor(int level) => _stars['$level'] ?? 0;
  int get totalStars => _stars.values.fold(0, (int a, int b) => a + b);
  bool isUnlocked(String skinId) => _unlocked.contains(skinId);

  void _load() {
    _highestLevel = _store.getInt(_kHighest, fallback: 1);
    _currentLevel = _store.getInt(_kCurrent, fallback: 1);
    _coins = _store.getInt(_kCoins);
    final List<String> unlocked = _store.getStringList(_kUnlocked);
    _unlocked = unlocked.isEmpty ? <String>['default'] : unlocked;
    _selectedSkin = _store.getString(_kSelected, fallback: 'default');
    _stars = _store
        .getJson(_kStars)
        .map((String k, dynamic v) => MapEntry<String, int>(k, (v as num).toInt()));
    _haptics = _store.getBool(_kHaptics, fallback: true);
    _sound = _store.getBool(_kSound, fallback: true);
    _seenOnboarding = _store.getBool(_kSeenOnboarding);
    _hints = _store.getInt(_kHints, fallback: startingHints);
  }

  Future<void> setCurrentLevel(int level) async {
    _currentLevel = level;
    await _store.setInt(_kCurrent, level);
    notifyListeners();
  }

  /// Records a completed level: unlocks the next one, banks stars + coins.
  Future<void> completeLevel(int level, int stars, int coinReward) async {
    final String key = '$level';
    if ((_stars[key] ?? 0) < stars) {
      _stars[key] = stars;
      await _store.setJson(_kStars,
          _stars.map((String k, int v) => MapEntry<String, dynamic>(k, v)));
    }
    if (level + 1 > _highestLevel) {
      _highestLevel = level + 1;
      await _store.setInt(_kHighest, _highestLevel);
    }
    _coins += coinReward;
    await _store.setInt(_kCoins, _coins);

    _currentLevel = level + 1;
    await _store.setInt(_kCurrent, _currentLevel);
    notifyListeners();
  }

  Future<bool> tryUnlockSkin(Skin skin) async {
    if (isUnlocked(skin.id)) return true;
    if (_coins < skin.cost) return false;
    _coins -= skin.cost;
    _unlocked = <String>[..._unlocked, skin.id];
    await _store.setInt(_kCoins, _coins);
    await _store.setStringList(_kUnlocked, _unlocked);
    notifyListeners();
    return true;
  }

  Future<void> selectSkin(String skinId) async {
    if (!isUnlocked(skinId)) return;
    _selectedSkin = skinId;
    await _store.setString(_kSelected, skinId);
    notifyListeners();
  }

  Future<void> addCoins(int amount) async {
    _coins += amount;
    await _store.setInt(_kCoins, _coins);
    notifyListeners();
  }

  /// Spend coins if affordable; returns false (and changes nothing) otherwise.
  Future<bool> spendCoins(int amount) async {
    if (_coins < amount) return false;
    _coins -= amount;
    await _store.setInt(_kCoins, _coins);
    notifyListeners();
    return true;
  }

  /// Consume one hint from the inventory. Returns false if empty.
  Future<bool> useHint() async {
    if (_hints <= 0) return false;
    _hints -= 1;
    await _store.setInt(_kHints, _hints);
    notifyListeners();
    return true;
  }

  /// Buy a pack of hints with coins. Returns false if not affordable.
  Future<bool> buyHints(int count, int cost) async {
    if (_coins < cost) return false;
    _coins -= cost;
    _hints += count;
    await _store.setInt(_kCoins, _coins);
    await _store.setInt(_kHints, _hints);
    notifyListeners();
    return true;
  }

  Future<void> setHaptics(bool value) async {
    _haptics = value;
    await _store.setBool(_kHaptics, value);
    notifyListeners();
  }

  Future<void> setSound(bool value) async {
    _sound = value;
    await _store.setBool(_kSound, value);
    notifyListeners();
  }

  Future<void> markOnboardingSeen() async {
    _seenOnboarding = true;
    await _store.setBool(_kSeenOnboarding, true);
    notifyListeners();
  }

  /// Wipes all progression but keeps onboarding/settings flags.
  Future<void> resetAll() async {
    _highestLevel = 1;
    _currentLevel = 1;
    _coins = 0;
    _unlocked = <String>['default'];
    _selectedSkin = 'default';
    _stars = <String, int>{};
    _hints = startingHints;
    await _store.setInt(_kHints, _hints);
    await _store.setInt(_kHighest, 1);
    await _store.setInt(_kCurrent, 1);
    await _store.setInt(_kCoins, 0);
    await _store.setStringList(_kUnlocked, _unlocked);
    await _store.setString(_kSelected, 'default');
    await _store.setJson(_kStars, <String, dynamic>{});
    notifyListeners();
  }
}
