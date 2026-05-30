import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/orientation_lock.dart';
import '../../data/repositories/progress_repository.dart';
import '../../widgets/coin_chip.dart';
import '../../widgets/koko_button.dart';
import '../game/game_screen.dart';
import '../game/widgets/how_to_play_sheet.dart';
import '../settings/settings_screen.dart';
import '../skins/skins_screen.dart';
import 'level_select_screen.dart';
import 'widgets/mascot.dart';
import 'widgets/menu_background.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  @override
  void initState() {
    super.initState();
    OrientationLock.portrait();
  }

  void _play(BuildContext context, ProgressRepository progress) {
    Navigator.of(context).push(
      fadeRoute(GameScreen(levelIndex: progress.currentLevel)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProgressRepository progress = AppScope.progressOf(context);

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: progress,
            builder: (BuildContext context, _) {
              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  // Explicit vertical budget so nothing ever overflows.
                  final double h = c.maxHeight;
                  final double logoH = (h * 0.26).clamp(120.0, 260.0);
                  final double mascotH = (h * 0.20).clamp(96.0, 190.0);

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
                    child: Column(
                      children: <Widget>[
                        _TopBar(
                          coins: progress.coins,
                          stars: progress.totalStars,
                          onSettings: () => Navigator.of(context)
                              .push(fadeRoute(const SettingsScreen())),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              SizedBox(
                                height: logoH,
                                child: Image.asset(
                                  AssetPaths.gameName,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _MascotStage(
                                skinId: progress.selectedSkin,
                                height: mascotH,
                              ),
                            ],
                          ),
                        ),
                        _PlayButton(
                          level: progress.currentLevel,
                          onPressed: () => _play(context, progress),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: KokoButton(
                                label: 'LEVELS',
                                icon: Icons.grid_view_rounded,
                                style: KokoButtonStyle.neon,
                                height: 54,
                                fontSize: 16,
                                onPressed: () => Navigator.of(context).push(
                                    fadeRoute(const LevelSelectScreen())),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: KokoButton(
                                label: 'SKINS',
                                icon: Icons.auto_awesome_rounded,
                                style: KokoButtonStyle.orange,
                                height: 54,
                                fontSize: 16,
                                onPressed: () => Navigator.of(context)
                                    .push(fadeRoute(const SkinsScreen())),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () => showHowToPlay(context),
                          icon: const Icon(Icons.help_outline_rounded,
                              color: AppColors.cream, size: 18),
                          label: Text('How to play',
                              style: AppText.body(
                                  size: 14, color: AppColors.cream)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.coins,
    required this.stars,
    required this.onSettings,
  });

  final int coins;
  final int stars;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          KokoIconButton(icon: Icons.settings_rounded, onPressed: onSettings),
          Row(
            children: <Widget>[
              _StarChip(stars: stars),
              const SizedBox(width: 10),
              CoinChip(coins: coins),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarChip extends StatelessWidget {
  const _StarChip({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 14, 5),
      decoration: BoxDecoration(
        color: AppColors.nightDeep.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.star_rounded, color: AppColors.goldLight, size: 22),
          const SizedBox(width: 6),
          Text('$stars',
              style: AppText.button(size: 16, color: AppColors.cream)),
        ],
      ),
    );
  }
}

/// The mascot standing on a glowing neon stage pad.
class _MascotStage extends StatelessWidget {
  const _MascotStage({required this.skinId, required this.height});
  final String skinId;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: height * 1.15,
          height: height * 0.22,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: <Color>[
                AppColors.neon.withValues(alpha: 0.45),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(200),
          ),
        ),
        Mascot(skinId: skinId, height: height),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.level, required this.onPressed});

  final int level;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text('LEVEL $level',
            style: AppText.label(size: 13, color: AppColors.goldLight)),
        const SizedBox(height: 6),
        KokoButton(
          label: 'PLAY',
          icon: Icons.play_arrow_rounded,
          style: KokoButtonStyle.gold,
          height: 64,
          fontSize: 23,
          onPressed: onPressed,
        ),
      ],
    );
  }
}
