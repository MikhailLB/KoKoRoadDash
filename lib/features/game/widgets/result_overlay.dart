import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../widgets/coin_chip.dart';
import '../../../widgets/koko_button.dart';

/// Animated dim + scale-in panel shared by the win and lose results.
class ResultOverlay extends StatefulWidget {
  const ResultOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeOutBack.transform(_c.value.clamp(0, 1));
        return Container(
          color: Colors.black.withValues(alpha: 0.62 * _c.value),
          alignment: Alignment.center,
          child: Transform.scale(
            scale: 0.8 + 0.2 * t.clamp(0, 1.0),
            child: Opacity(opacity: _c.value, child: child),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: _Panel(child: widget.child),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.panelLight, AppColors.panel],
        ),
        borderRadius: BorderRadius.circular(28),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class StarsRow extends StatelessWidget {
  const StarsRow({super.key, required this.earned, this.size = 46});
  final int earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(3, (int i) {
        final bool on = i < earned;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.08),
          child: _AnimatedStar(
            filled: on,
            size: i == 1 ? size * 1.18 : size,
            delayMs: i * 140,
          ),
        );
      }),
    );
  }
}

class _AnimatedStar extends StatefulWidget {
  const _AnimatedStar({
    required this.filled,
    required this.size,
    required this.delayMs,
  });
  final bool filled;
  final double size;
  final int delayMs;

  @override
  State<_AnimatedStar> createState() => _AnimatedStarState();
}

class _AnimatedStarState extends State<_AnimatedStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    if (widget.filled) {
      Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: widget.filled
          ? CurvedAnimation(parent: _c, curve: Curves.elasticOut)
          : const AlwaysStoppedAnimation<double>(1),
      child: Icon(
        Icons.star_rounded,
        size: widget.size,
        color: widget.filled ? AppColors.goldLight : AppColors.nightDeep,
        shadows: widget.filled
            ? <Shadow>[
                const Shadow(color: AppColors.gold, blurRadius: 12),
              ]
            : null,
      ),
    );
  }
}

/// Win result content.
class WinPanel extends StatelessWidget {
  const WinPanel({
    super.key,
    required this.level,
    required this.stars,
    required this.coins,
    required this.movesUsed,
    required this.threeStarMoves,
    required this.onNext,
    required this.onReplay,
    required this.onMenu,
  });

  final int level;
  final int stars;
  final int coins;
  final int movesUsed;
  final int threeStarMoves;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('LEVEL $level', style: AppText.label(color: AppColors.goldLight)),
        const SizedBox(height: 4),
        Text('COMPLETE!', style: AppText.title(size: 32)),
        const SizedBox(height: 18),
        StarsRow(earned: stars),
        const SizedBox(height: 10),
        Text(
          stars >= 3
              ? 'Perfect! Solved in $movesUsed moves'
              : 'Solved in $movesUsed moves  •  3★ in ≤$threeStarMoves',
          textAlign: TextAlign.center,
          style: AppText.body(size: 13, color: AppColors.steel),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.nightDeep.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CoinIcon(size: 24),
              const SizedBox(width: 8),
              Text('+$coins',
                  style: AppText.button(size: 18, color: AppColors.goldLight)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        KokoButton(
          label: 'NEXT LEVEL',
          icon: Icons.arrow_forward_rounded,
          style: KokoButtonStyle.gold,
          onPressed: onNext,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: KokoButton(
                label: 'REPLAY',
                style: KokoButtonStyle.ghost,
                height: 52,
                fontSize: 16,
                onPressed: onReplay,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KokoButton(
                label: 'MENU',
                style: KokoButtonStyle.ghost,
                height: 52,
                fontSize: 16,
                onPressed: onMenu,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Lose result content.
class LosePanel extends StatelessWidget {
  const LosePanel({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onMenu,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('SQUASHED!', style: AppText.title(size: 32, color: AppColors.orange)),
        const SizedBox(height: 10),
        Text(message,
            textAlign: TextAlign.center,
            style: AppText.body(size: 15, color: AppColors.cream)),
        const SizedBox(height: 22),
        KokoButton(
          label: 'TRY AGAIN',
          icon: Icons.refresh_rounded,
          style: KokoButtonStyle.gold,
          onPressed: onRetry,
        ),
        const SizedBox(height: 12),
        KokoButton(
          label: 'MENU',
          style: KokoButtonStyle.ghost,
          height: 52,
          fontSize: 16,
          onPressed: onMenu,
        ),
      ],
    );
  }
}
