import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';

enum KokoButtonStyle { gold, orange, neon, ghost }

/// A chunky, tactile game button with a 3D "lip", gradient face and a press
/// animation. Drawn entirely in Flutter — no image assets — so it stays crisp.
class KokoButton extends StatefulWidget {
  const KokoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = KokoButtonStyle.gold,
    this.icon,
    this.height = 60,
    this.expand = true,
    this.fontSize = 20,
  });

  final String label;
  final VoidCallback? onPressed;
  final KokoButtonStyle style;
  final IconData? icon;
  final double height;
  final bool expand;
  final double fontSize;

  @override
  State<KokoButton> createState() => _KokoButtonState();
}

class _KokoButtonState extends State<KokoButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null;

  void _set(bool v) {
    if (!_enabled) return;
    setState(() => _down = v);
  }

  LinearGradient get _gradient {
    switch (widget.style) {
      case KokoButtonStyle.gold:
        return AppColors.goldButton;
      case KokoButtonStyle.orange:
        return AppColors.orangeButton;
      case KokoButtonStyle.neon:
        return AppColors.neonButton;
      case KokoButtonStyle.ghost:
        return const LinearGradient(
          colors: <Color>[Color(0xFF36406F), Color(0xFF28315A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
    }
  }

  Color get _lip {
    switch (widget.style) {
      case KokoButtonStyle.gold:
        return const Color(0xFFB97A1E);
      case KokoButtonStyle.orange:
        return const Color(0xFFB73F12);
      case KokoButtonStyle.neon:
        return const Color(0xFF127E92);
      case KokoButtonStyle.ghost:
        return const Color(0xFF161D3C);
    }
  }

  Color get _textColor {
    switch (widget.style) {
      case KokoButtonStyle.gold:
      case KokoButtonStyle.orange:
        return AppColors.cocoa;
      case KokoButtonStyle.neon:
        return const Color(0xFF06343C);
      case KokoButtonStyle.ghost:
        return AppColors.cream;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double lipH = widget.height * 0.16;
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: _enabled
          ? () {
              HapticFeedback.lightImpact();
              widget.onPressed!.call();
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _enabled ? 1 : 0.5,
        child: SizedBox(
          width: widget.expand ? double.infinity : null,
          height: widget.height + lipH,
          child: Stack(
            children: <Widget>[
              // Lip / shadow base.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: widget.height + lipH,
                  decoration: BoxDecoration(
                    color: _lip,
                    borderRadius: BorderRadius.circular(widget.height * 0.32),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                top: _down ? lipH : 0,
                child: Container(
                  height: widget.height,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    gradient: _gradient,
                    borderRadius: BorderRadius.circular(widget.height * 0.32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (widget.icon != null) ...<Widget>[
                        Icon(widget.icon, color: _textColor, size: widget.fontSize + 4),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.button(
                            size: widget.fontSize,
                            color: _textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circular icon button in the same tactile language (used for nav/HUD).
class KokoIconButton extends StatelessWidget {
  const KokoIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 50,
    this.style = KokoButtonStyle.ghost,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final KokoButtonStyle style;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed!.call();
            },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: style == KokoButtonStyle.ghost
              ? const LinearGradient(
                  colors: <Color>[Color(0xFF36406F), Color(0xFF232B52)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : AppColors.goldButton,
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.25), width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon,
            color: style == KokoButtonStyle.ghost
                ? AppColors.cream
                : AppColors.cocoa,
            size: size * 0.5),
      ),
    );
  }
}
