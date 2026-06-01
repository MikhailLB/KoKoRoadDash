import 'dart:typed_data';

/// Stream-cipher style obfuscation for embedded strings.
///
/// The keystream is derived from an app-unique seed via an FNV-1a fold that
/// seeds a linear-congruential generator; each output byte is then mixed with
/// a running carry so the stream depends on its own history. Both the seed
/// AND the whole derivation differ per app, so byte arrays produced by
/// `tool/lane_encode.dart` decode under no sibling project's routine — there
/// is no shared algorithm "shape" to match.
const List<int> _seedBytes = <int>[
  0x6B, 0x64, 0x7A, 0x3A, 0x72, 0x6F, 0x61, 0x64, // "kdz:road"
  0x2F, 0x67, 0x75, 0x61, 0x72, 0x64, 0x2E, 0x76, // "/guard.v"
  0x33, 0x23, 0x37, 0x39, // "3#79"
];

Uint8List _buildStream(int size) {
  // FNV-1a 32-bit fold of the seed.
  int h = 0x811C9DC5;
  for (final int b in _seedBytes) {
    h = (h ^ b) & 0xFFFFFFFF;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  int state = (h ^ 0x9E3779B9) & 0xFFFFFFFF;
  if (state == 0) state = 0x2545F491;
  int carry = (h >> 7) & 0xFF;
  final Uint8List out = Uint8List(size);
  for (int i = 0; i < size; i++) {
    // LCG step (Numerical Recipes constants).
    state = (state * 1664525 + 1013904223) & 0xFFFFFFFF;
    final int r = ((state >> 13) ^ (state >> 21)) & 0xFF;
    carry = (carry + r + (i * 0x3B)) & 0xFF;
    out[i] = (r ^ carry) & 0xFF;
  }
  return out;
}

final Uint8List _stream = _buildStream(144);

/// Decode a masked byte list back to a UTF-8 string.
///
/// Pairs with `tool/lane_encode.dart`.
String decloak(List<int> raw) {
  if (raw.isEmpty) return '';
  final int sn = _stream.length;
  final Uint8List out = Uint8List(raw.length);
  for (int i = 0; i < raw.length; i++) {
    out[i] = raw[i] ^ _stream[i % sn];
  }
  return String.fromCharCodes(out);
}
