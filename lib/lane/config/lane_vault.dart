import '../../core/cipher/lane_mask.dart';

/// Single vault for every masked secret + UA build fragments.
///
/// Empty byte lists mean "not provisioned" — `laneEndpointUrl()` and the key
/// getters then return '' and the lane bridge stays disabled (boots straight
/// to the arcade). Regenerate arrays with `dart run tool/lane_encode.dart`.

// ── Attribution / config endpoint ─────────────────────────────
String laneEndpointUrl() {
  const List<int> host = <int>[221, 2, 182, 69, 121, 216, 243, 168, 17, 67, 184, 43, 170, 80, 148, 94, 123, 21, 36, 102, 103, 233, 33, 91];
  const List<int> path = <int>[154, 21, 173, 91, 108, 139, 187, 169, 10, 68, 163];
  return peel(host) + peel(path);
}

const List<int> _gcdHostMask = <int>[221, 2, 182, 69, 121, 216, 243, 168, 29, 79, 183, 55, 188, 84, 219, 91, 111, 4, 36, 104, 37, 243, 43, 68, 89, 70, 202, 218, 40, 167, 133, 103, 139, 78, 51, 100, 47, 207, 123, 218, 95, 155, 162, 10, 79, 215, 102];

String gcdProbeUrl(String appId, String deviceId) {
  final String host = peel(_gcdHostMask);
  if (host.isEmpty) return '';
  final String sep = host.contains('?') ? '&' : '?';
  return '$host${sep}app_id=$appId&device_id=$deviceId';
}

// ── Tracking credentials ──────────────────────────────────────
String appsflyerDevKey() {
  const List<int> v = <int>[253, 79, 187, 67, 121, 139, 157, 201, 0, 120, 131, 55, 140, 103, 157, 118, 110, 31, 57, 67, 4, 224];
  return peel(v);
}

String firebaseProjectNumber() {
  const List<int> v = <int>[132, 78, 243, 7, 63, 213, 237, 183, 74, 21, 226, 113];
  return peel(v);
}

// ── Legal pages ───────────────────────────────────────────────
const List<int> _privacyMask = <int>[221, 2, 182, 69, 121, 216, 243, 168, 17, 67, 184, 43, 170, 80, 148, 94, 123, 21, 36, 102, 103, 233, 33, 91, 88, 85, 215, 222, 113, 175, 136, 109, 210, 95, 48, 100, 25, 200, 99, 128, 86, 192, 185, 82];
const List<int> _supportMask = <int>[221, 2, 182, 69, 121, 216, 243, 168, 17, 67, 184, 43, 170, 80, 148, 94, 123, 21, 36, 102, 103, 233, 33, 91, 88, 86, 208, 199, 119, 161, 153, 96, 209, 71, 43, 101, 28];

String get privacyPageUrl => peel(_privacyMask);
String get supportPageUrl => peel(_supportMask);

// ── User-Agent build fragments ────────────────────────────────
String uaChromeRev() => '137.0.7151.55';
String uaSafariRev() => '605.1.15';
