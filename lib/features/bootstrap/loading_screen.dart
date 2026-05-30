import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/orientation_lock.dart';
import '../../game/rendering/sprite_cache.dart';
import '../menu/main_menu_screen.dart';
import 'widgets/loading_bar.dart';
import 'widgets/loading_video.dart';

/// The first screen: a looping branded video with a progress bar that fills as
/// assets decode. This is the one screen allowed in both orientations.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    OrientationLock.all();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..forward();
    _boot();
  }

  Future<void> _boot() async {
    await Future.wait<void>(<Future<void>>[
      _preloadSprites(),
      Future<void>.delayed(const Duration(milliseconds: 3300)),
    ]);
    if (!mounted) return;
    _navigate();
  }

  Future<void> _preloadSprites() async {
    final List<String> paths = <String>[
      ...AssetPaths.cars,
      for (int b = 1; b <= 4; b++) ...<String>[
        AssetPaths.bgLine(b),
        AssetPaths.bgStart(b),
        AssetPaths.bgEnd(b),
        AssetPaths.bgSafezone(b),
      ],
      for (final s in <String>['default', 'gold', 'samurai', 'pharaon', 'dragon'])
        ...<String>[AssetPaths.chicken(s), AssetPaths.chickenSmash(s)],
    ];
    await SpriteCache.instance.loadAll(paths);
  }

  void _navigate() {
    if (_navigated) return;
    _navigated = true;
    OrientationLock.portrait();
    Navigator.of(context).pushReplacement(fadeRoute(const MainMenuScreen()));
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
          final bool landscape = orientation == Orientation.landscape;
          final Size screen = MediaQuery.of(context).size;
          final double barWidth = landscape
              ? (screen.width * 0.24).clamp(180.0, 320.0)
              : screen.width * 0.72;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              LoadingVideo(
                key: ValueKey<bool>(landscape),
                landscape: landscape,
              ),
              // The video art already carries the "LOADING" wordmark, so we
              // only overlay the progress bar — centred at the bottom.
              Positioned(
                left: 0,
                right: 0,
                bottom: landscape ? 22 : 64,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (BuildContext context, _) => LoadingBar(
                      progress: _progress.value,
                      width: barWidth,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
