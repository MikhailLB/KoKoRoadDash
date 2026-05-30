import 'package:flutter/material.dart';

import '../../../core/constants/asset_paths.dart';

/// Progress bar that seamlessly cross-fades through the four bundled bar
/// states (empty -> half -> almost -> full) so the fill looks continuous.
///
/// The source art (384x688) has lots of transparent padding; the visible bar
/// is a centred band, so we crop to it (measured bounds below) and scale that
/// band up to [width].
class LoadingBar extends StatelessWidget {
  const LoadingBar({super.key, required this.progress, this.width = 300});

  /// 0..1.
  final double progress;
  final double width;

  // Measured non-transparent content bounds within the 384x688 source.
  static const double _imgW = 384;
  static const double _imgH = 688;
  static const double _contentW = 366;
  static const double _contentH = 128;

  @override
  Widget build(BuildContext context) {
    final List<String> bars = AssetPaths.loadingBars;
    final double p = progress.clamp(0.0, 1.0);
    final double scaled = p * (bars.length - 1);
    final int lower = scaled.floor().clamp(0, bars.length - 1);
    final int upper = (lower + 1).clamp(0, bars.length - 1);
    final double frac = scaled - lower;

    final double targetH = width * _contentH / _contentW;
    final double drawW = width * _imgW / _contentW;
    final double drawH = drawW * _imgH / _imgW;

    Widget barImage(String asset) => SizedBox(
          width: drawW,
          height: drawH,
          child: Image.asset(asset, fit: BoxFit.fill, gaplessPlayback: true),
        );

    return SizedBox(
      width: width,
      height: targetH,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          minWidth: 0,
          minHeight: 0,
          maxWidth: drawW,
          maxHeight: drawH,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              barImage(bars[lower]),
              Opacity(opacity: frac, child: barImage(bars[upper])),
            ],
          ),
        ),
      ),
    );
  }
}
