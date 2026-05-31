// ignore_for_file: avoid_print
//
// Helper that produces byte-list literals for `lib/lane/config/*.dart`.
// Fill in your real values below, then run:
//
//   dart run tool/lane_encode.dart
//
// Paste the printed arrays into:
//   - endpoint_locker.dart  (HOST + PATH + GCD)
//   - attribution_keys.dart (AppsFlyer dev key + Firebase project number)
//   - legal_links.dart      (privacy + support URLs)
//
// IMPORTANT: this seed MUST match `lib/core/cipher/lane_mask.dart`.
// Changing one without the other will produce garbage at runtime.

import 'dart:typed_data';

const List<int> _seedBytes = <int>[
  0x6B, 0x6F, 0x6B, 0x6F, 0x64, 0x61, 0x73, 0x68,
  0x2E, 0x6C, 0x61, 0x6E, 0x65, 0x2E, 0x76, 0x32,
];

Uint8List _buildStream(int size) {
  int hash = 5381;
  for (final int b in _seedBytes) {
    hash = ((hash * 33) + b) & 0xFFFFFFFF;
  }
  int state = hash == 0 ? 0x1A2B3C4D : hash;
  final Uint8List out = Uint8List(size);
  for (int i = 0; i < size; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    out[i] = ((state >> 11) ^ (i * 0x6D)) & 0xFF;
  }
  return out;
}

final Uint8List _stream = _buildStream(112);

List<int> mask(String s) {
  final List<int> out = <int>[];
  for (int i = 0; i < s.length; i++) {
    out.add(s.codeUnitAt(i) ^ _stream[i % _stream.length]);
  }
  return out;
}

String peel(List<int> raw) {
  final out = Uint8List(raw.length);
  for (int i = 0; i < raw.length; i++) {
    out[i] = raw[i] ^ _stream[i % _stream.length];
  }
  return String.fromCharCodes(out);
}

String fmt(List<int> v) => '[${v.join(', ')}]';

void main() {
  // ── EDIT THESE BEFORE RUNNING ────────────────────────────────
  const String configHost = 'https://kokoroaddash.com';
  const String configPath = '/config.php';
  const String privacyUrl = 'https://kokoroaddash.com/privacy-policy.html';
  const String supportUrl = 'https://kokoroaddash.com/support.html';
  const String gcdHost    = 'https://gcdsdk.appsflyer.com/install_data/v4.0/';
  const String afDevKey   = 'H9yvsiANzTPsTXhLqknMMj';
  const String fbProjNum  = '181257100915';
  // ─────────────────────────────────────────────────────────────

  void emit(String label, String value) {
    if (value.isEmpty) {
      print('$label : <empty — fill in encode_creds before running>');
      return;
    }
    final bytes = mask(value);
    final roundtrip = peel(bytes);
    final ok = roundtrip == value;
    print('$label : ${fmt(bytes)}    // verify=${ok ? "OK" : "MISMATCH"}');
  }

  emit('HOST', configHost);
  emit('PATH', configPath);
  emit('PRIV', privacyUrl);
  emit('SUPP', supportUrl);
  emit('GCD ', gcdHost);
  emit('AFK ', afDevKey);
  emit('FBN ', fbProjNum);
}
