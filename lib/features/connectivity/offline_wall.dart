import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Full-screen "No Internet" error using KokoRoadDash branded webp backgrounds.
/// The webp already contains all text/icons — we only overlay the Retry button.
/// Portrait  → assets/nowifi/Vertical_Nowifi_Screen.webp
/// Landscape → assets/nowifi/Horizontal_Nowifi_Screen.webp
class OfflineWall extends StatefulWidget {
  final WidgetBuilder retryBuilder;

  const OfflineWall({super.key, required this.retryBuilder});

  @override
  State<OfflineWall> createState() => _OfflineWallState();
}

class _OfflineWallState extends State<OfflineWall>
    with TickerProviderStateMixin {
  bool _retrying = false;
  late AnimationController _btnCtrl;
  late Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _btnScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRetry() async {
    if (_retrying) return;
    await _btnCtrl.forward();
    await _btnCtrl.reverse();
    setState(() => _retrying = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.retryBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final padding = MediaQuery.of(context).padding;

    final bgAsset = isLandscape
        ? 'assets/nowifi/Horizontal_Nowifi_Screen.webp'
        : 'assets/nowifi/Vertical_Nowifi_Screen.webp';

    // Button horizontal insets adapt to orientation
    final double hPad = isLandscape ? size.width * 0.30 : 36.0;
    // Bottom inset accounts for camera notch in landscape + system padding
    final double bPad = isLandscape
        ? (padding.bottom + 20).clamp(20.0, 60.0)
        : (padding.bottom + 48).clamp(48.0, 100.0);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen branded background (contains all text/icons)
          Image.asset(
            bgAsset,
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
          ),

          // Only the Retry button, anchored to the bottom
          Positioned(
            left: hPad,
            right: hPad,
            bottom: bPad,
            child: ScaleTransition(
              scale: _btnScale,
              child: _RetryButton(
                retrying: _retrying,
                onTap: _onRetry,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final bool retrying;
  final VoidCallback onTap;

  const _RetryButton({required this.retrying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: retrying
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF5CEBFB), Color(0xFF1FB6CE)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          color: retrying ? AppColors.neon.withValues(alpha: 0.25) : null,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.neon.withValues(alpha: retrying ? 0.3 : 0.7),
            width: 1.5,
          ),
          boxShadow: retrying
              ? []
              : [
                  BoxShadow(
                    color: AppColors.neon.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: retrying ? null : onTap,
            child: Center(
              child: retrying
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.neon.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Connecting...',
                          style: AppText.button(
                            size: 16,
                            color: AppColors.neon.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Retry',
                      style: AppText.button(
                        size: 18,
                        color: const Color(0xFF052A30),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
