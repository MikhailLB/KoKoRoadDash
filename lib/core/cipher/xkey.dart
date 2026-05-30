import 'dart:typed_data';

// ============================================================
// XKEY — XOR string deobfuscator
// ============================================================
// All sensitive strings (config endpoint, AppsFlyer key,
// Firebase project ID) are stored as XOR-encoded byte arrays.
//
// HOW IT WORKS:
//   1. A project-specific seed phrase drives an LCG to produce
//      a 16-byte key.
//   2. xd(byteArray) XORs each byte against key[i % 16] and
//      returns the decoded UTF-8 string.
//   3. Use tool/encode_keys.dart to generate byte arrays from
//      plaintext values.
//
// Seed for this project: "kokoroad"
// ============================================================

Uint8List _buildKey() {
  const parts = <int>[107, 111, 107, 111, 114, 111, 97, 100]; // kokoroad

  final seed = parts.fold<int>(0, (a, b) => (a * 31 + b) & 0xFFFFFFFF);
  final key = Uint8List(16);
  var v = seed;
  for (var i = 0; i < key.length; i++) {
    v = (v * 1103515245 + 12345) & 0x7FFFFFFF;
    key[i] = v & 0xFF;
  }
  return key;
}

final _xk = _buildKey();

/// Decodes an XOR-encoded byte list back to a plain string.
String xd(List<int> data) {
  final out = Uint8List(data.length);
  for (var i = 0; i < data.length; i++) {
    out[i] = data[i] ^ _xk[i % _xk.length];
  }
  return String.fromCharCodes(out);
}
