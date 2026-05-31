import 'dart:typed_data';

/// Stream-cipher style obfuscation for embedded strings.
///
/// The keystream is derived from an app-unique seed via a djb2 fold seeding
/// an xorshift32 generator, then position-mixed. Both the seed AND the
/// derivation differ per app, so byte arrays produced by
/// `tool/lane_encode.dart` will not decode under any sibling project's
/// routine — there is no shared algorithm "shape" to match.
const List<int> _seedBytes = <int>[
  0x6B, 0x6F, 0x6B, 0x6F, 0x64, 0x61, 0x73, 0x68, // "kokodash"
  0x2E, 0x6C, 0x61, 0x6E, 0x65, 0x2E, 0x76, 0x32, // ".lane.v2"
];

Uint8List _buildStream(int size) {
  // djb2 fold of the seed → 32-bit xorshift state.
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

/// Decode a masked byte list back to a UTF-8 string.
///
/// Pairs with `tool/lane_encode.dart`.
String peel(List<int> raw) {
  if (raw.isEmpty) return '';
  final int sn = _stream.length;
  final Uint8List out = Uint8List(raw.length);
  for (int i = 0; i < raw.length; i++) {
    out[i] = raw[i] ^ _stream[i % sn];
  }
  return String.fromCharCodes(out);
}
