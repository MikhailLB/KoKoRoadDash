import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../net/push_handler.dart';
import '../../net/vault_service.dart';
import '../../net/net_probe.dart';
import '../../setup/road_settings.dart';
import '../webview/web_shell.dart' deferred as shell;

/// Push notification opt-in screen shown before the WebView.
/// Uses KokoRoadDash branded webp backgrounds:
///   Portrait  → assets/notifications/Vertical_Notifications_Screen.webp
///   Landscape → assets/notifications/Horizontal_Notifications_Screen.webp
class PermissionGate extends StatefulWidget {
  final VaultService vault;
  final PushHandler pusher;
  final NetProbe netProbe;
  final String contentUrl;

  const PermissionGate({
    super.key,
    required this.vault,
    required this.pusher,
    required this.netProbe,
    required this.contentUrl,
  });

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final bgAsset = isLandscape
        ? 'assets/notifications/Horizontal_Notifications_Screen.webp'
        : 'assets/notifications/Vertical_Notifications_Screen.webp';

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Branded background
            Image.asset(
              bgAsset,
              fit: BoxFit.cover,
              width: size.width,
              height: size.height,
            ),

            // Buttons overlay
            if (!isLandscape)
              _PortraitButtons(
                size: size,
                onAccept: _onAccept,
                onSkip: _onSkip,
              )
            else
              _LandscapeButtons(
                size: size,
                onAccept: _onAccept,
                onSkip: _onSkip,
              ),
          ],
        ),
      ),
    );
  }

  void _onAccept() async {
    final granted = await widget.pusher.requestPermission();
    if (!mounted) return;
    if (!granted) {
      final skipUntil = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
          RoadSettings.notificationRetryDelaySeconds;
      await widget.vault.setNotificationSkipUntil(skipUntil);
    }
    _goToContent();
  }

  void _onSkip() async {
    final skipUntil = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        RoadSettings.notificationRetryDelaySeconds;
    await widget.vault.setNotificationSkipUntil(skipUntil);
    if (!mounted) return;
    _goToContent();
  }

  Future<void> _goToContent() async {
    await shell.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => shell.WebShell(
          url: widget.contentUrl,
          vault: widget.vault,
          pusher: widget.pusher,
          netProbe: widget.netProbe,
        ),
      ),
    );
  }
}

// Portrait: Accept + Skip stacked at bottom center
class _PortraitButtons extends StatelessWidget {
  final Size size;
  final VoidCallback onAccept;
  final VoidCallback onSkip;

  const _PortraitButtons({
    required this.size,
    required this.onAccept,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: size.width * 0.08,
      right: size.width * 0.08,
      bottom: size.height * 0.07,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AcceptButton(onTap: onAccept),
          const SizedBox(height: 16),
          _SkipButton(onTap: onSkip),
        ],
      ),
    );
  }
}

// Landscape: narrower centered column at bottom
class _LandscapeButtons extends StatelessWidget {
  final Size size;
  final VoidCallback onAccept;
  final VoidCallback onSkip;

  const _LandscapeButtons({
    required this.size,
    required this.onAccept,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: size.height * 0.06,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size.width * 0.32,
            child: _AcceptButton(onTap: onAccept, compact: true),
          ),
          const SizedBox(height: 8),
          _SkipButton(onTap: onSkip, compact: true),
        ],
      ),
    );
  }
}

// ─── Accept button (Koko gold style with pulsing glow) ─────────────────────

class _AcceptButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;

  const _AcceptButton({required this.onTap, this.compact = false});

  @override
  State<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends State<_AcceptButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _glowCtrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: _glow,
        builder: (_, _) => AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: widget.compact ? 12 : 17,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _pressed
                    ? [const Color(0xFFDDA020), const Color(0xFFD07010)]
                    : [AppColors.goldLight, AppColors.gold],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(widget.compact ? 16 : 20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(
                    alpha: _pressed ? 0.15 : _glow.value,
                  ),
                  blurRadius: _pressed ? 8 : 14 + _glow.value * 16,
                  spreadRadius: _pressed ? 0 : _glow.value * 3,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Allow Notifications',
                style: AppText.button(
                  size: widget.compact ? 15 : 19,
                  color: AppColors.cocoa,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Skip button (ghost text with opacity press) ────────────────────────────

class _SkipButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;

  const _SkipButton({required this.onTap, this.compact = false});

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : 0.82,
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 4 : 8),
          child: Center(
            child: Text(
              'Skip',
              style: AppText.button(
                size: widget.compact ? 15 : 20,
                color: AppColors.cream,
              ).copyWith(
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
