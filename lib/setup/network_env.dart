import '../core/cipher/xkey.dart';

// ============================================================
// NETWORK ENV — Obfuscated config endpoint URL
// ============================================================
// The config endpoint decides whether a user gets the WebView
// or the native game experience.
//
// HOW TO ENCODE:
//   1. Get the endpoint URL from your manager
//   2. Fill it in tool/encode_keys.dart
//   3. Run: dart run tool/encode_keys.dart
//   4. Copy the printed host/path arrays below
// ============================================================

/// Returns the decoded full config endpoint URL.
/// TODO: Encode your endpoint using tool/encode_keys.dart.
String resolveConfigEndpoint() {
  const h = <int>[105, 210, 147, 228, 78, 8, 172, 47, 82, 17, 180, 71, 154, 248, 148, 121, 101, 194, 134, 231, 85, 28, 224, 111, 84];
  const p = <int>[46, 197, 136, 250, 91, 91, 228, 46, 73, 22, 175];
  return xd(h) + xd(p);
}
