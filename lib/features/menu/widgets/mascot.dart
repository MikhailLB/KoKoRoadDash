import 'package:flutter/material.dart';

import '../../../core/constants/asset_paths.dart';

/// The selected chicken, idly bobbing on a soft glowing pad. Pure presentation.
class Mascot extends StatefulWidget {
  const Mascot({super.key, required this.skinId, this.height = 180});

  final String skinId;
  final double height;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
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
        final double t = Curves.easeInOut.transform(_c.value);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Transform.translate(
              offset: Offset(0, -6 * t),
              child: child,
            ),
            const SizedBox(height: 2),
            Container(
              width: widget.height * 0.5 + 8 * t,
              height: 14,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        );
      },
      child: SizedBox(
        height: widget.height,
        child: Image.asset(
          AssetPaths.chicken(widget.skinId),
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
