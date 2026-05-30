import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/direction.dart';

/// On-screen directional controls (plus a centre "wait" key). Mirrors swipe
/// input so the puzzle is fully playable with either.
class DPad extends StatelessWidget {
  const DPad({super.key, required this.onMove, required this.enabled});

  final ValueChanged<Direction> onMove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 212,
      height: 212,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: _key(Direction.up, Icons.keyboard_arrow_up_rounded),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _key(Direction.down, Icons.keyboard_arrow_down_rounded),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _key(Direction.left, Icons.keyboard_arrow_left_rounded),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _key(Direction.right, Icons.keyboard_arrow_right_rounded),
          ),
          _DPadKey(
            icon: Icons.hourglass_empty_rounded,
            enabled: enabled,
            size: 60,
            onTap: () => onMove(Direction.none),
          ),
        ],
      ),
    );
  }

  Widget _key(Direction dir, IconData icon) {
    return _DPadKey(icon: icon, enabled: enabled, onTap: () => onMove(dir));
  }
}

class _DPadKey extends StatefulWidget {
  const _DPadKey({
    required this.icon,
    required this.onTap,
    required this.enabled,
    this.size = 66,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final double size;

  @override
  State<_DPadKey> createState() => _DPadKeyState();
}

class _DPadKeyState extends State<_DPadKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.enabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF3A4470), Color(0xFF262D52)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: widget.enabled ? AppColors.cream : AppColors.steel,
            size: widget.size * 0.5,
          ),
        ),
      ),
    );
  }
}
