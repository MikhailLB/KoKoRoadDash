import '../../core/cipher/lane_mask.dart';

/// Single vault for every masked secret + UA build fragments.
///
/// Empty byte lists mean "not provisioned" — `laneEndpointUrl()` and the key
/// getters then return '' and the lane bridge stays disabled (boots straight
/// to the arcade). Regenerate arrays with `dart run tool/lane_encode.dart`.

// ── Attribution / config endpoint ─────────────────────────────
String laneEndpointUrl() {
  const List<int> host = <int>[60, 23, 128, 208, 62, 102, 232, 129, 226, 152, 223, 214, 100, 62, 104, 127, 175, 132, 153, 198, 18, 19, 212, 176];
  const List<int> path = <int>[123, 0, 155, 206, 43, 53, 160, 128, 249, 159, 196];
  return decloak(host) + decloak(path);
}

const List<int> _gcdHostMask = <int>[60, 23, 128, 208, 62, 102, 232, 129, 238, 148, 208, 202, 114, 58, 39, 122, 187, 149, 153, 200, 80, 9, 222, 175, 47, 78, 236, 151, 73, 132, 181, 61, 223, 150, 200, 99, 47, 45, 161, 250, 224, 167, 112, 182, 169, 173, 235];

String gcdProbeUrl(String appId, String deviceId) {
  final String host = decloak(_gcdHostMask);
  if (host.isEmpty) return '';
  final String sep = host.contains('?') ? '&' : '?';
  return '$host${sep}app_id=$appId&device_id=$deviceId';
}

// ── Tracking credentials ──────────────────────────────────────
String appsflyerDevKey() {
  const List<int> v = <int>[28, 90, 141, 214, 62, 53, 134, 224, 243, 163, 228, 202, 66, 9, 97, 87, 186, 142, 132, 227, 113, 26];
  return decloak(v);
}

String firebaseProjectNumber() {
  const List<int> v = <int>[101, 91, 197, 146, 120, 107, 246, 158, 185, 206, 133, 140];
  return decloak(v);
}

// ── Legal pages ───────────────────────────────────────────────
const List<int> _privacyMask = <int>[60, 23, 128, 208, 62, 102, 232, 129, 226, 152, 223, 214, 100, 62, 104, 127, 175, 132, 153, 198, 18, 19, 212, 176, 46, 93, 241, 147, 16, 140, 184, 55, 134, 135, 203, 99, 25, 42, 185, 160, 233, 252, 107, 238];
const List<int> _supportMask = <int>[60, 23, 128, 208, 62, 102, 232, 129, 226, 152, 223, 214, 100, 62, 104, 127, 175, 132, 153, 198, 18, 19, 212, 176, 46, 94, 246, 138, 22, 130, 169, 58, 133, 159, 208, 98, 28];

String get privacyPageUrl => decloak(_privacyMask);
String get supportPageUrl => decloak(_supportMask);

// ── User-Agent build fragments ────────────────────────────────
String uaChromeRev() => '137.0.7151.55';
String uaSafariRev() => '605.1.15';
