import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/skin.dart';
import '../../data/repositories/progress_repository.dart';
import '../../widgets/coin_chip.dart';
import '../menu/widgets/menu_background.dart';

class SkinsScreen extends StatelessWidget {
  const SkinsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProgressRepository progress = AppScope.progressOf(context);
    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: progress,
            builder: (BuildContext context, _) {
              return Column(
                children: <Widget>[
                  _Header(coins: progress.coins),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: Skin.catalog.length,
                      itemBuilder: (BuildContext context, int i) {
                        final Skin skin = Skin.catalog[i];
                        return _SkinTile(
                          skin: skin,
                          unlocked: progress.isUnlocked(skin.id),
                          selected: progress.selectedSkin == skin.id,
                          onTap: () => _onTap(context, progress, skin),
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

  Future<void> _onTap(
      BuildContext context, ProgressRepository progress, Skin skin) async {
    if (progress.isUnlocked(skin.id)) {
      await progress.selectSkin(skin.id);
      return;
    }
    final bool ok = await progress.tryUnlockSkin(skin);
    if (!context.mounted) return;
    if (ok) {
      await progress.selectSkin(skin.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.panel,
          content: Text('Need ${skin.cost - progress.coins} more coins'),
        ),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.cream),
          ),
          Expanded(
            child: Text('SKINS',
                textAlign: TextAlign.center, style: AppText.title(size: 26)),
          ),
          CoinChip(coins: coins),
        ],
      ),
    );
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile({
    required this.skin,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final Skin skin;
  final bool unlocked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[AppColors.panelLight, AppColors.panel],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AppColors.goldLight
                : Colors.white.withValues(alpha: 0.10),
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    ColorFiltered(
                      colorFilter: unlocked
                          ? const ColorFilter.mode(
                              Colors.transparent, BlendMode.multiply)
                          : const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ]),
                      child: Image.asset(
                        AssetPaths.chicken(skin.id),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                    if (!unlocked)
                      const Icon(Icons.lock_rounded,
                          color: AppColors.cream, size: 34),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(skin.name,
                  style: AppText.button(size: 16, color: AppColors.white)),
              const SizedBox(height: 4),
              _statusChip(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip() {
    if (selected) {
      return _chip('SELECTED', AppColors.neonGreen, AppColors.ink);
    }
    if (unlocked) {
      return _chip('SELECT', AppColors.gold, AppColors.cocoa);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CoinIcon(size: 18),
        const SizedBox(width: 6),
        Text('${skin.cost}',
            style: AppText.button(size: 15, color: AppColors.goldLight)),
      ],
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(label, style: AppText.button(size: 13, color: fg)),
    );
  }
}
