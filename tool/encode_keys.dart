// ============================================================
// ENCODE KEYS — XOR encodes sensitive strings for obfuscation
// ============================================================
// Run: dart run tool/encode_keys.dart
//
// ⚠️ ALWAYS use `dart run`, never PowerShell foreach loops —
//    PowerShell overflows 32-bit integers → wrong byte values.
//
// WORKFLOW:
//   1. Fill in your plaintext values below
//   2. dart run tool/encode_keys.dart
//   3. Paste printed arrays into:
//      - lib/setup/network_env.dart  → resolveConfigEndpoint()
//      - lib/setup/analytics_env.dart → resolveAFKey() / resolveFBProject()
//      - lib/net/road_net_client.dart → _chromeFrag / _webkitFrag
// ============================================================

void main() {
  // ── Project seed (must match lib/core/cipher/xkey.dart) ──────────────────
  // Seed: "kokoroad" → [107, 111, 107, 111, 114, 111, 97, 100]
  const seed = [107, 111, 107, 111, 114, 111, 97, 100];

  // ── Plaintext values to encode ───────────────────────────────────────────
  // TODO: Replace these placeholders with real values from your manager.

  // Config endpoint
  const configEndpointHost = 'https://kokkoroaddash.com';
  const configEndpointPath = '/config.php';

  // AppsFlyer Dev Key
  const appsFlyerKey = '9PG2dsvYS4ofwqnzVzajDP';

  // Firebase project number
  const firebaseProjectNumber = '173659775991';

  // Chrome version fragment for Android User-Agent
  const chromeVersion = '130.0.6723.102';

  // WebKit version fragment for iOS User-Agent
  const webkitVersion = '537.36';

  // ─────────────────────────────────────────────────────────────────────────

  final key = _deriveKey(seed);

  print('// ── Encoded values (paste into respective files) ──────────────────');
  print('');
  print('// lib/setup/network_env.dart → resolveConfigEndpoint()');
  print('// host:');
  print(_encode(configEndpointHost, key));
  print('// path:');
  print(_encode(configEndpointPath, key));
  print('');
  print('// lib/setup/analytics_env.dart → resolveAFKey()');
  print(_encode(appsFlyerKey, key));
  print('');
  print('// lib/setup/analytics_env.dart → resolveFBProject()');
  print(_encode(firebaseProjectNumber, key));
  print('');
  print('// lib/net/road_net_client.dart → _chromeFrag');
  print(_encode(chromeVersion, key));
  print('');
  print('// lib/net/road_net_client.dart → _webkitFrag');
  print(_encode(webkitVersion, key));
}

List<int> _deriveKey(List<int> parts) {
  final seed = parts.fold<int>(0, (a, b) => (a * 31 + b) & 0xFFFFFFFF);
  final key = List<int>.filled(16, 0);
  var v = seed;
  for (var i = 0; i < 16; i++) {
    v = (v * 1103515245 + 12345) & 0x7FFFFFFF;
    key[i] = v & 0xFF;
  }
  return key;
}

String _encode(String plaintext, List<int> key) {
  final bytes = plaintext.codeUnits;
  final out = <int>[];
  for (var i = 0; i < bytes.length; i++) {
    out.add(bytes[i] ^ key[i % key.length]);
  }
  return 'const <int>[${out.join(', ')}]';
}
