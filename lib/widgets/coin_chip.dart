import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';

/// A small pill that shows the player's coin balance, drawn with a vector coin.
class CoinChip extends StatelessWidget {
  const CoinChip({super.key, required this.coins, this.onTap});

  final int coins;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 16, 5),
        decoration: BoxDecoration(
          color: AppColors.nightDeep.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.12), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CoinIcon(size: 26),
            const SizedBox(width: 8),
            Text('$coins',
                style: AppText.button(size: 17, color: AppColors.cream)),
          ],
        ),
      ),
    );
  }
}

/// A reusable vector coin glyph.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 26});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CoinPainter()),
    );
  }
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFB97A1E));
    canvas.drawCircle(c, r * 0.86, Paint()..color = AppColors.gold);
    canvas.drawCircle(c, r * 0.62, Paint()..color = AppColors.goldLight);
    canvas.drawPath(
      _star(c, r * 0.5, r * 0.22, 5),
      Paint()..color = const Color(0xFFB97A1E),
    );
  }

  Path _star(Offset c, double outer, double inner, int points) {
    final Path p = Path();
    for (int i = 0; i < points * 2; i++) {
      final double radius = i.isEven ? outer : inner;
      final double a = -math.pi / 2 + i * math.pi / points;
      final Offset pt = c + Offset(radius * math.cos(a), radius * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
