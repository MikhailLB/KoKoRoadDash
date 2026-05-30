import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A living, fully vector-drawn backdrop: a scrolling sci-fi road with neon
/// side rails, drifting lane dashes and floating light motes. Used behind the
/// menu and other full-screen UI so the brand reads instantly without leaning
/// on a templated layout.
class MenuBackground extends StatefulWidget {
  const MenuBackground({super.key, this.child});
  final Widget? child;

  @override
  State<MenuBackground> createState() => _MenuBackgroundState();
}

class _MenuBackgroundState extends State<MenuBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    final math.Random rng = math.Random(7);
    _motes = List<_Mote>.generate(
      18,
      (int i) => _Mote(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        r: 1.5 + rng.nextDouble() * 3.5,
        speed: 0.02 + rng.nextDouble() * 0.06,
        hue: rng.nextBool(),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, _) {
              return CustomPaint(
                painter: _MenuBackgroundPainter(_c.value, _motes),
              );
            },
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _Mote {
  _Mote({
    required this.x,
    required this.y,
    required this.r,
    required this.speed,
    required this.hue,
  });
  final double x;
  double y;
  final double r;
  final double speed;
  final bool hue;
}

class _MenuBackgroundPainter extends CustomPainter {
  _MenuBackgroundPainter(this.t, this.motes);
  final double t;
  final List<_Mote> motes;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;

    // Night sky gradient.
    canvas.drawRect(
        full, Paint()..shader = AppColors.menuSky.createShader(full));

    // Soft radial glow behind the title area.
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.28),
      size.width * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            AppColors.gold.withValues(alpha: 0.16),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
            center: Offset(size.width * 0.5, size.height * 0.28),
            radius: size.width * 0.7)),
    );

    // Central road band.
    final double roadW = size.width * 0.62;
    final Rect road = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: roadW,
      height: size.height * 1.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(road, const Radius.circular(28)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF323847), Color(0xFF262B36)],
        ).createShader(road),
    );

    // Neon side rails (no blur — keeps the continuously-animated menu cheap).
    final Paint rail = Paint()
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..shader = const LinearGradient(
        colors: <Color>[AppColors.neon, AppColors.violet],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(road);
    canvas.drawLine(road.topLeft, road.bottomLeft, rail);
    canvas.drawLine(road.topRight, road.bottomRight, rail);

    // Scrolling lane dashes (two columns).
    final double dashH = size.height * 0.06;
    final double gap = dashH * 1.1;
    final double cycle = dashH + gap;
    final double offset = (t * cycle * 4) % cycle;
    final Paint dash = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (final double cx in <double>[
      size.width / 2 - roadW * 0.22,
      size.width / 2 + roadW * 0.22,
    ]) {
      for (double y = -cycle + offset; y < size.height + cycle; y += cycle) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, y),
                width: roadW * 0.05,
                height: dashH),
            const Radius.circular(4),
          ),
          dash,
        );
      }
    }

    // Floating motes (soft glow via stacked translucent circles, no blur).
    for (final _Mote m in motes) {
      final double y = (m.y - t * m.speed * 6) % 1.0;
      final Offset p = Offset(m.x * size.width, y * size.height);
      final Color c = m.hue ? AppColors.neon : AppColors.goldLight;
      canvas.drawCircle(p, m.r * 2.0, Paint()..color = c.withValues(alpha: 0.12));
      canvas.drawCircle(p, m.r, Paint()..color = c.withValues(alpha: 0.55));
    }

    // Bottom vignette for button legibility.
    canvas.drawRect(
      Rect.fromLTRB(0, size.height * 0.55, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            AppColors.nightDeep.withValues(alpha: 0.85),
          ],
        ).createShader(
            Rect.fromLTRB(0, size.height * 0.55, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant _MenuBackgroundPainter oldDelegate) =>
      oldDelegate.t != t;
}
