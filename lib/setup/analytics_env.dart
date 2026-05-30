import '../core/cipher/xkey.dart';

// ============================================================
// ANALYTICS ENV — Obfuscated AppsFlyer + Firebase credentials
// ============================================================
// All values are XOR-encoded byte arrays.
// NEVER store plaintext API keys or project IDs as string literals.
//
// HOW TO GENERATE:
//   1. Fill in your plaintext values in tool/encode_keys.dart
//   2. Run: dart run tool/encode_keys.dart
//   3. Copy the printed arrays into the const lists below
//
// ⚠️ ALWAYS use `dart run`, never PowerShell foreach loops —
//    PowerShell overflows 32-bit integers on Windows.
// ============================================================

/// Returns the decoded AppsFlyer Dev Key.
/// TODO: Replace the byte array with your encoded key.
String resolveAFKey() {
  const v = <int>[56, 246, 160, 166, 89, 65, 245, 89, 106, 74, 176, 74, 130, 251, 149, 98, 87, 220, 134, 254, 121, 98];
  return xd(v);
}

/// Returns the decoded Firebase project number (sender ID).
String resolveFBProject() {
  const v = <int>[48, 145, 212, 162, 8, 11, 180, 55, 12, 71, 230, 29];
  return xd(v);
}

/// Builds the GCD endpoint URL for AppsFlyer attribution retry.
/// Format: https://gcdsdk.appsflyer.com/install_data/v4.0/{appId}?device_id={deviceId}
String resolveGcdUrl(String appId, String deviceId) {
  const host = <int>[];
  const path = <int>[];
  if (host.isEmpty) return '';
  return '${xd(host)}${xd(path)}?app_id=$appId&device_id=$deviceId';
}
