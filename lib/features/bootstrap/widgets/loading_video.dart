import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/asset_paths.dart';
import '../../../core/theme/app_colors.dart';

/// Plays the looping loading clip for the given orientation, scaled to cover
/// the screen. Falls back to a gradient if the video can't initialise.
class LoadingVideo extends StatefulWidget {
  const LoadingVideo({super.key, required this.landscape});
  final bool landscape;

  @override
  State<LoadingVideo> createState() => _LoadingVideoState();
}

class _LoadingVideoState extends State<LoadingVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final String asset = widget.landscape
        ? AssetPaths.loadingVideoHorizontal
        : AssetPaths.loadingVideoVertical;
    final VideoPlayerController c = VideoPlayerController.asset(asset);
    _controller = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? c = _controller;
    if (!_ready || c == null || !c.value.isInitialized) {
      return const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.menuSky),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}
