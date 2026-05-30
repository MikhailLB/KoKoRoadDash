import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../data/repositories/progress_repository.dart';
import '../game/game_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProgressRepository progress = AppScope.progressOf(context);
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.menuSky),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: progress,
            builder: (BuildContext context, _) {
              // Show all unlocked levels plus a window of upcoming ones.
              final int count = progress.highestLevel + 11;
              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 16, 8),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.cream),
                        ),
                        Expanded(
                          child: Text('SELECT LEVEL',
                              textAlign: TextAlign.center,
                              style: AppText.title(size: 24)),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.86,
                      ),
                      itemCount: count,
                      itemBuilder: (BuildContext context, int i) {
                        final int level = i + 1;
                        final bool unlocked = level <= progress.highestLevel;
                        return _LevelCell(
                          level: level,
                          unlocked: unlocked,
                          stars: progress.starsFor(level),
                          onTap: unlocked
                              ? () {
                                  Navigator.of(context).push(fadeRoute(
                                      GameScreen(levelIndex: level)));
                                }
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LevelCell extends StatelessWidget {
  const _LevelCell({
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final int level;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: unlocked
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF3A4470), Color(0xFF2A3157)],
                )
              : const LinearGradient(
                  colors: <Color>[Color(0xFF222842), Color(0xFF1B2038)],
                ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: Colors.white.withValues(alpha: unlocked ? 0.14 : 0.05),
              width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (unlocked)
              Text('$level', style: AppText.title(size: 22))
            else
              const Icon(Icons.lock_rounded, color: AppColors.steel, size: 22),
            const SizedBox(height: 6),
            if (unlocked)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(3, (int s) {
                  return Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: s < stars ? AppColors.goldLight : AppColors.nightDeep,
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}
