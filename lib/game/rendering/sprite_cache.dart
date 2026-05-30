import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// Decodes and caches [ui.Image] instances for the [CustomPainter] board.
///
/// Widgets normally use `Image.asset`, but the game canvas draws raw images
/// directly, so we decode them once and keep them resident.
class SpriteCache {
  SpriteCache._();
  static final SpriteCache instance = SpriteCache._();

  final Map<String, ui.Image> _images = <String, ui.Image>{};

  ui.Image? get(String assetPath) => _images[assetPath];

  bool get isEmpty => _images.isEmpty;

  /// Decode a set of asset paths, skipping any already cached. Failures are
  /// swallowed so one missing asset never blocks the rest.
  Future<void> loadAll(Iterable<String> assetPaths) async {
    final List<Future<void>> jobs = <Future<void>>[];
    for (final String path in assetPaths.toSet()) {
      if (_images.containsKey(path)) continue;
      jobs.add(_load(path));
    }
    await Future.wait(jobs);
  }

  Future<void> _load(String path) async {
    try {
      final ByteData data = await rootBundle.load(path);
      final ui.Codec codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo frame = await codec.getNextFrame();
      _images[path] = frame.image;
    } catch (_) {
      // Asset missing or undecodable — leave it out; painter guards for null.
    }
  }
}
